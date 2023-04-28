# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::ITSMConfigItem;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Output::HTML::Layout::ITSMConfigItem - all ConfigItem-related HTML functions

=head1 SYNOPSIS

All ITSM Configuration Management-related HTML functions

=head1 PUBLIC INTERFACE

=over 4

=item ITSMConfigItemOutputStringCreate()

returns an output string

    my $String = $LayoutObject->ITSMConfigItemOutputStringCreate(
        Value => 11,       # (optional)
        Item  => $ItemRef,
        Print => 1,        # (optional, default 0)
    );

=cut

sub ITSMConfigItemOutputStringCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Item} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Item!',
        );
        return;
    }

    # load backend
    my $BackendObject = $Self->_ITSMLoadLayoutBackend(
        Type => $Param{Item}->{Input}->{Type},
    );

    return '' if !$BackendObject;

    # generate output string
    my $String = $BackendObject->OutputStringCreate(%Param);

    return $String;
}

=item ITSMConfigItemFormDataGet()

returns the values from the html form as hash reference

    my $FormDataRef = $LayoutObject->ITSMConfigItemFormDataGet(
        Key          => 'Item::1::Node::3',
        Item         => $ItemRef,
        ConfigItemID => 123,
    );

=cut

sub ITSMConfigItemFormDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item ConfigItemID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # load backend
    my $BackendObject = $Self->_ITSMLoadLayoutBackend(
        Type => $Param{Item}->{Input}->{Type},
    );

    return {} if !$BackendObject;

    # get form data
    my $FormData = $BackendObject->FormDataGet(%Param);

    return $FormData;
}

=item ITSMConfigItemInputCreate()

returns a input field html string

    my $String = $LayoutObject->ITSMConfigItemInputCreate(
        Key => 'Item::1::Node::3',
        Value => 11,                # (optional)
        Item => $ItemRef,
    );

=cut

sub ITSMConfigItemInputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # load backend
    my $BackendObject = $Self->_ITSMLoadLayoutBackend(
        Type => $Param{Item}->{Input}->{Type},
    );

    return '' if !$BackendObject;

    # lookup item value
    my $String = $BackendObject->InputCreate(%Param);

    return $String;
}

=item ITSMConfigItemSearchFormDataGet()

returns the values from the search html form

    my $ArrayRef = $LayoutObject->ITSMConfigItemSearchFormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub ITSMConfigItemSearchFormDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # load backend
    my $BackendObject = $Self->_ITSMLoadLayoutBackend(
        Type => $Param{Item}->{Input}->{Type},
    );

    return [] if !$BackendObject;

    # get form data
    my $Values = $BackendObject->SearchFormDataGet(%Param);

    return $Values;
}

=item ITSMConfigItemSearchInputCreate()

returns a search input field html string

    my $String = $LayoutObject->ITSMConfigItemSearchInputCreate(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub ITSMConfigItemSearchInputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # load backend
    my $BackendObject = $Self->_ITSMLoadLayoutBackend(
        Type => $Param{Item}->{Input}->{Type},
    );

    return '' if !$BackendObject;

    # lookup item value
    my $String = $BackendObject->SearchInputCreate(%Param);

    return $String;
}

=item _ITSMLoadLayoutBackend()

load a input type backend module

    $BackendObject = $LayoutObject->_ITSMLoadLayoutBackend(
        Type => 'GeneralCatalog',
    );

=cut

sub _ITSMLoadLayoutBackend {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    if ( !$Param{Type} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need Type!',
        );
        return;
    }

    my $GenericModule = 'Kernel::Output::HTML::ITSMConfigItem::Layout' . $Param{Type};

    # load the backend module
    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($GenericModule) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Can't load backend module $Param{Type}!"
        );
        return;
    }

    # create new instance
    my $BackendObject = $GenericModule->new(
        %{$Self},
        %Param,
        LayoutObject => $Self,
    );

    if ( !$BackendObject ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Can't create a new instance of backend module $Param{Type}!",
        );
        return;
    }

    return $BackendObject;
}

=item ITSMConfigItemListShow()

Returns a list of configuration items as sortable list with pagination.

This function is similar to L<Kernel::Output::HTML::LayoutTicket::TicketListShow()>
in F<Kernel/Output/HTML/LayoutTicket.pm>.

    my $Output = $LayoutObject->ITSMConfigItemListShow(
        ConfigItemIDs => $ConfigItemIDsRef,                  # total list of config item ids, that can be listed
        Total         => scalar @{ $ConfigItemIDsRef },      # total number of list items, config items in this case
        View          => $Self->{View},                      # optional, the default value is 'Small'
        Filter        => 'All',
        Filters       => \%NavBarFilter,
        FilterLink    => $LinkFilter,
        TitleName     => 'Overview: Config Item: Computer',
        TitleValue    => $Self->{Filter},
        Env           => $Self,
        LinkPage      => $LinkPage,
        LinkSort      => $LinkSort,
        Frontend      => 'Agent',                           # optional (Agent|Customer), default: Agent, indicates from which frontend this function was called
    );

=cut

sub ITSMConfigItemListShow {
    my ( $Self, %Param ) = @_;

    # take object ref to local, remove it from %Param (prevent memory leak)
    my $Env = delete $Param{Env};

    # lookup latest used view mode
    if ( !$Param{View} && $Self->{ 'UserITSMConfigItemOverview' . $Env->{Action} } ) {
        $Param{View} = $Self->{ 'UserITSMConfigItemOverview' . $Env->{Action} };
    }

    # fallback due to problem with session object (T#2015102290000583)
    my %UserPreferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Self->{UserID} );
    if ( !$Param{View} && $UserPreferences{ 'UserITSMConfigItemOverview' . $Env->{Action} } ) {
        $Param{View} = $UserPreferences{ 'UserITSMConfigItemOverview' . $Env->{Action} };
    }

    # set frontend
    my $Frontend = $Param{Frontend} || 'Agent';

    # set defaut view mode to 'small'
    my $View    = $Param{View} || 'Small';
    my $ClassID = $Param{Filter} || $Param{ClassID} || 'All';

    if (
        $Self->{Action} eq 'AgentITSMConfigItem'
        && ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' )
    ) {
        $Param{TitleValue} = 'All';
    }
    elsif (
        $Self->{Action} eq 'AgentITSMConfigItemSearch'
        && ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' )
        && $ClassID ne 'All'
        && $ClassID ne '-'
    ) {
        my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );
        $Param{TitleValue} = $ClassList->{$ClassID};
    }
    elsif (
        $Self->{Action} eq 'AgentITSMConfigItemSearch'
        && ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' )
        && $ClassID eq '-'
    ) {
        $Param{TitleValue} = 'SearchResult';
    }
    elsif ( !defined $Param{TitleValue} || $Param{TitleValue} eq '' ) {
        $Param{TitleValue} = $ClassID;
    }

    # store latest view mode
    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'UserITSMConfigItemOverview' . $Env->{Action},
        Value     => $View,
    );

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # update preferences if needed
    my $Key = 'UserITSMConfigItemOverview' . $Env->{Action};
    my $LastView = $Self->{$Key} || '';

    # if ( !$ConfigObject->Get('DemoSystem') && $Self->{$Key} ne $View ) {
    if ( !$ConfigObject->Get('DemoSystem') && $LastView ne $View ) {

        $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Key,
            Value  => $View,
        );
    }

    # get backend from config
    my $Backends = $ConfigObject->Get('ITSMConfigItem::Frontend::Overview');
    if ( !$Backends ) {
        return $LayoutObject->FatalError(
            Message => 'Need config option ITSMConfigItem::Frontend::Overview',
        );
    }

    # check for hash-ref
    if ( ref $Backends ne 'HASH' ) {
        return $LayoutObject->FatalError(
            Message => 'Config option ITSMConfigItem::Frontend::Overview needs to be a HASH ref!',
        );
    }

    # check for config key
    if ( !$Backends->{$View} ) {
        return $LayoutObject->FatalError(
            Message => "No config option found for the view '$View'!",
        );
    }

    # nav bar
    my $StartHit = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam(
        Param => 'StartHit',
    ) || 1;

    # get personal page shown count
    my $PageShownPreferencesKey = 'UserConfigItemOverview' . $View . 'PageShown';
    my $PageShown               = $Self->{$PageShownPreferencesKey} || 10;
    my $Group                   = 'ConfigItemOverview' . $View . 'PageShown';

    # check start option, if higher then elements available, set
    # it to the last overview page (Thanks to Stefan Schmidt!)
    if ( $StartHit > $Param{Total} ) {
        my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
        $StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
    }

    # get data selection
    my %Data;
    my $Config = $ConfigObject->Get('PreferencesGroups');
    if ( $Config && $Config->{$Group} && $Config->{$Group}->{Data} ) {
        %Data = %{ $Config->{$Group}->{Data} };
    }

    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UploadCacheObject   = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    my $SelectedItemStrg  = $ParamObject->GetParam( Param => 'SelectedItems' ) || '';
    my @SelectedItems     = split(',', $SelectedItemStrg);
    my %SelectedItemsHash = map( { $_ => 1 } @SelectedItems );
    my @UnselectedItems   = ();

    for my $ConfigItem ( @{$Param{ConfigItemIDs}} ) {
        if ( !$SelectedItemsHash{ $ConfigItem } ) {
            push(@UnselectedItems, $ConfigItem);
        }
    }
    my $UnselectedItemStrg = join(',', @UnselectedItems) || '';

    if ( !$Self->{FormID} ) {
        $Self->{FormID} = $UploadCacheObject->FormIDCreate();
    }

    # set page limit and build page nav
    my $Limit = $Param{Limit} || 20_000;
    my %PageNav = $LayoutObject->PageNavBar(
        Limit           => $Limit,
        StartHit        => $StartHit,
        PageShown       => $PageShown,
        AllHits         => $Param{Total} || 0,
        Action          => 'Action=' . $Env->{Action},
        Link            => $Param{LinkPage},
        SelectedItems   => $SelectedItemStrg,
        UnselectedItems => $UnselectedItemStrg,
        FormID          => $Self->{FormID}
    );

    # build shown ticket a page
    $Param{RequestedURL}    = "Action=$Self->{Action}";
    $Param{Group}           = $Group;
    $Param{PreferencesKey}  = $PageShownPreferencesKey;
    $Param{PageShownString} = $LayoutObject->BuildSelection(
        Name        => $PageShownPreferencesKey,
        SelectedID  => $PageShown,
        Data        => \%Data,
        Translation => 0,
        Sort        => 'NumericValue',
    );

    # build navbar content
    $LayoutObject->Block(
        Name => 'OverviewNavBar',
        Data => \%Param,
    );

    # back link
    if ( $Param{LinkBack} ) {
        $LayoutObject->Block(
            Name => 'OverviewNavBarPageBack',
            Data => \%Param,
        );
    }

    # get filters
    if ( $Param{Filters} ) {

        # get given filters
        my @NavBarFilters;
        for my $Prio ( sort keys %{ $Param{Filters} } ) {
            push @NavBarFilters, $Param{Filters}->{$Prio};
        }

        # build filter content
        $LayoutObject->Block(
            Name => 'OverviewNavBarFilter',
            Data => {
                %Param,
            },
        );

        # loop over filters
        my $Count = 0;
        for my $Filter (@NavBarFilters) {

            # increment filter count and build filter item
            $Count++;
            $LayoutObject->Block(
                Name => 'OverviewNavBarFilterItem',
                Data => {
                    %Param,
                    %{$Filter},
                },
            );

            # filter is selected
            if ( $Filter->{Filter} eq $Param{Filter} ) {
                $LayoutObject->Block(
                    Name => 'OverviewNavBarFilterItemSelected',
                    Data => {
                        %Param,
                        %{$Filter},
                    },
                );

            }
            else {
                $LayoutObject->Block(
                    Name => 'OverviewNavBarFilterItemSelectedNot',
                    Data => {
                        %Param,
                        %{$Filter},
                    },
                );
            }
        }
    }

    # set priority if not defined
    for my $Backend (
        keys %{$Backends}
    ) {
        if ( !defined $Backends->{$Backend}->{ModulePriority} ) {
            $Backends->{$Backend}->{ModulePriority} = 0;
        }
    }

    # loop over configured backends
    # for my $Backend ( sort keys %{$Backends} ) {
    for my $Backend (
        sort { $Backends->{$a}->{ModulePriority} cmp $Backends->{$b}->{ModulePriority} }
        keys %{$Backends}
    ) {

        # build navbar view mode
        $LayoutObject->Block(
            Name => 'OverviewNavBarViewMode',
            Data => {
                %Param,
                %{ $Backends->{$Backend} },
                Filter => $Param{Filter},
                View   => $Backend,
            },
        );

        # current view is configured in backend
        if ( $View eq $Backend ) {
            $LayoutObject->Block(
                Name => 'OverviewNavBarViewModeSelected',
                Data => {
                    %Param,
                    %{ $Backends->{$Backend} },
                    Filter => $Param{Filter},
                    View   => $Backend,
                },
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'OverviewNavBarViewModeNotSelected',
                Data => {
                    %Param,
                    %{ $Backends->{$Backend} },
                    Filter => $Param{Filter},
                    View   => $Backend,
                },
            );
        }
    }

    # check if page nav is available
    my $Columns = '';

    if (%PageNav) {
        $LayoutObject->Block(
            Name => 'OverviewNavBarPageNavBar',
            Data => \%PageNav,
        );

        # don't show context settings in AJAX case (e. g. in customer ticket history),
        #   because the submit with page reload will not work there
        if ( !$Param{AJAX} ) {
            $LayoutObject->Block(
                Name => 'ContextSettings',
                Data => {
                    %PageNav,
                    %Param,
                    ClassID => $ClassID,
                },
            );

            $Param{DisplayValueRef} = $Self->_ShowColumnSettings(
                ClassID      => $ClassID,
                TitleValue   => $Param{TitleValue},
                View         => $View,
                ShowColumns  => $Param{ShowColumns},
                Action       => $LayoutObject->{Action},
                LayoutObject => $LayoutObject,
            );
        }
    }

    # check if bulk feature is enabled
    my $BulkFeature = 0;
    if (
        $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeature')
        && (
            !defined $Param{ForceNoBulk}
            || !$Param{ForceNoBulk}
        )
    ) {
        my @Groups;
        if ( $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeatureGroup') ) {
            @Groups = @{ $ConfigObject->Get('ITSMConfigItem::Frontend::BulkFeatureGroup') };
        }
        if ( !@Groups ) {
            $BulkFeature = 1;
        }
        else {
            GROUP:
            for my $Group (@Groups) {
                next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
                if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                    $BulkFeature = 1;
                    last GROUP;
                }
            }
        }
    }

    # show the bulk action button if feature is enabled
    if ($BulkFeature) {
        $LayoutObject->Block(
            Name => 'BulkAction',
            Data => {
                %PageNav,
                %Param,
            },
        );
    }

    # build html content
    my $OutputNavBar = $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemOverviewNavBar',
        Data         => {%Param},
    );

    # create output
    my $OutputRaw = '';
    if ( !$Param{Output} ) {
        $LayoutObject->Print(
            Output => \$OutputNavBar,
        );
    }
    else {
        $OutputRaw .= $OutputNavBar;
    }

    # load module
    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Backends->{$View}->{Module} ) ) {
        return $LayoutObject->FatalError();
    }

    # check for backend object
    my $Object = $Backends->{$View}->{Module}->new( %{$Env} );
    return if !$Object;

    # run module
    my $Output = $Object->Run(
        %Param,
        Limit           => $Limit,
        StartHit        => $StartHit,
        PageShown       => $PageShown,
        AllHits         => $Param{Total} || 0,
        Frontend        => $Frontend,
        SelectedItems   => \@SelectedItems,
        UnselectedItems => \@UnselectedItems,
    );

    # create output
    if ( !$Param{Output} ) {
        $LayoutObject->Print(
            Output => \$Output,
        );
    }
    else {
        $OutputRaw .= $Output;
    }

    # create overview nav bar
    $LayoutObject->Block(
        Name => 'OverviewNavBar',
        Data => {%Param},
    );

    # return content if available
    return $OutputRaw;
}

sub _ShowColumnSettings {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if ( !$Param{ClassID} );
    return if ( !$Param{View} );
    return if ( !$Param{TitleValue} );
    return if ( !$Param{Action} );
    return if ( !$Param{LayoutObject} );

    # create needed objects
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $CustomerUserObject   = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');

    my $ClassID = $Param{ClassID};
    my $View    = $Param{View};
    my $Action  = $Param{Action};

    # get data selection
    my %CurrentUserData = $UserObject->GetUserData(
        UserID => $Self->{UserID},
    );

    # get subattributes for column settings
    my $Definition;
    my %DefinitionHash = ();
    my $ClassList      = ();
    if ( $ClassID ) {

        # get definition
        if ( $ClassID ne 'All' ) {

            # get definition
            $Definition = $ConfigItemObject->DefinitionGet(
                ClassID => $ClassID,
            );
        }
        elsif (
            $ClassID eq 'All'
            && $Action eq 'AgentITSMConfigItemSearch'
        ) {
            $ClassList = $GeneralCatalogObject->ItemList(
                Class => 'ITSM::ConfigItem::Class',
            );

            # check access
            $Self->{Config} = $ConfigObject->Get( 'ITSMConfigItem::Frontend::' . $Self->{Action} );
            for my $ClassID ( sort( keys( %{ $ClassList } ) ) ) {
                my $HasAccess = $ConfigItemObject->Permission(
                    Type    => $Self->{Config}->{Permission},
                    Scope   => 'Class',
                    ClassID => $ClassID,
                    UserID  => $Self->{UserID},
                );

                delete( $ClassList->{ $ClassID } ) if ( !$HasAccess );
            }

            # get definition hash
            for my $Class ( keys( %{ $ClassList } ) ) {
                $DefinitionHash{ $Class } = $ConfigItemObject->DefinitionGet(
                    ClassID => $Class,
                );
            }
        }
    }

    my $CSSClass           = '';
    my @SelectedValueArray = ();

    # get user settings
    if (
        defined( $CurrentUserData{ 'UserCustomCILV-' . $Action . '-' . $Param{TitleValue} } )
        && $CurrentUserData{ 'UserCustomCILV-' . $Action . '-' . $Param{TitleValue} }
    ) {
        my $SelectedColumnString = $CurrentUserData{ 'UserCustomCILV-' . $Action . '-' . $Param{TitleValue} };
        my @SelectedColumnArray  = split( /,/, $SelectedColumnString );

        # get selected values
        for my $Item ( @SelectedColumnArray ) {
            push( @SelectedValueArray, $Item );
        }
    }

    # if no columns selected
    if ( !scalar( @SelectedValueArray ) ) {
        for my $ShownColumn ( @{ $Param{ShowColumns} } ) {
            push( @SelectedValueArray, $ShownColumn );
        }
    }
    else {
        if ( $View eq 'Custom' ) {
            $Param{ShowColumns} = \@SelectedValueArray;
        }
    }

    # create display value hash
    my %DisplayValueHash = (
        'CurDeplState'     => 'Deployment State',
        'CurInciState'     => 'Current Incident State',
        'CurDeplStateType' => 'Deployment State Type',
        'CurInciStateType' => 'Current Incident State Type',
        'LastChanged'      => 'Last changed',
        'CurInciSignal'    => 'Current Incident Signal',
        'CurDeplSignal'    => 'Current Deployment Signal'
    );

    if (
        $ClassID
        && $ClassID ne 'All'
    ) {
        # prepare display values for class
        $Self->_PrepareDisplayValues(
            DefinitionRef   => $Definition->{DefinitionRef},
            DisplayValueRef => \%DisplayValueHash,
            Prefix          => ''
        );
    }
    elsif (
        $ClassID eq 'All'
        && $Action eq 'AgentITSMConfigItemSearch'
    ) {
        # prepare display values for class list
        for my $Class ( sort( keys( %{ $ClassList } ) ) ) {
            $Self->_PrepareDisplayValues(
                DefinitionRef   => $DefinitionHash{ $Class }->{DefinitionRef},
                DisplayValueRef => \%DisplayValueHash,
                Prefix          => ''
            );
        }
    }

    my %SelectedAttributes = map { $_ => 1 } @SelectedValueArray;

    # get selected value string
    my $SelectedValueStrg = '<div class="SortableColumns"><span class="SortableColumnsDescription">'
                          . $LayoutObject->{LanguageObject}->Translate('Selected Columns')
                          . ':</span><ul class="ColumnOrder" id="SortableSelected">';

    SELECTEDITEM:
    for my $Item ( @SelectedValueArray ) {
        # get parts of the entry
        my @SplitItem = split( /::/, $Item );

        # translate parts of entry
        my @TranslationArray;
        my $Prefix = '';
        for my $SplitPart ( @SplitItem ) {
            if ( $DisplayValueHash{ $Prefix . $SplitPart } ) {
                push( @TranslationArray, $LayoutObject->{LanguageObject}->Translate( $DisplayValueHash{ $Prefix . $SplitPart } ) );
            }
            else {
                push( @TranslationArray, $LayoutObject->{LanguageObject}->Translate( $SplitPart ) );
            }

            $Prefix .= $SplitPart . '::';
        }

        # add entry to output
        $SelectedValueStrg .= '<li class="ui-state-default'
                            . $CSSClass
                            . '" name="'
                            . $Item . '">'
                            . join( '::', @TranslationArray )
                            . '<span class="ui-icon ui-icon-arrowthick-2-n-s"></span>'
                            . '</li>';
    }

    $SelectedValueStrg .= '</ul></div>';

    # if no possible columns selected
    if (
        !defined( $Param{PossibleColumns} )
        || !$Param{PossibleColumns}
    ) {
        $Self->{DefaultConfig}  = $ConfigObject->Get('ITSMConfigItem::Frontend::AgentITSMConfigItem');
        $Param{PossibleColumns} = $Self->{DefaultConfig}->{ShowColumns};
    }

    # get possible value string
    my $PossibleValueStrg = '<div class="SortableColumns"><span class="SortableColumnsDescription">'
                          . $LayoutObject->{LanguageObject}->Translate('Possible Columns')
                          . ':</span><ul class="ColumnOrder" id="SortablePossible">';

    POSSIBLEITEM:
    for my $Item ( sort( keys( %DisplayValueHash ) ) ) {
        # skip selected entries
        next POSSIBLEITEM if ( $SelectedAttributes{ $Item } );

        # get parts of entry
        my @SplitItem = split( /::/, $Item );

        # translate parts of entry
        my @TranslationArray;
        my $Prefix = '';
        for my $SplitPart ( @SplitItem ) {
            if ( $DisplayValueHash{ $Prefix . $SplitPart } ) {
                push( @TranslationArray, $LayoutObject->{LanguageObject}->Translate( $DisplayValueHash{ $Prefix . $SplitPart } ) );
            }
            else {
                push( @TranslationArray, $LayoutObject->{LanguageObject}->Translate( $SplitPart ) );
            }

            $Prefix .= $SplitPart . '::';
        }

        # add entry to output
        $PossibleValueStrg .= '<li class="ui-state-default'
                            . $CSSClass
                            . '" name="'
                            . $Item . '">'
                            . join( '::', @TranslationArray )
                            . '<span class="ui-icon ui-icon-arrowthick-2-n-s"></span>'
                            . '</li>';
    }

    $PossibleValueStrg .= '</ul></div>';

    # Output
    $LayoutObject->Block(
        Name => 'OverviewNavSettingCustomCILV',
        Data => {
            Columns => $PossibleValueStrg . $SelectedValueStrg,
        },
    );
    return \%DisplayValueHash;
}

sub _PrepareDisplayValues {
    my ( $Self, %Param ) = @_;

    ITEM:
    for my $Item ( @{ $Param{DefinitionRef} } ) {
        # get display name if not set yet
        if ( !$Param{DisplayValueRef}->{ $Param{Prefix} . $Item->{Key} } ) {
            $Param{DisplayValueRef}->{ $Param{Prefix} . $Item->{Key} } = $Item->{Name};
        }

        # process sub
        if ( $Item->{Sub} ) {
            $Self->_PrepareDisplayValues(
                DefinitionRef   => $Item->{Sub},
                DisplayValueRef => $Param{DisplayValueRef},
                Prefix          => $Param{Prefix} . $Item->{Key} . '::',
            );
        }
    }

    return 1;
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
