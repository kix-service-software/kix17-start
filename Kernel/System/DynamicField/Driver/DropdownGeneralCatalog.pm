# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::DropdownGeneralCatalog;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseSelect);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::Main',

    # KIX4OTRS-capeIT
    'Kernel::System::GeneralCatalog',

    # EO KIX4OTRS-capeIT
);

=head1 NAME

Kernel::System::DynamicField::Driver::DropdownGeneralCatalog

=head1 SYNOPSIS

DynamicFields DropdownGeneralCatalog Driver delegate

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
        'IsSortable'                   => 1,
        'IsFiltrable'                  => 1,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Extension::Driver::Dropdown');

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

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check for valid general catalog class
    # KIX4OTRS-capeIT
    # if ( !$Param{DynamicFieldConfig}->{Config}->{PossibleValues} ) {
    if ( !$Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass} ) {

        # EO KIX4OTRS-capeIT
        $Self->{LogObject}->Log(
            Priority => 'error',

            # KIX4OTRS-capeIT
            # Message  => "Need PossibleValues in DynamicFieldConfig!",
            Message => "Need GeneralCatalogClass in DynamicFieldConfig!",

            # EO KIX4OTRS-capeIT
        );
        return;
    }

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->ValueSet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
        Value    => [
            {
                ValueText => $Param{Value},
            },
        ],
        UserID => $Param{UserID},
    );

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
    if ( defined $FieldValue ) {
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

    # set empty value
    if ( defined $FieldConfig->{PossibleNone} && $FieldConfig->{PossibleNone} ) {
        $PossibleValues->{'-'} = '-';
    }

    # EO KIX4OTRS-capeIT

    my $Size = 1;

    # TODO change ConfirmationNeeded parameter name to something more generic

    # when ConfimationNeeded parameter is present (AdminGenericAgent) the filed should be displayed
    # as an open list, because you might not want to change the value, otherwise a value will be
    # selected
    if ( $Param{ConfirmationNeeded} ) {
        $Size = 5;
    }

    my $DataValues = $Self->BuildSelectionDataGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        PossibleValues     => $PossibleValues,
        Value              => $Value,
    );

    my $HTMLString = $Param{LayoutObject}->BuildSelection(
        Data => $DataValues || {},
        Name => $FieldName,
        SelectedID  => $Value,
        Translation => $FieldConfig->{TranslatableValues} || 0,
        Class       => $FieldClass,
        Size        => $Size,
        HTMLQuote   => 1,
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

        my $FieldsToUpdate = '';
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

sub EditFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # get the field value from the http request
    my $Value = $Self->EditFieldValueGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        ParamObject        => $Param{ParamObject},

        # not necessary for this Driver but place it for consistency reasons
        ReturnValueStructure => 1,
    );

    my $ServerError;
    my $ErrorMessage;

    # perform necessary validations
    if ( $Param{Mandatory} && !$Value ) {
        return {
            ServerError => 1,
        };
    }
    else {

        # KIX4OTRS-capeIT
        # get general catalog class
        my $GeneralCatalogClass = $Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass};

        # set PossibleValues
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
        if ( $Value && $Value ne '-' && !$PossibleValues->{$Value} ) {
            $ServerError  = 1;
            $ErrorMessage = 'The field content is invalid';
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

    # get raw Value strings from field value
    my $Value = defined $Param{Value} ? $Param{Value} : '';

    # KIX4OTRS-capeIT
    # get general catalog class
    my $GeneralCatalogClass = $Param{DynamicFieldConfig}->{Config}->{GeneralCatalogClass};

    # set PossibleValues
    # my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};
    my $PossibleValues = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogClass,
    );

    # EO KIX4OTRS-capeIT

    # get real value
    # KIX4OTRS-capeIT
    # if ( $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value} ) {
    if ( $PossibleValues->{$Value} ) {

        # EO KIX4OTRS-capeIT

        # get readeable value
        # KIX4OTRS-capeIT
        # $Value = $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value};
        $Value = $PossibleValues->{$Value};

        # EO KIX4OTRS-capeIT
    }

    # check is needed to translate values
    if ( $Param{DynamicFieldConfig}->{Config}->{TranslatableValues} ) {

        # translate value
        $Value = $Param{LayoutObject}->{LanguageObject}->Translate($Value);
    }

    # set title as value after update and before limit
    my $Title = $Value;

    # HTMLOuput transformations
    if ( $Param{HTMLOutput} ) {
        $Value = $Param{LayoutObject}->Ascii2Html(
            Text => $Value,
            Max  => $Param{ValueMaxChars} || '',
        );

        $Title = $Param{LayoutObject}->Ascii2Html(
            Text => $Title,
            Max  => $Param{TitleMaxChars} || '',
        );
    }
    else {
        if ( $Param{ValueMaxChars} && length($Value) > $Param{ValueMaxChars} ) {
            $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
        }
        if ( $Param{TitleMaxChars} && length($Title) > $Param{TitleMaxChars} ) {
            $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
        }
    }

    # set field link form config
    my $Link = $Param{DynamicFieldConfig}->{Config}->{Link} || '';

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

    # set TreeView class
    if ( $FieldConfig->{TreeView} ) {
        $FieldClass .= ' DynamicFieldWithTreeView';
    }

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
    $SelectionData = $Param{PossibleValuesFilter} // $SelectionData;

    # check if $SelectionData differs from configured PossibleValues
    # and show values which are not contained as disabled if TreeView => 1
    if ( $FieldConfig->{TreeView} ) {

        if ( keys %{ $FieldConfig->{PossibleValues} } != keys %{$SelectionData} ) {

            my @Values;
            for my $Key ( sort keys %{ $FieldConfig->{PossibleValues} } ) {

                push @Values, {
                    Key      => $Key,
                    Value    => $FieldConfig->{PossibleValues}->{$Key},
                    Disabled => ( defined $SelectionData->{$Key} ) ? 0 : 1,
                };
            }
            $SelectionData = \@Values;
        }
    }

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

    if ( $FieldConfig->{TreeView} ) {
        my $TreeSelectionMessage = $Param{LayoutObject}->{LanguageObject}->Translate("Show Tree Selection");
        $HTMLString
            .= ' <a href="#" title="'
            . $TreeSelectionMessage
            . '" class="ShowTreeSelection"><span>'
            . $TreeSelectionMessage . '</span><i class="fa fa-sitemap"></i></a>';
    }

    # call EditLabelRender on the common Driver
    my $LabelString = $Self->EditLabelRender(
        %Param,
        FieldName => $FieldName,
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
                # my $DisplayItem = $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Item}
                my $DisplayItem = $PossibleValues->{$Item}

                    # EO KIX4OTRS-capeIT
                    || $Item;

                # translate the value
                if (
                    $Param{DynamicFieldConfig}->{Config}->{TranslatableValues}
                    && defined $Param{LayoutObject}
                    )
                {
                    $DisplayItem = $Param{LayoutObject}->{LanguageObject}->Translate($DisplayItem);
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

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    my $Value = defined $Param{Key} ? $Param{Key} : '';

    # get real values
    # KIX4OTRS-capeIT
    # my $PossibleValues = $Param{DynamicFieldConfig}->{Config}->{PossibleValues};
    my $PossibleValues = $Self->PossibleValuesGet(%Param);

    # EO KIX4OTRS-capeIT

    if ($Value) {

        # check if there is a real value for this key (otherwise keep the key)
        # KIX4OTRS-capeIT
        # if ( $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value} ) {
        if ( $PossibleValues && ref($PossibleValues) eq 'HASH' && $PossibleValues->{$Value} ) {

            # EO KIX4OTRS-capeIT

            # get readeable value
            # KIX4OTRS-capeIT
            # $Value = $Param{DynamicFieldConfig}->{Config}->{PossibleValues}->{$Value};
            $Value = $PossibleValues->{$Value};

            # EO KIX4OTRS-capeIT

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
    }

    return $Value;
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
        TranslatableValues => $Param{DynamicFieldconfig}->{Config}->{TranslatableValues},
    };
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
