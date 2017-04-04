# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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

        return $Self->LinkObjectTableCreateSimple(

            # KIX4OTRS-capeIT
            %Param,

            # EO KIX4OTRS-capeIT
            LinkListWithData => $Param{LinkListWithData},
            ViewMode         => $Param{ViewMode},
        );
    }
    else {

        return $Self->LinkObjectTableCreateComplex(

            # KIX4OTRS-capeIT
            %Param,

            # EO KIX4OTRS-capeIT
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
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

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

    # convert the link list
    my %LinkList;

    # KIX4OTRS-capeIT
    # get user data
    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData( UserID => $Self->{UserID} );
    my @UserLinkObjectTablePosition = ();
    if ( $UserData{ 'UserLinkObjectTablePosition-' . $Self->{Action} } ) {
        @UserLinkObjectTablePosition
            = split( /;/, $UserData{ 'UserLinkObjectTablePosition-' . $Self->{Action} } );
    }
    my %DirectionTypeList;

    # EO KIX4OTRS-capeIT

    for my $Object ( sort keys %{ $Param{LinkListWithData} } ) {

        for my $LinkType ( sort keys %{ $Param{LinkListWithData}->{$Object} } ) {

            # extract link type List
            my $LinkTypeList = $Param{LinkListWithData}->{$Object}->{$LinkType};

            for my $Direction ( sort keys %{$LinkTypeList} ) {

                # extract direction list
                my $DirectionList = $Param{LinkListWithData}->{$Object}->{$LinkType}->{$Direction};

                for my $ObjectKey ( sort keys %{$DirectionList} ) {

                    $LinkList{$Object}->{$ObjectKey}->{$LinkType} = $Direction;

                    # KIX4OTRS-capeIT
                    $DirectionTypeList{$Object}->{$ObjectKey}->{Direction} = $Direction;
                    $DirectionTypeList{$Object}->{$ObjectKey}->{Type}      = $LinkType;

                    # EO KIX4OTRS-capeIT

                }
            }
        }
    }

    my @OutputData;

    # KIX4OTRS-capeIT
    my %EnabledColumns;
    my @LinkObjects = ();

    # EO KIX4OTRS-capeIT
    OBJECT:
    for my $Object ( sort { lc $a cmp lc $b } keys %{ $Param{LinkListWithData} } ) {

        # KIX4OTRS-capeIT
        # get enabled columns for each object
        for my $Item ( keys %UserData ) {
            next if $Item !~ /^UserFilterColumnsEnabled-$Self->{Action}-$Object(-?)(.*?)$/;
            my $Enabled = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
                Data => $UserData{
                    'UserFilterColumnsEnabled-'
                        . $Self->{Action} . '-'
                        . $Object
                        . $1
                        . $2
                    },
            );
            $EnabledColumns{ $Object . $1 . $2 } = $Enabled;
        }

        # EO KIX4OTRS-capeIT

        # load backend
        my $BackendObject = $Self->_LoadLinkObjectLayoutBackend(
            Object => $Object,
        );

        next OBJECT if !$BackendObject;

        # get block data
        my @BlockData = $BackendObject->TableCreateComplex(
            ObjectLinkListWithData => $Param{LinkListWithData}->{$Object},
            Action                 => $Self->{Action},
            ObjectID               => $Param{ObjectID},

            # KIX4OTRS-capeIT
            EnabledColumns => \%EnabledColumns,

            # EO KIX4OTRS-capeIT
        );

        next OBJECT if !@BlockData;

        push @OutputData, @BlockData;
    }

    # KIX4OTRS-capeIT
    # create new instance of the layout object
    my $LayoutObject  = Kernel::Output::HTML::Layout->new( %{$Self} );
    my $LayoutObject2 = Kernel::Output::HTML::Layout->new( %{$Self} );

    # get preferences string
    return $Self->_PreferencesLinkObject(
        OutputData     => \@OutputData,
        EnabledColumns => \%EnabledColumns,
        LayoutObject   => $LayoutObject,
    ) if $Param{GetPreferences};

    # EO KIX4OTRS-capeIT

    # error handling
    for my $Block (@OutputData) {

        # KIX4OTRS-capeIT
        if ( !grep { $_ eq $Block->{Blockname} } @LinkObjects ) {
            push @LinkObjects, $Block->{Blockname};
        }

        # EO KIX4OTRS-capeIT

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

    # KIX4OTRS-capeIT
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

    # EO KIX4OTRS-capeIT

    # add "linked as" column to the table
    for my $Block (@OutputData) {

        # KIX4OTRS-capeIT
        my ( $Placeholder1, $Placeholder2, $Class ) = ( '', '', '' );

        if ( $Block->{Object} eq 'ITSMConfigItem' ) {
            $Block->{Blockname} =~ /^ConfigItem\s\((.*?)\)$/;
            ( $Placeholder1, $Placeholder2, $Class ) = ( '-', '_', $1 );
        }

        my $NoColumnsEnabled = 0;
        if ( !defined $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } ) {
            $NoColumnsEnabled = 1;
        }

        if (
            ( grep { $_ eq 'LinkType' }
            @{ $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } } )
            || $NoColumnsEnabled
            )
        {

            # EO KIX4OTRS-capeIT

            # define the headline column
            my $Column = {
                Content => 'Linked as',
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
            };

            # add check-box cell to item
            push @{$Item}, $CheckboxCell;
            }

            # KIX4OTRS-capeIT
        }

        # EO KIX4OTRS-capeIT
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

        # KIX4OTRS-capeIT
        my $LinkListWithData = $Param{LinkListWithData};

        # EO KIX4OTRS-capeIT

        for my $Block (@OutputData) {

            # define the headline column
            my $Column = {
                Content => ' ',
            };

            # add new column to the headline
            unshift @{ $Block->{Headline} }, $Column;

            for my $Item ( @{ $Block->{ItemList} } ) {

                # KIX4OTRS-capeIT
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

                # EO KIX4OTRS-capeIT

                # define check-box delete cell
                my $CheckboxCell = {
                    Type         => 'CheckboxDelete',
                    Object       => $Block->{Object},
                    Content      => '',
                    Key          => $Item->[0]->{Key},
                    LinkTypeList => $LinkList{ $Block->{Object} }->{ $Item->[0]->{Key} },
                    Translate    => 1,

                    # KIX4OTRS-capeIT
                    SourceObject => $SourceObject,
                    SourceKey    => $SourceKey

                        # EO KIX4OTRS-capeIT
                };

                # KIX4OTRS-capeIT
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
                    )
                {
                    $CheckboxCell = {
                        Type => 'Text'
                        }
                }

                # EO KIX4OTRS-capeIT

                # $CheckboxCell = {};

                # add checkbox cell to item
                # KIX4OTRS-capeIT
                if (
                    !(
                        $Block->{Object} eq 'ITSMConfigItem'
                        && defined $Param{LinkConfigItem}
                        && !$Param{LinkConfigItem}
                    )
                    )
                {

                    # EO KIX4OTRS-capeIT
                    unshift @{$Item}, $CheckboxCell;

                    # KIX4OTRS-capeIT
                }

                # EO KIX4OTRS-capeIT
            }
        }
    }

    # output the table complex block
    $LayoutObject->Block(
        Name => 'TableComplex',
    );

    # set block description
    my $BlockDescription = $Param{ViewMode} eq 'ComplexAdd' ? Translatable('Search Result') : Translatable('Linked');

    my $BlockCounter = 0;

# KIX4OTRS-capeIT
# OTRS complex table settings
# disabled because KIX4OTRS brings own link object table preferences settings
# EO KIX4OTRS-capeIT

    BLOCK:
    for my $Block (@OutputData) {

        next BLOCK if !$Block->{ItemList};
        next BLOCK if ref $Block->{ItemList} ne 'ARRAY';
        next BLOCK if !@{ $Block->{ItemList} };

        # KIX4OTRS-capeIT
        my ( $Placeholder1, $Placeholder2, $Class ) = ( '', '', '' );
        if ( $Block->{Object} eq 'ITSMConfigItem' ) {
            $Block->{Blockname} =~ /^ConfigItem\s\((.*?)\)$/;
            ( $Placeholder1, $Placeholder2, $Class ) = ( '-', '_', $1 );
        }

        # EO KIX4OTRS-capeIT

        # output the block
        $LayoutObject->Block(
            Name => 'TableComplexBlock',
            Data => {
                BlockDescription => $BlockDescription,
                Blockname        => $Block->{Blockname} || '',
                Name             => $Block->{Blockname},
                NameForm         => $Block->{Blockname},
                AJAX             => $Param{AJAX},

                # KIX4OTRS-capeIT
                LinkType      => $Block->{Object},
                PreferencesID => $Block->{Object} . $Placeholder2 . $Class,

                # EO KIX4OTRS-capeIT
            },
        );

# KIX4OTRS-capeIT
# OTRS complex table settings
# disabled because KIX4OTRS brings own link object table preferences settings
# EO KIX4OTRS-capeIT

        # output table headline
        for my $HeadlineColumn ( @{ $Block->{Headline} } ) {

            # output a headline column block
            $LayoutObject->Block(
                Name => 'TableComplexBlockColumn',
                Data => $HeadlineColumn,
            );
        }

        # output item list
        for my $Row ( @{ $Block->{ItemList} } ) {

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
        TemplateFile   => 'LinkObject',
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

    # KIX4OTRS-capeIT
    if ( $Param{FilterModule} && $Param{FilterMethod} ) {
        my $FilterMethod = $Param{FilterMethod};
        @SelectableObjectList = $Param{FilterModule}->$FilterMethod(
            %Param,
            List => \@SelectableObjectList,
        );
    }

    # EO KIX4OTRS-capeIT

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

# KIX4OTRS-capeIT
# ComplexTablePreferencesGet()
# disabled because KIX4OTRS brings own link object table preferences settings
# EO KIX4OTRS-capeIT

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
            Text => $String || '-',
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

            # KIX4OTRS-capeIT
            my $SourceObject = $Content->{SourceObject} || '-';
            my $SourceKey    = $Content->{SourceKey}    || '-';

            # EO KIX4OTRS-capeIT

            # run checkbox block
            $Param{LayoutObject}->Block(
                Name => 'Checkbox',
                Data => {
                    %{$Content},
                    Name  => 'LinkDeleteIdentifier',
                    Title => $LinkName,

                    # KIX4OTRS-capeIT
                    # Content => $Content->{Object} . '::' . $Content->{Key} . '::' . $LinkType,
                    Content => $SourceObject . '::'
                        . $SourceKey . '::'
                        . $Content->{Object} . '::'
                        . $Content->{Key} . '::'
                        . $LinkType,

                    # EO KIX4OTRS-capeIT
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

# KIX4OTRS-capeIT
sub _PreferencesLinkObject {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $JSONObject   = $Kernel::OM->Get('Kernel::System::JSON');

    my @OutputData     = @{ $Param{OutputData} };
    my %EnabledColumns = %{ $Param{EnabledColumns} };
    my $LayoutObject   = $Param{LayoutObject};

    # KIX4OTRS-capeIT
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

            # check if user columns enabled
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
                )
            {
                @{ $EnabledColumns{ $Block->{Object} } }
                    = ( "TicketNumber", "Title", "Type", "Queue", "State", "Created" );

                # add link type by default if no user enabled columns defined
                push @{ $EnabledColumns{ $Block->{Object} } }, 'LinkType';
            }

            # get default available columns
            for my $Col ( %{$ConfigHash} ) {
                next if !$ConfigHash->{$Col};
                $DefaultColumnHash{$Col} = $TranslationHash{$Col}
                    || $LayoutObject->{LanguageObject}->Translate($Col);
            }

        }

        # for itsm-change object
        elsif ( $Block->{Object} eq 'ITSMChange' ) {
            $ConfigHash = $ConfigObject->Get('ITSMChange::Frontend::AgentITSMChange');

            # check if user columns enabled
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
                )
            {
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
                )
            {
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
            $ConfigHash
                = $ConfigObject->Get('ITSMConfigItem::Frontend::AgentITSMConfigItem');

            # get class
            $Block->{Blockname} =~ /^ConfigItem\s\((.*?)\)$/;
            ( $Class, $Placeholder1, $Placeholder2 ) = ( $1, '-', '_' );

            # check if user columns enabled
            if (
                !defined $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class }
                || !scalar @{ $EnabledColumns{ $Block->{Object} . $Placeholder1 . $Class } }
                )
            {
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
                    $DefaultColumnHash{$Col} = $LayoutObject->{LanguageObject}
                        ->Get( $TranslationHash{$Col} );
                }
                else {
                    $DefaultColumnHash{$Col}
                        = $LayoutObject->{LanguageObject}->Translate($Col);
                }
            }

            # get the column config
            my $ColumnConfig
                = $ConfigObject->Get('LinkObject::ITSMConfigItem::ShowColumnsByClass');

            # get the configered columns and reorganize them by class name
            my %ColumnByClass;
            if ( $ColumnConfig && ref $ColumnConfig eq 'ARRAY' && @{$ColumnConfig} ) {
                for my $Name ( @{$ColumnConfig} ) {

                    # extract the class name and the column name
                    if ( $Name =~ m{ \A ([^:]+) :: (.+) \z }xms ) {
                        my ( $DefinedClass, $Col ) = ( $1, $2 );

                        # create new entry
                        if ( $DefinedClass eq $Class ) {
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
                )
            {
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
            my $ConfigHash = $ConfigObject->Get('Document::DefaultColumns');

            # check if user columns enabled
            my $UserColumnsEnabled = 1;
            if (
                !defined $EnabledColumns{ $Block->{Object} }
                || !scalar @{ $EnabledColumns{ $Block->{Object} } }
                )
            {
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
            )
        {
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
            $RequestURL
                =~ s/Agent(.*?)ZoomTabLinkedObjects;(.*?)DirectLinkAnchor=(.*?);?(.*)/Agent$1Zoom;$2$4/;
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
                Name          => $Self->{Action} . '-' . $Block->{Object} . $Placeholder1 . $Class,
                GroupName     => 'LinkedObjectFilterSettings',
                PreferencesID => $Block->{Object} . $Placeholder2 . $Class,
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

# EO KIX4OTRS-capeIT

=end Internal:

=cut

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
