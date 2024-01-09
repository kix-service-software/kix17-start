# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
