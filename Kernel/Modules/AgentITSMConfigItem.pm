# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItem;

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

    # get config of frontend module
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get("ITSMConfigItem::Frontend::$Self->{Action}");

    # get config data
    $Self->{SearchLimit} = $Self->{Config}->{SearchLimit} || 10000;

    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

    # store last screen, used for backlinks
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $Self->{RequestedURL},
    );

    # store last screen overview
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenOverview',
        Value     => $Self->{RequestedURL},
    );

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get default parameters, try to get filter (ClassID) from session if not given as parameter
    $Self->{Filter} = $ParamObject->GetParam( Param => 'Filter' )
        || $Self->{AgentITSMConfigItemClassFilter}
        # KIX4OTRS-capeIT
        || $ParamObject->GetParam( Param => 'ClassID' )
        # EO KIX4OTRS-capeIT
        || '';
    $Self->{View} = $ParamObject->GetParam( Param => 'View' ) || '';

    # store filter (ClassID) in session
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'AgentITSMConfigItemClassFilter',
        Value     => $Self->{Filter},
    );

    # get sorting parameters
    my $SortBy = $ParamObject->GetParam( Param => 'SortBy' )
        || $Self->{Config}->{'SortBy::Default'}
        || 'Number';

    # get ordering parameters
    my $OrderBy = $ParamObject->GetParam( Param => 'OrderBy' )
        || $Self->{Config}->{'Order::Default'}
        || 'Down';

    # set Sort and Order by as Arrays
    my @SortByArray  = ($SortBy);
    my @OrderByArray = ($OrderBy);

    # get general catalog object
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # get class list
    my $ClassList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # get possible deployment state list for config items to be shown
    # KIX4OTRS-capeIT
    # get functionality - should postproductive states be shown
    my $ShowDeploymentStatePostproductive
        = $Kernel::OM->Get('Kernel::Config')->Get('ConfigItemOverview::ShowDeploymentStatePostproductive');
    my @Functionality = ( 'preproductive', 'productive' );
    if ($ShowDeploymentStatePostproductive) {
        push( @Functionality, 'postproductive' );
    }

    # get state list
    # EO KIX4OTRS-capeIT
    my $StateList = $GeneralCatalogObject->ItemList(
        Class       => 'ITSM::ConfigItem::DeploymentState',
        Preferences => {

            # KIX4OTRS-capeIT
            # Functionality => [ 'preproductive', 'productive' ],
            Functionality => \@Functionality,

            # EO KIX4OTRS-capeIT
        },
    );

    # KIX4OTRS-capeIT
    # remove excluded deployment states from state list
    my %DeplStateList = %{$StateList};
    if ( $Kernel::OM->Get('Kernel::Config')->Get('ConfigItemOverview::ExcludedDeploymentStates') ) {
        my @ExcludedStates = split( /,/,
            $Kernel::OM->Get('Kernel::Config')->Get('ConfigItemOverview::ExcludedDeploymentStates') );
        for my $Item ( keys %DeplStateList ) {
            next if !( grep( /$DeplStateList{$Item}/, @ExcludedStates ) );
            delete $DeplStateList{$Item};
        }
    }

    # EO KIX4OTRS-capeIT

    # set the deployment state IDs parameter for the search
    my $DeplStateIDs;

    # KIX4OTRS-capeIT
    # for my $DeplStateKey ( sort keys %StateList ) {
    for my $DeplStateKey ( sort keys %DeplStateList ) {

        # EO KIX4OTRS-capeIT
        push @{$DeplStateIDs}, $DeplStateKey;
    }

    # to store the default class
    my $ClassIDAuto = '';

    # to store the NavBar filters
    my %Filters;

    # define position of the filter in the frontend
    my $PrioCounter = 1000;

    # to store the total number of config items in all classes that the user has access
    my $TotalCount;

    # to store all the clases that the user has access, used in search for filter 'All'
    my $AccessClassList;

    # my config item object
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    my $IncludePostproductive = $Kernel::OM->Get('Kernel::Config')->Get('ConfigItemOverview::ShowDeploymentStatePostproductive') || '';

    CLASSID:
    for my $ClassID ( sort { ${$ClassList}{$a} cmp ${$ClassList}{$b} } keys %{$ClassList} ) {

        # show menu link only if user has access rights
        my $HasAccess = $ConfigItemObject->Permission(
            Scope   => 'Class',
            ClassID => $ClassID,
            UserID  => $Self->{UserID},
            Type    => $Self->{Config}->{Permission},
        );

        next CLASSID if !$HasAccess;

        # insert this class to be passed as search parameter for filter 'All'
        push @{$AccessClassList}, $ClassID;

        # count all records of this class
        my $ClassCount = $ConfigItemObject->ConfigItemCount(
            ClassID               => $ClassID,
            IncludePostproductive => $IncludePostproductive,
        );

        # add the config items number in this class to the total
        $TotalCount += $ClassCount;

        # increase the PrioCounter
        $PrioCounter++;

        # add filter with params for the search method
        $Filters{$ClassID} = {
            Name   => $ClassList->{$ClassID},
            Prio   => $PrioCounter,
            Count  => $ClassCount,
            Search => {
                ClassIDs         => [$ClassID],
                DeplStateIDs     => $DeplStateIDs,
                OrderBy          => \@SortByArray,
                OrderByDirection => \@OrderByArray,
                Limit            => $Self->{SearchLimit},
            },
        };

        # remember the first class id to show this in the overview
        # if no class id was given
        if ( !$ClassIDAuto ) {
            $ClassIDAuto = $ClassID;
        }
    }

    # if only one filter exists
    if ( scalar keys %Filters == 1 ) {

        # get the name of the only filter
        my ($FilterName) = keys %Filters;

        # activate this filter
        $Self->{Filter} = $FilterName;
    }
    else {

        # add default filter, which shows all items
        $Filters{All} = {
            Name   => 'All',
            Prio   => 1000,
            Count  => $TotalCount,
            Search => {
                ClassIDs         => $AccessClassList,
                DeplStateIDs     => $DeplStateIDs,
                OrderBy          => \@SortByArray,
                OrderByDirection => \@OrderByArray,
                Limit            => $Self->{SearchLimit},
            },
        };

        # if no filter was selected activate the filter for the default class
        if ( !$Self->{Filter} ) {
            $Self->{Filter} = $ClassIDAuto;
        }
    }

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check if filter is valid
    if ( !$Filters{ $Self->{Filter} } ) {
        return $LayoutObject->ErrorScreen(
            Message => 'No access to Class is given!',
            Comment => 'Please contact the admin.',
        );
    }

    # investigate refresh
    my $Refresh = $Self->{UserRefreshTime} ? 60 * $Self->{UserRefreshTime} : undef;

    # output header
    my $Output = $LayoutObject->Header(
        Title   => 'Overview',
        Refresh => $Refresh,
    );
    $Output .= $LayoutObject->NavigationBar();
    $LayoutObject->Print( Output => \$Output );
    $Output = '';

    # display all navbar filters
    my %NavBarFilter;
    for my $Filter ( sort keys %Filters ) {

        # display the navbar filter
        $NavBarFilter{ $Filters{$Filter}->{Prio} } = {
            Filter => $Filter,
            %{ $Filters{$Filter} },
        };
    }

    # search config items which match the selected filter
    my $ConfigItemIDs = $ConfigItemObject->ConfigItemSearchExtended(
        %{ $Filters{ $Self->{Filter} }->{Search} },
    );

    # check for specific item rights (attribute 'CIGroupAccess')
    my @ItemClassGroupCheck;
    for my $ConfigItemID ( @{ $ConfigItemIDs } ) {

            # check for access rights
            my $HasAccess = $ConfigItemObject->Permission(
                Scope  => 'Item',
                ItemID => $ConfigItemID,
                UserID => $Self->{UserID},
                Type   => $Self->{Config}->{Permission},
            );

            push(@ItemClassGroupCheck, $ConfigItemID) if $HasAccess;
    }
    $ConfigItemIDs = \@ItemClassGroupCheck;

    # find out which columns should be shown
    my @ShowColumns;

    # KIX4OTRS-capeIT
    my %PossibleColumn = ();

    # EO KIX4OTRS-capeIT
    if ( $Self->{Config}->{ShowColumns} ) {

        # get all possible columns from config
        # KIX4OTRS-capeIT
        # my %PossibleColumn = %{ $Self->{Config}->{ShowColumns} };
        %PossibleColumn = %{ $Self->{Config}->{ShowColumns} };

        # EO KIX4OTRS-capeIT

        # show column "Class" if filter 'All' is selected
        if ( $Self->{Filter} eq 'All' ) {
            $PossibleColumn{Class} = '1';
        }

        # get the column names that should be shown
        COLUMNNAME:
        for my $Name ( sort keys %PossibleColumn ) {
            next COLUMNNAME if !$PossibleColumn{$Name};
            push @ShowColumns, $Name;
        }
    }

    # get the configured columns and reorganize them by class name
    if (
        IsArrayRefWithData( $Self->{Config}->{ShowColumnsByClass} )
        && $Self->{Filter}
        && $Self->{Filter} ne 'All'
        )
    {

        my %ColumnByClass;
        NAME:
        for my $Name ( @{ $Self->{Config}->{ShowColumnsByClass} } ) {
            my ( $Class, $Column ) = split /::/, $Name, 2;

            next NAME if !$Column;

            push @{ $ColumnByClass{$Class} }, $Column;
        }

        # check if there is a specific column config for the selected class
        my $SelectedClass = $ClassList->{ $Self->{Filter} };
        if ( $ColumnByClass{$SelectedClass} ) {
            @ShowColumns = @{ $ColumnByClass{$SelectedClass} };
        }
    }

    # show the list
    my $LinkPage =
        'Filter=' . $LayoutObject->Ascii2Html( Text => $Self->{Filter} )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
        . ';SortBy=' . $LayoutObject->Ascii2Html( Text => $SortBy )
        . ';OrderBy=' . $LayoutObject->Ascii2Html( Text => $OrderBy )
        . ';';
    my $LinkSort =
        'Filter=' . $LayoutObject->Ascii2Html( Text => $Self->{Filter} )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
        . ';';
    my $LinkFilter =
        'SortBy=' . $LayoutObject->Ascii2Html( Text => $SortBy )
        . ';OrderBy=' . $LayoutObject->Ascii2Html( Text => $OrderBy )
        . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
        . ';';

    # show config item list
    $Output .= $LayoutObject->ITSMConfigItemListShow(

        # KIX4OTRS-capeIT
        ConfigItemObject => $ConfigItemObject,

        # EO KIX4OTRS-capeIT
        ConfigItemIDs => $ConfigItemIDs,
        Total         => scalar @{$ConfigItemIDs},
        View          => $Self->{View},
        Filter        => $Self->{Filter},
        Filters       => \%NavBarFilter,
        FilterLink    => $LinkFilter,
        TitleName     => $LayoutObject->{LanguageObject}->Translate('Overview')
            . ': ' . $LayoutObject->{LanguageObject}->Translate('ITSM ConfigItem'),
        TitleValue  => $Filters{ $Self->{Filter} }->{Name},
        Env         => $Self,
        LinkPage    => $LinkPage,
        LinkSort    => $LinkSort,
        ShowColumns => \@ShowColumns,
        SortBy      => $LayoutObject->Ascii2Html( Text => $SortBy ),
        OrderBy     => $LayoutObject->Ascii2Html( Text => $OrderBy ),

        # KIX4OTRS-capeIT
        PossibleColumns => \%PossibleColumn,

        # EO KIX4OTRS-capeIT
    );

    # add footer
    $Output .= $LayoutObject->Footer();

    return $Output;
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
