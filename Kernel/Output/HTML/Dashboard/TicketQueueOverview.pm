# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::TicketQueueOverview;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed parameters
    for my $Needed (qw( Config Name UserID )) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    $Self->{PrefKey}  = 'UserDashboardPref' . $Self->{Name} . '-Shown';
    $Self->{CacheKey} = $Self->{Name} . '-' . $Self->{UserID};

    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StateObject   = $Kernel::OM->Get('Kernel::System::State');
    my $QueueObject   = $Kernel::OM->Get('Kernel::System::Queue');
    my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');
    my $TypeObject    = $Kernel::OM->Get('Kernel::System::Type');

    # set default col/row selections...
    $LayoutObject->{ $Self->{PrefKey} . '-Row' } = "StateIDs"
        if ( !$LayoutObject->{ $Self->{PrefKey} . '-Row' } );
    $LayoutObject->{ $Self->{PrefKey} . '-Column' } = "QueueIDs"
        if ( !$LayoutObject->{ $Self->{PrefKey} . '-Column' } );

    my %RowValueList        = ();
    my %RowValueListReverse = ();
    my %ColValueList        = ();
    my %ColValueListReverse = ();

    if ( $LayoutObject->{ $Self->{PrefKey} . '-Column' } eq 'StateIDs' ) {
        %ColValueList = $StateObject->StateList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Column' } eq 'StateTypeIDs' ) {
        %ColValueList = $StateObject->StateTypeList(
            UserID => $Self->{UserID},
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Column' } eq 'QueueIDs' ) {
        %ColValueList = $QueueObject->GetAllQueues(
            UserID => $Self->{UserID},
            Type => $Self->{Config}->{Permission} || 'ro',
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Column' } eq 'ServiceIDs' ) {
        %ColValueList = $ServiceObject->ServiceList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Column' } eq 'TypeIDs' ) {
        %ColValueList = $TypeObject->TypeList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
    }
    %ColValueListReverse = reverse(%ColValueList);

    if ( $LayoutObject->{ $Self->{PrefKey} . '-Row' } eq 'StateIDs' ) {
        %RowValueList = $StateObject->StateList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Row' } eq 'StateTypeIDs' ) {
        %RowValueList = $StateObject->StateTypeList(
            UserID => $Self->{UserID},
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Row' } eq 'QueueIDs' ) {
        %RowValueList = $QueueObject->QueueList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Row' } eq 'ServiceIDs' ) {
        %RowValueList = $ServiceObject->ServiceList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
    }
    elsif ( $LayoutObject->{ $Self->{PrefKey} . '-Row' } eq 'TypeIDs' ) {
        %RowValueList = $TypeObject->TypeList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
    }
    %RowValueListReverse = reverse(%RowValueList);

    $Self->{RowValueList}        = \%RowValueList;
    $Self->{RowValueListReverse} = \%RowValueListReverse;
    $Self->{ColValueList}        = \%ColValueList;
    $Self->{ColValueListReverse} = \%ColValueListReverse;

    $Self->{SearchAttributes} = {
        "StateIDs"     => "State",
        "StateTypeIDs" => "Statetype",
        "QueueIDs"     => "Queue",

        #...TO DO :: code must be extended to be more configurable...
    };
    if ( $ConfigObject->Get('Ticket::Type') ) {
        $Self->{SearchAttributes}->{'TypeIDs'} = 'Type';
    }
    if ( $ConfigObject->Get('Ticket::Service') ) {
        $Self->{SearchAttributes}->{'ServiceIDs'} = 'Service';
    }

    for my $CurrAttribute ( keys( %{ $Self->{SearchAttributes} } ) ) {
        $Self->{ $CurrAttribute . "Strg" } =
            $LayoutObject->{ $Self->{PrefKey} . '-' . $CurrAttribute } || '';
        my @SelectedValArr = split( ",", $Self->{ $CurrAttribute . "Strg" } );
        $Self->{$CurrAttribute} = \@SelectedValArr;

        if (
            !@SelectedValArr
            && ( $CurrAttribute eq $LayoutObject->{ $Self->{PrefKey} . '-Row' } )
        ) {
            my @DefRowValues = keys( %{ $Self->{RowValueList} } );
            $Self->{$CurrAttribute} = \@DefRowValues;
        }
        if (
            !@SelectedValArr
            && ( $CurrAttribute eq $LayoutObject->{ $Self->{PrefKey} . '-Column' } )
        ) {
            my @DefColValues = keys( %{ $Self->{ColValueList} } );
            $Self->{$CurrAttribute} = \@DefColValues;
        }
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    my @Params = ();

    # get needed objects
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $StateObject   = $Kernel::OM->Get('Kernel::System::State');
    my $QueueObject   = $Kernel::OM->Get('Kernel::System::Queue');
    my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');
    my $TypeObject    = $Kernel::OM->Get('Kernel::System::Type');

    # ROW and COLUMN definition (define which following search params are used)...
    my %ColumnSelection = (
        Desc        => 'Column',
        Name        => $Self->{PrefKey} . '-Column',
        Block       => 'Option',
        Data        => $Self->{SearchAttributes},
        SelectedID  => $Self->{ $Self->{PrefKey} . '-Column' },
        Translation => 1,
    );
    push( @Params, \%ColumnSelection );

    my %ColumnTotal = (
        Desc        => 'Show Column Total',
        Name        => $Self->{PrefKey} . '-ColumnTotal',
        Block       => 'Checkbox',
        SelectedID  => $LayoutObject->{ $Self->{PrefKey} . '-ColumnTotal' },
        Translation => 1,
    );
    push( @Params, \%ColumnTotal );

    my %RowSelection = (
        Desc        => 'Row',
        Name        => $Self->{PrefKey} . '-Row',
        Block       => 'Option',
        Data        => $Self->{SearchAttributes},
        SelectedID  => $Self->{ $Self->{PrefKey} . '-Row' },
        Translation => 1,
    );
    push( @Params, \%RowSelection );

    my %RowTotal = (
        Desc        => 'Show Row Total',
        Name        => $Self->{PrefKey} . '-RowTotal',
        Block       => 'Checkbox',
        SelectedID  => $LayoutObject->{ $Self->{PrefKey} . '-RowTotal' },
        Translation => 1,
    );
    push( @Params, \%RowTotal );

    # Stateselection...
    my %StateList = $StateObject->StateList(
        Valid  => 1,
        UserID => $Self->{UserID},
    );

    my %StateSelection = (
        Desc        => 'States',
        Name        => $Self->{PrefKey} . '-StateIDs',
        Block       => 'Option',
        Multiple    => 1,
        Data        => \%StateList,
        SelectedID  => $Self->{StateIDs},
        Translation => 1,
    );
    push( @Params, \%StateSelection );

    # StateType selection...
    my %StateTypeList = $StateObject->StateTypeList(
        UserID => $Self->{UserID},
    );
    my %StateTypeSelection = (
        Desc        => 'StateTypes',
        Name        => $Self->{PrefKey} . '-StateTypeIDs',
        Block       => 'Option',
        Multiple    => 1,
        Data        => \%StateTypeList,
        SelectedID  => $Self->{StateTypeIDs},
        Translation => 1,
    );
    push( @Params, \%StateTypeSelection );

    # Queue selection...
    my %QueueList = $QueueObject->GetAllQueues(
        UserID => $Self->{UserID},
        Type => $Self->{Config}->{Permission} || 'ro',
    );
    my %QueueSelection = (
        Desc        => 'Queues',
        Name        => $Self->{PrefKey} . '-QueueIDs',
        Block       => 'Option',
        Multiple    => 1,
        Data        => \%QueueList,
        SelectedID  => $Self->{QueueIDs},
        Translation => 0,
    );
    push( @Params, \%QueueSelection );

    # Service selection (if enabled)...
    if ( $ConfigObject->Get('Ticket::Service') ) {
        my %ServiceList = $ServiceObject->ServiceList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
        my %ServiceSelection = (
            Desc        => 'Services',
            Name        => $Self->{PrefKey} . '-ServiceIDs',
            Block       => 'Option',
            Multiple    => 1,
            Data        => \%ServiceList,
            SelectedID  => $Self->{ServiceIDs},
            Translation => $ConfigObject->Get('Ticket::ServiceTranslation'),
        );
        push( @Params, \%ServiceSelection );
    }

    # Type selection (if enabled)...
    if ( $ConfigObject->Get('Ticket::Type') ) {
        my %TypeList = $TypeObject->TypeList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
        my %TypeSelection = (
            Desc        => 'Types',
            Name        => $Self->{PrefKey} . '-TypeIDs',
            Block       => 'Option',
            Multiple    => 1,
            Data        => \%TypeList,
            SelectedID  => $Self->{TypeIDs},
            Translation => $ConfigObject->Get('Ticket::TypeTranslation'),
        );
        push( @Params, \%TypeSelection );
    }

    return @Params;
}

sub Config {
    my ( $Self, %Param ) = @_;

    # check if frontend module of link is used
    if ( $Self->{Config}->{Link} && $Self->{Config}->{Link} =~ /Action=(.+?)(&.+?|)$/ ) {
        my $Action = $1;
        if ( !v->Get('Frontend::Module')->{$Action} ) {
            $Self->{Config}->{Link} = '';
        }
    }

    return (
        %{ $Self->{Config} },

        # remember, do not allow to use page cache
        # (it's not working because of internal filter)
        CacheKey => undef,
        CacheTTL => undef,
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $LimitGroup = $Self->{Config}->{QueuePermissionGroup} || 0;
    my $CacheKey = 'User' . '-' . $Self->{UserID} . '-' . $LimitGroup;

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    my $Content = $CacheObject->Get(
        Type => 'DashboardQueueOverview',
        Key  => $CacheKey,
    );
    return $Content if defined $Content;

    # get all search base attributes
    my %TicketSearch;
    my %DynamicFieldsParameters;
    my @Params     = split( ';', $Self->{Config}->{Attributes} );
    my @Attributes = qw(
        StateType StateTypeIDs States StateIDs
        Queues QueueIDs
        Types TypeIDs
        Priorities PriorityIDs
        Services ServiceIDs SLAs SLAIDs
        Locks LockIDs
        OwnerIDs ResponsibleIDs WatchUserIDs
        ArchiveFlags
    );

    for my $String (@Params) {
        next if !$String;
        my ( $Key, $Value ) = split( '=', $String );

        # push ARRAYREF attributes directly in an ARRAYREF
        if ( grep( { $Key eq $_ } @Attributes ) ) {
            push @{ $TicketSearch{$Key} }, $Value;
        }
        elsif ( $Key =~ m{\A (DynamicField_.+?) _ (.+?) \z}sxm ) {
            $DynamicFieldsParameters{$1}->{$2} = $Value;
        }
        elsif ( !defined $TicketSearch{$Key} ) {
            $TicketSearch{$Key} = $Value;
        }
        elsif ( !ref $TicketSearch{$Key} ) {
            my $ValueTmp = $TicketSearch{$Key};
            $TicketSearch{$Key} = [$ValueTmp];
            push @{ $TicketSearch{$Key} }, $Value;
        }
        else {
            push @{ $TicketSearch{$Key} }, $Value;
        }
    }

    my $ColAttribute = $LayoutObject->{ $Self->{PrefKey} . '-Column' };
    my $RowAttribute = $LayoutObject->{ $Self->{PrefKey} . '-Row' };
    my $ColValues    = $Self->{$ColAttribute};
    my $RowValues    = $Self->{$RowAttribute};

    # check cache
    my $Summary = $CacheObject->Get(
        Type => 'Dashboard',
        Key  => $CacheKey . '-Summary',
    );

    %TicketSearch = (
        %TicketSearch,
        %DynamicFieldsParameters,
        Permission => $Self->{Config}->{Permission} || 'ro',
        UserID => $Self->{UserID},
    );

    # perform searches/counts...
    my @CountData   = qw{};
    my @ColHeadline = qw{};
    my $RowCount    = 0;
    for my $CurrRowValue ( @{$RowValues} ) {
        my @RowData = qw{};
        push( @RowData, $Self->{RowValueList}->{$CurrRowValue} );

        for my $CurrColValue ( @{$ColValues} ) {
            push( @ColHeadline, $Self->{ColValueList}->{$CurrColValue} ) if ( $RowCount < 1 );
            my $NumberOfTickets = $TicketObject->TicketSearch(
                Result => 'COUNT',
                %TicketSearch,
                $RowAttribute => [$CurrRowValue],
                $ColAttribute => [$CurrColValue],
            );
            push( @RowData, $NumberOfTickets || '0' );
        }
        push( @CountData, \@RowData );
        $RowCount++;
    }

    # display column headers...
    my @ColTotals = qw{};
    for my $CurrCol (@ColHeadline) {
        if (
            $ColAttribute ne 'QueueIDs'
            && (
                $ColAttribute ne 'ServiceIDs'
                || $ConfigObject->Get('Ticket::ServiceTranslation')
            )
            && (
                $ColAttribute ne 'TypeIDs'
                || $ConfigObject->Get('Ticket::TypeTranslation')
            )
        ) {
            $CurrCol = $LayoutObject->{LanguageObject}->Translate($CurrCol);
        }
        $LayoutObject->Block(
            Name => 'ContentColumnLabel',
            Data => {
                'ColumnLabel'   => $CurrCol,
                'cssClass'      => 'Sortable header',
                'SessionID'     => $LayoutObject->{'SessionID'},
                'SearchPattern' => $ColAttribute . "=$Self->{ColValueListReverse}->{$CurrCol};",
            },
        );
    }

    if ( $LayoutObject->{ $Self->{PrefKey} . '-RowTotal' } ) {
        $LayoutObject->Block(
            Name => 'ContentColumnLabel',
            Data => {
                'ColumnLabel' => $LayoutObject->{LanguageObject}->Translate('Total'),
                'cssClass'    => 'Sortable header',
            },
        );
    }

    # display column contents...
    my %ColTotal = qw{};
    for my $CurrRow (@CountData) {

        my @CurrRowArr   = @{$CurrRow};
        my $ColCount     = 0;
        my $CurrColLabel = "";
        my $RowTotal     = 0;
        for my $CurrCol (@CurrRowArr) {

            next if !defined($CurrCol);

            $ColCount++;
            if ( $ColCount < 2 ) {
                $CurrColLabel = $CurrCol;
                my $CurrRowLabel = $CurrCol;
                if (
                    $RowAttribute ne 'QueueIDs'
                    && (
                        $RowAttribute ne 'ServiceIDs'
                        || $ConfigObject->Get('Ticket::ServiceTranslation')
                    )
                    && (
                        $RowAttribute ne 'TypeIDs'
                        || $ConfigObject->Get('Ticket::TypeTranslation')
                    )
                ) {
                    $CurrRowLabel = $LayoutObject->{LanguageObject}->Translate($CurrCol);
                }
                $LayoutObject->Block(
                    Name => 'ContentRow',
                    Data => {
                        'cssClass'      => 'Sortable header',
                        'Label'         => $CurrRowLabel,
                        'SessionID'     => $LayoutObject->{'SessionID'},
                        'SearchPattern' => $RowAttribute . "="
                            . $Self->{RowValueListReverse}->{$CurrCol} . ";",
                    },
                );
            }
            else {
                $RowTotal += $CurrCol;
                $ColTotal{$ColCount} = int( $ColTotal{$ColCount} || 0 ) + int( $CurrCol || 0 );
                $LayoutObject->Block(
                    Name => 'ContentColumn',
                    Data => {
                        'cssClass'      => 'Sortable header',
                        'Number'        => $CurrCol,
                        'SearchPattern' => $RowAttribute
                            . "="
                            . $Self->{RowValueListReverse}->{$CurrColLabel}
                            . ";"
                            . $ColAttribute
                            . "="
                            . $Self->{ColValueListReverse}->{ $ColHeadline[ $ColCount - 2 ] }
                            . ";",
                    },
                );
            }
        }

        if ( $LayoutObject->{ $Self->{PrefKey} . '-RowTotal' } ) {
            $LayoutObject->Block(
                Name => 'ContentColumn',
                Data => {
                    'cssClass' => '',
                    'Number'   => $RowTotal,
                    'SearchPattern' => $RowAttribute
                        . "="
                        . $Self->{RowValueListReverse}->{$CurrColLabel}
                        . ";",
                },
            );
        }

    }

    if ( $LayoutObject->{ $Self->{PrefKey} . '-ColumnTotal' } ) {

        $LayoutObject->Block(
            Name => 'FootRow',
            Data => { 'Label' => 'Total', },
        );
        for my $ColCount ( sort {$a <=> $b} keys %ColTotal  ) {
            $LayoutObject->Block(
                Name => 'FootColumn',
                Data => {
                    'Number' => $ColTotal{$ColCount} || '0',
                },
            );
        }
        if ( $LayoutObject->{ $Self->{PrefKey} . '-RowTotal' } ) {
            $LayoutObject->Block(
                Name => 'FootColumn',
                Data => {},
            );
        }
    }

    # check for refresh time
    my $Refresh = '';
    if ( $Self->{UserRefreshTime} ) {
        $Refresh = 60 * $Self->{UserRefreshTime};
        my $NameHTML = $Self->{Name};
        $NameHTML =~ s{-}{_}xmsg;
        $LayoutObject->Block(
            Name => 'ContentLargeTicketQueueOverviewRefresh',
            Data => {
                %{ $Self->{Config} },
                Name        => $Self->{Name},
                NameHTML    => $NameHTML,
                RefreshTime => $Refresh,
            },
        );
    }

    $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardTicketQueueOverview',
        Data         => {
            %{ $Self->{Config} },
            Name    => $Self->{Name},
            TableID => $Self->{Name},
            ColumnLabel =>
                $Self->{SearchAttributes}->{
                $LayoutObject->{ $Self->{PrefKey} . '-Row' }
                },
        },
        KeepScriptTags => $Param{AJAX},
    );

    # cache result
    if ( $Self->{Config}->{CacheTTLLocal} ) {
        $CacheObject->Set(
            Type  => 'DashboardQueueOverview',
            Key   => $CacheKey,
            Value => $Content || '',
            TTL   => 2 * 60,
        );
    }

    return $Content;
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
