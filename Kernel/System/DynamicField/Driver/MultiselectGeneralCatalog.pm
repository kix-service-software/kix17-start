# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::MultiselectGeneralCatalog;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseSelect);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::GeneralCatalog',
);

=head1 NAME

Kernel::System::DynamicField::Driver::MultiselectGeneralCatalog

=head1 SYNOPSIS

DynamicFields MultiselectGeneralCatalog Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set field behaviors
    $Self->{Behaviors} = {
        'IsACLReducible'               => 1,
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 0,
        'IsFiltrable'                  => 0,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions

       # KIX4OTRS-capeIT
       # = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Extension::Driver::Multiselect');
        = $Kernel::OM->Get('Kernel::Config')
        ->Get('DynamicFields::Extension::Driver::MultiselectGeneralCatalog');

    # EO KIX4OTRS-capeIT

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldDriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldDriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldDriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$Kernel::OM->Get('Kernel::System::Main')->RequireBaseClass( $Extension->{Module} )
                )
            {
                die "Can't load dynamic fields backend module"
                    . " $Extension->{Module}! $@";
            }
        }

        # check if extension contains more behaviors
        if ( IsHashRefWithData( $Extension->{Behaviors} ) ) {

            %{ $Self->{Behaviors} } = (
                %{ $Self->{Behaviors} },
                %{ $Extension->{Behaviors} }
            );
        }
    }

    return $Self;
}

sub ValueIsDifferent {
    my ( $Self, %Param ) = @_;

    # special cases where the values are different but they should be reported as equals
    return if !defined $Param{Value1} && ( defined $Param{Value2} && $Param{Value2} eq '' );
    return if !defined $Param{Value2} && ( defined $Param{Value1} && $Param{Value1} eq '' );

    # compare the results
    return DataIsDifferent( Data1 => \$Param{Value1}, Data2 => \$Param{Value2} );
}

sub ValueGet {
    my ( $Self, %Param ) = @_;

    my $DFValue = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->ValueGet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
    );

    return if !$DFValue;
    return if !IsArrayRefWithData($DFValue);
    return if !IsHashRefWithData( $DFValue->[0] );

    # extract real values
    my @ReturnData;
    for my $Item ( @{$DFValue} ) {
        push @ReturnData, $Item->{ValueText}
    }

    return \@ReturnData;
}

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check for valid general catalog class
    # KIX4OTRS-capeIT
    # if ( !$Param{DynamicFieldConfig}->{Config}->{PossibleValues} ) {
    if ( !$Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass} ) {

        # EO KIX4OTRS-capeIT
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',

            # KIX4OTRS-capeIT
            # Message  => "Need PossibleValues in DynamicFieldConfig!",
            Message => "Need GeneralCatalogClass in DynamicFieldConfig!",

            # EO KIX4OTRS-capeIT
        );
        return;
    }

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # get dynamic field value object
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');

    # KIX4OTRS-capeIT
    # get dynamic field value object
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # EO KIX4OTRS-capeIT

    my @ValueText;
    if ( IsArrayRefWithData( \@Values ) ) {

        # if there is at least one value to set, this means one or more values are selected,
        #    set those values!
        for my $Item (@Values) {
            push @ValueText, { ValueText => $Item };
        }
    }
    else {
        push @ValueText, { ValueText => '' };
    }

    my $Success = $DynamicFieldValueObject->ValueSet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
        Value    => \@ValueText,
        UserID   => $Param{UserID},
    );

    return $Success;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    # check value
    my @Values;
    if ( IsArrayRefWithData( $Param{Value} ) ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # get dynamic field value object
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');

    my $Success;
    for my $Item (@Values) {

        $Success = $DynamicFieldValueObject->ValueValidate(
            Value => {
                ValueText => $Item,
            },
            UserID => $Param{UserID}
        );

        return if !$Success
    }

    return $Success;
}

sub EditFieldRender {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldName   = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $FieldLabel  = $Param{DynamicFieldConfig}->{Label};

    # KIX4OTRS-capeIT
    # my $Value;
    my $Value = '';

    # EO KIX4OTRS-capeIT

    # set the field value or default
    if ( $Param{UseDefaultValue} ) {
        $Value = ( defined $FieldConfig->{DefaultValue} ? $FieldConfig->{DefaultValue} : '' );
    }
    $Value = $Param{Value} // $Value;

    # check if a value in a template (GenericAgent etc.)
    # is configured for this dynamic field
    if (
        IsHashRefWithData( $Param{Template} )
        && defined $Param{Template}->{$FieldName}
        )
    {
        $Value = $Param{Template}->{$FieldName};
    }

    # extract the dynamic field value form the web request
    my $FieldValue = $Self->EditFieldValueGet(
        %Param,
    );

    # set values from ParamObject if present
    if ( IsArrayRefWithData($FieldValue) ) {
        $Value = $FieldValue;
    }

    # check and set class if necessary
    my $FieldClass = 'DynamicFieldText Modernize';
    if ( defined $Param{Class} && $Param{Class} ne '' ) {
        $FieldClass .= ' ' . $Param{Class};
    }

    # set field as mandatory
    if ( $Param{Mandatory} ) {
        $FieldClass .= ' Validate_Required';
    }

    # set error css class
    if ( $Param{ServerError} ) {
        $FieldClass .= ' ServerError';
    }

    # set TreeView class
    if ( $FieldConfig->{TreeView} ) {
        $FieldClass .= ' DynamicFieldWithTreeView';
    }

    # KIX4OTRS-capeIT
    # get general catalog class
    my $GeneralCatalogClass = $FieldConfig->{GeneralCatalogClass};

    # set PossibleValues
    # my $PossibleValues = $FieldConfig->{PossibleValues};
    my $PossibleValues = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogClass,
    );

    # EO KIX4OTRS-capeIT

    # check value
    my $SelectedValuesArrayRef;
    if ( defined $Value ) {
        if ( ref $Value eq 'ARRAY' ) {
            $SelectedValuesArrayRef = $Value;
        }
        else {
            $SelectedValuesArrayRef = [$Value];
        }
    }

    my $DataValues = $Self->BuildSelectionDataGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        PossibleValues     => $PossibleValues,
        Value              => $Value,
    );

    my $HTMLString = $Param{LayoutObject}->BuildSelection(
        Data => $DataValues || {},
        Name => $FieldName,
        SelectedID  => $SelectedValuesArrayRef,
        Translation => $FieldConfig->{TranslatableValues} || 0,
        Class       => $FieldClass,
        HTMLQuote   => 1,
        Multiple    => 1,
    );

    if ( $FieldConfig->{TreeView} ) {
        my $TreeSelectionMessage = $Param{LayoutObject}->{LanguageObject}->Translate("Show Tree Selection");
        $HTMLString
            .= ' <a href="#" title="'
            . $TreeSelectionMessage
            . '" class="ShowTreeSelection"><span>'
            . $TreeSelectionMessage . '</span><i class="fa fa-sitemap"></i></a>';
    }

    if ( $Param{Mandatory} ) {
        my $DivID = $FieldName . 'Error';

        my $FieldRequiredMessage = $Param{LayoutObject}->{LanguageObject}->Translate("This field is required.");

        # for client side validation
        $HTMLString .= <<"EOF";

<div id="$DivID" class="TooltipErrorMessage">
    <p>
        $FieldRequiredMessage
    </p>
</div>
EOF
    }

    if ( $Param{ServerError} ) {

        my $ErrorMessage = $Param{ErrorMessage} || 'This field is required.';
        $ErrorMessage = $Param{LayoutObject}->{LanguageObject}->Translate($ErrorMessage);
        my $DivID = $FieldName . 'ServerError';

        # for server side validation
        $HTMLString .= <<"EOF";

<div id="$DivID" class="TooltipErrorMessage">
    <p>
        $ErrorMessage
    </p>
</div>
EOF
    }

    if ( $Param{AJAXUpdate} ) {

        my $FieldSelector = '#' . $FieldName;

        my $FieldsToUpdate;
        if ( IsArrayRefWithData( $Param{UpdatableFields} ) ) {

            # Remove current field from updatable fields list
            my @FieldsToUpdate = grep { $_ ne $FieldName } @{ $Param{UpdatableFields} };

            # quote all fields, put commas in between them
            $FieldsToUpdate = join( ', ', map {"'$_'"} @FieldsToUpdate );
        }

        # add js to call FormUpdate()
        $Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"EOF");
\$('$FieldSelector').bind('change', function (Event) {
    Core.AJAX.FormUpdate(\$(this).parents('form'), 'AJAXUpdate', '$FieldName', [ $FieldsToUpdate ]);
});
Core.App.Subscribe('Event.AJAX.FormUpdate.Callback', function(Data) {
    var FieldName = '$FieldName';
    if (Data[FieldName] && \$('#' + FieldName).hasClass('DynamicFieldWithTreeView')) {
        Core.UI.TreeSelection.RestoreDynamicFieldTreeView(\$('#' + FieldName), Data[FieldName], '' , 1);
    }
});
EOF
    }

    # call EditLabelRender on the common Driver
    my $LabelString = $Self->EditLabelRender(
        %Param,
        Mandatory => $Param{Mandatory} || '0',
        FieldName => $FieldName,
    );

    my $Data = {
        Field => $HTMLString,
        Label => $LabelString,
    };

    return $Data;
}

sub EditFieldValueGet {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    my $Value;

    # check if there is a Template and retrieve the dynamic field value from there
    if ( IsHashRefWithData( $Param{Template} ) && defined $Param{Template}->{$FieldName} ) {
        $Value = $Param{Template}->{$FieldName};
    }

    # otherwise get dynamic field value from the web request
    elsif (
        defined $Param{ParamObject}
        && ref $Param{ParamObject} eq 'Kernel::System::Web::Request'
        )
    {
        my @Data = $Param{ParamObject}->GetArray( Param => $FieldName );

        # delete empty values (can happen if the user has selected the "-" entry)
        my $Index = 0;
        ITEM:
        for my $Item ( sort @Data ) {

            if ( !$Item ) {
                splice( @Data, $Index, 1 );
                next ITEM;
            }
            $Index++;
        }

        $Value = \@Data;
    }

    if ( defined $Param{ReturnTemplateStructure} && $Param{ReturnTemplateStructure} eq 1 ) {
        return {
            $FieldName => $Value,
        };
    }

    # for this field the normal return an the ReturnValueStructure are the same
    return $Value;
}

sub EditFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # get the field value from the http request
    my $Values = $Self->EditFieldValueGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        ParamObject        => $Param{ParamObject},

        # not necessary for this Driver but place it for consistency reasons
        ReturnValueStructure => 1,
    );

    my $ServerError;
    my $ErrorMessage;

    # perform necessary validations
    if ( $Param{Mandatory} && !IsArrayRefWithData($Values) ) {
        return {
            ServerError => 1,
        };
    }
    else {

        # KIX4OTRS-capeIT
        # get general catalog class
        my $GeneralCatalogClass = $Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass};

        # get possible values list
        # my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};
        my $PossibleValues = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
            Class => $GeneralCatalogClass,
        );

        # EO KIX4OTRS-capeIT

        # overwrite possible values if PossibleValuesFilter
        if ( defined $Param{PossibleValuesFilter} ) {
            $PossibleValues = $Param{PossibleValuesFilter}
        }

        # validate if value is in possible values list (but let pass empty values)
        for my $Item ( @{$Values} ) {
            if ( $Item ne '-' && !$PossibleValues->{$Item} ) {
                $ServerError  = 1;
                $ErrorMessage = 'The field content is invalid';
            }
        }
    }

    # create resulting structure
    my $Result = {
        ServerError  => $ServerError,
        ErrorMessage => $ErrorMessage,
    };

    return $Result;
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOuput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    # set Value and Title variables
    my $Value         = '';
    my $Title         = '';
    my $ValueMaxChars = $Param{ValueMaxChars} || '';
    my $TitleMaxChars = $Param{TitleMaxChars} || '';

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # KIX4OTRS-capeIT
    # get general catalog class
    my $GeneralCatalogClass = $Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass};

    # get real values
    # my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};
    my $PossibleValues = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogClass,
    );

    # EO KIX4OTRS-capeIT
    my $TranslatableValues = $Param{DynamicFieldConfig}->{Config}->{TranslatableValues};

    my @ReadableValues;
    my @ReadableTitles;

    my $ShowValueEllipsis;
    my $ShowTitleEllipsis;

    VALUEITEM:
    for my $Item (@Values) {
        next VALUEITEM if !$Item;

        my $ReadableValue = $Item;

        if ( $PossibleValues->{$Item} ) {
            $ReadableValue = $PossibleValues->{$Item};
            if ($TranslatableValues) {
                $ReadableValue = $Param{LayoutObject}->{LanguageObject}->Translate($ReadableValue);
            }
        }

        my $ReadableLength = length $ReadableValue;

        # set title equal value
        my $ReadableTitle = $ReadableValue;

        # cut strings if needed
        if ( $ValueMaxChars ne '' ) {

            if ( length $ReadableValue > $ValueMaxChars ) {
                $ShowValueEllipsis = 1;
            }
            $ReadableValue = substr $ReadableValue, 0, $ValueMaxChars;

            # decrease the max parameter
            $ValueMaxChars = $ValueMaxChars - $ReadableLength;
            if ( $ValueMaxChars < 0 ) {
                $ValueMaxChars = 0;
            }
        }

        if ( $TitleMaxChars ne '' ) {

            if ( length $ReadableTitle > $ValueMaxChars ) {
                $ShowTitleEllipsis = 1;
            }
            $ReadableTitle = substr $ReadableTitle, 0, $TitleMaxChars;

            # decrease the max parameter
            $TitleMaxChars = $TitleMaxChars - $ReadableLength;
            if ( $TitleMaxChars < 0 ) {
                $TitleMaxChars = 0;
            }
        }

        # HTMLOuput transformations
        if ( $Param{HTMLOutput} ) {

            $ReadableValue = $Param{LayoutObject}->Ascii2Html(
                Text => $ReadableValue,
            );

            $ReadableTitle = $Param{LayoutObject}->Ascii2Html(
                Text => $ReadableTitle,
            );
        }

        if ( length $ReadableValue ) {
            push @ReadableValues, $ReadableValue;
        }
        if ( length $ReadableTitle ) {
            push @ReadableTitles, $ReadableTitle;
        }
    }

    # get specific field settings
    my $FieldConfig = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Driver')->{Multiselect} || {};

    # set new line separator
    my $ItemSeparator = $FieldConfig->{ItemSeparator} || ', ';

    $Value = join( $ItemSeparator, @ReadableValues );
    $Title = join( $ItemSeparator, @ReadableTitles );

    if ($ShowValueEllipsis) {
        $Value .= '...';
    }
    if ($ShowTitleEllipsis) {
        $Title .= '...';
    }

    # this field type does not support the Link Feature
    my $Link;

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
        Link  => $Link,
    };

    return $Data;
}

sub SearchFieldRender {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldName   = 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $FieldLabel  = $Param{DynamicFieldConfig}->{Label};

    my $Value;

    my @DefaultValue;

    if ( defined $Param{DefaultValue} ) {
        @DefaultValue = split /;/, $Param{DefaultValue};
    }

    # set the field value
    if (@DefaultValue) {
        $Value = \@DefaultValue;
    }

    # get the field value, this function is always called after the profile is loaded
    my $FieldValues = $Self->SearchFieldValueGet(
        %Param,
    );

    if ( defined $FieldValues ) {
        $Value = $FieldValues;
    }

    # check and set class if necessary
    my $FieldClass = 'DynamicFieldMultiSelect Modernize';

    # KIX4OTRS-capeIT
    # get general catalog class
    my $GeneralCatalogClass = $FieldConfig->{GeneralCatalogClass};

    # set PossibleValues
    # my $SelectionData = $FieldConfig->{PossibleValues};
    my $SelectionData = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogClass,
    );

    # EO KIX4OTRS-capeIT

    # get historical values from database
    my $HistoricalValues = $Self->HistoricalValuesGet(%Param);

    # add historic values to current values (if they don't exist anymore)
    if ( IsHashRefWithData($HistoricalValues) ) {
        for my $Key ( sort keys %{$HistoricalValues} ) {
            if ( !$SelectionData->{$Key} ) {
                $SelectionData->{$Key} = $HistoricalValues->{$Key}
            }
        }
    }

    # use PossibleValuesFilter if defined
    $SelectionData = $Param{PossibleValuesFilter}
        if defined $Param{PossibleValuesFilter};

    my $HTMLString = $Param{LayoutObject}->BuildSelection(
        Data         => $SelectionData,
        Name         => $FieldName,
        SelectedID   => $Value,
        Translation  => $FieldConfig->{TranslatableValues} || 0,
        PossibleNone => 0,
        Class        => $FieldClass,
        Multiple     => 1,
        HTMLQuote    => 1,
    );

    # call EditLabelRender on the common backend
    my $LabelString = $Self->EditLabelRender(
        %Param,
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        FieldName          => $FieldName,
    );

    my $Data = {
        Field => $HTMLString,
        Label => $LabelString,
    };

    return $Data;
}

sub SearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    # get field value
    my $Value = $Self->SearchFieldValueGet(%Param);

    my $DisplayValue;

    if ( defined $Value && !$Value ) {
        $DisplayValue = '';
    }

    # KIX4OTRS-capeIT
    # get general catalog class
    my $GeneralCatalogClass = $Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass};

    # set PossibleValues
    my $PossibleValues = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogClass,
    );

    # EO KIX4OTRS-capeIT

    if ($Value) {
        if ( ref $Value eq 'ARRAY' ) {

            my @DisplayItemList;
            for my $Item ( @{$Value} ) {

                # set the display value
                # KIX4OTRS-capeIT
                my $DisplayItem = $PossibleValues->{$Item}
                    || $Item;
                if ( $Param{DynamicFieldConfig}->{Config}->{TranslatableValues} ) {

                    # translate the value
                    $DisplayItem = $Param{LayoutObject}->{LanguageObject}->Translate($DisplayValue);

                    # EO KIX4OTRS-capeIT
                }

                push @DisplayItemList, $DisplayItem;
            }

            # combine different values into one string
            $DisplayValue = join ' + ', @DisplayItemList;
        }
        else {

            # set the display value
            # KIX4OTRS-capeIT
            $DisplayValue = $PossibleValues->{$Value};

            if ( $Param{DynamicFieldConfig}->{Config}->{TranslatableValues} ) {

                # translate the value
                # EO KIX4OTRS-capeIT
                $DisplayValue = $Param{LayoutObject}->{LanguageObject}->Translate($DisplayValue);
            }
        }
    }

    # return search parameter structure
    return {
        Parameter => {
            Equals => $Value,
        },
        Display => $DisplayValue,
    };
}

sub StatsFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    # KIX4OTRS-capeIT
    # get general catalog class
    my $GeneralCatalogClass = $Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass};

    # set PossibleValues
    # my $Values = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};
    my $Values = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogClass,
    );

    # EO KIX4OTRS-capeIT

    # get historical values from database
    my $HistoricalValues = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->HistoricalValueGet(
        FieldID   => $Param{DynamicFieldConfig}->{ID},
        ValueType => 'Text,',
    );

    # add historic values to current values (if they don't exist anymore)
    for my $Key ( sort keys %{$HistoricalValues} ) {
        if ( !$Values->{$Key} ) {
            $Values->{$Key} = $HistoricalValues->{$Key}
        }
    }

    # use PossibleValuesFilter if defined
    $Values = $Param{PossibleValuesFilter} // $Values;

    return {
        Values             => $Values,
        Name               => $Param{DynamicFieldConfig}->{Label},
        Element            => 'DynamicField_' . $Param{DynamicFieldConfig}->{Name},
        TranslatableValues => $Param{DynamicFieldConfig}->{Config}->{TranslatableValues},
    };
}

sub CommonSearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    my $Operator = 'Equals';
    my $Value    = $Param{Value};

    return {
        $Operator => $Value,
    };
}

sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    # set Value and Title variables
    my $Value = '';
    my $Title = '';

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    my @ReadableValues;

    VALUEITEM:
    for my $Item (@Values) {
        next VALUEITEM if !$Item;

        push @ReadableValues, $Item;
    }

    # set new line separator
    my $ItemSeparator = ', ';

    # Output transformations
    $Value = join( $ItemSeparator, @ReadableValues );
    $Title = $Value;

    # cut strings if needed
    if ( $Param{ValueMaxChars} && length($Value) > $Param{ValueMaxChars} ) {
        $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
    }
    if ( $Param{TitleMaxChars} && length($Title) > $Param{TitleMaxChars} ) {
        $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}

sub TemplateValueTypeGet {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # set the field types
    my $EditValueType   = 'ARRAY';
    my $SearchValueType = 'ARRAY';

    # return the correct structure
    if ( $Param{FieldType} eq 'Edit' ) {
        return {
            $FieldName => $EditValueType,
            }
    }
    elsif ( $Param{FieldType} eq 'Search' ) {
        return {
            'Search_' . $FieldName => $SearchValueType,
            }
    }
    else {
        return {
            $FieldName             => $EditValueType,
            'Search_' . $FieldName => $SearchValueType,
            }
    }
}

sub ObjectMatch {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # the attribute must be an array
    return 0 if !IsArrayRefWithData( $Param{ObjectAttributes}->{$FieldName} );

    my $Match;

    # search in all values for this attribute
    VALUE:
    for my $AttributeValue ( @{ $Param{ObjectAttributes}->{$FieldName} } ) {

        next VALUE if !defined $AttributeValue;

        # only need to match one
        if ( $Param{Value} eq $AttributeValue ) {
            $Match = 1;
            last VALUE;
        }
    }

    return $Match;
}

sub PossibleValuesGet {
    my ( $Self, %Param ) = @_;

    # KIX4OTRS-capeIT
    # get general catalog class
    my $GeneralCatalogClass = $Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass};

    # set PossibleValues
    my $DefinedPossibleValues = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogClass,
    );

    # EO KIX4OTRS-capeIT

    # to store the possible values
    my %PossibleValues;

    # set none value if defined on field config
    if ( $Param{DynamicFieldConfig}->{Config}->{PossibleNone} ) {
        %PossibleValues = ( '' => '-' );
    }

    # set all other possible values if defined on field config
    # KIX4OTRS-capeIT
    # if ( IsHashRefWithData( $Param{DynamicFieldConfig}->{Config}->{PossibleValues} ) ) {
    if ( IsHashRefWithData($DefinedPossibleValues) ) {

        # EO KIX4OTRS-capeIT
        %PossibleValues = (
            %PossibleValues,

            # KIX4OTRS-capeIT
            # %{ $Param{DynamicFieldConfig}->{Config}->{PossibleValues} },
            %{$DefinedPossibleValues},

            # EO KIX4OTRS-capeIT
        );
    }

    # return the possible values hash as a reference
    return \%PossibleValues;
}

sub HistoricalValuesGet {
    my ( $Self, %Param ) = @_;

    # get historical values from database
    my $HistoricalValues = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->HistoricalValueGet(
        FieldID   => $Param{DynamicFieldConfig}->{ID},
        ValueType => 'Text',
    );

    # return the historical values from database
    return $HistoricalValues;
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    my @Keys;
    if ( ref $Param{Key} eq 'ARRAY' ) {
        @Keys = @{ $Param{Key} };
    }
    else {
        @Keys = ( $Param{Key} );
    }

    # get real values
    # KIX4OTRS-capeIT
    # my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};
    my $PossibleValues = $Self->PossibleValuesGet(%Param);

    # EO KIX4OTRS-capeIT

    # to store final values
    my @Values;

    KEYITEM:
    for my $Item (@Keys) {
        next KEYITEM if !$Item;

        # set the value as the key by default
        my $Value = $Item;

        # try to convert key to real value
        if ( $PossibleValues->{$Item} ) {
            $Value = $PossibleValues->{$Item};

            # check if translation is possible
            if (
                defined $Param{LanguageObject}
                && $Param{DynamicFieldConfig}->{Config}->{TranslatableValues}
                )
            {

                # translate value
                $Value = $Param{LanguageObject}->Translate($Value);
            }
        }
        push @Values, $Value;
    }

    return \@Values;
}

sub BuildSelectionDataGet {
    my ( $Self, %Param ) = @_;

    my $FieldConfig            = $Param{DynamicFieldConfig}->{Config};
    my $FilteredPossibleValues = $Param{PossibleValues};

    # get the possible values again as it might or might not contain the possible none and it could
    # also be overwritten
    my $ConfigPossibleValues = $Self->PossibleValuesGet(%Param);

    # check if $PossibleValues differs from configured PossibleValues
    # and show values which are not contained as disabled if TreeView => 1
    if ( $FieldConfig->{TreeView} ) {

        if ( keys %{$ConfigPossibleValues} != keys %{$FilteredPossibleValues} ) {

            # define variables to use later in the for loop
            my @Values;
            my $Parents;
            my %DisabledElements;
            my %ProcessedElements;
            my $PosibleNoneSet;

            my %Values;
            if ( defined $Param{Value} && IsArrayRefWithData( $Param{Value} ) ) {

                # create a lookup table
                %Values = map { $_ => 1 } @{ $Param{Value} };
            }

            # loop on all filtered possible values
            for my $Key ( sort keys %{$FilteredPossibleValues} ) {

                # special case for possible none
                if ( !$Key && !$PosibleNoneSet && $FieldConfig->{PossibleNone} ) {

                    my $Selected;
                    if (
                        !IsHashRefWithData( \%Values )
                        || ( defined $Values{''} && $Values{''} )
                        )
                    {
                        $Selected = 1;
                    }

                    # add possible none
                    push @Values, {
                        Key      => $Key,
                        Value    => $ConfigPossibleValues->{$Key} || '-',
                        Selected => $Selected,
                    };
                }

                # try to split its parents GrandParent::Parent::Son
                my @Elements = split /::/, $Key;

                # reset parents
                $Parents = '';

                # get each element in the hierarchy
                ELEMENT:
                for my $Element (@Elements) {

                    # add its own parents for the complete name
                    my $ElementLongName = $Parents . $Element;

                    # set new parent (before skip already processed)
                    $Parents .= $Element . '::';

                    # skip if already processed
                    next ELEMENT if $ProcessedElements{$ElementLongName};

                    my $Disabled;

                    # check if element exists in the original data or if it is already marked
                    if (
                        !defined $FilteredPossibleValues->{$ElementLongName}
                        && !$DisabledElements{$ElementLongName}
                        )
                    {

                        # mark element as disabled
                        $DisabledElements{$ElementLongName} = 1;

                        # also set the disabled flag for current element to add
                        $Disabled = 1;
                    }

                    # set element as already processed
                    $ProcessedElements{$ElementLongName} = 1;

                    # check if the current element is the selected one
                    my $Selected;
                    if ( IsHashRefWithData( \%Values ) && $Values{$ElementLongName} ) {
                        $Selected = 1;
                    }

                    # add element to the new list of possible values (now including missing parents)
                    push @Values, {
                        Key      => $ElementLongName,
                        Value    => $ConfigPossibleValues->{$ElementLongName} || $ElementLongName,
                        Disabled => $Disabled,
                        Selected => $Selected,
                    };
                }
            }
            $FilteredPossibleValues = \@Values;
        }
    }

    return $FilteredPossibleValues;
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
