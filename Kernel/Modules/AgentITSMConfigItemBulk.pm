# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemBulk;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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

    # get needed objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UploadCacheObject   = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $EncodeObject        = $Kernel::OM->Get('Kernel::System::Encode');
    my $ConfigItemObject    = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');
    my $BulkExecutor        = $Kernel::OM->Get('Kernel::System::AsynchronousExecutor::ITSMBulkExecutor');

    # declare the variables for all the parameters
    my %Error;
    my %GetParam;
    my @Notify;

    $Param{FormID}     = $ParamObject->GetParam( Param => 'FormID' );
    if ( !$Param{FormID} ) {
        $Param{FormID} = $UploadCacheObject->FormIDCreate();
    }

    # get involved config items, filtering empty ConfigItemIDs
    my @ContentItems = $UploadCacheObject->FormIDGetAllFilesData(
        FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID},
    );

    if ( $Self->{Subaction} eq 'CancelAndClose' ) {
        $UploadCacheObject->FormIDRemove( FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID} );

        return $LayoutObject->PopupClose(
            URL => ( $Self->{LastScreenOverview} || 'Action=AgentDashboard' ),
        );
    }

    elsif ( $Self->{Subaction} eq 'DoEnd' ) {
        my $ActionFlag = $ParamObject->GetParam( Param => 'ActionFlag' );

        if ( $ActionFlag ) {
            $UploadCacheObject->FormIDRemove( FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID} );

            return $LayoutObject->PopupClose(
                URL => ( $Self->{LastScreenOverview} || 'Action=AgentDashboard' ),
            );
        } else {
            my @ContentItems = $UploadCacheObject->FormIDGetAllFilesData(
                FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID},
            );

            for my $Item (@ContentItems) {
                next if $Item->{Filename} ne 'GetParam';
                $Item->{Content} = $EncodeObject->Convert(
                    Text => $Item->{Content},
                    From => 'utf-8',
                    To   => 'iso-8859-1',
                );
                %GetParam = $JSONObject->Decode( Data => $Item->{Content});
            }
        }
    }

    # check if bulk feature is enabled
    if ( !$ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeature') ) {
        return $LayoutObject->ErrorScreen(
            Message => 'Bulk feature is not enabled!',
        );
    }

    my @ConfigItemIDs;
    for my $Item (@ContentItems) {
        next if $Item->{Filename} ne 'ItemIDs';
        $Item->{Content} = $EncodeObject->Convert(
            Text => $Item->{Content},
            From => 'utf-8',
            To   => 'iso-8859-1',
        );
        push(@ConfigItemIDs, split(',', $Item->{Content}));
    }

    # check needed stuff
    if ( !@ConfigItemIDs ) {
        return $LayoutObject->ErrorScreen(
            Message => 'No ConfigItemID is given!',
            Comment => 'You need at least one selected Configuration Item!',
        );
    }
    my $Output .= $LayoutObject->Header(
        Type => 'Small',
    );

    # get all parameters and check for errors
    if ( $Self->{Subaction} eq 'Do' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get all parameters
        for my $Key (
            qw( LinkTogether LinkTogetherAnother LinkType LinkTogetherLinkType DeplStateID
            InciStateID )
            )
        {
            $GetParam{$Key} = $ParamObject->GetParam( Param => $Key ) || '';
        }

        if ( $GetParam{'LinkTogetherAnother'} ) {
            $Kernel::OM->Get('Kernel::System::CheckItem')->StringClean(
                StringRef => \$GetParam{'LinkTogetherAnother'},
                TrimLeft  => 1,
                TrimRight => 1,
            );
            my $ConfigItemID = $ConfigItemObject->ConfigItemLookup(
                ConfigItemNumber => $GetParam{'LinkTogetherAnother'},
            );
            if ( !$ConfigItemID ) {
                $Error{'LinkTogetherAnotherInvalid'} = 'ServerError';
            }
        }
    }

    # process config item
    my @ConfigItemIDSelected;
    my @IgnoredConfigItemID;
    my $ActionFlag = 0;
    my $Counter    = 1;

    # get link object
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    CONFIGITEM_ID:
    for my $ConfigItemID (@ConfigItemIDs) {
        my $ConfigItem = $ConfigItemObject->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );

        my $Config = $ConfigObject->Get("ITSMConfigItem::Frontend::AgentITSMConfigItemEdit");

        # check permissions
        my $Access = $ConfigItemObject->Permission(
            Scope  => 'Item',
            ItemID => $ConfigItemID,
            UserID => $Self->{UserID},
            Type   => $Config->{Permission},
        );

        if ( !$Access ) {

            # error screen, don't show config item
            push(@Notify, $ConfigItem->{Number} . ': $Text{"You don\'t have write access to this configuration item."}');
            push(@IgnoredConfigItemID, $ConfigItemID);
            next CONFIGITEM_ID;
        }

        # remember selected config item ids
        push @ConfigItemIDSelected, $ConfigItemID;

        # do some actions on CIs
        if ( ( $Self->{Subaction} eq 'Do' ) && ( !%Error ) ) {

            # challenge token check for write action
            $LayoutObject->ChallengeTokenCheck();

            my %JobParam = (
                CallAction      => 'ITSMBulkDo',
                FormID          => $Param{FormID},
                ConfigItemID    => $ConfigItemID,
                Action          => $Self->{Action},
                UserID          => $Self->{UserID},
                GetParam        => \%GetParam,
                ConfigItemIDs   => \@ConfigItemIDs,
                Counter         => $Counter,
            );
            my $Success = $BulkExecutor->AsyncCall(
                ObjectName     => 'Kernel::System::AsynchronousExecutor::ITSMBulkExecutor',
                FunctionName   => 'Run',
                TaskName       => $Self->{Action} . '-' . $Param{FormID} . '-ITSMBulkDo',
                FunctionParams => \%JobParam,
                Attempts       => 1,
            );

            $ActionFlag = 1;
        }
        $Counter++;
    }

    if ( $Self->{Subaction} eq 'Do' && ( !%Error ) ) {
        my $FileID = $UploadCacheObject->FormIDAddFile(
            FormID      => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID},
            Filename    => 'GetParam',
            Content     => $JSONObject->Encode( Data => %GetParam),
            ContentType => 'text/xml',
        );

        return $LayoutObject->ProgressBar(
            MaxCount     => scalar @ConfigItemIDSelected,
            IgnoredCount => scalar @IgnoredConfigItemID,
            ItemCount    => scalar @ConfigItemIDs,

            TaskName     => $Self->{Action} . '-' . $Param{FormID} . '-ITSMBulkDo',
            TaskType     => 'AsynchronousExecutor',
            Action       => $Self->{Action},
            LoaderText   => 'Config items will be saved, please wait a moment...',
            Title        => 'ITSM ConfigItem Bulk Action',
            EndParam     => {
                UserID      => $Self->{UserID},
                FormID      => $Param{FormID},
                ActionFlag  => $ActionFlag,
                Subaction   => 'DoEnd',
            },
            FooterType   => 'Small',
            HeaderType   => 'Small',
        );
    }

    $Output .= $Self->_Mask(
        %Param,
        %GetParam,
        ConfigItemIDs => \@ConfigItemIDSelected,
        Errors        => \%Error,
    );

    $Output .= $LayoutObject->Footer(
        Type => 'Small',
    );
    return $Output;
}

sub _Mask {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # prepare errors!
    if ( $Param{Errors} ) {
        for my $KeyError ( sort keys %{ $Param{Errors} } ) {
            $Param{$KeyError} = $LayoutObject->Ascii2Html( Text => $Param{Errors}->{$KeyError} );
        }
    }

    $LayoutObject->Block(
        Name => 'BulkAction',
        Data => \%Param,
    );

    if ( $Param{Notify} ) {
        $LayoutObject->Block(
            Name => 'BulkNotify',
        );
        for my $Notify ( @{$Param{Notify}} ) {
            $LayoutObject->Block(
                Name => 'BulkNotifyRow',
                Data => {
                    Priority => 'Notice',
                    Notify   => $Notify
                }
            );
        }
    }

    # remember config item ids
    if ( $Param{ConfigItemIDs} ) {
        for my $ConfigItemID ( @{ $Param{ConfigItemIDs} } ) {
            $LayoutObject->Block(
                Name => 'UsedConfigItemID',
                Data => {
                    ConfigItemID => $ConfigItemID,
                },
            );
        }
    }

    # get needed objects
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');

    $Self->{Config} = $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}");

    # deployment state
    if ( $Self->{Config}->{DeplState} ) {
        my $DeplStateList = $GeneralCatalogObject->ItemList(
            Class => 'ITSM::ConfigItem::DeploymentState',
        );

        # generate DeplStateStrg
        $Param{DeplStateStrg} = $LayoutObject->BuildSelection(
            Data         => $DeplStateList,
            Name         => 'DeplStateID',
            PossibleNone => 1,
            SelectedID   => $Param{DeplStateID},
            Sort         => 'AlphanumericValue',
        );
        $LayoutObject->Block(
            Name => 'DeplState',
            Data => {%Param},
        );
    }

    # incident state
    if ( $Self->{Config}->{InciState} ) {

        # get incident state list
        my $InciStateList = $GeneralCatalogObject->ItemList(
            Class       => 'ITSM::Core::IncidentState',
            Preferences => {
                Functionality => [ 'operational', 'incident' ],
            },
        );

        # generate InciStateStrg
        $Param{InciStateStrg} = $LayoutObject->BuildSelection(
            Data         => $InciStateList,
            Name         => 'InciStateID',
            PossibleNone => 1,
            SelectedID   => $Param{InciStateID},
            Sort         => 'AlphanumericValue',
        );
        $LayoutObject->Block(
            Name => 'InciState',
            Data => {%Param},
        );
    }

    # get link object
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # link types list
    # get possible types list
    my %PossibleTypesList = $LinkObject->PossibleTypesList(
        Object1 => 'ITSMConfigItem',
        Object2 => 'ITSMConfigItem',
        UserID  => $Self->{UserID},
    );

    # define blank line entry
    my %BlankLine = (
        Key      => '-',
        Value    => '-------------------------',
        Disabled => 1,
    );

    # create the selectable type list
    my $Counter = 0;
    my @SelectableTypesList;
    my @LinkTogetherTypeList;
    POSSIBLETYPE:
    for my $PossibleType ( sort { lc $a cmp lc $b } keys %PossibleTypesList ) {

        # lookup type id
        my $TypeID = $LinkObject->TypeLookup(
            Name   => $PossibleType,
            UserID => $Self->{UserID},
        );

        # get type
        my %Type = $LinkObject->TypeGet(
            TypeID => $TypeID,
            UserID => $Self->{UserID},
        );

        # type list for link together can contain only
        # link types which are not directed (not pointed)
        if ( !$Type{Pointed} ) {

            # create the source name
            my %SourceName;
            $SourceName{Key}   = $PossibleType . '::Source';
            $SourceName{Value} = $Type{SourceName};

            push @LinkTogetherTypeList, \%SourceName;
        }

        # create the source name
        my %SourceName;
        $SourceName{Key}   = $PossibleType . '::Source';
        $SourceName{Value} = $Type{SourceName};

        push @SelectableTypesList, \%SourceName;

        next POSSIBLETYPE if !$Type{Pointed};

        # create the target name
        my %TargetName;
        $TargetName{Key}   = $PossibleType . '::Target';
        $TargetName{Value} = $Type{TargetName};

        push @SelectableTypesList, \%TargetName;
    }
    continue {

        # add blank line
        push @SelectableTypesList, \%BlankLine;

        $Counter++;
    }

    # removed last (empty) entry
    pop @SelectableTypesList;

    # add blank lines on top and bottom of the list if more then two linktypes
    if ( $Counter > 2 ) {
        unshift @SelectableTypesList, \%BlankLine;
        push @SelectableTypesList, \%BlankLine;
    }

    # generate LinkTypeStrg
    $Param{LinkTypeStrg} = $LayoutObject->BuildSelection(
        Data         => \@SelectableTypesList,
        Name         => 'LinkType',
        PossibleNone => 0,
        SelectedID   => $Param{TypeIdentifier} || 'AlternativeTo::Source',
        Sort         => 'AlphanumericValue',
    );
    $Param{LinkTogetherLinkTypeStrg} = $LayoutObject->BuildSelection(
        Data         => \@LinkTogetherTypeList,
        Name         => 'LinkTogetherLinkType',
        PossibleNone => 0,
        SelectedID   => $Param{TypeIdentifier} || 'AlternativeTo::Source',
        Sort         => 'AlphanumericValue',
    );

    $Param{LinkTogetherYesNoOption} = $LayoutObject->BuildSelection(
        Data       => $ConfigObject->Get('YesNoOptions'),
        Name       => 'LinkTogether',
        SelectedID => $Param{LinkTogether} || 0,
    );

    # get output back
    return $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemBulk',
        Data         => \%Param
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
