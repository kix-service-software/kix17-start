# --
# Kernel/Modules/AgentOverlayPopup.pm - to prepare overlays for agent
# Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentOverlayPopup;
use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::AgentOverlay',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get objects
    $Self->{LayoutObject}       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{AgentOverlayObject} = $Kernel::OM->Get('Kernel::System::AgentOverlay');

    # check required objects...
    for (
        qw(UserID)
        )
    {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    return $Self;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my %OverlayList = $Self->{AgentOverlayObject}->AgentOverlayList(
        UserID => $Self->{UserID},
    );

    OVERLAYID:
    for my $OverlayID ( keys(%OverlayList) ) {
        next OVERLAYID if (!$OverlayList{$OverlayID});

        # get overlay
        my %Overlay = $Self->{AgentOverlayObject}->AgentOverlayGet(
            OverlayID => $OverlayID,
        );

        # show overlay
        my $AdditionalJS = <<"END";
    alert('$Overlay{Message}');

END
        $Self->{LayoutObject}->AddJSOnDocumentComplete(
            Code => $AdditionalJS,
        );

        # mark as seen
        my $Success = $Self->{AgentOverlayObject}->AgentOverlaySeen(
            OverlayID => $OverlayID,
            UserID    => $Self->{UserID},
        );
        if (!$Success) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Could not mark overlay_id ' . $OverlayID . ' as seen for user_id ' . $Self->{UserID},
            );
        }
    }

    return;
}

1;
