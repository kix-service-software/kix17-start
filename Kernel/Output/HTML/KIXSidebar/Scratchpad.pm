# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::Scratchpad;

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
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Content;

    if ( $Param{Frontend} eq 'Agent' ) {

        my %Notes = $TicketObject->TicketNotesGet(
            TicketID => $Param{TicketID},
            UserID   => $Self->{UserID}
        );
        $Content = $LayoutObject->Output(
            TemplateFile => 'AgentKIXSidebarScratchpad',
            Data         => {
                %{ $Self->{Config} },
                %Param,
                Notes => $Notes{ $Param{TicketID} } || '',
            },
            KeepScriptTags => $Param{AJAX},
        );

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
