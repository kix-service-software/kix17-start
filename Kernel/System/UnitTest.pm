# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest;

use strict;
use warnings;

use Term::ANSIColor();
use SOAP::Lite;
use FileHandle;
use Time::HiRes;

use Kernel::System::ObjectManager;

# UnitTest helper must be loaded to override the builtin time functions!
use Kernel::System::UnitTest::Helper;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Encode',
    'Kernel::System::Environment',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Time',
);

## no critic qw(InputOutput::RequireEncodingWithUTF8Layer BuiltinFunctions::ProhibitStringyEval)

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

    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{Output} = $Param{Output} || 'ASCII';

    $Self->{Filename} = $Param{Filename};

    $Self->{ANSI} = $Param{ANSI};

    $Self->{XML}     = undef;
    $Self->{XMLUnit} = '';

    $Self->{OriginalSTDOUT} = *STDOUT;
    $Self->{OriginalSTDOUT}->autoflush(1);

    return $Self;
}

=item Run()

Run all tests located in scripts/test/*.t and print result to stdout.

    $UnitTestObject->Run(
        Name      => 'JSON:User:Auth',  # optional, control which tests to select
        Directory => 'Selenium',        # optional, control which directory to select
        Verbose   => 1,                 # optional (default 0), only show result details for all tests, not just failing
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my %ResultSummary;
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my $Directory = "$Home/scripts/test";

    # custom subdirectory passed
    if ( $Param{Directory} ) {
        $Directory .= "/$Param{Directory}";
        $Directory =~ s/\.//g;
    }

    $Self->{Verbose} = $Param{Verbose};

    my @Files = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $Directory,
        Filter    => '*.t',
        Recursive => 1,
    );

    my $StartTime      = Time::HiRes::time();
    my $StartTimestamp = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    my $Product        = $Param{Product}
        || $Kernel::OM->Get('Kernel::Config')->Get('Product') . " "
        . $Kernel::OM->Get('Kernel::Config')->Get('Version');

    $Self->{Product} = $Product;    # we need this in the Selenium object

    my @Names = split( /:/, $Param{Name} || '' );

    $Self->{Content}     = '';
    $Self->{HTMLContent} = '';
    if ( $Self->{Output} eq 'HTML' ) {
        if ( $Self->{Filename} ) {
            $Self->{Content} = "<!DOCTYPE html>\n"
                . "<html>\n"
                . "<head>\n"
                . "    <title>"
                . $Kernel::OM->Get('Kernel::Config')->Get('Product')
                . " "
                . $Kernel::OM->Get('Kernel::Config')->Get('Version')
                . " - Test Summary</title>\n"
                . "</head>\n"
                . "<body>\n"
                . "    <a name='top'></a>\n";
        }
        else {
            print "\n"
                . "<html>\n"
                . "<head>\n"
                . "    <title>"
                . $Kernel::OM->Get('Kernel::Config')->Get('Product')
                . " "
                . $Kernel::OM->Get('Kernel::Config')->Get('Version')
                . " - Test Summary</title>\n"
                . "</head>\n"
                . "<body>\n"
                . "    <a name='top'></a>\n";
        }
    }

    $Self->{TestCountOk}    = 0;
    $Self->{TestCountNotOk} = 0;
    FILE:
    for my $File (@Files) {

        # check if only some tests are requested
        if (@Names) {
            my $Use = 0;
            for my $Name (@Names) {
                if ( $Name && $File =~ /\/\Q$Name\E\.t$/ ) {
                    $Use = 1;
                }
            }
            if ( !$Use ) {
                next FILE;
            }
        }
        $Self->{TestCount} = 0;
        my $UnitTestFile = $Kernel::OM->Get('Kernel::System::Main')->FileRead( Location => $File );
        if ( !$UnitTestFile ) {
            $Self->True( 0, "ERROR: $!: $File" );
            print STDERR "ERROR: $!: $File\n";
        }
        else {
            $Self->_PrintHeadlineStart($File);

            # create a new scope to be sure to destroy local object of the test files
            {
                # Make sure every UT uses its own clean environment.
                local $Kernel::OM = Kernel::System::ObjectManager->new(
                    'Kernel::System::Log' => {
                        LogPrefix => 'KIX-UnitTest',
                    },
                );

                # Provide $Self as 'Kernel::System::UnitTest' for convenience.
                $Kernel::OM->ObjectInstanceRegister(
                    Package      => 'Kernel::System::UnitTest',
                    Object       => $Self,
                    Dependencies => [],
                );

                push @{ $Self->{NotOkInfo} }, [$File];

                $Self->{OutputBuffer} = '';
                local *STDOUT = *STDOUT;
                local *STDERR = *STDERR;
                if ( !$Param{Verbose} ) {
                    undef *STDOUT;
                    undef *STDERR;
                    open STDOUT, '>:utf8', \$Self->{OutputBuffer} or die "Error: ?!";
                    open STDERR, '>:utf8', \$Self->{OutputBuffer} or die "Error: ?!";
                }

                # HERE the actual tests are run!!!
                if ( !eval( ${$UnitTestFile} ) ) {
                    if ($@) {
                        $Self->True( 0, "ERROR: Error in $File: $@" );
                    }
                    else {
                        $Self->True( 0, "ERROR: $File did not return a true value." );
                    }
                }
            }

            $Self->_PrintHeadlineEnd($File);
        }
    }

    my $TimeDiff = Time::HiRes::time() - $StartTime;
    my $Time     = sprintf("%.3f", $TimeDiff);
    
    my %OSInfo = $Kernel::OM->Get('Kernel::System::Environment')->OSInfoGet();

    $ResultSummary{Time}          = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    $ResultSummary{Timestamp}     = $StartTimestamp;
    $ResultSummary{TimeTaken}     = $Time;
    $ResultSummary{Product}       = $Product;
    $ResultSummary{ConfigProduct} = $Kernel::OM->Get('Kernel::Config')->Get('Product');
    $ResultSummary{ConfigVersion} = $Kernel::OM->Get('Kernel::Config')->Get('Version');
    $ResultSummary{Host}          = $Kernel::OM->Get('Kernel::Config')->Get('FQDN');
    $ResultSummary{Perl}          = sprintf "%vd", $^V;
    $ResultSummary{OS}            = $OSInfo{OS};
    $ResultSummary{Vendor}        = $OSInfo{OSName};
    $ResultSummary{Database}      = lc $Kernel::OM->Get('Kernel::System::DB')->Version();
    $ResultSummary{TestOk}        = $Self->{TestCountOk};
    $ResultSummary{TestNotOk}     = $Self->{TestCountNotOk};

    $Self->_PrintSummary(%ResultSummary);

    if ( $Self->{Output} eq 'HTML' ) {
        if ( $Self->{Filename} ) {
            $Self->{Content} .= $Self->{HTMLContent}. "\n"
                . "</body>\n"
                . "</html>";
        }
        else {
            print $Self->{HTMLContent} . "\n"
                . "</body>\n"
                . "</html>";
        }
    }

    if ( $Self->{Output} eq 'XML' ) {
        $Self->{Content}  = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n";
        $Self->{Content} .= "<kix_test>\n";
        $Self->{Content} .= "<Summary>\n";
        for my $Key ( sort keys %ResultSummary ) {
            $ResultSummary{$Key} =~ s/&/&amp;/g;
            $ResultSummary{$Key} =~ s/</&lt;/g;
            $ResultSummary{$Key} =~ s/>/&gt;/g;
            $ResultSummary{$Key} =~ s/"/&quot;/g;
            $Self->{Content} .= "  <Item Name=\"$Key\">$ResultSummary{$Key}</Item>\n";
        }
        $Self->{Content} .= "</Summary>\n";
        for my $Key ( sort keys %{ $Self->{XML}->{Test} } ) {

            # extract duration time
            my $Duration = $Self->{Duration}->{$Key};

            $Self->{Content} .= "<Unit Name=\"$Key\" Duration=\"$Duration\">\n";

            for my $TestCount ( sort { $a <=> $b } keys %{ $Self->{XML}->{Test}->{$Key} } ) {
                my $Result  = $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Result};
                my $Content = $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Name} . ' (' . $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Message} . ')';
                $Content =~ s/&/&amp;/g;
                $Content =~ s/</&lt;/g;
                $Content =~ s/>/&gt;/g;

                # Replace characters that are invalid in XML (https://www.w3.org/TR/REC-xml/#charsets)
                $Content =~ s/[^\x{0009}\x{000a}\x{000d}\x{0020}-\x{D7FF}\x{E000}-\x{FFFD}]+/"\x{FFFD}"/eg;
                $Self->{Content} .= qq|  <Test Result="$Result" Count="$TestCount">$Content</Test>\n|;
            }

            $Self->{Content} .= "</Unit>\n";
        }
        $Self->{Content} .= "</kix_test>\n";

        # print xml to console if now filename is given
        if ( !$Self->{Filename} ) {
            print $Self->{Content};
        }
    }

    if ( $Self->{Output} eq 'xUnit' ) {
        # head of xunit xml
        $Self->{Content} = '<?xml version="1.0" encoding="utf-8" ?>' . "\n";

        # prepare testsuites name
        my $TestSuitesName = $ResultSummary{Product} . '//' . $ResultSummary{OS} . ' ' . $ResultSummary{Vendor} . '//' . $ResultSummary{Database} . '//Perl ' . $ResultSummary{Perl} . '//' . $ResultSummary{Time};
        $TestSuitesName    =~ s/&/&amp;/g;
        $TestSuitesName    =~ s/</&lt;/g;
        $TestSuitesName    =~ s/>/&gt;/g;
        $TestSuitesName    =~ s/"/&quot;/g;

        # prepare testsuites timestamp
        my $TestSuitesTimestamp = $ResultSummary{Timestamp} || '';
        $TestSuitesTimestamp    =~ s/\s/T/;

        # prepare summary for tag testsuites
        $Self->{Content} .= '<testsuites';
        $Self->{Content} .= ' name="' . $TestSuitesName . '"';
        $Self->{Content} .= ' tests="' . ( $ResultSummary{TestOk} + $ResultSummary{TestNotOk} ) . '"';
        $Self->{Content} .= ' failures="' . $ResultSummary{TestNotOk} . '"';
        $Self->{Content} .= ' errors="0"';
        $Self->{Content} .= ' disabled="0"';
        $Self->{Content} .= ' timestamp="' . $TestSuitesTimestamp . '"';
        $Self->{Content} .= ' time="' . $ResultSummary{TimeTaken} . '"';
        $Self->{Content} .= '>' . "\n";

        # process test units
        my $TestSuiteID = 0;
        for my $Key ( sort keys %{ $Self->{XML}->{Test} } ) {

            # extract duration time
            my $Duration = $Self->{Duration}->{$Key};

            # prepare timestamp
            my $Timestamp = $Self->{Timestamp}->{$Key} || '';
            $Timestamp    =~ s/\s/T/;

            # prepare test count
            my $Tests = keys( %{ $Self->{XML}->{Test}->{$Key} } );

            # prepare failures count
            my $Failures = 0;
            for my $TestCount ( keys( %{ $Self->{XML}->{Test}->{$Key} } ) ) {
                if ( $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Result} eq 'not ok' ) {
                    $Failures += 1;
                }
            }

            # generate testsuite name
            my $TestSuiteName = $Key;
            $TestSuiteName    =~ s/^.+\/scripts\/test\/(.+)\.t$/$1/;
            $TestSuiteName    =~ s/&/&amp;/g;
            $TestSuiteName    =~ s/</&lt;/g;
            $TestSuiteName    =~ s/>/&gt;/g;
            $TestSuiteName    =~ s/"/&quot;/g;

            # prepare summary for tag testsuite
            $Self->{Content} .= '  <testsuite';
            $Self->{Content} .= ' id="' . $TestSuiteID . '"';
            $Self->{Content} .= ' name="' . $TestSuiteName . '"';
            $Self->{Content} .= ' hostname="' . $ResultSummary{Host} . '"';
            $Self->{Content} .= ' tests="' . $Tests . '"';
            $Self->{Content} .= ' failures="' . $Failures . '"';
            $Self->{Content} .= ' errors="0"';
            $Self->{Content} .= ' disabled="0"';
            $Self->{Content} .= ' skipped="0"';
            $Self->{Content} .= ' timestamp="' . $Timestamp . '"';
            $Self->{Content} .= ' time="' . $Duration . '"';
            $Self->{Content} .= '>' . "\n";

            # add properties
            $Self->{Content} .= '    <properties>' . "\n";
            $Self->{Content} .= '      <property';
            $Self->{Content} .= ' name="Product"';
            $Self->{Content} .= ' value="' . $ResultSummary{Product} . '"';
            $Self->{Content} .= '/>' . "\n";
            $Self->{Content} .= '      <property';
            $Self->{Content} .= ' name="Software"';
            $Self->{Content} .= ' value="' . $ResultSummary{ConfigProduct} . ' ' . $ResultSummary{ConfigVersion} . '"';
            $Self->{Content} .= '/>' . "\n";
            $Self->{Content} .= '      <property';
            $Self->{Content} .= ' name="OS"';
            $Self->{Content} .= ' value="' . $ResultSummary{OS} . ' ' . $ResultSummary{Vendor} . '"';
            $Self->{Content} .= '/>' . "\n";
            $Self->{Content} .= '      <property';
            $Self->{Content} .= ' name="Perl"';
            $Self->{Content} .= ' value="' . $ResultSummary{Perl} . '"';
            $Self->{Content} .= '/>' . "\n";
            $Self->{Content} .= '      <property';
            $Self->{Content} .= ' name="Database"';
            $Self->{Content} .= ' value="' . $ResultSummary{Database} . '"';
            $Self->{Content} .= '/>' . "\n";
            $Self->{Content} .= '    </properties>' . "\n";

            for my $TestCount ( sort { $a <=> $b } keys %{ $Self->{XML}->{Test}->{$Key} } ) {
                # generate testcase name
                my $TestCaseName = $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Name};
                $TestCaseName    =~ s/&/&amp;/g;
                $TestCaseName    =~ s/</&lt;/g;
                $TestCaseName    =~ s/>/&gt;/g;
                $TestCaseName    =~ s/"/&quot;/g;
                
                # prepare summary for tag testcase
                $Self->{Content} .= '    <testcase';
                $Self->{Content} .= ' name="' . sprintf("%05d-%s", $TestCount, $TestCaseName) . '"';
                $Self->{Content} .= ' classname="' . $TestSuiteName . '"';
                $Self->{Content} .= ' status="' . $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Result} . '"';
                if ( $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Duration} ) {
                    $Self->{Content} .= ' time="' . $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Duration} . '"';
                }
                $Self->{Content} .= '>';

                if ( $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Result} eq 'not ok' ) {
                    my $Content = $Self->{XML}->{Test}->{$Key}->{$TestCount}->{Message};
                    $Content    =~ s/&/&amp;/g;
                    $Content    =~ s/</&lt;/g;
                    $Content    =~ s/>/&gt;/g;
                    $Content    =~ s/"/&quot;/g;

                    # Replace characters that are invalid in XML (https://www.w3.org/TR/REC-xml/#charsets)
                    $Content =~ s/[^\x{0009}\x{000a}\x{000d}\x{0020}-\x{D7FF}\x{E000}-\x{FFFD}]+/"\x{FFFD}"/eg;

                    $Self->{Content} .= '<failure';
                    $Self->{Content} .= ' message="' . $Content . '"';
                    $Self->{Content} .= ' type="failure"';
                    $Self->{Content} .= '></failure>';
                }

                # close tag testcase
                $Self->{Content} .= '</testcase>' . "\n";
            }

            # close tag testsuite
            $Self->{Content} .= '  </testsuite>' . "\n";

            # increment testsuite id
            $TestSuiteID += 1;
        }

        # close tag testsuites
        $Self->{Content} .= '</testsuites>' . "\n";

        # print xunit to console if now filename is given
        if ( !$Self->{Filename} ) {
            print $Self->{Content};
        }
    }

    if ( $Self->{Filename} ) {
        my $FileLocation = $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
            Location   => $Self->{Filename},
            Content    => \$Self->{Content},
            Mode       => 'utf8',
            Type       => 'Local',
            Permission => '644',
        );
    }

    return $ResultSummary{TestNotOk} ? 0 : 1;
}

=item True()

test for a scalar value that evaluates to true.

Send a scalar value to this function along with the test's name:

    $UnitTestObject->True(1, 'Test Name');

    $UnitTestObject->True($ParamA, 'Test Name');

Internally, the function receives this value and evaluates it to see
if it's true, returning 1 in this case or undef, otherwise.

    my $TrueResult = $UnitTestObject->True(
        $TestValue,
        'Test Name',
    );

=cut

sub True {
    my ( $Self, $True, $Name, $StartTime ) = @_;

    if ( !$Name ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. True(\$A, \'Test Name\')!'
        );
        $Self->_Print( 0, '->>No Name!<<-', 'ERROR: Need Name! E. g. True(\$A, \'Test Name\')', $StartTime );
        return;
    }

    if ($True) {
        $Self->_Print( 1, $Name, 'is \'True\'', $StartTime );
        return 1;
    }
    else {
        $Self->_Print( 0, $Name, 'is \'False\', should be \'True\'', $StartTime );
        return;
    }
}

=item False()

test for a scalar value that evaluates to false.

It has the same interface as L</True()>, but tests
for a false value instead.

=cut

sub False {
    my ( $Self, $False, $Name, $StartTime ) = @_;

    if ( !$Name ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. False(\$A, \'Test Name\')!'
        );
        $Self->_Print( 0, '->>No Name!<<-', 'ERROR: Need Name! E. g. False(\$A, \'Test Name\')', $StartTime );
        return;
    }

    if ( !$False ) {
        $Self->_Print( 1, $Name, 'is \'False\'', $StartTime );
        return 1;
    }
    else {
        $Self->_Print( 0, $Name, 'is \'True\', should be \'False\'', $StartTime );
        return;
    }
}

=item Is()

compares two scalar values for equality.

To this function you must send a pair of scalar values to compare them,
and the name that the test will take, this is done as shown in the examples
below.

    $UnitTestObject->Is($A, $B, 'Test Name');

Returns 1 if the values were equal, or undef otherwise.

    my $IsResult = $UnitTestObject->Is(
        $ValueFromFunction,      # test data
        1,                       # expected value
        'Test Name',
    );

=cut

sub Is {
    my ( $Self, $Test, $ShouldBe, $Name, $StartTime ) = @_;

    if ( !$Name ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, '->>No Name!<<-', 'ERROR: Need Name! E. g. Is(\$A, \$B, \'Test Name\')', $StartTime );
        return;
    }

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, $Name, 'is \'undef\'', $StartTime );
        return 1;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 0, $Name, 'is \'undef\', should be \'' . $ShouldBe . '\'', $StartTime );
        return;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, $Name, 'is \'' . $Test . '\', should be \'undef\'', $StartTime );
        return;
    }
    elsif ( $Test eq $ShouldBe ) {
        $Self->_Print( 1, $Name, 'is \'' . $ShouldBe . '\'', $StartTime );
        return 1;
    }
    else {
        $Self->_Print( 0, $Name, 'is \'' . $Test . '\', should be \'' . $ShouldBe . '\'', $StartTime );
        return;
    }
}

=item IsNot()

compares two scalar values for inequality.

It has the same interface as L</Is()>, but tests
for inequality instead.

=cut

sub IsNot {
    my ( $Self, $Test, $ShouldBe, $Name, $StartTime ) = @_;

    if ( !$Name ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, '->>No Name!<<-' , 'ERROR: Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')', $StartTime );
        return;
    }

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, $Name, 'is \'undef\'', $StartTime );
        return;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 1, $Name. 'is \'undef\'', $StartTime );
        return 1;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, $Name, 'is \'' . $Test . '\'', $StartTime );
        return 1;
    }
    if ( $Test ne $ShouldBe ) {
        $Self->_Print( 1, $Name, 'is \'' . $Test . '\'', $StartTime );
        return 1;
    }
    else {
        $Self->_Print( 0, $Name, 'is \'' . $Test . '\', should not be \'' . $ShouldBe . '\'', $StartTime );
        return;
    }
}

=item IsDeeply()

compares complex data structures for equality.

To this function you must send the references to two data structures to be compared,
and the name that the test will take, this is done as shown in the examples
below.

    $UnitTestObject-> IsDeeply($ParamA, $ParamB, 'Test Name');

Where $ParamA and $ParamB must be references to a structure (scalar, list or hash).

Returns 1 if the data structures are the same, or undef otherwise.

    my $IsDeeplyResult = $UnitTestObject->IsDeeply(
        \%ResultHash,           # test data
        \%ExpectedHash,         # expected value
        'Dummy Test Name',
    );

=cut

sub IsDeeply {
    my ( $Self, $Test, $ShouldBe, $Name, $StartTime ) = @_;

    if ( !$Name ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, '->>No Name!<<-', 'ERROR: Need Name! E. g. Is(\$A, \$B, \'Test Name\')', $StartTime );
        return;
    }

    my $Diff = $Self->_DataDiff(
        Data1 => $Test,
        Data2 => $ShouldBe,
    );

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, $Name, 'is \'undef\'', $StartTime );
        return 1;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 0, $Name, 'is \'undef\', should be defined', $StartTime );
        return;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, $Name, 'is defined, should be \'undef\'', $StartTime );
        return;
    }
    elsif ( !$Diff ) {
        $Self->_Print( 1, $Name, 'matches expected value', $StartTime );
        return 1;
    }
    else {
        my $ShouldBeDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($ShouldBe);
        my $TestDump     = $Kernel::OM->Get('Kernel::System::Main')->Dump($Test);
        $Self->_Print( 0, $Name, 'is \'' . $TestDump . '\', should be \'' . $ShouldBeDump . '\'', $StartTime );
        return;
    }
}

=item IsNotDeeply()

compares two data structures for inequality.

It has the same interface as L</IsDeeply()>, but tests
for inequality instead.

=cut

sub IsNotDeeply {
    my ( $Self, $Test, $ShouldBe, $Name, $StartTime ) = @_;

    if ( !$Name ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')!'
        );
        $Self->_Print( 0, '->>No Name!<<-', 'ERROR: Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')', $StartTime );
        return;
    }

    my $Diff = $Self->_DataDiff(
        Data1 => $Test,
        Data2 => $ShouldBe,
    );

    if ( !defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 0, $Name, 'is \'undef\'', $StartTime );
        return;
    }
    elsif ( !defined $Test && defined $ShouldBe ) {
        $Self->_Print( 1, $Name, 'is \'undef\'', $StartTime );
        return 1;
    }
    elsif ( defined $Test && !defined $ShouldBe ) {
        $Self->_Print( 1, $Name, 'differs from expected value', $StartTime );
        return 1;
    }

    if ($Diff) {
        $Self->_Print( 1, $Name, 'the structures are not equal', $StartTime );
        return 1;
    }
    else {
        my $TestDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Test);
        $Self->_Print( 0, $Name, 'the structures are equal: \'' . $TestDump . '\'', $StartTime );
        return;
    }
}

=begin Internal:

=cut

=item _DataDiff()

compares two data structures with each other. Returns 1 if
they are different, undef otherwise.

Data parameters need to be passed by reference and can be SCALAR,
ARRAY or HASH.

    my $DataIsDifferent = $UnitTestObject->_DataDiff(
        Data1 => \$Data1,
        Data2 => \$Data2,
    );

=cut

sub _DataDiff {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data1 Data2)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # ''
    if ( ref $Param{Data1} eq '' && ref $Param{Data2} eq '' ) {

        # do nothing, it's ok
        return if !defined $Param{Data1} && !defined $Param{Data2};

        # return diff, because its different
        return 1 if !defined $Param{Data1} || !defined $Param{Data2};

        # return diff, because its different
        return 1 if $Param{Data1} ne $Param{Data2};

        # return, because its not different
        return;
    }

    # SCALAR
    if ( ref $Param{Data1} eq 'SCALAR' && ref $Param{Data2} eq 'SCALAR' ) {

        # do nothing, it's ok
        return if !defined ${ $Param{Data1} } && !defined ${ $Param{Data2} };

        # return diff, because its different
        return 1 if !defined ${ $Param{Data1} } || !defined ${ $Param{Data2} };

        # return diff, because its different
        return 1 if ${ $Param{Data1} } ne ${ $Param{Data2} };

        # return, because its not different
        return;
    }

    # ARRAY
    if ( ref $Param{Data1} eq 'ARRAY' && ref $Param{Data2} eq 'ARRAY' ) {
        my @A = @{ $Param{Data1} };
        my @B = @{ $Param{Data2} };

        # check if the count is different
        return 1 if $#A ne $#B;

        # compare array
        COUNT:
        for my $Count ( 0 .. $#A ) {

            # do nothing, it's ok
            next COUNT if !defined $A[$Count] && !defined $B[$Count];

            # return diff, because its different
            return 1 if !defined $A[$Count] || !defined $B[$Count];

            if ( $A[$Count] ne $B[$Count] ) {
                if ( ref $A[$Count] eq 'ARRAY' || ref $A[$Count] eq 'HASH' ) {
                    return 1 if $Self->_DataDiff(
                        Data1 => $A[$Count],
                        Data2 => $B[$Count]
                    );
                    next COUNT;
                }
                return 1;
            }
        }
        return;
    }

    # HASH
    if ( ref $Param{Data1} eq 'HASH' && ref $Param{Data2} eq 'HASH' ) {
        my %A = %{ $Param{Data1} };
        my %B = %{ $Param{Data2} };

        # compare %A with %B and remove it if checked
        KEY:
        for my $Key ( sort keys %A ) {

            # Check if both are undefined
            if ( !defined $A{$Key} && !defined $B{$Key} ) {
                delete $A{$Key};
                delete $B{$Key};
                next KEY;
            }

            # return diff, because its different
            return 1 if !defined $A{$Key} || !defined $B{$Key};

            if ( $A{$Key} eq $B{$Key} ) {
                delete $A{$Key};
                delete $B{$Key};
                next KEY;
            }

            # return if values are different
            if ( ref $A{$Key} eq 'ARRAY' || ref $A{$Key} eq 'HASH' ) {
                return 1 if $Self->_DataDiff(
                    Data1 => $A{$Key},
                    Data2 => $B{$Key}
                );
                delete $A{$Key};
                delete $B{$Key};
                next KEY;
            }
            return 1;
        }

        # check rest
        return 1 if %B;
        return;
    }

    if ( ref $Param{Data1} eq 'REF' && ref $Param{Data2} eq 'REF' ) {
        return 1 if $Self->_DataDiff(
            Data1 => ${ $Param{Data1} },
            Data2 => ${ $Param{Data2} }
        );
        return;
    }

    return 1;
}

sub _PrintSummary {
    my ( $Self, %ResultSummary ) = @_;

    # show result
    if ( $Self->{Output} eq 'HTML' ) {
        if ( $Self->{Filename} ) {
            $Self->{Content} .= "<table width='600' border='1'>\n";
            if ( $ResultSummary{TestNotOk} ) {
                $Self->{Content} .= "<tr><td bgcolor='red' colspan='2'>Summary</td></tr>\n";
            }
            else {
                $Self->{Content} .= "<tr><td bgcolor='green' colspan='2'>Summary</td></tr>\n";
            }
            $Self->{Content} .= "<tr><td>Product:  </td><td>$ResultSummary{Product}</td></tr>\n";
            $Self->{Content} .= "<tr><td>Test Time:</td><td>$ResultSummary{TimeTaken} s</td></tr>\n";
            $Self->{Content} .= "<tr><td>Time:     </td><td>$ResultSummary{Time}</td></tr>\n";
            $Self->{Content} .= "<tr><td>Timestamp:</td><td>$ResultSummary{Timestamp}</td></tr>\n";
            $Self->{Content} .= "<tr><td>Host:     </td><td>$ResultSummary{Host}</td></tr>\n";
            $Self->{Content} .= "<tr><td>Perl:     </td><td>$ResultSummary{Perl}</td></tr>\n";
            $Self->{Content} .= "<tr><td>OS:       </td><td>$ResultSummary{OS}</td></tr>\n";
            $Self->{Content} .= "<tr><td>Vendor:   </td><td>$ResultSummary{Vendor}</td></tr>\n";
            $Self->{Content} .= "<tr><td>Database: </td><td>$ResultSummary{Database}</td></tr>\n";
            $Self->{Content} .= "<tr><td>TestOk:   </td><td>$ResultSummary{TestOk}</td></tr>\n";
            $Self->{Content} .= "<tr><td>TestNotOk:</td><td>$ResultSummary{TestNotOk}</td></tr>\n";
            $Self->{Content} .= "</table><br>\n";
        }
        else {
            print "<table width='600' border='1'>\n";
            if ( $ResultSummary{TestNotOk} ) {
                print "<tr><td bgcolor='red' colspan='2'>Summary</td></tr>\n";
            }
            else {
                print "<tr><td bgcolor='green' colspan='2'>Summary</td></tr>\n";
            }
            print "<tr><td>Product:  </td><td>$ResultSummary{Product}</td></tr>\n";
            print "<tr><td>Test Time:</td><td>$ResultSummary{TimeTaken} s</td></tr>\n";
            print "<tr><td>Time:     </td><td>$ResultSummary{Time}</td></tr>\n";
            print "<tr><td>Timestamp:</td><td>$ResultSummary{Timestamp}</td></tr>\n";
            print "<tr><td>Host:     </td><td>$ResultSummary{Host}</td></tr>\n";
            print "<tr><td>Perl:     </td><td>$ResultSummary{Perl}</td></tr>\n";
            print "<tr><td>OS:       </td><td>$ResultSummary{OS}</td></tr>\n";
            print "<tr><td>Vendor:   </td><td>$ResultSummary{Vendor}</td></tr>\n";
            print "<tr><td>Database: </td><td>$ResultSummary{Database}</td></tr>\n";
            print "<tr><td>TestOk:   </td><td>$ResultSummary{TestOk}</td></tr>\n";
            print "<tr><td>TestNotOk:</td><td>$ResultSummary{TestNotOk}</td></tr>\n";
            print "</table><br>\n";
        }
    }
    elsif ( $Self->{Output} eq 'ASCII' ) {
        if ( $Self->{Filename} ) {
            $Self->{Content} .= "=====================================================================\n";
            $Self->{Content} .= " Product:   $ResultSummary{Product}\n";
            $Self->{Content} .= " Test Time: $ResultSummary{TimeTaken} s\n";
            $Self->{Content} .= " Time:      $ResultSummary{Time}\n";
            $Self->{Content} .= " Timestamp: $ResultSummary{Timestamp}\n";
            $Self->{Content} .= " Host:      $ResultSummary{Host}\n";
            $Self->{Content} .= " Perl:      $ResultSummary{Perl}\n";
            $Self->{Content} .= " OS:        $ResultSummary{OS}\n";
            $Self->{Content} .= " Vendor:    $ResultSummary{Vendor}\n";
            $Self->{Content} .= " Database:  $ResultSummary{Database}\n";
            $Self->{Content} .= " TestOk:    $ResultSummary{TestOk}\n";
            $Self->{Content} .= " TestNotOk: $ResultSummary{TestNotOk}\n";
            if ( $ResultSummary{TestNotOk} ) {
                $Self->{Content} .= " FailedTests:\n";
                FAILEDFILE:
                for my $FailedFile ( @{ $Self->{NotOkInfo} || [] } ) {
                    my ( $File, @Tests ) = @{ $FailedFile || [] };
                    next FAILEDFILE if !@Tests;
                    $Self->{Content} .= sprintf "  %s #%s\n", $File, join ", ", @Tests;
                }
            }
            $Self->{Content} .= "=====================================================================\n";
        }
        else {
            print "=====================================================================\n";
            print " Product:   $ResultSummary{Product}\n";
            print " Test Time: $ResultSummary{TimeTaken} s\n";
            print " Time:      $ResultSummary{Time}\n";
            print " Timestamp: $ResultSummary{Timestamp}\n";
            print " Host:      $ResultSummary{Host}\n";
            print " Perl:      $ResultSummary{Perl}\n";
            print " OS:        $ResultSummary{OS}\n";
            print " Vendor:    $ResultSummary{Vendor}\n";
            print " Database:  $ResultSummary{Database}\n";
            print " TestOk:    $ResultSummary{TestOk}\n";
            print " TestNotOk: $ResultSummary{TestNotOk}\n";
            if ( $ResultSummary{TestNotOk} ) {
                print " FailedTests:\n";
                FAILEDFILE:
                for my $FailedFile ( @{ $Self->{NotOkInfo} || [] } ) {
                    my ( $File, @Tests ) = @{ $FailedFile || [] };
                    next FAILEDFILE if !@Tests;
                    print sprintf "  %s #%s\n", $File, join ", ", @Tests;
                }
            }
            print "=====================================================================\n";
        }
    }
    return 1;
}

sub _PrintHeadlineStart {
    my ( $Self, $Name ) = @_;

    # set default name
    $Name ||= '->>No Name!<<-';

    if ( $Self->{Output} eq 'HTML' ) {
        $Self->{HTMLContent} .= "<table width='600' border='1'>\n";
        $Self->{HTMLContent} .= "<tr><td colspan='2'>$Name</td></tr>\n";
    }
    elsif ( $Self->{Output} eq 'ASCII' ) {
        if ( $Self->{Filename} ) {
            $Self->{Content} .= "+-------------------------------------------------------------------+\n";
            $Self->{Content} .= "$Name:\n";
            $Self->{Content} .= "+-------------------------------------------------------------------+\n";
        }
        else {
            print "+-------------------------------------------------------------------+\n";
            print "$Name:\n";
            print "+-------------------------------------------------------------------+\n";
        }
    }

    $Self->{XMLUnit} = $Name;

    # set duration start time
    $Self->{DurationStartTime}->{$Name} = Time::HiRes::time();

    # set start timestamp
    $Self->{Timestamp}->{$Name} = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();

    return 1;
}

sub _PrintHeadlineEnd {
    my ( $Self, $Name ) = @_;

    # set default name
    $Name ||= '->>No Name!<<-';

    if ( $Self->{Output} eq 'HTML' ) {
        $Self->{HTMLContent} .= "</table><br>\n";
    }
    elsif ( $Self->{Output} eq 'ASCII' ) {
        if ( $Self->{Filename} ) {
            $Self->{Content} .= "\n";
        }
        else {
            print "\n";
        }
    }

    # calculate duration time
    my $Duration = '';
    if ( $Self->{DurationStartTime}->{$Name} ) {
        my $Diff = Time::HiRes::time() - $Self->{DurationStartTime}->{$Name};

        $Duration = sprintf("%.3f", $Diff);

        delete $Self->{DurationStartTime}->{$Name};
    }
    $Self->{Duration}->{$Name} = $Duration;

    return 1;
}

sub _Print {
    my ( $Self, $Test, $Name, $Message, $StartTime ) = @_;

    # prepare duration
    my $Duration = '';
    if ( $StartTime ) {
        my $Diff = Time::HiRes::time() - $StartTime;

        $Duration = sprintf("%.3f", $Diff);
    }

    $Name ||= '->>No Name!<<-';

    my $NameMessage  = $Name . ' (' . $Message . ')';
    my $PrintMessage = $NameMessage;
    if ( length $PrintMessage > 1000 ) {
        $PrintMessage = substr( $PrintMessage, 0, 1000 ) . "...";
    }

    if ( $Self->{Output} eq 'ASCII' && ( $Self->{Verbose} || !$Test ) ) {
        print { $Self->{OriginalSTDOUT} } $Self->{OutputBuffer};
    }
    $Self->{OutputBuffer} = '';

    $Self->{TestCount}++;
 
    $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ $Self->{TestCount} }->{Name}     = $Name;
    $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ $Self->{TestCount} }->{Message}  = $Message;
    $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ $Self->{TestCount} }->{Duration} = $Duration;
 
    if ($Test) {
        $Self->{TestCountOk}++;
        if ( $Self->{Output} eq 'HTML' ) {
            $Self->{HTMLContent} .= "<tr><td width='70' bgcolor='green'>ok $Self->{TestCount}</td><td>$NameMessage</td></tr>\n";
        }
        elsif ( $Self->{Output} eq 'ASCII' ) {
            if ( $Self->{Filename} ) {
                if ( $Self->{Verbose} ) {
                   $Self->{Content} .=  " ok $Self->{TestCount} - $PrintMessage\n";
                }
                else {
                    $Self->{Content} .=  ".";
                }
            }
            else {
                if ( $Self->{Verbose} ) {
                    print { $Self->{OriginalSTDOUT} } " "
                        . $Self->_Color( 'green', "ok" )
                        . " $Self->{TestCount} - $PrintMessage\n";
                }
                else {
                    print { $Self->{OriginalSTDOUT} } $Self->_Color( 'green', "." );
                }
            }
        }
        $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ $Self->{TestCount} }->{Result}   = 'ok';
 
        return 1;
    }
    else {
        $Self->{TestCountNotOk}++;
        if ( $Self->{Output} eq 'HTML' ) {
            $Self->{HTMLContent} .= "<tr><td width='70' bgcolor='red'>not ok $Self->{TestCount}</td><td>$NameMessage</td></tr>\n";
        }
        elsif ( $Self->{Output} eq 'ASCII' ) {
            if ( $Self->{Filename} ) {
                if ( !$Self->{Verbose} ) {
                    $Self->{Content} .= "\n";
                }
                $Self->{Content} .= " not ok $Self->{TestCount} - $PrintMessage\n";
            }
            else {
                if ( !$Self->{Verbose} ) {
                    print { $Self->{OriginalSTDOUT} } "\n";
                }
                print { $Self->{OriginalSTDOUT} } " "
                    . $Self->_Color( 'red', "not ok" )
                    . " $Self->{TestCount} - $PrintMessage\n";
            }
        }
        $Self->{XML}->{Test}->{ $Self->{XMLUnit} }->{ $Self->{TestCount} }->{Result}   = 'not ok';

        # Store information about failed tests, but only if we are running in a toplevel unit test object
        #   that is actually processing filed, and not in an embedded object that just runs individual tests.
        if ( ref $Self->{NotOkInfo} eq 'ARRAY' ) {
            my $TestFailureDetails = $NameMessage;
            $TestFailureDetails =~ s{\(.+\)$}{};
            if ( length $TestFailureDetails > 200 ) {
                $TestFailureDetails = substr( $TestFailureDetails, 0, 200 ) . "...";
            }
            push( @{ $Self->{NotOkInfo}->[-1] }, sprintf( "%s - %s", $Self->{TestCount}, $TestFailureDetails ) );
        }

        return;
    }
}

=item _Color()

this will color the given text (see Term::ANSIColor::color()) if
ANSI output is available and active, otherwise the text stays unchanged.

    my $PossiblyColoredText = $CommandObject->_Color('green', $Text);

=cut

sub _Color {
    my ( $Self, $Color, $Text ) = @_;

    return $Text if !$Self->{ANSI};
    return Term::ANSIColor::color($Color) . $Text . Term::ANSIColor::color('reset');
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
