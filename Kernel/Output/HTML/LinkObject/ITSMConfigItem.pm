# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::LinkObject::ITSMConfigItem;

use strict;
use warnings;

use Kernel::Output::HTML::Layout;

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

    # get and remember the Deployment state colors
    my $DeploymentStatesList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    ITEMID:
    for my $ItemID ( sort keys %{$DeploymentStatesList} ) {

        # get deployment state preferences
        my %Preferences = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->GeneralCatalogPreferencesGet(
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

    # convert the list
    my %LinkList;
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

                $LinkList{$Class}->{$ConfigItemID}->{Data} = $DirectionList->{$ConfigItemID};
            }
        }
    }

    my @BlockData;

    # KIX4OTRS-capeIT
    # get user data
    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData( UserID => $Self->{UserID} );

    # EO KIX4OTRS-capeIT

    for my $Class ( sort { lc $a cmp lc $b } keys %LinkList ) {

        # extract config item data
        my $ConfigItemList = $LinkList{$Class};

        # to store the column headline
        my @ShowColumnsHeadlines;

        # create the item list
        my @ItemList;

        # KIX4OTRS-capeIT
        my @Columns;
        if (
            defined $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $Class }
            && scalar @{ $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $Class } }
            )
        {
            @Columns = @{ $Param{EnabledColumns}->{ 'ITSMConfigItem-' . $Class } };
        }

        # EO KIX4OTRS-capeIT
        for my $ConfigItemID (
            sort { $ConfigItemList->{$a}->{Data}->{Name} cmp $ConfigItemList->{$b}->{Data}->{Name} }
            keys %{$ConfigItemList}
            )
        {

            # extract version data
            my $Version = $ConfigItemList->{$ConfigItemID}->{Data};

            # make sure the column headline array is empty for each loop
            @ShowColumnsHeadlines = ();

            # KIX4OTRS-capeIT
            my @ItemColumns = ();

            # EO KIX4OTRS-capeIT

            # get the version data, including all the XML data
            my $VersionXMLData = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionGet(
                ConfigItemID => $ConfigItemID,
                XMLDataGet   => 1,
            );

            # convert the XML data into a hash
            my $ExtendedVersionData = $Self->_XMLData2Hash(
                XMLDefinition => $VersionXMLData->{XMLDefinition},
                XMLData       => $VersionXMLData->{XMLData}->[1]->{Version}->[1],
            );

            # KIX4OTRS-capeIT
            if ( !scalar @Columns ) {

                # EO KIX4OTRS-capeIT
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
                    Content => $Version->{CreateTime},
                },
            );

            # individual column config for this class exists
            if ( $ColumnByClass{$Class} ) {

                COLUMN:
                for my $Column ( @{ $ColumnByClass{$Class} } ) {

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
                            };
                        }

                        next COLUMN;
                    }

                        # convert to ascii text in case the value contains html
                        my $Value = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii(
                            String => $ExtendedVersionData->{$Column}->{Value},
                        ) || '';

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
                        };
                    }
                }

                # individual column config for this class does not exist,
                # so the default columns will be used
                else {

                    # add the default columns
                    push @ItemColumns, @AdditionalDefaultItemColumns;

                    # add the default column headlines
                    @ShowColumnsHeadlines = (
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
                    );
                }

                # KIX4OTRS-capeIT
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
                        String => $ExtendedVersionData->{$Col}->{Value},
                    ) ||'';
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

                    # headline
                    $TmpHashHeadline{Content} = $TranslationHash{$Col} || $Col;
                    $TmpHashHeadline{Width}   = 130;

                    push @ShowColumnsHeadlines, \%TmpHashHeadline;
                    push @ItemColumns,          \%TmpHashContent;
                }
            }

            # EO KIX4OTRS-capeIT

            push @ItemList, \@ItemColumns;
        }

        return if !@ItemList;

        # define the block data
        my %Block = (
            Object    => $Self->{ObjectData}->{Object},
            Blockname => $Self->{ObjectData}->{Realname} . ' (' . $Class . ')',

            # KIX4OTRS-capeIT
            # Headline  => [
            #     {
            #         Content => 'Incident State',
            #         Width   => 20,
            #     },
            #     {
            #         Content => 'Deployment State',
            #         Width   => 20,
            #     },
            #     {
            #         Content => 'ConfigItem#',
            #         Width   => 100,
            #     },
            # ],
            # EO KIX4OTRS-capeIT
            ItemList => \@ItemList,
        );

        # KIX4OTRS-capeIT
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
            },
        );

        # EO KIX4OTRS-capeIT

        # add the column headlines
        # KIX4OTRS-capeIT
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
        $Block{ItemList} = \@TempArray;
        # EO KIX4OTRS-capeIT
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
                    Content => 'CI:' . $Version->{Number},
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
                )
            {

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

        # KIX4OTRS-capeIT
        # add search all config items as first array element, but only if we are not linking
        my $Action = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam(Param => 'Action');
        if ($Action ne 'AgentLinkObject') {
            unshift @ObjectSelectList, {
                Key   => 'ITSMConfigItem::All',
                Value => 'ConfigItem::' . $Self->{LayoutObject}->{LanguageObject}->Translate('All'),
            };
        }

        # EO KIX4OTRS-capeIT

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

    # add object dependence attributes
    #if ( $Param{SubObject} ) {
    #
    #    # get class list
    #    my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
    #        Class => 'ITSM::ConfigItem::Class',
    #    );
    #
    #    if ( $ClassList && $ClassList eq 'HASH' ) {
    #
    #        # add here the search attributes of the subobject!
    #    }
    #}

    # KIX4OTRS-capeIT
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

    # EO KIX4OTRS-capeIT

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

            # KIX4OTRS-capeIT
            push( @FinalSearchOptionList, $Row );

            # EO KIX4OTRS-capeIT

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
            );

            # KIX4OTRS-capeIT
            push( @FinalSearchOptionList, $Row );

            # EO KIX4OTRS-capeIT

            next ROW;
        }

        # KIX4OTRS-capeIT
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

            #            my $String = $LayoutObject->ITSMConfigItemSearchInputCreate(
            #                Key => $Row->{FormKey},
            #                Item => $Row,
            #                Value => $Row->{FormData} || '',
            #            );
            #            $Row->{InputStrg} = $String;

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

        # EO KIX4OTRS-capeIT
    }

    # KIX4OTRS-capeIT
    #return @SearchOptionList;
    return @FinalSearchOptionList;

    # EO KIX4OTRS-capeIT
}

# KIX4OTRS-capeIT
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

# EO KIX4OTRS-capeIT

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

            # KIX4OTRS-capeIT
            next ITEM if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # EO KIX4OTRS-capeIT

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

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
