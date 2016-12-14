# --
# Kernel/System/Ticket/TicketExtensionsKIX4OTRSITSMIncidentProblem.pm - KIX4OTRS ticket changes
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Ralf(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketExtensionsKIX4OTRSITSMIncidentProblem;

use strict;
use warnings;

use Kernel::System::GeneralCatalog;

=item TicketCriticalityStringGet()

Returns the tickets criticality string value.

  $TicketObject->TicketCriticalityStringGet(
      %TicketData,
      %CustomerData,
      %ResponsibleData,
  );

=cut

sub TicketCriticalityStringGet {
    my ( $Self, %Param ) = @_;
    my $RetVal = "-";

    if ( !$Self->{GeneralCatalogObject} ) {
        $Self->{GeneralCatalogObject} = Kernel::System::GeneralCatalog->new( %{$Self} );
    }

    foreach (qw(TicketID UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( $Param{DynamicField_TicketFreeText13} ) {
        my $CriticalityList = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Criticality',
        );
        $RetVal = $CriticalityList->{ $Param{DynamicField_TicketFreeText13} };
    }

    return $RetVal;

}

=item TicketImpactStringGet()

Returns the tickets impact string value.

  $TicketObject->TicketImpactStringGet(
      %TicketData,
      %CustomerData,
      %ResponsibleData,
  );

=cut

sub TicketImpactStringGet {
    my ( $Self, %Param ) = @_;
    my $RetVal = "-";

    if ( !$Self->{GeneralCatalogObject} ) {
        $Self->{GeneralCatalogObject} = Kernel::System::GeneralCatalog->new( %{$Self} );
    }

    foreach (qw(TicketID UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( $Param{DynamicField_TicketFreeText14} ) {

        # get impact list
        my $ImpactList = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Impact',
        );
        $RetVal = $ImpactList->{ $Param{DynamicField_TicketFreeText14} };
    }

    return $RetVal;

}

# disable redefine warnings in this scope
{
    no warnings 'redefine';

    # reset all warnings
}

1;
