# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest::Utils;

use strict;
use warnings;

use Time::HiRes;

our $ObjectManagerDisabled = 1;

=item GetRandomNumber()

creates a random Number that can be used in tests as a unique identifier.

It is guaranteed that within a test this function will never return a duplicate.

Please note that these numbers are not really random and should only be used
to create test data.

=cut

# Use package variables here (instead of attributes in $Self)
# to make it work across several unit tests that run during the same second.
my %GetRandomNumberPrevious;

sub GetRandomNumber {

    my $PIDReversed = reverse $$;
    my $PID = reverse sprintf( '%.6d', $PIDReversed );

    my $Prefix = $PID . substr time(), -5, 5;

    if ( !defined( $GetRandomNumberPrevious{$Prefix} ) ) {
        $GetRandomNumberPrevious{$Prefix} = 0;
    }
    else {
        $GetRandomNumberPrevious{$Prefix} += 1;
    }

    return $Prefix . sprintf( '%04d', $GetRandomNumberPrevious{$Prefix} );
}

=item GetMilliTimeStamp()

returns the current time stamp in milliseconds

    my $MilliTimestamp = $UnitTestObject->GetMilliTimeStamp();

=cut
sub GetMilliTimeStamp {
    my ( $Self, %Param ) = @_;

    my $MilliTimestamp = int(Time::HiRes::time() * 1000);

    return $MilliTimestamp;
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
