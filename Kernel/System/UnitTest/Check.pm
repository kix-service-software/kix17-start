# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest::Check;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

=item True()

test for a scalar value that evaluates to true.

Internally, the function receives this value and evaluates it to see
if it's true, returning 1 in this case or 0, otherwise.

    my $TrueResult = $UnitTestObject->True(
        TestName  => 'Name of test',
        TestValue => $TestValue,
        StartTime => 1534125612531,
    );

=cut
sub True {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{'TestName'} ) {
        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. True(\$A, \'Test Name\')!'
        );
        # add error as test step
        $Self->_AddTestStep(
            TestName   => '->>No Name!<<-',
            Success    => 0,
            Broken     => 1,
            Message    => 'Need Name! E. g. True(\$A, \'Test Name\')',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return;
    }

    # check for true value
    if ( $Param{'TestValue'} ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'True\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # false value
    else {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'False\', should be \'True\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
}

=item False()

test for a scalar value that evaluates to false.

It has the same interface as L</True()>, but tests
for false instead.

=cut
sub False {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{'TestName'} ) {
        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. False(\$A, \'Test Name\')!'
        );
        # add error as test step
        $Self->_AddTestStep(
            TestName   => '->>No Name!<<-',
            Success    => 0,
            Broken     => 1,
            Message    => 'Need Name! E. g. False(\$A, \'Test Name\')',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return;
    }

    # check for false value
    if ( !$Param{'TestValue'} ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'False\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # true value
    else {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'True\', should be \'False\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
}

=item Is()

compares two scalar values for equality.

Returns 1 if the values were equal, or 0 otherwise.

    my $IsResult = $UnitTestObject->Is(
        TestName   => 'Name of test',
        CheckValue => $TestValue,
        TestValue  => $TestValue,
        StartTime  => 1534125612531,
    );

=cut
sub Is {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{'TestName'} ) {
        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')!'
        );
        # add error as test step
        $Self->_AddTestStep(
            TestName   => '->>No Name!<<-',
            Success    => 0,
            Broken     => 1,
            Message    => 'Need Name! E. g. Is(\$A, \$B, \'Test Name\')',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return;
    }

    # CheckValue and TestValue are undef
    if (
        !defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'undef\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # CheckValue is undef and TestValue is defined
    elsif (
        !defined( $Param{'CheckValue'} )
        && defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'' . $Param{'TestValue'} . '\', should be \'undef\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
    # CheckValue is defined and TestValue is undef
    elsif (
        defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'undef\', should be \'' . $Param{'CheckValue'} . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
    # CheckValue equals TestValue
    elsif ( $Param{'CheckValue'} eq $Param{'TestValue'} ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'' . $Param{'TestValue'} . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # CheckValue not equals TestValue
    else {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'' . $Param{'TestValue'} . '\', should be \'' . $Param{'CheckValue'} . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
}

=item IsNot()

compares two scalar values for inequality.

It has the same interface as L</Is()>, but tests
for inequality instead.

=cut
sub IsNot {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{'TestName'} ) {
        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')!'
        );
        # add error as test step
        $Self->_AddTestStep(
            TestName   => '->>No Name!<<-',
            Success    => 0,
            Broken     => 1,
            Message    => 'Need Name! E. g. IsNot(\$A, \$B, \'Test Name\')',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return;
    }

    # CheckValue and TestValue are undef
    if (
        !defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'undef\', should be defined',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
    # CheckValue is undef and TestValue is defined
    elsif (
        !defined( $Param{'CheckValue'} )
        && defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'' . $Param{'TestValue'} . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # CheckValue is defined and TestValue is undef
    elsif (
        defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'undef\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # CheckValue equals TestValue
    elsif ( $Param{'CheckValue'} eq $Param{'TestValue'} ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'' . $Param{'TestValue'} . '\', should be different',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
    # CheckValue not equals TestValue
    else {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'' . $Param{'TestValue'} . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
}

=item IsDeeply()

compares complex data structures for equality.

Returns 1 if the data structures are the same, or 0 otherwise.

    my $IsDeeplyResult = $UnitTestObject->IsDeeply(
        TestName  => 'Name of test',
        CheckValue => \%ExpectedHash,
        TestValue  => \%ResultHash,
        StartTime => 1534125612531,
    );

=cut
sub IsDeeply {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{'TestName'} ) {
        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. IsDeeply(\$A, \$B, \'Test Name\')!'
        );
        # add error as test step
        $Self->_AddTestStep(
            TestName   => '->>No Name!<<-',
            Success    => 0,
            Broken     => 1,
            Message    => 'Need Name! E. g. IsDeeply(\$A, \$B, \'Test Name\')',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return;
    }

    # CheckValue and TestValue are undef
    if (
        !defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'undef\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # CheckValue is undef and TestValue is defined
    elsif (
        !defined( $Param{'CheckValue'} )
        && defined( $Param{'TestValue'} )
    ) {
        my $TestDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'TestValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'' . $TestDump . '\', should be \'undef\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
    # CheckValue is defined and TestValue is undef
    elsif (
        defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        my $CheckDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'CheckValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'undef\', should be \'' . $CheckDump . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }

    # process data
    my $Diff = $Self->_DataDiff(
        CheckValue => $Param{CheckValue},
        TestValue  => $Param{TestValue},
    );

    # data is not different
    if ( !$Diff ) {
        my $CheckDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'CheckValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'matches expected value \'' . $CheckDump . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # data is different
    else {
        my $CheckDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'CheckValue'});
        my $TestDump  = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'TestValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'' . $TestDump . '\', should be \'' . $CheckDump . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
}

=item IsNotDeeply()

compares two data structures for inequality.

It has the same interface as L</IsDeeply()>, but tests
for inequality instead.

=cut
sub IsNotDeeply {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{'TestName'} ) {
        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Name! E. g. IsNotDeeply(\$A, \$B, \'Test Name\')!'
        );
        # add error as test step
        $Self->_AddTestStep(
            TestName   => '->>No Name!<<-',
            Success    => 0,
            Broken     => 1,
            Message    => 'Need Name! E. g. IsNotDeeply(\$A, \$B, \'Test Name\')',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return;
    }

    # CheckValue and TestValue are undef
    if (
        !defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'is \'undef\', should be defined',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
    }
    # CheckValue is undef and TestValue is defined
    elsif (
        !defined( $Param{'CheckValue'} )
        && defined( $Param{'TestValue'} )
    ) {
        my $TestDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'TestValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'' . $TestDump . '\', differs from check structure \'undef\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # CheckValue is defined and TestValue is undef
    elsif (
        defined( $Param{'CheckValue'} )
        && !defined( $Param{'TestValue'} )
    ) {
        my $CheckDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'CheckValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'undef\', differs from check structure \'' . $CheckDump . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }

    # process data
    my $Diff = $Self->_DataDiff(
        CheckValue => $Param{CheckValue},
        TestValue  => $Param{TestValue},
    );

    # data is different
    if ( $Diff ) {
        my $CheckDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'CheckValue'});
        my $TestDump  = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'TestValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 1,
            Message    => 'is \'' . $TestDump . '\', check structure \'' . $CheckDump . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 1;
    }
    # data is not different
    else {
        my $TestDump  = $Kernel::OM->Get('Kernel::System::Main')->Dump($Param{'TestValue'});
        $Self->_AddTestStep(
            TestName   => $Param{'TestName'},
            Success    => 0,
            Message    => 'the structures are equal: \'' . $TestDump . '\'',
            StartTime  => $Param{'StartTime'},
            Caller     => 1,
        );
        return 0;
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
        CheckValue => \$CheckValue,
        TestValue  => \$TestValue,
    );

=cut
sub _DataDiff {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(CheckValue TestValue)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # CheckValue and TestValue are not references
    if (
        ref( $Param{CheckValue} ) eq ''
        && ref( $Param{TestValue} ) eq ''
    ) {
        # CheckValue and TestValue are undef
        if (
            !defined( $Param{CheckValue} )
            && !defined( $Param{TestValue} )
        ) {
            return;
        }

        # CheckValue or TestValue are undef
        if (
            !defined( $Param{CheckValue} )
            || !defined( $Param{TestValue} )
        ) {
            return 1;
        }

        # CheckValue not equals TestValue
        if ( $Param{CheckValue} ne $Param{TestValue} ) {
            return 1;
        }

        # CheckValue equals TestValue
        return;
    }

    # CheckValue and TestValue are SCALAR references
    if (
        ref( $Param{CheckValue} ) eq 'SCALAR'
        && ref( $Param{TestValue} ) eq 'SCALAR'
    ) {
        # CheckValue and TestValue are undef
        if (
            !defined( ${ $Param{CheckValue} } )
            && !defined( ${ $Param{TestValue} } )
        ) {
            return;
        }

        # CheckValue or TestValue are undef
        if (
            !defined( ${ $Param{CheckValue} } )
            || !defined( ${ $Param{TestValue} } )
        ) {
            return 1;
        }

        # CheckValue not equals TestValue
        if ( ${ $Param{CheckValue} } ne ${ $Param{TestValue} } ) {
            return 1;
        }

        # CheckValue equals TestValue
        return;
    }

    # CheckValue and TestValue are ARRAY references
    if (
        ref( $Param{CheckValue} ) eq 'ARRAY'
        && ref( $Param{TestValue} ) eq 'ARRAY'
    ) {
        # get arrays from ref
        my @A = @{ $Param{CheckValue} };
        my @B = @{ $Param{TestValue} };

        # scalar count is different
        if ( scalar(@A) != scalar(@B) ) {
            return 1;
        }

        # compare arrays
        INDEX:
        for my $Index ( 0 .. $#A ) {
            # get entries from arrays
            my $CheckValue = $A[$Index];
            my $TestValue  = $B[$Index];

            # both entries are undef
            if (
                !defined( $CheckValue )
                && !defined( $TestValue )
            ) {
                next INDEX;
            }

            # one entry is undef
            if (
                !defined( $CheckValue )
                || !defined( $TestValue )
            ) {
                return 1;
            }

            # entries are not equal
            if ( $CheckValue ne $TestValue ) {
                # entry of CheckValue is ARRAY or HASH reference
                if (
                    ref( $CheckValue ) eq 'ARRAY'
                    || ref( $CheckValue ) eq 'HASH'
                ) {
                    # check sub reference
                    my $SubDiff = $Self->_DataDiff(
                        CheckValue => $CheckValue,
                        TestValue  => $TestValue
                    );

                    # sub data is different
                    if ( $SubDiff ) {
                        return 1;
                    }

                    # sub data is equal
                    next INDEX;
                }

                # entries are different
                return 1;
            }
        }

        # CheckValue equals TestValue
        return;
    }

    # CheckValue and TestValue are HASH references
    if (
        ref( $Param{CheckValue} ) eq 'HASH'
        && ref( $Param{TestValue} ) eq 'HASH'
    ) {
        # get hashes from ref
        my %A = %{ $Param{CheckValue} };
        my %B = %{ $Param{TestValue} };

        # key count is different
        if ( keys(%A) != keys(%B) ) {
            return 1;
        }

        # compare hashes and remove it if checked
        KEY:
        for my $Key ( sort( keys( %A ) ) ) {
            # both entries are undef
            if (
                !defined( $A{$Key} )
                && !defined( $B{$Key} )
            ) {
                next KEY;
            }

            # one entry is undef
            if (
                !defined( $A{$Key} )
                || !defined( $B{$Key} )
            ) {
                return 1;
            }

            # entries are equal
            if ( $A{$Key} eq $B{$Key} ) {
                next KEY;
            }

            # entry of CheckValue is ARRAY or HASH reference
            if (
                ref( $A{$Key} ) eq 'ARRAY'
                || ref( $A{$Key} ) eq 'HASH'
            ) {
                # check sub reference
                my $SubDiff = $Self->_DataDiff(
                    CheckValue => $A{$Key},
                    TestValue  => $B{$Key}
                );

                # sub data is different
                if ( $SubDiff ) {
                    return 1;
                }

                # sub data is equal
                next KEY;
            }

            # entries are different
            return 1;
        }

        # CheckValue equals TestValue
        return;
    }

    # CheckValue and TestValue are REF references
    if (
        ref( $Param{CheckValue} ) eq 'REF'
        && ref( $Param{TestValue} ) eq 'REF'
    ) {
        # check sub reference
        my $SubDiff = $Self->_DataDiff(
            CheckValue => ${ $Param{CheckValue} },
            TestValue  => ${ $Param{TestValue} }
        );

        # sub data is different
        if ( $SubDiff ) {
            return 1;
        }

        # CheckValue equals TestValue
        return;
    }

    # CheckValue not equals TestValue
    return 1;
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
