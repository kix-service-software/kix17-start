# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Time::VacationDay::RepentancePrayer;

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

    # use year index number (source: http://manfred.wilzeck.de/Datum_berechnen.html#Jahreszahl)
    my $Year = $Param{Year};
    my $Jx   = ( $Year + int( $Year / 4 ) - int( $Year / 100 ) + int( $Year / 400 ) ) % 7;

    # get day and month
    my $Month = 1;
    my $Day   = 22 - $Jx;

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
