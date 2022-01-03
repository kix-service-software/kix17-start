# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicFieldITSMConfigItem;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);
use URI::Escape qw(uri_unescape);
use Kernel::Language qw(Translatable);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    if ( $Self->{Subaction} eq 'Add' ) {
        return $Self->_Add(
            %Param,
        );
    }
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

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
        $LayoutObject->ChallengeTokenCheck();

        return $Self->_ChangeAction(
            %Param,
        );
    }

    if ( $Self->{Subaction} eq 'DefaultValueSearch' ) {
        return $Self->_DefaultValueSearch(
            %Param,
        );
    }

    return $LayoutObject->ErrorScreen(
        Message => "Undefined subaction.",
    );
}

sub _Add {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %GetParam;
    for my $Needed (qw(ObjectType FieldType FieldOrder)) {
        $GetParam{$Needed} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate( 'Need %s', $Needed ),
            );
        }
    }

    # get the object type and field type display name
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ObjectTypeName
        = $ConfigObject->Get('DynamicFields::ObjectType')->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName = $ConfigObject->Get('DynamicFields::Driver')->{ $GetParam{FieldType} }->{DisplayName} || '';

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
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    for my $Needed (qw(Name Label FieldOrder)) {
        $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed );
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
        my $DynamicFieldsList = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldList(
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
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam );
    }

    # get 'raw' configuration params
    for my $ConfigParam (
        qw(
            ItemSeparator
        )
    ) {
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam, Raw => 1, );
    }

    # get 'array' configuration params
    for my $ConfigParam (
        qw(
            ITSMConfigItemClasses DeploymentStates DefaultValues PermissionCheck
        )
    ) {
        my @Data = $ParamObject->GetArray( Param => $ConfigParam );
        $GetParam{$ConfigParam} = \@Data;
    }

    # get ValueTTL
    for my $ConfigParam (qw(ValueTTLData ValueTTLMultiplier)) {
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam );
    }
    if (
        $GetParam{'ValueTTLData'}
        && $GetParam{'ValueTTLMultiplier'}
    ) {
        $GetParam{'ValueTTL'} = $GetParam{'ValueTTLData'} * $GetParam{'ValueTTLMultiplier'};
    }
    else {
        $GetParam{'ValueTTL'} = 0;
    }

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $LayoutObject->ErrorScreen(
            Message => "Need ValidID",
        );
    }

    # set specific config
    my $FieldConfig = {
        ITSMConfigItemClasses => $GetParam{ITSMConfigItemClasses} || [],
        DeploymentStates      => $GetParam{DeploymentStates}      || [],
        PermissionCheck       => $GetParam{PermissionCheck}       || [],
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

    # get ValueTTL config
    for my $ConfigParam (qw(ValueTTL ValueTTLData ValueTTLMultiplier)) {
        $FieldConfig->{$ConfigParam} = $GetParam{$ConfigParam};
    }

    # create a new field
    my $FieldID = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldAdd(
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
        return $LayoutObject->ErrorScreen(
            Message => "Could not create the new field",
        );
    }

    return $LayoutObject->Redirect(
        OP => "Action=AdminDynamicField",
    );
}

sub _Change {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %GetParam;
    for my $Needed (qw(ObjectType FieldType)) {
        $GetParam{$Needed} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Needed );
        if ( !$Needed ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate( 'Need %s', $Needed ),
            );
        }
    }

    # get the object type and field type display name
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ObjectTypeName
        = $ConfigObject->Get('DynamicFields::ObjectType')->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName = $ConfigObject->Get('DynamicFields::Driver')->{ $GetParam{FieldType} }->{DisplayName} || '';

    my $FieldID = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'ID' );

    if ( !$FieldID ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Need ID'),
        );
    }

    # get dynamic field data
    my $DynamicFieldData = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
        ID => $FieldID,
    );

    # check for valid dynamic field configuration
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $LayoutObject->ErrorScreen(
            Message =>
                $LayoutObject->{LanguageObject}->Translate( 'Could not get data for dynamic field %s', $FieldID ),
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

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my %Errors;
    my %GetParam;

    for my $Needed (qw(Name Label FieldOrder)) {
        $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = Translatable('This field is required.');
        }
    }

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $FieldID = $ParamObject->GetParam( Param => 'ID' );
    if ( !$FieldID ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Need ID'),
        );
    }

    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField');

    # get dynamic field data
    my $DynamicFieldData = $DynamicField->DynamicFieldGet(
        ID => $FieldID,
    );

    # check for valid dynamic field configuration
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $LayoutObject->ErrorScreen(
            Message =>
                $LayoutObject->{LanguageObject}->Translate( 'Could not get data for dynamic field %s', $FieldID ),
        );
    }

    if ( $GetParam{Name} ) {

        # check if name is lowercase
        if ( $GetParam{Name} !~ m{\A (?: [a-zA-Z] | \d )+ \z}xms ) {

            # add server error error class
            $Errors{NameServerError} = 'ServerError';
            $Errors{NameServerErrorMessage} =
                Translatable('The field does not contain only ASCII letters and numbers.');
        }

        # get dynamic field list
        my $DynamicFieldsList = $DynamicField->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        ) || {};

        # check if name is duplicated
        my %DynamicFieldsList = %{$DynamicFieldsList};
        %DynamicFieldsList = reverse %DynamicFieldsList;

        if (
            $DynamicFieldsList{ $GetParam{Name} } &&
            $DynamicFieldsList{ $GetParam{Name} } ne $FieldID
        ) {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = Translatable('There is another field with the same name.');
        }

        # if it's an internal field, it's name should not change
        if (
            $DynamicFieldData->{InternalField} &&
            $DynamicFieldsList{ $GetParam{Name} } ne $FieldID
        ) {

            # add server error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = Translatable('The name for this field should not change.');
            $Param{InternalField}           = $DynamicFieldData->{InternalField};
        }
    }

    if ( $GetParam{FieldOrder} ) {

        # check if field order is numeric and positive
        if ( $GetParam{FieldOrder} !~ m{\A (?: \d )+ \z}xms ) {

            # add server error error class
            $Errors{FieldOrderServerError}        = 'ServerError';
            $Errors{FieldOrderServerErrorMessage} = Translatable('The field must be numeric.');
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
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam );
    }

    # get 'raw' configuration params
    for my $ConfigParam (
        qw(
            ItemSeparator
        )
    ) {
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam, Raw => 1, );
    }

    # get 'array' configuration params
    for my $ConfigParam (
        qw(
            ITSMConfigItemClasses DeploymentStates DefaultValues PermissionCheck
        )
    ) {
        my @Data = $ParamObject->GetArray( Param => $ConfigParam );
        $GetParam{$ConfigParam} = \@Data;
    }
    # get ValueTTL
    for my $ConfigParam (qw(ValueTTLData ValueTTLMultiplier)) {
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam );
    }
    if (
        $GetParam{'ValueTTLData'}
        && $GetParam{'ValueTTLMultiplier'}
    ) {
        $GetParam{'ValueTTL'} = $GetParam{'ValueTTLData'} * $GetParam{'ValueTTLMultiplier'};
    }
    else {
        $GetParam{'ValueTTL'} = 0;
    }

    # uncorrectable errors
    if ( !$GetParam{ValidID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Need ValidID'),
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
        PermissionCheck       => $GetParam{PermissionCheck}       || [],
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

    # get ValueTTL config
    for my $ConfigParam (qw(ValueTTL ValueTTLData ValueTTLMultiplier)) {
        $FieldConfig->{$ConfigParam} = $GetParam{$ConfigParam};
    }

    # update dynamic field (FieldType and ObjectType cannot be changed; use old values)
    my $UpdateSuccess = $DynamicField->DynamicFieldUpdate(
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
        return $LayoutObject->ErrorScreen(
            Message => $LayoutObject->{LanguageObject}->Translate( 'Could not update the field %s', $GetParam{Name} ),
        );
    }

    return $LayoutObject->Redirect(
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

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $Param{ITSMConfigItemClasses} = $Param{Config}->{ITSMConfigItemClasses} || [];
    $Param{DeploymentStates}      = $Param{Config}->{DeploymentStates}      || [];
    $Param{PermissionCheck}       = $Param{Config}->{PermissionCheck}       || [];
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
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    # get all fields
    my $DynamicFieldList = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
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
    my $CurrentlyText = $LayoutObject->{LanguageObject}->Translate('Currently') . ': ';
    for my $OrderNumber ( sort @DynamicfieldOrderList ) {
        $OrderNamesList{$OrderNumber} = $OrderNumber;
        if ( $DynamicfieldNamesList{$OrderNumber} && $OrderNumber ne $Param{FieldOrder} ) {
            $OrderNamesList{$OrderNumber} = $OrderNumber . ' - '
                . $CurrentlyText
                . $DynamicfieldNamesList{$OrderNumber}
        }
    }

    my $DynamicFieldOrderStrg = $LayoutObject->BuildSelection(
        Data          => \%OrderNamesList,
        Name          => 'FieldOrder',
        SelectedValue => $Param{FieldOrder} || 1,
        PossibleNone  => 0,
        Translation   => 0,
        Sort          => 'NumericKey',
        Class         => 'Modernize W75pc Validate_Number',
    );

    my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

    # create the Validity select
    my $ValidityStrg = $LayoutObject->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $Param{ValidID} || 1,
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'Modernize W50pc',
    );

    ## Field Configurations
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    # ITSMConfigItemClasses - ARRAY
    my $ClassRef = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );
    my $ITSMConfigItemClassesStrg = $LayoutObject->BuildSelection(
        Data         => \%{$ClassRef},
        Name         => 'ITSMConfigItemClasses',
        SelectedID   => $Param{ITSMConfigItemClasses},
        PossibleNone => 0,
        Translation  => 0,
        Multiple     => 1,
        Class        => 'W50pc',
    );

    # DeploymentStates - ARRAY
    my $DeploymentRef = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );
    my $DeploymentStatesStrg = $LayoutObject->BuildSelection(
        Data         => \%{$DeploymentRef},
        Name         => 'DeploymentStates',
        SelectedID   => $Param{DeploymentStates},
        PossibleNone => 0,
        Translation  => 0,
        Multiple     => 1,
        Class        => 'W50pc',
    );

    my $PermissionCheckStrg = $LayoutObject->BuildSelection(
        Data         => [
            'Agent',
            'Customer'
        ],
        Name         => 'PermissionCheck',
        SelectedID   => $Param{PermissionCheck},
        PossibleNone => 0,
        Translation  => 1,
        Multiple     => 1,
        Size         => 2,
        Class        => 'Modernize',
    );

    # Constrictions
    # nothing to do

    # DisplayPattern
    # nothing to do

    # MaxArraySize
    # nothing to do

    # ItemSeparator
    my $ItemSeparatorStrg = $LayoutObject->BuildSelection(
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

        my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $Label = $Param{DisplayPattern} || '<CI_Name>';
        while ($Label =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $Label =~ s/<CI_$1>/$Replace/g;
        }

        $LayoutObject->Block(
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

    my $ReadonlyInternalField = '';

    # Internal fields can not be deleted and name should not change.
    if ( $Param{InternalField} ) {
        $LayoutObject->Block(
            Name => 'InternalField',
            Data => {%Param},
        );
        $ReadonlyInternalField = 'readonly="readonly"';
    }

    # create the value ttl multiplier select
    $Param{ValueTTLMultiplierStrg} = $LayoutObject->BuildSelection(
        Data => {
            60       => Translatable('Minutes'),
            3600     => Translatable('Hours'),
            86400    => Translatable('Days'),
            31536000 => Translatable('Years'),
        },
        Name         => 'ValueTTLMultiplier',
        SelectedID   => $Param{ValueTTLMultiplier} || 60,
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'Modernize',
    );

    # generate output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminDynamicFieldITSMConfigItem',
        Data => {
            %Param,
            ValidityStrg              => $ValidityStrg,
            DynamicFieldOrderStrg     => $DynamicFieldOrderStrg,
            ITSMConfigItemClassesStrg => $ITSMConfigItemClassesStrg,
            PermissionCheckStrg       => $PermissionCheckStrg,
            DeploymentStatesStrg      => $DeploymentStatesStrg,
            ItemSeparatorStrg         => $ItemSeparatorStrg,
            DefaultValuesCount        => $DefaultValuesCount,
            ReadonlyInternalField     => $ReadonlyInternalField,
        }
    );

    $Output .= $LayoutObject->Footer();

    return $Output;
}

sub _DefaultValueSearch {
    my ( $Self, %Param ) = @_;

    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ITSMConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get search
    my $Search = $ParamObject->GetParam( Param => 'Search' ) || '';
    $Search = '*' . $Search . '*';
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$Search );

    # get used ITSMConfigItemClasses
    my @ITSMConfigItemClasses = $ParamObject->GetArray( Param => 'ITSMConfigItemClasses' );

    # get used DeploymentStates
    my @DeploymentStates = $ParamObject->GetArray( Param => 'DeploymentStates' );

    # get used Constrictions
    my $Constrictions = $ParamObject->GetParam( Param => 'Constrictions' ) || '';

    # get display type
    my $DisplayPattern = uri_unescape($ParamObject->GetParam( Param => 'DisplayPattern' )) || '<CI_Name>';

    # get used entries
    my @Entries = $ParamObject->GetArray( Param => 'DefaultValues' );

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
        my $ClassRef = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );
        for my $ClassID ( keys ( %{$ClassRef} ) ) {
            push ( @ITSMConfigItemClasses, $ClassID );
        }
    }

    for my $ClassID (@ITSMConfigItemClasses) {
        # get current definition
        my $XMLDefinition = $ITSMConfigItemObject->DefinitionGet(
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
    my $ConfigItemIDs = $ITSMConfigItemObject->ConfigItemSearchExtended(
        Name         => $Search,
        ClassIDs     => \@ITSMConfigItemClasses,
        DeplStateIDs => \@DeploymentStates,
        What         => \@SearchParamsWhat,
    );

    for my $ID ( @{$ConfigItemIDs} ) {
        $ConfigItemIDs{$ID} = 1;
    }

    $ConfigItemIDs = $ITSMConfigItemObject->ConfigItemSearchExtended(
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

        my $ConfigItem = $ITSMConfigItemObject->VersionGet(
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
    my $JSON = $LayoutObject->JSONEncode(
        Data => \@PossibleValues,
    );

    # send JSON response
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
