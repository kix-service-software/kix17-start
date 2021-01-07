# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicFieldRemoteDB;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::DFRemoteDB;
use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

use URI::Escape qw(uri_unescape);

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
        SearchSuffix   => '*',
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

    for my $Needed (qw(Name Label FieldOrder MaxArraySize DatabaseDSN DatabaseUser DatabasePw DatabaseTable DatabaseFieldKey)) {
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
            DatabaseType DatabaseFieldValue CacheTTL CachePossibleValues
            ShowKeyInTitle AgentLink CustomerLink
            DatabaseFieldSearch SearchPrefix SearchSuffix Constrictions
            MinQueryLength QueryDelay MaxQueryResult CaseSensitive
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
            DefaultValues
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
        DatabaseDSN         => $GetParam{DatabaseDSN},
        DatabaseUser        => $GetParam{DatabaseUser},
        DatabasePw          => $GetParam{DatabasePw},
        DatabaseType        => lc $GetParam{DatabaseType}     || '',
        DatabaseTable       => $GetParam{DatabaseTable},
        DatabaseFieldKey    => $GetParam{DatabaseFieldKey},
        DatabaseFieldValue  => $GetParam{DatabaseFieldValue}  || $GetParam{DatabaseFieldKey},
        DatabaseFieldSearch => $GetParam{DatabaseFieldSearch} || $GetParam{DatabaseFieldKey},
        SearchPrefix        => $GetParam{SearchPrefix}        || '',
        SearchSuffix        => $GetParam{SearchSuffix}        || '',
        MaxArraySize        => $GetParam{MaxArraySize}        || 1,
        CacheTTL            => $GetParam{CacheTTL}            || 0,
        CachePossibleValues => $GetParam{CachePossibleValues} || 0,
        ShowKeyInTitle      => $GetParam{ShowKeyInTitle}      || 0,
        ItemSeparator       => $GetParam{ItemSeparator}       || ', ',
        AgentLink           => $GetParam{AgentLink}           || '',
        CustomerLink        => $GetParam{CustomerLink}        || '',
        Constrictions       => $GetParam{Constrictions}       || '',
        MinQueryLength      => $GetParam{MinQueryLength}      || 3,
        QueryDelay          => $GetParam{QueryDelay}          || 300,
        MaxQueryResult      => $GetParam{MaxQueryResult}      || 10,
        CaseSensitive       => $GetParam{CaseSensitive},
        DefaultValues       => $GetParam{DefaultValues}       || [],
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

    for my $Needed (qw(Name Label FieldOrder MaxArraySize DatabaseDSN DatabaseUser DatabasePw DatabaseTable DatabaseFieldKey)) {
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
            DatabaseType DatabaseFieldValue CacheTTL CachePossibleValues
            ShowKeyInTitle AgentLink CustomerLink
            DatabaseFieldSearch SearchPrefix SearchSuffix Constrictions
            MinQueryLength QueryDelay MaxQueryResult CaseSensitive
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
            DefaultValues
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
        DatabaseDSN         => $GetParam{DatabaseDSN},
        DatabaseUser        => $GetParam{DatabaseUser},
        DatabasePw          => $GetParam{DatabasePw},
        DatabaseType        => lc $GetParam{DatabaseType}     || '',
        DatabaseTable       => $GetParam{DatabaseTable},
        DatabaseFieldKey    => $GetParam{DatabaseFieldKey},
        DatabaseFieldValue  => $GetParam{DatabaseFieldValue}  || $GetParam{DatabaseFieldKey},
        DatabaseFieldSearch => $GetParam{DatabaseFieldSearch} || $GetParam{DatabaseFieldKey},
        SearchPrefix        => $GetParam{SearchPrefix}        || '',
        SearchSuffix        => $GetParam{SearchSuffix}        || '',
        MaxArraySize        => $GetParam{MaxArraySize}        || 1,
        CacheTTL            => $GetParam{CacheTTL}            || 0,
        CachePossibleValues => $GetParam{CachePossibleValues} || 0,
        ShowKeyInTitle      => $GetParam{ShowKeyInTitle}      || 0,
        ItemSeparator       => $GetParam{ItemSeparator}       || ', ',
        AgentLink           => $GetParam{AgentLink}           || '',
        CustomerLink        => $GetParam{CustomerLink}        || '',
        Constrictions       => $GetParam{Constrictions}       || '',
        MinQueryLength      => $GetParam{MinQueryLength}      || 3,
        QueryDelay          => $GetParam{QueryDelay}          || 300,
        MaxQueryResult      => $GetParam{MaxQueryResult}      || 10,
        CaseSensitive       => $GetParam{CaseSensitive},
        DefaultValues       => $GetParam{DefaultValues}       || [],
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

    $Param{DatabaseDSN}         = $Param{Config}->{DatabaseDSN};
    $Param{DatabaseUser}        = $Param{Config}->{DatabaseUser};
    $Param{DatabasePw}          = $Param{Config}->{DatabasePw};
    $Param{DatabaseType}        = $Param{Config}->{DatabaseType}        || '';
    $Param{DatabaseTable}       = $Param{Config}->{DatabaseTable};
    $Param{DatabaseFieldKey}    = $Param{Config}->{DatabaseFieldKey};
    $Param{DatabaseFieldValue}  = $Param{Config}->{DatabaseFieldValue}  || $Param{Config}->{DatabaseFieldKey};
    $Param{DatabaseFieldSearch} = $Param{Config}->{DatabaseFieldSearch} || $Param{Config}->{DatabaseFieldKey};
    $Param{SearchPrefix}        = $Param{Config}->{SearchPrefix}        || '';
    $Param{SearchSuffix}        = $Param{Config}->{SearchSuffix}        || '';
    $Param{MaxArraySize}        = $Param{Config}->{MaxArraySize}        || 1;
    $Param{CacheTTL}            = $Param{Config}->{CacheTTL}            || 0;
    $Param{CachePossibleValues} = $Param{Config}->{CachePossibleValues} || 0;
    $Param{ShowKeyInTitle}      = $Param{Config}->{ShowKeyInTitle}      || 0;
    $Param{ItemSeparator}       = $Param{Config}->{ItemSeparator}       || ', ';
    $Param{AgentLink}           = $Param{Config}->{AgentLink}           || '';
    $Param{CustomerLink}        = $Param{Config}->{CustomerLink}        || '';
    $Param{Constrictions}       = $Param{Config}->{Constrictions}       || '';
    $Param{MinQueryLength}      = $Param{Config}->{MinQueryLength}      || 3;
    $Param{QueryDelay}          = $Param{Config}->{QueryDelay}          || 300;
    $Param{MaxQueryResult}      = $Param{Config}->{MaxQueryResult}      || 10;
    $Param{CaseSensitive}       = $Param{Config}->{CaseSensitive};
    $Param{DefaultValues}       = $Param{Config}->{DefaultValues}       || [];

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

    # SearchPrefix
    # nothing to do

    # SearchSuffix
    # nothing to do

    # Constrictions
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

    # CachePossibleValues
    my $CachePossibleValuesStrg = $LayoutObject->BuildSelection(
        Data         => {
            0 => 'No',
            1 => 'Yes',
        },
        Name         => 'CachePossibleValues',
        SelectedID   => $Param{CachePossibleValues},
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'Modernize W50pc',
    );

    # ShowKeyInTitle
    my $ShowKeyInTitleStrg = $LayoutObject->BuildSelection(
        Data => {
            0 => 'No',
            1 => 'Yes',
        },
        Name         => 'ShowKeyInTitle',
        SelectedID   => $Param{ShowKeyInTitle},
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'Modernize W50pc',
    );

    # DefaultValues
    my $DefaultValuesCount = 0;
    for my $Key ( @{ $Param{DefaultValues} } ) {
        next if (!$Key);
        $DefaultValuesCount++;

        my $Label = $Kernel::OM->Get('Kernel::System::DynamicField::Driver::RemoteDB')->ValueLookup(
            Key                => $Key,
            DynamicFieldConfig => {
                Name   => $Param{Name},
                Config => {
                    DatabaseDSN        => $Param{DatabaseDSN},
                    DatabaseUser       => $Param{DatabaseUser},
                    DatabasePw         => $Param{DatabasePw},
                    DatabaseType       => $Param{DatabaseType},
                    DatabaseTable      => $Param{DatabaseTable},
                    DatabaseFieldKey   => $Param{DatabaseFieldKey},
                    DatabaseFieldValue => $Param{DatabaseFieldValue},
                    CacheTTL           => $Param{CacheTTL},
                },
            },
        );

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

    # CaseSensitive
    my $CaseSensitiveSelectionStrg = $LayoutObject->BuildSelection(
        Data => {
            0 => 'No',
            1 => 'Yes',
        },
        Name         => 'CaseSensitive',
        SelectedID   => $Param{CaseSensitive},
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'W50pc',
    );

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
        TemplateFile => 'AdminDynamicFieldRemoteDB',
        Data => {
            %Param,
            ValidityStrg            => $ValidityStrg,
            DynamicFieldOrderStrg   => $DynamicFieldOrderStrg,
            ItemSeparatorStrg       => $ItemSeparatorStrg,
            CachePossibleValuesStrg => $CachePossibleValuesStrg,
            ShowKeyInTitleStrg      => $ShowKeyInTitleStrg,
            CaseSensitiveStrg       => $CaseSensitiveSelectionStrg,
            DefaultValuesCount      => $DefaultValuesCount,
            ReadonlyInternalField => $ReadonlyInternalField,
        }
    );

    $Output .= $LayoutObject->Footer();

    return $Output;
}

sub _DefaultValueSearch {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    my @PossibleValues;

    # get search
    my $Search = $ParamObject->GetParam( Param => 'Search' ) || '';
    $Search = '*' . $Search . '*';
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$Search );

    # get DB config
    my $DatabaseDSN         = $ParamObject->GetParam( Param => 'DatabaseDSN' )         || '';
    my $DatabaseUser        = $ParamObject->GetParam( Param => 'DatabaseUser' )        || '';
    my $DatabasePw          = $ParamObject->GetParam( Param => 'DatabasePw' )          || '';
    my $DatabaseType        = lc $ParamObject->GetParam( Param => 'DatabaseType' )     || '';
    my $DatabaseFieldKey    = $ParamObject->GetParam( Param => 'DatabaseFieldKey' )    || '';
    my $DatabaseFieldValue  = $ParamObject->GetParam( Param => 'DatabaseFieldValue' )  || $DatabaseFieldKey;
    my $DatabaseFieldSearch = $ParamObject->GetParam( Param => 'DatabaseFieldSearch' ) || $DatabaseFieldKey;
    my $SearchPrefix        = $ParamObject->GetParam( Param => 'SearchPrefix' )        || '';
    my $SearchSuffix        = $ParamObject->GetParam( Param => 'SearchSuffix' )        || '';
    my $DatabaseTable       = $ParamObject->GetParam( Param => 'DatabaseTable' )       || '';
    my $CaseSensitive       = $ParamObject->GetParam( Param => 'CaseSensitive' )       || '';

    my $DFRemoteDBObject;
    if (
        $DatabaseDSN
        && $DatabaseUser
    ) {
        $DFRemoteDBObject = Kernel::System::DFRemoteDB->new(
            %{ $Self },
            DatabaseDSN  => $DatabaseDSN,
            DatabaseUser => $DatabaseUser,
            DatabasePw   => $DatabasePw,
            Type         => $DatabaseType,
        );
    }

    if (
        $DFRemoteDBObject
        && $DatabaseFieldKey
        && $DatabaseFieldValue
        && $DatabaseFieldSearch
        && $DatabaseTable
    ) {
        # get relevant config
        my $ShowKeyInTitle = $ParamObject->GetParam( Param => 'ShowKeyInTitle' ) || '';

        # get used Constrictions
        my $Constrictions = $ParamObject->GetParam( Param => 'Constrictions' ) || '';

        # get used entries
        my @Entries = $ParamObject->GetArray( Param => 'DefaultValues' );

        $Search         =~ s/\*/%/gi;
        my $QuotedValue = $DFRemoteDBObject->Quote($Search);

        my $QueryCondition = $DFRemoteDBObject->QueryCondition(
            Key           => split( ',', $DatabaseFieldSearch ),
            Value         => $QuotedValue,
            SearchPrefix  => $SearchPrefix,
            SearchSuffix  => $SearchSuffix,
            CaseSensitive => $CaseSensitive,
        );

        # prepare constrictions
        if ( $Constrictions ) {
            my @Constrictions = split(/[\n\r]+/, $Constrictions);
            CONSTRICTION:
            for my $Constriction ( @Constrictions ) {
                my @ConstrictionRule = split(/::/, $Constriction);
                # check for valid constriction
                next CONSTRICTION if (
                    scalar(@ConstrictionRule) != 4
                    || $ConstrictionRule[0] eq ""
                    || $ConstrictionRule[1] eq ""
                    || $ConstrictionRule[2] eq ""
                );

                # only handle static constrictions in admininterface
                if (
                    $ConstrictionRule[1] eq 'Configuration'
                ) {
                    my $QuotedConstrictionValue = $DFRemoteDBObject->Quote($ConstrictionRule[2]);
                    my $QueryConstrictionCondition = $DFRemoteDBObject->QueryCondition(
                        Key           => $ConstrictionRule[0],
                        Value         => $QuotedConstrictionValue,
                        SearchPrefix  => '',
                        SearchSuffix  => '',
                        CaseSensitive => 1,
                    );

                    $QueryCondition .= ' AND ' . $QueryConstrictionCondition;
                }
            }
        }

        my $SQL = 'SELECT '
            . $DatabaseFieldKey
            . ', '
            . $DatabaseFieldValue
            . ' FROM '
            . $DatabaseTable
            . ' WHERE '
            . $QueryCondition;

        my $Success = $DFRemoteDBObject->Prepare(
            SQL   => $SQL,
        );
        if ( !$Success ) {
            return;
        }

        my $MaxCount = 1;
        RESULT:
        while (my @Row = $DFRemoteDBObject->FetchrowArray()) {
            my $Key    = $Row[0];
            next RESULT if ( grep( {/^$Key$/} @Entries ) );

            my $Value = $Row[1];
            my $Title = $Value;
            if ( $ShowKeyInTitle ) {
                $Title .= ' (' . $Key . ')';
            }

            push @PossibleValues, {
                Key    => $Key,
                Value  => $Value,
                Title  => $Title,
            };
            last RESULT if ($MaxCount == 25);
            $MaxCount++;
        }
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
