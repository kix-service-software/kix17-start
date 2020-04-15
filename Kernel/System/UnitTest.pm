# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest;

use strict;
use warnings;

use vars qw(@ISA);

use Kernel::System::UnitTest::Check;
use Kernel::System::UnitTest::Utils;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

## no critic qw(BuiltinFunctions::ProhibitStringyEval)

=head1 NAME

Kernel::System::UnitTest - global test interface

=head1 SYNOPSIS

Functions to run existing unit tests, as well as
functions to define test cases.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create unit test object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $UnitTestObject = $Kernel::OM->Get('Kernel::System::UnitTest');

=cut
sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    @ISA = qw(
        Kernel::System::UnitTest::Check
        Kernel::System::UnitTest::Utils
    );

    return $Self;
}

=item Run()

Run all tests located in scripts/test/*.t and print result to stdout.

    $UnitTestObject->Run(
        OutputDirectory => '/tmp/result',  # directory to write results to, without ending slash
        Silent          => 1,              # optional, (0|1), silents output to STDOUT
        TestDirectory   => 'Cache',        # optional, control which directory to select
        TestFilter      => 'Configure',    # optional, control which tests to select
    );

=cut
sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(OutputDirectory) ) {
        if ( !$Param{ $Needed } ) {
            print STDERR "Need $Needed!\n";
            return;
        }
    }

    # get needed objects
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    # init params
    $Self->{'OutputDirectory'} = $Param{'OutputDirectory'};
    $Self->{'Silent'}          = $Param{'Silent'};

    # init unit test
    $Self->_InitUnitTest();

    # get test files
    my @Files = $Self->_GetTestFiles( %Param );

    # process test files
    FILE:
    for my $File (@Files) {
        # init data for test file
        $Self->_TestFileStart(
            File => $File,
        );

        # read file
        my $UnitTestFile = $MainObject->FileRead(
            Location => $File
        );

        # check for content
        if ( !$UnitTestFile ) {
            # init data for testcase
            $Self->TestCaseStart(
                TestCase => 'Testfile',
            );

            # add test step with message that file could not be read
            $Self->_AddTestStep(
                TestName  => 'File Read',
                Success   => 0,
                Broken    => 1,
                Message   => "Could not read $File",
                StartTime => $Self->GetMilliTimeStamp(),
            );

            # output data for testcase
            $Self->TestCaseStop();

            # output data for test file
            $Self->_TestFileStop();
            next FILE;
        }

        # create a new scope to be sure to destroy local object of the test files
        {
            # Make sure every UT uses its own clean environment.
            local $Kernel::OM = Kernel::System::ObjectManager->new(
                'Kernel::System::Log' => {
                    LogPrefix => 'KIX-UnitTest-' . $Self->{'TestFile'}->{'Data'}->{'uuid'},
                },
            );

            # Provide $Self as 'Kernel::System::UnitTest' for convenience.
            $Kernel::OM->ObjectInstanceRegister(
                Package      => 'Kernel::System::UnitTest',
                Object       => $Self,
                Dependencies => [],
            );

            # HERE the actual tests are run
            if ( !eval( ${$UnitTestFile} ) ) {
                if ($@) {
                    # if no testcase is active, create a new testcase
                    if ( !$Self->{'TestCase'}->{'Active'} ) {
                        # init data for testcase
                        $Self->TestCaseStart(
                            TestCase => 'Testfile',
                        );
                    }

                    # add test step with message that file could not be read
                    $Self->_AddTestStep(
                        TestName  => 'File Eval',
                        Success   => 0,
                        Broken    => 1,
                        Message   => "Error in $File",
                        Trace     => "$@",
                        StartTime => $Self->GetMilliTimeStamp(),
                    );

                    # output data for testcase
                    $Self->TestCaseStop();

                    # output data for test file
                    $Self->_TestFileStop();
                    next FILE;
                }
                else {
                    # if no testcase is active, create a new testcase
                    if ( !$Self->{'TestCase'}->{'Active'} ) {
                        # init data for testcase
                        $Self->TestCaseStart(
                            TestCase => 'Testfile',
                        );
                    }

                    # add test step with message that file could not be read
                    $Self->_AddTestStep(
                        TestName  => 'File Returncode',
                        Success   => 0,
                        Broken    => 1,
                        Message   => "$File did not return a true value",
                        StartTime => $Self->GetMilliTimeStamp(),
                    );

                    # output data for testcase
                    $Self->TestCaseStop();

                    # output data for test file
                    $Self->_TestFileStop();
                    next FILE;
                }
            }
        }

        # output data for test file
        $Self->_TestFileStop();
    }

    # output summary
    $Self->_OutputSummary();

    return $Self->{'ReturnCode'};
}

=item TestCaseStart()

Prepare testcase data

    $UnitTestObject->TestCaseStart(
        TestCase    => 'TestCase',     # name of testcase
        Description => 'Description',  # optional, description of testcase
        Feature     => 'Feature',      # optional, feature label
        Story       => 'Story',        # optional, story label
        Package     => 'Package',      # optional, package label
        Suite       => 'Suite',        # optional, suite label
        TestClass   => 'TestClass'     # optional, testClass label
    );

=cut
sub TestCaseStart {
    my ( $Self, %Param ) = @_;

    # check if test case is still active
    if ( $Self->{'TestCase'}->{'Active'} ) {
        $Self->TestCaseStop();
    }

    # get needed objects
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # increment testcase counter
    $Self->{'Count'}->{'TestCase'} += 1;

    # set testcase active
    $Self->{'TestCase'}->{'Active'} = 1;

    # reset test counter
    $Self->{'TestCase'}->{'Count'}->{'Test'}    = 0;
    $Self->{'TestCase'}->{'Count'}->{'Success'} = 0;
    $Self->{'TestCase'}->{'Count'}->{'Fail'}    = 0;
    $Self->{'TestCase'}->{'Count'}->{'Skip'}    = 0;

    # reset broken flag
    $Self->{'TestCase'}->{'Broken'} = 0;

    # reset plan steps
    $Self->{'TestCase'}->{'PlanSteps'} = {};

    # generate uuid
    $Self->{'TestCase'}->{'Data'}->{'uuid'} = $Self->GetRandomNumber();

    # add child to test file
    push(@{ $Self->{'TestFile'}->{'Data'}->{'children'} }, $Self->{'TestCase'}->{'Data'}->{'uuid'});

    # set name
    $Self->{'TestCase'}->{'Data'}->{'name'}     = $Param{'TestCase'} || '->>No Name!<<-';
    $Self->{'TestCase'}->{'Data'}->{'fullName'} = $Param{'TestCase'} || '->>No Name!<<-';

    # set description
    $Self->{'TestCase'}->{'Data'}->{'description'} = $Param{'Description'} || '';

    # init scalar variables
    $Self->{'TestCase'}->{'Data'}->{'status'} = 'passed';
    $Self->{'TestCase'}->{'Data'}->{'stage'}  = 'finished';

    # init array variables
    $Self->{'TestCase'}->{'Data'}->{'attachments'} = [];
    $Self->{'TestCase'}->{'Data'}->{'links'}       = [];
    $Self->{'TestCase'}->{'Data'}->{'parameters'}  = [];
    $Self->{'TestCase'}->{'Data'}->{'steps'}       = [];

    # init statusDetails
    $Self->{'TestCase'}->{'Data'}->{'statusDetails'} = {
        'known' => $JSONObject->False(),
        'muted' => $JSONObject->False(),
        'flaky' => $JSONObject->False()
    };

    # init labels
    $Self->{'TestCase'}->{'Data'}->{'labels'} = [];
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'feature',
        'value' => $Param{'Feature'} || $Self->{'TestFile'}->{'Data'}->{'name'}
    });
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'story',
        'value' => $Param{'Story'} || $Param{'TestCase'}
    });
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'tag',
        'value' => 'UnitTest'
    });
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'package',
        'value' => $Param{'Package'} || $Self->{'TestFile'}->{'Data'}->{'name'}
    });
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'suite',
        'value' => $Param{'Suite'} || $Self->{'TestFile'}->{'Data'}->{'name'}
    });
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'testClass',
        'value' => $Param{'TestClass'} || $Param{'TestCase'}
    });
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'framework',
        'value' => 'KIX17'
    });
    push(@{ $Self->{'TestCase'}->{'Data'}->{'labels'} }, {
        'name'  => 'language',
        'value' => 'Perl'
    });

    # init stop time
    $Self->{'TestCase'}->{'Data'}->{'stop'} = '';

    # init start time
    $Self->{'TestCase'}->{'Data'}->{'start'} = $Self->GetMilliTimeStamp();

    return;
}

=item TestCaseStop()

Output testcase data

    $Self->TestCaseStop();

=cut
sub TestCaseStop {
    my ( $Self, %Param ) = @_;

    # check active state
    return if ( !$Self->{'TestCase'}->{'Active'} );

    # get needed objects
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    # get stop time
    $Self->{'TestCase'}->{'Data'}->{'stop'} = $Self->GetMilliTimeStamp();

    # handle planned steps
    $Self->_HandlePlannedTestSteps();

    # set testcase inactive
    $Self->{'TestCase'}->{'Active'} = 0;

    # calc duration
    my $Duration = $Self->{'TestCase'}->{'Data'}->{'stop'} - $Self->{'TestCase'}->{'Data'}->{'start'};

    # prepare file path and name
    my $Location = $Self->{'OutputDirectory'} . '/' . $Self->{'TestCase'}->{'Data'}->{'uuid'} . '-result.json';

    # encode json string
    my $JSONString = $JSONObject->Encode(
        Data     => $Self->{'TestCase'}->{'Data'},
        SortKeys => 1,
    );

    # write json to file
    my $FileLocation = $MainObject->FileWrite(
        Location   => $Location,
        Content    => \$JSONString,
        Mode       => 'utf8',
        Type       => 'Local',
        Permission => '644',
    );

    # output summary to console
    if ( !$Self->{'Silent'} ) {
        my $Summary = sprintf(
            "File: %s, Testcase: %s, Tests: %d, Success: %d, Fail: %d, Skip: %d, Duration: %dms\n",
            $Self->{'TestFile'}->{'Data'}->{'name'},
            $Self->{'TestCase'}->{'Data'}->{'name'},
            $Self->{'TestCase'}->{'Count'}->{'Test'},
            $Self->{'TestCase'}->{'Count'}->{'Success'},
            $Self->{'TestCase'}->{'Count'}->{'Fail'},
            $Self->{'TestCase'}->{'Count'}->{'Skip'},
            $Duration
        );
        print STDOUT $Summary;
    }

    return;
}

=begin Internal:

=cut

=item _GetTestFiles()

Provides array of test files to run

    my @TestFiles = $Self->_GetTestFiles(
        TestDirectory => 'Cache',         # optional, control which sub directory to lookup
        TestFilter    => 'Configure',     # optional, control which test file to select. glob notation. '.t' will be appended
    );

=cut
sub _GetTestFiles {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # get directory containing tests
    my $HomeDirectory = $ConfigObject->Get('Home');
    my $TestDirectory = "$HomeDirectory/scripts/test";

    # custom sub directory for test lookup
    if ( $Param{'TestDirectory'} ) {
        $TestDirectory .= "/$Param{'TestDirectory'}";
        $TestDirectory =~ s/\.//g;
    }

    # set filter for test files
    my $TestFilter = '*.t';
    if ( $Param{'TestFilter'} ) {
        $TestFilter = $Param{'TestFilter'} . '.t';
    }

    # get test files from test directory
    my @TestFiles = $MainObject->DirectoryRead(
        Directory => $TestDirectory,
        Filter    => $TestFilter,
        Recursive => 1,
    );

    # return test files
    return @TestFiles;
}

=item _InitUnitTest()

Prepare unit test data

    $Self->_InitUnitTest();

=cut
sub _InitUnitTest {
    my ( $Self, %Param ) = @_;

    # init return code
    $Self->{'ReturnCode'} = 1;

    # init start time
    $Self->{'StartTime'} = $Self->GetMilliTimeStamp();

    # init test counter
    $Self->{'Count'}->{'TestFile'} = 0;
    $Self->{'Count'}->{'TestCase'} = 0;
    $Self->{'Count'}->{'Test'}     = 0;
    $Self->{'Count'}->{'Success'}  = 0;
    $Self->{'Count'}->{'Fail'}     = 0;
    $Self->{'Count'}->{'Skip'}     = 0;

    return;
}

=item _TestFileStart()

Prepare test file data

    $Self->_TestFileStart(
        File => '/opt/kix17/script/test/Cache.t',  # path of test file
    );

=cut
sub _TestFileStart {
    my ( $Self, %Param ) = @_;

    # increment test file counter
    $Self->{'Count'}->{'TestFile'} += 1;

    # reset test counter
    $Self->{'TestFile'}->{'Count'}->{'Test'}    = 0;
    $Self->{'TestFile'}->{'Count'}->{'Success'} = 0;
    $Self->{'TestFile'}->{'Count'}->{'Fail'}    = 0;
    $Self->{'TestFile'}->{'Count'}->{'Skip'}    = 0;

    # generate uuid
    $Self->{'TestFile'}->{'Data'}->{'uuid'} = $Self->GetRandomNumber();

    # generate name
    my $TestFileName = $Param{'File'};
    $TestFileName    =~ s/^.+\/scripts\/test\/(.+)\.t$/$1/;
    $Self->{'TestFile'}->{'Data'}->{'name'} = $TestFileName;

    # init array variables
    $Self->{'TestFile'}->{'Data'}->{'afters'}   = [];
    $Self->{'TestFile'}->{'Data'}->{'befores'}  = [];
    $Self->{'TestFile'}->{'Data'}->{'children'} = [];
    $Self->{'TestFile'}->{'Data'}->{'links'}    = [];

    # init stop time
    $Self->{'TestFile'}->{'Data'}->{'stop'} = '';

    # init start time
    $Self->{'TestFile'}->{'Data'}->{'start'} = $Self->GetMilliTimeStamp();

    return;
}

=item _TestFileStop()

Output test file data

    $Self->_TestFileStop();

=cut
sub _TestFileStop {
    my ( $Self, %Param ) = @_;

    # check if test case is still active
    if ( $Self->{'TestCase'}->{'Active'} ) {
        $Self->TestCaseStop();
    }

    # get needed objects
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    # get stop time
    $Self->{'TestFile'}->{'Data'}->{'stop'} = $Self->GetMilliTimeStamp();

    # calc duration
    my $Duration = $Self->{'TestFile'}->{'Data'}->{'stop'} - $Self->{'TestFile'}->{'Data'}->{'start'};

    # prepare file path and name
    my $Location = $Self->{'OutputDirectory'} . '/' . $Self->{'TestFile'}->{'Data'}->{'uuid'} . '-container.json';

    # encode json string
    my $JSONString = $JSONObject->Encode(
        Data     => $Self->{'TestFile'}->{'Data'},
        SortKeys => 1,
    );

    # write json to file
    my $FileLocation = $MainObject->FileWrite(
        Location   => $Location,
        Content    => \$JSONString,
        Mode       => 'utf8',
        Type       => 'Local',
        Permission => '644',
    );

    # output summary to console
    if ( !$Self->{'Silent'} ) {
        my $Summary = sprintf(
            "File: %s, Testcases: %d, Tests: %d, Success: %d, Fail: %d, Skip: %d, Duration: %dms\n",
            $Self->{'TestFile'}->{'Data'}->{'name'},
            scalar( @{ $Self->{'TestFile'}->{'Data'}->{'children'} } ),
            $Self->{'TestFile'}->{'Count'}->{'Test'},
            $Self->{'TestFile'}->{'Count'}->{'Success'},
            $Self->{'TestFile'}->{'Count'}->{'Fail'},
            $Self->{'TestFile'}->{'Count'}->{'Skip'},
            $Duration
        );
        print STDOUT $Summary;
    }

    return;
}

=item _AddTestStep()

Process test step

    $Self->_AddTestStep(
        TestName   => 'Name of test',  # name of test step
        Success    => 0,               # (0|1), successful test
        Message    => 'test message',  # optional, message for test
        StartTime  => 1534125612531,   # timestamp of test start in milli seconds
        Caller     => 0,               # caller instance
    );

=cut
sub _AddTestStep {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # init step entry
    my %StepEntry = (
        'name'          => '',
        'status'        => '',
        'stage'         => 'finished',
        'steps'         => [],
        'attachments'   => [],
        'parameters'    => [],
        'start'         => '',
        'stop'          => $Self->GetMilliTimeStamp(),
        'statusDetails' => {
            'known' => $JSONObject->False(),
            'muted' => $JSONObject->False(),
            'flaky' => $JSONObject->False()
        },
    );

    # set test step name
    $StepEntry{'name'} = $Param{'TestName'} || '->>No Name!<<-';

    # set start time stamp
    if ( $Param{'StartTime'} ) {
        $StepEntry{'start'} = $Param{'StartTime'};
    }

    # set message
    if ( $Param{'Message'} ) {
        push( @{ $StepEntry{'parameters'} }, { 'Message' => $Param{'Message'} } );
    }

    # increment test count
    $Self->{'Count'}->{'Test'}               += 1;
    $Self->{'TestFile'}->{'Count'}->{'Test'} += 1;
    $Self->{'TestCase'}->{'Count'}->{'Test'} += 1;

    # process success status
    if ( $Param{'Success'} ) {
        # set status
        $StepEntry{'status'} = 'passed';

        # increment success count
        $Self->{'Count'}->{'Success'}               += 1;
        $Self->{'TestFile'}->{'Count'}->{'Success'} += 1;
        $Self->{'TestCase'}->{'Count'}->{'Success'} += 1;
    }
    # process fail status
    else {
        # set status broken (Test defect)
        if ( $Param{'Broken'} ) {
            $StepEntry{'status'} = 'broken';
        }

        # set status failed (Product defect)
        else {
            $StepEntry{'status'} = 'failed';
        }

        # increment fail count
        $Self->{'Count'}->{'Fail'}               += 1;
        $Self->{'TestFile'}->{'Count'}->{'Fail'} += 1;
        $Self->{'TestCase'}->{'Count'}->{'Fail'} += 1;

        # process trace
        my $Trace = $Param{'Trace'};
        if ( !$Trace ) {
            my $Caller = $Param{'Caller'} || 0;
            my ( $TracePackage, $TraceFilename, $TraceLine ) = caller( $Caller );
            $Trace = sprintf("%s:%d", $TraceFilename, $TraceLine);
        }
        push( @{ $StepEntry{'parameters'} }, { 'Trace' => $Trace } );

        # set fail data for testcase
        $Self->{'TestCase'}->{'Data'}->{'statusDetails'}->{'message'} = $Param{'Message'} || '->>No Message!<<-';
        $Self->{'TestCase'}->{'Data'}->{'statusDetails'}->{'trace'}   = $Trace;

        # set fail status for testcase
        if (
            $Param{'Broken'}
            || $Self->{'TestCase'}->{'Broken'}
        ) {
            $Self->{'TestCase'}->{'Broken'}           = 1;
            $Self->{'TestCase'}->{'Data'}->{'status'} = 'broken';
        }
        else {
            $Self->{'TestCase'}->{'Data'}->{'status'} = 'failed';
        }

        # set fail return code
        $Self->{'ReturnCode'} = 0;
    }

    # add step to testcase
    push(@{ $Self->{'TestCase'}->{'Data'}->{'steps'} }, \%StepEntry);

    return;
}

=item _HandlePlannedTestSteps()

Process skipped test steps

    $Self->_HandlePlannedTestSteps();

=cut
sub _HandlePlannedTestSteps {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    for my $Key ( sort( keys( %{ $Self->{'TestCase'}->{'PlanSteps'} } ) ) ) {
        # init step entry
        my %StepEntry = (
            'name'          => $Self->{'TestCase'}->{'PlanSteps'}->{$Key},
            'status'        => 'skipped',
            'stage'         => 'finished',
            'steps'         => [],
            'attachments'   => [],
            'parameters'    => [],
            'start'         => $Self->GetMilliTimeStamp(),
            'stop'          => $Self->GetMilliTimeStamp(),
            'statusDetails' => {
                'known' => $JSONObject->False(),
                'muted' => $JSONObject->False(),
                'flaky' => $JSONObject->False()
            },
        );

        # increment test count
        $Self->{'Count'}->{'Test'}               += 1;
        $Self->{'TestFile'}->{'Count'}->{'Test'} += 1;
        $Self->{'TestCase'}->{'Count'}->{'Test'} += 1;

        # increment skip count
        $Self->{'Count'}->{'Skip'}               += 1;
        $Self->{'TestFile'}->{'Count'}->{'Skip'} += 1;
        $Self->{'TestCase'}->{'Count'}->{'Skip'} += 1;

        # add step to testcase
        push(@{ $Self->{'TestCase'}->{'Data'}->{'steps'} }, \%StepEntry);
    }

    return;
}

=item _OutputSummary()

Output test summary

    $Self->_OutputSummary();

=cut
sub _OutputSummary {
    my ( $Self, %Param ) = @_;

    # calc duration
    my $Duration = $Self->GetMilliTimeStamp() - $Self->{'StartTime'};

    # output summary to console
    if ( !$Self->{'Silent'} ) {
        my $Summary = sprintf(
            "Files: %d, Testcases: %d, Tests: %d, Success: %d, Fail: %d, Skip: %d, Duration: %dms\n",
            $Self->{'Count'}->{'TestFile'},
            $Self->{'Count'}->{'TestCase'},
            $Self->{'Count'}->{'Test'},
            $Self->{'Count'}->{'Success'},
            $Self->{'Count'}->{'Fail'},
            $Self->{'Count'}->{'Skip'},
            $Duration
        );
        print STDOUT $Summary;
    }

    return;
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
