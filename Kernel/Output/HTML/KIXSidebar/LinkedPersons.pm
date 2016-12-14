# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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
        )
    {
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
