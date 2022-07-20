# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::OverviewCustom;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::Output::HTML::Layout'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = \%Param;
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create additional objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # check needed stuff
    for my $Needed (qw(PageShown StartHit)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # need ConfigItemIDs
    if ( !$Param{ConfigItemIDs} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need the ConfigItemIDs!',
        );
        return;
    }

    # define incident signals, needed for services
    my %InciSignals = (
        operational => 'greenled',
        warning     => 'yellowled',
        incident    => 'redled',
    );

    # build column header blocks
    my @PredefinedColumns = (
        "Name",         "Number",           "CurInciSignal", "Class",
        "CurDeplState", "CurDeplStateType", "CurInciState",  "CurInciStateType",
        "LastChanged",  "InciStateID",      "DeplStateID"
    );

    # create translation hash
    my %TranslationHash = (
        'CurDeplState'     => 'Deployment State',
        'CurDeplStateType' => 'Deployment State Type',
        'CurInciStateType' => 'Incident State Type',
        'CurInciState'     => 'Incident State',
        'LastChanged'      => 'Last changed',
        'CurInciSignal'    => 'Current Incident Signal',
        'CurDeplSignal'    => 'Current Deployment Signal'
    );

    # get columns
    my %CurrentUserData = $UserObject->GetUserData(
        UserID => $Self->{UserID},
    );

    # check ShowColumns parameter
    my @ShowColumns;
    if ( $Param{ShowColumns} && ref $Param{ShowColumns} eq 'ARRAY' ) {
        @ShowColumns = @{ $Param{ShowColumns} };
    }

    # meta items
    my @AvailableCols = ();
    if ( $CurrentUserData{ "UserCustomCILV-" . $Self->{Action} . "-" . $Param{TitleValue} } ) {
        @ShowColumns = split(
            /,/,
            $CurrentUserData{ "UserCustomCILV-" . $Self->{Action} . "-" . $Param{TitleValue} }
        );
    }

    if ( scalar @AvailableCols ) {
        @ShowColumns = @AvailableCols;
    }

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

    # store either ConfigItem IDs Locally
    my @ConfigItemIDs = @{ $Param{ConfigItemIDs} };
    my %ConfigItemTableData;
    my @ConfigItemIDsSorted;
    my $Counter = 1;

    # get needed un-/selected Config Items for bulk feature
    my @SelectedItems     = @{ $Param{SelectedItems} };
    my %SelectedItemsHash = map( { $_ => 1 } @SelectedItems );
    my @UnselectedItems   = @{ $Param{UnselectedItems} };

    # check if bulk feature is enabled
    my $BulkFeature = 0;
    if (
        $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeature')
        && (
            !defined $Param{ForceNoBulk}
            || !$Param{ForceNoBulk}
        )
    ) {
        my @Groups;
        if ( $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeatureGroup') ) {
            @Groups = @{ $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeatureGroup') };
        }
        if ( !@Groups ) {
            $BulkFeature = 1;
        }
        else {
            GROUP:
            for my $Group (@Groups) {
                next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
                if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                    $BulkFeature = 1;
                    last GROUP;
                }
            }
        }
    }

    # get config item pre menu modules
    my @ActionItems;
    if ( ref $ConfigObject->Get('ITSMConfigItem::Frontend::PreMenuModule') eq 'HASH' ) {
        my %Menus = %{ $ConfigObject->Get('ITSMConfigItem::Frontend::PreMenuModule') };

        MENU:
        for my $MenuKey ( sort( keys( %Menus ) ) ) {

            # load module
            if ( $Kernel::OM->Get('Kernel::System::Main')->Require( $Menus{$MenuKey}->{Module} ) ) {
                my $Object = $Menus{$MenuKey}->{Module}->new(
                    %{$Self},
                );

                # check if the menu is available
                next MENU if ref $Menus{$MenuKey} ne 'HASH';

                # set classes
                if ( $Menus{$MenuKey}->{Target} ) {

                    if ( $Menus{$MenuKey}->{Target} eq 'PopUp' ) {
                        $Menus{$MenuKey}->{MenuClass} = 'AsPopup';
                        $Menus{$MenuKey}->{PopupType} = 'ITSMConfigItemAction';
                    }
                    else {
                        $Menus{$MenuKey}->{MenuClass} = '';
                        $Menus{$MenuKey}->{PopupType} = '';
                    }
                }

                # grant access by default
                my $Access = 1;

                my $Action = $Menus{$MenuKey}->{Action};

                # can not execute the module due to a ConfigItem is required, then just check the
                # permissions as in the MenuModuleGeneric
                my $GroupsRo = $ConfigObject->Get('Frontend::Module')->{$Action}->{GroupRo} || [];
                my $GroupsRw = $ConfigObject->Get('Frontend::Module')->{$Action}->{Group}   || [];

                # check permission
                if ( $Action && ( @{$GroupsRo} || @{$GroupsRw} ) ) {

                    # deny access by default, when there are groups to check
                    $Access = 0;

                    # check read only groups
                    ROGROUP:
                    for my $RoGroup ( @{$GroupsRo} ) {

                        next ROGROUP if !$LayoutObject->{"UserIsGroupRo[$RoGroup]"};
                        next ROGROUP if $LayoutObject->{"UserIsGroupRo[$RoGroup]"} ne 'Yes';

                        # set access
                        $Access = 1;
                        last ROGROUP;
                    }

                    # check read write groups
                    RWGROUP:
                    for my $RwGroup ( @{$GroupsRw} ) {

                        next RWGROUP if !$LayoutObject->{"UserIsGroup[$RwGroup]"};
                        next RWGROUP if $LayoutObject->{"UserIsGroup[$RwGroup]"} ne 'Yes';

                        # set access
                        $Access = 1;
                        last RWGROUP;
                    }
                }

                # return if there is no access to the module
                next MENU if !$Access;

                # translate Name and Description
                my $Description = $LayoutObject->{LanguageObject}->Translate( $Menus{$MenuKey}->{Description} );
                my $Name        = $LayoutObject->{LanguageObject}->Translate( $Menus{$MenuKey}->{Description} );

                # generarte a web safe link
                my $Link = $LayoutObject->{Baselink} . $Menus{$MenuKey}->{Link};

                # sanity check
                if ( !defined $Menus{$MenuKey}->{MenuClass} ) {
                    $Menus{$MenuKey}->{MenuClass} = '';
                }

                # generate HTML for the menu item
                my $MenuHTML = << "END";
<li>
    <a href="$Link" class="$Menus{$MenuKey}->{MenuClass}" title="$Description">$Name</a>
</li>
END

                $MenuHTML =~ s/\n+//g;
                $MenuHTML =~ s/\s+/ /g;
                $MenuHTML =~ s/<\!--.+?-->//g;

                $Menus{$MenuKey}->{ID} = $Menus{$MenuKey}->{Name};
                $Menus{$MenuKey}->{ID} =~ s/(\s|&|;)//ig;

                push @ActionItems, {
                    HTML        => $MenuHTML,
                    ID          => $Menus{$MenuKey}->{ID},
                    Link        => $Link,
                    Target      => $Menus{$MenuKey}->{Target},
                    PopupType   => $Menus{$MenuKey}->{PopupType},
                    Description => $Description,
                };
            }
        }
    }

    # if SortBy is no predefined column get content for all ConfigItemIDs
    if (
        defined $Param{SortBy}
        && $Param{SortBy}
        && ( !grep { $Param{SortBy} eq $_ } @PredefinedColumns )
        && ( grep { $Param{SortBy} =~ m/$_/ } @ShowColumns )
    ) {
        for my $ConfigItemID (@ConfigItemIDs) {
            $ConfigItemTableData{$ConfigItemID} = $Self->_GetColumnContent(
                ConfigItemID      => $ConfigItemID,
                ShowColumns       => \@ShowColumns,
                PredefinedColumns => \@PredefinedColumns,
                InciSignals       => \%InciSignals,
                DeplSignals       => \%DeplSignals,
            );
        }
    }

    # else: use already sorted hash and get only content for current page
    else {

        # get content of columns
        for my $ConfigItemID (@ConfigItemIDs) {
            if (
                $Counter >= $Param{StartHit}
                && $Counter < ( $Param{PageShown} + $Param{StartHit} )
            ) {
                push( @ConfigItemIDsSorted, $ConfigItemID );

                $ConfigItemTableData{$ConfigItemID} = $Self->_GetColumnContent(
                    ConfigItemID      => $ConfigItemID,
                    ShowColumns       => \@ShowColumns,
                    PredefinedColumns => \@PredefinedColumns,
                    InciSignals       => \%InciSignals,
                    DeplSignals       => \%DeplSignals,
                );
            }
            last if $Counter == ( $Param{PageShown} + $Param{StartHit} );
            $Counter++;
        }
    }

    # create sort array using column data
    if (
        defined $Param{SortBy}
        && $Param{SortBy}
        && ( !grep { $Param{SortBy} eq $_ } @PredefinedColumns )
        && ( grep { $Param{SortBy} =~ m/$_/ } @ShowColumns )
    ) {
        my @SortArray;
        for my $ConfigItem ( keys %ConfigItemTableData ) {
            my %TmpHash = (
                Value => $ConfigItemTableData{$ConfigItem}->{ $Param{SortBy} }->{Value} || '',
                ConfigItemID => $ConfigItem
            );
            push @SortArray, \%TmpHash;
        }

        # sort data up
        @ConfigItemIDsSorted = map { $_->[1] }
            sort { $a->[0] cmp $b->[0] }
            map { [ $_->{Value}, $_ ] } @SortArray;

        # sort data down
        if ( $Param{OrderBy} eq 'Down' ) {
            @ConfigItemIDsSorted = reverse @ConfigItemIDsSorted;
        }

        # create data hash with sorted data
        @ConfigItemIDs = ();
        $Counter       = 0;
        for my $Row (@ConfigItemIDsSorted) {
            $Counter++;
            next if $Counter < $Param{StartHit};
            last if $Counter >= ( $Param{PageShown} + $Param{StartHit} );
            push @ConfigItemIDs, $Row->{ConfigItemID};
        }
    }
    else {
        @ConfigItemIDs = ();
        for my $Row (@ConfigItemIDsSorted) {
            push @ConfigItemIDs, $Row;
        }
    }

    # header
    if (@ShowColumns) {

        # show the bulk action button checkboxes if feature is enabled
        if ($BulkFeature) {
            push @ShowColumns, 'BulkAction';
        }

        for my $Column (@ShowColumns) {

            # create needed veriables
            my $CSS = 'OverviewHeader';
            my $OrderBy;

            # set class
            $CSS .= ' ' . $Column;

            # remove ID if necesary
            if ( $Param{SortBy} ) {
                $Param{SortBy} = ( $Param{SortBy} eq 'InciStateID' )
                    ? 'CurInciState'
                    : ( $Param{SortBy} eq 'DeplStateID' ) ? 'CurDeplState'
                    : ( $Param{SortBy} eq 'ClassID' )     ? 'Class'
                    : ( $Param{SortBy} eq 'ChangeTime' )  ? 'LastChanged'
                    :                                       $Param{SortBy};
            }

            # set the correct Set CSS class and order by link
            if ( $Param{SortBy} && ( $Param{SortBy} eq $Column ) ) {
                if ( $Param{OrderBy} && ( $Param{OrderBy} eq 'Up' ) ) {
                    $OrderBy = 'Down';
                    $CSS .= ' SortDescendingLarge';
                }
                else {
                    $OrderBy = 'Up';
                    $CSS .= ' SortAscendingLarge';
                }
            }
            else {
                $OrderBy = 'Up';
            }

            my $Translation;
            my @TranslationArray = ();
            my $TmpColumn        = $Column;
            my $ColumnSortBy;

            while ( $TmpColumn =~ m/^(.*?)::(.*)$/ ) {
                push @TranslationArray,
                    $LayoutObject->{LanguageObject}->Translate( $Param{TranslationRef}->{$1} )
                    || $1;
                $TmpColumn = $2;
            }
            push @TranslationArray,
                $LayoutObject->{LanguageObject}->Translate( $Param{TranslationRef}->{$TmpColumn} )
                || $TmpColumn;
            $Translation = join( "::", @TranslationArray );

            # get column name
            my $ColumnName = '';
            if ( $Column ne 'CurInciSignal' && $Column ne 'CurDeplSignal' && $Column ne 'Number' ) {
                $ColumnName = $TranslationHash{$Column} || $Translation || $Column
            }
            elsif ( $Column eq 'Number' ) {
                $ColumnName = 'ConfigItem#'
            }

            # get sort by
            if ( $Column eq 'CurInciSignal' || $Column eq 'CurInciState' ) {
                $ColumnSortBy = 'InciStateID';
            }
            elsif ( $Column eq 'CurDeplState' ) {
                $ColumnSortBy = 'DeplStateID';
            }
            elsif ( $Column eq 'LastChanged' ) {
                $ColumnSortBy = 'ChangeTime';
            }
            else {
                $ColumnSortBy = $Column;
            }

            if ( $Column ne 'BulkAction' ) {
                $LayoutObject->Block(
                    Name => 'RecordCustomHeader',
                    Data => {
                        %Param,
                        CSS        => $CSS,
                        OrderBy    => $OrderBy,
                        ColumnName => $ColumnName,
                        Column     => $Column,
                    },
                );

                $LayoutObject->Block(
                    Name => 'RecordCustomHeaderLinkStart',
                    Data => {
                        %Param,
                        OrderBy      => $OrderBy,
                        Column       => $Column,
                        ColumnSortBy => $ColumnSortBy,
                    },
                );
                $LayoutObject->Block(
                    Name => 'RecordCustomHeaderLinkEnd',
                    Data => {
                    },
                );
            }
            else {
                my $ItemALLChecked = '';
                my $SelectedAll    = '';

                if ( !scalar( @UnselectedItems ) ) {
                    $ItemALLChecked = ' checked="checked"';
                }

                if ( $Param{AllHits} > $Param{PageShown} ) {
                    $SelectedAll = 'SelectAllItemsPages';
                }

                $LayoutObject->Block(
                    Name => 'RecordBulkActionHeader',
                    Data => {
                        ItemALLChecked  => $ItemALLChecked,
                        SelectedAll     => $SelectedAll
                    },
                );
            }
        }
    }

    my $Output = '';

    # show config items if there are some
    if (@ConfigItemIDs) {

        # to store all data
        my %Data;
        my $BulkActivate = 0;

        CONFIGITEMID:
        for my $ConfigItemID (@ConfigItemIDs) {

            # check for access rights
            my $HasAccess = $ConfigItemObject->Permission(
                Scope  => 'Item',
                ItemID => $ConfigItemID,
                UserID => $Self->{UserID},
                Type   => $Self->{Config}->{Permission},
            );

            next CONFIGITEMID if !$HasAccess;

            %Data = %{ $ConfigItemTableData{$ConfigItemID} };

            # build record block
            $LayoutObject->Block(
                Name => 'Record',
                Data => {
                    %Param,
                    %Data,
                    ConfigItemID => $ConfigItemID,
                },
            );

            my $StateHighlighting
                = $ConfigObject->Get('ConfigItemOverview::HighlightMapping');
            if (
                $StateHighlighting
                && ref($StateHighlighting) eq 'HASH'
                && $StateHighlighting->{ $Data{CurDeplState} }
            ) {
                $Data{LineStyle} = $StateHighlighting->{ $Data{CurDeplState} };
            }

            # build column record blocks
            if (@ShowColumns) {
                for my $Column (@ShowColumns) {

                    if ( $Column ne 'BulkAction' ) {
                        $LayoutObject->Block(
                            Name => 'RecordCustom',
                            Data => {
                                Key   => $Column,
                                Value => $ConfigItemTableData{$ConfigItemID}->{$Column}->{Value},
                                Title => $ConfigItemTableData{$ConfigItemID}->{$Column}->{Title},
                                }
                        );

                        # show links if available
                        $LayoutObject->Block(
                            Name => 'RecordCustomLinkStart',
                            Data => {
                                %Param,
                                %Data,
                            },
                        );
                        $LayoutObject->Block(
                            Name => 'RecordCustomLinkEnd',
                            Data => {
                                %Param,
                                %Data,
                            },
                        );

                    }
                    else {
                        my $ItemChecked = '';

                        if ( $SelectedItemsHash{ $ConfigItemID } ) {
                            $ItemChecked = ' checked="checked"';
                        }

                        $LayoutObject->Block(
                            Name => 'RecordBulkAction',
                            Data => {
                                %Data,
                                %Param,
                                ConfigItemID => $ConfigItemID,
                                ItemChecked  => $ItemChecked,
                            }
                        );
                        if (
                            !$BulkActivate
                            && $ItemChecked
                        ) {
                            $BulkActivate = 1;
                            $LayoutObject->Block(
                                Name => 'BulkActivate',
                            );
                        }
                    }
                }

                # make a deep copy of the action items to avoid changing the definition
                my $ClonedActionItems = Storable::dclone( \@ActionItems );

                # substitute TT variables
                for my $ActionItem ( @{$ClonedActionItems} ) {
                    $ActionItem->{HTML} =~ s{ \Q[% Data.ConfigItemID | html %]\E }{$ConfigItemID}xmsg;
                    $ActionItem->{HTML} =~ s{ \Q[% Data.VersionID | html %]\E }{$Data{VersionID}}xmsg;
                    $ActionItem->{Link} =~ s{ \Q[% Data.ConfigItemID | html %]\E }{$ConfigItemID}xmsg;
                    $ActionItem->{Link} =~ s{ \Q[% Data.VersionID | html %]\E }{$Data{VersionID}}xmsg;
                }

                my $JSON = $LayoutObject->JSONEncode(
                    Data => $ClonedActionItems,
                );

                $LayoutObject->Block(
                    Name => 'DocumentReadyActionRowAdd',
                    Data => {
                        ConfigItemID => $ConfigItemID,
                        Data         => $JSON,
                    },
                );
            }
        }
    }

    # if there are no config items to show, a no data found message is displayed in the table
    else {
        $LayoutObject->Block(
            Name => 'NoDataFoundMsg',
            Data => {
                TotalColumns => scalar @ShowColumns,
            },
        );
    }

    my $FixedOverviewControl
        = $ConfigObject->Get('ITSMConfigItem::Frontend::FixedOverviewControl');

    if ($FixedOverviewControl) {
        $LayoutObject->Block(
            Name => 'ActivateFixedOverviewControl',
        );
    }

    # use template
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemOverviewCustom',
        Data         => {
            %Param,
            Type         => $Self->{ViewType},
            ColumnCount  => scalar @ShowColumns,
            StyleClasses => $StyleClasses,
        },
    );

    return $Output;
}

=item _GetColumnContent()

gets the content of each column per config item ID

    use Kernel::Config;
    #...use and instantiate lots of objects...

    my $Content = $Self->_GetColumnContent(
        ConfigItemID      => $ConfigItemID,
        ShowColumns       => \@ShowColumns,
        PredefinedColumns => \@PredefinedColumns,
        InciSignals       => \%InciSignals,
    );

=cut

sub _GetColumnContent {
    my ( $Self, %Param ) = @_;

    # create additional objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $HTMLUtilsObject      = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for (qw(ConfigItemID ShowColumns PredefinedColumns)) {
        if ( !defined( $Param{$_} ) ) {
            $LogObject->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get config item data
    my $ConfigItem = $ConfigItemObject->VersionGet(
        ConfigItemID => $Param{ConfigItemID},
        XMLDataGet   => 1,
    );
    return if !$ConfigItem;

    # store config item data,
    my %DataHash = %{$ConfigItem};

    my $StateHighlighting
        = $ConfigObject->Get('ConfigItemOverview::HighlightMapping');
    if (
        $StateHighlighting
        && ref($StateHighlighting) eq 'HASH'
        && $StateHighlighting->{ $ConfigItem->{CurDeplState} }
    ) {
        $DataHash{LineStyle}
            = $StateHighlighting->{ $ConfigItem->{CurDeplState} };
    }

    # build column record blocks
    if ( @{ $Param{ShowColumns} } ) {

        for my $Column ( @{ $Param{ShowColumns} } ) {

            my $Content;
            my $SubColumn = $Column;
            if ( $Column =~ m/^(.*)::(.*?)$/ ) {
                $SubColumn = $2;
            }

            # get content of special class attributes if shown
            if (
                !grep { $SubColumn eq $_ }
                @{ $Param{PredefinedColumns} }
            ) {
                $Content = join(
                    ",",
                    @{
                        $ConfigItemObject->GetAttributeValuesByKey(
                            KeyName       => $SubColumn,
                            XMLData       => $ConfigItem->{XMLData}->[1]->{Version}->[1],
                            XMLDefinition => $ConfigItem->{XMLDefinition},
                            )
                        }
                );
            }
            else {
                $Content = $ConfigItem->{$Column};
            }

            # create translated column content
            my $ColumnContent;
            my $ColumnTitle;
            if ( $Column eq 'CurInciSignal' ) {
                $ColumnContent = '<div class="Flag Small CustomFlag">'
                    . '<span class="'
                    . $Param{InciSignals}->{ $ConfigItem->{CurInciStateType} }
                    . '">'
                    . $ConfigItem->{CurInciState} . '"</span>'
                    . '</div>';
                $ColumnTitle = $LayoutObject->{LanguageObject}->Translate('Current Incident State');
            }
            elsif ( $Column eq 'CurDeplSignal' ) {
                my $DeplStateClass = $Param{DeplSignals}->{ $ConfigItem->{CurDeplState} } || '';
                $ColumnContent = '<div class="Flag Small CustomFlag">'
                    . '<span class="'
                    . $DeplStateClass
                    . '">'
                    . $ConfigItem->{CurDeplState} . '"</span>'
                    . '</div>';
                $ColumnTitle = $LayoutObject->{LanguageObject}->Translate('Current Deployment State');
            }
            elsif ( $Column eq 'LastChanged' ) {
                $ColumnContent = $LayoutObject->{LanguageObject}
                    ->FormatTimeString( $ConfigItem->{CreateTime} );
                $ColumnTitle = $LayoutObject->{LanguageObject}->Translate('Last Changed');
            }
            else {
                $ColumnContent = $ConfigItem->{$Column} || $Content;
                $ColumnTitle = $LayoutObject->{LanguageObject}->Translate($Column);
                if ( $Column =~ m/(State|Class)/ ) {
                    $ColumnContent = $LayoutObject->{LanguageObject}->Translate($ColumnContent);
                }
                $ColumnContent = $HTMLUtilsObject->ToHTML( String => $ColumnContent );
            }

            # store config item table data
            my %Tmp = (
                Value => $ColumnContent,
                Title => $Param{ConfigItemID} . '::' . $ColumnTitle,
            );
            $DataHash{$Column} = \%Tmp;
        }
    }

    return \%DataHash;
}

1;

=back

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
