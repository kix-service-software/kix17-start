# --
# Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::AgentOverlay;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $AgentOverlayObject = $Kernel::OM->Get('Kernel::System::AgentOverlay');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %OverlayList = $AgentOverlayObject->AgentOverlayList(
        UserID => $Self->{UserID},
    );

    # show content rows
    for my $OverlayID ( sort { $a <=> $b } ( keys ( %OverlayList ) ) ) {

        my %Overlay = $AgentOverlayObject->AgentOverlayGet(
            OverlayID => $OverlayID,
        );

        $LayoutObject->Block(
            Name => 'ContentSmallOverlayOverviewRow',
            Data => \%Overlay,
        );
    }

    # fill-up if no content exists
    if ( !scalar( keys( %OverlayList ) ) ) {
        $LayoutObject->Block(
            Name => 'ContentSmallOverlayOverviewNone',
            Data => {},
        );
    }

    # render content
    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardOverlayOverview',
        Data         => {
            %{ $Self->{Config} },
        },
    );

    # return content
    return $Content;
}

1;
