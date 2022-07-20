# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemZoomTabConfigItem;

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

    # get last version
    my $LastVersion = $VersionList->[-1];
    $LayoutObject->Block(
        Name => 'TabContent',
        Data => {
            %{$LastVersion},
            %{$ConfigItem},
            CurInciSignal => $InciSignals{ $LastVersion->{CurInciStateType} },
        },
    );

    # build version tree
    $LayoutObject->Block( Name => 'Tree' );
    my $Counter = 1;
    if ( !$Param{ShowVersions} && $VersionID eq $VersionList->[-1]->{VersionID} ) {
        $Counter     = @{$VersionList};
        $VersionList = [ $VersionList->[-1] ];
    }

    # output version tree header
    if ( $Param{ShowVersions} ) {
        $LayoutObject->Block(
            Name => 'Collapse',
            Data => {
                ConfigItemID => $ConfigItemID,
            },
        );
    }
    else {
        $LayoutObject->Block(
            Name => 'Expand',
            Data => {
                ConfigItemID => $ConfigItemID,
            },
        );
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    # output version tree
    for my $VersionHash ( @{$VersionList} ) {

        my %UserInfo = $UserObject->GetUserData(
            UserID => $VersionHash->{CreateBy},
            Cached => 1,
        );

        $ConfigItem->{'CreateByUserFullName'}
            = $UserInfo{UserLogin} . ' ('
            . $UserInfo{UserFirstname} . ' '
            . $UserInfo{UserLastname} . ')';

        $LayoutObject->Block(
            Name => 'TreeItem',
            Data => {
                %Param,
                %UserInfo,
                %{$ConfigItem},
                %{$VersionHash},
                Count      => $Counter,
                InciSignal => $InciSignals{ $VersionHash->{InciStateType} },
                DeplSignal => $DeplSignals{ $VersionHash->{DeplState} },
                Active     => $VersionHash->{VersionID} eq $VersionID ? 'Active' : '',
            },
        );

        $Counter++;
    }

    # get version
    my $Version = $ConfigItemObject->VersionGet(
        VersionID => $VersionID,
    );

    if (
        $Version
        && ref $Version eq 'HASH'
        && $Version->{XMLDefinition}
        && $Version->{XMLData}
        && ref $Version->{XMLDefinition} eq 'ARRAY'
        && ref $Version->{XMLData} eq 'ARRAY'
        && $Version->{XMLData}->[1]
        && ref $Version->{XMLData}->[1] eq 'HASH'
        && $Version->{XMLData}->[1]->{Version}
        && ref $Version->{XMLData}->[1]->{Version} eq 'ARRAY'
    ) {

        # transform ascii to html
        $Version->{Name} = $LayoutObject->Ascii2Html(
            Text           => $Version->{Name},
            HTMLResultMode => 1,
            LinkFeature    => 1,
        );

        # output name
        $LayoutObject->Block(
            Name => 'Data',
            Data => {
                Name        => 'Name',
                Description => 'The name of this config item',
                Value       => $Version->{Name},
                Identation  => 10,
            },
        );

        # output deployment state
        $LayoutObject->Block(
            Name => 'Data',
            Data => {
                Name        => 'Deployment State',
                Description => 'The deployment state of this config item',
                Value       => $LayoutObject->{LanguageObject}->Translate(
                    $Version->{DeplState},
                ),
                Identation => 10,
            },
        );

        # output incident state
        $LayoutObject->Block(
            Name => 'Data',
            Data => {
                Name        => 'Incident State',
                Description => 'The incident state of this config item',
                Value       => $LayoutObject->{LanguageObject}->Translate(
                    $Version->{InciState},
                ),
                Identation => 10,
            },
        );

        # start xml output
        $Self->_XMLOutput(
            XMLDefinition => $Version->{XMLDefinition},
            XMLData       => $Version->{XMLData}->[1]->{Version}->[1],
        );
    }

    my @Attachments = $ConfigItemObject->ConfigItemAttachmentList(
        ConfigItemID => $ConfigItemID,
    );

    if (@Attachments) {

        # get the metadata of the 1st attachment
        my $FirstAttachment = $ConfigItemObject->ConfigItemAttachmentGet(
            ConfigItemID => $ConfigItemID,
            Filename     => $Attachments[0],
        );

        $LayoutObject->Block(
            Name => 'Attachments',
            Data => {
                ConfigItemID => $ConfigItemID,
                Filename     => $FirstAttachment->{Filename},
                Filesize     => $FirstAttachment->{Filesize},
            },
        );

        # the 1st attachment was directly rendered into the 1st row's right cell, all further
        # attachments are rendered into a separate row
        ATTACHMENT:
        for my $Attachment (@Attachments) {

            # skip the 1st attachment
            next ATTACHMENT if $Attachment eq $Attachments[0];

            # get the metadata of the current attachment
            my $AttachmentData = $ConfigItemObject->ConfigItemAttachmentGet(
                ConfigItemID => $ConfigItemID,
                Filename     => $Attachment,
            );

            $LayoutObject->Block(
                Name => 'AttachmentRow',
                Data => {
                    ConfigItemID => $ConfigItemID,
                    Filename     => $AttachmentData->{Filename},
                    Filesize     => $AttachmentData->{Filesize},
                },
            );
        }
    }

    # handle DownloadAttachment
    if ( $Self->{Subaction} eq 'DownloadAttachment' ) {

        # get data for attachment
        my $Filename = $ParamObject->GetParam( Param => 'Filename' );
        my $AttachmentData = $ConfigItemObject->ConfigItemAttachmentGet(
            ConfigItemID => $ConfigItemID,
            Filename     => $Filename,
        );

        # return error if file does not exist
        if ( !$AttachmentData ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Message  => "No such attachment ($Filename)!",
                Priority => 'error',
            );
            return $LayoutObject->ErrorScreen();
        }

        return $LayoutObject->Attachment(
            %{$AttachmentData},
            Type => 'attachment',
        );
    }

    # store last screen
    # add session information
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

    # check if the browser sends the session id cookie
    # if not, add the session id to the url
    my $SessionID = '';
    if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
        $SessionID = ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
    }

    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $Self->{RequestedURL},
    );

    # start template output
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemZoomTabConfigItem',

        Data => {
            %{$LastVersion},
            %{$ConfigItem},
            CurInciSignal => $InciSignals{ $LastVersion->{CurInciStateType} },
            Session       => $SessionID,
        },
    );

    # add footer
    $Output .= $LayoutObject->Footer( Type => 'TicketZoomTab' );

    return $Output;
}

sub _XMLOutput {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLData};
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLData} ne 'HASH';
    return if ref $Param{XMLDefinition} ne 'ARRAY';

    $Param{Level} ||= 0;

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # stop loop, if no content was given
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # lookup value
            my $Value = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->XMLValueLookup(
                Item  => $Item,
                Value => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content},
            );

            # get layout object
            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

            # create output string
            $Value = $LayoutObject->ITSMConfigItemOutputStringCreate(
                Value => $Value,
                Item  => $Item,
                Key   => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
            );

            # calculate indentation for left-padding css based on 15px per level and 10px as default
            my $Indentation = 10;

            if ( $Param{Level} ) {
                $Indentation += 15 * $Param{Level};
            }

            # output data block
            $LayoutObject->Block(
                Name => 'Data',
                Data => {
                    Name        => $Item->{Name},
                    Description => $Item->{Description} || $Item->{Name},
                    Value       => $Value,
                    Indentation => $Indentation,
                },
            );

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                $Self->_XMLOutput(
                    XMLDefinition => $Item->{Sub},
                    XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                    Level         => $Param{Level} + 1,
                );
            }
        }
    }

    return 1;
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
