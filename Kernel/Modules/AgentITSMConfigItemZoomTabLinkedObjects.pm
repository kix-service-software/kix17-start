# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemZoomTabLinkedObjects;

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

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my $ConfigItemID = $ParamObject->GetParam( Param => 'ConfigItemID' ) || 0;
    my $VersionID    = $ParamObject->GetParam( Param => 'VersionID' )    || 0;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$ConfigItemID ) {
        return $LayoutObject->ErrorScreen(
            Message => "No ConfigItemID is given!",
            Comment => 'Please contact the admin.',
        );
    }

    # get needed object
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');

    # check for access rights
    my $HasAccess = $ConfigItemObject->Permission(
        Scope  => 'Item',
        ItemID => $ConfigItemID,
        UserID => $Self->{UserID},
        Type   => $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}")->{Permission},
    );

    if ( !$HasAccess ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => 'Can\'t show item, no access rights for ConfigItem are given!',
            Comment => 'Please contact the admin.',
        );
    }

    # set show versions
    $Param{ShowVersions} = 0;
    if ( $ParamObject->GetParam( Param => 'ShowVersions' ) ) {
        $Param{ShowVersions} = 1;
    }

    # get content
    my $ConfigItem = $ConfigItemObject->ConfigItemGet(
        ConfigItemID => $ConfigItemID,
    );
    if ( !$ConfigItem->{ConfigItemID} ) {
        return $LayoutObject->ErrorScreen(
            Message => "ConfigItemID $ConfigItemID not found in database!",
            Comment => 'Please contact the admin.',
        );
    }

    # get version list
    my $VersionList = $ConfigItemObject->VersionZoomList(
        ConfigItemID => $ConfigItemID,
    );
    if ( !$VersionList->[0]->{VersionID} ) {
        return $LayoutObject->ErrorScreen(
            Message => "No Version found for ConfigItemID $ConfigItemID!",
            Comment => 'Please contact the admin.',
        );
    }

    # set version id
    if ( !$VersionID ) {
        $VersionID = $VersionList->[-1]->{VersionID};
    }
    if ( $VersionID ne $VersionList->[-1]->{VersionID} ) {
        $Param{ShowVersions} = 1;
    }

    # set version id in param hash (only for menu module)
    if ($VersionID) {
        $Param{VersionID} = $VersionID;
    }

    # get last version
    my $LastVersion = $VersionList->[-1];

    # set incident signal
    my %InciSignals = (
        operational => 'greenled',
        warning     => 'yellowled',
        incident    => 'redled',
    );

    # to store the color for the deployment states
    my %DeplSignals;

    # get general catalog object
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # get list of deployment states
    my $DeploymentStatesList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    # set deployment style colors
    my $StyleClasses = '';

    ITEMID:
    for my $ItemID ( sort keys %{$DeploymentStatesList} ) {

        # get deployment state preferences
        my %Preferences = $GeneralCatalogObject->GeneralCatalogPreferencesGet(
            ItemID => $ItemID,
        );

        # check if a color is defined in preferences
        next ITEMID if !$Preferences{Color};

        # get deployment state
        my $DeplState = $DeploymentStatesList->{$ItemID};

        # remove any non ascii word characters
        $DeplState =~ s{ [^a-zA-Z0-9] }{_}msxg;

        # store the original deployment state as key
        # and the ss safe coverted deployment state as value
        $DeplSignals{ $DeploymentStatesList->{$ItemID} } = $DeplState;

        # covert to lower case
        my $DeplStateColor = lc $Preferences{Color};

        # add to style classes string
        $StyleClasses .= <<"END";
.Flag span.$DeplState {
    background-color: #$DeplStateColor;
}
END
    }

    # wrap into style tags
    if ($StyleClasses) {
        $StyleClasses = "<style>$StyleClasses</style>";
    }
    # get linked objects
    my $LinkListWithData = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkListWithData(
        Object => 'ITSMConfigItem',
        Key    => $ConfigItemID,
        State  => 'Valid',
        UserID => $Self->{UserID},
    );

    for my $LinkObject ( keys %{$LinkListWithData} ) {
        for my $LinkType ( keys %{ $LinkListWithData->{$LinkObject} } ) {
            for my $LinkDirection ( keys %{ $LinkListWithData->{$LinkObject}->{$LinkType} } ) {
                for my $LinkItem (
                    keys %{ $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection} }
                ) {
                    $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection}->{$LinkItem}
                        ->{SourceObject} = 'ITSMConfigItem';
                    $LinkListWithData->{$LinkObject}->{$LinkType}->{$LinkDirection}->{$LinkItem}
                        ->{SourceKey} = $ConfigItemID;
                }
            }
        }
    }

    # get link table view mode
    my $LinkTableViewMode = $ConfigObject->Get('LinkObject::ViewMode');

    # ask for rights to link config items
    my $LinkConfigItem = $ConfigItemObject->Permission(
        Scope  => 'Item',
        ItemID => $ConfigItemID,
        UserID => $Self->{UserID},
        Type   => 'rw',
    ) || 0;

    # get config of frontend module
    $Self->{Config} = $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}");

    # create quick link string
    if ( $Self->{Config}->{QuickLink} ) {
        my $QuickLinkStrg = $LayoutObject->BuildQuickLinkHTML(
            Object              => 'ITSMConfigItem',
            Key                 => $ConfigItemID,
            RefreshURL          => 'Action=' . $Self->{Action} . ';ConfigItemID=' . $ConfigItemID . ';SelectedTab=' . $ParamObject->GetParam( Param => 'TabIndex' ),
        );
        $LayoutObject->Block(
            Name => 'QuickLink',
            Data => {
                QuickLinkContent => $QuickLinkStrg,
            },
        );
    }

    # create the link table
    my $LinkTableStrg = $LayoutObject->LinkObjectTableCreate(
        LinkListWithData => $LinkListWithData,
        ViewMode         => $LinkTableViewMode . 'Delete',
        LinkConfigItem   => $LinkConfigItem,
        GetPreferences   => 0,
    );
    my $PreferencesLinkTableStrg = $LayoutObject->LinkObjectTableCreate(
        LinkListWithData => $LinkListWithData,
        ViewMode         => $LinkTableViewMode . 'Delete',
        LinkConfigItem   => $LinkConfigItem,
        GetPreferences   => 1,
    );

    $LayoutObject->Block(
        Name => 'TabContent',
        Data => {
            %{$LastVersion},
            %{$ConfigItem},
            CurInciSignal => $InciSignals{ $LastVersion->{CurInciStateType} },
        },
    );

    # output the link table
    if ($LinkTableStrg) {
        $LayoutObject->Block(
            Name => 'LinkTable',
            Data => {
                LinkTableStrg => $LinkTableStrg,
            },
        );
    }

    # store last screen
    if ( $Self->{CallingAction} ) {
        $Self->{RequestedURL} =~ s/DirectLinkAnchor=.+?(;|$)//;
        $Self->{RequestedURL} =~ s/CallingAction=.+?(;|$)//;
        $Self->{RequestedURL} =~ s/(^|;|&)Action=.+?(;|$)//;
        $Self->{RequestedURL}
            = "Action="
            . $Self->{CallingAction} . ";"
            . $Self->{RequestedURL} . "#"
            . $Self->{DirectLinkAnchor};
    }

    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $Self->{RequestedURL},
    );

    my $UserLanguage = $LayoutObject->{UserLanguage};

    # start template output
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemZoomTabLinkedObjects',
        Data         => {
            %{$LastVersion},
            %{$ConfigItem},
            CurInciSignal => $InciSignals{ $LastVersion->{CurInciStateType} },
            CurDeplSignal => $DeplSignals{ $LastVersion->{DeplState} },
            StyleClasses  => $StyleClasses,
            UserLanguage             => $UserLanguage,
            PreferencesLinkTableStrg => $PreferencesLinkTableStrg,
        },
    );

    # add footer
    $Output .= $LayoutObject->Footer( Type => 'TicketZoomTab' );

    return $Output;
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
