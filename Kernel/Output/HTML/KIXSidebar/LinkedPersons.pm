# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::LinkedPersons;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Content;

    # get linked objects
    my $LinkListWithData = $LinkObject->LinkListWithData(
        Object  => 'Ticket',
        Key     => $Self->{TicketID},
        Object2 => 'Person',
        State   => 'Valid',
        UserID  => $Self->{UserID},
    );

    if (
        $LinkListWithData
        && $LinkListWithData->{Person}
        && ref( $LinkListWithData->{Person} ) eq 'HASH'
    ) {
        $LayoutObject->Block(
            Name => 'SidebarWidget',
            Data => {
                %{ $Self->{Config} },
            },
        );

        # output result
        my $Template = 'AgentKIXSidebarLinkedPersons';
        if ( $Param{Frontend} eq 'Customer' ) {
            $Template = 'CustomerKIXSidebarLinkedPersons';
        }
        $Content = $LayoutObject->Output(
            TemplateFile => $Template,
            Data         => {
                %{ $Self->{Config} },
            },
            KeepScriptTags => $Param{AJAX},
        );
    }

    else {
        $Content = '';
    }

    return $Content;
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
