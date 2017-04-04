# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::Database::SQLBenchmark;

use strict;
use warnings;
use POSIX;

our $IsWin32 = 0; 
if ( $^O eq 'MSWin32' ) {
    eval { 
        require Win32; 
        require Win32::Process; 
    } or last;
    $IsWin32 = 1;
}

use Kernel::System::DB;
use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Time',
);

our %Jobs = (
    INSERT => \&Kernel::System::Console::Command::Dev::Tools::Database::SQLBenchmark::_SQLInsert,
    UPDATE => \&Kernel::System::Console::Command::Dev::Tools::Database::SQLBenchmark::_SQLUpdate,
    SELECT => \&Kernel::System::Console::Command::Dev::Tools::Database::SQLBenchmark::_SQLSelect,
    DELETE => \&Kernel::System::Console::Command::Dev::Tools::Database::SQLBenchmark::_SQLDelete,
); 

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Executes SQL statements to test the performance of your database.');
    $Self->AddOption(
        Name        => 'records',
        Description => "Number of records to be inserted, selected and deleted. Default: 10000.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'processes',
        Description => "Number of parallel processes to use. Default: 1",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'job',
        Description => "The job to be done (INSERT, UPDATE, SELECT, DELETE). Needed for the job process in Win32.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*?/smx,
        Invisible   => 1,
    );
    $Self->AddOption(
        Name        => 'process-id',
        Description => "The ID of the job process. Needed for the job process in Win32.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
        Invisible   => 1,
    );
    $Self->AdditionalHelp("<red>Please don't use this command in production environments.</red>\n");

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Records   = $Self->GetOption('records');
    my $ProcessID = $Self->GetOption('process-id');
    my $Processes = $Self->GetOption('processes');
 
    if (!$ProcessID) {

        print "\nRunning Benchmark...\n\n";

        print "Statement  Records Time[s] Records/s Time[ms]/Record\n";
        print "--------- -------- ------- --------- ---------------\n";

        $Self->_Benchmark(
            Records   => $Records || 10000,
        Processes => $Processes || 1,
        );
    }
    else {
        my $Job   = $Self->GetOption('job');

        $Jobs{$Job}->(
            $Self, 
            Records => $Records,
        Process => $ProcessID,
        );
    }

    exit 1;
}

sub _Benchmark {
    my ( $Self, %Param ) = @_;
    my $TimeTotal;

    my $TotalRecords = $Param{Records} * $Param{Processes};

    $Self->{TimeObject} = $Kernel::OM->Get('Kernel::System::Time');
        $Self->{DBObject}   = Kernel::System::DB->new( %{$Self} );

    # create the table
    my $TableCreate = '
        <TableCreate Name="sql_benchmark">
            <Column Name="name_a" Required="true" Size="60" Type="VARCHAR"></Column>
            <Column Name="name_b" Required="true" Size="60" Type="VARCHAR"></Column>
            <Index Name="idx_sql_benchmark_name_a">
                <IndexColumn Name="name_a">
                </IndexColumn>
            </Index>
        </TableCreate>';

    my @XMLArray = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
        String => $TableCreate,
    );
    my @SQL = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessor(
        Database => \@XMLArray,
    );

    foreach my $SQL (@SQL) {
        $Self->{DBObject}->Do(
            SQL => $SQL,
        );
    }

        foreach my $Job (qw(INSERT UPDATE SELECT DELETE)) {
            printf("%-9s %8s ", $Job, $TotalRecords);
            $| = 1;

            my $TimeTaken = 0;
            if (!$IsWin32) {
                $TimeTaken = $Self->_DoJob( 
                     Job       => $Job,
                     Records   => $Param{Records},
                     Processes => $Param{Processes},
                );
            }
            else {
                $TimeTaken = $Self->_DoJobWin32( 
                     Job       => $Job,
                     Records   => $Param{Records},
                 Processes => $Param{Processes},
            );
            }

            $TimeTotal += $TimeTaken;
            printf("%7i %9i %15.2f\n", $TimeTaken, ceil($TotalRecords/$TimeTaken), $TimeTaken*1000/$TotalRecords);
        }

    # drop the table
    $Self->{DBObject}->Do(
        SQL => 'DROP TABLE sql_benchmark',
    );

    print "\nTotal Time: $TimeTotal s\n";

    return 1;
}

sub _DoJob {
    my ( $Self, %Param ) = @_;
    my @Children;
    my $TimeStart = $Self->{TimeObject}->SystemTime();

    for my $Process ( 1 .. $Param{Processes} ) {
    my $PID = fork();

    if (!$PID) {
            # child process - do your job
            $Jobs{$Param{Job}}->(
                $Self,
                Process => $Process,
                Records => $Param{Records}
            );

            exit 0;
        }
        else {
            push(@Children, $PID);
        }
    }
 
    while (@Children){ 
        waitpid(shift @Children, 0); 
    }

    return $Self->{TimeObject}->SystemTime() - $TimeStart;
}

sub _DoJobWin32 {
    my ( $Self, %Param ) = @_;
    my @Children;
    my $TimeStart = $Self->{TimeObject}->SystemTime();
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    for my $Process ( 1 .. $Param{Processes} ) {
        my $Child;
        Win32::Process::Create(
            $Child, 
            $ENV{COMSPEC},
            "/c $Home/bin/kix.Console.pl Dev::Tools::Database::SQLBenchmark --allow-root --job $Param{Job} --process-id $Process --records $Param{Records}", 
            0, 0, "."
        );
        push(@Children, $Child);
    }
 
    while (@Children){ 
        my $ExitCode;
        $Children[0]->GetExitCode($ExitCode);
        if ($ExitCode != Win32::Process::STILL_ACTIVE()) {
            shift @Children;
       }
        sleep(1);
    }

    return $Self->{TimeObject}->SystemTime() - $TimeStart;
}

sub _SQLInsert {
    my ( $Self, %Param ) = @_;

    my $DBObject = Kernel::System::DB->new( %{$Self} );

    for my $Count ( 1 .. $Param{Records} ) {
    
        my $Value1 = "aaa$Count-$Param{Process}";
        my $Value2 = int rand 1000000;

        # insert data
        $DBObject->Do(
            SQL => 'INSERT INTO sql_benchmark (name_a, name_b) values (?, ?)',
            Bind => [ \$Value1, \$Value2, ],
        );

    }

    return 1;
}

sub _SQLUpdate {
    my ( $Self, %Param ) = @_;

    my $DBObject = Kernel::System::DB->new( %{$Self} );

    for my $Count ( 1 .. $Param{Records} ) {

        my $ValueOld = "aaa$Count-$Param{Process}";
        my $Value1   = "bbb$Count-$Param{Process}";
        my $Value2   = int rand 1000000;

        # update data
        $DBObject->Do(
            SQL => 'UPDATE sql_benchmark SET name_a = ?, name_b = ? WHERE name_a = ?',
            Bind => [ \$Value1, \$Value2, \$ValueOld ],
        );
    }

    return 1;
}

sub _SQLSelect {
    my ( $Self, %Param ) = @_;

    my $DBObject = Kernel::System::DB->new( %{$Self} );

    for my $Count ( 1 .. $Param{Records} ) {

    my $Value = "bbb$Count-$Param{Process}";

        # select the data
        $DBObject->Prepare(
            SQL  => "SELECT name_a, name_b FROM sql_benchmark WHERE name_a = ?",
            Bind => [ \$Value ],
        );

        # fetch the data
        while ( my @Row = $DBObject->FetchrowArray() ) {

            # do nothing
        }
    }

    return 1;
}

sub _SQLDelete {
    my ( $Self, %Param ) = @_;

    my $DBObject = Kernel::System::DB->new( %{$Self} );

    for my $Count ( 1 .. $Param{Records} ) {

        my $Value = "bbb$Count-$Param{Process}";

        # delete data
        $DBObject->Do(
            SQL  => 'DELETE FROM sql_benchmark WHERE name_a = ?',
            Bind => [ \$Value ],
        );
    }

    return 1;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
