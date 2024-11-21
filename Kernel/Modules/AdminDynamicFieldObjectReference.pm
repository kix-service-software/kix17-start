# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicFieldObjectReference;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);
use Kernel::System::CheckItem;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    # set possible values handling strings
    $Self->{EmptyString}     = '_DynamicFields_EmptyString_Dont_Use_It_String_Please';
    $Self->{DuplicateString} = '_DynamicFields_DuplicatedString_Dont_Use_It_String_Please';
    $Self->{DeletedString}   = '_DynamicFields_DeletedString_Dont_Use_It_String_Please';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create additional objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get configured object types
    $Self->{ObjectTypeConfig} = $ConfigObject->Get('DynamicFields::ObjectType');

    # get the fields config
    $Self->{FieldTypeConfig} = $ConfigObject->Get('DynamicFields::Driver') || {};

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
    return $LayoutObject->ErrorScreen(
        Message => Translatable('Undefined subaction.'),
    );
}

sub _Add {
    my ( $Self, %Param ) = @_;

    # create additional objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %GetParam;
    for my $Needed (qw(ObjectType FieldType FieldOrder)) {
        $GetParam{$Needed} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate( 'Need %s', $Needed ),
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName = $Self->{FieldTypeConfig}->{ $GetParam{FieldType} }->{DisplayName}
        || 'ObjectReference';

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
            $Errors{ $Needed . 'ServerErrorMessage' } = Translatable('This field is required.');
        }
    }

    # get the TreeView option and set it to '0' if it is undefined
    $GetParam{TreeView} = $ParamObject->GetParam( Param => 'TreeView' );
    $GetParam{TreeView} = defined $GetParam{TreeView} && $GetParam{TreeView} ? '1' : '0';

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    if ( $GetParam{Name} ) {

        # check if name is alphanumeric
        if ( $GetParam{Name} !~ m{\A (?: [a-zA-Z] | \d )+ \z}xms ) {

            # add server error error class
            $Errors{NameServerError} = 'ServerError';
            $Errors{NameServerErrorMessage} =
                Translatable('The field does not contain only ASCII letters and numbers.');
        }

        # get dynamic field list
        my $DynamicFieldsList = $DynamicFieldObject->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        ) || {};

        # check if name is duplicated
        my %DynamicFieldsList = %{$DynamicFieldsList};
        %DynamicFieldsList = reverse %DynamicFieldsList;

        if ( $DynamicFieldsList{ $GetParam{Name} } ) {

            # add server error error class
            $Errors{NameServerError}        = 'ServerError';
            $Errors{NameServerErrorMessage} = Translatable('There is another field with the same name.');
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

    for my $ConfigParam (
        qw(
        ObjectType ObjectTypeName FieldType FieldTypeName DefaultValue PossibleNone
        ValidID Rows Cols Link AlternativeDisplay ObjectReference DisplayFieldType)
    ) {
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam );
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
            Message => Translatable('Need ValidID'),
        );
    }

    # return to add screen if errors
    if (%Errors) {
        return $Self->_ShowScreen(
            %Param,
            %Errors,
            %GetParam,
            Mode => 'Add',
        );
    }

    # set specific config
    my $FieldConfig = {
        Link               => $GetParam{Link},
        ObjectReference    => $GetParam{ObjectReference},
        DisplayFieldType   => $GetParam{DisplayFieldType},
        TreeView           => $GetParam{TreeView},
        DefaultValue       => $GetParam{DefaultValue},
        PossibleNone       => $GetParam{PossibleNone},
        TranslatableValues => $GetParam{TranslatableValues},
        AlternativeDisplay => $GetParam{AlternativeDisplay},
    };

    # get ValueTTL config
    for my $ConfigParam (qw(ValueTTL ValueTTLData ValueTTLMultiplier)) {
        $FieldConfig->{$ConfigParam} = $GetParam{$ConfigParam};
    }

    # create a new field
    my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
        Name       => $GetParam{Name},
        Label      => $GetParam{Label},
        FieldOrder => $GetParam{FieldOrder},
        FieldType  => $GetParam{ObjectReference},
        ObjectType => $GetParam{ObjectType},
        Config     => $FieldConfig,
        ValidID    => $GetParam{ValidID},
        UserID     => $Self->{UserID},
    );

    if ( !$FieldID ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Could not create the new field'),
        );
    }

    return $LayoutObject->Redirect(
        OP => "Action=AdminDynamicField",
    );
}

sub _Change {
    my ( $Self, %Param ) = @_;

    # create additional objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my %GetParam;

    for my $Needed (qw(ObjectType FieldType)) {
        $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate( 'Need %s', $Needed ),
            );
        }
    }

    # get the object type and field type display name
    my $ObjectTypeName = $Self->{ObjectTypeConfig}->{ $GetParam{ObjectType} }->{DisplayName} || '';
    my $FieldTypeName  = $Self->{FieldTypeConfig}->{ $GetParam{FieldType} }->{DisplayName}   || '';

    my $FieldID = $ParamObject->GetParam( Param => 'ID' );

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

    my %Config = ();

    # extract configuration
    if ( IsHashRefWithData( $DynamicFieldData->{Config} ) ) {
        %Config = %{ $DynamicFieldData->{Config} };
    }

    return $Self->_ShowScreen(
        %Param,
        %GetParam,
        %${DynamicFieldData},
        %Config,
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
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    for my $Needed (qw(Name Label FieldOrder)) {
        $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed );
        if ( !$GetParam{$Needed} ) {
            $Errors{ $Needed . 'ServerError' }        = 'ServerError';
            $Errors{ $Needed . 'ServerErrorMessage' } = Translatable('This field is required.');
        }
    }

    # get the TreeView option and set it to '0' if it is undefined
    $GetParam{TreeView} = $ParamObject->GetParam( Param => 'TreeView' );
    $GetParam{TreeView} = defined $GetParam{TreeView} && $GetParam{TreeView} ? '1' : '0';

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $FieldID = $ParamObject->GetParam( Param => 'ID' );
    if ( !$FieldID ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Need ID'),
        );
    }

    # get dynamic field data
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldData   = $DynamicFieldObject->DynamicFieldGet(
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
        my $DynamicFieldsList = $DynamicFieldObject->DynamicFieldList(
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

    # get values with fallback to latest config
    for my $ConfigParam (
        qw(ObjectType ObjectTypeName FieldType FieldTypeName ValidID PossibleNone ObjectReference DisplayFieldType)
    ) {
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam )
            || $DynamicFieldData->{Config}->{$ConfigParam};
    }

    # get values without fallback to latest config
    for my $ConfigParam (qw(DefaultValue Link AlternativeDisplay)) {
        $GetParam{$ConfigParam} = $ParamObject->GetParam( Param => $ConfigParam );
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
            ID   => $FieldID,
            Mode => 'Change',
        );
    }

    # set specific config
    my $FieldConfig = {
        DefaultValue       => $GetParam{DefaultValue},
        Link               => $GetParam{Link},
        ObjectReference    => $GetParam{ObjectReference},
        DisplayFieldType   => $GetParam{DisplayFieldType},
        TreeView           => $GetParam{TreeView},
        PossibleNone       => $GetParam{PossibleNone},
        AlternativeDisplay => $GetParam{AlternativeDisplay},
    };

    # get ValueTTL config
    for my $ConfigParam (qw(ValueTTL ValueTTLData ValueTTLMultiplier)) {
        $FieldConfig->{$ConfigParam} = $GetParam{$ConfigParam};
    }

    # update dynamic field (FieldType and ObjectType cannot be changed; use old values)
    my $UpdateSuccess = $DynamicFieldObject->DynamicFieldUpdate(
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

    # create additional objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');

    $Param{DisplayFieldName} = 'New';

    if ( $Param{Mode} eq 'Change' ) {
        $Param{ShowWarning}      = 'ShowWarning';
        $Param{DisplayFieldName} = $Param{Name};
    }

    $Param{DeletedString} = $Self->{DeletedString};

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # header
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    # get all fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
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
        push @DynamicfieldOrderList, $LastOrderNumber;
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
        Class         => 'W75pc Validate_Number',
    );

    my %ValidList = $ValidObject->ValidList();

    # create the Validity select
    my $ValidityStrg = $LayoutObject->BuildSelection(
        Data         => \%ValidList,
        Name         => 'ValidID',
        SelectedID   => $Param{ValidID} || 1,
        PossibleNone => 0,
        Translation  => 1,
        Class        => 'W50pc',
    );

    my @FieldTypes = ( 'AutoComplete', 'Dropdown', 'Multiselect' );
    my $Backends = $ConfigObject->Get('DynamicFields::Driver');
    my @ObjectReferences;
    for my $Backend ( sort keys %{$Backends} ) {
        next if !defined $Backends->{$Backend}->{ConfigDialog};
        next if $Backends->{$Backend}->{ConfigDialog} ne 'AdminDynamicFieldObjectReference';
        next if $Backend eq 'ObjectReference';
        push @ObjectReferences, $Backend;
    }

    # create the object reference select
    my $ObjectReferenceStrg = $Param{ObjectReference};
    if ( $Param{Mode} eq 'Add' ) {
        $ObjectReferenceStrg = $LayoutObject->BuildSelection(
            Data         => \@ObjectReferences,
            Name         => 'ObjectReference',
            SelectedID   => $Param{ObjectReference},
            PossibleNone => 0,
            Translation  => 0,
            Class        => 'W50pc',
        );
    }

    # create the field type select
    my $FieldTypeStrg = $LayoutObject->BuildSelection(
        Data         => \@FieldTypes,
        Name         => 'DisplayFieldType',
        SelectedID   => $Param{DisplayFieldType},
        PossibleNone => 0,
        Translation  => 0,
        Class        => 'W50pc',
    );

    # define config field specific settings
    my $DefaultValue = ( defined $Param{DefaultValue} ? $Param{DefaultValue} : '' );
    my $Link = $Param{Link} || '';
    my $AlternativeDisplay = $Param{AlternativeDisplay} || '';

    my $ReadonlyInternalField = '';

    # Internal fields can not be deleted and name should not change.
    if ( $Param{InternalField} ) {
        $LayoutObject->Block(
            Name => 'InternalField',
            Data => {%Param},
        );
        $ReadonlyInternalField = 'readonly="readonly"';
    }

    my $PossibleNone = $Param{PossibleNone} || '0';

    # create translatable values option list
    my $PossibleNoneStrg = $LayoutObject->BuildSelection(
        Data => {
            0 => Translatable('No'),
            1 => Translatable('Yes'),
        },
        Name       => 'PossibleNone',
        SelectedID => $PossibleNone,
        Class      => 'W50pc',
    );

    my $TranslatableValues = $Param{TranslatableValues} || '0';

    # create translatable values option list
    my $TranslatableValuesStrg = $LayoutObject->BuildSelection(
        Data => {
            0 => Translatable('No'),
            1 => Translatable('Yes'),
        },
        Name       => 'TranslatableValues',
        SelectedID => $TranslatableValues,
        Class      => 'W50pc',
    );

    my $TreeView = $Param{TreeView} || '0';

    # create treeview option list
    my $TreeViewStrg = $LayoutObject->BuildSelection(
        Data => {
            0 => Translatable('No'),
            1 => Translatable('Yes'),
        },
        Name       => 'TreeView',
        SelectedID => $TreeView,
        Class      => 'W50pc',
    );

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
        TemplateFile => 'AdminDynamicFieldObjectReference',
        Data         => {
            %Param,
            ValidityStrg          => $ValidityStrg,
            DynamicFieldOrderStrg => $DynamicFieldOrderStrg,
            DefaultValue          => $DefaultValue,
            PossibleNoneStrg      => $PossibleNoneStrg,
            ReadonlyInternalField => $ReadonlyInternalField,
            Link                  => $Link,
            ObjectReferenceStrg   => $ObjectReferenceStrg,
            FieldTypeStrg         => $FieldTypeStrg,
            AlternativeDisplay    => $AlternativeDisplay,
            }
    );

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
