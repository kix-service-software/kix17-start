# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# Copyright (C) 2021-2023 Znuny GmbH, https://znuny.org/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with patches licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::System::Log;

use strict;
use warnings;

use Carp ();

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
);

## no critic qw(BuiltinFunctions::ProhibitStringyEval)

=head1 NAME

Kernel::System::Log - global log interface

=head1 SYNOPSIS

All log functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a log object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::System::Log' => {
            LogPrefix => 'InstallScriptX',  # not required, but highly recommend
        },
    );
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

=cut

my %LogLevel = (
    error  => 16,
    notice => 8,
    info   => 4,
    debug  => 2,
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    if ( !$Kernel::OM ) {
        Carp::confess('$Kernel::OM is not defined, please initialize your object manager');
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    $Self->{ProductVersion} = $ConfigObject->Get('Product') . ' ';
    $Self->{ProductVersion} .= $ConfigObject->Get('Version');

    # get system id
    my $SystemID = $ConfigObject->Get('SystemID');

    # check log prefix
    $Self->{LogPrefix} = $Param{LogPrefix} || '?LogPrefix?';
    $Self->{LogPrefix} .= '-' . $SystemID;

    # configured log level (debug by default)
    $Self->{MinimumLevel}    = lc( $ConfigObject->Get('MinimumLogLevel') ) || 'debug';
    $Self->{MinimumLevelNum} = $LogLevel{ $Self->{MinimumLevel} };

    # load log backend
    my $GenericModule = $ConfigObject->Get('LogModule') || 'Kernel::System::Log::SysLog';
    if ( !eval "require $GenericModule" ) {
        die "Can't load log backend module $GenericModule! $@";
    }

    # create backend handle
    $Self->{Backend} = $GenericModule->new(
        %Param,
    );

    return $Self if ( !eval "require IPC::SysV" );

    # create the IPC options
    $Self->{IPCKey}  = '444423' . $SystemID;       # This name is used to identify the shared memory segment
    $Self->{IPCSize} = $ConfigObject->Get('LogSystemCacheSize') || 32 * 1024;

    # init session data mem
    if ( !eval { $Self->{IPCSHMKey} = shmget( $Self->{IPCKey}, $Self->{IPCSize}, oct(1777) ) } ) {

        # If direct creation fails, try more gently, allocate a small segment first and the reset/resize it
        $Self->{IPCSHMKey} = shmget( $Self->{IPCKey}, 1, oct(1777) );
        if (
            !defined( $Self->{IPCSHMKey} )
            || !shmctl( $Self->{IPCSHMKey}, 0, 0 )
        ) {
            $Self->Log(
                Priority => 'notice',
                Message  => "Can't remove shm for log: $!",
            );

            # Continue without IPC
            return $Self;
        }

        # Re-initialize SHM segment
        $Self->{IPCSHMKey} = shmget( $Self->{IPCKey}, $Self->{IPCSize}, oct(1777) );
    }

    # Continue without IPC
    return $Self if !$Self->{IPCSHMKey};

    # Only flag IPC as active if everything worked well
    $Self->{IPC} = 1;

    return $Self;
}

=item Log()

log something. log priorities are 'debug', 'info', 'notice' and 'error'.

These are mapped to the SysLog priorities. Please use the appropriate priority level:

=over

=item debug

Debug-level messages; info useful for debugging the application, not useful during operations.

=item info

Informational messages; normal operational messages - may be used for reporting etc, no action required.

=item notice

Normal but significant condition; events that are unusual but not error conditions, no immediate action required.

=item error

Error conditions. Non-urgent failures, should be relayed to developers or admins, each item must be resolved.

=back

See for more info L<http://en.wikipedia.org/wiki/Syslog#Severity_levels>

    $LogObject->Log(
        Priority => 'error',
        Message  => "Need something!",
    );

=cut

sub Log {
    my ( $Self, %Param ) = @_;

    my $Priority    = lc( $Param{Priority} ) || 'debug';
    my $PriorityNum = $LogLevel{$Priority}   || $LogLevel{debug};

    return 1 if $PriorityNum < $Self->{MinimumLevelNum};

    my $Message = $Param{MSG}    || $Param{Message} || '???';
    my $Caller  = $Param{Caller} || 0;

    # returns the context of the current subroutine and sub-subroutine!
    my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller( $Caller + 0 );
    my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller( $Caller + 1 );

    $Subroutine2 ||= $0;

    # log backend
    $Self->{Backend}->Log(
        Priority  => $Priority,
        Message   => $Message,
        LogPrefix => $Self->{LogPrefix},
        Module    => $Subroutine2,
        Line      => $Line1,
    );

    # if error, write it to STDERR
    if ( $Priority =~ /^error/i ) {

        my $Error = sprintf "ERROR: $Self->{LogPrefix} Perl: %vd OS: $^O Time: "
            . localtime() . "\n\n", $^V;

        $Error .= " Message: $Message\n\n";

        if ( %ENV && ( $ENV{REMOTE_ADDR} || $ENV{REQUEST_URI} ) ) {

            my $RemoteAddress = $ENV{REMOTE_ADDR} || '-';
            my $RequestURI    = $ENV{REQUEST_URI} || '-';

            $Error .= " RemoteAddress: $RemoteAddress\n";
            $Error .= " RequestURI: $RequestURI\n\n";
        }

        $Error .= " Traceback ($$): \n";

        COUNT:
        for ( my $Count = 0; $Count < 30; $Count++ ) {

            my ( $TracePackage1, $TraceFilename1, $TraceLine1, $TraceSubroutine1 ) = caller( $Caller + $Count );

            last COUNT if ( !$TraceLine1 );

            my ( $TracePackage2, $TraceFilename2, $TraceLine2, $TraceSubroutine2 ) = caller( $Caller + 1 + $Count );

            # if there is no caller module use the file name
            $TraceSubroutine2 ||= $0;

            # print line if upper caller module exists
            my $VersionString = '';

            eval { $VersionString = $TracePackage1->VERSION || ''; };

            # version is present
            if ($VersionString) {
                $VersionString = ' (v' . $VersionString . ')';
            }

            $Error .= "   Module: $TraceSubroutine2$VersionString Line: $TraceLine1\n";

            last COUNT if !$TraceLine2;
        }

        $Error .= "\n";
        print STDERR $Error;

        # store data (for the frontend)
        $Self->{error}->{Message}   = $Message;
        $Self->{error}->{Traceback} = $Error;
    }

    # remember to info and notice messages
    elsif ( lc $Priority eq 'info' || lc $Priority eq 'notice' ) {
        $Self->{ lc $Priority }->{Message} = $Message;
    }

    # write shm cache log
    if ( lc $Priority ne 'debug' && $Self->{IPC} ) {

        $Priority = lc $Priority;

        my $Data   = localtime() . ";;$Priority;;$Self->{LogPrefix};;$Message\n";
        my $String = $Self->GetLog();

### Patch licensed under the GPL-3.0, Copyright (C) 2021-2023 Znuny GmbH, https://znuny.org/ ###
#        shmwrite( $Self->{IPCSHMKey}, $Data . $String, 0, $Self->{IPCSize} ) || die $!;
        # Fix for issue #286 (GitHub) / #328 (internal): Encode output.
        my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

        my $Output = $Data . $String;
        $EncodeObject->EncodeOutput( \$Output );

        shmwrite( $Self->{IPCSHMKey}, $Output, 0, $Self->{IPCSize} ) || die $!;
### EO Patch licensed under the GPL-3.0, Copyright (C) 2021-2023 Znuny GmbH, https://znuny.org/ ###
    }

    return 1;
}

=item GetLogEntry()

to get the last log info back

    my $Message = $LogObject->GetLogEntry(
        Type => 'error', # error|info|notice
        What => 'Message', # Message|Traceback
    );

=cut

sub GetLogEntry {
    my ( $Self, %Param ) = @_;

    return $Self->{ lc $Param{Type} }->{ $Param{What} } || '';
}

=item GetLog()

to get the tmp log data (from shared memory - ipc) in csv form

    my $CSVLog = $LogObject->GetLog();

=cut

sub GetLog {
    my ( $Self, %Param ) = @_;

    my $String = '';
    if ( $Self->{IPC} ) {
        shmread( $Self->{IPCSHMKey}, $String, 0, $Self->{IPCSize} ) || die "$!";
    }

    # Remove \0 bytes that shmwrite adds for padding.
    $String =~ s{\0}{}smxg;

    # encode the string
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$String );

    return $String;
}

=item CleanUp()

to clean up tmp log data from shared memory (ipc)

    $LogObject->CleanUp();

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    return 1 if !$Self->{IPC};

    shmwrite( $Self->{IPCSHMKey}, '', 0, $Self->{IPCSize} ) || die $!;

    return 1;
}

=item Dumper()

dump a perl variable to log

    $LogObject->Dumper(@Array);

    or

    $LogObject->Dumper(%Hash);

=cut

sub Dumper {
    my ( $Self, @Data ) = @_;

    require Data::Dumper;

    # returns the context of the current subroutine and sub-subroutine!
    my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller(0);
    my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller(1);

    $Subroutine2 ||= $0;

    # log backend
    $Self->{Backend}->Log(
        Priority  => 'debug',
        Message   => substr( Data::Dumper::Dumper(@Data), 0, 600600600 ),
        LogPrefix => $Self->{LogPrefix},
        Module    => $Subroutine2,
        Line      => $Line1,
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
