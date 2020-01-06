# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::ConfigItemInfo;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    $Self->{Config} = $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output;

    # create needed objects
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get params
    my $ConfigItemID = $ParamObject->GetParam( Param => 'ConfigItemID' ) || 0;
    my $VersionID    = $ParamObject->GetParam( Param => 'VersionID' )    || 0;

    # required further down in tab link generation...
    $Param{ConfigItemID} = $ConfigItemID;
    $Param{VersionID}    = $VersionID;

    # check needed stuff
    if ( !$ConfigItemID ) {
        return $LayoutObject->ErrorScreen(
            Message => "No ConfigItemID is given!",
            Comment => 'Please contact the admin.',
        );
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

    # get create user data
    my %CreateUser = $UserObject->GetUserData(
        UserID => $ConfigItem->{CreateBy},
        Cached => 1,
    );
    $ConfigItem->{'CreateByUserFullName'}
        = $CreateUser{UserLogin} . ' ('
        . $CreateUser{UserFirstname} . ' '
        . $CreateUser{UserLastname} . ')';

    # get change user data
    my %ChangeUser = $UserObject->GetUserData(
        UserID => $ConfigItem->{ChangeBy},
        Cached => 1,
    );
    $ConfigItem->{'ChangeByUserFullName'}
        = $ChangeUser{UserLogin} . ' ('
        . $ChangeUser{UserFirstname} . ' '
        . $ChangeUser{UserLastname} . ')';

    $Output = $LayoutObject->Output(
        TemplateFile => 'AgentKIXSidebarConfigItemInfo',
        Data         => {
            %{ $Self->{Config} },
            %{$LastVersion},
            %{$ConfigItem},
            CurInciSignal => $InciSignals{ $LastVersion->{CurInciStateType} },
            CurDeplSignal => $DeplSignals{ $LastVersion->{CurDeplState} },
        },
        KeepScriptTags => $Param{AJAX},
    );

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
