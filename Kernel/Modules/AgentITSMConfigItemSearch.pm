# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemSearch;

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

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my $Output;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    $Self->{Config} = $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}");

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get config data
    $Self->{StartHit} = int( $ParamObject->GetParam( Param => 'StartHit' ) || 1 );
    $Self->{SearchLimit} = $Self->{Config}->{SearchLimit} || 10000;
    $Self->{SortBy} = $ParamObject->GetParam( Param => 'SortBy' )
        || $Self->{Config}->{'SortBy::Default'}
        || 'Number';
    $Self->{OrderBy} = $ParamObject->GetParam( Param => 'OrderBy' )
        || $Self->{Config}->{'Order::Default'}
        || 'Down';
    $Self->{Profile}     = $ParamObject->GetParam( Param => 'Profile' )     || '';
    $Self->{SaveProfile} = $ParamObject->GetParam( Param => 'SaveProfile' ) || '';
    $Self->{TakeLastSearch} = $ParamObject->GetParam( Param => 'TakeLastSearch' );

    # get general catalog object
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # get class list
    my $ClassList = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    # get config item object
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # check for access rights on the classes
    for my $ClassID ( sort keys %{$ClassList} ) {
        my $HasAccess = $ConfigItemObject->Permission(
            Type    => $Self->{Config}->{Permission},
            Scope   => 'Class',
            ClassID => $ClassID,
            UserID  => $Self->{UserID},
        );

        delete $ClassList->{$ClassID} if !$HasAccess;
    }

    # get class id
    my $ClassID = $ParamObject->GetParam( Param => 'ClassID' );

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # KIX4OTRS-capeIT
    my @ClassIDArray = ();

    # if ( $ClassID && !$ClassList->{$ClassID} ) {
    if ( $ClassID && !$ClassList->{$ClassID} && $ClassID ne 'All' ) {

        # EO KIX4OTRS-capeIT
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Invalid ClassID!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    # KIX4OTRS-capeIT
    elsif ( $ClassID && $ClassID ne 'All' ) {
        push @ClassIDArray, $ClassID;
    }
    else {
        @ClassIDArray = keys %{$ClassList};
    }

    # EO KIX4OTRS-capeIT

    # get single params
    my %GetParam;

    # get search profile object
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');

    # load profiles string params
    if ( ( $ClassID && $Self->{Profile} ) && $Self->{TakeLastSearch} ) {
        %GetParam = $SearchProfileObject->SearchProfileGet(
            Base      => 'ConfigItemSearch' . $ClassID,
            Name      => $Self->{Profile},
            UserLogin => $Self->{UserLogin},
        );
    }

    # KIX4OTRS-capeIT
    # search with a saved template
    if ( $ParamObject->GetParam( Param => 'SearchTemplate' ) && $Self->{Profile} ) {
        return $LayoutObject->Redirect(
            OP =>
                "Action=AgentITSMConfigItemSearch;Subaction=Search;TakeLastSearch=1;ClassID=$ClassID;Profile=$Self->{Profile};SearchDialog=1;ResultForm=Normal;"
        );
    }

    # EO KIX4OTRS-capeIT

    # ------------------------------------------------------------ #
    # delete search profiles
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'AJAXProfileDelete' ) {

        # remove old profile stuff
        $SearchProfileObject->SearchProfileDelete(
            Base      => 'ConfigItemSearch' . $ClassID,
            Name      => $Self->{Profile},
            UserLogin => $Self->{UserLogin},
        );
        my $Output = $LayoutObject->JSONEncode(
            Data => 1,
        );
        return $LayoutObject->Attachment(
            NoCache     => 1,
            ContentType => 'text/html',
            Content     => $Output,
            Type        => 'inline',
        );
    }

    # ------------------------------------------------------------ #
    # init search dialog (select class)
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AJAX' ) {

        # generate dropdown for selecting the class
        # automatically show search mask after selecting a class via AJAX
        # KIX4OTRS-capeIT
        $ClassList->{'All'} = '<' . $LayoutObject->{LanguageObject}->Translate('All') . '>';

        # EO KIX4OTRS-capeIT

        my $ClassOptionStrg = $LayoutObject->BuildSelection(
            Data         => $ClassList,
            Name         => 'SearchClassID',
            PossibleNone => 1,
            SelectedID   => $ClassID || '',
            Translation  => 1,
            Class        => 'Modernize',
        );

        # html search mask output
        $LayoutObject->Block(
            Name => 'SearchAJAX',
            Data => {
                ClassOptionStrg => $ClassOptionStrg,
                Profile         => $Self->{Profile},
            },
        );

        # set class fields if class specified
        if ($ClassID) {
            $LayoutObject->Block(
                Name => 'SearchAJAXSetClass',
                Data => {
                    Profile => $Self->{Profile},
                },
            );
        }

        # output template
        $Output = $LayoutObject->Output(
            TemplateFile => 'AgentITSMConfigItemSearch',
        );

        return $LayoutObject->Attachment(
            NoCache     => 1,
            ContentType => 'text/html',
            Content     => $Output,
            Type        => 'inline',
        );
    }

    # ------------------------------------------------------------ #
    # set search fields for selected class
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {

        # ClassID is required for the search mask and for actual searching
        if ( !$ClassID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('No ClassID is given!'),
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        # KIX4OTRS-capeIT
        my $HasAccess = 1;
        for my $Class (@ClassIDArray) {

            # EO KIX4OTRS-capeIT

            # check if user is allowed to search class
            # KIX4OTRS-capeIT
            # my $HasAccess = $ConfigItemObject->Permission(
            $HasAccess = $HasAccess && $ConfigItemObject->Permission(

                # EO KIX4OTRS-capeIT
                Type  => $Self->{Config}->{Permission},
                Scope => 'Class',

                # KIX4OTRS-capeIT
                # ClassID => $ClassID,
                ClassID => $Class,

                # EO KIX4OTRS-capeIT
                UserID => $Self->{UserID},
            );

            # KIX4OTRS-capeIT
        }

        # EO KIX4OTRS-capeIT

        # show error screen
        if ( !$HasAccess ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('No access rights for this class given!'),
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        # get current definition
        # KIX4OTRS-capeIT
        my %AttributesHash;
        my %XMLDefinitionHash = ();
        for my $Class (@ClassIDArray) {

            # my $XMLDefinition = $ConfigItemObject->DefinitionGet(
            #     ClassID => $ClassID,
            # );
            my $XMLDefinition = $ConfigItemObject->DefinitionGet(
                ClassID => $Class,
            );

            # EO KIX4OTRS-capeIT
            if ( !$XMLDefinition->{DefinitionID} ) {
            return $LayoutObject->ErrorScreen(
                Message =>
                    $LayoutObject->{LanguageObject}->Translate( 'No definition was defined for class %s!', $ClassID ),
                Comment => Translatable('Please contact the administrator.'),
                );
            }

            # KIX4OTRS-capeIT
            $XMLDefinitionHash{$Class} = $XMLDefinition;

            # EO KIX4OTRS-capeIT

            my @XMLAttributes = (
                {
                    Key   => 'Number',
                Value => Translatable('Number'),
                },
                {
                    Key   => 'Name',
                Value => Translatable('Name'),
                },
                {
                    Key   => 'DeplStateIDs',
                Value => Translatable('Deployment State'),
                },
                {
                    Key   => 'InciStateIDs',
                Value => Translatable('Incident State'),
                },
            );

            # get attributes to include in attributes string
            if ( $XMLDefinition->{Definition} ) {
                $Self->_XMLSearchAttributesGet(
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                    XMLAttributes => \@XMLAttributes,
                );
            }

            # KIX4OTRS-capeIT
            for my $Attribute (@XMLAttributes) {
                if ( defined $AttributesHash{Key}->{ $Attribute->{Key} } ) {
                    $AttributesHash{Key}->{ $Attribute->{Key} }++;
                }
                else {
                    $AttributesHash{Key}->{ $Attribute->{Key} }   = 1;
                    $AttributesHash{Value}->{ $Attribute->{Key} } = $Attribute->{Value};
                }
            }
        }
        # EO KIX4OTRS-capeIT

        my %GetParam = $SearchProfileObject->SearchProfileGet(
            Base      => 'ConfigItemSearch' . $ClassID,
            Name      => $Self->{Profile},
            UserLogin => $Self->{UserLogin},
        );

        # KIX4OTRS-capeIT
        # get user data
        my %CurrentUserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $Self->{UserID},
        );
        my @XMLAttributes = ();
        if (
            defined $CurrentUserData{UserConfigItemSearchAllBehavior}
            && $CurrentUserData{UserConfigItemSearchAllBehavior} eq 'EqualAttributes'
            )
        {
            my $ListSize = scalar @ClassIDArray;
            for my $Attribute (
                sort {
                    $LayoutObject->{LanguageObject}->Translate($a)
                        cmp $LayoutObject->{LanguageObject}->Translate($b)
                } keys %{ $AttributesHash{Key} }
                )
            {
                next if $AttributesHash{Key}->{$Attribute} < $ListSize;
                my %TmpHash = ();
                $TmpHash{Key}   = $Attribute;
                $TmpHash{Value} = $AttributesHash{Value}->{$Attribute};
                push @XMLAttributes, \%TmpHash;
            }
        }
        else {
            for my $Attribute (
                sort {
                    $LayoutObject->{LanguageObject}->Translate($a)
                        cmp $LayoutObject->{LanguageObject}->Translate($b)
                } keys %{ $AttributesHash{Key} }
                )
            {
                my %TmpHash = ();
                $TmpHash{Key}   = $Attribute;
                $TmpHash{Value} = $AttributesHash{Value}->{$Attribute};
                push @XMLAttributes, \%TmpHash;
            }
        }

        # EO KIX4OTRS-capeIT
        # build attributes string for attributes list
        $Param{AttributesStrg} = $LayoutObject->BuildSelection(
            Data     => \@XMLAttributes,
            Name     => 'Attribute',
            Multiple => 0,
            Class    => 'Modernize',
        );

        # build attributes string for recovery on add or subtract search fields
        $Param{AttributesOrigStrg} = $LayoutObject->BuildSelection(
            Data     => \@XMLAttributes,
            Name     => 'AttributeOrig',
            Multiple => 0,
            Class    => 'Modernize',
        );

        my %Profiles = $SearchProfileObject->SearchProfileList(
            Base      => 'ConfigItemSearch' . $ClassID,
            UserLogin => $Self->{UserLogin},
        );

        delete $Profiles{''};
        $Profiles{'last-search'} = '-';
        $Param{ProfilesStrg} = $LayoutObject->BuildSelection(
            Data       => \%Profiles,
            Name       => 'Profile',
            ID         => 'SearchProfile',
            SelectedID => $Self->{Profile},

            # Do not modernize this field as this causes problems with the automatic focussing of the first element.
        );

        # get deployment state list
        my $DeplStateList = $GeneralCatalogObject->ItemList(
            Class => 'ITSM::ConfigItem::DeploymentState',
        );

        # generate dropdown for selecting the wanted deployment states
        my $CurDeplStateOptionStrg = $LayoutObject->BuildSelection(
            Data       => $DeplStateList,
            Name       => 'DeplStateIDs',
            SelectedID => $GetParam{DeplStateIDs} || [],
            Size       => 5,
            Multiple   => 1,
            Class      => 'Modernize',
        );

        # get incident state list
        my $InciStateList = $GeneralCatalogObject->ItemList(
            Class => 'ITSM::Core::IncidentState',
        );

        # generate dropdown for selecting the wanted incident states
        my $CurInciStateOptionStrg = $LayoutObject->BuildSelection(
            Data       => $InciStateList,
            Name       => 'InciStateIDs',
            SelectedID => $GetParam{InciStateIDs} || [],
            Size       => 5,
            Multiple   => 1,
            Class      => 'Modernize',
        );

        # generate PreviousVersionOptionStrg
        my $PreviousVersionOptionStrg = $LayoutObject->BuildSelection(
            Name => 'PreviousVersionSearch',
            Data => {
                0 => Translatable('No'),
                1 => Translatable('Yes'),
            },
            SelectedID => $GetParam{PreviousVersionSearch} || '0',
            Class => 'Modernize',
        );

        # build output format string
        $Param{ResultFormStrg} = $LayoutObject->BuildSelection(
            Data => {
                Normal => Translatable('Normal'),
                Print  => Translatable('Print'),
                CSV    => Translatable('CSV'),
            },
            Name       => 'ResultForm',
            SelectedID => $GetParam{ResultForm} || 'Normal',
            Class      => 'Modernize',
        );

        $LayoutObject->Block(
            Name => 'AJAXContent',
            Data => {
                ClassID                   => $ClassID,
                CurDeplStateOptionStrg    => $CurDeplStateOptionStrg,
                CurInciStateOptionStrg    => $CurInciStateOptionStrg,
                PreviousVersionOptionStrg => $PreviousVersionOptionStrg,
                AttributesStrg            => $Param{AttributesStrg},
                AttributesOrigStrg        => $Param{AttributesOrigStrg},
                ResultFormStrg            => $Param{ResultFormStrg},
                ProfilesStrg              => $Param{ProfilesStrg},
                Number                    => $GetParam{Number} || '',
                Name                      => $GetParam{Name} || '',
            },
        );

        # output xml search form
        # KIX4OTRS-capeIT
        # default values
        my @DefaultKeys = ( 'Number', 'Name', 'DeplStateIDs', 'InciStateIDs' );
        my @UsedKeys;
        for my $Class (@ClassIDArray) {

            # if ( $XMLDefinition->{Definition} ) {
            if ( $XMLDefinitionHash{$Class}->{Definition} ) {

                if ( scalar @XMLAttributes ) {

                    # EO KIX4OTRS-capeIT
                    $Self->_XMLSearchFormOutput(

                        # KIX4OTRS-capeIT
                        # XMLDefinition => $XMLDefinition->{DefinitionRef},
                        XMLDefinition => $XMLDefinitionHash{$Class}->{DefinitionRef},

                        # EO KIX4OTRS-capeIT
                        XMLAttributes => \@XMLAttributes,
                        GetParam      => \%GetParam,
                    );

                    # KIX4OTRS-capeIT
                    # remove already used xml attributes
                    my @TmpArray;
                    for my $Hash (@XMLAttributes) {

                        # get already used keys
                        next if grep { $Hash->{Key} eq $_ } @DefaultKeys;
                        next if grep { $Hash->{Key} eq $_ } @UsedKeys;

                        # check if key is used by definition ref
                        my $Found = 0;
                        for my $XMLDefinition ( @{ $XMLDefinitionHash{$Class}->{DefinitionRef} } ) {
                            next if $Hash->{Key} ne $XMLDefinition->{Key};
                            push @UsedKeys, $Hash->{Key};
                            $Found = 1;
                            last;
                        }

                        # if not found add to new array
                        if ( !$Found ) {
                            my %TempHash = %{$Hash};
                            push @TmpArray, \%TempHash;
                        }
                    }
                    @XMLAttributes = @TmpArray;
                }
            }

            # EO KIX4OTRS-capeIT
        }

        # show attributes
        my $AttributeIsUsed = 0;
        KEY:
        for my $Key ( sort keys %GetParam ) {
            next KEY if !$Key;
            next KEY if !defined $GetParam{$Key};
            next KEY if $GetParam{$Key} eq '';

            $AttributeIsUsed = 1;

            $LayoutObject->Block(
                Name => 'SearchAJAXShow',
                Data => {
                    Attribute => $Key,
                },
            );
        }

        # if no attribute is shown, show configitem number
        if ( !$Self->{Profile} ) {

            $LayoutObject->Block(
                Name => 'SearchAJAXShow',
                Data => {
                    Attribute => 'Number',
                },
            );
        }

        # output template
        $Output = $LayoutObject->Output(
            TemplateFile => 'AgentITSMConfigItemSearch',
        );

        return $LayoutObject->Attachment(
            NoCache     => 1,
            ContentType => 'text/html',
            Content     => $Output,
            Type        => 'inline',
        );
    }

    # ------------------------------------------------------------ #
    # perform search
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Search' ) {

        my $SearchDialog = $ParamObject->GetParam( Param => 'SearchDialog' );

        # fill up profile name (e.g. with last-search)
        if ( !$Self->{Profile} || !$Self->{SaveProfile} ) {
            $Self->{Profile} = 'last-search';
        }

        # store last overview screen
        my $URL = "Action=AgentITSMConfigItemSearch;Profile=$Self->{Profile};"
            . "TakeLastSearch=1;StartHit=$Self->{StartHit};Subaction=Search;"
            . "OrderBy=$Self->{OrderBy};SortBy=$Self->{SortBy}";

        if ($ClassID) {
            $URL .= ";ClassID=$ClassID";
        }

        # get session object
        my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'LastScreenOverview',
            Value     => $URL,
        );
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => 'LastScreenView',
            Value     => $URL,
        );

        # ClassID is required for the search mask and for actual searching
        if ( !$ClassID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('No ClassID is given!'),
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        # KIX4OTRS-capeIT
        my $HasAccess = 1;
        for my $Class (@ClassIDArray) {

            # EO KIX4OTRS-capeIT

            # check if user is allowed to search class
            # KIX4OTRS-capeIT
            # my $HasAccess = $ConfigItemObject->Permission(
            $HasAccess = $HasAccess && $ConfigItemObject->Permission(

                # EO KIX4OTRS-capeIT
                Type  => $Self->{Config}->{Permission},
                Scope => 'Class',

                # KIX4OTRS-capeIT
                # ClassID => $ClassID,
                ClassID => $Class,

                # EO KIX4OTRS-capeIT
                UserID => $Self->{UserID},
            );

            # KIX4OTRS-capeIT
        }

        # EO KIX4OTRS-capeIT

        # show error screen
        if ( !$HasAccess ) {
            return $LayoutObject->ErrorScreen(
                Message => 'No access rights for this class given!',
                Comment => 'Please contact the admin.',
            );
        }

        # KIX4OTRS-capeIT
        my %DefinitionHash = ();
        for my $Class (@ClassIDArray) {

            # EO KIX4OTRS-capeIT
            # get current definition
            my $XMLDefinition = $ConfigItemObject->DefinitionGet(

                # KIX4OTRS-capeIT
                # ClassID => $ClassID,
                ClassID => $Class,

                # EO KIX4OTRS-capeIT
            );

            # KIX4OTRS-capeIT
            $DefinitionHash{$Class} = $XMLDefinition;

            # EO KIX4OTRS-capeIT

            # abort, if no definition is defined
            if ( !$XMLDefinition->{DefinitionID} ) {
                return $LayoutObject->ErrorScreen(
                Message =>
                    $LayoutObject->{LanguageObject}->Translate( 'No definition was defined for class %s!', $ClassID ),
                Comment => Translatable('Please contact the administrator.'),
                );
            }

            # KIX4OTRS-capeIT
        }

        # EO KIX4OTRS-capeIT

        # get scalar search attributes (special handling for Number and Name)
        FORMVALUE:
        for my $FormValue (qw(Number Name)) {

            my $Value = $ParamObject->GetParam( Param => $FormValue );

            # must be defined and not be an empty string
            # BUT the number 0 is an allowed value
            next FORMVALUE if !defined $Value;
            next FORMVALUE if $Value eq '';

            $GetParam{$FormValue} = $Value;
        }

        # get ther scalar search attributes
        FORMVALUE:
        for my $FormValue (qw(PreviousVersionSearch ResultForm)) {

            my $Value = $ParamObject->GetParam( Param => $FormValue );

            next FORMVALUE if !$Value;

            $GetParam{$FormValue} = $Value;
        }

        # get array search attributes
        FORMARRAY:
        for my $FormArray (qw(DeplStateIDs InciStateIDs)) {

            my @Array = $ParamObject->GetArray( Param => $FormArray );

            next FORMARRAY if !@Array;

            $GetParam{$FormArray} = \@Array;
        }

        # KIX4OTRS-capeIT
        my %XMLGetParamHash = ();
        for my $Class (@ClassIDArray) {

            # EO KIX4OTRS-capeIT

            # get xml search form
            my $XMLFormData = [];
            my $XMLGetParam = [];
            $Self->_XMLSearchFormGet(

                # KIX4OTRS-capeIT
                # XMLDefinition => $XMLDefinition->{DefinitionRef},
                XMLDefinition => $DefinitionHash{$Class}->{DefinitionRef},

                # EO KIX4OTRS-capeIT
                XMLFormData => $XMLFormData,
                XMLGetParam => $XMLGetParam,
                %GetParam,
            );

            # KIX4OTRS-capeIT
            $XMLGetParamHash{$Class} = $XMLGetParam;

            # EO KIX4OTRS-capeIT

            if ( @{$XMLFormData} ) {
                $GetParam{What} = $XMLFormData;
            }

            # KIX4OTRS-capeIT
        }

        # EO KIX4OTRS-capeIT

        # save search profile (under last-search or real profile name)
        $Self->{SaveProfile} = 1;

        # remember last search values only if search is called from a search dialog
        # not from results page
        if ( $Self->{SaveProfile} && $Self->{Profile} && $SearchDialog ) {

            # remove old profile stuff
            $SearchProfileObject->SearchProfileDelete(
                Base      => 'ConfigItemSearch' . $ClassID,
                Name      => $Self->{Profile},
                UserLogin => $Self->{UserLogin},
            );

            # insert new profile params
            for my $Key ( sort keys %GetParam ) {
                if ( $GetParam{$Key} && $Key ne 'What' ) {
                    $SearchProfileObject->SearchProfileAdd(
                        Base      => 'ConfigItemSearch' . $ClassID,
                        Name      => $Self->{Profile},
                        Key       => $Key,
                        Value     => $GetParam{$Key},
                        UserLogin => $Self->{UserLogin},
                    );
                }
            }

            # insert new profile params also from XMLform
            # KIX4OTRS-capeIT
            for my $Class (@ClassIDArray) {

                # if ( @{$XMLGetParam} ) {
                if ( @{ $XMLGetParamHash{$Class} } ) {

                    # for my $Parameter ( @{$XMLGetParam} ) {
                    for my $Parameter ( @{ $XMLGetParamHash{$Class} } ) {

                        # EO KIX4OTRS-capeIT
                        for my $Key ( sort keys %{$Parameter} ) {
                            if ( $Parameter->{$Key} ) {

                            $SearchProfileObject->SearchProfileAdd(
                                    Base      => 'ConfigItemSearch' . $ClassID,
                                    Name      => $Self->{Profile},
                                    Key       => $Key,
                                    Value     => $Parameter->{$Key},
                                    UserLogin => $Self->{UserLogin},
                                );

                            }
                        }
                    }
                }

                # KIX4OTRS-capeIT
            }

            # EO KIX4OTRS-capeIT
        }

        my $SearchResultList = [];

        # start search if called from a search dialog or from a resutls page
        if ( $SearchDialog || $Self->{TakeLastSearch} ) {

            # start search
            $SearchResultList = $ConfigItemObject->ConfigItemSearchExtended(
                %GetParam,
                OrderBy          => [ $Self->{SortBy} ],
                OrderByDirection => [ $Self->{OrderBy} ],
                Limit            => $Self->{SearchLimit},

                # KIX4OTRS-capeIT
                # ClassIDs         => [$ClassID],
                ClassIDs => \@ClassIDArray,

                # EO KIX4OTRS-capeIT
            );
        }

        # get param only if called from a search dialog, otherwise it must be already in %GetParam
        # from a loaded profile
        if ($SearchDialog) {
            $GetParam{ResultForm} = $ParamObject->GetParam( Param => 'ResultForm' );
        }

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        # CSV output
        if ( $GetParam{ResultForm} eq 'CSV' ) {
            my @CSVData;
            my @CSVHead;

            # mapping between header name and data field
            my %Header2Data = (
                'Class'            => 'Class',
                'Incident State'   => 'InciState',
                'Name'             => 'Name',
                'ConfigItemNumber' => 'Number',
                'Deployment State' => 'DeplState',
                'Version'          => 'VersionID',
                'Create Time'      => 'CreateTime',
            );

            CONFIGITEMID:
            for my $ConfigItemID ( @{$SearchResultList} ) {

                # check for access rights
                my $HasAccess = $ConfigItemObject->Permission(
                    Scope  => 'Item',
                    ItemID => $ConfigItemID,
                    UserID => $Self->{UserID},
                    Type   => $Self->{Config}->{Permission},
                );

                next CONFIGITEMID if !$HasAccess;

                # get version
                my $LastVersion = $ConfigItemObject->VersionGet(
                    ConfigItemID => $ConfigItemID,
                    XMLDataGet   => 0,
                );

                # csv quote
                if ( !@CSVHead ) {
                    @CSVHead = @{ $Self->{Config}->{SearchCSVData} };
                }

                # store data
                my @Data;
                for my $Header (@CSVHead) {
                    push @Data, $LastVersion->{ $Header2Data{$Header} };
                }
                push @CSVData, \@Data;
            }

            # csv quote
            # translate non existing header may result in a garbage file
            if ( !@CSVHead ) {
                @CSVHead = @{ $Self->{Config}->{SearchCSVData} };
            }

            # translate headers
            for my $Header (@CSVHead) {

                # replace ConfigItemNumber header with the current ConfigItemNumber from sysconfig
                if ( $Header eq 'ConfigItemNumber' ) {
                    $Header = $ConfigObject->Get('ITSMConfigItem::Hook');
                }
                else {
                    $Header = $LayoutObject->{LanguageObject}->Translate($Header);
                }
            }

            # assable CSV data
            my $CSV = $Kernel::OM->Get('Kernel::System::CSV')->Array2CSV(
                Head      => \@CSVHead,
                Data      => \@CSVData,
                Separator => $Self->{UserCSVSeparator},
            );

            # return csv to download
            my $CSVFile = 'configitem_search';
            my ( $s, $m, $h, $D, $M, $Y ) = $TimeObject->SystemTime2Date(
                SystemTime => $TimeObject->SystemTime(),
            );
            $M = sprintf( "%02d", $M );
            $D = sprintf( "%02d", $D );
            $h = sprintf( "%02d", $h );
            $m = sprintf( "%02d", $m );
            return $LayoutObject->Attachment(
                Filename    => $CSVFile . "_" . "$Y-$M-$D" . "_" . "$h-$m.csv",
                ContentType => "text/csv; charset=" . $LayoutObject->{UserCharset},
                Content     => $CSV,
            );
        }

        # print PDF output
        elsif ( $GetParam{ResultForm} eq 'Print' ) {

            my @PDFData;

            # get pdf object
            my $PDFObject = $Kernel::OM->Get('Kernel::System::PDF');

            CONFIGITEMID:
            for my $ConfigItemID ( @{$SearchResultList} ) {

                # check for access rights
                my $HasAccess = $ConfigItemObject->Permission(
                    Scope  => 'Item',
                    ItemID => $ConfigItemID,
                    UserID => $Self->{UserID},
                    Type   => $Self->{Config}->{Permission},
                );

                next CONFIGITEMID if !$HasAccess;

                # get version
                my $LastVersion = $ConfigItemObject->VersionGet(
                    ConfigItemID => $ConfigItemID,
                    XMLDataGet   => 0,
                );

                # set pdf rows
                my @PDFRow;
                for my $StoreData (qw(Class InciState Name Number DeplState VersionID CreateTime)) {
                    push @PDFRow, $LastVersion->{$StoreData};
                }
                push @PDFData, \@PDFRow;

            }

            # PDF Output
            my $Title = $LayoutObject->{LanguageObject}->Translate('Configuration Item') . ' '
                . $LayoutObject->{LanguageObject}->Translate('Search');
            my $PrintedBy = $LayoutObject->{LanguageObject}->Translate('printed by');
            my $Page      = $LayoutObject->{LanguageObject}->Translate('Page');
            my $Time      = $LayoutObject->{Time};

            # get maximum number of pages
            my $MaxPages = $ConfigObject->Get('PDF::MaxPages');
            if ( !$MaxPages || $MaxPages < 1 || $MaxPages > 1000 ) {
                $MaxPages = 100;
            }

            # create the header
            my $CellData;

            # output 'No Result', if no content was given
            if (@PDFData) {
                $CellData->[0]->[0]->{Content} = $LayoutObject->{LanguageObject}->Translate('Class');
                $CellData->[0]->[0]->{Font}    = 'ProportionalBold';
                $CellData->[0]->[1]->{Content} = $LayoutObject->{LanguageObject}->Translate('Incident State');
                $CellData->[0]->[1]->{Font}    = 'ProportionalBold';
                $CellData->[0]->[2]->{Content} = $LayoutObject->{LanguageObject}->Translate('Name');
                $CellData->[0]->[2]->{Font}    = 'ProportionalBold';
                $CellData->[0]->[3]->{Content} = $LayoutObject->{LanguageObject}->Translate('Number');
                $CellData->[0]->[3]->{Font}    = 'ProportionalBold';
                $CellData->[0]->[4]->{Content} = $LayoutObject->{LanguageObject}->Translate('Deployment State');
                $CellData->[0]->[4]->{Font}    = 'ProportionalBold';
                $CellData->[0]->[5]->{Content} = $LayoutObject->{LanguageObject}->Translate('Version');
                $CellData->[0]->[5]->{Font}    = 'ProportionalBold';
                $CellData->[0]->[6]->{Content} = $LayoutObject->{LanguageObject}->Translate('Create Time');
                $CellData->[0]->[6]->{Font}    = 'ProportionalBold';

                # create the content array
                my $CounterRow = 1;
                for my $Row (@PDFData) {
                    my $CounterColumn = 0;
                    for my $Content ( @{$Row} ) {
                        $CellData->[$CounterRow]->[$CounterColumn]->{Content} = $Content;
                        $CounterColumn++;
                    }
                    $CounterRow++;
                }
            }
            else {
                $CellData->[0]->[0]->{Content} = $LayoutObject->{LanguageObject}->Translate('No Result!');
            }

            # page params
            my %PageParam;
            $PageParam{PageOrientation} = 'landscape';
            $PageParam{MarginTop}       = 30;
            $PageParam{MarginRight}     = 40;
            $PageParam{MarginBottom}    = 40;
            $PageParam{MarginLeft}      = 40;
            $PageParam{HeaderRight}     = $Title;

            # table params
            my %TableParam;
            $TableParam{CellData}            = $CellData;
            $TableParam{Type}                = 'Cut';
            $TableParam{FontSize}            = 6;
            $TableParam{Border}              = 0;
            $TableParam{BackgroundColorEven} = '#DDDDDD';
            $TableParam{Padding}             = 1;
            $TableParam{PaddingTop}          = 3;
            $TableParam{PaddingBottom}       = 3;

            # create new pdf document
            $PDFObject->DocumentNew(
                Title  => $ConfigObject->Get('Product') . ': ' . $Title,
                Encode => $LayoutObject->{UserCharset},
            );

            # start table output
            $PDFObject->PageNew(
                %PageParam,
                FooterRight => $Page . ' 1',
            );

            $PDFObject->PositionSet(
                Move => 'relativ',
                Y    => -6,
            );

            # output title
            $PDFObject->Text(
                Text     => $Title,
                FontSize => 13,
            );

            $PDFObject->PositionSet(
                Move => 'relativ',
                Y    => -6,
            );

            # output "printed by"
            $PDFObject->Text(
                Text => $PrintedBy . ' '
                    . $Self->{UserFullname} . ' '
                    . $Time,
                FontSize => 9,
            );

            $PDFObject->PositionSet(
                Move => 'relativ',
                Y    => -14,
            );

            PAGE:
            for my $Count ( 2 .. $MaxPages ) {

                # output table (or a fragment of it)
                %TableParam = $PDFObject->Table(%TableParam);

                # stop output or another page
                if ( $TableParam{State} ) {
                    last PAGE;
                }
                else {
                    $PDFObject->PageNew(
                        %PageParam,
                        FooterRight => $Page . ' ' . $Count,
                    );
                }
            }

            # return the pdf document
            my $Filename = 'configitem_search';
            my ( $s, $m, $h, $D, $M, $Y ) = $TimeObject->SystemTime2Date(
                SystemTime => $TimeObject->SystemTime(),
            );
            $M = sprintf( "%02d", $M );
            $D = sprintf( "%02d", $D );
            $h = sprintf( "%02d", $h );
            $m = sprintf( "%02d", $m );
            my $PDFString = $PDFObject->DocumentOutput();
            return $LayoutObject->Attachment(
                Filename    => $Filename . "_" . "$Y-$M-$D" . "_" . "$h-$m.pdf",
                ContentType => "application/pdf",
                Content     => $PDFString,
                Type        => 'inline',
            );
        }

        # normal HTML output
        else {

            # start html page
            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $LayoutObject->Print( Output => \$Output );
            $Output = '';

            $Self->{Filter} = $ParamObject->GetParam( Param => 'Filter' ) || '';
            $Self->{View}   = $ParamObject->GetParam( Param => 'View' )   || '';

            # show config items
            my $LinkPage = 'Filter='
                . $LayoutObject->Ascii2Html( Text => $Self->{Filter} )
                . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
                . ';SortBy=' . $LayoutObject->Ascii2Html( Text => $Self->{SortBy} )
                . ';OrderBy='
                . $LayoutObject->Ascii2Html( Text => $Self->{OrderBy} )
                . ';Profile=' . $Self->{Profile} . ';TakeLastSearch=1;Subaction=Search'
                . ';ClassID=' . $ClassID
                . ';';
            my $LinkSort = 'Filter='
                . $LayoutObject->Ascii2Html( Text => $Self->{Filter} )
                . ';View=' . $LayoutObject->Ascii2Html( Text => $Self->{View} )
                . ';Profile=' . $Self->{Profile} . ';TakeLastSearch=1;Subaction=Search'
                . ';ClassID=' . $ClassID
                . ';';
            my $LinkFilter = 'TakeLastSearch=1;Subaction=Search;Profile='
                . $LayoutObject->Ascii2Html( Text => $Self->{Profile} )
                . ';ClassID='
                . $LayoutObject->Ascii2Html( Text => $ClassID )
                . ';';
            my $LinkBack = 'Subaction=LoadProfile;Profile='
                . $LayoutObject->Ascii2Html( Text => $Self->{Profile} )
                . ';ClassID='
                . $LayoutObject->Ascii2Html( Text => $ClassID )
                . ';TakeLastSearch=1;';

            # find out which columns should be shown
            my @ShowColumns;
            if ( $Self->{Config}->{ShowColumns} ) {

                # get all possible columns from config
                my %PossibleColumn = %{ $Self->{Config}->{ShowColumns} };

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
                && $ClassID
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
                my $SelectedClass = $ClassList->{$ClassID};
                if ( $ColumnByClass{$SelectedClass} ) {
                    @ShowColumns = @{ $ColumnByClass{$SelectedClass} };
                }
            }

            # KIX4OTRS-capeIT
            # my $ClassName = $ClassList->{$ClassID};
            my $ClassName;
            if ( $ClassID ne 'All' ) {
                $ClassName = $ClassList->{$ClassID};
            }
            else {
                $ClassName = $ClassID;
            }

            # EO KIX4OTRS-capeIT

            my $Title
                = $LayoutObject->{LanguageObject}->Translate('Config Item Search Results')
                . ' '
                . $LayoutObject->{LanguageObject}->Translate('Class')
                . ' '
                . $LayoutObject->{LanguageObject}->Translate($ClassName);

            $Output .= $LayoutObject->ITSMConfigItemListShow(
                ConfigItemIDs => $SearchResultList,
                Total         => scalar @{$SearchResultList},
                View          => $Self->{View},
                Filter        => $ClassID,
                Env           => $Self,
                LinkPage      => $LinkPage,
                LinkSort      => $LinkSort,
                LinkFilter    => $LinkFilter,
                LinkBack      => $LinkBack,
                Profile       => $Self->{Profile},
                TitleName     => $Title,
                ShowColumns   => \@ShowColumns,
                SortBy        => $LayoutObject->Ascii2Html( Text => $Self->{SortBy} ),
                OrderBy       => $LayoutObject->Ascii2Html( Text => $Self->{OrderBy} ),
                ClassID       => $ClassID,

                # KIX4OTRS-capeIT
                ClassList => $ClassList,

                # EO KIX4OTRS-capeIT
            );

            # build footer
            $Output .= $LayoutObject->Footer();

            return $Output;
        }
    }

    # ------------------------------------------------------------ #
    # call search dialog from search empty screen
    # ------------------------------------------------------------ #
    else {

        # show default search screen
        $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $LayoutObject->Block(
            Name => 'Search',
            Data => {
                Profile => $Self->{Profile},
                ClassID => $ClassID,
            },
        );

        # output template
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AgentITSMConfigItemSearch',
        );

        # output footer
        $Output .= $LayoutObject->Footer();

        return $Output;
    }
}

sub _XMLSearchFormOutput {
    my ( $Self, %Param ) = @_;

    my %GetParam = %{ $Param{GetParam} };

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLAttributes} ne 'ARRAY';

    $Param{Level} ||= 0;
    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # set prefix
        my $InputKey = $Item->{Key};
        my $Name     = $Item->{Name};
        if ( $Param{Prefix} ) {
            $InputKey = $Param{Prefix} . '::' . $InputKey;
            $Name     = $Param{PrefixName} . '::' . $Name;
        }

        # KIX4OTRS-capeIT
        # check if attribute is in xml attribute array and remove it if found
        my $Found = 0;
        my $Position = -1;
        for my $AttributeHash ( @{ $Param{XMLAttributes} } ) {
            $Position++;
            next if $AttributeHash->{Key} ne $InputKey;
            $Found = 1;
            splice(@{ $Param{XMLAttributes} },$Position,1);
            last;
        }

        # EO KIX4OTRS-capeIT

        # output attribute, if marked as searchable
        # KIX4OTRS-capeIT
        # if ( $Item->{Searchable} ) {
        if ( $Item->{Searchable} && $Found ) {

            # EO KIX4OTRS-capeIT
            my $Value;

            # date type fields must to get all date parameters
            if ( $Item->{Input}->{Type} eq 'Date' ) {
                $Value =
                    {
                    $InputKey                      => $GetParam{$InputKey},
                    $InputKey . '::TimeStart::Day' => $GetParam{ $InputKey . '::TimeStart::Day' },
                    $InputKey
                        . '::TimeStart::Month' => $GetParam{ $InputKey . '::TimeStart::Month' },
                    $InputKey . '::TimeStart::Year' => $GetParam{ $InputKey . '::TimeStart::Year' },
                    $InputKey . '::TimeStop::Day'   => $GetParam{ $InputKey . '::TimeStop::Day' },
                    $InputKey . '::TimeStop::Month' => $GetParam{ $InputKey . '::TimeStop::Month' },
                    $InputKey . '::TimeStop::Year'  => $GetParam{ $InputKey . '::TimeStop::Year' },
                    } || '';
            }

            # date-time type fields must get all date and time parameters
            elsif ( $Item->{Input}->{Type} eq 'DateTime' ) {
                $Value =
                    {
                    $InputKey => $GetParam{$InputKey},
                    $InputKey
                        . '::TimeStart::Minute' => $GetParam{ $InputKey . '::TimeStart::Minute' },
                    $InputKey . '::TimeStart::Hour' => $GetParam{ $InputKey . '::TimeStart::Hour' },
                    $InputKey . '::TimeStart::Day'  => $GetParam{ $InputKey . '::TimeStart::Day' },
                    $InputKey
                        . '::TimeStart::Month' => $GetParam{ $InputKey . '::TimeStart::Month' },
                    $InputKey . '::TimeStart::Year' => $GetParam{ $InputKey . '::TimeStart::Year' },
                    $InputKey
                        . '::TimeStop::Minute' => $GetParam{ $InputKey . '::TimeStop::Minute' },
                    $InputKey . '::TimeStop::Hour'  => $GetParam{ $InputKey . '::TimeStop::Hour' },
                    $InputKey . '::TimeStop::Day'   => $GetParam{ $InputKey . '::TimeStop::Day' },
                    $InputKey . '::TimeStop::Month' => $GetParam{ $InputKey . '::TimeStop::Month' },
                    $InputKey . '::TimeStop::Year'  => $GetParam{ $InputKey . '::TimeStop::Year' },
                    } || '';
            }

            # other kinds of fields can get its value directly
            else {
                $Value = $GetParam{$InputKey} || '';
            }

            # get layout object
            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

            # create search input element
            my $InputString = $LayoutObject->ITSMConfigItemSearchInputCreate(
                Key   => $InputKey,
                Item  => $Item,
                Value => $Value,
            );

            # output attribute row
            $LayoutObject->Block(
                Name => 'AttributeRow',
                Data => {
                    Key         => $InputKey,
                    Name        => $Name,
                    Description => $Item->{Description} || $Item->{Name},
                    InputString => $InputString,
                },
            );

            # KIX4OTRS-capeIT
            # push @{ $Param{XMLAttributes} }, {
            #     Key   => $InputKey,
            #     Value => $Name,
            # };
            # EO KIX4OTRS-capeIT
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLSearchFormOutput(
            XMLDefinition => $Item->{Sub},
            XMLAttributes => $Param{XMLAttributes},
            Level         => $Param{Level} + 1,
            Prefix        => $InputKey,
            PrefixName    => $Name,
            GetParam      => \%GetParam,
        );
    }

    return 1;
}

sub _XMLSearchFormGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if !$Param{XMLFormData};
    return if !$Param{XMLGetParam};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLFormData} ne 'ARRAY';
    return if ref $Param{XMLGetParam} ne 'ARRAY';

    $Param{Level} ||= 0;

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create inputkey
        my $InputKey = $Item->{Key};
        if ( $Param{Prefix} ) {
            $InputKey = $Param{Prefix} . '::' . $InputKey;
        }

        # Date type fields must to get all date parameters.
        if ( $Item->{Input}->{Type} eq 'Date' && $Param{$InputKey} ) {
            $Param{$InputKey} =
                {
                $InputKey                      => $Param{$InputKey},
                $InputKey . '::TimeStart::Day' => $Param{ $InputKey . '::TimeStart::Day' },
                $InputKey
                    . '::TimeStart::Month' => $Param{ $InputKey . '::TimeStart::Month' },
                $InputKey . '::TimeStart::Year' => $Param{ $InputKey . '::TimeStart::Year' },
                $InputKey . '::TimeStop::Day'   => $Param{ $InputKey . '::TimeStop::Day' },
                $InputKey . '::TimeStop::Month' => $Param{ $InputKey . '::TimeStop::Month' },
                $InputKey . '::TimeStop::Year'  => $Param{ $InputKey . '::TimeStop::Year' },
                } || '';
        }

        # Date-time type fields must get all date and time parameters.
        elsif ( $Item->{Input}->{Type} eq 'DateTime' && $Param{$InputKey} ) {
            $Param{$InputKey} =
                {
                $InputKey => $Param{$InputKey},
                $InputKey
                    . '::TimeStart::Minute' => $Param{ $InputKey . '::TimeStart::Minute' },
                $InputKey . '::TimeStart::Hour' => $Param{ $InputKey . '::TimeStart::Hour' },
                $InputKey . '::TimeStart::Day'  => $Param{ $InputKey . '::TimeStart::Day' },
                $InputKey
                    . '::TimeStart::Month' => $Param{ $InputKey . '::TimeStart::Month' },
                $InputKey . '::TimeStart::Year' => $Param{ $InputKey . '::TimeStart::Year' },
                $InputKey
                    . '::TimeStop::Minute' => $Param{ $InputKey . '::TimeStop::Minute' },
                $InputKey . '::TimeStop::Hour'  => $Param{ $InputKey . '::TimeStop::Hour' },
                $InputKey . '::TimeStop::Day'   => $Param{ $InputKey . '::TimeStop::Day' },
                $InputKey . '::TimeStop::Month' => $Param{ $InputKey . '::TimeStop::Month' },
                $InputKey . '::TimeStop::Year'  => $Param{ $InputKey . '::TimeStop::Year' },
                } || '';
        }

        # get search form data
        my $Values = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->ITSMConfigItemSearchFormDataGet(
            Key   => $InputKey,
            Item  => $Item,
            Value => $Param{$InputKey},
        );

        # create search key
        my $SearchKey = $InputKey;
        $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;
        $SearchKey = "[1]{'Version'}[1]{'$SearchKey'}[%]{'Content'}";

        # ITSMConfigItemSearchFormDataGet() can return string, arrayref or hashref
        if ( ref $Values eq 'ARRAY' ) {

            # filter empty elements
            my @SearchValues = grep {$_} @{$Values};

            if (@SearchValues) {
                push @{ $Param{XMLFormData} }, {
                    $SearchKey => \@SearchValues,
                };

                push @{ $Param{XMLGetParam} }, {
                    $InputKey => \@SearchValues,
                };
            }

        }
        elsif ($Values) {

            # e.g. for Date between searches
            push @{ $Param{XMLFormData} }, {
                $SearchKey => $Values,
            };

            if ( ref $Values eq 'HASH' ) {
                if ( $Item->{Input}->{Type} eq 'Date' ) {
                    if ( $Values->{'-between'} ) {

                        # get time elemet values
                        my ( $StartDate, $StopDate ) = @{ $Values->{'-between'} };
                        my ( $StartYear, $StartMonth, $StartDay ) = split( /-/, $StartDate );
                        my ( $StopYear,  $StopMonth,  $StopDay )  = split( /-/, $StopDate );

                        # store time elment values
                        push @{ $Param{XMLGetParam} }, {
                            $InputKey                        => 1,
                            $InputKey . '::TimeStart::Day'   => $StartDay,
                            $InputKey . '::TimeStart::Month' => $StartMonth,
                            $InputKey . '::TimeStart::Year'  => $StartYear,
                            $InputKey . '::TimeStop::Day'    => $StopDay,
                            $InputKey . '::TimeStop::Month'  => $StopMonth,
                            $InputKey . '::TimeStop::Year'   => $StopYear,
                        };
                    }
                }
                elsif ( $Item->{Input}->{Type} eq 'DateTime' ) {
                    if ( $Values->{'-between'} ) {

                        # get time elemet values
                        my ( $StartDateTime, $StopDateTime ) = @{ $Values->{'-between'} };
                        my ( $StartDate, $StartTime ) = split( /\s/, $StartDateTime );
                        my ( $StartYear, $StartMonth,  $StartDay )    = split( /-/,  $StartDate );
                        my ( $StartHour, $StartMinute, $StartSecond ) = split( /\:/, $StartTime );

                        my ( $StopDate, $StopTime ) = split( /\s/, $StopDateTime );
                        my ( $StopYear, $StopMonth,  $StopDay )    = split( /-/,  $StopDate );
                        my ( $StopHour, $StopMinute, $StopSecond ) = split( /\:/, $StopTime );

                        # store time elment values
                        push @{ $Param{XMLGetParam} }, {
                            $InputKey                         => 1,
                            $InputKey . '::TimeStart::Minute' => $StartMinute,
                            $InputKey . '::TimeStart::Hour'   => $StartHour,
                            $InputKey . '::TimeStart::Day'    => $StartDay,
                            $InputKey . '::TimeStart::Month'  => $StartMonth,
                            $InputKey . '::TimeStart::Year'   => $StartYear,
                            $InputKey . '::TimeStop::Minute'  => $StopMinute,
                            $InputKey . '::TimeStop::Hour'    => $StopHour,
                            $InputKey . '::TimeStop::Day'     => $StopDay,
                            $InputKey . '::TimeStop::Month'   => $StopMonth,
                            $InputKey . '::TimeStop::Year'    => $StopYear,
                        };
                    }
                }
            }
            else {
                push @{ $Param{XMLGetParam} }, {
                    $InputKey => $Values,
                };
            }

        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLSearchFormGet(
            %Param,
            XMLDefinition => $Item->{Sub},
            XMLFormData   => $Param{XMLFormData},
            XMLGetParam   => $Param{XMLGetParam},
            Level         => $Param{Level} + 1,
            Prefix        => $InputKey,
        );
    }

    return 1;
}

sub _XMLSearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{XMLAttributes} ne 'ARRAY';

    $Param{Level} ||= 0;
    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # set prefix
        my $InputKey = $Item->{Key};
        my $Name     = $Item->{Name};
        if ( $Param{Prefix} ) {
            $InputKey = $Param{Prefix} . '::' . $InputKey;
            $Name     = $Param{PrefixName} . '::' . $Name;
        }

        # store attribute, if marked as searchable
        if ( $Item->{Searchable} ) {
            push @{ $Param{XMLAttributes} }, {
                Key   => $InputKey,
                Value => $Name,
            };
        }

        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_XMLSearchAttributesGet(
            XMLDefinition => $Item->{Sub},
            XMLAttributes => $Param{XMLAttributes},
            Level         => $Param{Level} + 1,
            Prefix        => $InputKey,
            PrefixName    => $Name,
        );
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
