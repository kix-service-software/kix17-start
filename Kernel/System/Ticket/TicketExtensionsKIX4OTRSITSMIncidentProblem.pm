# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketExtensionsKIX4OTRSITSMIncidentProblem;

use strict;
use warnings;

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

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # init return value
    my $RetVal = "-";

    # check if value is given
    if ( $Param{'DynamicField_ITSMCriticality'} ) {
        # get configuration of dynamicfield
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => 'ITSMCriticality',
        );

        # get display value
        my $ValueStrg = $BackendObject->DisplayValueRender(
            LayoutObject       => $LayoutObject,
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Param{'DynamicField_ITSMCriticality'},
            HTMLOutput         => 0,
        );
        $RetVal = $ValueStrg->{Value};
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

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # init return value
    my $RetVal = "-";

    # check if value is given
    if ( $Param{'DynamicField_ITSMImpact'} ) {
        # get configuration of dynamicfield
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            Name => 'ITSMImpact',
        );

        # get display value
        my $ValueStrg = $BackendObject->DisplayValueRender(
            LayoutObject       => $LayoutObject,
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Param{'DynamicField_ITSMImpact'},
            HTMLOutput         => 0,
        );
        $RetVal = $ValueStrg->{Value};
    }

    return $RetVal;
}

# disable redefine warnings in this scope
{
    no warnings 'redefine';

    # reset all warnings
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
