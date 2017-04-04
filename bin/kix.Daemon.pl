#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use File::Path qw();
use Time::HiRes qw(sleep);
use Fcntl qw(:flock);

our $IsWin32 = 0; 
if ( $^O eq 'MSWin32' ) {
    eval { 
        require Win32; 
        require Win32::Process; 
    } or last;
    $IsWin32 = 1;
}

use Kernel::System::ObjectManager;

print STDOUT "kix.Daemon.pl - the KIX daemon\n";

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix.Daemon.pl',
    },
);

if ( !$IsWin32 ) {
    # Don't allow to run these scripts as root.
    if ( $> == 0 ) {    # $EFFECTIVE_USER_ID
        print STDERR
            "Error: You cannot run kix.Daemon.pl as root. Please run it as the apache user or with the help of su:\n";
        print STDERR "  su -c \"bin/kix.Daemon.pl ...\" -s /bin/bash <apache user>\n";
        exit 1;
    }
}

# get config object
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

# get the NodeID from the SysConfig settings, this is used on High Availability systems.
my $NodeID = $ConfigObject->Get('NodeID') || 1;

# check NodeID, if does not match its impossible to continue
if ( $NodeID !~ m{ \A \d+ \z }xms && $NodeID > 0 && $NodeID < 1000 ) {
    print STDERR "NodeID '$NodeID' is invalid. Change the NodeID to a number between 1 and 999.";
    exit 1;
}

# get pid directory
my $PIDDir  = $ConfigObject->Get('Home') . '/var/run/';
my $PIDFile = $PIDDir . "Daemon-NodeID-$NodeID.pid";
my $PIDFH;

# get default log directory
my $LogDir = $ConfigObject->Get('Daemon::Log::LogPath') || $ConfigObject->Get('Home') . '/var/log/Daemon';

if ( !-d $LogDir ) {
    File::Path::mkpath( $LogDir, 0, 0770 );    ## no critic

    if ( !-d $LogDir ) {
        print STDERR "Failed to create path: $LogDir";
        exit 1;
    }
}

if ( !@ARGV ) {
    PrintUsage();
    exit 0;
}

# to wait until all daemon stops (in seconds)
my $DaemonStopWait = 30;
my $ForceStop;

# check for debug mode
my %DebugDaemons;
my $Debug;
if (
    ((lc $ARGV[0] eq 'start') || (lc $ARGV[0] eq '--child') || (lc $ARGV[0] eq '--module'))
    && (($ARGV[1] && lc $ARGV[1] eq '--debug') || ($ARGV[3] && lc $ARGV[3] eq '--debug')) 
    )
{
    $Debug = 1;

    # if no more arguments, then use debug mode for all daemons
    if ( !$ARGV[2] ) {
        $DebugDaemons{All} = 1;
    }

    # otherwise set debug mode specific for named daemons
    else {

        ARGINDEX:
        for my $ArgIndex ( 2 .. 99 ) {

            # stop checking if there are no more arguments
            last ARGINDEX if !$ARGV[$ArgIndex];

            # remember debug mode for each daemon
            $DebugDaemons{ $ARGV[$ArgIndex] } = 1;
        }
    }
}
elsif (
    lc $ARGV[0] eq 'stop'
    && $ARGV[1]
    && lc $ARGV[1] eq '--force'
    )
{
    $ForceStop = 1;
}
elsif ( $ARGV[0] ne '--module' && $ARGV[1] ) {
    print STDERR "Invalid option: $ARGV[1]\n\n";
    PrintUsage();
    exit 0;
}

# check for action
if ( lc $ARGV[0] eq 'start' ) {
    exit 1 if !Start();
    exit 0;
}
elsif ( lc $ARGV[0] eq 'stop' ) {
    exit 1 if !Stop();
    exit 0;
}
elsif ( lc $ARGV[0] eq 'status' ) {
    exit 1 if !Status();
    exit 0;
}
elsif ( lc $ARGV[0] eq '--child' ) {
    exit 1 if !_Run();
    exit 0;
}
elsif ( lc $ARGV[0] eq '--module' ) {
    exit 1 if !_RunModule(
        Module     => $ARGV[1],
        ModuleName => $ARGV[2]
    );
    exit 0;
}
else {
    PrintUsage();
    exit 0;
}

sub PrintUsage {
    my $UsageText = "Usage:\n";
    $UsageText .= " kix.Daemon.pl <ACTION> [--debug] [--force]\n";
    $UsageText .= "\nActions:\n";
    $UsageText .= sprintf " %-30s - %s", 'start', 'Starts the daemon process' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'stop', 'Stops the daemon process' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'status', 'Shows daemon process current state' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'help', 'Shows this help screen' . "\n";
    $UsageText .= "\nNote:\n";
    $UsageText
        .= " In debug mode if a daemon module is specified the debug mode will be activated only for that daemon.\n";
    $UsageText .= " Debug information is stored in the daemon log files localed under: $LogDir\n";
    $UsageText .= "\n kix.Daemon.pl start --debug SchedulerTaskWorker SchedulerCronTaskManager\n\n";
    $UsageText
        .= "\n Forced stop reduces the time the main daemon waits other daemons to stop from normal 30 seconds to 5.\n";
    $UsageText .= "\n kix.Daemon.pl stop --force\n\n";
    print STDOUT "$UsageText\n";

    return 1;
}

sub Start {
    if (!$IsWin32) {
        # create a fork of the current process
        # parent gets the PID of the child
        # child gets PID = 0
        my $DaemonPID = fork;

        # check if fork was not possible
        die "Can not create daemon process: $!" if !defined $DaemonPID || $DaemonPID < 0;
    
        # close parent gracefully
        exit 0 if $DaemonPID;
        
        # run Child
        _Run();
    }
    else {
        my $ChildProcess;
        my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');
        my $Debug = join(' ', keys %DebugDaemons);
        
        Win32::Process::Create(
            $ChildProcess, 
            $ENV{COMSPEC},
            "/c wperl $Home/bin/kix.Daemon.pl --child --debug ".$Debug, 
            0, 
            0x00000008,    # DETACHED_PROCESS
            "."
        );
        my $DaemonPID = $ChildProcess->GetProcessID();
        
        # check if fork was not possible
        die "Can not create daemon process: $!" if !defined $DaemonPID || $DaemonPID < 0;
    
        # close parent gracefully
        return 0;
    }
}

sub Stop {
    my %Param = @_;

    my $RunningDaemonPID = _PIDUnlock();

    if ($RunningDaemonPID) {

        if ($ForceStop) {

            if (!$IsWin32) {
                # send TERM signal to running daemon
                kill 15, $RunningDaemonPID;
            }
            else {
                Win32::Process::KillProcess($RunningDaemonPID, 1);
            }
        }
        else {
            if (!$IsWin32) {
                # send INT signal to running daemon
                kill 2, $RunningDaemonPID;
            }
            else {
                Win32::Process::KillProcess($RunningDaemonPID, 1);
            }
        }
    }

    print STDOUT "Daemon stopped\n";

    return 1;
}

sub Status {
    my %Param = @_;

    if ( -e $PIDFile ) {

        # read existing PID file
        open my $FH, '<', $PIDFile;    ## no critic

        # try to lock the file exclusively
        if ( !flock( $FH, LOCK_EX | LOCK_NB ) ) {

            # if no exclusive lock, daemon might be running, send signal to the PID
            my $RegisteredPID = do { local $/; <$FH> };
            close $FH;

            if ($RegisteredPID) {

                # check if process is running
                my $RunningPID;
                if (!$IsWin32) {
                    $RunningPID = kill 0, $RegisteredPID;
                }
                else {
                    my $ProcessObj;
                    $RunningPID = Win32::Process::Open($ProcessObj, $RegisteredPID, 1);
                }

                if ($RunningPID) {
                    print STDOUT "Daemon running\n";
                    return 1;
                }
            }
        }
        else {

            # if exclusive lock is granted, then it is not running
            close $FH;
        }
    }

    _PIDUnlock();

    print STDOUT "Daemon not running\n";
    return;
}

sub _Run {
    # lock PID
    my $LockSuccess = _PIDLock();

    if ( !$LockSuccess ) {
        print "Daemon already running!\n";
        exit 0;
    }

    # get daemon modules from SysConfig
    my $DaemonModuleConfig = $Kernel::OM->Get('Kernel::Config')->Get('DaemonModules') || {};

    # create daemon module hash
    my %DaemonModules;
    MODULE:
    for my $Module ( sort keys %{$DaemonModuleConfig} ) {

        next MODULE if !$Module;
        next MODULE if !$DaemonModuleConfig->{$Module};
        next MODULE if ref $DaemonModuleConfig->{$Module} ne 'HASH';
        next MODULE if !$DaemonModuleConfig->{$Module}->{Module};

        $DaemonModules{ $DaemonModuleConfig->{$Module}->{Module} } = {
            PID  => 0,
            Name => $Module,
        };
    }

    my $DaemonChecker = 1;
    local $SIG{INT} = sub { $DaemonChecker = 0; };
    local $SIG{TERM} = sub { $DaemonChecker = 0; $DaemonStopWait = 5; };
    local $SIG{CHLD} = "IGNORE";

    print STDOUT "Daemon started\n";
    if ($Debug) {
        print STDOUT "\nDebug information is stored in the daemon log files localed under: $LogDir\n\n";
    }

    while ($DaemonChecker) {

        MODULE:
        for my $Module ( sort keys %DaemonModules ) {

            next MODULE if !$Module;

            # check if daemon is still alive
            my $RunningPID;
            if (!$IsWin32) {
                $RunningPID = kill 0, $DaemonModules{$Module}->{PID};
            }
            else {
                my $ProcessObj;
                $RunningPID = Win32::Process::Open($ProcessObj, $DaemonModules{$Module}->{PID}, 1);
            }
            
            if ( $DaemonModules{$Module}->{PID} && !$RunningPID ) {
                $DaemonModules{$Module}->{PID} = 0;
            }

            next MODULE if $DaemonModules{$Module}->{PID};

            my $ChildPID;

            if (!$IsWin32) {
                # fork daemon process
                $ChildPID = fork;
            }
            else {
                my $ChildProcess;
                my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');
                my $Debug = join(' ', keys %DebugDaemons);
                                
                Win32::Process::Create(
                    $ChildProcess, 
                    $ENV{COMSPEC},
                    "/c wperl $Home/bin/kix.Daemon.pl --module \"$Module\" \"$DaemonModules{$Module}->{Name}\" --debug ".$Debug, 
                    0, 
                    0x00000008,    # DETACHED_PROCESS
                    "."
                );
                $ChildPID = $ChildProcess->GetProcessID();
            }

            if ( !$ChildPID ) {

                exit _RunModule(
                    Module     => $Module,
                    ModuleName => $DaemonModules{$Module}->{Name}
                );
            }
            else {

                if ($Debug) {
                    print STDOUT "Registered Daemon $Module with PID $ChildPID\n";
                }

                $DaemonModules{$Module}->{PID} = $ChildPID;
            }
        }

        # sleep 0.1 seconds to protect the system of a 100% CPU usage if one daemon
        # module is damaged and produces hard errors
        sleep 0.1;
        
        # in windows sleep even more, otherwise the CPU load will be too high
        if ($IsWin32) {
            sleep 5;
        }
    }

    # send all daemon processes a stop signal
    MODULE:
    for my $Module ( sort keys %DaemonModules ) {

        next MODULE if !$Module;
        next MODULE if !$DaemonModules{$Module}->{PID};

        if ($Debug) {
            print STDOUT "Send stop signal to $Module with PID $DaemonModules{$Module}->{PID}\n";
        }

        if (!$IsWin32) {
            kill 2, $DaemonModules{$Module}->{PID};
        }
        else {
            Win32::Process::KillProcess($DaemonModules{$Module}->{PID}, 1);
        }
    }

    # wait for active daemon processes to stop (typically 30 secs, or just 5 if forced)
    WAITTIME:
    for my $WaitTime ( 1 .. $DaemonStopWait ) {

        my $ProcessesStillRunning;
        MODULE:
        for my $Module ( sort keys %DaemonModules ) {

            next MODULE if !$Module;
            next MODULE if !$DaemonModules{$Module}->{PID};

            # check if PID is still alive
            my $RunningPID;
            if (!$IsWin32) {
                $RunningPID = kill 0, $DaemonModules{$Module}->{PID};
            }
            else {
                my $ProcessObj;
                $RunningPID = Win32::Process::Open($ProcessObj, $DaemonModules{$Module}->{PID}, 1);
            }
            
            if ( !$RunningPID ) {

                # remove daemon pid from list
                $DaemonModules{$Module}->{PID} = 0;
            }
            else {

                $ProcessesStillRunning = 1;

                if ($Debug) {
                    print STDOUT "Waiting to stop $Module with PID $DaemonModules{$Module}->{PID}\n";
                }
            }
        }

        last WAITTIME if !$ProcessesStillRunning;

        sleep 1;
    }

    # hard kill of all children witch are not stopped after 30 seconds
    MODULE:
    for my $Module ( sort keys %DaemonModules ) {

        next MODULE if !$Module;
        next MODULE if !$DaemonModules{$Module}->{PID};

        print STDOUT "Killing $Module with PID $DaemonModules{$Module}->{PID}\n";

        if (!$IsWin32) {
           kill 9, $DaemonModules{$Module};
        }
        else {
            Win32::Process::KillProcess($DaemonModules{$Module}->{PID}, 1);
        }
    }

    # remove current log files without content
    _LogFilesCleanup();

    return 0;
}

sub _RunModule {
    my (%Param) = @_;

    my $ChildRun = 1;
    local $SIG{INT}  = sub { $ChildRun = 0; };
    local $SIG{TERM} = sub { $ChildRun = 0; };
    local $SIG{CHLD} = "IGNORE";

    # define the ZZZ files
    my @ZZZFiles = (
        'ZZZAAuto.pm',
        'ZZZAuto.pm',
    );

    # reload the ZZZ files (mod_perl workaround)
    for my $ZZZFile (@ZZZFiles) {

        PREFIX:
        for my $Prefix (@INC) {
            my $File = $Prefix . '/Kernel/Config/Files/' . $ZZZFile;
            next PREFIX if !-f $File;
            do $File;
            last PREFIX;
        }
    }

    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::System::Log' => {
            LogPrefix => "kix.Daemon.pl - Daemon $Param{Module}",
        },
    );

    # disable in memory cache because many processes runs at the same time
    $Kernel::OM->Get('Kernel::System::Cache')->Configure(
        CacheInMemory  => 0,
        CacheInBackend => 1,
    );

    # set daemon log files
    _LogFilesSet(
        Module => $Param{ModuleName}
    );
    
    my $DaemonObject;
    LOOP:
    while ($ChildRun) {

        # create daemon object if not exists
        eval {

        
            if (
                !$DaemonObject
                && ( $DebugDaemons{All} || $DebugDaemons{ $Param{ModuleName} } )
               )
            {
                $Kernel::OM->ObjectParamAdd(
                    $Param{Module} => {
                        Debug => 1,
                    },
                );
            }

            $DaemonObject ||= $Kernel::OM->Get($Param{Module});
        };

        # wait 10 seconds if creation of object is not possible
        if ( !$DaemonObject ) {
            sleep 10;
            last LOOP;
        }

        METHOD:
        for my $Method ( 'PreRun', 'Run', 'PostRun' ) {
            last LOOP if !eval { $DaemonObject->$Method() };
        }
        
        # in Win32 exit this loop to restart the whole process
        # otherwise zombies will remain when parent gets stopped
        last LOOP if ($IsWin32);
    }
    
    return 0;
}

sub _PIDLock {

    # check pid directory
    if ( !-e $PIDDir ) {

        File::Path::mkpath( $PIDDir, 0, 0770 );    ## no critic

        if ( !-e $PIDDir ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Can't create directory '$PIDDir': $!",
            );

            exit 1;
        }
    }
    if ( !-w $PIDDir ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Don't have write permissions in directory '$PIDDir': $!",
        );

        exit 1;
    }

    if ( -e $PIDFile ) {

        # read existing PID file
        open my $FH, '<', $PIDFile;    ## no critic

        # try to get a exclusive of the pid file, if fails daemon is already running
        if ( !flock( $FH, LOCK_EX | LOCK_NB ) ) {
            close $FH;
            return;
        }

        my $RegisteredPID = do { local $/; <$FH> };
        close $FH;

        if ($RegisteredPID) {

            return 1 if $RegisteredPID eq $$;

            # check if another process is running
            my $AnotherRunningPID = kill 0, $RegisteredPID;

            return if $AnotherRunningPID;
        }
    }

    # create new PID file (set exclusive lock while writing the PIDFile)
    open my $FH, '>', $PIDFile || die "Can not create PID file: $PIDFile\n";    ## no critic
    return if !flock( $FH, LOCK_EX | LOCK_NB );
    print $FH $$;
    close $FH;

    # keep PIDFile shared locked forever
    open $PIDFH, '<', $PIDFile || die "Can not create PID file: $PIDFile\n";    ## no critic
    return if !flock( $PIDFH, LOCK_SH | LOCK_NB );

    return 1;
}

sub _PIDUnlock {

    return if !-e $PIDFile;

    # read existing PID file
    open my $FH, '<', $PIDFile;                                                 ## no critic

    # wait if PID is exclusively locked (and do a shared lock for reading)
    flock $FH, LOCK_SH;
    my $RegisteredPID = do { local $/; <$FH> };
    close $FH;

    unlink $PIDFile;

    return $RegisteredPID;
}

sub _LogFilesSet {
    my %Param = @_;

    # define log file names
    my $FileStdOut = "$LogDir/$Param{Module}OUT";
    my $FileStdErr = "$LogDir/$Param{Module}ERR";

    my $SystemTime = $Kernel::OM->Get('Kernel::System::Time')->SystemTime();

    # backup old log files
    use File::Copy qw(move);
    if ( -e "$FileStdOut.log" ) {
        move( "$FileStdOut.log", "$FileStdOut-$SystemTime.log" );
    }
    if ( -e "$FileStdErr.log" ) {
        move( "$FileStdErr.log", "$FileStdErr-$SystemTime.log" );
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $RedirectSTDOUT = $ConfigObject->Get('Daemon::Log::STDOUT') || 0;
    my $RedirectSTDERR = $ConfigObject->Get('Daemon::Log::STDERR') || 0;

    # redirect STDOUT and STDERR
    if ($RedirectSTDOUT) {
        open STDOUT, '>>', "$FileStdOut.log";
    }
    if ($RedirectSTDERR) {
        open STDERR, '>>', "$FileStdErr.log";
    }

    # remove not needed log files
    my $DaysToKeep = $ConfigObject->Get('Daemon::Log::DaysToKeep') || 1;
    my $DaysToKeepTime = $SystemTime - $DaysToKeep * 24 * 60 * 60;

    my @LogFiles = glob "$LogDir/*.log";

    LOGFILE:
    for my $LogFile (@LogFiles) {

        # skip if is not a backup file
        next LOGFILE if ( $LogFile !~ m{(?: .* /)* $Param{Module} (?: OUT|ERR ) - (\d+) \.log}igmx );

        # do not delete files during keep period if they have content
        next LOGFILE if ( ( $1 > $DaysToKeepTime ) && -s $LogFile );

        # delete file
        if ( !unlink $LogFile ) {

            # log old backup file cannot be deleted
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Daemon: $Param{Module} could not delete old log file $LogFile! $!",
            );
        }
    }

    return 1;
}

sub _LogFilesCleanup {
    my %Param = @_;

    my @LogFiles = glob "$LogDir/*.log";

    LOGFILE:
    for my $LogFile (@LogFiles) {

        # skip if is not a backup file
        next LOGFILE if ( $LogFile !~ m{ (?: OUT|ERR ) (?: -\d+)* \.log}igmx );

        # do not delete files if they have content
        next LOGFILE if -s $LogFile;

        # delete file
        if ( !unlink $LogFile ) {

            # log old backup file cannot be deleted
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Daemon: could not delete empty log file $LogFile! $!",
            );
        }
    }

    return 1;
}

exit 0;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
