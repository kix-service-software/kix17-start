# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Time::VacationDay::WhitMonday;

use strict;
use warnings;

our @ObjectDependencies = ();

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # init return variable
    my %VacationDays = ();

    # check data
    if (
        !$Param{Name}
        || !$Param{Year}
    ) {
        return %VacationDays;
    }

    # use extended gauss eastern formular
    my $X  = $Param{Year};
    my $K  = int( $X / 100 );
    my $M  = int( 15 + ( 3 * $K + 3 ) / 4 ) - int( ( 8 * $K + 13 ) / 25 );
    my $S  = 2 - int( ( 3 * $K + 3 ) / 4 );
    my $A  = $X % 19;
    my $D  = ( 19 * $A + $M ) % 30;
    my $R  = int( ( $D + int( $A / 11 ) ) / 29 );
    my $OG = 21 + $D - $R;
    my $SZ = 7 - ( $X + int( $X / 4 ) + $S ) % 7;
    my $OE = 7 - ( $OG - $SZ ) % 7;
    my $OS = $OG + $OE;

    # get day and month
    my $Month = 3;
    my $Day   = $OS + 50;
    if ( $Day > 92 ) {
        $Day   -= 92;
        $Month += 3;
    }
    elsif ( $Day > 61 ) {
        $Day   -= 61;
        $Month += 2;
    }
    elsif ( $Day > 31 ) {
        $Day   -= 31;
        $Month += 1;
    }

    # add to return value
    $VacationDays{$Month}->{$Day} = $Param{Name};

    return %VacationDays;
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
