# --
# Kernel/Modules/AdminDynamicFieldITSMConfigItem.pm - provides a dynamic fields config view for admins
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicFieldITSMConfigItem;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use URI::Escape qw(uri_unescape);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::DynamicField',
    'Kernel::System::Encode',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::TemplateGenerator',
    'Kernel::System::Valid',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    # create additional objects
    $Self->{ConfigObject}            = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}            = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{DynamicFieldObject}      = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{EncodeObject}            = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{GeneralCatalogObject}    = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{ITSMConfigItemObject}    = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{TemplateGeneratorObject} = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
    $Self->{ValidObject}             = $Kernel::OM->Get('Kernel::System::Valid');
    $Self->{ParamObject}             = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get configured object types
    $Self->{ObjectTypeConfig} = $Self->{ConfigObject}->Get('DynamicFields::ObjectType');

    # get the fields config
    $Self->{FieldTypeConfig} = $Self->{ConfigObject}->Get('DynamicFields::Driver') || {};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Self->{Subaction} eq 'Add' ) {
        return $Self->_Add(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        return $Self->_AddAction(
            %Param,
        );
    }
    if ( $Self->{Subaction} eq 'Change' ) {
        return $Self->_Change(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $Self->{LayoutObject}->ChallengeTokenCheck();

        return $Self->_ChangeAction(
            %Param,
        );
    }

    if ( $Self->{Subaction} eq 'DefaultValueSearch' ) {
        return $Self->_DefaultValueSearch(
            %Param,
        );
    }

    return $Self->{LayoutObject}->ErrorScreen(
        Message => "Undefined subaction.",
    );
}

sub _Add {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    for my $Needed (qw(ObjectType FieldType FieldOrder)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Need $Needed",
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName  = $Self->{FieldTypeConfig}->{ $GetParam{FieldType} }->{DisplayName}   || '';

    return $Self->_ShowScreen(
        %Param,
        %GetParam,
        Mode           => 'Add',
        ObjectTypeName => $ObjectTypeName,
        FieldTypeName  => $FieldTypeName,
    );
}

sub _AddAction {
    my ( $Self, %Param ) = @_;

    my %Errors;
    my %GetParam;

    for my $Needed (qw(Name Label FieldOrder)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = 'This field is required.';
        }
    }

    if ( $GetParam{Name} ) {

        # check if name is alphanumeric
        if ( $GetParam{Name} !~ m{\A (?: [a-zA-Z] | \d )+ \z}xms ) {

            # add server error error class
            $Errors{NameServerError} = 'ServerError';
            $Errors{NameServerErrorMessage} =
                'The field does not contain only ASCII letters and numbers.';
        }

        # get dynamic field list
        my $DynamicFieldsList = $Self->{DynamicFieldObject}->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        ) || {};

        # check if name is duplicated
        my %DynamicFieldsList = %{$DynamicFieldsList};
        %DynamicFieldsList = reverse %DynamicFieldsList;

        if ( $DynamicFieldsList{ $GetParam{Name} } ) {

            # add server error error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'There is another field with the same name.';
        }
    }

    if ( $GetParam{FieldOrder} ) {

        # check if field order is numeric and positive
        if ( $GetParam{FieldOrder} !~ m{\A (?: \d )+ \z}xms ) {

            # add server error error class
            $Errors{FieldOrderServerError}        = 'ServerError';
            $Errors{FieldOrderServerErrorMessage} = 'The field must be numeric.';
        }
    }

    # get 'normal' configuration params
    for my $ConfigParam (
        qw(
            ObjectType ObjectTypeName FieldType FieldTypeName ValidID
            Constrictions DisplayPattern MaxArraySize AgentLink CustomerLink
            MinQueryLength QueryDelay MaxQueryResult
        )
    ) {
        $GetParam{$ConfigParam} = $Self->{ParamObject}->GetParam( Param => $ConfigParam );
    }

    # get 'raw' configuration params
    for my $ConfigParam (
        qw(
            ItemSeparator
        )
    ) {
        $GetParam{$ConfigParam} = $Self->{ParamObject}->GetParam( Param => $ConfigParam, Raw => 1, );
    }

    # get 'array' configuration params
    for my $ConfigParam (
        qw(
            ITSMConfigItemClasses DeploymentStates DefaultValues
        )
    ) {
        my @Data = $Self->{ParamObject}->GetArray( Param => $ConfigParam );
        $GetParam{$ConfigParam} = \@Data;
    }

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ValidID",
        );
    }

    # set specific config
    my $FieldConfig = {
        ITSMConfigItemClasses => $GetParam{ITSMConfigItemClasses} || [],
        DeploymentStates      => $GetParam{DeploymentStates}      || [],
        Constrictions         => $GetParam{Constrictions}         || '',
        DisplayPattern        => $GetParam{DisplayPattern}        || '<CI_Name>',
        MaxArraySize          => $GetParam{MaxArraySize}          || '1',
        ItemSeparator         => $GetParam{ItemSeparator}         || ', ',
        DefaultValues         => $GetParam{DefaultValues}         || [],
        AgentLink             => $GetParam{AgentLink}             || '',
        CustomerLink          => $GetParam{CustomerLink}          || '',
        MinQueryLength        => $GetParam{MinQueryLength}        || 3,
        QueryDelay            => $GetParam{QueryDelay}            || 300,
        MaxQueryResult        => $GetParam{MaxQueryResult}        || 10,
    };

    # create a new field
    my $FieldID = $Self->{DynamicFieldObject}->DynamicFieldAdd(
        Name       => $GetParam{Name},
        Label      => $GetParam{Label},
        FieldOrder => $GetParam{FieldOrder},
        FieldType  => $GetParam{FieldType},
        ObjectType => $GetParam{ObjectType},
        Config     => $FieldConfig,
        ValidID    => $GetParam{ValidID},
        UserID     => $Self->{UserID},
    );

    if ( !$FieldID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not create the new field",
        );
    }

    return $Self->{LayoutObject}->Redirect(
        OP => "Action=AdminDynamicField",
    );
}

sub _Change {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    for my $Needed (qw(ObjectType FieldType)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $Self->{LayoutObject}->ErrorScreen(
                Message => "Need $Needed",
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName  = $Self->{FieldTypeConfig}->{ $GetParam{FieldType} }->{DisplayName}   || '';

    my $FieldID = $Self->{ParamObject}->GetParam( Param => 'ID' );

    if ( !$FieldID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ID",
        );
    }

    # get dynamic field data
    my $DynamicFieldData = $Self->{DynamicFieldObject}->DynamicFieldGet(
        ID => $FieldID,
    );

    # check for valid dynamic field configuration
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not get data for dynamic field $FieldID",
        );
    }

    return $Self->_ShowScreen(
        %Param,
        %GetParam,
        %{$DynamicFieldData},
        ID             => $FieldID,
        Mode           => 'Change',
        ObjectTypeName => $ObjectTypeName,
        FieldTypeName  => $FieldTypeName,
    );
}

sub _ChangeAction {
    my ( $Self, %Param ) = @_;

    my %Errors;
    my %GetParam;

    for my $Needed (qw(Name Label FieldOrder)) {
        $GetParam{$Needed} = $Self->{ParamObject}->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = 'This field is required.';
        }
    }

    my $FieldID = $Self->{ParamObject}->GetParam( Param => 'ID' );
    if ( !$FieldID ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ID",
        );
    }

    # get dynamic field data
    my $DynamicFieldData = $Self->{DynamicFieldObject}->DynamicFieldGet(
        ID => $FieldID,
    );

    # check for valid dynamic field configuration
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not get data for dynamic field $FieldID",
        );
    }

    if ( $GetParam{Name} ) {

        # check if name is lowercase
        if ( $GetParam{Name} !~ m{\A (?: [a-zA-Z] | \d )+ \z}xms ) {

            # add server error error class
            $Errors{NameServerError} = 'ServerError';
            $Errors{NameServerErrorMessage} =
                'The field does not contain only ASCII letters and numbers.';
        }

        # get dynamic field list
        my $DynamicFieldsList = $Self->{DynamicFieldObject}->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        ) || {};

        # check if name is duplicated
        my %DynamicFieldsList = %{$DynamicFieldsList};
        %DynamicFieldsList = reverse %DynamicFieldsList;

        if (
            $DynamicFieldsList{ $GetParam{Name} } &&
            $DynamicFieldsList{ $GetParam{Name} } ne $FieldID
            )
        {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'There is another field with the same name.';
        }

        # if it's an internal field, it's name should not change
        if (
            $DynamicFieldData->{InternalField} &&
            $DynamicFieldsList{ $GetParam{Name} } ne $FieldID
            )
        {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = 'The name for this field should not change.';
            $Param{InternalField}           = $DynamicFieldData->{InternalField};
        }
    }

    if ( $GetParam{FieldOrder} ) {

        # check if field order is numeric and positive
        if ( $GetParam{FieldOrder} !~ m{\A (?: \d )+ \z}xms ) {

            # add server error error class
            $Errors{FieldOrderServerError}        = 'ServerError';
            $Errors{FieldOrderServerErrorMessage} = 'The field must be numeric.';
        }
    }

    # get 'normal' configuration params
    for my $ConfigParam (
        qw(
            ObjectType ObjectTypeName FieldType FieldTypeName ValidID
            Constrictions DisplayPattern MaxArraySize AgentLink CustomerLink
            MinQueryLength QueryDelay MaxQueryResult
        )
    ) {
        $GetParam{$ConfigParam} = $Self->{ParamObject}->GetParam( Param => $ConfigParam );
    }

    # get 'raw' configuration params
    for my $ConfigParam (
        qw(
            ItemSeparator
        )
    ) {
        $GetParam{$ConfigParam} = $Self->{ParamObject}->GetParam( Param => $ConfigParam, Raw => 1, );
    }

    # get 'array' configuration params
    for my $ConfigParam (
        qw(
            ITSMConfigItemClasses DeploymentStates DefaultValues
        )
    ) {
        my @Data = $Self->{ParamObject}->GetArray( Param => $ConfigParam );
        $GetParam{$ConfigParam} = \@Data;
    }

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Need ValidID",
        );
    }

    # return to change screen if errors
    if (%Errors) {
        return $Self->_ShowScreen(
            %Param,
            %Errors,
            %GetParam,
            ID             => $FieldID,
            Mode           => 'Change',
        );
    }

    # set specific config
    my $FieldConfig = {
        ITSMConfigItemClasses => $GetParam{ITSMConfigItemClasses} || [],
        DeploymentStates      => $GetParam{DeploymentStates}      || [],
        Constrictions         => $GetParam{Constrictions}         || '',
        DisplayPattern        => $GetParam{DisplayPattern}        || '<CI_Name>',
        MaxArraySize          => $GetParam{MaxArraySize}          || '1',
        ItemSeparator         => $GetParam{ItemSeparator}         || ', ',
        DefaultValues         => $GetParam{DefaultValues}         || [],
        AgentLink             => $GetParam{AgentLink}             || '',
        CustomerLink          => $GetParam{CustomerLink}          || '',
        MinQueryLength        => $GetParam{MinQueryLength}        || 3,
        QueryDelay            => $GetParam{QueryDelay}            || 300,
        MaxQueryResult        => $GetParam{MaxQueryResult}        || 10,
    };

    # update dynamic field (FieldType and ObjectType cannot be changed; use old values)
    my $UpdateSuccess = $Self->{DynamicFieldObject}->DynamicFieldUpdate(
        ID         => $FieldID,
        Name       => $GetParam{Name},
        Label      => $GetParam{Label},
        FieldOrder => $GetParam{FieldOrder},
        FieldType  => $DynamicFieldData->{FieldType},
        ObjectType => $DynamicFieldData->{ObjectType},
        Config     => $FieldConfig,
        ValidID    => $GetParam{ValidID},
        UserID     => $Self->{UserID},
    );

    if ( !$UpdateSuccess ) {
        return $Self->{LayoutObject}->ErrorScreen(
            Message => "Could not update the field $GetParam{Name}",
        );
    }

    return $Self->{LayoutObject}->Redirect(
        OP => "Action=AdminDynamicField",
    );
}

sub _ShowScreen {
    my ( $Self, %Param ) = @_;

    $Param{DisplayFieldName} = 'New';

    if ( $Param{Mode} eq 'Change' ) {
        $Param{ShowWarning}      = 'ShowWarning';
        $Param{DisplayFieldName} = $Param{Name};
    }

    $Param{ITSMConfigItemClasses} = $Param{Config}->{ITSMConfigItemClasses} || [];
    $Param{DeploymentStates}      = $Param{Config}->{DeploymentStates}      || [];
    $Param{Constrictions}         = $Param{Config}->{Constrictions}         || '';
    $Param{DisplayPattern}        = $Param{Config}->{DisplayPattern}        || '<CI_Name>';
    $Param{MaxArraySize}          = $Param{Config}->{MaxArraySize}          || '1';
    $Param{ItemSeparator}         = $Param{Config}->{ItemSeparator}         || ', ';
    $Param{DefaultValues}         = $Param{Config}->{DefaultValues}         || [];
    $Param{AgentLink}             = $Param{Config}->{AgentLink}             || '';
    $Param{CustomerLink}          = $Param{Config}->{CustomerLink}          || '';
    $Param{MinQueryLength}        = $Param{Config}->{MinQueryLength}        || 3;
    $Param{QueryDelay}            = $Param{Config}->{QueryDelay}            || 300;
    $Param{MaxQueryResult}        = $Param{Config}->{MaxQueryResult}        || 10;

    # header
    my $Output = $Self->{LayoutObject}->Header();
    $Output   .= $Self->{LayoutObject}->NavigationBar();

    # get all fields
    my $DynamicFieldList = $Self->{DynamicFieldObject}->DynamicFieldListGet(
        Valid => 0,
    );

    # get the list of order numbers (is already sorted).
    my @DynamicfieldOrderList;
    my %DynamicfieldNamesList;
    for my $Dynamicfield ( @{$DynamicFieldList} ) {
        push @DynamicfieldOrderList, $Dynamicfield->{FieldOrder};
        $DynamicfieldNamesList{ $Dynamicfield->{FieldOrder} } = $Dynamicfield->{Label};
    }

    # when adding we need to create an extra order number for the new field
    if ( $Param{Mode} eq 'Add' ) {

        # get the last element form the order list and add 1
        my $LastOrderNumber = $DynamicfieldOrderList[-1];
        $LastOrderNumber++;

        # add this new order number to the end of the list
        push ( @DynamicfieldOrderList, $LastOrderNumber );
    }

    # show the names of the other fields to ease ordering
    my %OrderNamesList;
    my $CurrentlyText = $Self->{LayoutObject}->{LanguageObject}->Translate('Currently') . ': ';
    for my $OrderNumber ( sort @DynamicfieldOrderList ) {
        $OrderNamesList{$OrderNumber} = $OrderNumber;
        if ( $DynamicfieldNamesList{$OrderNumber} && $OrderNumber ne $Param{FieldOrder} ) {
            $OrderNamesList{$OrderNumber} = $OrderNumber . ' - '
                . $CurrentlyText
                . $DynamicfieldNamesList{$OrderNumber}
        }
    }

    my $DynamicFieldOrderStrg = $Self->{LayoutObject}->BuildSelection(
        Data          => \%OrderNamesList,
        Name          => 'FieldOrder',
        SelectedValue => $Param{FieldOrder} || 1,
        PossibleNone  => 0,
        Translation   => 0,
        Sort          => 'NumericKey',
        Class         => 'Modernize W75pc Validate_Number',
    );

    my %ValidList = $Self->{ValidObject}->ValidList();

    # create the Validity select
    my $ValidityStrg = $Self->{LayoutObject}->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $Param{ValidID} || 1,
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'Modernize W50pc',
    );

    ## Field Configurations
    # ITSMConfigItemClasses - ARRAY
    my $ClassRef = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );
    my $ITSMConfigItemClassesStrg = $Self->{LayoutObject}->BuildSelection(
        Data         => \%{$ClassRef},
        Name         => 'ITSMConfigItemClasses',
        SelectedID   => $Param{ITSMConfigItemClasses},
        PossibleNone => 0,
        Translation  => 0,
        Multiple     => 1,
        Class        => 'W50pc',
    );

    # DeploymentStates - ARRAY
    my $DeploymentRef = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );
    my $DeploymentStatesStrg = $Self->{LayoutObject}->BuildSelection(
        Data         => \%{$DeploymentRef},
        Name         => 'DeploymentStates',
        SelectedID   => $Param{DeploymentStates},
        PossibleNone => 0,
        Translation  => 0,
        Multiple     => 1,
        Class        => 'W50pc',
    );

    # Constrictions
    # nothing to do

    # DisplayPattern
    # nothing to do

    # MaxArraySize
    # nothing to do

    # ItemSeparator
    my $ItemSeparatorStrg = $Self->{LayoutObject}->BuildSelection(
        Data => {
            ', ' => 'Comma (,)',
            '; ' => 'Semicolon (;)',
            ' '  => 'Whitespace ( )',
        },
        Name         => 'ItemSeparator',
        SelectedID   => $Param{ItemSeparator},
        PossibleNone => 0,
        Translation  => 1,
        Multiple     => 0,
        Class        => 'Modernize W50pc',
    );

    # DefaultValues
    my $DefaultValuesCount = 0;
    for my $Key ( @{ $Param{DefaultValues} } ) {
        next if (!$Key);
        $DefaultValuesCount++;

        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $Label = $Param{DisplayPattern} || '<CI_Name>';
        while ($Label =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $Label =~ s/<CI_$1>/$Replace/g;
        }

        $Self->{LayoutObject}->Block(
            Name => 'DefaultValue',
            Data => {
                DefaultValue => $Key,
                Label        => $Label,
                ValueCounter => $DefaultValuesCount,
            },
        );
    }

    # AgentLink
    # nothing to do

    # CustomerLink
    # nothing to do

    # MinQueryLength
    # nothing to do

    # QueryDelay
    # nothing to do

    # MaxQueryResult
    # nothing to do

    # Internal fields can not be deleted and name should not change.
    if ( $Param{InternalField} ) {
        $Self->{LayoutObject}->Block(
            Name => 'InternalField',
            Data => {%Param},
        );
    }

    # generate output
    $Output .= $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminDynamicFieldITSMConfigItem',
        Data => {
            %Param,
            ValidityStrg              => $ValidityStrg,
            DynamicFieldOrderStrg     => $DynamicFieldOrderStrg,
            ITSMConfigItemClassesStrg => $ITSMConfigItemClassesStrg,
            DeploymentStatesStrg      => $DeploymentStatesStrg,
            ItemSeparatorStrg         => $ItemSeparatorStrg,
            DefaultValuesCount        => $DefaultValuesCount,
        }
    );

    $Output .= $Self->{LayoutObject}->Footer();

    return $Output;
}

sub _DefaultValueSearch {
    my ( $Self, %Param ) = @_;

    # get search
    my $Search = $Self->{ParamObject}->GetParam( Param => 'Search' ) || '';
    $Search = '*' . $Search . '*';
    $Self->{EncodeObject}->EncodeInput( \$Search );

    # get used ITSMConfigItemClasses
    my @ITSMConfigItemClasses = $Self->{ParamObject}->GetArray( Param => 'ITSMConfigItemClasses' );

    # get used DeploymentStates
    my @DeploymentStates = $Self->{ParamObject}->GetArray( Param => 'DeploymentStates' );

    # get used Constrictions
    my $Constrictions = $Self->{ParamObject}->GetParam( Param => 'Constrictions' ) || '';

    # get display type
    my $DisplayPattern = uri_unescape($Self->{ParamObject}->GetParam( Param => 'DisplayPattern' )) || '<CI_Name>';

    # get used entries
    my @Entries = $Self->{ParamObject}->GetArray( Param => 'DefaultValues' );

    # build search params from constrictions...
    my @SearchParamsWhat;

    # prepare constrictions
    my %Constrictions = ();
    if ( $Constrictions ) {
        my @Constrictions = split(/[\n\r]+/, $Constrictions);
        RESTRICTION:
        for my $Constriction ( @Constrictions ) {
            my @ConstrictionRule = split(/::/, $Constriction);
            # check for valid constriction
            next RESTRICTION if (
                scalar(@ConstrictionRule) != 4
                || $ConstrictionRule[0] eq ""
                || $ConstrictionRule[1] eq ""
                || $ConstrictionRule[2] eq ""
            );

            # only handle static constrictions in admininterface
            if (
                $ConstrictionRule[1] eq 'Configuration'
            ) {
                $Constrictions{$ConstrictionRule[0]} = $ConstrictionRule[2];
            }
        }
    }

    if ( !scalar(@ITSMConfigItemClasses) ) {
        my $ClassRef = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );
        for my $ClassID ( keys ( %{$ClassRef} ) ) {
            push ( @ITSMConfigItemClasses, $ClassID );
        }
    }

    for my $ClassID (@ITSMConfigItemClasses) {
        # get current definition
        my $XMLDefinition = $Self->{ITSMConfigItemObject}->DefinitionGet(
            ClassID => $ClassID,
        );

        # prepare seach
        $Self->_ExportXMLSearchDataPrepare(
            XMLDefinition => $XMLDefinition->{DefinitionRef},
            What          => \@SearchParamsWhat,
            SearchData    => {
                %Constrictions,
            },
        );
    }

    my %ConfigItemIDs;
    my $ConfigItemIDs = $Self->{ITSMConfigItemObject}->ConfigItemSearchExtended(
        Name         => $Search,
        ClassIDs     => \@ITSMConfigItemClasses,
        DeplStateIDs => \@DeploymentStates,
        What         => \@SearchParamsWhat,
    );

    for my $ID ( @{$ConfigItemIDs} ) {
        $ConfigItemIDs{$ID} = 1;
    }

    $ConfigItemIDs = $Self->{ITSMConfigItemObject}->ConfigItemSearchExtended(
        Number       => $Search,
        ClassIDs     => \@ITSMConfigItemClasses,
        DeplStateIDs => \@DeploymentStates,
        What         => \@SearchParamsWhat,
    );

    for my $ID ( @{$ConfigItemIDs} ) {
        $ConfigItemIDs{$ID} = 1;
    }

    my @PossibleValues;
    my $MaxCount = 1;
    CIID:
    for my $Key ( sort keys %ConfigItemIDs ) {
        next CIID if ( grep { /^$Key$/ } @Entries );

        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $Label = $DisplayPattern || '<CI_Name>';
        while ($Label =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $Label =~ s/<CI_$1>/$Replace/g;
        }

        my $Title = $ConfigItem->{Name};

        push (
            @PossibleValues,
            {
                Key    => $Key,
                Value  => $Label,
                Search => $Param{Search},
                Label  => $Label,
                Title  => $Title,
            }
        );
        last CIID if ($MaxCount == 25);
        $MaxCount++;
    }

    # build JSON output
    my $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => \@PossibleValues,
    );

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _ExportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{What}          || ref $Param{What}          ne 'ARRAY';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};
        my $DataKey = $Item->{Key};

        # prepare value
        my $Values = $Param{SearchData}->{$DataKey};
        if ($Values) {

            # create search key
            my $SearchKey = $Key;
            $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;

            # create search hash
            my $SearchHash = {
                '[1]{\'Version\'}[1]{\''
                    . $SearchKey
                    . '\'}[%]{\'Content\'}' => $Values,
            };
            push @{ $Param{What} }, $SearchHash;
        }
        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_ExportXMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            SearchData    => $Param{SearchData},
            Prefix        => $Key,
        );
    }

    return 1;
}

1;
