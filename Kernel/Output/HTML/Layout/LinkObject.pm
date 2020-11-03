# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::LinkObject;

use strict;
use warnings;

use Kernel::System::LinkObject;
use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Output::HTML::Layout::LinkObject - all LinkObject-related HTML functions

=head1 SYNOPSIS

All LinkObject-related HTML functions

=head1 PUBLIC INTERFACE

=over 4

=item LinkObjectTableCreate()

create a output table

    my $String = $LayoutObject->LinkObjectTableCreate(
        LinkListWithData => $LinkListWithDataRef,
        ViewMode         => 'Simple', # (Simple|SimpleRaw|Complex|ComplexAdd|ComplexDelete|ComplexRaw)
    );

=cut

sub LinkObjectTableCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(LinkListWithData ViewMode)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( $Param{ViewMode} =~ m{ \A Simple }xms ) {

        return '' if ( $Param{GetPreferences} );
        return $Self->LinkObjectTableCreateSimple(
            %Param,
            LinkListWithData => $Param{LinkListWithData},
            ViewMode         => $Param{ViewMode},
        );
    }
    else {

        return $Self->LinkObjectTableCreateComplex(
            %Param,
            LinkListWithData => $Param{LinkListWithData},
            ViewMode         => $Param{ViewMode},
            AJAX             => $Param{AJAX},
            SourceObject     => $Param{Object},
            ObjectID         => $Param{Key},
        );
    }
}

=item LinkObjectTableCreateComplex()

create a complex output table

    my $String = $LayoutObject->LinkObjectTableCreateComplex(
        LinkListWithData => $LinkListRef,
        ViewMode         => 'Complex', # (Complex|ComplexAdd|ComplexDelete|ComplexRaw)
    );

=cut

sub LinkObjectTableCreateComplex {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    # check needed stuff
    for my $Argument (qw(LinkListWithData ViewMode)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check link list
    if ( ref $Param{LinkListWithData} ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'LinkListWithData must be a hash reference!',
        );
        return;
    }

    return if !%{ $Param{LinkListWithData} };

    if( $Param{Action} ) {
        $Self->{Action} = $Param{Action};
    }

    # convert the link list
    my %LinkList;

    # get user data
    my %UserData = $UserObject->GetUserData( UserID => $Self->{UserID} );
    my @UserLinkObjectTablePosition = ();
    if ( $UserData{ 'UserLinkObjectTablePosition-' . $Self->{Action} } ) {
        @UserLinkObjectTablePosition
            = split( /;/, $UserData{ 'UserLinkObjectTablePosition-' . $Self->{Action} } );
    }
    my %DirectionTypeList;
    my %LinkObjectList;
    my @Classes;

    for my $Object ( sort keys %{ $Param{LinkListWithData} } ) {

        for my $LinkType ( sort keys %{ $Param{LinkListWithData}->{$Object} } ) {

            # extract link type List
            my $LinkTypeList = $Param{LinkListWithData}->{$Object}->{$LinkType};

            for my $Direction ( sort keys %{$LinkTypeList} ) {

                # extract direction list
                my $DirectionList = $Param{LinkListWithData}->{$Object}->{$LinkType}->{$Direction};

                for my $ObjectKey ( sort keys %{$DirectionList} ) {
                    $LinkList{$Object}->{$ObjectKey}->{$LinkType}          = $Direction;
                    $DirectionTypeList{$Object}->{$ObjectKey}->{Direction} = $Direction;
                    $DirectionTypeList{$Object}->{$ObjectKey}->{Type}      = $LinkType;

                    %LinkObjectList = (
                        SourceObject => $DirectionList->{$ObjectKey}->{SourceObject},
                        SourceKey    => $DirectionList->{$ObjectKey}->{SourceKey},
                    );

                    if ( $Object eq 'ITSMConfigItem' ) {
                        my $ClassID = $DirectionList->{$ObjectKey}->{ClassID} || '';
                        if (!grep( { $ClassID eq $_ } @Classes ) ) {
                            push( @Classes, $ClassID);
                        }
                    }
                }
            }
        }
    }

    my %Filters;
    my @OutputData;
    my %EnabledColumns;
    my @LinkObjects = ();

    OBJECT:
    for my $Object ( sort { lc $a cmp lc $b } keys %{ $Param{LinkListWithData} } ) {

        # get enabled columns for each object
        for my $Item ( keys %UserData ) {
            if( $Item =~ /^UserFilterColumnsEnabled-$Self->{Action}-$Object(-?)(.*?)$/ ) {
                my $FilterObject = $1;
                my $FilterColumn = $2;
                my $Enabled      = $JSONObject->Decode(
                    Data => $UserData{
                        'UserFilterColumnsEnabled-'
                            . $Self->{Action} . '-'
                            . $Object
                            . $FilterObject
                            . $FilterColumn
                    },
                );
                $EnabledColumns{ $Object . $FilterObject . $FilterColumn } = $Enabled;
            }
        }

        # load backend
        my $BackendObject = $Self->_LoadLinkObjectLayoutBackend(
            Object => $Object,
        );

        next OBJECT if !$BackendObject;

        if ( $BackendObject->{Behaviors}->{IsFilterable} ) {
            if ( $Self->{Action} ne 'AgentLinkObject' ) {
                if ( $Object eq 'ITSMConfigItem' ) {
                    if ( $Param{OnlyClassID} ) {
                        @Classes = ();
                        push(@Classes, $Param{OnlyClassID});
                    }
                    for my $ClassID ( @Classes ) {
                        %{$Filters{$Object}->{$ClassID}} = $Self->_ColumnFilters(
                            Source   => $LinkObjectList{SourceObject},
                            Target   => $Object,
                            ClassID  => $ClassID
                        );
                    }
                } else {
                    %{$Filters{$Object}} = $Self->_ColumnFilters(
                        Source => $LinkObjectList{SourceObject},
                        Target => $Object
                    );
                }
            }
        }

        # get block data
        my @BlockData = $BackendObject->TableCreateComplex(
            ObjectLinkListWithData => $Param{LinkListWithData}->{$Object},
            Action                 => $Self->{Action},
            ObjectID               => $Param{ObjectID},
            EnabledColumns         => \%EnabledColumns,
            OnlyClassID            => $Param{OnlyClassID} || '',
            SortBy                 => $Param{SortBy},
            OrderBy                => $Param{OrderBy},
            %{$Filters{$Object}},
        );

        next OBJECT if !@BlockData;

        push @OutputData, @BlockData;
    }

    # create new instance of the layout object
    my $LayoutObject  = Kernel::Output::HTML::Layout->new( %{$Self} );
    my $LayoutObject2 = Kernel::Output::HTML::Layout->new( %{$Self} );

    # get preferences string
    return $Self->_PreferencesLinkObject(
        OutputData     => \@OutputData,
        EnabledColumns => \%EnabledColumns,
        LayoutObject   => $LayoutObject,
    ) if $Param{GetPreferences};

    # error handling
    for my $Block (@OutputData) {
        if ( !grep { $_ eq $Block->{Blockname} } @LinkObjects ) {
            push @LinkObjects, $Block->{Blockname};
        }

        ITEM:
        for my $Item ( @{ $Block->{ItemList} } ) {

            next ITEM if $Item->[0]->{Key} && $Block->{Object};

            if ( !$Block->{Object} ) {
                $Item->[0] = {
                    Type    => 'Text',
                    Content => 'ERROR: Object attribute not found in the block data.',
                };
            }
            else {
                $Item->[0] = {
                    Type => 'Text',
                    Content =>
                        'ERROR: Key attribute not found in the first column of the item list.',
                };
            }
        }
    }

    for my $Object (@LinkObjects) {
        next if grep { $_ eq $Object } @UserLinkObjectTablePosition;
        push @UserLinkObjectTablePosition, $Object;
    }

    if ( scalar @UserLinkObjectTablePosition ) {
        my @BlockDataTmp;
        for my $Key (@UserLinkObjectTablePosition) {
            for my $Block (@OutputData) {
                next if $Block->{Blockname} ne $Key;
                push @BlockDataTmp, $Block;
            }
        }
        @OutputData = @BlockDataTmp;
    }

    # add "linked as" column to the table
    for my $Block (@OutputData) {

        my ( $Placeholder1, $Placeholder2, $Class ) = ( '', '', '' );

        if ( $Block->{Object} eq 'ITSMConfigItem' ) {
            my ( $CIClass ) = $Block->{Blockname} =~ /^ConfigItem\s\((.*?)\)$/;
            ( $Placeholder1, $Placeholder2, $Class ) = ( '-', '_', $CIClass );
            $Class =~ s/[^A-Za-z0-9_-]/_/g;
        }

        my $NoColumnsEnabled = 0;
        if ( !defined $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } ) {
            $NoColumnsEnabled = 1;
        }

        if (
            (
                grep { $_ eq 'LinkType' }
                @{ $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } }
            )
            || $NoColumnsEnabled
        ) {
            my %FilterData;
            if ( $Block->{Behaviors}->{IsFilterable} ) {
                my $Filterable = $Filters{$Block->{Object}}->{GetColumnFilterSelect}->{LinkType};
                my $ClassID    = $Block->{ClassID} || '';
                if ( $Block->{Object} eq 'ITSMConfigItem' ) {
                    $Filterable = $Filters{$Block->{Object}}->{$ClassID}->{GetColumnFilterSelect}->{LinkType};
                }

                %FilterData = (
                    Filterable       => $Self->{Action} ne 'AgentLinkObject' ? 1 : 0,
                    FilterTitle      => $Filterable ? Translatable('filter active') : Translatable('filter not active'),
                    OrderCSS         => $Filterable ? 'FilterActive' : '',
                    ColumnFilterStrg => $LayoutObject->BuildSelection(
                        Name        => $Block->{Object} . $ClassID . 'ColumnFilterLinkType',
                        Data        => [
                            {
                                Key   => '',
                                Value => uc $LayoutObject->{LanguageObject}->Translate('Linked as'),
                            },
                        ],
                        Class       => 'ColumnFilter',
                        Translation => 1,
                        SelectedID  => '',
                    )
                );
            }

            # define the headline column
            my $Column = {
                Content => 'Linked as',
                %FilterData
            };

            # add new column to the headline
            push @{ $Block->{Headline} }, $Column;

            for my $Item ( @{ $Block->{ItemList} } ) {

                # define check-box cell
                my $CheckboxCell = {
                    Type         => 'LinkTypeList',
                    Content      => '',
                    LinkTypeList => $LinkList{ $Block->{Object} }->{ $Item->[0]->{Key} },
                    Translate    => 1,
                    CssStyle     => $Item->[0]->{CssStyle},
                };

                # add check-box cell to item
                push @{$Item}, $CheckboxCell;
            }
        }
    }

    return @OutputData if $Param{ViewMode} && $Param{ViewMode} eq 'ComplexRaw';

    if ( $Param{ViewMode} eq 'ComplexAdd' ) {

        for my $Block (@OutputData) {

            # define the headline column
            my $Column = {
                Content => 'Select',
            };

            # add new column to the headline
            unshift @{ $Block->{Headline} }, $Column;

            for my $Item ( @{ $Block->{ItemList} } ) {

                # define check-box cell
                my $CheckboxCell = {
                    Type    => 'Checkbox',
                    Name    => 'LinkTargetKeys',
                    Content => $Item->[0]->{Key},
                };

                # add check-box cell to item
                unshift @{$Item}, $CheckboxCell;
            }
        }
    }

    if ( $Param{ViewMode} eq 'ComplexDelete' ) {

        my $LinkListWithData = $Param{LinkListWithData};

        for my $Block (@OutputData) {

            # define the headline column
            my $Column = {
                Content => ' ',
            };

            # add new column to the headline
            unshift @{ $Block->{Headline} }, $Column;

            for my $Item ( @{ $Block->{ItemList} } ) {
                my $ObjectID     = $Item->[0]->{Key};
                my $SourceObject = $LinkListWithData->{ $Block->{Object} }
                    ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Type} }
                    ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Direction} }
                    ->{$ObjectID}
                    ->{SourceObject};
                my $SourceKey = $LinkListWithData->{ $Block->{Object} }
                    ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Type} }
                    ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Direction} }
                    ->{$ObjectID}
                    ->{SourceKey};

                # define check-box delete cell
                my $CheckboxCell = {
                    Type         => 'CheckboxDelete',
                    Object       => $Block->{Object},
                    Content      => '',
                    Key          => $Item->[0]->{Key},
                    LinkTypeList => $LinkList{ $Block->{Object} }->{ $Item->[0]->{Key} },
                    Translate    => 1,
                    SourceObject => $SourceObject,
                    SourceKey    => $SourceKey
                };

                if (
                    $Block->{Object} eq 'ITSMConfigItem'
                    && (
                        !defined $LinkListWithData->{ $Block->{Object} }
                        ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Type} }
                        ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Direction} }
                        ->{$ObjectID}->{Access}
                        || !$LinkListWithData->{ $Block->{Object} }
                        ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Type} }
                        ->{ $DirectionTypeList{ $Block->{Object} }->{$ObjectID}->{Direction} }
                        ->{$ObjectID}->{Access}
                    )
                ) {
                    $CheckboxCell = {
                        Type => 'Text'
                    }
                }

                # add checkbox cell to item
                unshift @{$Item}, $CheckboxCell;
            }
        }
    }

    # output the table complex block
    $LayoutObject->Block(
        Name => 'TableComplex',
    );

    # set block description
    my $BlockDescription = $Param{ViewMode} eq 'ComplexAdd' ? Translatable('Search Result') : Translatable('Linked');
    my $BlockCounter     = 0;

    BLOCK:
    for my $Block (@OutputData) {

        next BLOCK if !$Block->{ItemList};
        next BLOCK if ref $Block->{ItemList} ne 'ARRAY';

        my $UsedFilter = 0;
        if (
            (
                (
                    $Block->{Object} eq 'ITSMConfigItem'
                    && IsHashRefWithData($Filters{$Block->{Object}}->{$Block->{ClassID}}->{GetColumnFilterSelect})
                ) || (
                    $Block->{Object} ne 'ITSMConfigItem'
                    && IsHashRefWithData($Filters{$Block->{Object}}->{GetColumnFilterSelect})
                )
            )
            && $Self->{Action} ne 'AgentLinkObject'
        ) {
            $UsedFilter = 1;
        }

        next BLOCK if !@{ $Block->{ItemList} } && !$UsedFilter;

        my ( $Placeholder1, $Placeholder2, $Class ) = ( '', '', '' );
        if ( $Block->{Object} eq 'ITSMConfigItem' ) {
            my ( $CIClass ) = $Block->{Blockname} =~ /^ConfigItem\s\((.*?)\)$/;
            ( $Placeholder1, $Placeholder2, $Class ) = ( '-', '_', $CIClass );
            $Class =~ s/[^A-Za-z0-9_-]/_/g;
        }

        my $UseFilter = 0;
        if (
            $Block->{Behaviors}->{IsFiltrable}
            && $Self->{Action} ne 'AgentLinkObject'
        ) {
            $UseFilter = 1;
        }

        # output the block
        $LayoutObject->Block(
            Name => 'TableComplexBlock',
            Data => {
                BlockDescription => $BlockDescription,
                Blockname        => $Block->{Blockname} || '',
                Name             => $Block->{Blockname},
                NameForm         => $Block->{Blockname},
                AJAX             => $Param{AJAX},
                LinkType         => $Block->{Object},
                PreferencesID    => $Block->{Object} . $Placeholder2 . $Class,
                Source           => $LinkObjectList{SourceObject},
                Target           => $Block->{Object},
                ClassID          => $Block->{ClassID} || '',
                CallingAction    => $Self->{Action},
                ItemID           => $LinkObjectList{SourceKey},
                UseFilter        => $UseFilter
            },
        );

        # output table headline
        for my $HeadlineColumn ( @{ $Block->{Headline} } ) {
            # output a headline column block
            $LayoutObject->Block(
                Name => 'TableComplexBlockColumn',
                Data => {
                    %{$HeadlineColumn},
                    Sortable   => $Self->{Action} ne 'AgentLinkObject' ? $HeadlineColumn->{Sortable} : 0,
                    Filterable => $Self->{Action} ne 'AgentLinkObject' ? $HeadlineColumn->{Filterable} : 0
                }
            );
        }

        my $HasRows = scalar(@{ $Block->{ItemList}}) || 0;
        if ( @{ $Block->{ItemList} } ) {

            # output item list
            ROW:
            for my $Row ( @{ $Block->{ItemList} } ) {
                my $LinkFilter = $Filters{$Block->{Object}}->{GetColumnFilterSelect}->{LinkType};
                if ( $Block->{Object} eq 'ITSMConfigItem' ) {
                    $LinkFilter = $Filters{$Block->{Object}}->{$Block->{ClassID}}->{GetColumnFilterSelect}->{LinkType};
                }

                if (
                    $UsedFilter
                    && $LinkFilter
                ) {
                    my $TypeName = $Kernel::OM->Get('Kernel::System::LinkObject')->TypeLookup(
                        TypeID => $LinkFilter,
                        UserID => $Self->{UserID}
                    );
                    if (!$Row->[0]->{LinkTypeList}->{$TypeName}) {
                        $HasRows--;
                        next ROW;
                    }
                }

                # output a table row block
                $LayoutObject->Block(
                    Name => 'TableComplexBlockRow',
                );

                for my $Column ( @{$Row} ) {

                    # create the content string
                    my $Content = $Self->_LinkObjectContentStringCreate(
                        Object       => $Block->{Object},
                        ContentData  => $Column,
                        LayoutObject => $LayoutObject2,
                    );

                    # output a table column block
                    $LayoutObject->Block(
                        Name => 'TableComplexBlockRowColumn',
                        Data => {
                            %{$Column},
                            Content => $Content,
                        },
                    );
                }
            }
        }

        if ( !$HasRows ) {
            # output a table row block
            $LayoutObject->Block(
                Name => 'TableComplexBlockRow',
            );

            if ( $UseFilter ) {
                # output a table row block
                $LayoutObject->Block(
                    Name => 'TableComplexBlockRowColumnFilter',
                );
            }
            next BLOCK;
        }

        if ( $Param{ViewMode} eq 'ComplexAdd' ) {

            # output the action row block
            $LayoutObject->Block(
                Name => 'TableComplexBlockActionRow',
            );

            $LayoutObject->Block(
                Name => 'TableComplexBlockActionRowBulk',
                Data => {
                    Name        => Translatable('Bulk'),
                    TableNumber => $BlockCounter,
                },
            );

            # output the footer block
            $LayoutObject->Block(
                Name => 'TableComplexBlockFooterAdd',
                Data => {
                    LinkTypeStrg => $Param{LinkTypeStrg} || '',
                },
            );
        }

        elsif ( $Param{ViewMode} eq 'ComplexDelete' ) {

            # output the action row block
            $LayoutObject->Block(
                Name => 'TableComplexBlockActionRow',
            );

            $LayoutObject->Block(
                Name => 'TableComplexBlockActionRowBulk',
                Data => {
                    Name        => Translatable('Bulk'),
                    TableNumber => $BlockCounter,
                },
            );

            # output the footer block
            $LayoutObject->Block(
                Name => 'TableComplexBlockFooterDelete',
            );
        }
        else {

            # output the footer block
            $LayoutObject->Block(
                Name => 'TableComplexBlockFooterNormal',
            );
        }

        # increase BlockCounter to set correct IDs for Select All Check-boxes
        $BlockCounter++;
    }

    return $LayoutObject->Output(
        TemplateFile   => $Param{Template} || 'LinkObject',
        Data           => {
            Action       => $Self->{Action},
            UserLanguage => $LayoutObject->{UserLanguage} || 'en',
        },
        KeepScriptTags => $Param{AJAX},
    );
}

=item LinkObjectTableCreateSimple()

create a simple output table

    my $String = $LayoutObject->LinkObjectTableCreateSimple(
        LinkListWithData => $LinkListWithDataRef,
        ViewMode         => 'SimpleRaw',            # (optional) (Simple|SimpleRaw)
    );

=cut

sub LinkObjectTableCreateSimple {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{LinkListWithData} || ref $Param{LinkListWithData} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need LinkListWithData!'
        );
        return;
    }

    # get type list
    my %TypeList = $Kernel::OM->Get('Kernel::System::LinkObject')->TypeList(
        UserID => $Self->{UserID},
    );

    return if !%TypeList;

    my %OutputData;
    OBJECT:
    for my $Object ( sort keys %{ $Param{LinkListWithData} } ) {

        # load backend
        my $BackendObject = $Self->_LoadLinkObjectLayoutBackend(
            Object => $Object,
        );

        next OBJECT if !$BackendObject;

        # get link output data
        my %LinkOutputData = $BackendObject->TableCreateSimple(
            ObjectLinkListWithData => $Param{LinkListWithData}->{$Object},
        );

        next OBJECT if !%LinkOutputData;

        for my $LinkType ( sort keys %LinkOutputData ) {

            $OutputData{$LinkType}->{$Object} = $LinkOutputData{$LinkType}->{$Object};
        }
    }

    return %OutputData if $Param{ViewMode} && $Param{ViewMode} eq 'SimpleRaw';

    # create new instance of the layout object
    my $LayoutObject  = Kernel::Output::HTML::Layout->new( %{$Self} );
    my $LayoutObject2 = Kernel::Output::HTML::Layout->new( %{$Self} );

    my $Count = 0;
    for my $LinkTypeLinkDirection ( sort { lc $a cmp lc $b } keys %OutputData ) {
        $Count++;

        # output the table simple block
        if ( $Count == 1 ) {
            $LayoutObject->Block(
                Name => 'TableSimple',
            );
        }

        # investigate link type name
        my @LinkData = split q{::}, $LinkTypeLinkDirection;
        my $LinkTypeName = $TypeList{ $LinkData[0] }->{ $LinkData[1] . 'Name' };

        # output the type block
        $LayoutObject->Block(
            Name => 'TableSimpleType',
            Data => {
                LinkTypeName => $LinkTypeName,
            },
        );

        # extract object list
        my $ObjectList = $OutputData{$LinkTypeLinkDirection};

        for my $Object ( sort { lc $a cmp lc $b } keys %{$ObjectList} ) {

            for my $Item ( @{ $ObjectList->{$Object} } ) {

                # create the content string
                my $Content = $Self->_LinkObjectContentStringCreate(
                    Object       => $Object,
                    ContentData  => $Item,
                    LayoutObject => $LayoutObject2,
                );

                # output the type block
                $LayoutObject->Block(
                    Name => 'TableSimpleTypeRow',
                    Data => {
                        %{$Item},
                        Content => $Content,
                    },
                );
            }
        }
    }

    # show no linked object available
    if ( !$Count ) {
        $LayoutObject->Block(
            Name => 'TableSimpleNone',
            Data => {},
        );
    }

    return $LayoutObject->Output(
        TemplateFile => 'LinkObject',
    );
}

=item LinkObjectSelectableObjectList()

return a selection list of linkable objects

    my $String = $LayoutObject->LinkObjectSelectableObjectList(
        Object   => 'Ticket',
        Selected => $Identifier,  # (optional)
    );

=cut

sub LinkObjectSelectableObjectList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Object} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Object!'
        );
        return;
    }

    # get possible objects list
    my %PossibleObjectsList = $Kernel::OM->Get('Kernel::System::LinkObject')->PossibleObjectsList(
        Object => $Param{Object},
        UserID => $Self->{UserID},
    );

    return if !%PossibleObjectsList;

    # get the select lists
    my @SelectableObjectList;
    my @SelectableTempList;
    my $AddBlankLines;
    POSSIBLEOBJECT:
    for my $PossibleObject ( sort { lc $a cmp lc $b } keys %PossibleObjectsList ) {

        # load backend
        my $BackendObject = $Self->_LoadLinkObjectLayoutBackend(
            Object => $PossibleObject,
        );

        return if !$BackendObject;

        # get object select list
        my @SelectableList = $BackendObject->SelectableObjectList(
            %Param,
        );

        next POSSIBLEOBJECT if !@SelectableList;

        push @SelectableTempList,   \@SelectableList;
        push @SelectableObjectList, @SelectableList;

        next POSSIBLEOBJECT if $AddBlankLines;

        # check each keys if blank lines must be added
        ROW:
        for my $Row (@SelectableList) {
            next ROW if !$Row->{Key} || $Row->{Key} !~ m{ :: }xms;
            $AddBlankLines = 1;
            last ROW;
        }
    }

    # add blank lines
    if ($AddBlankLines) {

        # reset list
        @SelectableObjectList = ();

        # define blank line entry
        my %BlankLine = (
            Key      => '-',
            Value    => '-------------------------',
            Disabled => 1,
        );

        # insert the blank lines
        for my $Elements (@SelectableTempList) {
            push @SelectableObjectList, @{$Elements};
        }
        continue {
            push @SelectableObjectList, \%BlankLine;
        }

        # add blank lines in top of the list
        unshift @SelectableObjectList, \%BlankLine;
    }

    if ( $Param{FilterModule} && $Param{FilterMethod} ) {
        my $FilterMethod = $Param{FilterMethod};
        @SelectableObjectList = $Param{FilterModule}->$FilterMethod(
            %Param,
            List => \@SelectableObjectList,
        );
    }

    # create new instance of the layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # create target object string
    my $TargetObjectStrg = $LayoutObject->BuildSelection(
        Data     => \@SelectableObjectList,
        Name     => 'TargetIdentifier',
        Class    => 'Modernize',
        TreeView => 1,
    );

    return $TargetObjectStrg;
}

=item LinkObjectSearchOptionList()

return a list of search options

    my @SearchOptionList = $LayoutObject->LinkObjectSearchOptionList(
        Object    => 'Ticket',
        SubObject => 'Bla',     # (optional)
    );

=cut

sub LinkObjectSearchOptionList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Object} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Object!'
        );
        return;
    }

    # load backend
    my $BackendObject = $Self->_LoadLinkObjectLayoutBackend(
        Object => $Param{Object},
    );

    return if !$BackendObject;

    # get search option list
    my @SearchOptionList = $BackendObject->SearchOptionList(
        %Param,
    );

    return @SearchOptionList;
}

=begin Internal:

=item _LinkObjectContentStringCreate()

return a output string

    my $String = $LayoutObject->_LinkObjectContentStringCreate(
        Object       => 'Ticket',
        ContentData  => $HashRef,
        LayoutObject => $LocalLayoutObject,
    );

=cut

sub _LinkObjectContentStringCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object ContentData LayoutObject)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # load link core module
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # load backend
    my $BackendObject = $Self->_LoadLinkObjectLayoutBackend(
        Object => $Param{Object},
    );

    # create content string in backend module
    if ($BackendObject) {

        my $ContentString = $BackendObject->ContentStringCreate(
            %Param,
            LinkObject   => $LinkObject,
            LayoutObject => $Param{LayoutObject},
        );

        return $ContentString if defined $ContentString;
    }

    # extract content
    my $Content = $Param{ContentData};

    # set blockname
    my $Blockname = $Content->{Type};

    # set global default value
    $Content->{MaxLength} ||= 100;

    # prepare linktypelist
    if ( $Content->{Type} eq 'LinkTypeList' ) {

        $Blockname = 'Plain';

        # get type list
        my %TypeList = $LinkObject->TypeList(
            UserID => $Self->{UserID},
        );

        return if !%TypeList;

        my @LinkNameList;
        LINKTYPE:
        for my $LinkType ( sort { lc $a cmp lc $b } keys %{ $Content->{LinkTypeList} } ) {

            next LINKTYPE if $LinkType eq 'NOTLINKED';

            # extract direction
            my $Direction = $Content->{LinkTypeList}->{$LinkType};

            # extract linkname
            my $LinkName = $TypeList{$LinkType}->{ $Direction . 'Name' };

            # translate
            if ( $Content->{Translate} ) {
                $LinkName = $Param{LayoutObject}->{LanguageObject}->Translate($LinkName);
            }

            push @LinkNameList, $LinkName;
        }

        # join string
        my $String = join qq{\n}, @LinkNameList;

        # transform ascii to html
        $Content->{Content} = $Param{LayoutObject}->Ascii2Html(
            Text           => $String || '-',
            HTMLResultMode => 1,
            LinkFeature    => 0,
        );
    }

    # prepare checkbox delete
    elsif ( $Content->{Type} eq 'CheckboxDelete' ) {

        $Blockname = 'Plain';

        # get type list
        my %TypeList = $LinkObject->TypeList(
            UserID => $Self->{UserID},
        );

        return if !%TypeList;

        LINKTYPE:
        for my $LinkType ( sort { lc $a cmp lc $b } keys %{ $Content->{LinkTypeList} } ) {

            next LINKTYPE if $LinkType eq 'NOTLINKED';

            # extract direction
            my $Direction = $Content->{LinkTypeList}->{$LinkType};

            # extract linkname
            my $LinkName = $TypeList{$LinkType}->{ $Direction . 'Name' };

            # translate
            if ( $Content->{Translate} ) {
                $LinkName = $Param{LayoutObject}->{LanguageObject}->Translate($LinkName);
            }

            my $SourceObject = $Content->{SourceObject} || '-';
            my $SourceKey    = $Content->{SourceKey}    || '-';

            # run checkbox block
            $Param{LayoutObject}->Block(
                Name => 'Checkbox',
                Data => {
                    %{$Content},
                    Name    => 'LinkDeleteIdentifier',
                    Title   => $LinkName,
                    Content => $SourceObject . '::'
                        . $SourceKey . '::'
                        . $Content->{Object} . '::'
                        . $Content->{Key} . '::'
                        . $LinkType,
                },
            );
        }

        $Content->{Content} = $Param{LayoutObject}->Output(
            TemplateFile => 'LinkObject',
        );
    }

    elsif ( $Content->{Type} eq 'TimeLong' ) {
        $Blockname = 'TimeLong';
    }

    elsif ( $Content->{Type} eq 'Date' ) {
        $Blockname = 'Date';
    }

    # prepare text
    elsif ( $Content->{Type} eq 'Text' || !$Content->{Type} ) {

        $Blockname = $Content->{Translate} ? 'TextTranslate' : 'Text';
        $Content->{Content} ||= '-';
    }

    # run block
    $Param{LayoutObject}->Block(
        Name => $Blockname,
        Data => $Content,
    );

    return $Param{LayoutObject}->Output(
        TemplateFile => 'LinkObject',
    );
}

=item _LoadLinkObjectLayoutBackend()

load a linkobject layout backend module

    $BackendObject = $LayoutObject->_LoadLinkObjectLayoutBackend(
        Object => 'Ticket',
    );

=cut

sub _LoadLinkObjectLayoutBackend {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if ( !$Param{Object} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need Object!',
        );
        return;
    }

    # check if object is already cached
    return $Self->{Cache}->{LoadLinkObjectLayoutBackend}->{ $Param{Object} }
        if $Self->{Cache}->{LoadLinkObjectLayoutBackend}->{ $Param{Object} };

    my $GenericModule = "Kernel::Output::HTML::LinkObject::$Param{Object}";

    # load the backend module
    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($GenericModule) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Can't load backend module $Param{Object}!"
        );
        return;
    }

    # create new instance
    my $BackendObject = $GenericModule->new(
        %{$Self},
        %Param,
    );

    if ( !$BackendObject ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Can't create a new instance of backend module $Param{Object}!",
        );
        return;
    }

    # cache the object
    $Self->{Cache}->{LoadLinkObjectLayoutBackend}->{ $Param{Object} } = $BackendObject;

    return $BackendObject;
}

sub _PreferencesLinkObject {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $JSONObject         = $Kernel::OM->Get('Kernel::System::JSON');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my @OutputData     = @{ $Param{OutputData} };
    my %EnabledColumns = %{ $Param{EnabledColumns} };
    my $LayoutObject   = $Param{LayoutObject};

    # create preferences settings
    for my $Block (@OutputData) {

        next if !$Block->{ItemList};
        next if ref $Block->{ItemList} ne 'ARRAY';
        next if !@{ $Block->{ItemList} };

        # output
        my @ColumnsAvailable;
        my @ColumnsEnabled;
        my %DefaultColumnHash = ();
        my $ConfigHash;
        my ( $Class, $Placeholder1, $Placeholder2 ) = ( '', '', '' );

        # get default available columns
        # for ticket object
        if ( $Block->{Object} eq 'Ticket' ) {
            my %TranslationHash = (
                'EscalationResponseTime' => 'First Response Time',
                'EscalationSolutionTime' => 'Solution Time',
                'EscalationUpdateTime'   => 'Update Time',
                'PendingTime'            => 'Pending Time',
            );

            $ConfigHash = $ConfigObject->Get('DefaultOverviewColumns');

            my $TicketConfig = $ConfigObject->Get('LinkObject::Ticket');
            my @EnabledDynamicFields;
            if ( $TicketConfig->{DynamicField} ) {
                DYNAMICFIELD:
                for ( sort keys %{$TicketConfig->{DynamicField}} ) {
                    next DYNAMICFIELD if !$TicketConfig->{DynamicField}->{$_};
                    my $Name = $_;
                    if ( $Name !~ /^DynamicField_/ ) {
                        $Name = 'DynamicField_' . $Name;
                    }
                    $ConfigHash->{$Name} = $TicketConfig->{DynamicField}->{$_};
                    if ( $TicketConfig->{DynamicField}->{$_} eq '2' ) {
                        push( @EnabledDynamicFields, $Name )
                    }
                }
            }

            # check if user columns enabled
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
            ) {
                @{ $EnabledColumns{ $Block->{Object} } }
                    = ( "TicketNumber", "Title", "Type", "Queue", "State", "Created" );

                # add link type by default if no user enabled columns defined
                push @{ $EnabledColumns{ $Block->{Object} } }, 'LinkType';

                if ( @EnabledDynamicFields ) {
                    push( @{ $EnabledColumns{ $Block->{Object} } }, @EnabledDynamicFields);
                }
            }

            # get default available columns
            for my $Col ( %{$ConfigHash} ) {
                next if !$ConfigHash->{$Col};
                if ( $Col =~ m/^DynamicField_(.*?)$/ ) {
                    my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
                        Name => $1
                    );
                    $DefaultColumnHash{$Col} = $LayoutObject->{LanguageObject}->Translate( $DynamicField->{Label} ) . ' (DF)';
                }
                else {
                    $DefaultColumnHash{$Col} = $TranslationHash{$Col} || $LayoutObject->{LanguageObject}->Translate($Col);
                }
            }

        }

        # for itsm-change object
        elsif ( $Block->{Object} eq 'ITSMChange' ) {
            $ConfigHash = $ConfigObject->Get('ITSMChange::Frontend::AgentITSMChange');

            # check if user columns enabled
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
            ) {
                @{ $EnabledColumns{ $Block->{Object} } } = (
                    'ChangeStateSignal', 'ChangeNumber', 'ChangeTitle', 'ChangeState',
                    'ChangeTime'
                );

                # add link type by default if no user enabled columns defined
                push @{ $EnabledColumns{ $Block->{Object} } }, 'LinkType';
            }

            # get default available columns
            for my $Col ( %{ $ConfigHash->{ShowColumns} } ) {
                next if !$ConfigHash->{ShowColumns}->{$Col};
                $DefaultColumnHash{$Col} = $LayoutObject->{LanguageObject}->Translate($Col);
            }
        }

        # for itsm-workorder object
        elsif ( $Block->{Object} eq 'ITSMWorkOrder' ) {
            $ConfigHash
                = $ConfigObject->Get('ITSMChange::Frontend::AgentITSMChangeMyWorkOrders');

            # check if user columns enabled
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
            ) {
                @{ $EnabledColumns{ $Block->{Object} } } = (
                    'WorkOrderStateSignal', 'ChangeNumber',
                    'WorkOrderTitle',       'ChangeTitle',
                    'WorkOrderState',       'ChangeTime'
                );

                # add link type by default if no user enabled columns defined
                push @{ $EnabledColumns{ $Block->{Object} } }, 'LinkType';
            }

            # get default available columns
            for my $Col ( %{ $ConfigHash->{ShowColumns} } ) {
                next if !$ConfigHash->{ShowColumns}->{$Col};
                $DefaultColumnHash{$Col} = $LayoutObject->{LanguageObject}->Translate($Col);
            }
        }

        # for itsm-config item object
        elsif ( $Block->{Object} eq 'ITSMConfigItem' ) {

            # create translation hash
            my %TranslationHash = (
                'CurDeplState'     => 'Deployment State',
                'CurDeplStateType' => 'Deployment State Type',
                'CurInciStateType' => 'Incident State Type',
                'CurInciState'     => 'Incident State',
                'LastChanged'      => 'Last changed',
                'CurInciSignal'    => 'Current Incident Signal'
            );

            # get default config
            $ConfigHash = $ConfigObject->Get('ITSMConfigItem::Frontend::AgentITSMConfigItem');

            # get class
            my ( $CIClass ) = $Block->{Blockname} =~ /^ConfigItem\s\((.*?)\)$/;
            ( $Class, $Placeholder1, $Placeholder2 ) = ( $CIClass , '-', '_' );
            my $RealClass = $Class;
            $Class =~ s/[^A-Za-z0-9_-]/_/g;

            # check if user columns enabled
            if (
                !defined $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class }
                || !scalar @{ $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } }
            ) {
                for my $Col ( %{ $ConfigHash->{ShowColumns} } ) {
                    next if !$ConfigHash->{ShowColumns}->{$Col};
                    push @{ $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } }, $Col;
                }

                # add link type by default if no user enabled columns defined
                push @{ $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } }, 'LinkType';
            }

            for my $Col ( %{ $ConfigHash->{ShowColumns} } ) {
                next if !$ConfigHash->{ShowColumns}->{$Col};
                if ( defined $TranslationHash{$Col} ) {
                    $DefaultColumnHash{$Col} = $LayoutObject->{LanguageObject}->Get( $TranslationHash{$Col} );
                }
                else {
                    $DefaultColumnHash{$Col} = $LayoutObject->{LanguageObject}->Translate($Col);
                }
            }

            # get the column config
            my $ColumnConfig = $ConfigObject->Get('LinkObject::ITSMConfigItem::ShowColumnsByClass');

            # get the configered columns and reorganize them by class name
            if ( $ColumnConfig && ref $ColumnConfig eq 'ARRAY' && @{$ColumnConfig} ) {
                for my $Name ( @{$ColumnConfig} ) {

                    # extract the class name and the column name
                    if ( $Name =~ m{ \A ([^:]+) :: (.+) \z }xms ) {
                        my ( $DefinedClass, $Col ) = ( $1, $2 );

                        # create new entry
                        if ( $DefinedClass eq $RealClass ) {
                            my @SplitArray = split( /::/, $Col );
                            my $Count = 0;
                            for my $SplitItem (@SplitArray) {
                                if ( defined $TranslationHash{$SplitItem} ) {
                                    $SplitArray[$Count] = $LayoutObject->{LanguageObject}
                                        ->Get( $TranslationHash{$SplitItem} );
                                }
                                else {
                                    $SplitArray[$Count]
                                        = $LayoutObject->{LanguageObject}->Translate($SplitItem);
                                }
                                $Count++;
                            }
                            my $TranslatedString = join( "::", @SplitArray );
                            $DefaultColumnHash{$Col} = $TranslatedString;
                        }
                    }
                }
            }
        }

        # for person object
        elsif ( $Block->{Object} eq 'Person' ) {
            my $ConfigHashPerson = $ConfigObject->Get('LinkedPerson::ModeComplex');
            my %PersonColumns    = %{ $ConfigHashPerson->{Columns} };
            my %Translations     = %{ $ConfigHashPerson->{ColumnHeaders} };

            # check if user columns enabled
            my $UserColumnsEnabled = 1;
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
            ) {
                $UserColumnsEnabled = 0;
            }

            # get default available columns
            for my $Column ( sort keys %PersonColumns ) {
                $DefaultColumnHash{ $PersonColumns{$Column} } = $Translations{$Column};
                if ( !$UserColumnsEnabled ) {
                    push @{ $EnabledColumns{ $Block->{Object} } }, $PersonColumns{$Column};
                }
            }

            # add link type by default if no user enabled columns defined
            if ( !$UserColumnsEnabled ) {
                push @{ $EnabledColumns{ $Block->{Object} } }, 'LinkType';
            }
        }

        # for document object
        elsif ( $Block->{Object} eq 'Document' ) {
            $ConfigHash = $ConfigObject->Get('Document::DefaultColumns');

            # check if user columns enabled
            my $UserColumnsEnabled = 1;
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
            ) {
                $UserColumnsEnabled = 0;
            }

            # get default available columns
            for my $Column ( keys %{$ConfigHash} ) {
                next if !$ConfigHash->{$Column};
                $DefaultColumnHash{$Column} = $LayoutObject->{LanguageObject}->Translate($Column);
                if ( !$UserColumnsEnabled ) {
                    push @{ $EnabledColumns{ $Block->{Object} } }, $Column;
                }
            }

            # add link type by default if no user enabled columns defined
            if ( !$UserColumnsEnabled ) {
                push @{ $EnabledColumns{ $Block->{Object} } }, 'LinkType';
            }

        }

        # for service object
        elsif ( $Block->{Object} eq 'Service' ) {
            my %ConfigHash = (
                'Incident State' => 1,
                'Service'        => 1,
                'Type'           => 1,
                'Criticality'    => 1,
                'Changed'        => 1,
            );

            for my $Column ( keys %ConfigHash ) {
                next if !$ConfigHash{$Column};
                $DefaultColumnHash{$Column} = $LayoutObject->{LanguageObject}->Translate($Column);
            }
        }

        # add link column
        $DefaultColumnHash{LinkType} = 'Link Type';
        my %ColumnTranslations;

        # sort columns and add column to translation hash
        for my $Col (
            sort { $DefaultColumnHash{$a} cmp $DefaultColumnHash{$b} }
            keys %DefaultColumnHash
        ) {
            push @ColumnsAvailable, $Col;
            $ColumnTranslations{$Col} = $DefaultColumnHash{$Col};
        }

        if ( $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } ) {

            @ColumnsEnabled = @{ $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } };

            my @AvTmp;
            my @EnTmp;
            for my $Col (@ColumnsAvailable) {
                if ( grep { $_ eq $Col } @ColumnsEnabled ) {
                    push @EnTmp, $Col;
                }
                else {
                    push @AvTmp, $Col;
                }
            }
            @ColumnsAvailable = @AvTmp;
        }

        # get requested url
        my $RequestURL = $Self->{RequestedURL};
        if ( defined $RequestURL && $RequestURL ) {
            my $URLPattern = 'Agent(.*?)ZoomTabLinkedObjects;(.*?)DirectLinkAnchor=(.*?);?(.*)';
            $RequestURL =~ s/$URLPattern/Agent$1Zoom;$2$4/;
            if ( defined $1 && $1 eq 'Ticket' ) {
                $Param{RequestedURL} = $RequestURL . ';SelectedTab=2;';
            }
            else {
                $Param{RequestedURL} = $RequestURL . ';SelectedTab=1;';
            }
        }
        elsif ( $Self->{Action} eq 'AgentLinkObject' ) {
            $Param{RequestedURL}
                = 'Action='
                . $Self->{Action}
                . ';SourceObject='
                . $ParamObject->GetParam( Param => 'SourceObject' )
                . ';SourceKey='
                . $ParamObject->GetParam( Param => 'SourceKey' )
                . ';SEARCH::TicketNumber=***;'
        }

        $LayoutObject->Block(
            Name => 'FilterColumnSettings',
            Data => {
                ColumnsEnabled   => $JSONObject->Encode( Data => \@ColumnsEnabled ),
                ColumnsAvailable => $JSONObject->Encode( Data => \@ColumnsAvailable ),
                Desc             => 'Shown Columns',
                Name             => $Self->{Action} . '-' . $Block->{Object} . $Placeholder1 . $Class,
                GroupName        => 'LinkedObjectFilterSettings',
                PreferencesID    => $Block->{Object} . $Placeholder2 . $Class,
                %Param,
            },
        );

        for my $Column ( keys %ColumnTranslations ) {
            $LayoutObject->Block(
                Name => 'ColumnTranslation',
                Data => {
                    ColumnName      => $Column,
                    TranslateString => $ColumnTranslations{$Column},
                },
            );
            $LayoutObject->Block(
                Name => 'ColumnTranslationSeparator',
            );
        }
    }

    return $LayoutObject->Output(
        TemplateFile => 'PreferencesLinkObject',
    );
}

sub _ColumnFilters {
    my ( $Self, %Param ) = @_;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');
    my $JSONObject  = $Kernel::OM->Get('Kernel::System::JSON');

    my $ClassID = $Param{ClassID} || $ParamObject->GetParam( Param => 'ClassID' ) || '';

    my $PrefKeyPrefix                = 'User' . $Param{Source} . 'LinkObjectFilters';
    my $PrefKeyColumnFilters         = $PrefKeyPrefix . $Param{Target} . $ClassID;
    my $PrefKeyColumnFiltersRealKeys = $PrefKeyPrefix . 'RealKeys' . $Param{Target} . $ClassID;
    my $PrefKeyColumnFiltersOrderBy  = $PrefKeyPrefix . $Param{Target} . $ClassID . '-OrderBy';
    my $PrefKeyColumnFiltersSortBy   = $PrefKeyPrefix . $Param{Target} . $ClassID . '-SortBy';
    my %Filters;

    if ( !$Param{OnlyGetPreferences} ) {

        # get sorting and filtering params
        for my $Item (qw(SortBy OrderBy)) {
            $Filters{$Item} = $ParamObject->GetParam( Param => $Item );
        }

        PARAM:
        for my $Key (
            $ParamObject->GetParamNames()
        ) {
            my $Pattern = $Param{Target} . $ClassID . 'ColumnFilter';
            next PARAM if $Key !~ /^$Pattern/;

            my $FilterValue  = $ParamObject->GetParam( Param => $Key ) || '';
            my ($ColumnName) = $Key =~ /^$Pattern(.*)/;

            next PARAM if $FilterValue eq '';

            if ( $ColumnName eq 'CustomerID' ) {
                push @{ $Filters{ColumnFilter}->{$ColumnName} }, $FilterValue;
                push @{ $Filters{ColumnFilter}->{ $ColumnName . 'Raw' } }, $FilterValue;
            }
            elsif ( $ColumnName eq 'CustomerUserID' ) {
                push @{ $Filters{ColumnFilter}->{CustomerUserLogin} },    $FilterValue;
                push @{ $Filters{ColumnFilter}->{CustomerUserLoginRaw} }, $FilterValue;
            }
            else {
                push @{ $Filters{ColumnFilter}->{ $ColumnName . 'IDs' } }, $FilterValue;
            }

            $Filters{GetColumnFilter}->{$ColumnName}       = $FilterValue;
            $Filters{GetColumnFilterSelect}->{$ColumnName} = $FilterValue;
        }
        my $RemoveFilters = $ParamObject->GetParam( Param => 'RemoveFilters' ) || 0;

        if ($RemoveFilters) {
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $PrefKeyColumnFilters,
                Value  => '',
            );
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $PrefKeyColumnFiltersRealKeys,
                Value  => '',
            );
        }

        # just in case new filter values arrive
        elsif (
            IsHashRefWithData( $Filters{GetColumnFilter} )
            && IsHashRefWithData( $Filters{GetColumnFilterSelect} )
            && IsHashRefWithData( $Filters{ColumnFilter} )
        ) {

            # check if the user has filter preferences for this widget
            my %Preferences = $UserObject->GetPreferences(
                UserID => $Self->{UserID},
            );

            my $ColumnPrefValues;
            if ( $Preferences{ $PrefKeyColumnFilters } ) {
                $ColumnPrefValues = $JSONObject->Decode(
                    Data => $Preferences{ $PrefKeyColumnFilters },
                );
            }

            PREFVALUES:
            for my $Column ( sort keys %{ $Filters{GetColumnFilterSelect} } ) {
                if ( $Filters{GetColumnFilterSelect}->{$Column} eq 'DeleteFilter' ) {
                    delete $ColumnPrefValues->{$Column};
                    next PREFVALUES;
                }
                $ColumnPrefValues->{$Column} = $Filters{GetColumnFilterSelect}->{$Column};
            }

            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $PrefKeyColumnFilters,
                Value  => $JSONObject->Encode( Data => $ColumnPrefValues ),
            );

            # save real key's name
            my $ColumnPrefRealKeysValues;
            if ( $Preferences{ $PrefKeyColumnFiltersRealKeys } ) {
                $ColumnPrefRealKeysValues = $JSONObject->Decode(
                    Data => $Preferences{ $PrefKeyColumnFiltersRealKeys },
                );
            }

            REALKEYVALUES:
            for my $Column ( sort keys %{ $Filters{ColumnFilter} } ) {
                next REALKEYVALUES if !$Column;

                my $DeleteFilter = 0;
                if ( IsArrayRefWithData( $Filters{ColumnFilter}->{$Column} ) ) {
                    if ( grep { $_ eq 'DeleteFilter' } @{ $Filters{ColumnFilter}->{$Column} } ) {
                        $DeleteFilter = 1;
                    }
                }
                elsif ( IsHashRefWithData( $Filters{ColumnFilter}->{$Column} ) ) {

                    if (
                        grep { $Filters{ColumnFilter}->{$Column}->{$_} eq 'DeleteFilter' }
                        keys %{ $Filters{ColumnFilter}->{$Column} }
                    ) {
                        $DeleteFilter = 1;
                    }
                }

                if ($DeleteFilter) {
                    delete $ColumnPrefRealKeysValues->{$Column};
                    delete $Filters{ColumnFilter}->{$Column};
                    next REALKEYVALUES;
                }
                $ColumnPrefRealKeysValues->{$Column} = $Filters{ColumnFilter}->{$Column};
            }

            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $PrefKeyColumnFiltersRealKeys,
                Value  => $JSONObject->Encode( Data => $ColumnPrefRealKeysValues ),
            );
        }
    }

    # check if the user has filter preferences for this widget
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    # get column names from Preferences
    my $PreferencesColumnFilters;
    if ( $Preferences{ $PrefKeyColumnFilters } ) {
        $PreferencesColumnFilters = $JSONObject->Decode(
            Data => $Preferences{ $PrefKeyColumnFilters },
        );
    }

    if ($PreferencesColumnFilters) {
        $Filters{GetColumnFilterSelect} = $PreferencesColumnFilters;
        my @ColumnFilters = keys %{$PreferencesColumnFilters};
        for my $Field (@ColumnFilters) {
            $Filters{GetColumnFilter}->{ $Field } = $PreferencesColumnFilters->{$Field};
        }
    }

    # get column real names from Preferences
    my $PreferencesColumnFiltersRealKeys;
    if ( $Preferences{ $PrefKeyColumnFiltersRealKeys } ) {
        $PreferencesColumnFiltersRealKeys = $JSONObject->Decode(
            Data => $Preferences{ $PrefKeyColumnFiltersRealKeys },
        );
    }

    if ($PreferencesColumnFiltersRealKeys) {
        my @ColumnFiltersReal = keys %{$PreferencesColumnFiltersRealKeys};
        for my $Field (@ColumnFiltersReal) {
            $Filters{ColumnFilter}->{$Field} = $PreferencesColumnFiltersRealKeys->{$Field};
        }
    }

    # load and save SortBy and OrderBy
    if ( !$Filters{OrderBy} ) {
        $Filters{OrderBy} = $Preferences{ $PrefKeyColumnFiltersOrderBy } || "Down";
    }
    else {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $PrefKeyColumnFiltersOrderBy,
            Value  => $Filters{OrderBy},
        );
    }

    if ( !$Filters{SortBy} ) {
        $Filters{SortBy}  = $Preferences{ $PrefKeyColumnFiltersSortBy } || '';
    }
    else {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $PrefKeyColumnFiltersSortBy,
            Value  => $Filters{SortBy},
        );
    }

    return %Filters;
}

sub LinkObjectFilterContent {
    my ( $Self, %Param ) = @_;

    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %FilterContent;

    OBJECT:
    for my $Object ( sort { lc $a cmp lc $b } keys %{ $Param{LinkListWithData} } ) {

        # load backend
        my $BackendObject = $Self->_LoadLinkObjectLayoutBackend(
            Object => $Object,
        );

        next OBJECT if !$BackendObject;

        my %Filters;
        if ( $Object eq 'ITSMConfigItem' ) {
            %Filters = $Self->_ColumnFilters(
                Source             => $Param{Source},
                ClassID            => $Param{OnlyClassID},
                Target             => $Object,
                OnlyGetPreferences => 1
            );
        }
        else {
            %Filters = $Self->_ColumnFilters(
                Source             => $Param{Source},
                Target             => $Object,
                OnlyGetPreferences => 1
            );
        }

        my %PossibleFilter;
        my @ItemIDs;
        for my $LinkType ( sort keys %{ $Param{LinkListWithData}->{$Object} } ) {

            my $TypeID = $LinkObject->TypeLookup(
                Name   => $LinkType,
                UserID => $Self->{UserID},
            );
            if ( !$PossibleFilter{$TypeID} ) {
                my %TypeData = $LinkObject->TypeGet(
                    TypeID => $TypeID,
                );
                $PossibleFilter{$TypeID} = $LayoutObject->{LanguageObject}->Translate($TypeData{Name});
            }

            # extract link type List
            my $LinkTypeList = $Param{LinkListWithData}->{$Object}->{$LinkType};
            for my $Direction ( sort keys %{$LinkTypeList} ) {
                # extract direction list
                my $DirectionList = $Param{LinkListWithData}->{$Object}->{$LinkType}->{$Direction};

                push(@ItemIDs, keys %{$DirectionList});
            }
        }

        if ( $Param{FilterColumn} ne 'LinkType' ) {
            # get block data
            $FilterContent{$Object} = $BackendObject->FilterContent(
                ItemIDs          => \@ItemIDs,
                Action           => $Self->{Action},
                Object           => $Object,
                FilterColumn     => $Param{FilterColumn},
                LinkListWithData => $Param{LinkListWithData}->{$Object},
                ClassID          => $Param{OnlyClassID},
                %Filters
            );
        } else {
            my $Label         = $LayoutObject->{LanguageObject}->Translate('Linked as');
            my $SelectedValue = defined $Filters{GetColumnFilter}->{ $Param{FilterColumn} } ? $Filters{GetColumnFilter}->{ $Param{FilterColumn} } : '';

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

            # set possible values
            for my $ValueKey ( sort { lc $PossibleFilter{$a} cmp lc $PossibleFilter{$b} } keys %PossibleFilter ) {
                push @{$Data}, {
                    Key   => $ValueKey,
                    Value => $LayoutObject->{LanguageObject}->Translate($PossibleFilter{$ValueKey})
                };
            }

            # build select HTML
            $FilterContent{$Object} = $LayoutObject->BuildSelectionJSON(
                [
                    {
                        Name         => $Object . $Param{OnlyClassID} . 'ColumnFilter' . $Param{FilterColumn},
                        Data         => $Data,
                        Class        => 'ColumnFilter',
                        Sort         => 'AlphanumericKey',
                        TreeView     => 1,
                        SelectedID   => $SelectedValue,
                        Translation  => 1,
                        AutoComplete => 'off',
                    },
                ],
            );
        }
    }
    return $FilterContent{$Param{Object}};
}

=end Internal:

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
