# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::ITSMConfigItemReference;

use strict;
use warnings;

use base qw(Kernel::System::DynamicField::Driver::Base);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Ticket::ColumnFilter',
);

=head1 NAME

Kernel::System::DynamicField::Driver::ITSMConfigItemReference

=head1 SYNOPSIS

DynamicFields ITSMConfigItemReference backend delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create additional objects
    $Self->{ConfigObject}            = $Kernel::OM->Get('Kernel::Config');
    $Self->{DynamicFieldValueObject} = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');
    $Self->{GeneralCatalogObject}    = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{ITSMConfigItemObject}    = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # get the fields config
    $Self->{FieldTypeConfig} = $Self->{ConfigObject}->Get('DynamicFields::Driver') || {};

    # set field behaviors
    $Self->{Behaviors} = {
        'IsACLReducible'               => 0,
        'IsNotificationEventCondition' => 1,
        'IsSortable'                   => 1,
        'IsFiltrable'                  => 1,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions = $Self->{ConfigObject}->Get('DynamicFields::Extension::Driver::ITSMConfigItemReference');

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

sub ValueGet {
    my ( $Self, %Param ) = @_;

    my $DFValue = $Self->{DynamicFieldValueObject}->ValueGet(
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

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    my $Success;
    if ( IsArrayRefWithData( \@Values ) ) {

        # if there is at least one value to set, this means one or more values are selected,
        #    set those values!
        my @ValueText;
        for my $Item (@Values) {
            push @ValueText, { ValueText => $Item };
        }

        $Success = $Self->{DynamicFieldValueObject}->ValueSet(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            Value    => \@ValueText,
            UserID   => $Param{UserID},
        );
    }
    else {

        # otherwise no value was selected, then in fact this means that any value there should be
        # deleted
        $Success = $Self->{DynamicFieldValueObject}->ValueDelete(
            FieldID  => $Param{DynamicFieldConfig}->{ID},
            ObjectID => $Param{ObjectID},
            UserID   => $Param{UserID},
        );
    }

    return $Success;
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

    # to store final values
    my @Values;

    KEYITEM:
    for my $Item ( @Keys ) {
        next KEYITEM if !$Item;

        # set the value as the key by default
        my $Value = $Item;

        # try to convert key to real value
        my $Number = $Self->{ITSMConfigItemObject}->ConfigItemLookup(
            ConfigItemID => $Item,
        );
        if ( $Number ) {
            my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
                ConfigItemID => $Item,
                XMLDataGet   => 0,
            );

            $Value = $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Name>';
            while ($Value =~ m/<CI_([^>]+)>/) {
                my $Replace = $ConfigItem->{$1} || '';
                $Value =~ s/<CI_$1>/$Replace/g;
            }
        }
        push ( @Values, $Value );
    }

    return \@Values;
}

sub ValueIsDifferent {
    my ( $Self, %Param ) = @_;

    # special cases where the values are different but they should be reported as equals
    if (
        !defined $Param{Value1}
        && ref $Param{Value2} eq 'ARRAY'
        && !IsArrayRefWithData( $Param{Value2} )
        )
    {
        return
    }
    if (
        !defined $Param{Value2}
        && ref $Param{Value1} eq 'ARRAY'
        && !IsArrayRefWithData( $Param{Value1} )
        )
    {
        return
    }

    # compare the results
    return DataIsDifferent(
        Data1 => \$Param{Value1},
        Data2 => \$Param{Value2}
    );
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

    my $Success;
    for my $Item (@Values) {

        $Success = $Self->{DynamicFieldValueObject}->ValueValidate(
            Value => {
                ValueText => $Item,
            },
            UserID => $Param{UserID}
        );

        return if !$Success
    }

    return $Success;
}

sub PossibleValuesGet {
    my ( $Self, %Param ) = @_;

    my %PossibleValues;

    # get used Constrictions
    my $Constrictions = $Param{DynamicFieldConfig}->{Config}->{Constrictions};

    # build search params from constrictions...
    my @SearchParamsWhat;

    # prepare constrictions
    my %Constrictions = ();
    if ( $Constrictions ) {
        my @Constrictions = split(/[\n\r]+/, $Constrictions);
        CONSTRICTION:
        for my $Constriction ( @Constrictions ) {
            my @ConstrictionRule = split(/::/, $Constriction);
            my $ConstrictionCheck = 1;
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
                $Constrictions{$ConstrictionRule[0]} = $ConstrictionRule[2];
            }
        }
    }

    my @ITSMConfigItemClasses = ();
    if(
        defined( $Param{DynamicFieldConfig}->{Config}->{ITSMConfigItemClasses} )
        && IsArrayRefWithData( $Param{DynamicFieldConfig}->{Config}->{ITSMConfigItemClasses} )
    ) {
        @ITSMConfigItemClasses = @{$Param{DynamicFieldConfig}->{Config}->{ITSMConfigItemClasses}};
    }
    else {
        my $ClassRef = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );
        for my $ClassID ( keys ( %{$ClassRef} ) ) {
            push ( @ITSMConfigItemClasses, $ClassID );
        }
    }

    for my $ClassID ( @ITSMConfigItemClasses ) {
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

    my $ConfigItemIDs = $Self->{ITSMConfigItemObject}->ConfigItemSearchExtended(
        Name         => '*',
        ClassIDs     => \@ITSMConfigItemClasses,
        DeplStateIDs => $Param{DynamicFieldConfig}->{Config}->{DeploymentStates},
        What         => \@SearchParamsWhat,
    );

    for my $CIID ( @{$ConfigItemIDs} ) {
        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $CIID,
            XMLDataGet   => 0,
        );

        my $Label = $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Name>';
        while ($Label =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $Label =~ s/<CI_$1>/$Replace/g;
        }

        $PossibleValues{$CIID} = $Label;
    }

    # return the possible values hash as a reference
    return \%PossibleValues;
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

sub EditFieldRender {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldID     = $Param{DynamicFieldConfig}->{ID};
    my $FieldName   = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $FieldLabel  = $Param{DynamicFieldConfig}->{Label};

    my $Value;

    # set the field value or default
    if ( $Param{UseDefaultValue} ) {
        $Value = ( defined $FieldConfig->{DefaultValues} ? $FieldConfig->{DefaultValues} : '' );
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
    my $FieldClass = '';
    if ( defined $Param{Class} && $Param{Class} ne '' ) {
        $FieldClass = $Param{Class};
    }

    # set field as mandatory
    if ( $Param{Mandatory} ) {
        $FieldClass .= ' Validate_Required';
    }

    # set error css class
    if ( $Param{ServerError} ) {
        $FieldClass .= ' ServerError';
    }

    # check value
    my $SelectedValuesArrayRef = [];
    if ( defined $Value ) {
        if ( ref $Value eq 'ARRAY' ) {
            $SelectedValuesArrayRef = $Value;
        }
        else {
            $SelectedValuesArrayRef = [$Value];
        }
    }

    my $AutoCompleteFieldName = $FieldName . "_AutoComplete";
    my $ContainerFieldName    = $FieldName . "_Container";
    my $DisplayFieldName      = $FieldName . "_Display";
    my $IDCounterName         = $FieldName . "_IDCount";
    my $ValidateFieldName     = $FieldName . "_Validate";
    my $ValueFieldName        = $FieldName . "_";

    my $MaxArraySize          = $FieldConfig->{MaxArraySize} || 1;

    # get used Constrictions
    my $ConstrictionString = $FieldName . ';TicketID';
    my $Constrictions      = $Param{DynamicFieldConfig}->{Config}->{Constrictions};
    if ( $Constrictions ) {
        my $CustomerConstriction = 0;
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
                $ConstrictionRule[1] eq 'Ticket'
            ) {
                $ConstrictionString .= ';' . $ConstrictionRule[2];
            }
            elsif (
                $ConstrictionRule[1] eq 'CustomerUser'
            ) {
                $CustomerConstriction = 1;
            }
        }
        if ( $CustomerConstriction ) {
            $ConstrictionString .= ';CustomerUserID;SelectedCustomerUser';
        }
    }

    my $TranslateRemoveSelection = $Param{LayoutObject}->{LanguageObject}->Translate("Remove selection");

    my $HTMLString = <<"END";
    <input id="$FieldName" type="text" style="display:none;" />
    <div class="InputField_Container W50pc">
        <input id="$AutoCompleteFieldName" type="text" style="margin-bottom:2px;" />
        <div class="Clear"></div>
        <div id="$ContainerFieldName" class="InputField_InputContainer" style="display:block;">
END

    my $ValueCounter = 0;
    for my $Key ( @{ $SelectedValuesArrayRef } ) {
        next if (!$Key);
        $ValueCounter++;

        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $Label = $FieldConfig->{DisplayPattern} || '<CI_Name>';
        while ($Label =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $Label =~ s/<CI_$1>/$Replace/g;
        }

        my $Title = $ConfigItem->{Name};

        $HTMLString .= <<"END";
        <div class="InputField_Selection" style="display:block;position:inherit;top:0px;">
            <input id="$ValueFieldName$ValueCounter" type="hidden" name="$FieldName" value="$Key" />
            <div class="Text" title="$Title">$Label</div><div class="Remove"><a href="#" role="button" title="$TranslateRemoveSelection" tabindex="-1" aria-label="$TranslateRemoveSelection: $Label">x</a></div>
            <div class="Clear"></div>
        </div>
END
    }

    my $ValidValue = "";
    if($ValueCounter){
       $ValidValue = '1';
    }

    $HTMLString .= <<"END";
        </div>
        <input id="$ValidateFieldName" type="text" class="$FieldClass" value="$ValidValue" style="display:none;" />
        <div class="Clear"></div>
    </div>
END

    $Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"END");
Core.Config.Set('DynamicFieldITSMConfigItem.TranslateRemoveSelection', '$TranslateRemoveSelection');
DynamicFieldITSMConfigItem.InitEditField("$FieldName", "$FieldID", "$MaxArraySize", "$ValueCounter", "$FieldConfig->{QueryDelay}", "$FieldConfig->{MinQueryLength}", "$ConstrictionString");
END

    my $JSValueCounter = 0;
    for my $Key ( @{ $SelectedValuesArrayRef } ) {
        next if (!$Key);
        $JSValueCounter++;

        $Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"END");
DynamicFieldITSMConfigItem.InitEditValue("$FieldName", "$JSValueCounter");
END
    }

    if ( $Param{Mandatory} ) {
        my $DivID = $FieldName . 'Error';

        my $FieldRequiredMessage = $Param{LayoutObject}->{LanguageObject}->Translate("This field is required.");

        # for client side validation
        $HTMLString .= <<"END";
        <div id="$DivID" class="TooltipErrorMessage">
            <p>
                $FieldRequiredMessage
            </p>
        </div>
END
    }

    if ( $Param{ServerError} ) {

        my $ErrorMessage = $Param{ErrorMessage} || 'This field is required.';
        $ErrorMessage = $Param{LayoutObject}->{LanguageObject}->Translate($ErrorMessage);
        my $DivID = $FieldName . 'ServerError';

        # for server side validation
        $HTMLString .= <<"END";
        <div id="$DivID" class="TooltipErrorMessage">
            <p>
                $ErrorMessage
            </p>
        </div>
END
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
        $Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"END");
DynamicFieldITSMConfigItem.InitAJAXUpdate("$FieldName", [ $FieldsToUpdate ]);
END
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
    if ( IsHashRefWithData( $Param{Template} ) ) {
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

        # validate if value is id of config item
        for my $Item ( @{$Values} ) {
            my $Number = $Self->{ITSMConfigItemObject}->ConfigItemLookup(
                ConfigItemID => $Item,
            );
            if ( !$Number ) {
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

sub SearchFieldRender {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldID     = $Param{DynamicFieldConfig}->{ID};
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
    my $FieldValue = $Self->SearchFieldValueGet(%Param);

    # set values from ParamObject if present
    if ( IsArrayRefWithData($FieldValue) ) {
        $Value = $FieldValue;
    }

    # check and set class if necessary
    my $FieldClass = '';

    my $AutoCompleteFieldName = $FieldName . "_AutoComplete";
    my $ContainerFieldName    = $FieldName . "_Container";
    my $DisplayFieldName      = $FieldName . "_Display";
    my $IDCounterName         = $FieldName . "_IDCount";
    my $ValueFieldName        = $FieldName . "_";

    my $MaxArraySize          = $FieldConfig->{MaxArraySize} || 1;

    my $TranslateRemoveSelection = $Param{LayoutObject}->{LanguageObject}->Translate("Remove selection");

    my $HTMLString = <<"END";
    <div class="InputField_Container W50pc">
        <input id="$AutoCompleteFieldName" type="text" style="margin-bottom:2px;" />
        <div class="Clear"></div>
        <div id="$ContainerFieldName" class="InputField_InputContainer" style="display:block;">
END

    my $ValueCounter = 0;
    for my $Key ( @{ $Value } ) {
        next if (!$Key);
        $ValueCounter++;

        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $Label = $FieldConfig->{DisplayPattern} || '<CI_Name>';
        while ($Label =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $Label =~ s/<CI_$1>/$Replace/g;
        }

        my $Title = $ConfigItem->{Name};

        $HTMLString .= <<"END";
        <div class="InputField_Selection" style="display:block;position:inherit;top:0px;">
            <input id="$ValueFieldName$ValueCounter" type="hidden" name="$FieldName" value="$Key" />
            <div class="Text" title="$Title">$Label</div><div class="Remove"><a href="#" role="button" title="$TranslateRemoveSelection" tabindex="-1" aria-label="$TranslateRemoveSelection: $Label">x</a></div>
            <div class="Clear"></div>
        </div>
<script type="text/javascript">//<![CDATA[
    function Init$ValueFieldName$ValueCounter() {
        \$('#$ValueFieldName$ValueCounter').siblings('div.Remove').find('a').bind('click', function() {
            \$('#$ValueFieldName$ValueCounter').parent().remove();
            if (\$('input[name=$FieldName]').length == 0) {
                \$('#$ContainerFieldName').hide();
            }
            return false;
        });
    }
    function Wait$ValueFieldName$ValueCounter() {
        if (window.jQuery) {
            \$('#Attribute').bind('redraw.InputField', function() {
                Init$ValueFieldName$ValueCounter();
            });
            if (
                \$('form[name=compose] input[name=Action]').first().val() == 'AdminGenericAgent'
                && \$('form[name=compose] input[name=Subaction]').first().val() == 'UpdateAction'
            ) {
                Init$ValueFieldName$ValueCounter();
            }
        } else {
            window.setTimeout(Wait$ValueFieldName$ValueCounter, 1);
        }
    }
    window.setTimeout(Wait$ValueFieldName$ValueCounter, 0);
//]]></script>
END
    }

    $HTMLString .= <<"END";
        </div>
        <div class="Clear"></div>
    </div>
<script type="text/javascript">//<![CDATA[
    function Init$AutoCompleteFieldName() {
        var $IDCounterName = $ValueCounter;
        \$('#$AutoCompleteFieldName').autocomplete({
            delay: $FieldConfig->{QueryDelay},
            minLength: $FieldConfig->{MinQueryLength},
            source: function (Request, Response) {
                var Data = {};
                Data.Action         = 'DynamicFieldITSMConfigItemAJAXHandler';
                Data.Subaction      = 'Search';
                Data.ConfigOnly     = '1';
                Data.FieldPrefix    = 'Search_';
                Data.Search         = Request.term;
                Data.DynamicFieldID = $FieldID;

                var QueryString = Core.AJAX.SerializeForm(\$('#$AutoCompleteFieldName'), Data);
                \$.each(Data, function (Key, Value) {
                    QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
                });

                if (\$('#$AutoCompleteFieldName').data('AutoCompleteXHR')) {
                    \$('#$AutoCompleteFieldName').data('AutoCompleteXHR').abort();
                    \$('#$AutoCompleteFieldName').removeData('AutoCompleteXHR');
                }
                \$('#$AutoCompleteFieldName').data('AutoCompleteXHR', Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), QueryString, function (Result) {
                    var Data = [];
                    \$.each(Result, function () {
                        Data.push({
                            key:   this.Key,
                            value: this.Value,
                            title: this.Title
                        });
                    });
                    \$('#$AutoCompleteFieldName').data('AutoCompleteData', Data);
                    \$('#$AutoCompleteFieldName').removeData('AutoCompleteXHR');
                    Response(Data);
                }).fail(function() {
                    Response(\$('#$AutoCompleteFieldName').data('AutoCompleteData'));
                }));
            },
            select: function (Event, UI) {
                $IDCounterName++;
                \$('#$ContainerFieldName').append(
                    '<div class="InputField_Selection" style="display:block;position:inherit;top:0px;">'
                    + '<input id="$ValueFieldName'
                    + $IDCounterName
                    + '" type="hidden" name="$FieldName" value="'
                    + UI.item.key
                    + '" />'
                    + '<div class="Text" title="'
                    + UI.item.title
                    + '">'
                    + UI.item.value
                    + '</div>'
                    + '<div class="Remove"><a href="#" role="button" title="$TranslateRemoveSelection" tabindex="-1" aria-label="$TranslateRemoveSelection: '
                    + UI.item.value
                    + '">x</a></div><div class="Clear"></div>'
                    + '</div>'
                );
                \$('#$ValueFieldName' + $IDCounterName).siblings('div.Remove').find('a').data('counter', $IDCounterName);
                \$('#$ValueFieldName' + $IDCounterName).siblings('div.Remove').find('a').bind('click', function() {
                    \$('#$ValueFieldName' + \$(this).data('counter')).parent().remove();
                    if (\$('input[name=$FieldName]').length == 0) {
                        \$('#$ContainerFieldName').hide();
                    }
                    return false;
                });
                \$('#$ContainerFieldName').show();
                \$('#$AutoCompleteFieldName').val('');
                Event.preventDefault();
                return false;
            },
        });
        \$('#$AutoCompleteFieldName').blur(function() {
            \$(this).val('');
        });

        if (\$('input[name=$FieldName]').length == 0) {
            \$('#$ContainerFieldName').hide();
        }
    }
    function Wait$AutoCompleteFieldName() {
        if (window.jQuery) {
            \$('#Attribute').bind('redraw.InputField', function() {
                Init$AutoCompleteFieldName();
            });
            if (
                \$('form[name=compose] input[name=Action]').first().val() == 'AdminGenericAgent'
                && \$('form[name=compose] input[name=Subaction]').first().val() == 'UpdateAction'
            ) {
                Init$AutoCompleteFieldName();
            }
        } else {
            window.setTimeout(Wait$AutoCompleteFieldName, 1);
        }
    }
    window.setTimeout(Wait$AutoCompleteFieldName, 0);
//]]></script>
END

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

sub SearchFieldValueGet {
    my ( $Self, %Param ) = @_;

    my $Value;

    # get dynamic field value from param object
    if ( defined $Param{ParamObject} ) {
        my @FieldValues = $Param{ParamObject}->GetArray(
            Param => 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name}
        );

        $Value = \@FieldValues;
    }

    # otherwise get the value from the profile
    elsif ( defined $Param{Profile} ) {
        $Value = $Param{Profile}->{ 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name} };
    }
    else {
        return;
    }

    if ( defined $Param{ReturnProfileStructure} && $Param{ReturnProfileStructure} eq 1 ) {
        return {
            'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name} => $Value,
        };
    }

    return $Value;
}

sub SearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    # get field value
    my $Value = $Self->SearchFieldValueGet(%Param);

    my $DisplayValue;

    if ( defined $Value && !$Value ) {
        $DisplayValue = '';
    }

    if ($Value) {
        if ( ref $Value eq 'ARRAY' ) {

            my @DisplayItemList;
            for my $Item ( @{$Value} ) {

                # set the display value
                my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
                    ConfigItemID => $Item,
                    XMLDataGet   => 0,
                );

                my $DisplayItem = $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Name>';
                while ($DisplayItem =~ m/<CI_([^>]+)>/) {
                    my $Replace = $ConfigItem->{$1} || '';
                    $DisplayItem =~ s/<CI_$1>/$Replace/g;
                }

                push @DisplayItemList, $DisplayItem;
            }

            # combine different values into one string
            $DisplayValue = join ' + ', @DisplayItemList;
        }
        else {

            # set the display value
            my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
                ConfigItemID => $Value,
                XMLDataGet   => 0,
            );

            $DisplayValue = $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Name>';
            while ($DisplayValue =~ m/<CI_([^>]+)>/) {
                my $Replace = $ConfigItem->{$1} || '';
                $DisplayValue =~ s/<CI_$1>/$Replace/g;
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

sub SearchSQLGet {
    my ( $Self, %Param ) = @_;

    my %Operators = (
        Equals            => '=',
        GreaterThan       => '>',
        GreaterThanEquals => '>=',
        SmallerThan       => '<',
        SmallerThanEquals => '<=',
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( $Operators{ $Param{Operator} } ) {
        my $SQL = " $Param{TableAlias}.value_text $Operators{$Param{Operator}} '";
        $SQL .= $DBObject->Quote( $Param{SearchTerm} ) . "' ";
        return $SQL;
    }

    if ( $Param{Operator} eq 'Like' ) {

        my $SQL = $DBObject->QueryCondition(
            Key   => "$Param{TableAlias}.value_text",
            Value => $Param{SearchTerm},
        );

        return $SQL;
    }

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        'Priority' => 'error',
        'Message'  => "Unsupported Operator $Param{Operator}",
    );

    return;
}

sub SearchSQLOrderFieldGet {
    my ( $Self, %Param ) = @_;

    return "$Param{TableAlias}.value_text";
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
    my $ItemSeparator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator} || ', ';

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

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOuput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    # get raw Value strings from field value
    my @Keys;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Keys = @{ $Param{Value} };
    }
    else {
        @Keys = ( $Param{Value} );
    }

    my @Values;
    my @Titles;

    for my $Key (@Keys) {
        next if ( !$Key );

        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $EntryValue = $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Name>';
        while ($EntryValue =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $EntryValue =~ s/<CI_$1>/$Replace/g;
        }

        # set title as value after update and before limit
        my $EntryTitle = $EntryValue;

        # HTMLOuput transformations
        if ( $Param{HTMLOutput} ) {
            $EntryValue = $Param{LayoutObject}->Ascii2Html(
                Text => $EntryValue,
                Max => $Param{ValueMaxChars} || '',
            );

            $EntryTitle = $Param{LayoutObject}->Ascii2Html(
                Text => $EntryTitle,
                Max => $Param{TitleMaxChars} || '',
            );

            # set field link form config
            my $HasLink = 0;
            if (
                $Param{LayoutObject}->{UserType} eq 'User'
                && $Param{DynamicFieldConfig}->{Config}->{AgentLink}
                )
            {
                $EntryValue
                    = '<a href="'
                    . $Param{DynamicFieldConfig}->{Config}->{AgentLink}
                    . '" title="'
                    . $EntryTitle
                    . '" target="_blank" class="DynamicFieldLink">'
                    . $EntryValue . '</a>';
                $HasLink = 1;
            }
            elsif (
                $Param{LayoutObject}->{UserType} eq 'Customer'
                && $Param{DynamicFieldConfig}->{Config}->{CustomerLink}
                )
            {
                $EntryValue
                    = '<a href="'
                    . $Param{DynamicFieldConfig}->{Config}->{CustomerLink}
                    . '" title="'
                    . $EntryTitle
                    . '" target="_blank" class="DynamicFieldLink">'
                    . $EntryValue . '</a>';
                $HasLink = 1;
            }
            if ($HasLink) {
                while ($EntryValue =~ m/<CI_([^>]+)>/) {
                    my $Replace = $Param{LayoutObject}->LinkEncode($ConfigItem->{$1}) || '';
                    $EntryValue =~ s/<CI_$1>/$Replace/g;
                }

                # Replace <SessionID>
                if ( $EntryValue =~ /<SessionID>/ ) {
                    my $Replace = $Param{LayoutObject}->{SessionID};
                    $EntryValue =~ s/<SessionID>/$Replace/g;
                }
            }
        }
        else {
            if ( $Param{ValueMaxChars} && length($EntryValue) > $Param{ValueMaxChars} ) {
                $EntryValue = substr( $EntryValue, 0, $Param{ValueMaxChars} ) . '...';
            }
            if ( $Param{TitleMaxChars} && length($EntryTitle) > $Param{TitleMaxChars} ) {
                $EntryTitle = substr( $EntryTitle, 0, $Param{TitleMaxChars} ) . '...';
            }
        }

        push ( @Values, $EntryValue );
        push ( @Titles, $EntryTitle );
    }

    # set item separator
    my $ItemSeparator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator} || ', ';

    my $Value = join( $ItemSeparator, @Values );
    my $Title = join( $ItemSeparator, @Titles );

    # this field type does not support the Link Feature in normal way. Links are provided via Value in HTMLOutput
    my $Link;

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
        Link  => $Link,
    };

    return $Data;
}

sub StatsFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    my @ITSMConfigItemClasses = ();
    if(
        defined( $Param{DynamicFieldConfig}->{Config}->{ITSMConfigItemClasses} )
        && IsArrayRefWithData( $Param{DynamicFieldConfig}->{Config}->{ITSMConfigItemClasses} )
    ) {
        @ITSMConfigItemClasses = @{$Param{DynamicFieldConfig}->{Config}->{ITSMConfigItemClasses}};
    }
    else {
        my $ClassRef = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::ConfigItem::Class',
        );
        for my $ClassID ( keys ( %{$ClassRef} ) ) {
            push ( @ITSMConfigItemClasses, $ClassID );
        }
    }

    # set PossibleValues
    my $Values;

    my %DefaultValuesList;

    my $DeplStates = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    my $ConfigItemIDs = $Self->{ITSMConfigItemObject}->ConfigItemSearch(
        ClassIDs     => \@ITSMConfigItemClasses,
        DeplStateIDs => $Param{DynamicFieldConfig}->{Config}->{DeploymentStates},
        UserID       => $Param{UserID},
    );

    for my $CIID ( @{$ConfigItemIDs} ) {
        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $CIID,
        );

        $DefaultValuesList{$CIID} = $Param{DynamicFieldConfig}->{Config}->{DisplayPattern} || '<CI_Name>';
        while ($DefaultValuesList{$CIID} =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $DefaultValuesList{$CIID} =~ s/<CI_$1>/$Replace/g;
        }
    }

    $Values = \%DefaultValuesList;

    # get historical values from database
    my $HistoricalValues = $Self->{DynamicFieldValueObject}->HistoricalValueGet(
        FieldID   => $Param{DynamicFieldConfig}->{ID},
        ValueType => 'Text,',
    );

    # add historic values to current values (if they don't exist anymore)
    for my $Key ( keys ( %{$HistoricalValues} ) ) {
        if ( !$Values->{$Key} ) {
            $Values->{$Key} = $HistoricalValues->{$Key}
        }
    }

    # use PossibleValuesFilter if defined
    $Values = $Param{PossibleValuesFilter} if ( defined($Param{PossibleValuesFilter}) );

    return {
        Values             => $Values,
        Name               => $Param{DynamicFieldConfig}->{Label},
        Element            => 'DynamicField_' . $Param{DynamicFieldConfig}->{Name},
        Block              => 'MultiSelectField',
    };
}

sub StatsSearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    my $Operator = 'Equals';
    my $Value    = $Param{Value};

    return {
        $Operator => $Value,
    };
}

sub ColumnFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};

    # get column filter values from database
    my $ColumnFilterValues = $Kernel::OM->Get('Kernel::System::Ticket::ColumnFilter')->DynamicFieldFilterValuesGet(
        TicketIDs => $Param{TicketIDs},
        FieldID   => $Param{DynamicFieldConfig}->{ID},
        ValueType => 'Text',
    );

    # get the display value if still exist in dynamic field configuration
    for my $Key ( sort ( keys ( %{$ColumnFilterValues} ) ) ) {
        my $ConfigItem = $Self->{ITSMConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 0,
        );

        my $Value = $FieldConfig->{DisplayPattern} || '<CI_Name>';
        while ($Value =~ m/<CI_([^>]+)>/) {
            my $Replace = $ConfigItem->{$1} || '';
            $Value =~ s/<CI_$1>/$Replace/g;
        }
        $ColumnFilterValues->{$Key} = $Value;
    }

    return $ColumnFilterValues;
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
