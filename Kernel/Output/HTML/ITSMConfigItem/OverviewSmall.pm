# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::OverviewSmall;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::HTMLUtils',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

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

    # store either ConfigItem IDs Locally
    my @ConfigItemIDs = @{ $Param{ConfigItemIDs} };

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

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

                my %Safe = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
                    String       => $MenuHTML,
                    NoApplet     => 1,
                    NoObject     => 1,
                    NoEmbed      => 1,
                    NoSVG        => 1,
                    NoImg        => 1,
                    NoIntSrcLoad => 0,
                    NoExtSrcLoad => 1,
                    NoJavaScript => 1,
                );
                if ( $Safe{Replace} ) {
                    $MenuHTML = $Safe{String};
                }

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

    # check ShowColumns parameter
    my @ShowColumns;
    if ( $Param{ShowColumns} && ref $Param{ShowColumns} eq 'ARRAY' ) {
        @ShowColumns = @{ $Param{ShowColumns} };
    }
    # show the bulk action button checkboxes if feature is enabled
    if (
        @ShowColumns
        && $BulkFeature
    ) {
        push @ShowColumns, 'BulkAction';
    }
    my @XMLShowColumns = grep( {/::/} @ShowColumns );
    my %XMLColumnsHash = ();

    # get config item object
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');


    # show config items if there are some
    if (@ConfigItemIDs) {
        # to store all data
        my %ConfigItemData    = ();
        my $BulkActivate      = 0;
        my $Counter           = 0;
        my $StateHighlighting = $ConfigObject->Get('ConfigItemOverview::HighlightMapping');

        CONFIGITEMID:
        for my $ConfigItemID (@ConfigItemIDs) {
            $Counter++;
            next CONFIGITEMID if (
                $Counter < $Param{StartHit}
                || $Counter >= ( $Param{PageShown} + $Param{StartHit} )
            );

            # check for access rights
            my $HasAccess = $ConfigItemObject->Permission(
                Scope  => 'Item',
                ItemID => $ConfigItemID,
                UserID => $Self->{UserID},
                Type   => $Self->{Config}->{Permission},
            );
            next CONFIGITEMID if !$HasAccess;

            # get config item data
            my $ConfigItem = $ConfigItemObject->VersionGet(
                ConfigItemID => $ConfigItemID,
                XMLDataGet   => 1,
            );
            next CONFIGITEMID if !$ConfigItem;

            # convert the XML data into a hash
            my $ExtendedVersionData = $Self->_XMLData2Hash(
                XMLDefinition => $ConfigItem->{XMLDefinition},
                XMLData       => $ConfigItem->{XMLData}->[1]->{Version}->[1],
            );

            $ConfigItemData{$ConfigItemID}->{'VersionData'} = $ConfigItem;
            $ConfigItemData{$ConfigItemID}->{'XMLData'}     = $ExtendedVersionData;

            COLUMN:
            for my $Column (@XMLShowColumns) {

                # check if column exists in CI-Data
                next COLUMN if !$ExtendedVersionData->{$Column}->{Name};

                $XMLColumnsHash{$Column} = $ExtendedVersionData->{$Column}->{Name};
            }
        }

        $Counter = 0;
        CONFIGITEM:
        for my $ConfigItemID (@ConfigItemIDs) {
            $Counter++;
            next CONFIGITEM if (
                $Counter < $Param{StartHit}
                || $Counter >= ( $Param{PageShown} + $Param{StartHit} )
            );

            next CONFIGITEM if (!$ConfigItemData{$ConfigItemID});

            my %Data                = %{$ConfigItemData{$ConfigItemID}->{'VersionData'}};
            my $ExtendedVersionData = $ConfigItemData{$ConfigItemID}->{'XMLData'};

            if (
                $StateHighlighting
                && ref($StateHighlighting) eq 'HASH'
                && $StateHighlighting->{ $Data{CurDeplState} }
            ) {
                $Data{'LineStyle'} = $StateHighlighting->{ $Data{CurDeplState} };
            }

            # build record block
            $LayoutObject->Block(
                Name => 'Record',
                Data => {
                    %Param,
                    %Data,
                },
            );

            # build column record blocks
            if (@ShowColumns) {

                COLUMN:
                for my $Column (@ShowColumns) {
                    if ( $Column eq 'BulkAction') {
                        my $ItemChecked = '';

                        if ( $SelectedItemsHash{ $ConfigItemID } ) {
                            $ItemChecked = ' checked="checked"';
                        }
                        $LayoutObject->Block(
                            Name => 'Record' . $Column,
                            Data => {
                                %Param,
                                %Data,
                                CurInciSignal => $InciSignals{ $Data{CurInciStateType} },
                                CurDeplSignal => $DeplSignals{ $Data{CurDeplState} },
                                ItemChecked   => $ItemChecked,
                            },
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
                    } else {
                        $LayoutObject->Block(
                            Name => 'Record' . $Column,
                            Data => {
                                %Param,
                                %Data,
                                CurInciSignal => $InciSignals{ $Data{CurInciStateType} },
                                CurDeplSignal => $DeplSignals{ $Data{CurDeplState} },
                            },
                        );
                    }
                    # show links if available
                    $LayoutObject->Block(
                        Name => 'Record' . $Column . 'LinkStart',
                        Data => {
                            %Param,
                            %Data,
                        },
                    );
                    $LayoutObject->Block(
                        Name => 'Record' . $Column . 'LinkEnd',
                        Data => {
                            %Param,
                            %Data,
                        },
                    );
                }
                COLUMN:
                for my $Column (@XMLShowColumns) {

                    # check if column exists in CI-Data
                    next COLUMN if !$XMLColumnsHash{$Column};

                    # convert to ascii text in case the value contains html
                    my $Value = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii( String => $ExtendedVersionData->{$Column}->{Value} || '' ) || '';

                    # convert all whitespace and newlines to single spaces
                    $Value =~ s{ \s+ }{ }gxms;

                    # show the xml attribute data
                    $LayoutObject->Block(
                        Name => 'RecordXMLAttribute',
                        Data => {
                            %Param,
                            XMLAttributeData => $Value,
                        },
                    );
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
    # if there are no config items to show, a no data found message is displayed in the table
    else {
        $LayoutObject->Block(
            Name => 'NoDataFoundMsg',
            Data => {
                TotalColumns => scalar @ShowColumns,
            },
        );
    }

    # build column header blocks
    if (@ShowColumns) {

        for my $Column (@ShowColumns) {

            # create needed veriables
            my $CSS = 'OverviewHeader';
            my $OrderBy;

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

            if ($Column eq 'BulkAction') {
                my $ItemALLChecked = '';
                my $SelectedAll    = '';

                if ( !scalar( @UnselectedItems ) ) {
                    $ItemALLChecked = ' checked="checked"';
                }

                if ( $Param{AllHits} > $Param{PageShown} ) {
                    $SelectedAll = 'SelectAllItemsPages';
                }
                $LayoutObject->Block(
                    Name => 'Record' . $Column . 'Header',
                    Data => {
                        %Param,
                        CSS            => $CSS,
                        OrderBy        => $OrderBy,
                        ItemALLChecked => $ItemALLChecked,
                        SelectedAll    => $SelectedAll
                    },
                );
            } else {
                $LayoutObject->Block(
                    Name => 'Record' . $Column . 'Header',
                    Data => {
                        %Param,
                        CSS     => $CSS,
                        OrderBy => $OrderBy,
                    },
                );
            }
        }

        # get the XML column headers only if the filter is not set to 'all'
        # and if there are CIs to show
        if ( $Param{Filter} && $Param{Filter} ne 'All' && @ConfigItemIDs ) {

            COLUMN:
            for my $Column (@XMLShowColumns) {

                # check if column should be shown
                next COLUMN if !$XMLColumnsHash{$Column};

                # show the xml attribute header
                $LayoutObject->Block(
                    Name => 'RecordXMLAttributeHeader',
                    Data => {
                        %Param,
                        XMLAttributeHeader => $XMLColumnsHash{$Column},
                    },
                );
            }
        }
    }

    # use template
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemOverviewSmall',
        Data         => {
            %Param,
            Type         => $Self->{ViewType},
            ColumnCount  => scalar @ShowColumns,
            StyleClasses => $StyleClasses,
        },
    );

    return $Output;
}

=over

=item _XMLData2Hash()

returns a hash reference with all xml data of a config item

Return

    $Data = {
        'HardDisk::2' => {
            Value => 'HD2',
            Name  => Hard Disk::2'
         },
        'CPU::1' => {
            Value => '',
            Name  => 'CPU::1',
        },
        'HardDisk::2::Capacity::1' => {
            Value => '780 GB',
            Name  => 'Hard Disk::2::Capacity::1',
        },
    };

    my $Data = _XMLData2Hash(
        XMLDefinition => $Version->{XMLDefinition},
        XMLData       => $Version->{XMLData}->[1]->{Version}->[1],
        Data          => \%DataHashRef,                                 # optional
        Prefix        => 'HardDisk::1',                                 # optional
    );

=cut

sub _XMLData2Hash {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLData};
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLData} ne 'HASH';
    return if ref $Param{XMLDefinition} ne 'ARRAY';

    # to store the return data
    my $Data = $Param{Data} || {};

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            next ITEM if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # lookup value
            my $Value = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->XMLValueLookup(
                Item  => $Item,
                Value => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content} || '',
            );

            # only if value is not empty
            if ($Value) {

                # create output string
                $Value = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->ITSMConfigItemOutputStringCreate(
                    Value => $Value,
                    Item  => $Item,
                    Key   => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
                );
            }

            # add prefix
            my $Prefix = $Item->{Key} . '::' . $Counter;
            if ( $Param{Prefix} ) {
                $Prefix = $Param{Prefix} . '::' . $Prefix;
            }

            my $Name = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{LanguageObject}->Translate($Item->{Name})
                . '::'
                . $Counter;
            if ( $Param{Prefix} ) {
                $Name = $Data->{$Param{Prefix}}->{Name} . '::' . $Name;
            }

            # store the item in hash
            $Data->{$Prefix} = {
                Name  => $Name,
                Value => $Value,
            };

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                $Data = $Self->_XMLData2Hash(
                    XMLDefinition => $Item->{Sub},
                    XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                    Prefix        => $Prefix,
                    Data          => $Data,
                );
            }
        }
    }

    return $Data;
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
