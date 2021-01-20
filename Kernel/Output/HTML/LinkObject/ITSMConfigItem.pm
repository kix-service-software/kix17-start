# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::LinkObject::ITSMConfigItem;

use strict;
use warnings;

use Kernel::Output::HTML::Layout;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::HTMLUtils',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log',
    'Kernel::System::Web::Request',
);

=head1 NAME

Kernel::Output::HTML::LinkObject::ITSMConfigItem - layout backend module

=head1 SYNOPSIS

All layout functions of link object (config item)

=over 4

=cut

=item new()

create an object

    $BackendObject = Kernel::Output::HTML::LinkObject::ITSMConfigItem->new(
        UserLanguage => 'en',
        UserID       => 1,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(UserLanguage UserID)) {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    # We need our own LayoutObject instance to avoid blockdata collisions
    #   with the main page.
    $Self->{LayoutObject} = Kernel::Output::HTML::Layout->new( %{$Self} );

    # define needed variables
    $Self->{ObjectData} = {
        Object     => 'ITSMConfigItem',
        Realname   => 'ConfigItem',
        ObjectName => 'SourceObjectID',
    };

    # set field behaviors
    $Self->{Behaviors} = {
        'IsSortable'  => 1,
    };

    # define sortable columns
    $Self->{ValidSortableColumns} = {
        'Number'        => 1,
    };

    return $Self;
}

=item TableCreateComplex()

return an array with the block data

Return

    @BlockData = (
        {

            ObjectName  => 'ConfigItemID',
            ObjectID    => '123',

            Object    => 'ITSMConfigItem',
            Blockname => 'ConfigItem Computer',
            Headline  => [
                {
                    Content => '',
                    Width   => 20,
                },
                {
                    Content => 'ConfigItem#',
                    Width   => 100,
                },
                {
                    Content => 'Name',
                },
                {
                    Content => 'Deployment State',
                    Width   => 130,
                },
                {
                    Content => 'Created',
                    Width   => 130,
                },
            ],
            ItemList => [
                [
                    {
                        Type             => 'CurInciSignal',
                        Key              => '123',
                        Content          => 'Incident',
                        CurInciStateType => 'incident',
                    },
                    {
                        Type    => 'Link',
                        Content => '123',
                        Link    => 'Action=AgentITSMConfigItemZoom;ConfigItemID=123',
                    },
                    {
                        Type      => 'Text',
                        Content   => 'The Name of the Config Item',
                        MaxLength => 50,
                    },
                    {
                        Type      => 'Text',
                        Content   => 'In Repair',
                        Translate => 1,
                    },
                    {
                        Type    => 'TimeLong',
                        Content => '2008-01-01 12:12:00',
                    },
                ],
                [
                    {
                        Type             => 'CurInciSignal',
                        Key              => '234',
                        Content          => 'Incident',
                        CurInciStateType => 'incident',
                    },
                    {
                        Type    => 'Link',
                        Content => '234',
                        Link    => 'Action=AgentITSMConfigItemZoom;ConfigItemID=234',
                    },
                    {
                        Type      => 'Text',
                        Content   => 'The Name of the Config Item 234',
                        MaxLength => 50,
                    },
                    {
                        Type      => 'Text',
                        Content   => 'Productive',
                        Translate => 1,
                    },
                    {
                        Type    => 'TimeLong',
                        Content => '2007-11-11 12:12:00',
                    },
                ],
            ],
        },
    );

    @BlockData = $LinkObject->TableCreateComplex(
        ObjectLinkListWithData => $ObjectLinkListRef,
    );

=cut

sub TableCreateComplex {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ObjectLinkListWithData} || ref $Param{ObjectLinkListWithData} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ObjectLinkListWithData!',
        );
        return;
    }

    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # get and remember the Deployment state colors
    my $DeploymentStatesList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    ITEMID:
    for my $ItemID ( sort keys %{$DeploymentStatesList} ) {

        # get deployment state preferences
        my %Preferences = $GeneralCatalogObject->GeneralCatalogPreferencesGet(
            ItemID => $ItemID,
        );

        # check if a color is defined in preferences
        next ITEMID if !$Preferences{Color};

        # add color style definition
        my $DeplState = $DeploymentStatesList->{$ItemID};

        # remove any non ascii word characters
        $DeplState =~ s{ [^a-zA-Z0-9] }{_}msxg;

        # covert to lower case
        $Self->{DeplStateColors}->{$DeplState} = lc $Preferences{Color};
    }

    # get the column config
    my $ColumnConfig = $Kernel::OM->Get('Kernel::Config')->Get('LinkObject::ITSMConfigItem::ShowColumnsByClass');

    # get the configered columns and reorganize them by class name
    my %ColumnByClass;
    if ( $ColumnConfig && ref $ColumnConfig eq 'ARRAY' && @{$ColumnConfig} ) {

        NAME:
        for my $Name ( @{$ColumnConfig} ) {
            my ( $Class, $Column ) = split /::/, $Name, 2;

            next NAME if !$Column;

            push @{ $ColumnByClass{$Class} }, $Column;
        }
    }

    my %ClassIDList;
    my %LinkList;

    # convert the list
    for my $LinkType ( sort keys %{ $Param{ObjectLinkListWithData} } ) {

        # extract link type List
        my $LinkTypeList = $Param{ObjectLinkListWithData}->{$LinkType};

        for my $Direction ( sort keys %{$LinkTypeList} ) {

            # extract direction list
            my $DirectionList = $Param{ObjectLinkListWithData}->{$LinkType}->{$Direction};

            CONFIGITEMID:
            for my $ConfigItemID ( sort keys %{$DirectionList} ) {

                # extract class
                my $Class = $DirectionList->{$ConfigItemID}->{Class} || '';

                next CONFIGITEMID if !$Class;

                my $ClassID = $DirectionList->{$ConfigItemID}->{ClassID};

                $ClassIDList{$Class} = $ClassID;

                next CONFIGITEMID if $Param{OnlyClassID} && $ClassID ne $Param{OnlyClassID};

                $LinkList{$Class}->{$ConfigItemID}->{Data} = $DirectionList->{$ConfigItemID};
            }
        }
    }

    my @BlockData;

    # get user data
    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData( UserID => $Self->{UserID} );

    for my $Class ( sort { lc $a cmp lc $b } keys %LinkList ) {

        # extract config item data
        my $ConfigItemList = $LinkList{$Class};

        # to store the column headline
        my @ShowColumnsHeadlines;

        # create the item list
        my @ItemList;
        my @Columns;
        my $PreferenceClass = $Class;
        $PreferenceClass =~ s/[^A-Za-z0-9_-]/_/g;
        if (
            defined $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $PreferenceClass }
            && scalar @{ $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $PreferenceClass } }
        ) {
            @Columns = @{ $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $PreferenceClass } };
        }
        elsif (
            defined $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $Class }
            && scalar @{ $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $Class } }
        ) {
            @Columns = @{ $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $Class } };
        }

        my @SortedList;
        my $ClassID               = $ClassIDList{$Class} || '';
        my $SortBy                = $Param{SortBy}  || 'Number';
        my $OrderBy               = $Param{OrderBy} || 'Down';
        my $ColumnFilter          = $Param{$ClassID}->{ColumnFilter}          || {};
        my $GetColumnFilterSelect = $Param{$ClassID}->{GetColumnFilterSelect} || {};

        if ( $OrderBy eq 'Down' ) {
            @SortedList = sort { lc $ConfigItemList->{$a}->{Data}->{$SortBy} cmp lc $ConfigItemList->{$b}->{Data}->{$SortBy} } keys %{$ConfigItemList};
        } else {
            @SortedList = sort { lc $ConfigItemList->{$b}->{Data}->{$SortBy} cmp lc $ConfigItemList->{$a}->{Data}->{$SortBy} } keys %{$ConfigItemList};
        }

        CONFIGITEM:
        for my $ConfigItemID (
            @SortedList
        ) {

            my $ConfigItemData = $ConfigItemObject->ConfigItemGet(
                ConfigItemID => $ConfigItemID,
            );

            # extract version data
            my $Version = $ConfigItemList->{$ConfigItemID}->{Data};

            # make sure the column headline array is empty for each loop
            @ShowColumnsHeadlines = ();

            my @ItemColumns = ();

            # get the version data, including all the XML data
            my $VersionXMLData = $ConfigItemObject->VersionGet(
                ConfigItemID => $ConfigItemID,
                XMLDataGet   => 1,
            );

            # convert the XML data into a hash
            my $ExtendedVersionData = $Self->_XMLData2Hash(
                XMLDefinition => $VersionXMLData->{XMLDefinition},
                XMLData       => $VersionXMLData->{XMLData}->[1]->{Version}->[1],
            );

            if ( !scalar @Columns ) {
                @ItemColumns = (
                    {
                        Type             => 'CurInciSignal',
                        Key              => $ConfigItemID,
                        Content          => $Version->{CurInciState},
                        CurInciStateType => $Version->{CurInciStateType},
                    },
                    {
                        Type    => 'CurDeplSignal',
                        Key     => $ConfigItemID,
                        Content => $Version->{CurDeplState},
                    },
                    {
                        Type    => 'Link',
                        Content => $Version->{Number},
                        Link    => $Self->{LayoutObject}->{Baselink}
                            . 'Action=AgentITSMConfigItemZoom;ConfigItemID='
                            . $ConfigItemID,
                        Title => "ConfigItem# $Version->{Number} ($Version->{Class}): $Version->{Name}",
                    },
                );

                # these columns will be added if no class based column config is defined
                my @AdditionalDefaultItemColumns = (
                    {
                        Type      => 'Text',
                        Content   => $Version->{Name},
                        MaxLength => 50,
                    },
                    {
                        Type      => 'Text',
                        Content   => $Version->{CurDeplState},
                        Translate => 1,
                    },
                    {
                        Type    => 'TimeLong',
                        Content => $ConfigItemData->{CreateTime},
                    },
                );

                # individual column config for this class exists
                if ( $ColumnByClass{$Class} ) {

                    COLUMN:
                    for my $Column ( @{ $ColumnByClass{$Class} } ) {
                        my %TmpHash;
                        if (
                            $Self->{Behaviors}->{IsSortable}
                            && $Self->{ValidSortableColumns}->{$Column}
                        ) {
                            $TmpHash{Sortable} = $Column;
                            if ( $SortBy eq $Column ) {
                                $TmpHash{OrderCSS}  = $OrderBy eq 'Down' ? 'SortDescendingLarge' : 'SortAscendingLarge';
                                $TmpHash{SortTitle} = $OrderBy eq 'Down' ? Translatable('sorted descending') : Translatable('sorted ascending');
                            }
                        }

                        if (
                            $Self->{Behaviors}->{IsSortable}
                            && $Self->{Behaviors}->{IsFilterable}
                            && $Self->{ValidSortableColumns}->{$Column}
                            && $Self->{ValidFilterableColumns}->{$Column}
                        ) {

                            $TmpHash{FilterTitle} = Translatable('filter not active');
                            if (
                                $GetColumnFilterSelect
                                 && $GetColumnFilterSelect->{$Column}
                            ) {
                                $TmpHash{OrderCSS} .= ' FilterActive';
                                $TmpHash{FilterTitle} = Translatable('filter active');
                            }

                            # variable to save the filter's HTML code
                            $TmpHash{ColumnFilterStrg} = $Self->_InitialColumnFilter(
                                ColumnName => $Column,
                                ClassID    => $ClassID
                            );
                        }

                        if (
                            $Self->{Behaviors}->{IsFilterable}
                            && $Self->{ValidFilterableColumns}->{$Column}
                        ) {
                            $TmpHash{Filterable} = 1;
                        }

                        # process some non-xml attributes
                        if ( $Version->{$Column} ) {

                            # handle the CI name
                            if ( $Column eq 'Name' ) {

                                # add the column
                                push @ItemColumns, {
                                    Type      => 'Text',
                                    Content   => $Version->{Name},
                                    MaxLength => 50,
                                };

                                # add the headline
                                push @ShowColumnsHeadlines, {
                                    Content => 'Name',
                                    %TmpHash
                                };
                            }

                            # special translation handling
                            elsif ( $Column eq 'CurDeplState' ) {

                                # add the column
                                push @ItemColumns, {
                                    Type      => 'Text',
                                    Content   => $Version->{$Column},
                                    Translate => 1,
                                };

                                # add the headline
                                push @ShowColumnsHeadlines, {
                                    Content => 'Deployment State',
                                    %TmpHash
                                };
                            }

                            # special translation handling
                            elsif ( $Column eq 'CurInciState' ) {

                                # add the column
                                push @ItemColumns, {
                                    Type      => 'Text',
                                    Content   => $Version->{$Column},
                                    Translate => 1,
                                };

                                # add the headline
                                push @ShowColumnsHeadlines, {
                                    Content => 'Incident State',
                                    %TmpHash
                                };
                            }

                            # special translation handling
                            elsif ( $Column eq 'Class' ) {

                                # add the column
                                push @ItemColumns, {
                                    Type      => 'Text',
                                    Content   => $Version->{$Column},
                                    Translate => 1,
                                };

                                # add the headline
                                push @ShowColumnsHeadlines, {
                                    Content => 'Class',
                                    %TmpHash
                                };
                            }

                            # special date/time handling
                            elsif ( $Column eq 'CreateTime' ) {

                                # add the column
                                push @ItemColumns, {
                                    Type    => 'TimeLong',
                                    Content => $Version->{CreateTime},
                                };

                                # add the headline
                                push @ShowColumnsHeadlines, {
                                    Content => 'Created',
                                    %TmpHash
                                };
                            }

                            next COLUMN;
                        }

                        # convert to ascii text in case the value contains html
                        my $Value = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii(
                            String => $ExtendedVersionData->{$Column}->{Value} || '',
                        );

                        # convert all whitespace and newlines to single spaces
                        $Value =~ s{ \s+ }{ }gxms;

                        # add the column
                        push @ItemColumns, {
                            Type    => 'Text',
                            Content => $Value,
                        };

                        # add the headline
                        push @ShowColumnsHeadlines, {
                            Content => $ExtendedVersionData->{$Column}->{Name} || '',
                            %TmpHash
                        };
                    }
                }

                # individual column config for this class does not exist,
                # so the default columns will be used
                else {

                    # add the default columns
                    push @ItemColumns, @AdditionalDefaultItemColumns;

                    # add the default column headlines
                    for my $Column ( qw(Name CurDeplState Created) ) {
                        my %TmpHash;
                        if (
                            $Self->{Behaviors}->{IsSortable}
                            && $Self->{ValidSortableColumns}->{$Column}
                        ) {
                            $TmpHash{Sortable} = $Column;
                            if ( $SortBy eq $Column ) {
                                $TmpHash{OrderCSS}  = $OrderBy eq 'Down' ? 'SortDescendingLarge' : 'SortAscendingLarge';
                                $TmpHash{SortTitle} = $OrderBy eq 'Down' ? Translatable('sorted descending') : Translatable('sorted ascending');
                            }
                        }

                        if (
                            $Self->{Behaviors}->{IsSortable}
                            && $Self->{Behaviors}->{IsFilterable}
                            && $Self->{ValidSortableColumns}->{$Column}
                            && $Self->{ValidFilterableColumns}->{$Column}
                        ) {

                            $TmpHash{FilterTitle} = Translatable('filter not active');
                            if (
                                $GetColumnFilterSelect
                                 && $GetColumnFilterSelect->{$Column}
                            ) {
                                $TmpHash{OrderCSS} .= ' FilterActive';
                                $TmpHash{FilterTitle} = Translatable('filter active');
                            }

                            # variable to save the filter's HTML code
                            $TmpHash{ColumnFilterStrg} = $Self->_InitialColumnFilter(
                                ColumnName => $Column,
                                ClassID    => $ClassID
                            );
                        }

                        if (
                            $Self->{Behaviors}->{IsFilterable}
                            && $Self->{ValidFilterableColumns}->{$Column}
                        ) {
                            $TmpHash{Filterable} = 1;
                        }

                        if ( $Column ne 'Name' ) {
                            push(@ShowColumnsHeadlines, {
                                    Content => $Column ne 'Created' ? 'Deployment State' : $Column,
                                    Width   => 130,
                                    %TmpHash
                                }
                            );
                        }
                        else {
                            push(@ShowColumnsHeadlines, {
                                    Content => 'Name',
                                    %TmpHash
                                }
                            );
                        }
                    }
                }
            }
            else {
                # create translation hash
                my %TranslationHash = (
                    'CurDeplState'     => 'Deployment State',
                    'CurDeplStateType' => 'Deployment State Type',
                    'CurInciStateType' => 'Incident State Type',
                    'CurInciState'     => 'Incident State',
                    'LastChanged'      => 'Last changed',
                    'CurInciSignal'    => 'Current Incident Signal'
                );

                for my $Col (@Columns) {

                    next if $Col eq 'LinkType';

                    my %TmpHashContent;
                    my %TmpHashHeadline;

                    if ( $Col =~ /(State|Class)/ ) {
                        $TmpHashContent{Translate} = 1;
                    }
                    if ( $Col =~ /^Name$/ ) {
                        $TmpHashContent{MaxLength} = 50;
                    }

                    $TmpHashContent{Content} = $Version->{$Col} || $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii(
                        String => $ExtendedVersionData->{$Col}->{Value} || '',
                    );
                    $TmpHashContent{Type}    = 'Text';
                    $TmpHashContent{Key}     = $ConfigItemID;

                    # content
                    if ( $Col eq 'CurInciSignal' || $Col eq 'CurInciState' ) {
                        $TmpHashContent{Type}             = 'CurInciSignal';
                        $TmpHashContent{CurInciStateType} = $Version->{CurInciStateType};
                        $TmpHashContent{Content}          = $Version->{CurInciState};
                    }
                    elsif ( $Col eq 'Number' ) {
                        $TmpHashContent{Type} = 'Link';
                        $TmpHashContent{Link}
                            = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{Baselink} . 'Action=AgentITSMConfigItemZoom;ConfigItemID='
                            . $ConfigItemID;
                    }
                    elsif ( $Col =~ /Time/ ) {
                        $TmpHashContent{Type} = 'TimeLong';
                    }

                    # special date/time handling
                    elsif ( $Col eq 'LastChanged' ) {
                        $TmpHashContent{Type}    = 'TimeLong';
                        $TmpHashContent{Content} = $Version->{CreateTime};
                    }

                    # headline
                    $TmpHashHeadline{Content} = $TranslationHash{$Col} || $Col;
                    $TmpHashHeadline{Width}   = 130;

                    if (
                        $Self->{Behaviors}->{IsSortable}
                        && $Self->{ValidSortableColumns}->{$Col}
                    ) {
                        $TmpHashHeadline{Sortable} = $Col;
                        if ( $SortBy eq $Col ) {
                            $TmpHashHeadline{OrderCSS}  = $OrderBy eq 'Down' ? 'SortDescendingLarge' : 'SortAscendingLarge';
                            $TmpHashHeadline{SortTitle} = $OrderBy eq 'Down' ? Translatable('sorted descending') : Translatable('sorted ascending');
                        }
                    }

                    if (
                        $Self->{Behaviors}->{IsSortable}
                        && $Self->{Behaviors}->{IsFilterable}
                        && $Self->{ValidSortableColumns}->{$Col}
                        && $Self->{ValidFilterableColumns}->{$Col}
                    ) {

                        $TmpHashHeadline{FilterTitle} = Translatable('filter not active');
                        if (
                            $GetColumnFilterSelect
                             && $GetColumnFilterSelect->{$Col}
                        ) {
                            $TmpHashHeadline{OrderCSS} .= ' FilterActive';
                            $TmpHashHeadline{FilterTitle} = Translatable('filter active');
                        }

                        # variable to save the filter's HTML code
                        $TmpHashHeadline{ColumnFilterStrg} = $Self->_InitialColumnFilter(
                            ColumnName => $Col,
                            ClassID    => $ClassID
                        );
                    }

                    if (
                        $Self->{Behaviors}->{IsFilterable}
                        && $Self->{ValidFilterableColumns}->{$Col}
                    ) {
                        $TmpHashHeadline{Filterable} = 1;
                    }

                    push @ShowColumnsHeadlines, \%TmpHashHeadline;
                    push @ItemColumns,          \%TmpHashContent;
                }
            }

            if (
                $Self->{Behaviors}->{IsFilterable}
                && $ColumnFilter
            ) {
                FILTER:
                for my $Key ( sort keys %{$ColumnFilter} ) {
                    my $FilterColumn = $Key;
                    $FilterColumn =~ s/IDs$/ID/i;

                    next FILTER if $FilterColumn eq 'LinkTypeID';
                    next CONFIGITEM if !grep( {$_ eq $Version->{$FilterColumn} } @{$ColumnFilter->{$Key}} );
                }
            }

            push @ItemList, \@ItemColumns;
        }

        # define the block data
        my %Block = (
            Object    => $Self->{ObjectData}->{Object},
            Blockname => $Self->{ObjectData}->{Realname} . ' (' . $Class . ')',
            ItemList  => \@ItemList,
        );

        my %TmpHash;
        if (
            $Self->{Behaviors}->{IsSortable}
            && $Self->{ValidSortableColumns}->{Number}
        ) {
            $TmpHash{Sortable} = 'Number';
            if ( $SortBy eq 'Number' ) {
                $TmpHash{OrderCSS}  = $OrderBy eq 'Down' ? 'SortDescendingLarge' : 'SortAscendingLarge';
                $TmpHash{SortTitle} = $OrderBy eq 'Down' ? Translatable('sorted descending') : Translatable('sorted ascending');
            }
        }

        my @Headlines = (
            {
                Content => 'Incident State',
                Width   => 20,
            },
            {
                Content => 'Deployment State',
                Width   => 20,
            },
            {
                Content => 'ConfigItem#',
                Width   => 100,
                %TmpHash
            },
        );

        # add the column headlines
        if ( !scalar @Columns ) {
            push @{ $Block{Headline} }, @Headlines;
        }

        # check for access rights
        my @TempArray = ();
        for my $Item ( @{ $Block{ItemList} } ) {
            my $HasAccess = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->Permission(
                Scope  => 'Item',
                ItemID => $Item->[0]->{Key},
                UserID => $Self->{UserID},
                Type   => 'ro',
            ) || 0;
            push @TempArray, $Item if $HasAccess;
        }

        $Block{ClassID}  = $ClassID;
        $Block{ItemList} = \@TempArray;

        push @{ $Block{Headline} }, @ShowColumnsHeadlines;
        push @BlockData, \%Block;
    }

    return @BlockData;
}

=item TableCreateSimple()

return a hash with the link output data

Return

    %LinkOutputData = (
        Normal::Source => {
            ITSMConfigItem => [
                {
                    Type    => 'Link',
                    Content => 'CI:55555',
                    Title   => 'ConfigItem# 555555: The config item name',
                    Css     => 'style="text-decoration: line-through"',
                },
                {
                    Type    => 'Link',
                    Content => 'CI:22222',
                    Title   => 'ConfigItem# 22222: Title of config name 22222',
                },
            ],
        },
        ParentChild::Target => {
            ITSMConfigItem => [
                {
                    Type    => 'Link',
                    Content => 'CI:77777',
                    Title   => 'ConfigItem# 77777: ConfigItem name',
                },
            ],
        },
    );

    %LinkOutputData = $LinkObject->TableCreateSimple(
        ObjectLinkListWithData => $ObjectLinkListRef,
    );

=cut

sub TableCreateSimple {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ObjectLinkListWithData} || ref $Param{ObjectLinkListWithData} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ObjectLinkListWithData!',
        );
        return;
    }

    my %LinkOutputData;
    for my $LinkType ( sort keys %{ $Param{ObjectLinkListWithData} } ) {

        # extract link type List
        my $LinkTypeList = $Param{ObjectLinkListWithData}->{$LinkType};

        for my $Direction ( sort keys %{$LinkTypeList} ) {

            # extract direction list
            my $DirectionList = $Param{ObjectLinkListWithData}->{$LinkType}->{$Direction};

            my @ItemList;
            for my $ConfigItemID ( sort { $a <=> $b } keys %{$DirectionList} ) {

                # extract config item data
                my $Version = $DirectionList->{$ConfigItemID};

                # define item data
                my %Item = (
                    Type    => 'Link',
                    Content => 'CI:' . $Version->{Number} . ' - ' . $Version->{Name},
                    Title   => "ConfigItem# $Version->{Number} ($Version->{Class}): $Version->{Name}",
                    Link    => $Self->{LayoutObject}->{Baselink}
                        . 'Action=AgentITSMConfigItemZoom;ConfigItemID='
                        . $ConfigItemID,
                );

                push @ItemList, \%Item;
            }

            # add item list to link output data
            $LinkOutputData{ $LinkType . '::' . $Direction }->{ITSMConfigItem} = \@ItemList;
        }
    }

    return %LinkOutputData;
}

=item ContentStringCreate()

return a output string

    my $String = $LayoutObject->ContentStringCreate(
        ContentData => $HashRef,
    );

=cut

sub ContentStringCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ContentData} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ContentData!',
        );
        return;
    }

    # extract content
    my $Content = $Param{ContentData};

    if ( $Content->{Type} ne 'CurInciSignal' && $Content->{Type} ne 'CurDeplSignal' ) {
        return;
    }

    my $String;
    if ( $Content->{Type} eq 'CurInciSignal' ) {

        # set incident signal
        my %InciSignals = (
            incident    => 'redled',
            operational => 'greenled',
            unknown     => 'grayled',
            warning     => 'yellowled',
        );

        # investigate current incident signal
        $Content->{CurInciStateType} ||= 'unknown';
        my $CurInciSignal = $InciSignals{ $Content->{CurInciStateType} };
        $CurInciSignal ||= $InciSignals{unknown};

        $String = $Self->{LayoutObject}->Output(
            Template => '<div class="Flag Small" title="[% Data.CurInciState | html %]"> '
                . '<span class="[% Data.CurInciSignal | html %]"></span> </div>',
            Data => {
                CurInciSignal => $CurInciSignal,
                CurInciState  => $Content->{Content} || '',
            },
        );
    }
    elsif ( $Content->{Type} eq 'CurDeplSignal' ) {

        # convert deployment state to a web safe CSS class
        my $DeplState = $Content->{Content} || '';
        $DeplState =~ s{ [^a-zA-Z0-9] }{_}msxg;

        # get the color of the deplyment state if defined
        my $DeplStateColor = $Self->{DeplStateColors}->{$DeplState} || '';

        my $Template = '<div class="Flag Small" title="[% Data.CurDeplState | html %]"> ';

        # check if color is defined and set the style class
        if ($DeplStateColor) {
            $Template .= << "END";
<style>
    .Flag span.$DeplState {
        background-color: #$DeplStateColor;
    }
</style>
END
        }

        $Template .= "<span class=\"DeplState $DeplState\"></span> </div>";

        $String = $Self->{LayoutObject}->Output(
            Template => $Template,
            Data     => {
                CurDeplState => $Content->{Content} || '',
            },
        );
    }

    return $String;
}

=item SelectableObjectList()

return an array hash with selectable objects

Return

    @SelectableObjectList = (
        {
            Key      => '-',
            Value    => 'ConfigItem',
            Disabled => 1,
        },
        {
            Key   => 'ITSMConfigItem::25',
            Value => 'ConfigItem::Computer',
        },
        {
            Key   => 'ITSMConfigItem::26',
            Value => 'ConfigItem::Software',
        },
        {
            Key   => 'ITSMConfigItem::27',
            Value => 'ConfigItem::Network',
        },
    );

    @SelectableObjectList = $LinkObject->SelectableObjectList(
        Selected => $Identifier,  # (optional)
    );

=cut

sub SelectableObjectList {
    my ( $Self, %Param ) = @_;

    # define headline
    my @ObjectSelectList;

    # get class list
    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    return if !$ClassList;
    return if ref $ClassList ne 'HASH';

    # get the config with the default subobjects
    my $DefaultSubobject = $Kernel::OM->Get('Kernel::Config')->Get('LinkObject::DefaultSubObject') || {};

    CLASSID:
    for my $ClassID ( sort { lc $ClassList->{$a} cmp lc $ClassList->{$b} } keys %{$ClassList} ) {

        # show class only if user has access rights
        my $HasAccess = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->Permission(
            Scope   => 'Class',
            ClassID => $ClassID,
            UserID  => $Self->{UserID},
            Type    => 'ro',
        );

        next CLASSID if !$HasAccess;

        my $Class = $ClassList->{$ClassID} || '';
        my $Identifier = $Self->{ObjectData}->{Object} . '::' . $ClassID;

        # set selected flag
        my $Selected;
        if ( $Param{Selected} ) {

            if ( $Param{Selected} eq $Identifier ) {
                $Selected = 1;
            }
            elsif (
                $Param{Selected} eq $Self->{ObjectData}->{Object}
                && $DefaultSubobject->{ $Self->{ObjectData}->{Object} }
            ) {

                # extract default class name
                my $DefaultClass = $DefaultSubobject->{ $Self->{ObjectData}->{Object} } || '';

                # check class
                if ( $DefaultClass eq $Class ) {
                    $Selected = 1;
                }
            }
        }

        # create row
        my %Row = (
            Key      => $Identifier,
            Value    => $Self->{ObjectData}->{Realname} . '::' . $Class,
            Selected => $Selected,
        );

        push @ObjectSelectList, \%Row;
    }

    # only add headline if there are configitem classes
    # where the user has the permission to use them
    if (@ObjectSelectList) {

        # add search all config items as first array element, but only if we are not linking
        my $Action = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam(Param => 'Action');
        if ($Action ne 'AgentLinkObject') {
            unshift @ObjectSelectList, {
                Key   => 'ITSMConfigItem::All',
                Value => 'ConfigItem::' . $Self->{LayoutObject}->{LanguageObject}->Translate('All'),
            };
        }

        # add headline as first array element
        unshift @ObjectSelectList, {
            Key      => '-',
            Value    => $Self->{ObjectData}->{Realname},
            Disabled => 1,
        };
    }

    return @ObjectSelectList;
}

=item SearchOptionList()

return an array hash with search options

Return

    @SearchOptionList = (
        {
            Key       => 'Number',
            Name      => 'ConfigItem#',
            InputStrg => $FormString,
            FormData  => '1234',
        },
        {
            Key       => 'Name',
            Name      => 'Name',
            InputStrg => $FormString,
            FormData  => 'BlaBla',
        },
    );

    @SearchOptionList = $LinkObject->SearchOptionList(
        SubObject => '25',  # (optional)
    );

=cut

sub SearchOptionList {
    my ( $Self, %Param ) = @_;

    # search option list
    my @SearchOptionList = (
        {
            Key  => 'Number',
            Name => 'ConfigItem#',
            Type => 'Text',
        },
        {
            Key  => 'Name',
            Name => 'Name',
            Type => 'Text',
        },
        {
            Key  => 'DeplStateIDs',
            Name => 'Deployment State',
            Type => 'List',
        },
        {
            Key  => 'InciStateIDs',
            Name => 'Incident State',
            Type => 'List',
        },
    );

    my @FinalSearchOptionList;
    if ( $Param{SubObject} ) {

        my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

        my $XMLDefinition = $ConfigItemObject->DefinitionGet(
            ClassID => $Param{SubObject},
        );

        # xml search form create
        $Self->_XMLSearchAttributeList(
            XMLDefinition       => $XMLDefinition->{DefinitionRef},
            SearchAttributeList => \@SearchOptionList,
        );

    }

    # add formkey
    for my $Row (@SearchOptionList) {
        $Row->{FormKey} = 'SEARCH::' . $Row->{Key};
    }

    # add form data and input string
    ROW:
    for my $Row (@SearchOptionList) {

        # prepare text input fields
        if ( $Row->{Type} eq 'Text' ) {

            # get form data
            $Row->{FormData} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Row->{FormKey} );

            # parse the input text block
            $Self->{LayoutObject}->Block(
                Name => 'InputText',
                Data => {
                    Key   => $Row->{FormKey},
                    Value => $Row->{FormData} || '',
                },
            );

            # add the input string
            $Row->{InputStrg} = $Self->{LayoutObject}->Output(
                TemplateFile => 'LinkObject',
            );

            push( @FinalSearchOptionList, $Row );

            next ROW;
        }

        # prepare list boxes
        if ( $Row->{Type} eq 'List' ) {

            # get form data
            my @FormData = $Kernel::OM->Get('Kernel::System::Web::Request')->GetArray( Param => $Row->{FormKey} );
            $Row->{FormData} = \@FormData;

            # prepare deployment state list
            my %ListData;
            if ( $Row->{Key} eq 'DeplStateIDs' ) {

                # get deployment state list
                my $DeplStateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                    Class => 'ITSM::ConfigItem::DeploymentState',
                );

                # add list
                if ( $DeplStateList && ref $DeplStateList eq 'HASH' ) {
                    %ListData = %{$DeplStateList};
                }
            }

            # prepare incident state list
            elsif ( $Row->{Key} eq 'InciStateIDs' ) {

                # get incident state list
                my $InciStateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                    Class => 'ITSM::Core::IncidentState',
                );

                # add list
                if ( $InciStateList && ref $InciStateList eq 'HASH' ) {
                    %ListData = %{$InciStateList};
                }
            }

            # add the input string
            $Row->{InputStrg} = $Self->{LayoutObject}->BuildSelection(
                Data       => \%ListData,
                Name       => $Row->{FormKey},
                SelectedID => $Row->{FormData},
                Size       => 3,
                Multiple   => 1,
                Class      => 'Modernize',
            );

            push( @FinalSearchOptionList, $Row );

            next ROW;
        }

        if ( $Row->{Type} eq 'GeneralCatalog' ) {

            # get form data
            my @FormData = $Kernel::OM->Get('Kernel::System::Web::Request')->GetArray( Param => $Row->{FormKey} );
            $Row->{FormData} = \@FormData;

            my %ListData;
            if ( $Row->{Input} && ref( $Row->{Input} ) eq 'HASH' && $Row->{Input}->{Class} ) {

                # get deployment state list
                my $SelectionList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                    Class => $Row->{Input}->{Class},
                );

                # add list
                if ( $SelectionList && ref($SelectionList) eq 'HASH' ) {
                    %ListData = %{$SelectionList};
                }

                $Row->{InputStrg} = $Self->{LayoutObject}->BuildSelection(
                    Data       => \%ListData,
                    Name       => $Row->{FormKey},
                    SelectedID => $Row->{FormData},
                    Size       => 3,
                    Multiple   => 1,
                );
            }
            push( @FinalSearchOptionList, $Row );
            next ROW;
        }

        # provide search input fields for other CI-attributes except Date/DateTime...
        elsif ( $Row->{Type} && ( $Row->{Type} !~ /Date/ ) ) {

            $Row->{FormData} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Row->{FormKey} );

            $Self->{LayoutObject}->Block(
                Name => 'InputText',
                Data => {
                    Key => $Row->{FormKey},
                    Value => $Row->{FormData} || '',
                },
            );

            $Row->{InputStrg} = $Self->{LayoutObject}->Output(
                TemplateFile => 'LinkObject',
            );

            push( @FinalSearchOptionList, $Row );
            next ROW;
        }

        # log the removal of search attributes which cannot be displayed...
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => 'Search attribute type '
                . $Row->{Type}
                . ' removed from search mask',
        );
    }

    return @FinalSearchOptionList;
}

sub _XMLSearchAttributeList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{SearchAttributeList};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{SearchAttributeList} ne 'ARRAY';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # set prefix
        my $InputKey = $Item->{Key};
        my $Name     = $Item->{Name};

        if ( $Param{Prefix} ) {
            $InputKey = $Param{Prefix} . '::' . $InputKey;
            $Name     = $Param{PrefixName} . '::' . $Name;
        }

        # add attribute, if marked as searchable
        if ( $Item->{Searchable} ) {
            my %Row = (
                Key   => $InputKey,
                Name  => $Name,
                Input => $Item->{Input},
                Type  => $Item->{Input}->{Type},
            );
            push @{ $Param{SearchAttributeList} }, \%Row;
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLSearchAttributeList(
            XMLDefinition       => $Item->{Sub},
            SearchAttributeList => $Param{SearchAttributeList},
            Prefix              => $InputKey,
            PrefixName          => $Name,
        );
    }

    return 1;
}

=item _XMLData2Hash()

returns a hash reference with all xml data of a config item

Return

    $Data = {
        'HardDisk::2' => {
            Value => 'HD2',
            Name  => 'Hard Disk',
         },
        'CPU::1' => {
            Value => '',
            Name  => 'CPU',
        },
        'HardDisk::2::Capacity::1' => {
            Value => '780 GB',
            Name  => 'Capacity',
        },
    };

    my $Data = $LinkObject->_XMLData2Hash(
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

            # create output string
            $Value = $Self->{LayoutObject}->ITSMConfigItemOutputStringCreate(
                Value => $Value,
                Item  => $Item,
            );

            # add prefix
            my $Prefix = $Item->{Key} . '::' . $Counter;
            if ( $Param{Prefix} ) {
                $Prefix = $Param{Prefix} . '::' . $Prefix;
            }

            # store the item in hash
            $Data->{$Prefix} = {
                Name  => $Item->{Name},
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

sub _InitialColumnFilter {
    my ( $Self, %Param ) = @_;

    return if !$Param{ColumnName};

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %TranslationHash = (
        'CurDeplState'     => 'Deployment State',
        'CurDeplStateType' => 'Deployment State Type',
        'CurInciStateType' => 'Incident State Type',
        'CurInciState'     => 'Incident State',
        'LastChanged'      => 'Last changed',
        'CurInciSignal'    => 'Current Incident Signal'
    );

    my $Label = $Param{Label} || $Param{ColumnName};
    $Label = $LayoutObject->{LanguageObject}->Translate($TranslationHash{$Label});

    # set fixed values
    my $Data = [
        {
            Key   => '',
            Value => uc $Label,
        },
    ];

    my $Class = 'ColumnFilter';
    if ( $Param{Css} ) {
        $Class .= ' ' . $Param{Css};
    }

    # build select HTML
    my $ColumnFilterHTML = $LayoutObject->BuildSelection(
        Name        => 'ITSMConfigItem' . $Param{ClassID} . 'ColumnFilter' . $Param{ColumnName},
        Data        => $Data,
        Class       => $Class,
        Translation => 1,
        SelectedID  => '',
    );
    return $ColumnFilterHTML;
}

sub FilterContent {
    my ( $Self, %Param ) = @_;

    return if !$Param{FilterColumn};

    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # get and remember the Deployment state colors
    my $DeploymentStatesList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );
    my $IncidentStatesList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::Core::IncidentState',
    );

    my %ColumnValues;

    for my $LinkType ( sort keys %{$Param{LinkListWithData}} ) {
        for my $Direction ( sort keys %{$Param{LinkListWithData}->{$LinkType}} ) {
            for my $ConfigItemID ( sort keys %{$Param{LinkListWithData}->{$LinkType}->{$Direction}} ) {
                next if ($Param{LinkListWithData}->{$LinkType}->{$Direction}->{$ConfigItemID}->{ClassID} ne $Param{ClassID} );
                my $Attr   = $Param{LinkListWithData}->{$LinkType}->{$Direction}->{$ConfigItemID}->{$Param{FilterColumn}};
                my $AttrID = $Param{LinkListWithData}->{$LinkType}->{$Direction}->{$ConfigItemID}->{$Param{FilterColumn} . 'ID'};

                if ( $AttrID && $Attr ) {
                    $ColumnValues{$AttrID} = $Attr;
                }
            }
        }
    }
    # make sure that even a value of 0 is passed as a Selected value, e.g. Unchecked value of a
    my $SelectedValue = defined $Param{GetColumnFilter}->{ $Param{FilterColumn} } ? $Param{GetColumnFilter}->{ $Param{FilterColumn} } : '';

    my $LabelColumn = $Param{FilterColumn};

    # variable to save the filter's HTML code
    my $ColumnFilterJSON = $Self->_ColumnFilterJSON(
        ColumnName    => $Param{FilterColumn},
        Label         => $LabelColumn,
        ColumnValues  => \%ColumnValues,
        SelectedValue => $SelectedValue,
        ClassID       => $Param{ClassID}
    );
    return $ColumnFilterJSON;
}

sub _ColumnFilterJSON {
    my ( $Self, %Param ) = @_;

    return if !$Param{ColumnName};
    return if !$Self->{ValidFilterableColumns}->{ $Param{ColumnName} };

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %TranslationHash = (
        'CurDeplState'     => 'Deployment State',
        'CurDeplStateType' => 'Deployment State Type',
        'CurInciStateType' => 'Incident State Type',
        'CurInciState'     => 'Incident State',
        'LastChanged'      => 'Last changed',
        'CurInciSignal'    => 'Current Incident Signal'
    );


    my $Label = $Param{Label};
    $Label = $LayoutObject->{LanguageObject}->Translate($TranslationHash{$Label});

    # set fixed values
    my $Data = [
        {
            Key   => 'DeleteFilter',
            Value => uc $Label,
        },
        {
            Key      => '-',
            Value    => '-',
            Disabled => 1,
        },
    ];

    if ( $Param{ColumnValues} && ref $Param{ColumnValues} eq 'HASH' ) {

        my %Values = %{ $Param{ColumnValues} };

        # set possible values
        for my $ValueKey ( sort { lc $Values{$a} cmp lc $Values{$b} } keys %Values ) {
            push @{$Data}, {
                Key   => $ValueKey,
                Value => $Values{$ValueKey}
            };
        }
    }

    # build select HTML
    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            {
                Name         => 'ITSMConfigItem' . $Param{ClassID} . 'ColumnFilter' . $Param{ColumnName},
                Data         => $Data,
                Class        => 'ColumnFilter',
                Sort         => 'AlphanumericKey',
                TreeView     => 1,
                SelectedID   => $Param{SelectedValue},
                Translation  => 1,
                AutoComplete => 'off',
            },
        ],
    );

    return $JSON;
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
