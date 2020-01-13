# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketQueue;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # set debug
    $Self->{Debug} = 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # get config of AgentTicketSearch for fulltext search
    my $AgentTicketSearchConfig = $ConfigObject->Get("Ticket::Frontend::AgentTicketSearch");

    my $LayoutObject              = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UserObject                = $Kernel::OM->Get('Kernel::System::User');
    my $LockObject                = $Kernel::OM->Get('Kernel::System::Lock');
    my $StateObject               = $Kernel::OM->Get('Kernel::System::State');
    my $SearchProfileObject       = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    $Self->{SearchProfileQueue} = $LayoutObject->{LanguageObject}->Get( $ConfigObject->Get('Ticket::SearchProfileQueue') ) || '???';

    my %UserPreferences      = $UserObject->GetPreferences( UserID => $Self->{UserID} );
    $Self->{UserPreferences} = \%UserPreferences;

    if ( !defined( $Self->{UserPreferences}->{UserQueueViewLayout} ) ) {
        $Self->{UserPreferences}->{UserQueueViewLayout} = 'Tree';
    }
    elsif ( $Self->{UserPreferences}->{UserQueueViewLayout} eq 'Default' ) {
        $Self->{UserPreferences}->{UserQueueViewLayout} = '';
    }

    # get permissions
    $Self->{SearchPermission} = 'rw';
    if ( $Config->{ViewAllPossibleTickets} ) {
        $Self->{SearchPermission} = 'ro';
    }

    my $SortBy;
    if ( $ParamObject->GetParam( Param => 'SortBy' ) ) {
        $SortBy = $ParamObject->GetParam( Param => 'SortBy' );
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserQueueSortBy',
            Value  => $SortBy,
        );
    }

    # Determine the default ordering to be used. Observe the QueueSort setting.
    my $DefaultOrderBy = $Config->{'Order::Default'}
        || 'Up';
    if ( $Config->{QueueSort} ) {
        if ( defined $Config->{QueueSort}->{ $Self->{QueueID} } ) {
            if ( $Config->{QueueSort}->{ $Self->{QueueID} } ) {
                $DefaultOrderBy = 'Down';
            }
            else {
                $DefaultOrderBy = 'Up';
            }
        }
    }

    # Set the sort order from the request parameters, or take the default.
    my $OrderBy;
    if ( $ParamObject->GetParam( Param => 'OrderBy' ) ) {
        $OrderBy = $ParamObject->GetParam( Param => 'OrderBy' );
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserQueueOrderBy',
            Value  => $OrderBy,
        );
    }

    # if no OrderBy or SortBy get user preferences
    if ( !$SortBy ) {
        $SortBy = $Self->{UserPreferences}->{UserQueueSortBy}
            || $Config->{'SortBy::Default'}
            || 'Age';
    }

    if ( !$OrderBy ) {
        $OrderBy = $Self->{UserPreferences}->{UserQueueOrderBy}
            || $Config->{'OrderBy::Default'}
            || 'Up';
    }

    # get session object
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

    # create URL to store last screen
    my $URL = "Action=AgentTicketQueue;"
        . ";QueueID="       . $LayoutObject->LinkEncode( $Self->{QueueID} )
        . ";View="          . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'View')        || '' )
        . ";Filter="        . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'Filter')      || '' )
        . ";SortBy="        . $LayoutObject->LinkEncode( $SortBy )
        . ";OrderBy="       . $LayoutObject->LinkEncode( $OrderBy )
        . ";StartHit="      . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'StartHit')    || '')
        . ";StartWindow="   . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'StartWindow') || 0);

    # store last queue screen
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenOverview',
        Value     => $URL,
    );

    # store last screen
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $URL,
    );

    # get filters stored in the user preferences
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );
    my $StoredFiltersKey = 'UserStoredFilterColumns-' . $Self->{Action};
    my $JSONObject       = $Kernel::OM->Get('Kernel::System::JSON');
    my $StoredFilters    = $JSONObject->Decode(
        Data => $Preferences{$StoredFiltersKey},
    );

    # delete stored filters if needed
    if ( $ParamObject->GetParam( Param => 'DeleteFilters' ) ) {
        $StoredFilters = {};
    }

    # get the column filters from the web request or user preferences
    my %ColumnFilter;
    my %GetColumnFilter;
    COLUMNNAME:
    for my $ColumnName (
        qw(Owner Responsible State Queue Priority Type Lock Service SLA CustomerID CustomerUserID)
    ) {
        # get column filter from web request
        my $FilterValue = $ParamObject->GetParam( Param => 'ColumnFilter' . $ColumnName )
            || '';

        # if filter is not present in the web request, try with the user preferences
        if ( $FilterValue eq '' ) {
            if ( $ColumnName eq 'CustomerID' ) {
                $FilterValue = $StoredFilters->{$ColumnName}->[0] || '';
            }
            elsif ( $ColumnName eq 'CustomerUserID' ) {
                $FilterValue = $StoredFilters->{CustomerUserLogin}->[0] || '';
            }
            else {
                $FilterValue = $StoredFilters->{ $ColumnName . 'IDs' }->[0] || '';
            }
        }
        next COLUMNNAME if $FilterValue eq '';
        next COLUMNNAME if $FilterValue eq 'DeleteFilter';

        if ( $ColumnName eq 'CustomerID' ) {
            push @{ $ColumnFilter{$ColumnName} }, $FilterValue;
            push @{ $ColumnFilter{ $ColumnName . 'Raw' } }, $FilterValue;
            $GetColumnFilter{$ColumnName} = $FilterValue;
        }
        elsif ( $ColumnName eq 'CustomerUserID' ) {
            push @{ $ColumnFilter{CustomerUserLogin} },    $FilterValue;
            push @{ $ColumnFilter{CustomerUserLoginRaw} }, $FilterValue;
            $GetColumnFilter{$ColumnName} = $FilterValue;
        }
        else {
            push @{ $ColumnFilter{ $ColumnName . 'IDs' } }, $FilterValue;
            $GetColumnFilter{$ColumnName} = $FilterValue;
        }
    }

    # get all dynamic fields
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    );

    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
        next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

        # get filter from web request
        my $FilterValue = $ParamObject->GetParam(
            Param => 'ColumnFilterDynamicField_' . $DynamicFieldConfig->{Name}
        );

        # if no filter from web request, try from user preferences
        if ( !defined $FilterValue || $FilterValue eq '' ) {
            $FilterValue = $StoredFilters->{ 'DynamicField_' . $DynamicFieldConfig->{Name} }->{Equals};
        }

        next DYNAMICFIELD if !defined $FilterValue;
        next DYNAMICFIELD if $FilterValue eq '';
        next DYNAMICFIELD if $FilterValue eq 'DeleteFilter';

        $ColumnFilter{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = {
            Equals => $FilterValue,
        };
        $GetColumnFilter{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $FilterValue;
    }

    # build NavigationBar & to get the output faster!
    my $Refresh = '';
    if ( $Self->{UserRefreshTime} ) {
        $Refresh = 60 * $Self->{UserRefreshTime};
    }

    my $Output;
    if ( $Self->{Subaction} ne 'AJAXFilterUpdate' ) {
        $Output = $LayoutObject->Header(
            Refresh => $Refresh,
        );
        $Output .= $LayoutObject->NavigationBar();
    }

    # viewable locks
    my @ViewableLockIDs = $Kernel::OM->Get('Kernel::System::Lock')->LockViewableLock( Type => 'ID' );

    # viewable states
    my @ViewableStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'ID',
    );

    # get permissions
    my $Permission = $Self->{SearchPermission};

    # sort on default by using both (Priority, Age) else use only one sort argument
    my %Sort;

    # get if search result should be pre-sorted by priority
    my $PreSortByPriority = $Config->{'PreSort::ByPriority'};
    if ( !$PreSortByPriority ) {
        %Sort = (
            SortBy  => $SortBy,
            OrderBy => $OrderBy,
        );
    }
    else {
        %Sort = (
            SortBy  => [ 'Priority', $SortBy ],
            OrderBy => [ 'Down',     $OrderBy ],
        );
    }

    # get custom queues
    my @ViewableQueueIDs;
    if ( !$Self->{QueueID} ) {
        @ViewableQueueIDs = $Kernel::OM->Get('Kernel::System::Queue')->GetAllCustomQueues(
            UserID => $Self->{UserID},
        );
    }

    elsif ( $Self->{QueueID} =~ m/^SearchProfile_(.*)/ ) {
        $Self->{ViewSearchProfile} = $1;

        my %Profiles = $SearchProfileObject->SearchProfileList(
            Base             => 'TicketSearch',
            UserLogin        => $Self->{UserLogin},
            WithSubscription => 1
        );

        delete $Profiles{'last-search'};
        for my $Profile ( keys %Profiles ) {
            my $Encrypted = Digest::MD5::md5_hex($Profile);
            next if $Encrypted ne $Self->{ViewSearchProfile};
            $Self->{ViewSearchProfile} = $Profile;
            last;
        }
    }
    elsif (
        $Config->{IndividualViewParameterAND} &&
        ref( $Config->{IndividualViewParameterAND} ) eq 'HASH' &&
        $Config->{IndividualViewParameterAND}->{ $Self->{QueueID} }
    ) {
        $Self->{IndividualViewAND} = $Config->{IndividualViewParameterAND};
    }
    elsif (
        $Config->{IndividualViewParameterOR} &&
        ref( $Config->{IndividualViewParameterOR} ) eq 'HASH' &&
        $Config->{IndividualViewParameterOR}->{ $Self->{QueueID} }
    ) {
        $Self->{IndividualViewOR} = $Config->{IndividualViewParameterOR};
    }

    else {
        @ViewableQueueIDs = ( $Self->{QueueID} );
    }

    # get subqueue display setting
    my $UseSubQueues = $ParamObject->GetParam( Param => 'UseSubQueues' ) // $Config->{UseSubQueues} || 0;

    my %Filters = (
        All => {
            Name   => Translatable('All tickets'),
            Prio   => 1000,
            Search => {
                StateIDs => \@ViewableStateIDs,
                QueueIDs => \@ViewableQueueIDs,
                %Sort,
                Permission   => $Permission,
                UserID       => $Self->{UserID},
                UseSubQueues => $UseSubQueues,
            },
        },
        Unlocked => {
            Name   => Translatable('Available tickets'),
            Prio   => 1001,
            Search => {
                LockIDs  => \@ViewableLockIDs,
                StateIDs => \@ViewableStateIDs,
                QueueIDs => \@ViewableQueueIDs,
                %Sort,
                Permission   => $Permission,
                UserID       => $Self->{UserID},
                UseSubQueues => $UseSubQueues,
            },
        },
    );

    my $Filter = $ParamObject->GetParam( Param => 'Filter' )
        || $Self->{UserPreferences}->{UserViewAllTickets}
        || 'Unlocked';

    # check if filter is valid
    if ( !$Filters{$Filter} ) {
        $LayoutObject->FatalError(
            Message => $LayoutObject->{LanguageObject}->Translate( 'Invalid Filter: %s!', $Filter ),
        );
    }

    my $View = $ParamObject->GetParam( Param => 'View' ) || '';

    # lookup latest used view mode
    if ( !$View && $Self->{ 'UserTicketOverview' . $Self->{Action} } ) {
        $View = $Self->{ 'UserTicketOverview' . $Self->{Action} };
    }

    # otherwise use Preview as default as in LayoutTicket
    $View ||= 'Preview';

    # Check if selected view is available.
    my $Backends = $ConfigObject->Get('Ticket::Frontend::Overview');
    if ( !$Backends->{$View} ) {

        # Try to find fallback, take first configured view mode.
        KEY:
        for my $Key ( sort keys %{$Backends} ) {
            $View = $Key;
            last KEY;
        }
    }

    # get personal page shown count
    my $PageShownPreferencesKey = 'UserTicketOverview' . $View . 'PageShown';
    my $PageShown = $Self->{$PageShownPreferencesKey} || 10;

    # do shown tickets lookup
    my $Limit = 10_000;

    my $ElementChanged = $ParamObject->GetParam( Param => 'ElementChanged' ) || '';
    my $HeaderColumn = $ElementChanged;
    $HeaderColumn =~ s{\A ColumnFilter }{}msxg;

    # get data (viewable tickets...)
    # search all tickets
    my @ViewableTickets;
    my @OriginalViewableTickets;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if (@ViewableQueueIDs) {

        # get ticket values
        if (
            !IsStringWithData($HeaderColumn)
            || (
                IsStringWithData($HeaderColumn)
                && (
                    $ConfigObject->Get('OnlyValuesOnTicket') ||
                    $HeaderColumn eq 'CustomerID' ||
                    $HeaderColumn eq 'CustomerUserID'
                )
            )
        ) {
            @OriginalViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                %ColumnFilter,
                Limit  => $Limit,
                Result => 'ARRAY',
            );

            my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

            @ViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                %ColumnFilter,
                Limit  => $Start + $PageShown - 1,
                Result => 'ARRAY',
            );
        }
    }

    # search tickets based on individual queue view options
    elsif ( $Self->{ViewSearchProfile} ) {

        my %Search;
        my $SearchProfile;
        my $SearchProfileUser;
        my $ViewSearchProfilePlain = '';

        my %Profiles = $SearchProfileObject->SearchProfileList(
            Base             => 'TicketSearch',
            UserLogin        => $Self->{UserLogin},
            WithSubscription => 1
        );

        delete $Profiles{'last-search'};
        for my $Profile ( keys %Profiles ) {
            my $Encrypted = Digest::MD5::md5_hex( $Profiles{$Profile} );
            next if $Encrypted ne $Self->{ViewSearchProfile};
            $ViewSearchProfilePlain = $Profile;
            last;
        }

        if ( $ViewSearchProfilePlain =~ m/^(.*?)::(.*?)$/ ) {
            $SearchProfileUser = $2;
            $SearchProfile     = $1;
        }

        %Search = $SearchProfileObject->SearchProfileGet(
            Base      => 'TicketSearch',
            Name      => $SearchProfile,
            UserLogin => $SearchProfileUser || $Self->{UserLogin},
        );

        my %TimeMap = (
            ArticleCreate    => 'ArticleTime',
            TicketCreate     => 'Time',
            TicketChange     => 'ChangeTime',
            TicketLastChange => 'LastChangeTime',
            TicketClose      => 'CloseTime',
            TicketEscalation => 'EscalationTime',
            TicketPending    => 'PendingTime',
        );

        for my $TimeType ( sort keys %TimeMap ) {

            # get create time settings
            if ( !$Search{ $TimeMap{$TimeType} . 'SearchType' } ) {

                # do nothing with time stuff
            }
            elsif ( $Search{ $TimeMap{$TimeType} . 'SearchType' } eq 'TimeSlot' ) {
                for my $Key (qw(Month Day)) {
                    $Search{ $TimeType . 'TimeStart' . $Key }
                        = sprintf( "%02d", $Search{ $TimeType . 'TimeStart' . $Key } );
                    $Search{ $TimeType . 'TimeStop' . $Key }
                        = sprintf( "%02d", $Search{ $TimeType . 'TimeStop' . $Key } );
                }
                if (
                    $Search{ $TimeType . 'TimeStartDay' }
                    && $Search{ $TimeType . 'TimeStartMonth' }
                    && $Search{ $TimeType . 'TimeStartYear' }
                ) {
                    $Search{ $TimeType . 'TimeNewerDate' } = $Search{ $TimeType . 'TimeStartYear' } . '-'
                        . $Search{ $TimeType . 'TimeStartMonth' } . '-'
                        . $Search{ $TimeType . 'TimeStartDay' }
                        . ' 00:00:00';
                }
                if (
                    $Search{ $TimeType . 'TimeStopDay' }
                    && $Search{ $TimeType . 'TimeStopMonth' }
                    && $Search{ $TimeType . 'TimeStopYear' }
                ) {
                    $Search{ $TimeType . 'TimeOlderDate' } = $Search{ $TimeType . 'TimeStopYear' } . '-'
                        . $Search{ $TimeType . 'TimeStopMonth' } . '-'
                        . $Search{ $TimeType . 'TimeStopDay' }
                        . ' 23:59:59';
                }
            }
            elsif ( $Search{ $TimeMap{$TimeType} . 'SearchType' } eq 'TimePoint' ) {
                if (
                    $Search{ $TimeType . 'TimePoint' }
                    && $Search{ $TimeType . 'TimePointStart' }
                    && $Search{ $TimeType . 'TimePointFormat' }
                ) {
                    my $Time = 0;
                    if ( $Search{ $TimeType . 'TimePointFormat' } eq 'minute' ) {
                        $Time = $Search{ $TimeType . 'TimePoint' };
                    }
                    elsif ( $Search{ $TimeType . 'TimePointFormat' } eq 'hour' ) {
                        $Time = $Search{ $TimeType . 'TimePoint' } * 60;
                    }
                    elsif ( $Search{ $TimeType . 'TimePointFormat' } eq 'day' ) {
                        $Time = $Search{ $TimeType . 'TimePoint' } * 60 * 24;
                    }
                    elsif ( $Search{ $TimeType . 'TimePointFormat' } eq 'week' ) {
                        $Time = $Search{ $TimeType . 'TimePoint' } * 60 * 24 * 7;
                    }
                    elsif ( $Search{ $TimeType . 'TimePointFormat' } eq 'month' ) {
                        $Time = $Search{ $TimeType . 'TimePoint' } * 60 * 24 * 30;
                    }
                    elsif ( $Search{ $TimeType . 'TimePointFormat' } eq 'year' ) {
                        $Time = $Search{ $TimeType . 'TimePoint' } * 60 * 24 * 365;
                    }
                    if ( $Search{ $TimeType . 'TimePointStart' } eq 'Before' ) {

                        # more than ... ago
                        $Search{ $TimeType . 'TimeOlderMinutes' } = $Time;
                    }
                    elsif ( $Search{ $TimeType . 'TimePointStart' } eq 'Next' ) {

                        # within next
                        $Search{ $TimeType . 'TimeNewerMinutes' } = 0;
                        $Search{ $TimeType . 'TimeOlderMinutes' } = -$Time;
                    }
                    else {

                        # within last ...
                        $Search{ $TimeType . 'TimeOlderMinutes' } = 0;
                        $Search{ $TimeType . 'TimeNewerMinutes' } = $Time;
                    }
                }
            }
        }

        # dynamic fields search parameters for ticket search
        my %DynamicFieldSearchParameters;
        my $DynamicFields = $DynamicFieldObject->DynamicFieldListGet(
            Valid => 1,
            ObjectType => [ 'Ticket', 'Article' ],
        );

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$DynamicFields} ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # get search field preferences
            my $SearchFieldPreferences = $DynamicFieldBackendObject->SearchFieldPreferences(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            next DYNAMICFIELD if !IsArrayRefWithData($SearchFieldPreferences);

            PREFERENCE:
            for my $Preference ( @{$SearchFieldPreferences} ) {

                # extract the dynamic field value from the profile
                my $SearchParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Profile            => \%Search,
                    LayoutObject       => $LayoutObject,
                    Type               => $Preference->{Type},
                );

                # set search parameter
                if ( defined $SearchParameter ) {
                    $DynamicFieldSearchParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
                        = $SearchParameter->{Parameter};
                }
            }
        }

        my %SearchExtended = (
            ContentSearchPrefix => '*',
            ContentSearchSuffix => '*',
        );

        %Search = ( %Search, %SearchExtended, %DynamicFieldSearchParameters );

        # check archive flags
        $Search{ArchiveFlags} = ['n'];
        if ( defined $Search{SearchInArchive} && $Search{SearchInArchive} eq 'AllTickets' ) {
            $Search{ArchiveFlags} = [ 'y', 'n' ];
        }
        elsif ( defined $Search{SearchInArchive} && $Search{SearchInArchive} eq 'ArchivedTickets' ) {
            $Search{ArchiveFlags} = ['y'];
        }

        %Filters = (
            All => {
                Name   => 'All tickets',
                Prio   => 1000,
                Search => {

                    # StateIDs => \@ViewableStateIDs,
                    %Search,
                    %Sort,
                    FullTextIndex   => 1,
                    ConditionInline => 1,
                    UserID          => $Self->{UserID},
                },
            },
            Unlocked => {
                Name   => 'Available tickets',
                Prio   => 1001,
                Search => {
                    LockIDs => \@ViewableLockIDs,

                    # StateIDs => \@ViewableStateIDs,
                    %Search,
                    %Sort,
                    FullTextIndex   => 1,
                    ConditionInline => 1,
                    UserID          => $Self->{UserID},
                },
            },
        );

        if ( $Filters{ $Filter }->{Search}->{Fulltext} ) {
            $Filters{All}->{Search}->{ContentSearch}      = 'OR';
            $Filters{Unlocked}->{Search}->{ContentSearch} = 'OR';

            for (qw(From To Cc Subject Body)) {
                $Filters{All}->{Search}->{$_} =
                    $Filters{ $Filter }->{Search}->{Fulltext};
                $Filters{Unlocked}->{Search}->{$_} =
                    $Filters{ $Filter }->{Search}->{Fulltext};
            }
        }

        @OriginalViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Filter }->{Search} },
            Limit  => $Limit,
            Result => 'ARRAY',
        );

        if ( $Filters{ $Filter }->{Search}->{Fulltext} ) {
            # search tickets with TicketNumber
            # (we have to do this here, because TicketSearch concatenates TN and Title with AND condition)
            # clear additional parameters
            for (qw(From To Cc Subject Body)) {
                delete $Filters{ $Filter }->{Search}->{$_};
            }

            my $TicketHook          = $ConfigObject->Get('Ticket::Hook');
            my $FulltextSearchParam = $Filters{ $Filter }->{Search}->{Fulltext};
            $FulltextSearchParam =~ s/$TicketHook//g;
            $Filters{ $Filter }->{Search}->{TicketNumber} = '*' . $FulltextSearchParam . '*';

            my @OriginalViewableTicketIDsTN = $TicketObject->TicketSearch(
                %{ $Filters{ $Filter }->{Search} },
                %ColumnFilter,
                Limit  => $Limit,
                Result => 'ARRAY',
            );

            delete $Filters{ $Filter }->{Search}->{TicketNumber};

            # search tickets with Title
            $Filters{ $Filter }->{Search}->{Title} = $Filters{ $Filter }->{Search}->{Fulltext};

            my @OriginalViewableTicketIDsTitle = $TicketObject->TicketSearch(
                %{ $Filters{ $Filter }->{Search} },
                %ColumnFilter,
                Limit  => $Limit,
                Result => 'ARRAY',
            );

            delete $Filters{ $Filter }->{Search}->{Title};

            # search tickets with remarks (TicketNotes)
            $Filters{ $Filter }->{Search}->{TicketNotes} = $Filters{ $Filter }->{Search}->{Fulltext};

            my @OriginalViewableTicketIDsTicketNotes = $TicketObject->TicketSearch(
                %{ $Filters{ $Filter }->{Search} },
                %ColumnFilter,
                Limit  => $Limit,
                Result => 'ARRAY',
            );

            delete $Filters{ $Filter }->{Search}->{TicketNotes};

            # search ticket with DF if configured
            my @OriginalViewableTicketIDsDF = ();
            if ( $AgentTicketSearchConfig->{FulltextSearchInDynamicFields} ) {

                # prepare fulltext serach in DFs
                DYNAMICFIELDFULLTEXT:
                for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                    next DYNAMICFIELDFULLTEXT
                        if !(
                            $AgentTicketSearchConfig->{FulltextSearchInDynamicFields}->{ $DynamicFieldConfig->{Name} }
                        );
                    next DYNAMICFIELDFULLTEXT if !IsHashRefWithData($DynamicFieldConfig);

                    my %DFSearchParameters;

                    # get search field preferences
                    my $SearchFieldPreferences = $DynamicFieldBackendObject->SearchFieldPreferences(
                        DynamicFieldConfig => $DynamicFieldConfig,
                    );

                    next DYNAMICFIELDFULLTEXT if !IsArrayRefWithData($SearchFieldPreferences);

                    PREFERENCEFULLTEXT:
                    for my $Preference ( @{$SearchFieldPreferences} ) {

                        # extract the dynamic field value from the profile
                        my $SearchParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                            DynamicFieldConfig => $DynamicFieldConfig,
                            Profile            => {
                                "Search_DynamicField_$DynamicFieldConfig->{Name}" => '*'
                                    . $Filters{ $Filter }->{Search}->{Fulltext} . '*',
                            },
                            LayoutObject => $LayoutObject,
                            Type         => $Preference->{Type},
                        );

                        # set search parameter
                        if ( defined $SearchParameter ) {
                            $DFSearchParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $SearchParameter->{Parameter};
                        }
                    }

                    # search all tickets
                    my @OriginalViewableTicketIDsThisDF = $TicketObject->TicketSearch(
                        %Sort,
                        Result          => 'ARRAY',
                        Limit           => $Limit,
                        UserID          => $Self->{UserID},
                        ConditionInline => $AgentTicketSearchConfig->{ExtendedSearchCondition},
                        ArchiveFlags    => $Filters{ $Filter }->{Search}->{ArchiveFlags},
                        %DFSearchParameters,
                    );

                    if (@OriginalViewableTicketIDsThisDF) {

                        # join arrays
                        @OriginalViewableTicketIDsDF = (
                            @OriginalViewableTicketIDsDF,
                            @OriginalViewableTicketIDsThisDF,
                        );
                    }
                }
            }

            # merge original arrays
            my @OriginalMergeArray;
            push(
                @OriginalMergeArray,
                @OriginalViewableTickets,
                @OriginalViewableTicketIDsTitle,
                @OriginalViewableTicketIDsTicketNotes,
                @OriginalViewableTicketIDsTN,
                @OriginalViewableTicketIDsDF
            );

            if ( scalar(@OriginalMergeArray) > 1 ) {
                # sort original merged tickets
                @OriginalViewableTickets = $TicketObject->TicketSearch(
                    %Sort,
                    Result       => 'ARRAY',
                    UserID       => $Self->{UserID},
                    TicketID     => \@OriginalMergeArray,
                    ArchiveFlags => $Filters{ $Filter }->{Search}->{ArchiveFlags},
                    Limit        => $Limit,
                );
            }
            else {
                @OriginalViewableTickets = @OriginalMergeArray;
            }
        }

        if ( scalar(@OriginalViewableTickets) > 1 ) {
            my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

            # get page tickets
            @ViewableTickets = $TicketObject->TicketSearch(
                %Sort,
                Result       => 'ARRAY',
                UserID       => $Self->{UserID},
                TicketID     => \@OriginalViewableTickets,
                ArchiveFlags => $Filters{ $Filter }->{Search}->{ArchiveFlags},
                Limit        => $Start + 50,
            );
        }
        else {
            @ViewableTickets = @OriginalViewableTickets;
        }

        push( @ViewableQueueIDs, 0 );

    }
    elsif ( $Self->{IndividualViewAND} ) {

        my %Search;
        my $TmpSelQueueID = $Self->{QueueID};
        my @SearchParameters = split( '\|\|\|', $Self->{IndividualViewAND}->{$TmpSelQueueID} );
        for my $CurrSearch (@SearchParameters) {
            my @CurrSearchParamater = split( ':::', $CurrSearch );
            next if ( scalar(@CurrSearchParamater) != 2 );

            my $Key = $CurrSearchParamater[0];
            my @Values = split( ';', $CurrSearchParamater[1] );

            for my $Value (@Values) {
                if ( $Value eq '_ME_' ) {
                    $Value = $Self->{UserID};
                }
                elsif ( $Value eq '_ANY_' ) {
                    $Value = '*';
                }
                elsif ( $Value eq '_NONE_' ) {

                    # no change, further processing in TicketSearch
                }
                elsif ( $Value =~ /_ME_PREF_.+/ ) {
                    $Value =~ s/.*_ME_PREF_//;
                    $Value = $Self->{UserPreferences}->{$Value} || '';
                }
            }
            $Search{$Key} = \@Values;
        }

        # other search permissions for this view?
        if (
            $Config->{IndividualViewPermission}
            && $Config->{IndividualViewPermission}->{$TmpSelQueueID}
        ) {
            $Permission = $Config->{IndividualViewPermission}->{$TmpSelQueueID};
        }

        # "unlocked" shows all tickets; "all" observes lock state
        # this names are used due to KIX compatibility
        %Filters = (
            All => {
                Name   => 'All tickets',
                Prio   => 1000,
                Search => {
                    StateIDs => \@ViewableStateIDs,
                    %Search,
                    %Sort,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                },
            },
            Unlocked => {
                Name   => 'Available tickets',
                Prio   => 1001,
                Search => {
                    LockIDs  => \@ViewableLockIDs,
                    StateIDs => \@ViewableStateIDs,
                    %Search,
                    %Sort,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                },
            },
        );

        @OriginalViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Filter }->{Search} },
            %ColumnFilter,
            Limit  => $Limit,
            Result => 'ARRAY',
        );

        my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

        @ViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Filter }->{Search} },
            %ColumnFilter,
            Limit  => $Start + 50,
            Result => 'ARRAY',
        );

        push( @ViewableQueueIDs, 0);
    }
    elsif ( $Self->{IndividualViewOR} ) {
        my %Search;
        my $TmpSelQueueID = $Self->{QueueID};
        my @SearchParameters = split( '\|\|\|', $Self->{IndividualViewOR}->{$TmpSelQueueID} );
        for my $CurrSearch (@SearchParameters) {
            my @CurrSearchParamater = split( ':::', $CurrSearch );
            next if ( scalar(@CurrSearchParamater) != 2 );

            my $Key = $CurrSearchParamater[0];
            my @Values = split( ';', $CurrSearchParamater[1] );

            for my $Value (@Values) {
                if ( $Value eq '_ME_' ) {
                    $Value = $Self->{UserID};
                }
                elsif ( $Value eq '_ANY_' ) {
                    $Value = '*';
                }
                elsif ( $Value eq '_NONE_' ) {

                    # no change, further processing in TicketSearch
                }
                elsif ( $Value =~ /_ME_PREF_.+/ ) {
                    $Value =~ s/.*_ME_PREF_//;
                    $Value = $Self->{UserPreferences}->{$Value} || '';
                }
            }
            $Search{$Key} = \@Values;
        }

        # other search permissions for this view?
        if (
            $Config->{IndividualViewPermission}
            && $Config->{IndividualViewPermission}->{$TmpSelQueueID}
        ) {
            $Permission = $Config->{IndividualViewPermission}->{$TmpSelQueueID};
        }

        # "unlocked" shows all tickets; "all" observes lock state
        # this names are used due to KIX compatibility
        %Filters = (
            All => {
                Name     => 'All tickets',
                Prio     => 1000,
                SearchOR => {
                    StateIDs => \@ViewableStateIDs,
                    %Search,
                    %Sort,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                },
            },
            Unlocked => {
                Name     => 'Available tickets',
                Prio     => 1001,
                SearchOR => {
                    LockIDs  => \@ViewableLockIDs,
                    StateIDs => \@ViewableStateIDs,
                    %Search,
                    %Sort,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                },
            },
        );

        @OriginalViewableTickets = $TicketObject->TicketSearchOR(
             %{ $Filters{ $Filter }->{SearchOR} },
            Limit  => $Limit,
            Result => 'ARRAY',
        );

        my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

        @ViewableTickets = $TicketObject->TicketSearchOR(
            %{ $Filters{ $Filter }->{SearchOR} },
            Limit  => $Start + 50,
            Result => 'ARRAY',
        );

        push( @ViewableQueueIDs, 0 );
    }

    if ( $Self->{Subaction} eq 'AJAXFilterUpdate' ) {

        my $FilterContent = $LayoutObject->TicketListShow(
            FilterContentOnly   => 1,
            HeaderColumn        => $HeaderColumn,
            ElementChanged      => $ElementChanged,
            OriginalTicketIDs   => \@OriginalViewableTickets,
            Action              => 'AgentTicketQueue',
            Env                 => $Self,
            View                => $View,
            EnableColumnFilters => 1,
        );

        if ( !$FilterContent ) {
            $LayoutObject->FatalError(
                Message => $LayoutObject->{LanguageObject}
                    ->Translate( 'Can\'t get filter content data of %s!', $HeaderColumn ),
            );
        }

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $FilterContent,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    else {

        # store column filters
        my $NewStoredFilters = \%ColumnFilter;

        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $StoredFiltersKey,
            Value  => $JSONObject->Encode( Data => $NewStoredFilters ),
        );
    }

    my $CountTotal = 0;
    my %NavBarFilter;
    for my $FilterColumn ( sort keys %Filters ) {
        my $Count = 0;
        if (@ViewableQueueIDs) {

            if ( $Filters{ $FilterColumn }->{SearchOR} ) {
                $Count = $TicketObject->TicketSearchOR(
                    %{ $Filters{$FilterColumn}->{SearchOR} },
                    %ColumnFilter,
                    Result => 'COUNT',
                );
            }
            else {

                if ( $Filters{ $FilterColumn }->{Search}->{Fulltext} ) {
                    $Filters{All}->{Search}->{ContentSearch}      = 'OR';
                    $Filters{Unlocked}->{Search}->{ContentSearch} = 'OR';

                    for (qw(From To Cc Subject Body)) {
                        $Filters{All}->{Search}->{$_} =
                            $Filters{ $FilterColumn }->{Search}->{Fulltext};
                        $Filters{Unlocked}->{Search}->{$_} =
                            $Filters{ $FilterColumn }->{Search}->{Fulltext};
                    }

                    my @CountTickets = $TicketObject->TicketSearch(
                        %{ $Filters{ $FilterColumn }->{Search} },
                        %ColumnFilter,
                        Result => 'ARRAY',
                    );
                    my @CountTicketIDsDF = ();

                    # search tickets with TicketNumber
                    # (we have to do this here, because TicketSearch concatenates TN and Title with AND condition)
                    # clear additional parameters
                    for (qw(From To Cc Subject Body)) {
                        delete $Filters{ $FilterColumn }->{Search}->{$_};
                    }

                    my $TicketHook          = $ConfigObject->Get('Ticket::Hook');
                    my $FulltextSearchParam = $Filters{ $FilterColumn }->{Search}->{Fulltext};
                    $FulltextSearchParam =~ s/$TicketHook//g;
                    $Filters{ $FilterColumn }->{Search}->{TicketNumber} = '*' . $FulltextSearchParam . '*';

                    my @CountTicketIDsTN = $TicketObject->TicketSearch(
                        %{ $Filters{ $FilterColumn }->{Search} },
                        %ColumnFilter,
                        Result => 'ARRAY',
                    );

                    # search tickets with Title
                    delete $Filters{ $FilterColumn }->{Search}->{TicketNumber};
                    $Filters{ $FilterColumn }->{Search}->{Title} = $Filters{ $FilterColumn }->{Search}->{Fulltext};
                    my @CountTicketIDsTitle = $TicketObject->TicketSearch(
                        %{ $Filters{ $FilterColumn }->{Search} },
                        %ColumnFilter,
                        Result => 'ARRAY',
                    );

                    # search tickets with remarks (TicketNotes)
                    delete $Filters{ $FilterColumn }->{Search}->{Title};
                    $Filters{ $FilterColumn }->{Search}->{TicketNotes} = $Filters{ $FilterColumn }->{Search}->{Fulltext};
                    my @CountTicketIDsTicketNotes = $TicketObject->TicketSearch(
                        %{ $Filters{ $FilterColumn }->{Search} },
                        %ColumnFilter,
                        Result => 'ARRAY',
                    );
                    delete $Filters{ $FilterColumn }->{Search}->{TicketNotes};

                    # search ticket with DF if configured
                    if ( $AgentTicketSearchConfig->{FulltextSearchInDynamicFields} ) {

                        # prepare fulltext serach in DFs
                        DYNAMICFIELDFULLTEXT:
                        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                            next DYNAMICFIELDFULLTEXT
                                if !(
                                        $AgentTicketSearchConfig->{FulltextSearchInDynamicFields}
                                        ->{ $DynamicFieldConfig->{Name} }
                                );
                            next DYNAMICFIELDFULLTEXT if !IsHashRefWithData($DynamicFieldConfig);

                            my %DFSearchParameters;

                            # get search field preferences
                            my $SearchFieldPreferences = $DynamicFieldBackendObject->SearchFieldPreferences(
                                DynamicFieldConfig => $DynamicFieldConfig,
                            );

                            next DYNAMICFIELDFULLTEXT if !IsArrayRefWithData($SearchFieldPreferences);

                            PREFERENCEFULLTEXT:
                            for my $Preference ( @{$SearchFieldPreferences} ) {

                                # extract the dynamic field value from the profile
                                my $SearchParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                                    DynamicFieldConfig => $DynamicFieldConfig,
                                    Profile            => {
                                        "Search_DynamicField_$DynamicFieldConfig->{Name}" => '*'
                                            . $Filters{ $FilterColumn }->{Search}->{Fulltext} . '*',
                                    },
                                    LayoutObject => $LayoutObject,
                                    Type         => $Preference->{Type},
                                );

                                # set search parameter
                                if ( defined $SearchParameter ) {
                                    $DFSearchParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $SearchParameter->{Parameter};
                                }
                            }

                            # search tickets
                            my @CountTicketIDsThisDF = $TicketObject->TicketSearch(
                                %Sort,
                                Result          => 'ARRAY',
                                UserID          => $Self->{UserID},
                                ConditionInline => $AgentTicketSearchConfig->{ExtendedSearchCondition},
                                ArchiveFlags    => $Filters{ $FilterColumn }->{Search}->{ArchiveFlags},
                                %DFSearchParameters,
                            );

                            if (@CountTicketIDsThisDF) {

                                # join arrays
                                @CountTicketIDsDF = (
                                    @CountTicketIDsDF,
                                    @CountTicketIDsThisDF,
                                );
                            }
                        }
                    }

                    # merge arrays
                    my @MergeArray;
                    push(
                        @MergeArray,
                        @CountTickets,
                        @CountTicketIDsTitle,
                        @CountTicketIDsTicketNotes,
                        @CountTicketIDsTN,
                        @CountTicketIDsDF
                    );

                    if ( scalar(@MergeArray) > 1 ) {
                        # sort merged tickets
                        @CountTickets = $TicketObject->TicketSearch(
                            %Sort,
                            Result       => 'ARRAY',
                            UserID       => $Self->{UserID},
                            TicketID     => \@MergeArray,
                            ArchiveFlags => $Filters{ $FilterColumn }->{Search}->{ArchiveFlags},
                        );
                    }
                    else {
                        @CountTickets = @MergeArray;
                    }
                    $Count = scalar( @CountTickets ) || 0;
                }
                else {
                    $Count = $TicketObject->TicketSearch(
                        %{ $Filters{$FilterColumn}->{Search} },
                        %ColumnFilter,
                        Result => 'COUNT',
                    );
                }
            }
        }

        if ( $FilterColumn eq $Filter ) {
            $CountTotal = $Count;
        }

        $NavBarFilter{ $Filters{$FilterColumn}->{Prio} } = {
            Count  => $Count,
            Filter => $FilterColumn,
            %{ $Filters{$FilterColumn} },
        };
    }

    my $ColumnFilterLink = '';
    COLUMNNAME:
    for my $ColumnName ( sort keys %GetColumnFilter ) {
        next COLUMNNAME if !$ColumnName;
        next COLUMNNAME if !defined $GetColumnFilter{$ColumnName};
        next COLUMNNAME if $GetColumnFilter{$ColumnName} eq '';
        $ColumnFilterLink
            .= ';' . $LayoutObject->Ascii2Html( Text => 'ColumnFilter' . $ColumnName )
            . '=' . $LayoutObject->Ascii2Html( Text => $GetColumnFilter{$ColumnName} );
    }

    my $SubQueueLink = '';
    if ( !$Config->{UseSubQueues} && $UseSubQueues ) {
        $SubQueueLink = ';UseSubQueues=1';
    }
    elsif ( $Config->{UseSubQueues} && !$UseSubQueues ) {
        $SubQueueLink = ';UseSubQueues=0';
    }

    my $LinkPage = 'QueueID='
        . $LayoutObject->Ascii2Html( Text => $Self->{QueueID} )
        . ';Filter='
        . $LayoutObject->Ascii2Html( Text => $Filter )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
        . ';SortBy=' . $LayoutObject->Ascii2Html( Text => $SortBy )
        . ';OrderBy=' . $LayoutObject->Ascii2Html( Text => $OrderBy )
        . $SubQueueLink
        . $ColumnFilterLink
        . ';';

    my $LinkSort = 'QueueID='
        . $LayoutObject->Ascii2Html( Text => $Self->{QueueID} )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
        . ';Filter='
        . $LayoutObject->Ascii2Html( Text => $Filter )
        . $SubQueueLink
        . $ColumnFilterLink
        . ';';

    my $LinkFilter = 'QueueID='
        . $LayoutObject->Ascii2Html( Text => $Self->{QueueID} )
        . ';SortBy=' . $LayoutObject->Ascii2Html( Text => $SortBy )
        . ';OrderBy=' . $LayoutObject->Ascii2Html( Text => $OrderBy )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
        . $SubQueueLink
        . ';';

    my $LastColumnFilter = $ParamObject->GetParam( Param => 'LastColumnFilter' ) || '';

    if ( !$LastColumnFilter && $ColumnFilterLink ) {

        # is planned to have a link to go back here
        $LastColumnFilter = 1;
    }

    my %NavBar = $Self->BuildQueueView(
        QueueIDs         => \@ViewableQueueIDs,
        Filter           => $Filter,
        UseSubQueues     => $UseSubQueues,
        ViewableLockIDs  => \@ViewableLockIDs,
        ViewableStateIDs => \@ViewableStateIDs,
    );

    my $SubQueueIndicatorTitle = '';
    if ( !$Config->{UseSubQueues} && $UseSubQueues ) {
        $SubQueueIndicatorTitle = ' (' . $LayoutObject->{LanguageObject}->Translate('including subqueues') . ')';
    }
    elsif ( $Config->{UseSubQueues} && !$UseSubQueues ) {
        $SubQueueIndicatorTitle = ' (' . $LayoutObject->{LanguageObject}->Translate('excluding subqueues') . ')';
    }

    # show tickets
    my $TicketList = $LayoutObject->TicketListShow(
        Filter     => $Filter,
        Filters    => \%NavBarFilter,
        TicketIDs  => \@ViewableTickets,

        OriginalTicketIDs => \@OriginalViewableTickets,
        GetColumnFilter   => \%GetColumnFilter,
        LastColumnFilter  => $LastColumnFilter,
        Action            => 'AgentTicketQueue',
        Total             => $CountTotal,
        RequestedURL      => $Self->{RequestedURL},

        NavBar => \%NavBar,
        View   => $View,

        Bulk       => 1,
        TitleName  => Translatable('QueueView'),
        TitleValue => $NavBar{SelectedQueue} . $SubQueueIndicatorTitle,

        Env        => $Self,
        LinkPage   => $LinkPage,
        LinkSort   => $LinkSort,
        LinkFilter => $LinkFilter,

        OrderBy             => $OrderBy,
        SortBy              => $SortBy,
        EnableColumnFilters => 1,
        ColumnFilterForm    => {
            QueueID => $Self->{QueueID} || '',
            Filter  => $Filter          || '',
        },

        # do not print the result earlier, but return complete content
        Output             => 1,
        Output             => 1,
        DynamicFieldConfig => $Self->{DynamicField},
    );

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketQueue' . $Self->{UserPreferences}->{UserQueueViewLayout},
        Data => { %NavBar, TicketList => $TicketList }
    );

    # get page footer
    $Output .= $LayoutObject->Footer() if $Self->{Subaction} ne 'AJAXFilterUpdate';
    return $Output;
}

sub BuildQueueView {
    my ( $Self, %Param ) = @_;

    $Param{SelectedQueueID} = $Self->{QueueID};

    my $DBObject         = $Kernel::OM->Get('Kernel::System::DB');
    my @ViewableLockIDs  = @{ $Param{ViewableLockIDs} };
    my @ViewableStateIDs = @{ $Param{ViewableStateIDs} };

    if ( $Param{Filter} eq 'All' ) {
        $DBObject->Prepare( SQL => "SELECT id FROM ticket_lock_type" );
        while ( my @Data = $DBObject->FetchrowArray() ) {
            push( @ViewableLockIDs, $Data[0] );
        }
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %Data = $Kernel::OM->Get('Kernel::System::Ticket')->TicketAcceleratorIndex(
        UserID          => $Self->{UserID},
        QueueID         => $Self->{QueueID},
        ShownQueueIDs   => $Param{QueueIDs},
        Filter          => $Param{Filter},
        ViewableLockIDs => \@ViewableLockIDs,
    );

    my $ConfigObject            = $Kernel::OM->Get('Kernel::Config');
    my $Config                  = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");
    my $AgentTicketSearchConfig = $ConfigObject->Get("Ticket::Frontend::AgentTicketSearch");

    # build individual queue views (search profiles and virtual queues)
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my %Profiles            = $SearchProfileObject->SearchProfileList(
        Base             => 'TicketSearch',
        UserLogin        => $Self->{UserLogin},
        WithSubscription => 1,
    );
    delete $Profiles{'last-search'};

    if ( %Profiles && ref \%Profiles eq 'HASH' ) {
        for my $SearchProfile ( keys %Profiles ) {
            my %Hash;
            my $SearchProfileUser;
            my $SearchProfileName = $SearchProfile;
            if ( $SearchProfile =~ m/^(.*?)::(.*?)$/ ) {
                $SearchProfileUser = $2;
                $SearchProfile     = $1
            }

            # get search profile data
            my %SearchProfileData = $SearchProfileObject->SearchProfileGet(
                Base      => 'TicketSearch',
                Name      => $SearchProfile,
                UserLogin => $SearchProfileUser || $Self->{UserLogin},
            );

            my %TimeMap = (
                ArticleCreate    => 'ArticleTime',
                TicketCreate     => 'Time',
                TicketChange     => 'ChangeTime',
                TicketLastChange => 'LastChangeTime',
                TicketClose      => 'CloseTime',
                TicketEscalation => 'EscalationTime',
                TicketPending    => 'PendingTime',
            );

            for my $TimeType ( sort keys %TimeMap ) {

                # get create time settings
                if ( !$SearchProfileData{ $TimeMap{$TimeType} . 'SearchType' } ) {

                    # do nothing with time stuff
                }
                elsif ( $SearchProfileData{ $TimeMap{$TimeType} . 'SearchType' } eq 'TimeSlot' ) {
                    for my $Key (qw(Month Day)) {
                        $SearchProfileData{ $TimeType . 'TimeStart' . $Key }
                            = sprintf( "%02d", $SearchProfileData{ $TimeType . 'TimeStart' . $Key } );
                        $SearchProfileData{ $TimeType . 'TimeStop' . $Key }
                            = sprintf( "%02d", $SearchProfileData{ $TimeType . 'TimeStop' . $Key } );
                    }
                    if (
                        $SearchProfileData{ $TimeType . 'TimeStartDay' }
                        && $SearchProfileData{ $TimeType . 'TimeStartMonth' }
                        && $SearchProfileData{ $TimeType . 'TimeStartYear' }
                    ) {
                        $SearchProfileData{ $TimeType . 'TimeNewerDate' } = $SearchProfileData{ $TimeType . 'TimeStartYear' } . '-'
                            . $SearchProfileData{ $TimeType . 'TimeStartMonth' } . '-'
                            . $SearchProfileData{ $TimeType . 'TimeStartDay' }
                            . ' 00:00:00';
                    }
                    if (
                        $SearchProfileData{ $TimeType . 'TimeStopDay' }
                        && $SearchProfileData{ $TimeType . 'TimeStopMonth' }
                        && $SearchProfileData{ $TimeType . 'TimeStopYear' }
                    ) {
                        $SearchProfileData{ $TimeType . 'TimeOlderDate' } = $SearchProfileData{ $TimeType . 'TimeStopYear' } . '-'
                            . $SearchProfileData{ $TimeType . 'TimeStopMonth' } . '-'
                            . $SearchProfileData{ $TimeType . 'TimeStopDay' }
                            . ' 23:59:59';
                    }
                }
                elsif ( $SearchProfileData{ $TimeMap{$TimeType} . 'SearchType' } eq 'TimePoint' ) {
                    if (
                        $SearchProfileData{ $TimeType . 'TimePoint' }
                        && $SearchProfileData{ $TimeType . 'TimePointStart' }
                        && $SearchProfileData{ $TimeType . 'TimePointFormat' }
                    ) {
                        my $Time = 0;
                        if ( $SearchProfileData{ $TimeType . 'TimePointFormat' } eq 'minute' ) {
                            $Time = $SearchProfileData{ $TimeType . 'TimePoint' };
                        }
                        elsif ( $SearchProfileData{ $TimeType . 'TimePointFormat' } eq 'hour' ) {
                            $Time = $SearchProfileData{ $TimeType . 'TimePoint' } * 60;
                        }
                        elsif ( $SearchProfileData{ $TimeType . 'TimePointFormat' } eq 'day' ) {
                            $Time = $SearchProfileData{ $TimeType . 'TimePoint' } * 60 * 24;
                        }
                        elsif ( $SearchProfileData{ $TimeType . 'TimePointFormat' } eq 'week' ) {
                            $Time = $SearchProfileData{ $TimeType . 'TimePoint' } * 60 * 24 * 7;
                        }
                        elsif ( $SearchProfileData{ $TimeType . 'TimePointFormat' } eq 'month' ) {
                            $Time = $SearchProfileData{ $TimeType . 'TimePoint' } * 60 * 24 * 30;
                        }
                        elsif ( $SearchProfileData{ $TimeType . 'TimePointFormat' } eq 'year' ) {
                            $Time = $SearchProfileData{ $TimeType . 'TimePoint' } * 60 * 24 * 365;
                        }
                        if ( $SearchProfileData{ $TimeType . 'TimePointStart' } eq 'Before' ) {

                            # more than ... ago
                            $SearchProfileData{ $TimeType . 'TimeOlderMinutes' } = $Time;
                        }
                        elsif ( $SearchProfileData{ $TimeType . 'TimePointStart' } eq 'Next' ) {

                            # within next
                            $SearchProfileData{ $TimeType . 'TimeNewerMinutes' } = 0;
                            $SearchProfileData{ $TimeType . 'TimeOlderMinutes' } = -$Time;
                        }
                        else {

                            # within last ...
                            $SearchProfileData{ $TimeType . 'TimeOlderMinutes' } = 0;
                            $SearchProfileData{ $TimeType . 'TimeNewerMinutes' } = $Time;
                        }
                    }
                }
            }

            # dynamic fields search parameters for ticket search
            my %DynamicFieldSearchParameters;
            my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
            my $DynamicFieldBackendObject
                = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
            my $DynamicFields = $DynamicFieldObject->DynamicFieldListGet(
                Valid => 1,
                ObjectType => [ 'Ticket', 'Article' ],
            );

            # cycle trough the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{$DynamicFields} ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                # get search field preferences
                my $SearchFieldPreferences = $DynamicFieldBackendObject->SearchFieldPreferences(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                next DYNAMICFIELD if !IsArrayRefWithData($SearchFieldPreferences);

                PREFERENCE:
                for my $Preference ( @{$SearchFieldPreferences} ) {

                    # extract the dynamic field value from the profile
                    my $SearchParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Profile            => \%SearchProfileData,
                        LayoutObject       => $Self->{LayoutObject},
                        Type               => $Preference->{Type},
                    );

                    # set search parameter
                    if ( defined $SearchParameter ) {
                        $DynamicFieldSearchParameters{
                            'DynamicField_'
                                . $DynamicFieldConfig->{Name}
                            }
                            = $SearchParameter->{Parameter};
                    }
                }
            }

            my %SearchExtended = (
                ContentSearchPrefix => '*',
                ContentSearchSuffix => '*',
            );

            %SearchProfileData
                = ( %SearchProfileData, %SearchExtended, %DynamicFieldSearchParameters );

            # only show selected profiles
            next if !$SearchProfileData{ShowProfileAsQueue};

            # prepare fulltext search
            if ( $SearchProfileData{Fulltext} ) {
                $SearchProfileData{ContentSearch} = 'OR';
                for (qw(From To Cc Subject Body)) {
                    $SearchProfileData{$_} = $SearchProfileData{Fulltext};
                }
            }

            # check archive flags
            $SearchProfileData{ArchiveFlags} = ['n'];
            if (
                defined $SearchProfileData{SearchInArchive}
                && $SearchProfileData{SearchInArchive} eq 'AllTickets'
            ) {
                $SearchProfileData{ArchiveFlags} = [ 'y', 'n' ];
            }
            elsif (
                defined $SearchProfileData{SearchInArchive}
                && $SearchProfileData{SearchInArchive} eq 'ArchivedTickets'
            ) {
                $SearchProfileData{ArchiveFlags} = ['y'];
            }

            # get total ticket count
            my @ViewableTicketIDs = $TicketObject->TicketSearch(
                %SearchProfileData,
                UserID          => $Self->{UserID},
                ConditionInline => 1,
                FullTextIndex   => 1,
                Result          => 'ARRAY',
            );

            if ( $SearchProfileData{Fulltext} ) {
                my @ViewableTicketIDsDF = ();

                # search tickets with TicketNumber
                # (we have to do this here, because TicketSearch concatenates TN and Title with AND condition)
                # clear additional parameters
                for (qw(From To Cc Subject Body)) {
                    delete $SearchProfileData{$_};
                }

                my $TicketHook          = $ConfigObject->Get('Ticket::Hook');
                my $FulltextSearchParam = $SearchProfileData{Fulltext};
                $FulltextSearchParam =~ s/$TicketHook//g;
                $SearchProfileData{TicketNumber} = '*' . $FulltextSearchParam . '*';

                my @ViewableTicketIDsTN = $TicketObject->TicketSearch(
                    %SearchProfileData,
                    UserID          => $Self->{UserID},
                    ConditionInline => 1,
                    FullTextIndex   => 1,
                    Result          => 'ARRAY',
                );

                # search tickets with Title
                delete $SearchProfileData{TicketNumber};
                $SearchProfileData{Title} = $SearchProfileData{Fulltext};
                my @ViewableTicketIDsTitle = $TicketObject->TicketSearch(
                    %SearchProfileData,
                    UserID          => $Self->{UserID},
                    ConditionInline => 1,
                    FullTextIndex   => 1,
                    Result          => 'ARRAY',
                );

                # search tickets with remarks (TicketNotes)
                delete $SearchProfileData{Title};
                $SearchProfileData{TicketNotes} = $SearchProfileData{Fulltext};
                my @ViewableTicketIDsTicketNotes = $TicketObject->TicketSearch(
                    %SearchProfileData,
                    UserID          => $Self->{UserID},
                    ConditionInline => 1,
                    FullTextIndex   => 1,
                    Result          => 'ARRAY',
                );
                delete $SearchProfileData{TicketNotes};

                # search ticket with DF if configured
                if ( $AgentTicketSearchConfig->{FulltextSearchInDynamicFields} ) {

                    # prepare fulltext serach in DFs
                    DYNAMICFIELDFULLTEXT:
                    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                        next DYNAMICFIELDFULLTEXT
                            if !(
                                    $AgentTicketSearchConfig->{FulltextSearchInDynamicFields}
                                    ->{ $DynamicFieldConfig->{Name} }
                            );
                        next DYNAMICFIELDFULLTEXT if !IsHashRefWithData($DynamicFieldConfig);

                        my %DFSearchParameters;

                        # get search field preferences
                        my $SearchFieldPreferences = $DynamicFieldBackendObject->SearchFieldPreferences(
                            DynamicFieldConfig => $DynamicFieldConfig,
                        );

                        next DYNAMICFIELDFULLTEXT if !IsArrayRefWithData($SearchFieldPreferences);

                        PREFERENCEFULLTEXT:
                        for my $Preference ( @{$SearchFieldPreferences} ) {

                            # extract the dynamic field value from the profile
                            my $SearchParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                                DynamicFieldConfig => $DynamicFieldConfig,
                                Profile            => {
                                    "Search_DynamicField_$DynamicFieldConfig->{Name}" => '*'
                                        . $SearchProfileData{Fulltext} . '*',
                                },
                                LayoutObject => $LayoutObject,
                                Type         => $Preference->{Type},
                            );

                            # set search parameter
                            if ( defined $SearchParameter ) {
                                $DFSearchParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $SearchParameter->{Parameter};
                            }
                        }

                        # search tickets
                        my @ViewableTicketIDsThisDF = $TicketObject->TicketSearch(
                            Result          => 'ARRAY',
                            SortBy          => $Self->{SortBy},
                            OrderBy         => $Self->{OrderBy},
                            Limit           => $Self->{SearchLimit},
                            UserID          => $Self->{UserID},
                            ConditionInline => $AgentTicketSearchConfig->{ExtendedSearchCondition},
                            ArchiveFlags    => $SearchProfileData{ArchiveFlags},
                            %DFSearchParameters,
                        );

                        if (@ViewableTicketIDsThisDF) {

                            # join arrays
                            @ViewableTicketIDsDF = (
                                @ViewableTicketIDsDF,
                                @ViewableTicketIDsThisDF,
                            );
                        }
                    }
                }

                # merge arrays
                my @MergeArray;
                push(
                    @MergeArray,
                    @ViewableTicketIDs,
                    @ViewableTicketIDsTitle,
                    @ViewableTicketIDsTicketNotes,
                    @ViewableTicketIDsTN,
                    @ViewableTicketIDsDF
                );

                if ( scalar(@MergeArray) > 1 ) {
                    # sort merged tickets
                    @ViewableTicketIDs = $TicketObject->TicketSearch(
                        Result       => 'ARRAY',
                        SortBy       => $Self->{SortBy},
                        OrderBy      => $Self->{OrderBy},
                        UserID       => $Self->{UserID},
                        TicketID     => \@MergeArray,
                        ArchiveFlags => $SearchProfileData{ArchiveFlags},
                    );
                }
                else {
                    @ViewableTicketIDs = @MergeArray;
                }
            }
            $Hash{Total} = scalar( @ViewableTicketIDs ) || 0;

            # prepare fulltext search
            if ( $SearchProfileData{Fulltext} ) {
                $SearchProfileData{ContentSearch} = 'OR';
                for (qw(From To Cc Subject Body)) {
                    $SearchProfileData{$_} = $SearchProfileData{Fulltext};
                }
            }
            # get ticket count
            @ViewableTicketIDs = $TicketObject->TicketSearch(
                %SearchProfileData,
                LockIDs         => \@ViewableLockIDs,
                UserID          => $Self->{UserID},
                ConditionInline => 1,
                FullTextIndex   => 1,
                Result          => 'ARRAY',
            );

            if ( $SearchProfileData{Fulltext} ) {
                my @ViewableTicketIDsDF = ();

                # search tickets with TicketNumber
                # (we have to do this here, because TicketSearch concatenates TN and Title with AND condition)
                # clear additional parameters
                for (qw(From To Cc Subject Body)) {
                    delete $SearchProfileData{$_};
                }

                my $TicketHook          = $ConfigObject->Get('Ticket::Hook');
                my $FulltextSearchParam = $SearchProfileData{Fulltext};
                $FulltextSearchParam =~ s/$TicketHook//g;
                $SearchProfileData{TicketNumber} = '*' . $FulltextSearchParam . '*';

                my @ViewableTicketIDsTN = $TicketObject->TicketSearch(
                    %SearchProfileData,
                    LockIDs         => \@ViewableLockIDs,
                    UserID          => $Self->{UserID},
                    ConditionInline => 1,
                    FullTextIndex   => 1,
                    Result          => 'ARRAY',
                );

                # search tickets with Title
                delete $SearchProfileData{TicketNumber};
                $SearchProfileData{Title} = $SearchProfileData{Fulltext};
                my @ViewableTicketIDsTitle = $TicketObject->TicketSearch(
                    %SearchProfileData,
                    LockIDs         => \@ViewableLockIDs,
                    UserID          => $Self->{UserID},
                    ConditionInline => 1,
                    FullTextIndex   => 1,
                    Result          => 'ARRAY',
                );

                # search tickets with remarks (TicketNotes)
                delete $SearchProfileData{Title};
                $SearchProfileData{TicketNotes} = $SearchProfileData{Fulltext};
                my @ViewableTicketIDsTicketNotes = $TicketObject->TicketSearch(
                    %SearchProfileData,
                    LockIDs         => \@ViewableLockIDs,
                    UserID          => $Self->{UserID},
                    ConditionInline => 1,
                    FullTextIndex   => 1,
                    Result          => 'ARRAY',
                );
                delete $SearchProfileData{TicketNotes};

                # search ticket with DF if configured
                if ( $AgentTicketSearchConfig->{FulltextSearchInDynamicFields} ) {

                    # prepare fulltext serach in DFs
                    DYNAMICFIELDFULLTEXT:
                    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                        next DYNAMICFIELDFULLTEXT
                            if !(
                                    $AgentTicketSearchConfig->{FulltextSearchInDynamicFields}
                                    ->{ $DynamicFieldConfig->{Name} }
                            );
                        next DYNAMICFIELDFULLTEXT if !IsHashRefWithData($DynamicFieldConfig);

                        my %DFSearchParameters;

                        # get search field preferences
                        my $SearchFieldPreferences = $DynamicFieldBackendObject->SearchFieldPreferences(
                            DynamicFieldConfig => $DynamicFieldConfig,
                        );

                        next DYNAMICFIELDFULLTEXT if !IsArrayRefWithData($SearchFieldPreferences);

                        PREFERENCEFULLTEXT:
                        for my $Preference ( @{$SearchFieldPreferences} ) {

                            # extract the dynamic field value from the profile
                            my $SearchParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                                DynamicFieldConfig => $DynamicFieldConfig,
                                Profile            => {
                                    "Search_DynamicField_$DynamicFieldConfig->{Name}" => '*'
                                        . $SearchProfileData{Fulltext} . '*',
                                },
                                LayoutObject => $LayoutObject,
                                Type         => $Preference->{Type},
                            );

                            # set search parameter
                            if ( defined $SearchParameter ) {
                                $DFSearchParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} }  = $SearchParameter->{Parameter};
                            }
                        }

                        # search tickets
                        my @ViewableTicketIDsThisDF = $TicketObject->TicketSearch(
                            Result          => 'ARRAY',
                            LockIDs         => \@ViewableLockIDs,
                            SortBy          => $Self->{SortBy},
                            OrderBy         => $Self->{OrderBy},
                            Limit           => $Self->{SearchLimit},
                            UserID          => $Self->{UserID},
                            ConditionInline => $AgentTicketSearchConfig->{ExtendedSearchCondition},
                            ArchiveFlags    => $SearchProfileData{ArchiveFlags},
                            %DFSearchParameters,
                        );

                        if (@ViewableTicketIDsThisDF) {

                            # join arrays
                            @ViewableTicketIDsDF = (
                                @ViewableTicketIDsDF,
                                @ViewableTicketIDsThisDF,
                            );
                        }
                    }
                }

                # merge arrays
                my @MergeArray;
                push(
                    @MergeArray,
                    @ViewableTicketIDs,
                    @ViewableTicketIDsTitle,
                    @ViewableTicketIDsTicketNotes,
                    @ViewableTicketIDsTN,
                    @ViewableTicketIDsDF
                );

                if ( scalar(@MergeArray) > 1 ) {
                    # sort merged tickets
                    @ViewableTicketIDs = $TicketObject->TicketSearch(
                        Result       => 'ARRAY',
                        SortBy       => $Self->{SortBy},
                        OrderBy      => $Self->{OrderBy},
                        UserID       => $Self->{UserID},
                        TicketID     => \@MergeArray,
                        ArchiveFlags => $SearchProfileData{ArchiveFlags},
                    );
                }
                else {
                    @ViewableTicketIDs = @MergeArray;
                }
            }
            $Hash{Count} = scalar( @ViewableTicketIDs ) || 0;

            my $Encrypted            = Digest::MD5::md5_hex($Profiles{$SearchProfileName});
            $Hash{QueueID}           = 'SearchProfile_' . $Encrypted;
            $Hash{SearchProfileName} = $SearchProfileName;
            $Hash{Queue}             = $Profiles{$SearchProfileName};
            $Hash{MaxAge}            = 0;

            # add content to current availible views
            push( @{ $Data{Queues} }, \%Hash );

            # set name for selected queue, needed for highlight
            if ( $Self->{QueueID} eq $Hash{QueueID} ) {
                $Param{SelectedQueue} = $Hash{Queue};
                $Data{TicketsShown}   = $Hash{Count};
            }
        }
    }

    # show individual views
    if (
        $Config->{IndividualViews} &&
        ref( $Config->{IndividualViews} ) eq 'HASH'
    ) {
        my $QueueViews          = $Config->{IndividualViews};
        my $QueueViewName       = $Config->{IndividualViewNames};
        my $QueueViewParamAND   = $Config->{IndividualViewParameterAND};
        my $QueueViewParamOR    = $Config->{IndividualViewParameterOR};
        my $QueueViewPermission = $Config->{IndividualViewPermission};

        return $LayoutObject->FatalError( Message => "IndividualViews not a HASH!" )
            if ( !$QueueViews || ref($QueueViews) ne 'HASH' );
        return $LayoutObject->FatalError( Message => "IndividualViewNames not a HASH!" )
            if ( !$QueueViewName || ref($QueueViewName) ne 'HASH' );
        return $LayoutObject
            ->FatalError( Message => "IndividualViewParameterAND not a HASH!" )
            if ( !$QueueViewParamAND || ref($QueueViewParamAND) ne 'HASH' );
        return $LayoutObject
            ->FatalError( Message => "IndividualViewParameterOR not a HASH!" )

            if ( !$QueueViewParamOR || ref($QueueViewParamOR) ne 'HASH' );
        return $LayoutObject
            ->FatalError( Message => "IndividualViewPermission not a HASH!" )
            if ( !$QueueViewPermission || ref($QueueViewPermission) ne 'HASH' );

        for my $View ( sort keys %{$QueueViews} ) {

            # check for misconfiguration
            next if ( $View eq '' || $View =~ /^\d+$/ );

            my %Hash;
            $Hash{QueueID} = $View;
            $Hash{Queue}   = $LayoutObject->{LanguageObject}->Get( $QueueViewName->{$View} ) || '';
            $Hash{MaxAge}  = 0;

            # prepare search parameter
            my %Search;
            my $SearchParametersStr = $QueueViewParamAND->{$View} || $QueueViewParamOR->{$View};
            my @SearchParameters = split( '\|\|\|', $SearchParametersStr );
            for my $CurrSearch (@SearchParameters) {
                my @CurrSearchParamater = split( ':::', $CurrSearch );
                next if ( scalar(@CurrSearchParamater) != 2 );

                my $Key = $CurrSearchParamater[0];
                my @Values = split( ';', $CurrSearchParamater[1] );

                for my $Value (@Values) {
                    if ( $Value eq '_ME_' ) {
                        $Value = $Self->{UserID};
                    }
                    elsif ( $Value eq '_ANY_' ) {
                        $Value = '*';
                    }
                    elsif ( $Value eq '_NONE_' ) {

                        # no change, further processing in TicketSearch
                    }
                    elsif ( $Value =~ /_ME_PREF_.+/ ) {
                        $Value =~ s/.*_ME_PREF_//;
                        $Value = $Self->{UserPreferences}->{$Value} || '';
                    }
                }
                $Search{$Key} = \@Values;
            }

            # other search permissions for this view?
            my $Permission = $Self->{SearchPermission};
            if ( $QueueViewPermission->{$View} ) {
                $Permission = $QueueViewPermission->{$View};
            }

            # count tickets
            if ( $QueueViewParamOR->{$View} ) {
                $Hash{Count} = $TicketObject->TicketSearchOR(
                    StateIDs => \@ViewableStateIDs,
                    LockIDs  => \@ViewableLockIDs,
                    %Search,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                    Result     => 'COUNT',
                ) || 0;
                $Hash{Total} = $TicketObject->TicketSearchOR(
                    StateIDs => \@ViewableStateIDs,
                    %Search,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                    Result     => 'COUNT',
                ) || 0;
            }
            else {
                $Hash{Count} = $TicketObject->TicketSearch(
                    StateIDs => \@ViewableStateIDs,
                    LockIDs  => \@ViewableLockIDs,
                    %Search,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                    Result     => 'COUNT',
                ) || 0;
                $Hash{Total} = $TicketObject->TicketSearch(
                    StateIDs => \@ViewableStateIDs,
                    %Search,
                    Permission => $Permission,
                    UserID     => $Self->{UserID},
                    Result     => 'COUNT',
                ) || 0;
            }

            # add content to current availible views
            push( @{ $Data{Queues} }, \%Hash );

            # set name for selected queue, needed for highlight
            if ( $Self->{QueueID} eq $Hash{QueueID} ) {
                $Param{SelectedQueue} = $Hash{Queue};
                $Data{TicketsShown}   = $Hash{Count};
            }
        }
    }

    # build output ...
    my %AllQueues = $Kernel::OM->Get('Kernel::System::Queue')->QueueList( Valid => 0 );

    my $ViewLayoutFunction = '_MaskQueueView' . $Self->{UserPreferences}->{UserQueueViewLayout};

    # return $Self->_MaskQueueView(
    return $Self->$ViewLayoutFunction(
        %Data,
        QueueID         => $Self->{QueueID},
        AllQueues       => \%AllQueues,
        ViewableTickets => $Self->{ViewableTickets},
        SelectedQueue   => $Param{SelectedQueue} || '',
        SelectedQueueID => $Param{SelectedQueueID},
        Filter          => $Param{Filter},
        UseSubQueues    => $Param{UseSubQueues},
    );
}

sub _MaskQueueView {
    my ( $Self, %Param ) = @_;

    my $QueueID         = $Param{QueueID} || 0;
    my @QueuesNew       = @{ $Param{Queues} };
    my $QueueIDOfMaxAge = $Param{QueueIDOfMaxAge} || -1;
    my %AllQueues       = %{ $Param{AllQueues} };
    my %Counter;
    my %Totals;
    my %UsedQueue;
    my @ListedQueues;
    my $HaveTotals   = 0;    # flag for "Total" in index backend
    my $Level        = 0;
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $CustomQueues = $ConfigObject->Get('Ticket::CustomQueue') || '???';
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomQueue  = $LayoutObject->{LanguageObject}->Translate($CustomQueues);
    my $Config       = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");
    $Self->{HighlightAge1} = $Config->{HighlightAge1};
    $Self->{HighlightAge2} = $Config->{HighlightAge2};
    $Self->{Blink}         = $Config->{Blink};

    if ( !$Param{SelectedQueue} ) {
        $Param{SelectedQueue} = $AllQueues{$QueueID} || $CustomQueue;
    }

    my @MetaQueue = split /::/, $Param{SelectedQueue};
    $Level = $#MetaQueue + 2;

    # prepare shown queues (short names)
    # - get queue total count -
    for my $QueueRef (@QueuesNew) {
        push @ListedQueues, $QueueRef;
        my %Queue = %$QueueRef;
        my @Queue = split /::/, $Queue{Queue};
        $HaveTotals ||= exists $Queue{Total};

        # remember counted/used queues
        $UsedQueue{ $Queue{Queue} } = 1;

        # move to short queue names
        my $QueueName = '';
        for ( 0 .. $#Queue ) {
            if ( !$QueueName ) {
                $QueueName .= $Queue[$_];
            }
            else {
                $QueueName .= '::' . $Queue[$_];
            }
            if ( !exists $Counter{$QueueName} ) {
                $Counter{$QueueName} = 0;    # init
                $Totals{$QueueName}  = 0;
            }
            my $Total = $Queue{Total} || 0;
            $Counter{$QueueName} += $Queue{Count};
            $Totals{$QueueName}  += $Total;
            if (
                ( $Counter{$QueueName} || $Totals{$QueueName} )
                && !$Queue{$QueueName}
                && !$UsedQueue{$QueueName}
            ) {

                # IMHO, this is purely pathological--TicketAcceleratorIndex
                # sorts queues by name, so we should never stumble across one
                # that we have not seen before!
                my %Hash = ();
                $Hash{Queue} = $QueueName;
                $Hash{Count} = $Counter{$QueueName};
                $Hash{Total} = $Total;
                for ( sort keys %AllQueues ) {
                    if ( $AllQueues{$_} eq $QueueName ) {
                        $Hash{QueueID} = $_;
                    }
                }
                $Hash{MaxAge} = 0;
                push( @ListedQueues, \%Hash );
                $UsedQueue{$QueueName} = 1;
            }
        }
    }

    # build queue string
    QUEUE:
    for my $QueueRef (@ListedQueues) {
        my $QueueStrg = '';
        my %Queue     = %$QueueRef;

        # replace name of CustomQueue
        if ( $Queue{Queue} eq 'CustomQueue' ) {
            $Counter{$CustomQueue} = $Counter{ $Queue{Queue} };
            $Totals{$CustomQueue}  = $Totals{ $Queue{Queue} };
            $Queue{Queue}          = $CustomQueue;
        }
        my @QueueName = split /::/, $Queue{Queue};
        my $ShortQueueName = $QueueName[-1];
        $Queue{MaxAge} = $Queue{MaxAge} / 60;
        $Queue{QueueID} = 0 if ( !$Queue{QueueID} );

        # skip empty Queues (or only locked tickets)
        if (

            # only check when setting is set
            $Config->{HideEmptyQueues}

            # empty or locked only
            && $Counter{ $Queue{Queue} } < 1

            # always show 'my queues'
            && $Queue{QueueID} != 0
        ) {
            next QUEUE;
        }

        my $View   = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'View' )   || '';
        my $Filter = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'Filter' ) || 'Unlocked';

        $QueueStrg
            .= "<li><a href=\"$LayoutObject->{Baselink}Action=AgentTicketQueue;QueueID=$Queue{QueueID}";
        $QueueStrg .= ';View=' . $LayoutObject->Ascii2Html( Text => $View );
        $QueueStrg .= ';Filter=' . $LayoutObject->Ascii2Html( Text => $Filter );
        if ( $QueueID eq $Queue{QueueID} && $Config->{UseSubQueues} eq $Param{UseSubQueues} ) {
            $QueueStrg .= ';UseSubQueues=';
            $QueueStrg .= $Param{UseSubQueues} ? 0 : 1;
        }
        $QueueStrg .= '" class="';

        # should i highlight this queue
        # the oldest queue
        if ( $Queue{QueueID} eq $QueueIDOfMaxAge && $Self->{Blink} ) {
            $QueueStrg .= 'Oldest';
        }
        elsif ( $Queue{MaxAge} >= $Self->{HighlightAge2} ) {
            $QueueStrg .= 'OlderLevel2';
        }
        elsif ( $Queue{MaxAge} >= $Self->{HighlightAge1} ) {
            $QueueStrg .= 'OlderLevel1';
        }

        # display the current and all its lower levels in bold
        my $CheckQueueName;
        if (
            $Level > scalar @QueueName
            && scalar @MetaQueue >= scalar @QueueName
            && $Param{SelectedQueue} =~ m{ \A \Q$QueueName[0]\E }xms
        ) {
            my $CheckLevel = 0;
            CHECKLEVEL:
            for ( $CheckLevel = 0; $CheckLevel < scalar @QueueName; ++$CheckLevel ) {
                if ($CheckQueueName) {
                    $CheckQueueName .= '::';
                }
                $CheckQueueName .= $MetaQueue[$CheckLevel];
            }
        }

        # should i display this queue in bold?
        if ( $CheckQueueName && $Queue{Queue} =~ m{ \A \Q$CheckQueueName\E \z }xms ) {
            $QueueStrg .= ' Active';
        }

        $QueueStrg .= '">';

        # remember to selected queue info
        if ( $QueueID eq $Queue{QueueID} ) {
            $Param{SelectedQueue} = $Queue{Queue};
            $Param{AllSubTickets} = $Counter{ $Queue{Queue} };
        }

        # QueueStrg
        $QueueStrg .= $LayoutObject->Ascii2Html( Text => $ShortQueueName );

        # If the index backend supports totals, we show total tickets
        # as well as unlocked ones in the form  "QueueName (total / unlocked)"
        if ( $HaveTotals && ( $Totals{ $Queue{Queue} } != $Counter{ $Queue{Queue} } ) ) {
            $QueueStrg .= " ($Totals{$Queue{Queue}}/$Counter{$Queue{Queue}})";
        }
        else {
            $QueueStrg .= " ($Counter{$Queue{Queue}})";
        }

        $QueueStrg .= '</a></li>';

        if ( scalar( @QueueName ) == 1 ) {
            $Param{QueueStrg} .= $QueueStrg;
        }
        elsif ( $Level >= scalar @QueueName ) {
            my $CheckQueueStrgName = '';
            for ( my $LevelCount = 0; $LevelCount < scalar @QueueName - 1; ++$LevelCount ) {
                $CheckQueueStrgName .= $MetaQueue[$LevelCount] . '::';
            }
            if ( $Queue{Queue} =~ m{ \A \Q$CheckQueueStrgName\E }xms ) {

                $Param{ 'QueueStrg' . scalar @QueueName - 1 } .= $QueueStrg;
            }
        }
    }

    my $Counter = 0;
    KEYS:
    for my $Keys ( sort keys %Param ) {
        if ( $Keys !~ /^QueueStrg/ ) {
            next KEYS;
        }
        my $Class = $Counter;
        if ( $Counter > 10 ) {
            $Class = 'X';
        }

        $Param{QueueStrgLevel}
            .= '<ul class="QueueOverviewList Level_' . $Class . '">' . $Param{$Keys} . '</ul>';
        $Counter++;
    }

    return (
        MainName      => 'Queues',
        SelectedQueue => $Param{SelectedQueue},
        MainContent   => $Param{QueueStrgLevel},
        Total         => $Param{TicketsShown},
    );
}

sub _MaskQueueViewTree {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    my $CustomQueues = $ConfigObject->Get('Ticket::CustomQueue') || '???';
    my $CustomQueue = $LayoutObject->{LanguageObject}->Translate($CustomQueues);

    my $QueueID = $Param{QueueID} || 0;
    my @QueuesNew = @{ $Param{Queues} };

    # add search profile queue if search profiles activated for queue view
    my $SearchProfileCount = 0;
    for my $QueueHash (@QueuesNew) {
        next if $QueueHash->{QueueID} !~ m/^SearchProfile_/;
        $SearchProfileCount++;
    }

    if ($SearchProfileCount) {
        my %SearchProfileQueue;
        $SearchProfileQueue{Queue}   = $Self->{SearchProfileQueue};
        $SearchProfileQueue{QueueID} = 'SearchProfileQueue';
        $SearchProfileQueue{Count}   = $SearchProfileCount;
        $SearchProfileQueue{MaxAge}  = 0;
        push @QueuesNew, \%SearchProfileQueue;
    }

    my $QueueIDOfMaxAge = $Param{QueueIDOfMaxAge} || -1;
    $Self->{HighlightAge1} = $Config->{HighlightAge1};
    $Self->{HighlightAge2} = $Config->{HighlightAge2};
    $Self->{Blink}         = $Config->{Blink};

    my %AllQueues        = %{ $Param{AllQueues} };
    my %AllQueuesReverse = reverse %AllQueues;
    my %AllQueuesData;

    $Param{SelectedSearchProfileQueueName} = '';
    if ( $QueueID =~ m/^SearchProfile_(.*)/ ) {
            $Param{SelectedSearchProfileQueue} = $1;
    } elsif ( !$Param{SelectedQueue} ) {
        $Param{SelectedQueue} = $AllQueues{$QueueID} || $CustomQueue;
    }

    my @MetaQueue = split( /::/, $Param{SelectedQueue} );
    my $Level = $#MetaQueue + 2;

    # build queue information (including virtual queues)
    for my $QueueRef (@QueuesNew) {
        my %Queue = %{$QueueRef};
        if (
            defined $Queue{QueueID}
            && $Queue{QueueID} =~ m/^SearchProfile_(.*)/
        ) {
            if ( defined $Param{SelectedSearchProfileQueue}
                && $Param{SelectedSearchProfileQueue} eq $1
            ) {
                $Param{SelectedSearchProfileQueueName} = $Queue{Queue};
                $Param{SelectedQueue}                  = $Self->{SearchProfileQueue} . ' - ' . $Queue{Queue};

                @MetaQueue = split( /::/, $Self->{SearchProfileQueue} . '::' . $Queue{Queue} );
                $Level = $#MetaQueue + 2;
            }
            $Queue{Queue}   = $Self->{SearchProfileQueue} . '::' . $Queue{Queue};
        }

        if ( $Queue{Queue} eq 'CustomQueue' ) { $Queue{Queue} = $CustomQueue; }
        my @Queue = split( /::/, $Queue{Queue} );
        my $QueueName4Sort = $Queue{Queue};
        $QueueName4Sort =~ s/ /AAAa/g;
        $QueueName4Sort =~ s/-/AAAb/g;
        $QueueName4Sort =~ s/_/AAAc/g;

        $AllQueuesData{$QueueName4Sort} = {
            Count      => $Queue{Count},
            Total      => $Queue{Total},
            Queue      => $Queue[-1],
            QueueID    => $Queue{QueueID},
            QueueSplit => \@Queue,
            MaxAge     => ( $Queue{MaxAge} / 60 ) || 0,
            Name       => $Queue{Queue},
        };

        # process current queue information to all parents
        my $QueueName = '';
        for ( 0 .. $#Queue - 1 ) {
            $QueueName .= '::' if $QueueName;
            $QueueName .= $Queue[$_];
            $QueueName4Sort = $QueueName;
            $QueueName4Sort =~ s/ /AAAa/g;
            $QueueName4Sort =~ s/-/AAAb/g;
            $QueueName4Sort =~ s/_/AAAc/g;

            # parent not initialized yet?
            if ( !$AllQueuesData{$QueueName4Sort} ) {
                my @QueueSplit = split( /::/, $QueueName );
                $AllQueuesData{$QueueName4Sort} = {
                    Count      => 0,
                    Queue      => $Queue[$_],
                    QueueID    => $AllQueuesReverse{$QueueName},
                    QueueSplit => \@QueueSplit,    # prevent strange behaviour and freezes
                    MaxAge     => 0,
                    Name       => $QueueName,
                };
            }

            # add current ticket count to parent queue
            $AllQueuesData{$QueueName4Sort}->{Total} += $Queue{Total} || 0;
            $AllQueuesData{$QueueName4Sort}->{Count} += $Queue{Count} || 0;
        }
    }

    # build queue string
    my %QueueBuildLastLevel = (
        QueueVirtStrg => 0,
        QueueRealStrg => 0,
    );
    for my $SortName ( sort { lc($a) cmp lc($b) } keys %AllQueuesData ) {
        my %Queue = %{ $AllQueuesData{$SortName} };

        my $Current   = $Queue{Name};
        my @QueueName = @{ $Queue{QueueSplit} };

        # not CustomQueue and nothing to show?
        next if (
            ( defined $Queue{Total} && !$Queue{Total} )
            && $Queue{Queue} !~ /^\Q$CustomQueue\E/
        );

        # set relevant html container
        my $QueuePlace = ( $AllQueuesReverse{$Current} ) ? 'QueueRealStrg' : 'QueueVirtStrg';

        # build queue link with short name
        my $CurrentMaxLength = 46 - ( 2 * $#QueueName );

        my $QueueStrg = '';

        # if there are any search profiles to show
        if ( defined $Queue{QueueID} && $Queue{QueueID} =~ m/^SearchProfileQueue$/ ) {
            $QueueStrg = '<a href="?#" class="NoReload">' . $Queue{Queue} . '</a>';
        }

        # show other queues
        elsif ( defined $Queue{QueueID} ) {
            my $QueueCountDisplay;
            if ( $Queue{Count} == $Queue{Total} ) {
                $QueueCountDisplay = "(" . $Queue{Total} . ")";
            }
            else {
                $QueueCountDisplay = "(" . $Queue{Count} . "/" . $Queue{Total} . ")";
            }
            $QueueStrg = '<a href="' . $LayoutObject->{Baselink}
                . 'Action=AgentTicketQueue'
                . ';QueueID=' . $Queue{QueueID}
                . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
                . ';Filter='
                . $LayoutObject->Ascii2Html( Text => $Param{Filter} ) . '"'
                . ' title="'
                . $Current . '">'
                . $Queue{Queue} . ' '
                . $QueueCountDisplay
                . '</a>';
        }

        my $ListClass  = '';
        my $DataJSTree = '';

        # should i highlight this queue
        # the oldest queue
        if ( defined $Queue{QueueID} && $Queue{QueueID} eq $QueueIDOfMaxAge && $Self->{Blink} ) {
            $ListClass .= 'Oldest';
        }
        elsif ( $Queue{MaxAge} >= $Self->{HighlightAge2} ) {
            $ListClass .= 'OlderLevel2';
        }
        elsif ( $Queue{MaxAge} >= $Self->{HighlightAge1} ) {
            $ListClass .= 'OlderLevel1';
        }

        # should I focus and expand this queue
        if ( $Param{SelectedQueue} =~ /^\Q$QueueName[0]\E/ && $Level - 1 >= $#QueueName ) {
            if ( $#MetaQueue >= $#QueueName ) {
                my $CompareString = $MetaQueue[0];
                for ( 1 .. $#QueueName ) { $CompareString .= "::" . $MetaQueue[$_]; }
                if ( $Current =~ /^\Q$CompareString\E$/ ) {
                    $DataJSTree = '{"opened":true,"selected":true}';
                }
            }
        }
        elsif ($QueueName[0] eq $Self->{SearchProfileQueue}
            && $#QueueName == 1
            && $QueueName[1] eq $Param{SelectedSearchProfileQueueName}
        ) {
            $DataJSTree = '{"opened":true,"selected":true}';
        }

        # open sub queue menu
        if ( $QueueBuildLastLevel{$QueuePlace} < $#QueueName ) {
            $Param{$QueuePlace} .= '<ul>';
        }

        # close former sub queue menu
        elsif ( $QueueBuildLastLevel{$QueuePlace} > $#QueueName ) {
            $Param{$QueuePlace} .=
                '</li></ul>' x ( $QueueBuildLastLevel{$QueuePlace} - $#QueueName );
            $Param{$QueuePlace} .= '</li>';
        }

        # close former list element
        elsif ( $Param{$QueuePlace} ) {
            $Param{$QueuePlace} .= '</li>';
        }

        $Param{$QueuePlace}
            .= "<li class='Node $ListClass' data-jstree='$DataJSTree' id='QueueID_$Queue{QueueID}'>"
            . $QueueStrg;

        # keep current queue level for next queue
        $QueueBuildLastLevel{$QueuePlace} = $#QueueName;
    }

    # build queue tree (and close all sub queue menus)
    $Param{QueueStrg} .= '<ul class="QueueTreeView">';
    $Param{QueueStrg} .= $Param{QueueVirtStrg} || '';
    $Param{QueueStrg} .= '</li></ul>' x $QueueBuildLastLevel{QueueVirtStrg};
    $Param{QueueStrg} .= $Param{QueueRealStrg} || '';
    $Param{QueueStrg} .= '</li></ul>' x $QueueBuildLastLevel{QueueRealStrg};
    $Param{QueueStrg} .= '</li></ul>';

    return (
        MainName        => 'Queues',
        SelectedQueue   => $Param{SelectedQueue},
        SelectedQueueID => $Param{SelectedQueueID},
        QueueID         => $QueueID || 0,
        MainContent     => $Param{QueueStrg},
        PageNavBar      => $Param{PageNavBar},
        Total           => $Param{TicketsShown},
    );
}

sub _MaskQueueViewDropDown {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    my $CustomQueues = $ConfigObject->Get('Ticket::CustomQueue') || '???';
    my $CustomQueue = $LayoutObject->{LanguageObject}->Translate($CustomQueues);

    my $QueueID         = $Param{QueueID} || 0;
    my @QueuesNew       = @{ $Param{Queues} };
    my $QueueIDOfMaxAge = $Param{QueueIDOfMaxAge} || -1;
    $Self->{HighlightAge1} = $Config->{HighlightAge1};
    $Self->{HighlightAge2} = $Config->{HighlightAge2};
    $Self->{Blink}         = $Config->{Blink};

    my %AllQueues        = %{ $Param{AllQueues} };
    my %AllQueuesReverse = reverse %AllQueues;
    my %AllQueuesData;

    my %QueueStrg;

    if ( !$Param{SelectedQueue} ) {
        $Param{SelectedQueue} = $AllQueues{$QueueID} || $CustomQueue;
    }

    my @MetaQueue = split( /::/, $Param{SelectedQueue} );
    my $Level = $#MetaQueue + 2;

    # build queue information (including virtual queues)
    for my $QueueRef (@QueuesNew) {
        my %Queue = %{$QueueRef};
        if ( $Queue{Queue} eq 'CustomQueue' ) { $Queue{Queue} = $CustomQueue; }
        my @Queue = split( /::/, $Queue{Queue} );

        $AllQueuesData{ $Queue{Queue} } = {
            Count      => $Queue{Count},
            Total      => $Queue{Total},
            Queue      => $Queue[-1],
            QueueID    => $Queue{QueueID},
            QueueSplit => \@Queue,
            MaxAge     => ( $Queue{MaxAge} / 60 ) || 0,
        };

        # process current queue information to all parents
        my $QueueName = '';
        for ( 0 .. $#Queue - 1 ) {
            $QueueName .= '::' if $QueueName;
            $QueueName .= $Queue[$_];

            # parent not initialized yet?
            if ( !$AllQueuesData{$QueueName} ) {
                my @QueueSplit = split( /::/, $QueueName );
                $AllQueuesData{$QueueName} = {
                    Count      => 0,
                    Queue      => $Queue[$_],
                    QueueID    => $AllQueuesReverse{$QueueName},
                    QueueSplit => \@QueueSplit,    # prevent strange behaviour and freezes
                    MaxAge     => 0,
                };
            }

            # add current ticket count to parent queue
            $AllQueuesData{$QueueName}->{Total} += $Queue{Total} || 0;
            $AllQueuesData{$QueueName}->{Count} += $Queue{Count} || 0;
        }
    }

    for my $Current ( sort keys %AllQueuesData ) {
        my %Queue     = %{ $AllQueuesData{$Current} };
        my @QueueName = @{ $Queue{QueueSplit} };

        # not CustomQueue and nothing to show?
        next if ( defined $Queue{Total} && !$Queue{Total} && $Queue{Queue} !~ /^\Q$CustomQueue\E/ );

        my $QueueStrg = $LayoutObject->{Baselink}
            . 'Action=AgentTicketQueue'
            . ';QueueID=' . $Queue{QueueID}
            . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
            . ';Filter=' . $LayoutObject->Ascii2Html( Text => $Param{Filter} );

        # add SessionID if necessary
        if ( !$ConfigObject->Get('SessionUseCookie') ) {
            $QueueStrg
                .= ';' . $ConfigObject->Get('SessionName') . '=' . $LayoutObject->{SessionID};
        }

        my $ListClass = '';

        # should i highlight this queue
        # the oldest queue
        if ( $Queue{QueueID} eq $QueueIDOfMaxAge && $Self->{Blink} ) {
            $ListClass .= 'Oldest';
        }
        elsif ( $Queue{MaxAge} >= $Self->{HighlightAge2} ) {
            $ListClass .= 'OlderLevel2';
        }
        elsif ( $Queue{MaxAge} >= $Self->{HighlightAge1} ) {
            $ListClass .= 'OlderLevel1';
        }

        # should I focus and expand this queue
        if ( $Param{SelectedQueue} =~ /^\Q$QueueName[0]\E/ && $Level - 1 >= $#QueueName ) {
            if ( $#MetaQueue >= $#QueueName ) {
                my $CompareString = $MetaQueue[0];
                for ( 1 .. $#QueueName ) { $CompareString .= "::" . $MetaQueue[$_]; }
                if ( $Current =~ /^\Q$CompareString\E$/ ) {
                    $QueueStrg{$#QueueName}->{Selected}   = $CompareString;
                    $QueueStrg{$#QueueName}->{SelectedID} = $QueueStrg;
                }
            }
        }
        my $QueueCountDisplay;
        if ( $Queue{Count} == $Queue{Total} ) {
            $QueueCountDisplay = "(" . $Queue{Total} . ")";
        }
        else {
            $QueueCountDisplay = "(" . $Queue{Count} . "/" . $Queue{Total} . ")";
        }
        $QueueStrg{$#QueueName}->{Data}->{$Current}->{Label}
            = $QueueName[-1] . " " . $QueueCountDisplay;
        $QueueStrg{$#QueueName}->{Data}->{$Current}->{Link} = $QueueStrg;
    }

    my $ParentFilter;
    foreach my $QueueLevel ( sort keys %QueueStrg ) {
        my %QueueLevelList;
        foreach my $Key ( sort keys %{ $QueueStrg{$QueueLevel}->{Data} } ) {
            if ( !$QueueLevel || $ParentFilter && $Key =~ /^\Q$ParentFilter\E::/ ) {
                $QueueLevelList{ $QueueStrg{$QueueLevel}->{Data}->{$Key}->{Link} }
                    = $QueueStrg{$QueueLevel}->{Data}->{$Key}->{Label};
            }
        }
        next if !%QueueLevelList;

        if ($QueueLevel) {
            my $SelectedParentKey = $QueueStrg{ $QueueLevel - 1 }->{Selected};
            $QueueLevelList{
                $QueueStrg{ $QueueLevel - 1 }->{Data}->{$SelectedParentKey}
                    ->{Link}
                }
                = '-';
        }
        if ( $Param{QueueStrg} ) {
            $Param{QueueStrg} .= '<span class="SpacingLeft SpacingRight">&gt;&gt;</span>';
        }
        $Param{QueueStrg} .= $LayoutObject->BuildSelection(
            Data       => \%QueueLevelList,
            SelectedID => $QueueStrg{$QueueLevel}->{SelectedID},
            Name       => "QueueID[$QueueLevel]",
        );
        $ParentFilter = $QueueStrg{$QueueLevel}->{Selected};
    }

    return (
        MainName      => 'Queues',
        SelectedQueue => $Param{SelectedQueue},
        QueueID       => $QueueID || 0,
        MainContent   => $Param{QueueStrg},
        PageNavBar    => $Param{PageNavBar},
        Total         => $Param{TicketsShown},
    );
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
