# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::LinkObject::Ticket;

use strict;
use warnings;

use Kernel::Output::HTML::Layout;
use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Priority',
    'Kernel::System::State',
    'Kernel::System::Type',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
);

=head1 NAME

Kernel::Output::HTML::LinkObject::Ticket - layout backend module

=head1 SYNOPSIS

All layout functions of link object (ticket).

=over 4

=cut

=item new()

create an object

    $BackendObject = Kernel::Output::HTML::LinkObject::Ticket->new(
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

    # We need our own LayoutObject instance to avoid block data collisions
    #   with the main page.
    $Self->{LayoutObject} = Kernel::Output::HTML::Layout->new( %{$Self} );

    # define needed variables
    $Self->{ObjectData} = {
        Object     => 'Ticket',
        Realname   => 'Ticket',
        ObjectName => 'SourceObjectID',
    };

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid      => 0,
        ObjectType => ['Ticket'],
    );

    # set field behaviors
    $Self->{Behaviors} = {
        'IsSortable'  => 1,
    };

    # define sortable columns
    $Self->{ValidSortableColumns} = {
        'TicketNumber'           => 1,
    };

    return $Self;
}

=item TableCreateComplex()

return an array with the block data

Return

    %BlockData = (
        {
            ObjectName  => 'TicketID',
            ObjectID    => '14785',

            Object    => 'Ticket',
            Blockname => 'Ticket',
            Headline  => [
                {
                    Content => 'Number#',
                    Width   => 130,
                },
                {
                    Content => 'Title',
                },
                {
                    Content => 'Created',
                    Width   => 110,
                },
            ],
            ItemList => [
                [
                    {
                        Type     => 'Link',
                        Key      => $TicketID,
                        Content  => '123123123',
                        CssClass => 'StrikeThrough',
                    },
                    {
                        Type      => 'Text',
                        Content   => 'The title',
                        MaxLength => 50,
                    },
                    {
                        Type    => 'TimeLong',
                        Content => '2008-01-01 12:12:00',
                    },
                ],
                [
                    {
                        Type    => 'Link',
                        Key     => $TicketID,
                        Content => '434234',
                    },
                    {
                        Type      => 'Text',
                        Content   => 'The title of ticket 2',
                        MaxLength => 50,
                    },
                    {
                        Type    => 'TimeLong',
                        Content => '2008-01-01 12:12:00',
                    },
                ],
            ],
        },
    );

    @BlockData = $BackendObject->TableCreateComplex(
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

    # get user object
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject    = $Kernel::OM->Get('Kernel::System::Time');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # get user preferences
    my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );

    # convert the list
    my %LinkList;
    for my $LinkType ( sort keys %{ $Param{ObjectLinkListWithData} } ) {

        # extract link type List
        my $LinkTypeList = $Param{ObjectLinkListWithData}->{$LinkType};

        for my $Direction ( sort keys %{$LinkTypeList} ) {

            # extract direction list
            my $DirectionList = $Param{ObjectLinkListWithData}->{$LinkType}->{$Direction};

            for my $TicketID ( sort keys %{$DirectionList} ) {

                # skip showing links to merged tickets
                next
                    if (
                    (
                           !defined $UserPreferences{UserShowMergedTicketsInLinkedObjects}
                        || !$UserPreferences{UserShowMergedTicketsInLinkedObjects}
                    )
                    && $Direction eq 'Target'
                    && $DirectionList->{$TicketID}->{State} eq 'merged'
                    );

                $LinkList{$TicketID}->{Data} = $DirectionList->{$TicketID};
            }
        }
    }

    # create the item list
    my @ItemList;

    # default enabled queues
    my @ColumnsEnabled = ( "TicketNumber", "Title", "Type", "Queue", "State", "Created" );

    if ( defined $Param{EnabledColumns}->{Ticket} && scalar @{ $Param{EnabledColumns}->{Ticket} } ) {
        @ColumnsEnabled = ();
        for my $Column ( @{ $Param{EnabledColumns}->{Ticket} } ) {
            next if $Column eq 'LinkType';
            push @ColumnsEnabled, $Column;
        }
    }

    my @SortedList;
    my $SortBy  = $Param{SortBy}  || 'TicketNumber';
    my $OrderBy = $Param{OrderBy} || 'Down';

    if ( $OrderBy eq 'Down' ) {
        @SortedList = sort { lc $LinkList{$a}{Data}->{$SortBy} cmp lc $LinkList{$b}{Data}->{$SortBy} } keys %LinkList;
    } else {
        @SortedList = sort { lc $LinkList{$b}{Data}->{$SortBy} cmp lc $LinkList{$a}{Data}->{$SortBy} } keys %LinkList;
    }

    TICKET:
    for my $TicketID (
        @SortedList
    ) {

        # extract ticket data
        my $Ticket = $LinkList{$TicketID}{Data};

        if (
            $Self->{Behaviors}->{IsFilterable}
            && $Param{ColumnFilter}
        ) {
            FILTER:
            for my $Key ( sort keys %{$Param{ColumnFilter}} ) {
                my $FilterColumn = $Key;
                $FilterColumn =~ s/IDs$/ID/i;

                next FILTER if $FilterColumn eq 'LinkTypeID';
                next TICKET if !grep( {$_ eq $Ticket->{$FilterColumn} } @{$Param{ColumnFilter}->{$Key}} );
            }
        }

        # set css class
        my $HighlightClass = $LayoutObject->GetTicketHighlight(
            View   => 'Small',
            Ticket => $Ticket
        );

        my $CustomCSSStyle = '';
        if (
            $HighlightClass
            && (
                $Ticket->{StateType} eq 'closed'
                || $Ticket->{StateType} eq 'merged'
            )
        ) {
           $CustomCSSStyle = 'text-decoration: line-through;';
        }

        my @ItemColumns;

        # get ticket escalation preferences
        my $TicketEscalation = $TicketObject->TicketEscalationCheck(
            TicketID => $TicketID,
            UserID   => $Self->{UserID},
        );
        my $TicketEscalationDisabled = $TicketObject->TicketEscalationDisabledCheck(
            TicketID => $TicketID,
            UserID   => $Self->{UserID},
        );

        for my $Column (@ColumnsEnabled) {

            my %TmpHash;
            $TmpHash{Content}        = $Ticket->{$Column};
            $TmpHash{Key}            = $TicketID;
            $TmpHash{HighlightClass} = $HighlightClass;
            $TmpHash{CustomCSSStyle} = $CustomCSSStyle;
            $TmpHash{Type}           = 'Text';

            if ( $TmpHash{Content} ) {

                if ( $Column =~ /^(?:Age|Escalation(!?|Update|Solution|Response)Time)$/ ) {
                    my $Prefix                   = $1 || 'Age';
                    if ( $Prefix eq 'Response' ) {
                        $Prefix = 'FirstResponse';
                    }

                    # return CustomAge for column 'Age'
                    if ( $Prefix eq 'Age' ) {
                        $TmpHash{Content} = $LayoutObject->CustomerAge(
                            Age   => $Ticket->{Age},
                            Space => ' ',
                        );
                    }
                    # return 'suspended' if escalation is disabled
                    elsif (
                        $TicketEscalationDisabled
                        && $TicketEscalation->{ $Prefix }
                    ) {
                        $TmpHash{Translate} = 1;
                        $TmpHash{Content}   = 'suspended';
                    }
                    # return CustomerAgeInHours for escalation columns
                    else {
                        my $Attr = $Prefix . 'Time';

                        $TmpHash{Content} = $LayoutObject->CustomerAgeInHours(
                            Age => $Ticket->{$Attr} || 0,
                            Space => ' ',
                        );
                    }
                }
                elsif ( $Column eq 'PendingTime' ) {
                    my $DisplayPendingTime = $UserPreferences{UserDisplayPendingTime} || '';

                    if ( $DisplayPendingTime && $DisplayPendingTime eq 'RemainingTime' ) {

                        $TmpHash{Content} = $LayoutObject->CustomerAge(
                            Age   => $Ticket->{'UntilTime'},
                            Space => ' ',
                        );
                    }
                    elsif ( defined $Ticket->{UntilTime} && $Ticket->{UntilTime} ) {
                        $TmpHash{Content} = $TimeObject->SystemTime2TimeStamp(
                            SystemTime => $Ticket->{RealTillTimeNotUsed},
                        );
                        $TmpHash{Content} = $LayoutObject->{LanguageObject}->FormatTimeString( $TmpHash{Content}, 'DateFormat' );
                    }
                    else {
                        $TmpHash{Content} = '';
                    }
                }
                elsif ( $Column eq 'TicketNumber' ) {
                    $TmpHash{Type} = 'Link';
                    $TmpHash{Link} = $LayoutObject->{Baselink}
                    . 'Action=AgentTicketZoom;TicketID='
                    . $TicketID;
                }
                elsif ( $Column =~ /(Created|Changed|Time)/ ) {
                    $TmpHash{Type} = 'TimeLong';
                }
                elsif ( $Column eq 'Title' ) {
                    $TmpHash{MaxLength} = 50;
                }
                elsif ( $Column eq 'State' ) {
                    $TmpHash{Translate} = 1;
                }
                elsif ( $Column eq 'Type' ) {
                    $TmpHash{Translate} = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::TypeTranslation') || 0;
                }
                elsif ( $Column eq 'Service' ) {
                    $TmpHash{Translate} = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ServiceTranslation') || 0;
                }
                elsif ( $Column eq 'SLA' ) {
                    $TmpHash{Translate} = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SLATranslation') || 0;
                }

                if ( $Column =~ /^DynamicField_(.*)/ ) {
                    my $Fieldname          = $1;
                    my $DynamicFieldConfig = {};

                    DYNAMICFIELD:
                    for my $DFConfig ( @{ $Self->{DynamicField} } ) {
                        next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
                        next DYNAMICFIELD if $DFConfig->{Name} ne $Fieldname;

                        $DynamicFieldConfig = $DFConfig;
                        last DYNAMICFIELD;
                    }
                    next if !IsHashRefWithData($DynamicFieldConfig);

                    # get field value
                    my $Value = $BackendObject->ValueGet(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        ObjectID           => $TicketID,
                    );

                    my $Valuetrg = $BackendObject->DisplayValueRender(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Value              => $Value,
                        ValueMaxChars      => 20,
                        LayoutObject       => $LayoutObject,
                    );

                    $TmpHash{Content} = $Valuetrg->{Value} || '';
                }
            }
            push( @ItemColumns, \%TmpHash );
        }

        push @ItemList, \@ItemColumns;
    }

    # define the block data
    my $TicketHook        = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Hook');
    my $TicketHookDivider = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::HookDivider');

    my @Headlines;

    my %TranslationHash = (
        'EscalationResponseTime' => 'First Response Time',
        'EscalationSolutionTime' => 'Solution Time',
        'EscalationUpdateTime'   => 'Update Time',
        'PendingTime'            => 'Pending Time',
    );

    for my $Column (@ColumnsEnabled) {
        my %TmpHash;
        my $Content;
        if ( $Column eq 'TicketNumber' ) {
            $Content = $TicketHook;
        }

        elsif ( $Column =~ /^DynamicField_(.*)/ ) {
            my $Fieldname          = $1;
            my $DynamicFieldConfig = {};

            DYNAMICFIELD:
            for my $DFConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DFConfig);
                next DYNAMICFIELD if $DFConfig->{Name} ne $Fieldname;

                $DynamicFieldConfig = $DFConfig;
                last DYNAMICFIELD;
            }
            if ( IsHashRefWithData($DynamicFieldConfig) ) {
                $Content = $LayoutObject->{LanguageObject}->Translate($DynamicFieldConfig->{Label} || '');
            }
        }

        else {
            $Content = $TranslationHash{$Column} || $Column;
        }

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

            my $Css;
            if (
                $Column eq 'CustomerID'
                || $Column eq 'Responsible'
                || $Column eq 'Owner'
            ) {
                $Css = 'Hidden';

            }

            $TmpHash{FilterTitle} = Translatable('filter not active');
            if (
                $Param{GetColumnFilterSelect}
                 && $Param{GetColumnFilterSelect}->{$Column}
            ) {
                $TmpHash{OrderCSS} .= ' FilterActive';
                $TmpHash{FilterTitle} = Translatable('filter active');
            }

            # variable to save the filter's HTML code
            $TmpHash{ColumnFilterStrg} = $Self->_InitialColumnFilter(
                ColumnName => $Column,
                Css        => $Css,
            );
            $TmpHash{ColumnFilterCSS} = $Css;
        }

        if (
            $Self->{Behaviors}->{IsFilterable}
            && $Self->{ValidFilterableColumns}->{$Column}
        ) {
            if ( $Column eq 'CustomerID' ) {
                 $TmpHash{SearchableCustomer} = 1;
            }
            if (
                $Column eq 'Responsible'
                || $Column eq 'Owner'
            ) {
                 $TmpHash{SearchableUser} = 1;
            }
            $TmpHash{Filterable} = 1;
        }

        $TmpHash{Content} = $Content;
        $TmpHash{Width}   = 130;

        push( @Headlines, \%TmpHash );
    }

    my %Block      = (
        Object    => $Self->{ObjectData}->{Object},
        Blockname => $Self->{ObjectData}->{Realname},
        Headline  => \@Headlines,
        ItemList  => \@ItemList,
    );

    return ( \%Block );
}

=item TableCreateSimple()

return a hash with the link output data

Return

    %LinkOutputData = (
        Normal::Source => {
            Ticket => [
                {
                    Type     => 'Link',
                    Content  => 'T:55555',
                    Title    => 'Ticket#555555: The ticket title',
                    CssClass => 'StrikeThrough',
                },
                {
                    Type    => 'Link',
                    Content => 'T:22222',
                    Title   => 'Ticket#22222: Title of ticket 22222',
                },
            ],
        },
        ParentChild::Target => {
            Ticket => [
                {
                    Type    => 'Link',
                    Content => 'T:77777',
                    Title   => 'Ticket#77777: Ticket title',
                },
            ],
        },
    );

    %LinkOutputData = $BackendObject->TableCreateSimple(
        ObjectLinkListWithData => $ObjectLinkListRef,
    );

=cut

sub TableCreateSimple {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ObjectLinkListWithData} || ref $Param{ObjectLinkListWithData} ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ObjectLinkListWithData!'
        );
        return;
    }

    my $TicketHook        = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Hook');
    my $TicketHookDivider = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::HookDivider');
    my %LinkOutputData;
    for my $LinkType ( sort keys %{ $Param{ObjectLinkListWithData} } ) {

        # extract link type List
        my $LinkTypeList = $Param{ObjectLinkListWithData}->{$LinkType};

        for my $Direction ( sort keys %{$LinkTypeList} ) {

            # extract direction list
            my $DirectionList = $Param{ObjectLinkListWithData}->{$LinkType}->{$Direction};

            my @ItemList;
            for my $TicketID ( sort { $a <=> $b } keys %{$DirectionList} ) {

                # extract ticket data
                my $Ticket = $DirectionList->{$TicketID};

                # set css
                my $CssClass;

                if ( $Ticket->{StateType} eq 'closed' || $Ticket->{StateType} eq 'merged' ) {
                    $CssClass = 'StrikeThrough';
                }

                $Ticket->{TitleFull} = $Ticket->{Title};
                if ( length( $Ticket->{Title} ) > 20 ) {
                    $Ticket->{Title} = substr( $Ticket->{Title}, 0, 15 ) . '[...]';
                }

                # define item data
                my %Item = (
                    Type    => 'Link',
                    Content => 'T:' . $Ticket->{TicketNumber} . ' - ' . $Ticket->{Title},
                    Title   => "$TicketHook$TicketHookDivider$Ticket->{TicketNumber}: $Ticket->{Title}",
                    Link    => $Self->{LayoutObject}->{Baselink}
                        . 'Action=AgentTicketZoom;TicketID='
                        . $TicketID,
                    CssClass        => $CssClass,
                    ID              => $TicketID,
                    LinkType        => $LinkType,
                    ObjectType      => 'Ticket',
                    TicketStateType => $Ticket->{StateType},
                );

                push @ItemList, \%Item;
            }

            # add item list to link output data
            $LinkOutputData{ $LinkType . '::' . $Direction }->{Ticket} = \@ItemList;
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
            Message  => 'Need ContentData!'
        );
        return;
    }

    return;
}

=item SelectableObjectList()

return an array hash with selectable objects

Return

    @SelectableObjectList = (
        {
            Key   => 'Ticket',
            Value => 'Ticket',
        },
    );

    @SelectableObjectList = $BackendObject->SelectableObjectList(
        Selected => $Identifier,  # (optional)
    );

=cut

sub SelectableObjectList {
    my ( $Self, %Param ) = @_;

    my $Selected;
    if ( $Param{Selected} && $Param{Selected} eq $Self->{ObjectData}->{Object} ) {
        $Selected = 1;
    }

    # object select list
    my @ObjectSelectList = (
        {
            Key      => $Self->{ObjectData}->{Object},
            Value    => $Self->{ObjectData}->{Realname},
            Selected => $Selected,
        },
    );

    return @ObjectSelectList;
}

=item SearchOptionList()

return an array hash with search options

Return

    @SearchOptionList = (
        {
            Key       => 'TicketNumber',
            Name      => 'Ticket#',
            InputStrg => $FormString,
            FormData  => '1234',
        },
        {
            Key       => 'Title',
            Name      => 'Title',
            InputStrg => $FormString,
            FormData  => 'BlaBla',
        },
    );

    @SearchOptionList = $BackendObject->SearchOptionList(
        SubObject => 'Bla',  # (optional)
    );

=cut

sub SearchOptionList {
    my ( $Self, %Param ) = @_;

    my $ParamHook = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Hook') || 'Ticket#';

    # search option list
    my @SearchOptionList = (
        {
            Key  => 'TicketNumber',
            Name => $ParamHook,
            Type => 'Text',
        },
        {
            Key  => 'TicketTitle',
            Name => Translatable('Title'),
            Type => 'Text',
        },
        {
            Key  => 'TicketFulltext',
            Name => Translatable('Fulltext'),
            Type => 'Text',
        },
        {
            Key  => 'PriorityIDs',
            Name => Translatable('Priority'),
            Type => 'List',
        },
    );

    # set further search criteria according to configuration
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $SearchOptionsRef = $ConfigObject->Get('Ticket::Link::SearchOptions::Order');
    my $SearchNamesRef   = $ConfigObject->Get('Ticket::Link::SearchOptions::Name');
    my $SearchMethodsRef = $ConfigObject->Get('Ticket::Link::SearchOptions::CallMethod');
    if (
        $SearchOptionsRef && ref($SearchOptionsRef) eq 'ARRAY' &&
        $SearchNamesRef   && ref($SearchNamesRef)   eq 'HASH' &&
        $SearchMethodsRef && ref($SearchMethodsRef) eq 'HASH'
    ) {
        for my $Key ( @{$SearchOptionsRef} ) {
            push(
                @SearchOptionList,
                {
                    Key     => $Key,
                    Name    => $SearchNamesRef->{$Key} || $Key,
                    Methods => $SearchMethodsRef->{$Key},
                    Type    => 'List',
                },
            );
        }
    }

    if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ArchiveSystem') ) {
        push @SearchOptionList,
            {
            Key  => 'ArchiveID',
            Name => Translatable('Archive search'),
            Type => 'List',
            };
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

            next ROW;
        }

        # prepare list boxes
        if ( $Row->{Type} eq 'List' ) {

            # get form data
            my @FormData = $Kernel::OM->Get('Kernel::System::Web::Request')->GetArray( Param => $Row->{FormKey} );
            $Row->{FormData} = \@FormData;

            my $Multiple = 1;

            my %ListData;
            if ( $Row->{Methods} && $Row->{Methods} =~ /(\w+)Object::(\w+)/ ) {
                my $Object;
                my $ObjectType = $1;
                my $Method = $2;
                eval {
                    $Object =  $Kernel::OM->Get('Kernel::System::'.$ObjectType);
                    %ListData = $Object->$Method(
                        UserID => $Self->{UserID},
                    );
                };
                if ($@) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "LinkObjectTicket - "
                            . " invalid CallMethod ($Object->$Method) configured "
                            . "(" . $@ . ")!",
                    );
                }
            }

            elsif ( $Row->{Key} eq 'PriorityIDs' ) {
                %ListData = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList(
                    UserID => $Self->{UserID},
                );
            }
            elsif ( $Row->{Key} eq 'TypeIDs' ) {
                %ListData = $Kernel::OM->Get('Kernel::System::Type')->TypeList(
                    UserID => $Self->{UserID},
                );
            }
            elsif ( $Row->{Key} eq 'ArchiveID' ) {
                %ListData = (
                    ArchivedTickets    => Translatable('Archived tickets'),
                    NotArchivedTickets => Translatable('Unarchived tickets'),
                    AllTickets         => Translatable('All tickets'),
                );
                if ( !scalar @{ $Row->{FormData} } ) {
                    $Row->{FormData} = ['NotArchivedTickets'];
                }
                $Multiple = 0;
            }

            # add the input string
            $Row->{InputStrg} = $Self->{LayoutObject}->BuildSelection(
                Data       => \%ListData,
                Name       => $Row->{FormKey},
                SelectedID => $Row->{FormData},
                Size       => 3,
                Multiple   => $Multiple,
                Class      => 'Modernize',
            );

            next ROW;
        }

        if ( $Row->{Type} eq 'Checkbox' ) {

            # get form data
            $Row->{FormData} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Row->{FormKey} );

            # parse the input text block
            $Self->{LayoutObject}->Block(
                Name => 'Checkbox',
                Data => {
                    Name    => $Row->{FormKey},
                    Title   => $Row->{FormKey},
                    Content => $Row->{FormKey},
                    Checked => $Row->{FormData} || '',
                },
            );

            # add the input string
            $Row->{InputStrg} = $Self->{LayoutObject}->Output(
                TemplateFile => 'LinkObject',
            );

            next ROW;
        }
    }

    return @SearchOptionList;
}

sub _InitialColumnFilter {
    my ( $Self, %Param ) = @_;

    return if !$Param{ColumnName};

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Label = $Param{Label} || $Param{ColumnName};
    $Label = $LayoutObject->{LanguageObject}->Translate($Label);

    # set fixed values
    my $Data = [
        {
            Key   => '',
            Value => uc $Label,
        },
    ];

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'State'
        || $Param{ColumnName} eq 'Lock'
        || $Param{ColumnName} eq 'Priority'
    ) {
        $TranslationOption = 1;
    }

    my $Class = 'ColumnFilter';
    if ( $Param{Css} ) {
        $Class .= ' ' . $Param{Css};
    }

    # build select HTML
    my $ColumnFilterHTML = $LayoutObject->BuildSelection(
        Name        => 'TicketColumnFilter' . $Param{ColumnName},
        Data        => $Data,
        Class       => $Class,
        Translation => $TranslationOption,
        SelectedID  => '',
    );
    return $ColumnFilterHTML;
}

sub FilterContent {
    my ( $Self, %Param ) = @_;

    return if !$Param{FilterColumn};

    my $FunctionName = $Param{FilterColumn} . 'FilterValuesGet';
    if ( $Param{FilterColumn} eq 'CustomerID' ) {
        $FunctionName = 'CustomerFilterValuesGet';
    }

    my $ColumnValues = $Kernel::OM->Get('Kernel::System::Ticket::ColumnFilter')->$FunctionName(
        TicketIDs    => $Param{ItemIDs},
        HeaderColumn => $Param{FilterColumn},
        UserID       => $Self->{UserID},
    );

    # make sure that even a value of 0 is passed as a Selected value, e.g. Unchecked value of a
    # check-box dynamic field.
    my $SelectedValue = defined $Param{GetColumnFilter}->{ $Param{FilterColumn} } ? $Param{GetColumnFilter}->{ $Param{FilterColumn} } : '';

    my $LabelColumn = $Param{FilterColumn};

    # variable to save the filter's HTML code
    my $ColumnFilterJSON = $Self->_ColumnFilterJSON(
        ColumnName    => $Param{FilterColumn},
        Label         => $LabelColumn,
        ColumnValues  => $ColumnValues,
        SelectedValue => $SelectedValue,
    );
    return $ColumnFilterJSON;
}

sub _ColumnFilterJSON {
    my ( $Self, %Param ) = @_;

    return if !$Param{ColumnName};
    return if !$Self->{ValidFilterableColumns}->{ $Param{ColumnName} };

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Label = $Param{Label};
    $Label = $LayoutObject->{LanguageObject}->Translate($Label);

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

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'State'
        || $Param{ColumnName} eq 'Lock'
        || $Param{ColumnName} eq 'Priority'
    ) {
        $TranslationOption = 1;
    }

    # build select HTML
    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            {
                Name         => 'TicketColumnFilter' . $Param{ColumnName},
                Data         => $Data,
                Class        => 'ColumnFilter',
                Sort         => 'AlphanumericKey',
                TreeView     => 1,
                SelectedID   => $Param{SelectedValue},
                Translation  => $TranslationOption,
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
