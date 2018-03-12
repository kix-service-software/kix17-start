# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketQueue;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

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

    # KIX4OTRS-capeIT
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $LockObject          = $Kernel::OM->Get('Kernel::System::Lock');
    my $StateObject         = $Kernel::OM->Get('Kernel::System::State');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $DynamicFieldObject  = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject
        = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    $Self->{SearchProfileQueue}
        = $LayoutObject->{LanguageObject}->Get( $ConfigObject->Get('Ticket::SearchProfileQueue') )
        || '???';

    my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );
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

    # my $SortBy = $ParamObject->GetParam( Param => 'SortBy' )
    #     || $Config->{'SortBy::Default'}
    #     || 'Age';
    my $SortBy;
    if ( $ParamObject->GetParam( Param => 'SortBy' ) ) {
        $SortBy = $ParamObject->GetParam( Param => 'SortBy' );
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserQueueSortBy',
            Value  => $SortBy,
        );
    }

    # EO KIX4OTRS-capeIT

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

    # KIX4OTRS-capeIT
    # Set the sort order from the request parameters, or take the default.
    # my $OrderBy = $ParamObject->GetParam( Param => 'OrderBy' )
    #     || $DefaultOrderBy;
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

    # EO KIX4OTRS-capeIT    # EO KIX4OTRS-capeIT

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

    # get user object
    # KIX4OTRS-capeIT
    # moved content upwards
    # my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    # EO KIX4OTRS-capeIT

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
        )
    {
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

    # get layout object
    # KIX4OTRS-capeIT
    # moved content upwards
    # my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    # EO KIX4OTRS-capeIT

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
    # KIX4OTRS-capeIT
    # my $Permission = 'rw';
    # if ( $Config->{ViewAllPossibleTickets} ) {
    #     $Permission = 'ro';
    # }
    my $Permission = $Self->{SearchPermission};

    # EO KIX4OTRS-capeIT

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

    # KIX4OTRS-capeIT
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
        )
    {
        $Self->{IndividualViewAND} = $Config->{IndividualViewParameterAND};
    }
    elsif (
        $Config->{IndividualViewParameterOR} &&
        ref( $Config->{IndividualViewParameterOR} ) eq 'HASH' &&
        $Config->{IndividualViewParameterOR}->{ $Self->{QueueID} }
        )
    {
        $Self->{IndividualViewOR} = $Config->{IndividualViewParameterOR};
    }

    # EO KIX4OTRS-capeIT
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

        # KIX4OTRS-capeIT
        || $Self->{UserPreferences}->{UserViewAllTickets}

        # EO KIX4OTRS-capeIT
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
            )
        {
            @OriginalViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                Limit  => $Limit,
                Result => 'ARRAY',
            );

            my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

            @ViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                %ColumnFilter,
                Limit  => $Limit,
                Result => 'ARRAY',
            );
        }
    }

    # KIX4OTRS-capeIT
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

        # get create time settings
        if ( !$Search{ArticleTimeSearchType} ) {

            # do nothing with time stuff
        }
        elsif ( $Search{ArticleTimeSearchType} eq 'TimeSlot' ) {
            for my $Key (qw(Month Day)) {
                $Search{"ArticleCreateTimeStart$Key"}
                    = sprintf( "%02d", $Search{"ArticleCreateTimeStart$Key"} );
                $Search{"ArticleCreateTimeStop$Key"}
                    = sprintf( "%02d", $Search{"ArticleCreateTimeStop$Key"} );
            }
            if (
                $Search{ArticleCreateTimeStartDay}
                && $Search{ArticleCreateTimeStartMonth}
                && $Search{ArticleCreateTimeStartYear}
                )
            {
                $Search{ArticleCreateTimeNewerDate}
                    = $Search{ArticleCreateTimeStartYear} . '-'
                    . $Search{ArticleCreateTimeStartMonth} . '-'
                    . $Search{ArticleCreateTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $Search{ArticleCreateTimeStopDay}
                && $Search{ArticleCreateTimeStopMonth}
                && $Search{ArticleCreateTimeStopYear}
                )
            {
                $Search{ArticleCreateTimeOlderDate}
                    = $Search{ArticleCreateTimeStopYear} . '-'
                    . $Search{ArticleCreateTimeStopMonth} . '-'
                    . $Search{ArticleCreateTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $Search{ArticleTimeSearchType} eq 'TimePoint' ) {
            if (
                $Search{ArticleCreateTimePoint}
                && $Search{ArticleCreateTimePointStart}
                && $Search{ArticleCreateTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $Search{ArticleCreateTimePointFormat} eq 'minute' ) {
                    $Time = $Search{ArticleCreateTimePoint};
                }
                elsif ( $Search{ArticleCreateTimePointFormat} eq 'hour' ) {
                    $Time = $Search{ArticleCreateTimePoint} * 60;
                }
                elsif ( $Search{ArticleCreateTimePointFormat} eq 'day' ) {
                    $Time = $Search{ArticleCreateTimePoint} * 60 * 24;
                }
                elsif ( $Search{ArticleCreateTimePointFormat} eq 'week' ) {
                    $Time = $Search{ArticleCreateTimePoint} * 60 * 24 * 7;
                }
                elsif ( $Search{ArticleCreateTimePointFormat} eq 'month' ) {
                    $Time = $Search{ArticleCreateTimePoint} * 60 * 24 * 30;
                }
                elsif ( $Search{ArticleCreateTimePointFormat} eq 'year' ) {
                    $Time = $Search{ArticleCreateTimePoint} * 60 * 24 * 365;
                }
                if ( $Search{ArticleCreateTimePointStart} eq 'Before' ) {
                    $Search{ArticleCreateTimeOlderMinutes} = $Time;
                }
                else {
                    $Search{ArticleCreateTimeNewerMinutes} = $Time;
                }
            }
        }

        # get create time settings
        if ( !$Search{TimeSearchType} ) {

            # do nothing with time stuff
        }
        elsif ( $Search{TimeSearchType} eq 'TimeSlot' ) {
            for my $Key (qw(Month Day)) {
                $Search{"TicketCreateTimeStart$Key"}
                    = sprintf( "%02d", $Search{"TicketCreateTimeStart$Key"} );
                $Search{"TicketCreateTimeStop$Key"}
                    = sprintf( "%02d", $Search{"TicketCreateTimeStop$Key"} );
            }
            if (
                $Search{TicketCreateTimeStartDay}
                && $Search{TicketCreateTimeStartMonth}
                && $Search{TicketCreateTimeStartYear}
                )
            {
                $Search{TicketCreateTimeNewerDate}
                    = $Search{TicketCreateTimeStartYear} . '-'
                    . $Search{TicketCreateTimeStartMonth} . '-'
                    . $Search{TicketCreateTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $Search{TicketCreateTimeStopDay}
                && $Search{TicketCreateTimeStopMonth}
                && $Search{TicketCreateTimeStopYear}
                )
            {
                $Search{TicketCreateTimeOlderDate}
                    = $Search{TicketCreateTimeStopYear} . '-'
                    . $Search{TicketCreateTimeStopMonth} . '-'
                    . $Search{TicketCreateTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $Search{TimeSearchType} eq 'TimePoint' ) {
            if (
                $Search{TicketCreateTimePoint}
                && $Search{TicketCreateTimePointStart}
                && $Search{TicketCreateTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $Search{TicketCreateTimePointFormat} eq 'minute' ) {
                    $Time = $Search{TicketCreateTimePoint};
                }
                elsif ( $Search{TicketCreateTimePointFormat} eq 'hour' ) {
                    $Time = $Search{TicketCreateTimePoint} * 60;
                }
                elsif ( $Search{TicketCreateTimePointFormat} eq 'day' ) {
                    $Time = $Search{TicketCreateTimePoint} * 60 * 24;
                }
                elsif ( $Search{TicketCreateTimePointFormat} eq 'week' ) {
                    $Time = $Search{TicketCreateTimePoint} * 60 * 24 * 7;
                }
                elsif ( $Search{TicketCreateTimePointFormat} eq 'month' ) {
                    $Time = $Search{TicketCreateTimePoint} * 60 * 24 * 30;
                }
                elsif ( $Search{TicketCreateTimePointFormat} eq 'year' ) {
                    $Time = $Search{TicketCreateTimePoint} * 60 * 24 * 365;
                }
                if ( $Search{TicketCreateTimePointStart} eq 'Before' ) {
                    $Search{TicketCreateTimeOlderMinutes} = $Time;
                }
                else {
                    $Search{TicketCreateTimeNewerMinutes} = $Time;
                }
            }
        }

        # get change time settings
        if ( !$Search{ChangeTimeSearchType} ) {

            # do nothing on time stuff
        }
        elsif ( $Search{ChangeTimeSearchType} eq 'TimeSlot' ) {
            for my $Key (qw(Month Day)) {
                $Search{"TicketChangeTimeStart$Key"}
                    = sprintf( "%02d", $Search{"TicketChangeTimeStart$Key"} );
                $Search{"TicketChangeTimeStop$Key"}
                    = sprintf( "%02d", $Search{"TicketChangeTimeStop$Key"} );
            }
            if (
                $Search{TicketChangeTimeStartDay}
                && $Search{TicketChangeTimeStartMonth}
                && $Search{TicketChangeTimeStartYear}
                )
            {
                $Search{TicketChangeTimeNewerDate}
                    = $Search{TicketChangeTimeStartYear} . '-'
                    . $Search{TicketChangeTimeStartMonth} . '-'
                    . $Search{TicketChangeTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $Search{TicketChangeTimeStopDay}
                && $Search{TicketChangeTimeStopMonth}
                && $Search{TicketChangeTimeStopYear}
                )
            {
                $Search{TicketChangeTimeOlderDate}
                    = $Search{TicketChangeTimeStopYear} . '-'
                    . $Search{TicketChangeTimeStopMonth} . '-'
                    . $Search{TicketChangeTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $Search{ChangeTimeSearchType} eq 'TimePoint' ) {
            if (
                $Search{TicketChangeTimePoint}
                && $Search{TicketChangeTimePointStart}
                && $Search{TicketChangeTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $Search{TicketChangeTimePointFormat} eq 'minute' ) {
                    $Time = $Search{TicketChangeTimePoint};
                }
                elsif ( $Search{TicketChangeTimePointFormat} eq 'hour' ) {
                    $Time = $Search{TicketChangeTimePoint} * 60;
                }
                elsif ( $Search{TicketChangeTimePointFormat} eq 'day' ) {
                    $Time = $Search{TicketChangeTimePoint} * 60 * 24;
                }
                elsif ( $Search{TicketChangeTimePointFormat} eq 'week' ) {
                    $Time = $Search{TicketChangeTimePoint} * 60 * 24 * 7;
                }
                elsif ( $Search{TicketChangeTimePointFormat} eq 'month' ) {
                    $Time = $Search{TicketChangeTimePoint} * 60 * 24 * 30;
                }
                elsif ( $Search{TicketChangeTimePointFormat} eq 'year' ) {
                    $Time = $Search{TicketChangeTimePoint} * 60 * 24 * 365;
                }
                if ( $Search{TicketChangeTimePointStart} eq 'Before' ) {
                    $Search{TicketChangeTimeOlderMinutes} = $Time;
                }
                else {
                    $Search{TicketChangeTimeNewerMinutes} = $Time;
                }
            }
        }

        # get close time settings
        if ( !$Search{CloseTimeSearchType} ) {

            # do nothing on time stuff
        }
        elsif ( $Search{CloseTimeSearchType} eq 'TimeSlot' ) {
            for my $Key (qw(Month Day)) {
                $Search{"TicketCloseTimeStart$Key"}
                    = sprintf( "%02d", $Search{"TicketCloseTimeStart$Key"} );
                $Search{"TicketCloseTimeStop$Key"}
                    = sprintf( "%02d", $Search{"TicketCloseTimeStop$Key"} );
            }
            if (
                $Search{TicketCloseTimeStartDay}
                && $Search{TicketCloseTimeStartMonth}
                && $Search{TicketCloseTimeStartYear}
                )
            {
                $Search{TicketCloseTimeNewerDate}
                    = $Search{TicketCloseTimeStartYear} . '-'
                    . $Search{TicketCloseTimeStartMonth} . '-'
                    . $Search{TicketCloseTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $Search{TicketCloseTimeStopDay}
                && $Search{TicketCloseTimeStopMonth}
                && $Search{TicketCloseTimeStopYear}
                )
            {
                $Search{TicketCloseTimeOlderDate}
                    = $Search{TicketCloseTimeStopYear} . '-'
                    . $Search{TicketCloseTimeStopMonth} . '-'
                    . $Search{TicketCloseTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $Search{CloseTimeSearchType} eq 'TimePoint' ) {
            if (
                $Search{TicketCloseTimePoint}
                && $Search{TicketCloseTimePointStart}
                && $Search{TicketCloseTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $Search{TicketCloseTimePointFormat} eq 'minute' ) {
                    $Time = $Search{TicketCloseTimePoint};
                }
                elsif ( $Search{TicketCloseTimePointFormat} eq 'hour' ) {
                    $Time = $Search{TicketCloseTimePoint} * 60;
                }
                elsif ( $Search{TicketCloseTimePointFormat} eq 'day' ) {
                    $Time = $Search{TicketCloseTimePoint} * 60 * 24;
                }
                elsif ( $Search{TicketCloseTimePointFormat} eq 'week' ) {
                    $Time = $Search{TicketCloseTimePoint} * 60 * 24 * 7;
                }
                elsif ( $Search{TicketCloseTimePointFormat} eq 'month' ) {
                    $Time = $Search{TicketCloseTimePoint} * 60 * 24 * 30;
                }
                elsif ( $Search{TicketCloseTimePointFormat} eq 'year' ) {
                    $Time = $Search{TicketCloseTimePoint} * 60 * 24 * 365;
                }
                if ( $Search{TicketCloseTimePointStart} eq 'Before' ) {
                    $Search{TicketCloseTimeOlderMinutes} = $Time;
                }
                else {
                    $Search{TicketCloseTimeNewerMinutes} = $Time;
                }
            }
        }

        # get pending time settings
        if ( !$Search{PendingTimeSearchType} ) {

            # do nothing on time stuff
        }
        elsif ( $Search{PendingTimeSearchType} eq 'TimeSlot' ) {
            for (qw(Month Day)) {
                $Search{"TicketPendingTimeStart$_"}
                    = sprintf( "%02d", $Search{"TicketPendingTimeStart$_"} );
            }
            for (qw(Month Day)) {
                $Search{"TicketPendingTimeStop$_"}
                    = sprintf( "%02d", $Search{"TicketPendingTimeStop$_"} );
            }
            if (
                $Search{TicketPendingTimeStartDay}
                && $Search{TicketPendingTimeStartMonth}
                && $Search{TicketPendingTimeStartYear}
                )
            {
                $Search{TicketPendingTimeNewerDate}
                    = $Search{TicketPendingTimeStartYear} . '-'
                    . $Search{TicketPendingTimeStartMonth} . '-'
                    . $Search{TicketPendingTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $Search{TicketPendingTimeStopDay}
                && $Search{TicketPendingTimeStopMonth}
                && $Search{TicketPendingTimeStopYear}
                )
            {
                $Search{TicketPendingTimeOlderDate}
                    = $Search{TicketPendingTimeStopYear} . '-'
                    . $Search{TicketPendingTimeStopMonth} . '-'
                    . $Search{TicketPendingTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $Search{PendingTimeSearchType} eq 'TimePoint' ) {
            if (
                $Search{TicketPendingTimePoint}
                && $Search{TicketPendingTimePointStart}
                && $Search{TicketPendingTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $Search{TicketPendingTimePointFormat} eq 'minute' ) {
                    $Time = $Search{TicketPendingTimePoint};
                }
                elsif ( $Search{TicketPendingTimePointFormat} eq 'hour' ) {
                    $Time = $Search{TicketPendingTimePoint} * 60;
                }
                elsif ( $Search{TicketPendingTimePointFormat} eq 'day' ) {
                    $Time = $Search{TicketPendingTimePoint} * 60 * 24;
                }
                elsif ( $Search{TicketPendingTimePointFormat} eq 'week' ) {
                    $Time = $Search{TicketPendingTimePoint} * 60 * 24 * 7;
                }
                elsif ( $Search{TicketPendingTimePointFormat} eq 'month' ) {
                    $Time = $Search{TicketPendingTimePoint} * 60 * 24 * 30;
                }
                elsif ( $Search{TicketPendingTimePointFormat} eq 'year' ) {
                    $Time = $Search{TicketPendingTimePoint} * 60 * 24 * 365;
                }
                if ( $Search{TicketPendingTimePointStart} eq 'Before' ) {
                    $Search{TicketPendingTimeOlderMinutes} = $Time;
                }
                else {
                    $Search{TicketPendingTimeOlderMinutes} = 0;
                    $Search{TicketPendingTimeNewerMinutes} = $Time;
                }
            }
        }

        # get escalation time settings
        if ( !$Search{EscalationTimeSearchType} ) {

            # do nothing on time stuff
        }
        elsif ( $Search{EscalationTimeSearchType} eq 'TimeSlot' ) {
            for my $Key (qw(Month Day)) {
                $Search{"TicketEscalationTimeStart$Key"}
                    = sprintf( "%02d", $Search{"TicketEscalationTimeStart$Key"} );
                $Search{"TicketEscalationTimeStop$Key"}
                    = sprintf( "%02d", $Search{"TicketEscalationTimeStop$Key"} );
            }
            if (
                $Search{TicketEscalationTimeStartDay}
                && $Search{TicketEscalationTimeStartMonth}
                && $Search{TicketEscalationTimeStartYear}
                )
            {
                $Search{TicketEscalationTimeNewerDate}
                    = $Search{TicketEscalationTimeStartYear} . '-'
                    . $Search{TicketEscalationTimeStartMonth} . '-'
                    . $Search{TicketEscalationTimeStartDay}
                    . ' 00:00:00';
            }
            if (
                $Search{TicketEscalationTimeStopDay}
                && $Search{TicketEscalationTimeStopMonth}
                && $Search{TicketEscalationTimeStopYear}
                )
            {
                $Search{TicketEscalationTimeOlderDate}
                    = $Search{TicketEscalationTimeStopYear} . '-'
                    . $Search{TicketEscalationTimeStopMonth} . '-'
                    . $Search{TicketEscalationTimeStopDay}
                    . ' 23:59:59';
            }
        }
        elsif ( $Search{EscalationTimeSearchType} eq 'TimePoint' ) {
            if (
                $Search{TicketEscalationTimePoint}
                && $Search{TicketEscalationTimePointStart}
                && $Search{TicketEscalationTimePointFormat}
                )
            {
                my $Time = 0;
                if ( $Search{TicketEscalationTimePointFormat} eq 'minute' ) {
                    $Time = $Search{TicketEscalationTimePoint};
                }
                elsif ( $Search{TicketEscalationTimePointFormat} eq 'hour' ) {
                    $Time = $Search{TicketEscalationTimePoint} * 60;
                }
                elsif ( $Search{TicketEscalationTimePointFormat} eq 'day' ) {
                    $Time = $Search{TicketEscalationTimePoint} * 60 * 24;
                }
                elsif ( $Search{TicketEscalationTimePointFormat} eq 'week' ) {
                    $Time = $Search{TicketEscalationTimePoint} * 60 * 24 * 7;
                }
                elsif ( $Search{TicketEscalationTimePointFormat} eq 'month' ) {
                    $Time = $Search{TicketEscalationTimePoint} * 60 * 24 * 30;
                }
                elsif ( $Search{TicketEscalationTimePointFormat} eq 'year' ) {
                    $Time = $Search{TicketEscalationTimePoint} * 60 * 24 * 365;
                }
                if ( $Search{TicketEscalationTimePointStart} eq 'Before' ) {
                    $Search{TicketEscalationTimeOlderMinutes} = $Time;
                }
                else {
                    $Search{TicketEscalationTimeNewerMinutes} = $Time;
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
        elsif ( defined $Search{SearchInArchive} && $Search{SearchInArchive} eq 'ArchivedTickets' )
        {
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

        my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;
        @ViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Filter }->{Search} },
            %ColumnFilter,
            Limit  => $Start + 50,
            Result => 'ARRAY',
        );

        push @ViewableQueueIDs, 0;

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
            )
        {
            $Permission = $Config->{IndividualViewPermission}->{$TmpSelQueueID};
        }

        # "unlocked" shows all tickets; "all" observes lock state
        # this names are used due to OTRS compatibility
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

        my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;
        @ViewableTickets = $TicketObject->TicketSearch(
            %{ $Filters{ $Filter }->{Search} },
            %ColumnFilter,
            Limit  => $Start + 50,
            Result => 'ARRAY',
        );
        push @ViewableQueueIDs, 0;
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
            )
        {
            $Permission = $Config->{IndividualViewPermission}->{$TmpSelQueueID};
        }

        # "unlocked" shows all tickets; "all" observes lock state
        # this names are used due to OTRS compatibility
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

        my $Start = $ParamObject->GetParam( Param => 'StartHit' ) || 1;
        @ViewableTickets = $TicketObject->TicketSearchOR(
            %{ $Filters{ $Filter }->{SearchOR} },
            Limit  => $Start + 50,
            Result => 'ARRAY',
        );
        push @ViewableQueueIDs, 0;
    }

    # EO KIX4OTRS-capeIT

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
        my $StoredFilters = \%ColumnFilter;

        my $StoredFiltersKey = 'UserStoredFilterColumns-' . $Self->{Action};
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $StoredFiltersKey,
            Value  => $JSONObject->Encode( Data => $StoredFilters ),
        );
    }

    my $CountTotal = 0;
    my %NavBarFilter;
    for my $FilterColumn ( sort keys %Filters ) {
        my $Count = 0;
        if (@ViewableQueueIDs) {

            # KIX4OTRS-capeIT
            if ( $Filters{$Filter}->{SearchOR} ) {
                $Count = $TicketObject->TicketSearchOR(
                    %{ $Filters{$FilterColumn}->{SearchOR} },
                    %ColumnFilter,
                    Result => 'COUNT',
                );
            }
            else {

                # EO KIX4OTRS-capeIT
                $Count = $TicketObject->TicketSearch(
                    %{ $Filters{$FilterColumn}->{Search} },
                    %ColumnFilter,
                    Result => 'COUNT',
                );

                # KIX4OTRS-capeIT
            }

            # EO KIX4OTRS-capeIT
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
            . '=' . $LayoutObject->Ascii2Html( Text => $GetColumnFilter{$ColumnName} )
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
        QueueIDs     => \@ViewableQueueIDs,
        Filter       => $Filter,
        UseSubQueues => $UseSubQueues,

        # KIX4OTRS-capeIT
        ViewableLockIDs  => \@ViewableLockIDs,
        ViewableStateIDs => \@ViewableStateIDs,

        # EO KIX4OTRS-capeIT
    );

    my $SubQueueIndicatorTitle = '';
    if ( !$Config->{UseSubQueues} && $UseSubQueues ) {
        $SubQueueIndicatorTitle = ' (' . $LayoutObject->{LanguageObject}->Translate('including subqueues') . ')';
    }
    elsif ( $Config->{UseSubQueues} && !$UseSubQueues ) {
        $SubQueueIndicatorTitle = ' (' . $LayoutObject->{LanguageObject}->Translate('excluding subqueues') . ')';
    }

    # show tickets
    # KIX4OTRS-capeIT
    # $Output .= $LayoutObject->TicketListShow(
    my $TicketList = $LayoutObject->TicketListShow(

        # EO KIX4OTRS-capeIT
        Filter     => $Filter,
        Filters    => \%NavBarFilter,
        FilterLink => $LinkFilter,

        # KIX4OTRS-capeIT
        # DataInTheMiddle => $LayoutObject->Output(
        #     TemplateFile => 'AgentTicketQueue',
        #     Data         => \%NavBar,
        # ),
        # EO KIX4OTRS-capeIT

        TicketIDs => \@ViewableTickets,

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
        Output => 1,

        # KIX4OTRS-capeIT
        Output             => 1,
        DynamicFieldConfig => $Self->{DynamicField},

        #        ),
        # EO KIX4OTRS-capeIT
    );

    # KIX4OTRS-capeIT
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketQueue' . $Self->{UserPreferences}->{UserQueueViewLayout},
        Data => { %NavBar, TicketList => $TicketList }
    );

    # EO KIX4OTRS-capeIT

    # get page footer
    $Output .= $LayoutObject->Footer() if $Self->{Subaction} ne 'AJAXFilterUpdate';
    return $Output;
}

sub BuildQueueView {
    my ( $Self, %Param ) = @_;

    # KIX4OTRS-capeIT
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

    # EO KIX4OTRS-capeIT

    my %Data = $Kernel::OM->Get('Kernel::System::Ticket')->TicketAcceleratorIndex(
        UserID        => $Self->{UserID},
        QueueID       => $Self->{QueueID},
        ShownQueueIDs => $Param{QueueIDs},

        # KIX4OTRS-capeIT
        Filter          => $Param{Filter},
        ViewableLockIDs => \@ViewableLockIDs,

        # EO KIX4OTRS-capeIT
    );

    # KIX4OTRS-capeIT
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

            # get create time settings
            if ( !$SearchProfileData{ArticleTimeSearchType} ) {

                # do nothing with time stuff
            }
            elsif ( $SearchProfileData{ArticleTimeSearchType} eq 'TimeSlot' ) {
                for my $Key (qw(Month Day)) {
                    $SearchProfileData{"ArticleCreateTimeStart$Key"}
                        = sprintf( "%02d", $SearchProfileData{"ArticleCreateTimeStart$Key"} );
                    $SearchProfileData{"ArticleCreateTimeStop$Key"}
                        = sprintf( "%02d", $SearchProfileData{"ArticleCreateTimeStop$Key"} );
                }
                if (
                    $SearchProfileData{ArticleCreateTimeStartDay}
                    && $SearchProfileData{ArticleCreateTimeStartMonth}
                    && $SearchProfileData{ArticleCreateTimeStartYear}
                    )
                {
                    $SearchProfileData{ArticleCreateTimeNewerDate}
                        = $SearchProfileData{ArticleCreateTimeStartYear} . '-'
                        . $SearchProfileData{ArticleCreateTimeStartMonth} . '-'
                        . $SearchProfileData{ArticleCreateTimeStartDay}
                        . ' 00:00:00';
                }
                if (
                    $SearchProfileData{ArticleCreateTimeStopDay}
                    && $SearchProfileData{ArticleCreateTimeStopMonth}
                    && $SearchProfileData{ArticleCreateTimeStopYear}
                    )
                {
                    $SearchProfileData{ArticleCreateTimeOlderDate}
                        = $SearchProfileData{ArticleCreateTimeStopYear} . '-'
                        . $SearchProfileData{ArticleCreateTimeStopMonth} . '-'
                        . $SearchProfileData{ArticleCreateTimeStopDay}
                        . ' 23:59:59';
                }
            }
            elsif ( $SearchProfileData{ArticleTimeSearchType} eq 'TimePoint' ) {
                if (
                    $SearchProfileData{ArticleCreateTimePoint}
                    && $SearchProfileData{ArticleCreateTimePointStart}
                    && $SearchProfileData{ArticleCreateTimePointFormat}
                    )
                {
                    my $Time = 0;
                    if ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'minute' ) {
                        $Time = $SearchProfileData{ArticleCreateTimePoint};
                    }
                    elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'hour' ) {
                        $Time = $SearchProfileData{ArticleCreateTimePoint} * 60;
                    }
                    elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'day' ) {
                        $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24;
                    }
                    elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'week' ) {
                        $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24 * 7;
                    }
                    elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'month' ) {
                        $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24 * 30;
                    }
                    elsif ( $SearchProfileData{ArticleCreateTimePointFormat} eq 'year' ) {
                        $Time = $SearchProfileData{ArticleCreateTimePoint} * 60 * 24 * 365;
                    }
                    if ( $SearchProfileData{ArticleCreateTimePointStart} eq 'Before' ) {
                        $SearchProfileData{ArticleCreateTimeOlderMinutes} = $Time;
                    }
                    else {
                        $SearchProfileData{ArticleCreateTimeNewerMinutes} = $Time;
                    }
                }
            }

            # get create time settings
            if ( !$SearchProfileData{TimeSearchType} ) {

                # do nothing with time stuff
            }
            elsif ( $SearchProfileData{TimeSearchType} eq 'TimeSlot' ) {
                for my $Key (qw(Month Day)) {
                    $SearchProfileData{"TicketCreateTimeStart$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketCreateTimeStart$Key"} );
                    $SearchProfileData{"TicketCreateTimeStop$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketCreateTimeStop$Key"} );
                }
                if (
                    $SearchProfileData{TicketCreateTimeStartDay}
                    && $SearchProfileData{TicketCreateTimeStartMonth}
                    && $SearchProfileData{TicketCreateTimeStartYear}
                    )
                {
                    $SearchProfileData{TicketCreateTimeNewerDate}
                        = $SearchProfileData{TicketCreateTimeStartYear} . '-'
                        . $SearchProfileData{TicketCreateTimeStartMonth} . '-'
                        . $SearchProfileData{TicketCreateTimeStartDay}
                        . ' 00:00:00';
                }
                if (
                    $SearchProfileData{TicketCreateTimeStopDay}
                    && $SearchProfileData{TicketCreateTimeStopMonth}
                    && $SearchProfileData{TicketCreateTimeStopYear}
                    )
                {
                    $SearchProfileData{TicketCreateTimeOlderDate}
                        = $SearchProfileData{TicketCreateTimeStopYear} . '-'
                        . $SearchProfileData{TicketCreateTimeStopMonth} . '-'
                        . $SearchProfileData{TicketCreateTimeStopDay}
                        . ' 23:59:59';
                }
            }

            elsif ( $SearchProfileData{TimeSearchType} eq 'TimePoint' ) {
                if (
                    $SearchProfileData{TicketCreateTimePoint}
                    && $SearchProfileData{TicketCreateTimePointStart}
                    && $SearchProfileData{TicketCreateTimePointFormat}
                    )
                {
                    my $Time = 0;
                    if ( $SearchProfileData{TicketCreateTimePointFormat} eq 'minute' ) {
                        $Time = $SearchProfileData{TicketCreateTimePoint};
                    }
                    elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'hour' ) {
                        $Time = $SearchProfileData{TicketCreateTimePoint} * 60;
                    }
                    elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'day' ) {
                        $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24;
                    }
                    elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'week' ) {
                        $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24 * 7;
                    }
                    elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'month' ) {
                        $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24 * 30;
                    }
                    elsif ( $SearchProfileData{TicketCreateTimePointFormat} eq 'year' ) {
                        $Time = $SearchProfileData{TicketCreateTimePoint} * 60 * 24 * 365;
                    }
                    if ( $SearchProfileData{TicketCreateTimePointStart} eq 'Before' ) {
                        $SearchProfileData{TicketCreateTimeOlderMinutes} = $Time;
                    }
                    else {
                        $SearchProfileData{TicketCreateTimeNewerMinutes} = $Time;
                    }
                }
            }

            # get change time settings
            if ( !$SearchProfileData{ChangeTimeSearchType} ) {

                # do nothing on time stuff
            }
            elsif ( $SearchProfileData{ChangeTimeSearchType} eq 'TimeSlot' ) {
                for my $Key (qw(Month Day)) {
                    $SearchProfileData{"TicketChangeTimeStart$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketChangeTimeStart$Key"} );
                    $SearchProfileData{"TicketChangeTimeStop$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketChangeTimeStop$Key"} );
                }
                if (
                    $SearchProfileData{TicketChangeTimeStartDay}
                    && $SearchProfileData{TicketChangeTimeStartMonth}
                    && $SearchProfileData{TicketChangeTimeStartYear}
                    )
                {
                    $SearchProfileData{TicketChangeTimeNewerDate}
                        = $SearchProfileData{TicketChangeTimeStartYear} . '-'
                        . $SearchProfileData{TicketChangeTimeStartMonth} . '-'
                        . $SearchProfileData{TicketChangeTimeStartDay}
                        . ' 00:00:00';
                }
                if (
                    $SearchProfileData{TicketChangeTimeStopDay}
                    && $SearchProfileData{TicketChangeTimeStopMonth}
                    && $SearchProfileData{TicketChangeTimeStopYear}
                    )
                {
                    $SearchProfileData{TicketChangeTimeOlderDate}
                        = $SearchProfileData{TicketChangeTimeStopYear} . '-'
                        . $SearchProfileData{TicketChangeTimeStopMonth} . '-'
                        . $SearchProfileData{TicketChangeTimeStopDay}
                        . ' 23:59:59';
                }
            }
            elsif ( $SearchProfileData{ChangeTimeSearchType} eq 'TimePoint' ) {
                if (
                    $SearchProfileData{TicketChangeTimePoint}
                    && $SearchProfileData{TicketChangeTimePointStart}
                    && $SearchProfileData{TicketChangeTimePointFormat}
                    )
                {
                    my $Time = 0;
                    if ( $SearchProfileData{TicketChangeTimePointFormat} eq 'minute' ) {
                        $Time = $SearchProfileData{TicketChangeTimePoint};
                    }
                    elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'hour' ) {
                        $Time = $SearchProfileData{TicketChangeTimePoint} * 60;
                    }
                    elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'day' ) {
                        $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24;
                    }
                    elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'week' ) {
                        $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24 * 7;
                    }
                    elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'month' ) {
                        $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24 * 30;
                    }
                    elsif ( $SearchProfileData{TicketChangeTimePointFormat} eq 'year' ) {
                        $Time = $SearchProfileData{TicketChangeTimePoint} * 60 * 24 * 365;
                    }
                    if ( $SearchProfileData{TicketChangeTimePointStart} eq 'Before' ) {
                        $SearchProfileData{TicketChangeTimeOlderMinutes} = $Time;
                    }
                    else {
                        $SearchProfileData{TicketChangeTimeNewerMinutes} = $Time;
                    }
                }
            }

            # get close time settings
            if ( !$SearchProfileData{CloseTimeSearchType} ) {

                # do nothing on time stuff
            }
            elsif ( $SearchProfileData{CloseTimeSearchType} eq 'TimeSlot' ) {
                for my $Key (qw(Month Day)) {
                    $SearchProfileData{"TicketCloseTimeStart$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketCloseTimeStart$Key"} );
                    $SearchProfileData{"TicketCloseTimeStop$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketCloseTimeStop$Key"} );
                }
                if (
                    $SearchProfileData{TicketCloseTimeStartDay}
                    && $SearchProfileData{TicketCloseTimeStartMonth}
                    && $SearchProfileData{TicketCloseTimeStartYear}
                    )
                {
                    $SearchProfileData{TicketCloseTimeNewerDate}
                        = $SearchProfileData{TicketCloseTimeStartYear} . '-'
                        . $SearchProfileData{TicketCloseTimeStartMonth} . '-'
                        . $SearchProfileData{TicketCloseTimeStartDay}
                        . ' 00:00:00';
                }
                if (
                    $SearchProfileData{TicketCloseTimeStopDay}
                    && $SearchProfileData{TicketCloseTimeStopMonth}
                    && $SearchProfileData{TicketCloseTimeStopYear}
                    )
                {
                    $SearchProfileData{TicketCloseTimeOlderDate}
                        = $SearchProfileData{TicketCloseTimeStopYear} . '-'
                        . $SearchProfileData{TicketCloseTimeStopMonth} . '-'
                        . $SearchProfileData{TicketCloseTimeStopDay}
                        . ' 23:59:59';
                }
            }
            elsif ( $SearchProfileData{CloseTimeSearchType} eq 'TimePoint' ) {
                if (
                    $SearchProfileData{TicketCloseTimePoint}
                    && $SearchProfileData{TicketCloseTimePointStart}
                    && $SearchProfileData{TicketCloseTimePointFormat}
                    )
                {
                    my $Time = 0;
                    if ( $SearchProfileData{TicketCloseTimePointFormat} eq 'minute' ) {
                        $Time = $SearchProfileData{TicketCloseTimePoint};
                    }
                    elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'hour' ) {
                        $Time = $SearchProfileData{TicketCloseTimePoint} * 60;
                    }
                    elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'day' ) {
                        $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24;
                    }
                    elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'week' ) {
                        $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24 * 7;
                    }
                    elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'month' ) {
                        $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24 * 30;
                    }
                    elsif ( $SearchProfileData{TicketCloseTimePointFormat} eq 'year' ) {
                        $Time = $SearchProfileData{TicketCloseTimePoint} * 60 * 24 * 365;
                    }
                    if ( $SearchProfileData{TicketCloseTimePointStart} eq 'Before' ) {
                        $SearchProfileData{TicketCloseTimeOlderMinutes} = $Time;
                    }
                    else {
                        $SearchProfileData{TicketCloseTimeNewerMinutes} = $Time;
                    }
                }
            }

            # KIX4OTRS-capeIT
            # get last change time settings
            if ( !$SearchProfileData{LastChangeTimeSearchType} ) {

                # do nothing on time stuff
            }
            elsif ( $SearchProfileData{LastChangeTimeSearchType} eq 'TimeSlot' ) {
                for my $Key (qw(Month Day)) {
                    $SearchProfileData{"TicketLastChangeTimeStart$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketLastChangeTimeStart$Key"} );
                    $SearchProfileData{"TicketLastChangeTimeStop$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketLastChangeTimeStop$Key"} );
                }
                if (
                    $SearchProfileData{TicketLastChangeTimeStartDay}
                    && $SearchProfileData{TicketLastChangeTimeStartMonth}
                    && $SearchProfileData{TicketLastChangeTimeStartYear}
                    )
                {
                    $SearchProfileData{TicketLastChangeTimeNewerDate}
                        = $SearchProfileData{TicketLastChangeTimeStartYear} . '-'
                        . $SearchProfileData{TicketLastChangeTimeStartMonth} . '-'
                        . $SearchProfileData{TicketLastChangeTimeStartDay}
                        . ' 00:00:00';
                }
                if (
                    $SearchProfileData{TicketLastChangeTimeStopDay}
                    && $SearchProfileData{TicketLastChangeTimeStopMonth}
                    && $SearchProfileData{TicketLastChangeTimeStopYear}
                    )
                {
                    $SearchProfileData{TicketLastChangeTimeOlderDate}
                        = $SearchProfileData{TicketLastChangeTimeStopYear} . '-'
                        . $SearchProfileData{TicketLastChangeTimeStopMonth} . '-'
                        . $SearchProfileData{TicketLastChangeTimeStopDay}
                        . ' 23:59:59';
                }
            }
            elsif ( $SearchProfileData{LastChangeTimeSearchType} eq 'TimePoint' ) {
                if (
                    $SearchProfileData{TicketLastChangeTimePoint}
                    && $SearchProfileData{TicketLastChangeTimePointStart}
                    && $SearchProfileData{TicketLastChangeTimePointFormat}
                    )
                {
                    my $Time = 0;
                    if ( $SearchProfileData{TicketLastChangeTimePointFormat} eq 'minute' ) {
                        $Time = $SearchProfileData{TicketLastChangeTimePoint};
                    }
                    elsif ( $SearchProfileData{TicketLastChangeTimePointFormat} eq 'hour' ) {
                        $Time = $SearchProfileData{TicketLastChangeTimePoint} * 60;
                    }
                    elsif ( $SearchProfileData{TicketLastChangeTimePointFormat} eq 'day' ) {
                        $Time = $SearchProfileData{TicketLastChangeTimePoint} * 60 * 24;
                    }
                    elsif ( $SearchProfileData{TicketLastChangeTimePointFormat} eq 'week' ) {
                        $Time = $SearchProfileData{TicketLastChangeTimePoint} * 60 * 24 * 7;
                    }
                    elsif ( $SearchProfileData{TicketLastChangeTimePointFormat} eq 'month' ) {
                        $Time = $SearchProfileData{TicketLastChangeTimePoint} * 60 * 24 * 30;
                    }
                    elsif ( $SearchProfileData{TicketLastChangeTimePointFormat} eq 'year' ) {
                        $Time = $SearchProfileData{TicketLastChangeTimePoint} * 60 * 24 * 365;
                    }
                    if ( $SearchProfileData{TicketLastChangeTimePointStart} eq 'Before' ) {
                        $SearchProfileData{TicketLastChangeTimeOlderMinutes} = $Time;
                    }
                    else {
                        $SearchProfileData{TicketLastChangeTimeNewerMinutes} = $Time;
                    }
                }
            }

            # get pending time settings
            if ( !$SearchProfileData{PendingTimeSearchType} ) {

                # do nothing on time stuff
            }
            elsif ( $SearchProfileData{PendingTimeSearchType} eq 'TimeSlot' ) {
                for (qw(Month Day)) {
                    $SearchProfileData{"TicketPendingTimeStart$_"}
                        = sprintf( "%02d", $SearchProfileData{"TicketPendingTimeStart$_"} );
                }
                for (qw(Month Day)) {
                    $SearchProfileData{"TicketPendingTimeStop$_"}
                        = sprintf( "%02d", $SearchProfileData{"TicketPendingTimeStop$_"} );
                }
                if (
                    $SearchProfileData{TicketPendingTimeStartDay}
                    && $SearchProfileData{TicketPendingTimeStartMonth}
                    && $SearchProfileData{TicketPendingTimeStartYear}
                    )
                {
                    $SearchProfileData{TicketPendingTimeNewerDate}
                        = $SearchProfileData{TicketPendingTimeStartYear} . '-'
                        . $SearchProfileData{TicketPendingTimeStartMonth} . '-'
                        . $SearchProfileData{TicketPendingTimeStartDay}
                        . ' 00:00:00';
                }
                if (
                    $SearchProfileData{TicketPendingTimeStopDay}
                    && $SearchProfileData{TicketPendingTimeStopMonth}
                    && $SearchProfileData{TicketPendingTimeStopYear}
                    )
                {
                    $SearchProfileData{TicketPendingTimeOlderDate}
                        = $SearchProfileData{TicketPendingTimeStopYear} . '-'
                        . $SearchProfileData{TicketPendingTimeStopMonth} . '-'
                        . $SearchProfileData{TicketPendingTimeStopDay}
                        . ' 23:59:59';
                }
            }
            elsif ( $SearchProfileData{PendingTimeSearchType} eq 'TimePoint' ) {
                if (
                    $SearchProfileData{TicketPendingTimePoint}
                    && $SearchProfileData{TicketPendingTimePointStart}
                    && $SearchProfileData{TicketPendingTimePointFormat}
                    )
                {
                    my $Time = 0;
                    if ( $SearchProfileData{TicketPendingTimePointFormat} eq 'minute' ) {
                        $Time = $SearchProfileData{TicketPendingTimePoint};
                    }
                    elsif ( $SearchProfileData{TicketPendingTimePointFormat} eq 'hour' ) {
                        $Time = $SearchProfileData{TicketPendingTimePoint} * 60;
                    }
                    elsif ( $SearchProfileData{TicketPendingTimePointFormat} eq 'day' ) {
                        $Time = $SearchProfileData{TicketPendingTimePoint} * 60 * 24;
                    }
                    elsif ( $SearchProfileData{TicketPendingTimePointFormat} eq 'week' ) {
                        $Time = $SearchProfileData{TicketPendingTimePoint} * 60 * 24 * 7;
                    }
                    elsif ( $SearchProfileData{TicketPendingTimePointFormat} eq 'month' ) {
                        $Time = $SearchProfileData{TicketPendingTimePoint} * 60 * 24 * 30;
                    }
                    elsif ( $SearchProfileData{TicketPendingTimePointFormat} eq 'year' ) {
                        $Time = $SearchProfileData{TicketPendingTimePoint} * 60 * 24 * 365;
                    }
                    if ( $SearchProfileData{TicketPendingTimePointStart} eq 'Before' ) {
                        $SearchProfileData{TicketPendingTimeOlderMinutes} = $Time;
                    }
                    else {
                        $SearchProfileData{TicketPendingTimeNewerMinutes} = $Time;
                    }
                }
            }

            # get escalation time settings
            if ( !$SearchProfileData{EscalationTimeSearchType} ) {

                # do nothing on time stuff
            }
            elsif ( $SearchProfileData{EscalationTimeSearchType} eq 'TimeSlot' ) {
                for my $Key (qw(Month Day)) {
                    $SearchProfileData{"TicketEscalationTimeStart$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketEscalationTimeStart$Key"} );
                    $SearchProfileData{"TicketEscalationTimeStop$Key"}
                        = sprintf( "%02d", $SearchProfileData{"TicketEscalationTimeStop$Key"} );
                }
                if (
                    $SearchProfileData{TicketEscalationTimeStartDay}
                    && $SearchProfileData{TicketEscalationTimeStartMonth}
                    && $SearchProfileData{TicketEscalationTimeStartYear}
                    )
                {
                    $SearchProfileData{TicketEscalationTimeNewerDate}
                        = $SearchProfileData{TicketEscalationTimeStartYear} . '-'
                        . $SearchProfileData{TicketEscalationTimeStartMonth} . '-'
                        . $SearchProfileData{TicketEscalationTimeStartDay}
                        . ' 00:00:00';
                }
                if (
                    $SearchProfileData{TicketEscalationTimeStopDay}
                    && $SearchProfileData{TicketEscalationTimeStopMonth}
                    && $SearchProfileData{TicketEscalationTimeStopYear}
                    )
                {
                    $SearchProfileData{TicketEscalationTimeOlderDate}
                        = $SearchProfileData{TicketEscalationTimeStopYear} . '-'
                        . $SearchProfileData{TicketEscalationTimeStopMonth} . '-'
                        . $SearchProfileData{TicketEscalationTimeStopDay}
                        . ' 23:59:59';
                }
            }
            elsif ( $SearchProfileData{EscalationTimeSearchType} eq 'TimePoint' ) {
                if (
                    $SearchProfileData{TicketEscalationTimePoint}
                    && $SearchProfileData{TicketEscalationTimePointStart}
                    && $SearchProfileData{TicketEscalationTimePointFormat}
                    )
                {
                    my $Time = 0;
                    if ( $SearchProfileData{TicketEscalationTimePointFormat} eq 'minute' ) {
                        $Time = $SearchProfileData{TicketEscalationTimePoint};
                    }
                    elsif ( $SearchProfileData{TicketEscalationTimePointFormat} eq 'hour' ) {
                        $Time = $SearchProfileData{TicketEscalationTimePoint} * 60;
                    }
                    elsif ( $SearchProfileData{TicketEscalationTimePointFormat} eq 'day' ) {
                        $Time = $SearchProfileData{TicketEscalationTimePoint} * 60 * 24;
                    }
                    elsif ( $SearchProfileData{TicketEscalationTimePointFormat} eq 'week' ) {
                        $Time = $SearchProfileData{TicketEscalationTimePoint} * 60 * 24 * 7;
                    }
                    elsif ( $SearchProfileData{TicketEscalationTimePointFormat} eq 'month' ) {
                        $Time = $SearchProfileData{TicketEscalationTimePoint} * 60 * 24 * 30;
                    }
                    elsif ( $SearchProfileData{TicketEscalationTimePointFormat} eq 'year' ) {
                        $Time = $SearchProfileData{TicketEscalationTimePoint} * 60 * 24 * 365;
                    }

                    if ( $SearchProfileData{TicketEscalationTimePointStart} eq 'Before' ) {
                        $SearchProfileData{TicketEscalationTimeOlderMinutes} = $Time;
                    }
                    elsif ( $SearchProfileData{TicketEscalationTimePointStart} eq 'Next' ) {
                        $SearchProfileData{TicketEscalationTimeOlderMinutes} = (-1) * $Time;
                        $SearchProfileData{TicketEscalationTimeNewerMinutes} = 0;
                    }
                    else {
                        $SearchProfileData{TicketEscalationTimeOlderMinutes} = 0;
                        $SearchProfileData{TicketEscalationTimeNewerMinutes} = $Time;
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
                )
            {
                $SearchProfileData{ArchiveFlags} = [ 'y', 'n' ];
            }
            elsif (
                defined $SearchProfileData{SearchInArchive}
                && $SearchProfileData{SearchInArchive} eq 'ArchivedTickets'
                )
            {
                $SearchProfileData{ArchiveFlags} = ['y'];
            }

            # do ticket search to get ticket count
            $Hash{Total} = $TicketObject->TicketSearch(

                # StateIDs => $Self->{ViewableStateIDs},
                # LockIDs  => \@ViewableLockIDs,
                %SearchProfileData,
                UserID          => $Self->{UserID},
                ConditionInline => 1,
                FullTextIndex   => 1,
                Result          => 'COUNT',
            ) || 0;
            $Hash{Count} = $TicketObject->TicketSearch(
                LockIDs => \@ViewableLockIDs,
                %SearchProfileData,
                UserID          => $Self->{UserID},
                ConditionInline => 1,
                FullTextIndex   => 1,
                Result          => 'COUNT',
            ) || 0;

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

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $Config       = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # show individual views
    if (
        $Config->{IndividualViews} &&
        ref( $Config->{IndividualViews} ) eq 'HASH'
        )
    {
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

    # EO KIX4OTRS-capeIT

    # build output ...
    my %AllQueues = $Kernel::OM->Get('Kernel::System::Queue')->QueueList( Valid => 0 );

    # KIX4OTRS-capeIT
    my $ViewLayoutFunction = '_MaskQueueView' . $Self->{UserPreferences}->{UserQueueViewLayout};

    # return $Self->_MaskQueueView(
    return $Self->$ViewLayoutFunction(

        # EO KIX4OTRS-capeIT

        %Data,
        QueueID         => $Self->{QueueID},
        AllQueues       => \%AllQueues,
        ViewableTickets => $Self->{ViewableTickets},

        # KIX4OTRS-capeIT
        SelectedQueue => $Param{SelectedQueue} || '',
        SelectedQueueID => $Param{SelectedQueueID},
        Filter          => $Param{Filter},

        # EO KIX4OTRS-capeIT

        UseSubQueues => $Param{UseSubQueues},
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
    my $HaveTotals = 0;    # flag for "Total" in index backend
    my %UsedQueue;
    my @ListedQueues;
    my $Level        = 0;
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $CustomQueues = $ConfigObject->Get('Ticket::CustomQueue') || '???';
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomQueue  = $LayoutObject->{LanguageObject}->Translate($CustomQueues);
    my $Config       = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");
    $Self->{HighlightAge1} = $Config->{HighlightAge1};
    $Self->{HighlightAge2} = $Config->{HighlightAge2};
    $Self->{Blink}         = $Config->{Blink};

    # KIX4OTRS-capeIT
    #    $Param{SelectedQueue} = $AllQueues{$QueueID} || $CustomQueue;
    if ( !$Param{SelectedQueue} ) {
        $Param{SelectedQueue} = $AllQueues{$QueueID} || $CustomQueue;
    }

    # EO KIX4OTRS-capeIT

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
                )
            {

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
            )
        {
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
        # KIX4OTRS
        # if ( $Queue{QueueID} == $QueueIDOfMaxAge && $Self->{Blink} ) {
        if ( $Queue{QueueID} eq $QueueIDOfMaxAge && $Self->{Blink} ) {

            # EO KIX4OTRS
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
            )
        {
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

        if ( scalar @QueueName eq 1 ) {
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

# KIX4OTRS-capeIT
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
            )
        {
            if ( defined $Param{SelectedSearchProfileQueue}
                && $Param{SelectedSearchProfileQueue} eq $1 )
            {
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
                    Count   => 0,
                    Queue   => $Queue[$_],
                    QueueID => $AllQueuesReverse{$QueueName},

                    #QueueSplit => [ $Queue[0] .. $Queue[$_] ],
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
        next
            if (
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
        if ( defined $Queue{QueueID} && $Queue{QueueID} eq $QueueIDOfMaxAge && $Self->{Blink} )
        {
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
            && $QueueName[1] eq $Param{SelectedSearchProfileQueueName} )
        {
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
                    Count   => 0,
                    Queue   => $Queue[$_],
                    QueueID => $AllQueuesReverse{$QueueName},

                    #QueueSplit => [ $Queue[0] .. $Queue[$_] ],
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

# EO KIX4OTRS-capeIT

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
