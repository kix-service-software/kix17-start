# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketArticleFlagView;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON');
    my $StateObject   = $Kernel::OM->Get('Kernel::System::State');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    my $SortBy = $ParamObject->GetParam( Param => 'SortBy' )
        || $Config->{'SortBy::Default'}
        || 'Age';
    my $OrderBy = $ParamObject->GetParam( Param => 'OrderBy' )
        || $Config->{'Order::Default'}
        || 'Up';

    my $ArticleFlag = $ParamObject->GetParam( Param => 'ArticleFlag' );

    # create URL to store last screen
    my $URL = "Action=AgentTicketArticleFlagView;"
        . ";ArticleFlag="   . $LayoutObject->LinkEncode( $ArticleFlag )
        . ";View="          . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'View')        || '' )
        . ";Filter="        . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'Filter')      || '' )
        . ";SortBy="        . $LayoutObject->LinkEncode( $SortBy )
        . ";OrderBy="       . $LayoutObject->LinkEncode( $OrderBy )
        . ";StartHit="      . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'StartHit')    || '')
        . ";StartWindow="   . $LayoutObject->LinkEncode( $ParamObject->GetParam(Param => 'StartWindow') || 0);

    # store last screen
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $URL,
    );

    # store last overview screen
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenOverview',
        Value     => $URL,
    );

    # get filters stored in the user preferences
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );
    my $StoredFiltersKey = 'UserStoredFilterColumns-' . $Self->{Action};
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
            $GetColumnFilter{$ColumnName} = $FilterValue;
        }
        elsif ( $ColumnName eq 'CustomerUserID' ) {
            push @{ $ColumnFilter{CustomerUserLogin} }, $FilterValue;
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

    # starting with page ...
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

    # get locked  viewable tickets...
    my $SortByS = $SortBy;
    if ( $SortByS eq 'CreateTime' ) {
        $SortByS = 'Age';
    }

    # get pending states
    my @PendingAutoStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingAuto',
        Result => 'ID',
    );
    my @PendingReminderStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingReminder',
        Result => 'ID',
    );
    my @PendingsStateIDs = (@PendingAutoStateIDs, @PendingReminderStateIDs);

    my %Filters = (
        All => {
            Name   => 'All',
            Prio   => 1000,
            Search => {
                ArticleFlag => $ArticleFlag,
                OrderBy     => $OrderBy,
                SortBy      => $SortByS,
                UserID      => $Self->{UserID},
                Permission  => 'ro',
            },
        },
        New => {
            Name   => 'New Article',
            Prio   => 1001,
            Search => {
                ArticleFlag   => $ArticleFlag,
                NotTicketFlag => {
                    Seen => 1,
                },
                TicketFlagUserID => $Self->{UserID},
                OrderBy          => $OrderBy,
                SortBy           => $SortByS,
                UserID           => $Self->{UserID},
                Permission       => 'ro',
            },
        },
        Reminder => {
            Name   => 'Pending',
            Prio   => 1002,
            Search => {
                ArticleFlag => $ArticleFlag,
                StateIDs    => \@PendingsStateIDs,
                OrderBy     => $OrderBy,
                SortBy      => $SortByS,
                UserID      => $Self->{UserID},
                Permission  => 'ro',
            },
        },
        ReminderReached => {
            Name   => 'Reminder Reached',
            Prio   => 1003,
            Search => {
                ArticleFlag                   => $ArticleFlag,
                StateIDs                      => \@PendingReminderStateIDs,
                TicketPendingTimeOlderMinutes => 1,
                OrderBy                       => $OrderBy,
                SortBy                        => $SortByS,
                UserID                        => $Self->{UserID},
                Permission                    => 'ro',
            },
        },
    );

    my $Filter = $ParamObject->GetParam( Param => 'Filter' ) || 'All';

    # check if filter is valid
    if ( !$Filters{$Filter} ) {
        $LayoutObject->FatalError( Message => "Invalid Filter: $Filter!" );
    }

    # do shown tickets lookup
    my $Limit = 10_000;

    my $ElementChanged = $ParamObject->GetParam( Param => 'ElementChanged' ) || '';
    my $HeaderColumn = $ElementChanged;
    $HeaderColumn =~ s{\A ColumnFilter }{}msxg;
    my @OriginalViewableTickets;
    my @ViewableTickets;
    my $ViewableTicketCount = 0;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

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
        if (
            !defined( $Filters{ $Filter }->{Search}->{StateIDs} )
            || IsArrayRefWithData( $Filters{ $Filter }->{Search}->{StateIDs} )
        ) {
            @OriginalViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                Limit  => $Limit,
                Result => 'ARRAY',
            );

            @ViewableTickets = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                %ColumnFilter,
                Result => 'ARRAY',
                Limit  => 1_000,
            );
        }
    }

    my $View = $ParamObject->GetParam( Param => 'View' ) || '';

    if ( $Self->{Subaction} eq 'AJAXFilterUpdate' ) {

        my $FilterContent = $LayoutObject->TicketListShow(
            FilterContentOnly   => 1,
            HeaderColumn        => $HeaderColumn,
            ElementChanged      => $ElementChanged,
            OriginalTicketIDs   => \@OriginalViewableTickets,
            Action              => 'AgentTicketStatusView',
            Env                 => $Self,
            View                => $View,
            EnableColumnFilters => 1,
        );

        if ( !$FilterContent ) {
            $LayoutObject->FatalError(
                Message => "Can't get filter content data of $HeaderColumn!",
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

    if ( $ViewableTicketCount > $Limit ) {
        $ViewableTicketCount = $Limit;
    }

    my %NavBarFilter;
    for my $Filter ( sort keys %Filters ) {
        my $Count = 0;
        if (
            !defined( $Filters{ $Filter }->{Search}->{StateIDs} )
            || IsArrayRefWithData( $Filters{ $Filter }->{Search}->{StateIDs} )
        ) {
            $Count = $TicketObject->TicketSearch(
                %{ $Filters{$Filter}->{Search} },
                %ColumnFilter,
                Result => 'COUNT',
            );
        }

        $NavBarFilter{ $Filters{$Filter}->{Prio} } = {
            Count  => $Count,
            Filter => $Filter,
            %{ $Filters{$Filter} },
            %ColumnFilter,
        };
    }

    my $ColumnFilterLink = '';
    COLUMNNAME:
    for my $ColumnName ( sort keys %GetColumnFilter ) {
        next COLUMNNAME if !$ColumnName;
        next COLUMNNAME if !$GetColumnFilter{$ColumnName};
        $ColumnFilterLink
            .= ';' . $LayoutObject->Ascii2Html( Text => 'ColumnFilter' . $ColumnName )
            . '=' . $LayoutObject->Ascii2Html( Text => $GetColumnFilter{$ColumnName} )
    }

    # show ticket's
    my $LinkPage = 'Filter='
        . $LayoutObject->Ascii2Html( Text => $Filter )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
        . ';SortBy=' . $LayoutObject->Ascii2Html( Text => $SortBy )
        . ';OrderBy=' . $LayoutObject->Ascii2Html( Text => $OrderBy )
        . ';ArticleFlag=' . $LayoutObject->Ascii2Html( Text => $ArticleFlag )
        . $ColumnFilterLink
        . ';';
    my $LinkSort = 'Filter='
        . $LayoutObject->Ascii2Html( Text => $Filter )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
        . ';ArticleFlag=' . $LayoutObject->Ascii2Html( Text => $ArticleFlag )
        . $ColumnFilterLink
        . ';';
    my $LinkFilter = 'SortBy=' . $LayoutObject->Ascii2Html( Text => $SortBy )
        . ';OrderBy=' . $LayoutObject->Ascii2Html( Text => $OrderBy )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $View )
        . ';ArticleFlag=' . $LayoutObject->Ascii2Html( Text => $ArticleFlag )
        . ';';
    my $LastColumnFilter = $ParamObject->GetParam( Param => 'LastColumnFilter' ) || '';

    if ( !$LastColumnFilter && $ColumnFilterLink ) {

        # is planned to have a link to go back here
        $LastColumnFilter = 1;
    }

    $Output .= $LayoutObject->TicketListShow(
        TicketIDs           => \@ViewableTickets,
        OriginalTicketIDs   => \@OriginalViewableTickets,
        GetColumnFilter     => \%GetColumnFilter,
        LastColumnFilter    => $LastColumnFilter,
        Action              => 'AgentTicketLockedView',
        RequestedURL        => $Self->{RequestedURL},
        Total               => scalar @ViewableTickets,
        View                => $View,
        Filter              => $Filter,
        Filters             => \%NavBarFilter,
        TitleName           => 'My Flagged Tickets',
        TitleValue          => $Filters{$Filter}->{Name},
        Bulk                => 1,
        Env                 => $Self,
        LinkPage            => $LinkPage,
        LinkSort            => $LinkSort,
        LinkFilter          => $LinkFilter,
        OrderBy             => $OrderBy,
        SortBy              => $SortBy,
        EnableColumnFilters => 1,
        ColumnFilterForm    => {
            ArticleFlag => $ArticleFlag || '',
            Filter      => $Filter      || '',
        },
        Output => 1, # do not print the result earlier, but return complete content
    );

    # get page footer
    $Output .= $LayoutObject->Footer();
    return $Output;
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
