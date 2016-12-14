# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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
