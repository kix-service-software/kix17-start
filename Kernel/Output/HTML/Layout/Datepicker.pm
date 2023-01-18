# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::Datepicker;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::ObjectManager;

=head1 NAME

Kernel::Output::HTML::Layout::Datepicker - Datepicker data

=head1 SYNOPSIS

All valid functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item DatepickerGetVacationDays()

Returns a hash of all vacation days defined in the system.

    $LayoutObject->DatepickerGetVacationDays();

=cut

sub DatepickerGetVacationDays {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');

    # get the defined vacation days
    my $TimeVacationDays        = $ConfigObject->Get('TimeVacationDays');
    if ( $Param{Calendar} ) {
        if ( $ConfigObject->Get( "TimeZone::Calendar" . $Param{Calendar} . "Name" ) ) {
            $TimeVacationDays        = $ConfigObject->Get( "TimeVacationDays::Calendar" . $Param{Calendar} );
        }
    }

    # prepare moveable vacation days
    my $TimeVacationDaysOneTime;
    my ($CurrSec, $CurrMin, $CurrHour, $CurrDay, $CurrMonth, $CurrYear, $CurrWeekDay) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );
    my $FirstYear = $CurrYear - 1;
    my $LastYear  = $CurrYear + 10;
    for my $Year ( $FirstYear..$LastYear ) {
        $TimeVacationDaysOneTime->{ $Year } = $TimeObject->PrepareVacationDaysOfYear(
            Calendar => $Param{Calendar},
            Year     => $Year,
        );
    }

    # translate the vacation description if possible
    for my $Month ( sort keys %{$TimeVacationDays} ) {
        for my $Day ( sort keys %{ $TimeVacationDays->{$Month} } ) {
            $TimeVacationDays->{$Month}->{$Day}
                = $Self->{LanguageObject}->Translate( $TimeVacationDays->{$Month}->{$Day} );
        }
    }

    for my $Year ( sort keys %{$TimeVacationDaysOneTime} ) {
        for my $Month ( sort keys %{ $TimeVacationDaysOneTime->{$Year} } ) {
            for my $Day ( sort keys %{ $TimeVacationDaysOneTime->{$Year}->{$Month} } ) {
                $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day} = $Self->{LanguageObject}->Translate(
                    $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day}
                );
            }
        }
    }
    return {
        'TimeVacationDays'        => $TimeVacationDays,
        'TimeVacationDaysOneTime' => $TimeVacationDaysOneTime,
    };
}

sub HasDatepickerDirectSet {
    my ( $Self, %Param ) = @_;
    $Self->{HasDatepicker} = 1;
    return;
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
