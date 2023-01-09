# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::Date;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use Kernel::Language qw(Translatable);

use base qw(Kernel::System::DynamicField::Driver::BaseDateTime);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::Main',
    'Kernel::System::Log',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::DynamicField::Driver::Date

=head1 SYNOPSIS

DynamicFields Date Driver delegate

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
        'IsACLReducible'               => 0,
        'IsNotificationEventCondition' => 0,
        'IsSortable'                   => 1,
        'IsFiltrable'                  => 0,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
        'CanRandomize'                 => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Extension::Driver::Date');

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
            ) {
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

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check for no time in date fields
    if ( $Param{Value} && $Param{Value} !~ m{\A \d{4}-\d{2}-\d{2}\s00:00:00 \z}xms ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The value for the field Date is invalid!\n"
                . "The date must be valid and the time must be 00:00:00",
        );
        return;
    }

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->ValueSet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
        Value    => [
            {
                ValueDateTime => $Param{Value},
            },
        ],
        UserID => $Param{UserID},
    );

    return $Success;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    my $Prefix          = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $DateRestriction = $Param{DynamicFieldConfig}->{Config}->{DateRestriction};

    # check for no time in date fields
    if (
        $Param{Value}
        && $Param{Value} !~ m{\A \d{4}-\d{2}-\d{2}\s00:00:00 \z}xms
        && $Param{Value} !~ m{\A \d{4}-\d{2}-\d{2}\s23:59:59 \z}xms
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The value for the field Date is invalid!\n"
                . "The date must be valid and the time must be 00:00:00"
                . " (or 23:59:59 for search parameters)",
        );
        return;
    }

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->ValueValidate(
        Value => {
            ValueDateTime => $Param{Value},
        },
        UserID => $Param{UserID},
    );

    if (
        !$Param{SearchValidation}
        && $DateRestriction
    ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        my $ValueSystemTime = $TimeObject->TimeStamp2SystemTime(
            String => $Param{Value},
        );
        my $SystemTime = $TimeObject->SystemTime();
        my ( $SystemTimePast, $SystemTimeFuture ) = $SystemTime;

        # if validating date only value, allow today for selection
        if ( $Param{DynamicFieldConfig}->{FieldType} eq 'Date' ) {

            # calculate today system time boundaries
            my @Today = $TimeObject->SystemTime2Date(
                SystemTime => $SystemTime,
            );
            $SystemTimePast = $TimeObject->Date2SystemTime(
                Year   => $Today[5],
                Month  => $Today[4],
                Day    => $Today[3],
                Hour   => 0,
                Minute => 0,
                Second => 0,
            );
            $SystemTimeFuture = $SystemTimePast + 60 * 60 * 24 - 1;    # 23:59:59
        }

        if ( $DateRestriction eq 'DisableFutureDates' && $ValueSystemTime > $SystemTimeFuture ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "The value for the field Date is in the future! The date needs to be in the past!",
            );
            return;
        }
        elsif ( $DateRestriction eq 'DisablePastDates' && $ValueSystemTime < $SystemTimePast ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "The value for the field Date is in the past! The date needs to be in the future!",
            );
            return;
        }
    }

    return $Success;
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

    if ( $Operators{ $Param{Operator} } ) {
        my $SQL = " $Param{TableAlias}.value_date $Operators{$Param{Operator}} '"
            . $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{SearchTerm} );

        # Append hh:mm:ss if only the ISO date was supplied to get a full date-time string.
        if ( $Param{SearchTerm} =~ m{\A \d{4}-\d{2}-\d{2}\z}xms ) {
            $SQL .= " 00:00:00";
        }

        $SQL .= "' ";
        return $SQL;
    }

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        'Priority' => 'error',
        'Message'  => "Unsupported Operator $Param{Operator}",
    );

    return;
}

sub EditFieldRender {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldName   = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $FieldLabel  = $Param{DynamicFieldConfig}->{Label};

    my $Value;

    # set the field value or default
    if ( $Param{UseDefaultValue} ) {
        $Value = $FieldConfig->{DefaultValue} || '';
    }

    my %SplitedFieldValues;
    if ( defined $Param{Value} ) {
        $Value = $Param{Value};
    }
    if ($Value) {
        my ( $Year, $Month, $Day, $Hour, $Minute, $Second ) = $Value =~
            m{ \A ( \d{4} ) - ( \d{2} ) - ( \d{2} ) \s ( \d{2} ) : ( \d{2} ) : ( \d{2} ) \z }xms;

        %SplitedFieldValues = (

            # if a value is sent this value must be active, then the Used part needs to be set to 1
            # otherwise user can easily forget to mark the checkbox and this could lead into data
            # lost Bug#8258
            $FieldName . 'Used'   => 1,
            $FieldName . 'Year'   => $Year,
            $FieldName . 'Month'  => $Month,
            $FieldName . 'Day'    => $Day,
            $FieldName . 'Hour'   => $Hour,
            $FieldName . 'Minute' => $Minute,
        );
    }

    # extract the dynamic field value form the web request
    my $FieldValues = $Self->EditFieldValueGet(
        ReturnValueStructure => 1,
        %Param,
    );

    # set values from ParamObject if present
    if ( defined $FieldValues && IsHashRefWithData($FieldValues) ) {
        for my $Type (qw(Used Year Month Day Hour Minute)) {
            $FieldConfig->{ $FieldName . $Type } = $FieldValues->{ $FieldName . $Type };
        }
    }

    # check and set class if necessary
    my $FieldClass = 'DynamicFieldText';
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

    # to set the predefined based on a time difference
    my $DiffTime = $FieldConfig->{DefaultValue};
    if ( !defined $DiffTime || $DiffTime !~ m/^ \s* -? \d+ \s* $/smx ) {
        $DiffTime = 0;
    }

    # to set the years range
    my %YearsPeriodRange;
    if ( defined $FieldConfig->{YearsPeriod} && $FieldConfig->{YearsPeriod} eq '1' ) {
        %YearsPeriodRange = (
            YearPeriodPast   => $FieldConfig->{YearsInPast}   || 0,
            YearPeriodFuture => $FieldConfig->{YearsInFuture} || 0,
        );
    }

    # date restrictions
    if ( $FieldConfig->{DateRestriction} ) {
        if ( $FieldConfig->{DateRestriction} eq 'DisablePastDates' ) {
            $FieldConfig->{ValidateDateInFuture} = 1;
        }
        elsif ( $FieldConfig->{DateRestriction} eq 'DisableFutureDates' ) {
            $FieldConfig->{ValidateDateNotInFuture} = 1;
        }
    }

    my $HTMLString = $Param{LayoutObject}->BuildDateSelection(
        %Param,
        Prefix               => $FieldName,
        Format               => 'DateInputFormat',
        $FieldName . 'Class' => $FieldClass,
        DiffTime             => $DiffTime,
        $FieldName . Required => $Param{Mandatory} || 0,
        $FieldName . Optional => 1,
        Validate              => 1,
        %{$FieldConfig},
        %SplitedFieldValues,
        %YearsPeriodRange,
        OverrideTimeZone => 1,
    );

    if ( $Param{Mandatory} ) {
        my $DivID = $FieldName . 'UsedError';

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

    if ( $Param{AJAXUpdate} ) {

        my $FieldSelector = '#' . $FieldName . 'Used';

        my $FieldsToUpdate = '';
        if ( IsArrayRefWithData( $Param{UpdatableFields} ) ) {

            # Remove current field from updatable fields list
            my @FieldsToUpdate = grep { $_ ne $FieldName } @{ $Param{UpdatableFields} };

            # quote all fields, put commas in between them
            $FieldsToUpdate = join( ', ', map {"'$_'"} @FieldsToUpdate );
        }

        # add js to call FormUpdate()
        $Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"EOF");
\$('$FieldSelector').on('change', function (Event) {
    Core.AJAX.FormUpdate(\$(this).parents('form'), 'AJAXUpdate', '$FieldName', [ $FieldsToUpdate ]);
});
EOF
    }

    if ( $Param{ServerError} ) {

        my $ErrorMessage = $Param{ErrorMessage} || 'This field is required.';
        $ErrorMessage = $Param{LayoutObject}->{LanguageObject}->Translate($ErrorMessage);
        my $DivID = $FieldName . 'UsedServerError';

        # for server side validation
        $HTMLString .= <<"EOF";

<div id="$DivID" class="TooltipErrorMessage">
    <p>
        $ErrorMessage
    </p>
</div>
EOF
    }

    # call EditLabelRender on the common Driver
    my $LabelString = $Self->EditLabelRender(
        %Param,
        Mandatory => $Param{Mandatory} || '0',
        FieldName => $FieldName . 'Used',
    );

    my $Data = {
        Field => $HTMLString,
        Label => $LabelString,
    };

    return $Data;
}

sub EditFieldValueGet {
    my ( $Self, %Param ) = @_;

    # set the Prefix as the dynamic field name
    my $Prefix = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    my %DynamicFieldValues;

    # check if there is a Template and retrieve the dynamic field value from there
    if ( IsHashRefWithData( $Param{Template} ) && defined $Param{Template}->{ $Prefix . 'Used' } ) {
        for my $Type (qw(Used Year Month Day)) {
            $DynamicFieldValues{ $Prefix . $Type } = $Param{Template}->{ $Prefix . $Type } || 0;
        }
    }

    # otherwise get dynamic field value from the web request
    elsif (
        defined $Param{ParamObject}
        && ref $Param{ParamObject} eq 'Kernel::System::Web::Request'
    ) {
        for my $Type (qw(Used Year Month Day)) {
            $DynamicFieldValues{ $Prefix . $Type } = $Param{ParamObject}->GetParam(
                Param => $Prefix . $Type,
            ) || 0;
        }
    }

    # complete the rest of the date with 0s to have a valid Date/Time value
    for my $Type (qw(Hour Minute)) {
        $DynamicFieldValues{ $Prefix . $Type } = 0;
    }

    # return if the field is empty (e.g. initial screen)
    return if !$DynamicFieldValues{ $Prefix . 'Used' }
        && !$DynamicFieldValues{ $Prefix . 'Year' }
        && !$DynamicFieldValues{ $Prefix . 'Month' }
        && !$DynamicFieldValues{ $Prefix . 'Day' };

    # check if return value structure is needed
    if ( defined $Param{ReturnValueStructure} && $Param{ReturnValueStructure} eq '1' ) {
        return \%DynamicFieldValues;
    }

    # check if return template structure is needed
    if ( defined $Param{ReturnTemplateStructure} && $Param{ReturnTemplateStructure} eq '1' ) {
        return \%DynamicFieldValues;
    }

    # add seconds, as 0 to the DynamicFieldValues hash
    $DynamicFieldValues{ 'DynamicField_' . $Param{DynamicFieldConfig}->{Name} . 'Second' } = 0;

    my $ManualTimeStamp = '';

    if ( $DynamicFieldValues{ $Prefix . 'Used' } ) {

        # add a leading zero for date parts that could be less than ten to generate a correct
        # time stamp
        for my $Type (qw(Month Day Hour Minute Second)) {
            $DynamicFieldValues{ $Prefix . $Type } = sprintf "%02d",
                $DynamicFieldValues{ $Prefix . $Type };
        }
        my $Year  = $DynamicFieldValues{ $Prefix . 'Year' }  || '0000';
        my $Month = $DynamicFieldValues{ $Prefix . 'Month' } || '00';
        my $Day   = $DynamicFieldValues{ $Prefix . 'Day' }   || '00';
        my $Hour  = '00';
        my $Minute = '00';
        my $Second = '00';

        $ManualTimeStamp =
            $Year . '-' . $Month . '-' . $Day . ' '
            . $Hour . ':' . $Minute . ':' . $Second;
    }

    return $ManualTimeStamp;
}

sub EditFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # get the field value from the http request
    my $Value = $Self->EditFieldValueGet(
        DynamicFieldConfig   => $Param{DynamicFieldConfig},
        ParamObject          => $Param{ParamObject},
        ReturnValueStructure => 1,
    );

    # on normal basis Used field could be empty but if there was no value from EditFieldValueGet()
    # it must be an error
    if ( !defined $Value ) {
        return {
            ServerError  => 1,
            ErrorMessage => 'Invalid Date!'
        };
    }

    my $ServerError;
    my $ErrorMessage;

    # set the date time prefix as field name
    my $Prefix = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # date restriction
    my $DateRestriction = $Param{DynamicFieldConfig}->{Config}->{DateRestriction};

    # perform necessary validations
    if ( $Param{Mandatory} && !$Value->{ $Prefix . 'Used' } ) {
        $ServerError = 1;
    }

    if ( $Value->{ $Prefix . 'Used' } && $DateRestriction ) {

        my $Year   = $Value->{ $Prefix . 'Year' }   || '0000';
        my $Month  = $Value->{ $Prefix . 'Month' }  || '00';
        my $Day    = $Value->{ $Prefix . 'Day' }    || '00';
        my $Hour   = $Value->{ $Prefix . 'Hour' }   || '00';
        my $Minute = $Value->{ $Prefix . 'Minute' } || '00';
        my $Second = $Value->{ $Prefix . 'Second' } || '00';

        my $ManualTimeStamp =
            $Year . '-' . $Month . '-' . $Day . ' '
            . $Hour . ':' . $Minute . ':' . $Second;

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        my $ValueSystemTime = $TimeObject->TimeStamp2SystemTime(
            String => $ManualTimeStamp,
        );
        my $SystemTime = $TimeObject->SystemTime();
        my ( $SystemTimePast, $SystemTimeFuture ) = $SystemTime;

        # if validating date only value, allow today for selection
        if ( $Param{DynamicFieldConfig}->{FieldType} eq 'Date' ) {

            # calculate today system time boundaries
            my @Today = $TimeObject->SystemTime2Date(
                SystemTime => $SystemTime,
            );
            $SystemTimePast = $TimeObject->Date2SystemTime(
                Year   => $Today[5],
                Month  => $Today[4],
                Day    => $Today[3],
                Hour   => 0,
                Minute => 0,
                Second => 0,
            );
            $SystemTimeFuture = $SystemTimePast + 60 * 60 * 24 - 1;    # 23:59:59
        }

        if ( $DateRestriction eq 'DisableFutureDates' && $ValueSystemTime > $SystemTimeFuture ) {
            $ServerError  = 1;
            $ErrorMessage = "Invalid date (need a past date)!";
        }
        elsif ( $DateRestriction eq 'DisablePastDates' && $ValueSystemTime < $SystemTimePast ) {
            $ServerError  = 1;
            $ErrorMessage = "Invalid date (need a future date)!";
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

    my $Value = '';

    # convert date to localized string
    if ( defined $Param{Value} ) {
        $Value = $Param{LayoutObject}->{LanguageObject}->FormatTimeString(
            $Param{Value},
            'DateFormatShort',
        );

    }

    # in this Driver there is no need for HTMLOutput
    # Title is always equal to Value
    my $Title = $Value;

    # set field link form config
    my $Link = $Param{DynamicFieldConfig}->{Config}->{Link} || '';

    my $Data = {
        Value => $Value,
        Title => $Title,
        Link  => $Link,
    };

    return $Data;
}

sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    my $Value = defined $Param{Value} ? $Param{Value} : '';

    # only keep date part, loose time part of time-stamp
    $Value =~ s{ \A (\d{4} - \d{2} - \d{2}) .+?\z }{$1}xms;

    # Title is always equal to Value
    my $Title = $Value;

    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}

sub SearchFieldRender {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldName   = 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # set the default type
    $Param{Type} ||= 'TimeSlot';

    # add type to FieldName
    $FieldName .= $Param{Type};

    my $FieldLabel = $Param{DynamicFieldConfig}->{Label};

    my $Value;

    my %DefaultValue;

    if ( defined $Param{DefaultValue} ) {
        my @Items = split /;/, $Param{DefaultValue};

# format example of the key name for TimePoint:
#
# Search_DynamicField_DateTest1TimePointFormat=week;Search_DynamicField_DateTest1TimePointStart=Before;Search_DynamicField_DateTest1TimePointValue=7;

# format example of the key name for TimeSlot:
#
# Search_DynamicField_DateTest1TimeSlotStartYear=1974;Search_DynamicField_DateTest1TimeSlotStartMonth=01;Search_DynamicField_DateTest1TimeSlotStartDay=26;
# Search_DynamicField_DateTest1TimeSlotStartHour=00;Search_DynamicField_DateTest1TimeSlotStartMinute=00;Search_DynamicField_DateTest1TimeSlotStartSecond=00;
# Search_DynamicField_DateTest1TimeSlotStopYear=2013;Search_DynamicField_DateTest1TimeSlotStopMonth=01;Search_DynamicField_DateTest1TimeSlotStopDay=26;
# Search_DynamicField_DateTest1TimeSlotStopHour=23;Search_DynamicField_DateTest1TimeSlotStopMinute=59;Search_DynamicField_DateTest1TimeSlotStopSecond=59;

        my $KeyName = 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name} . $Param{Type};

        ITEM:
        for my $Item (@Items) {
            my ( $ItemKey, $ItemValue ) = split /=/, $Item;

            # only handle keys that match the current type
            next ITEM if $ItemKey !~ m{ $Param{Type} }xms;

            if ( $Param{Type} eq 'TimePoint' ) {

                if ( $ItemKey eq $KeyName . 'Format' ) {
                    $DefaultValue{Format}->{$ItemKey} = $ItemValue;
                }
                elsif ( $ItemKey eq $KeyName . 'Start' ) {
                    $DefaultValue{Start}->{$ItemKey} = $ItemValue;
                }
                elsif ( $ItemKey eq $KeyName . 'Value' ) {
                    $DefaultValue{Value}->{$ItemKey} = $ItemValue;
                }

                next ITEM;
            }
            if ( $ItemKey =~ m{Start} ) {
                $DefaultValue{ValueStart}->{$ItemKey} = $ItemValue;
            }
            elsif ( $ItemKey =~ m{Stop} ) {
                $DefaultValue{ValueStop}->{$ItemKey} = $ItemValue;
            }
        }
    }

    # set the field value
    if (%DefaultValue) {
        $Value = \%DefaultValue;
    }

    # get the field value, this function is always called after the profile is loaded
    my $FieldValues = $Self->SearchFieldValueGet(
        %Param,
    );

    if (
        defined $FieldValues
        && $Param{Type} eq 'TimeSlot'
        && defined $FieldValues->{ValueStart}
        && defined $FieldValues->{ValueStop}
    ) {
        $Value = $FieldValues;
    }
    elsif (
        defined $FieldValues
        && $Param{Type} eq 'TimePoint'
        && defined $FieldValues->{Format}
        && defined $FieldValues->{Start}
        && defined $FieldValues->{Value}
    ) {
        $Value = $FieldValues;
    }

    # check and set class if necessary
    my $FieldClass = 'DynamicFieldDateTime';

    # set as checked if necessary
    my $FieldChecked = ( defined $Value->{$FieldName} && $Value->{$FieldName} == 1 ? 'checked="checked"' : '' );

    my $HTMLString = <<"EOF";
    <input type="hidden" id="$FieldName" name="$FieldName" value="1"/>
EOF

    if ( $Param{ConfirmationCheckboxes} ) {
        $HTMLString = <<"EOF";
    <input type="checkbox" id="$FieldName" name="$FieldName" value="1" $FieldChecked/>
EOF
    }

    # build HTML for TimePoint
    if ( $Param{Type} eq 'TimePoint' ) {

        $HTMLString .= $Param{LayoutObject}->BuildSelection(
            Data => {
                'Before' => Translatable('more than ... ago'),
                'Last'   => Translatable('within the last ...'),
                'Next'   => Translatable('within the next ...'),
                'After'  => Translatable('in more than ...'),
            },
            Sort           => 'IndividualKey',
            SortIndividual => [ 'Before', 'Last', 'Next', 'After' ],
            Name           => $FieldName . 'Start',
            SelectedID => $Value->{Start}->{ $FieldName . 'Start' } || 'Last',
        );
        $HTMLString .= ' ' . $Param{LayoutObject}->BuildSelection(
            Data       => [ 1 .. 59 ],
            Name       => $FieldName . 'Value',
            SelectedID => $Value->{Value}->{ $FieldName . 'Value' } || 1,
        );
        $HTMLString .= ' ' . $Param{LayoutObject}->BuildSelection(
            Data => {
                minute => Translatable('minute(s)'),
                hour   => Translatable('hour(s)'),
                day    => Translatable('day(s)'),
                week   => Translatable('week(s)'),
                month  => Translatable('month(s)'),
                year   => Translatable('year(s)'),
            },
            Name       => $FieldName . 'Format',
            SelectedID => $Value->{Format}->{ $FieldName . 'Format' } || Translatable('day'),
        );

        my $AdditionalText;
        if ( $Param{UseLabelHints} ) {
            $AdditionalText = Translatable('before/after');
        }

        # call EditLabelRender on the common driver
        my $LabelString = $Self->EditLabelRender(
            %Param,
            FieldName      => $FieldName,
            AdditionalText => $AdditionalText,
        );

        my $Data = {
            Field => $HTMLString,
            Label => $LabelString,
        };

        return $Data;
    }

    # build HTML for start value set
    $HTMLString .= $Param{LayoutObject}->BuildDateSelection(
        %Param,
        Prefix               => $FieldName . 'Start',
        Format               => 'DateInputFormat',
        $FieldName . 'Class' => $FieldClass,
        DiffTime             => -( ( 60 * 60 * 24 ) * 30 ),
        Validate             => 1,
        %{ $Value->{ValueStart} },
    );

    # build HTML for "and" separator
    $HTMLString .= ' ' . $Param{LayoutObject}->{LanguageObject}->Translate("and") . "\n";

    # build HTML for stop value set
    $HTMLString .= $Param{LayoutObject}->BuildDateSelection(
        %Param,
        Prefix               => $FieldName . 'Stop',
        Format               => 'DateInputFormat',
        $FieldName . 'Class' => $FieldClass,
        DiffTime             => +( ( 60 * 60 * 24 ) * 30 ),
        Validate             => 1,
        %{ $Value->{ValueStop} },
    );

    my $AdditionalText;
    if ( $Param{UseLabelHints} ) {
        $AdditionalText = Translatable('between');
    }

    # call EditLabelRender on the common Driver
    my $LabelString = $Self->EditLabelRender(
        %Param,
        FieldName      => $FieldName,
        AdditionalText => $AdditionalText,
    );

    my $Data = {
        Field => $HTMLString,
        Label => $LabelString,
    };

    return $Data;
}

sub SearchFieldValueGet {
    my ( $Self, %Param ) = @_;

    # set the Prefix as the dynamic field name
    my $Prefix = 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # set the default type
    $Param{Type} ||= 'TimeSlot';

    # add type to prefix
    $Prefix .= $Param{Type};

    if ( $Param{Type} eq 'TimePoint' ) {

        # get dynamic field value
        my %DynamicFieldValues;
        for my $Type (qw(Start Value Format)) {

            # get dynamic field value form param object
            if ( defined $Param{ParamObject} ) {

                # return if value was not checked (useful in customer interface)
                return if !$Param{ParamObject}->GetParam( Param => $Prefix );

                $DynamicFieldValues{ $Prefix . $Type } = $Param{ParamObject}->GetParam(
                    Param => $Prefix . $Type,
                );
            }

            # otherwise get the value from the profile
            elsif ( defined $Param{Profile} ) {

                # return if value was not checked (useful in customer interface)
                return if !$Param{Profile}->{$Prefix};

                $DynamicFieldValues{ $Prefix . $Type } = $Param{Profile}->{ $Prefix . $Type };
            }
            else {
                return;
            }
        }

        # return if the field is empty (e.g. initial screen)
        return if !$DynamicFieldValues{ $Prefix . 'Start' }
            && !$DynamicFieldValues{ $Prefix . 'Value' }
            && !$DynamicFieldValues{ $Prefix . 'Format' };

        $DynamicFieldValues{$Prefix} = 1;

        # check if return value structure is needed
        if ( defined $Param{ReturnProfileStructure} && $Param{ReturnProfileStructure} eq '1' ) {
            return \%DynamicFieldValues;
        }

        return {
            Format => {
                $Prefix . 'Format' => $DynamicFieldValues{ $Prefix . 'Format' } || 'Last',
            },
            Start => {
                $Prefix . 'Start' => $DynamicFieldValues{ $Prefix . 'Start' } || 'day',
            },
            Value => {
                $Prefix . 'Value' => $DynamicFieldValues{ $Prefix . 'Value' } || 1,
            },
            $Prefix => 1,
        };
    }

    # get dynamic field value
    my %DynamicFieldValues;
    for my $Type (qw(Start Stop)) {
        for my $Part (qw(Year Month Day)) {

            # get dynamic field value from param object
            if ( defined $Param{ParamObject} ) {

                # return if value was not checked (useful in customer interface)
                return if !$Param{ParamObject}->GetParam( Param => $Prefix );

                $DynamicFieldValues{ $Prefix . $Type . $Part } = $Param{ParamObject}->GetParam(
                    Param => $Prefix . $Type . $Part,
                );
            }

            # otherwise get the value from the profile
            elsif ( defined $Param{Profile} ) {

                # return if value was not checked (useful in customer interface)
                return if !$Param{Profile}->{$Prefix};

                $DynamicFieldValues{ $Prefix . $Type . $Part } = $Param{Profile}->{ $Prefix . $Type . $Part };
            }
            else {
                return;
            }
        }
    }

    # return if the field is empty (e.g. initial screen)
    return if !$DynamicFieldValues{ $Prefix . 'StartYear' }
        && !$DynamicFieldValues{ $Prefix . 'StartMonth' }
        && !$DynamicFieldValues{ $Prefix . 'StartDay' }
        && !$DynamicFieldValues{ $Prefix . 'StopYear' }
        && !$DynamicFieldValues{ $Prefix . 'StopMonth' }
        && !$DynamicFieldValues{ $Prefix . 'StopDay' };

    $DynamicFieldValues{ $Prefix . 'StartHour' }   = '00';
    $DynamicFieldValues{ $Prefix . 'StartMinute' } = '00';
    $DynamicFieldValues{ $Prefix . 'StartSecond' } = '00';
    $DynamicFieldValues{ $Prefix . 'StopHour' }    = '23';
    $DynamicFieldValues{ $Prefix . 'StopMinute' }  = '59';
    $DynamicFieldValues{ $Prefix . 'StopSecond' }  = '59';

    $DynamicFieldValues{$Prefix} = 1;

    # check if return value structure is needed
    if ( defined $Param{ReturnProfileStructure} && $Param{ReturnProfileStructure} eq '1' ) {
        return \%DynamicFieldValues;
    }

    # add a leading zero for date parts that could be less than ten to generate a correct
    # time stamp
    for my $Type (qw(Start Stop)) {
        for my $Part (qw(Month Day Hour Minute Second)) {
            $DynamicFieldValues{ $Prefix . $Type . $Part } = sprintf "%02d",
                $DynamicFieldValues{ $Prefix . $Type . $Part };
        }
    }

    my $ValueStart = {
        $Prefix . 'StartYear'   => $DynamicFieldValues{ $Prefix . 'StartYear' }   || '0000',
        $Prefix . 'StartMonth'  => $DynamicFieldValues{ $Prefix . 'StartMonth' }  || '00',
        $Prefix . 'StartDay'    => $DynamicFieldValues{ $Prefix . 'StartDay' }    || '00',
        $Prefix . 'StartHour'   => $DynamicFieldValues{ $Prefix . 'StartHour' }   || '00',
        $Prefix . 'StartMinute' => $DynamicFieldValues{ $Prefix . 'StartMinute' } || '00',
        $Prefix . 'StartSecond' => $DynamicFieldValues{ $Prefix . 'StartSecond' } || '00',
    };

    my $ValueStop = {
        $Prefix . 'StopYear'   => $DynamicFieldValues{ $Prefix . 'StopYear' }   || '0000',
        $Prefix . 'StopMonth'  => $DynamicFieldValues{ $Prefix . 'StopMonth' }  || '00',
        $Prefix . 'StopDay'    => $DynamicFieldValues{ $Prefix . 'StopDay' }    || '00',
        $Prefix . 'StopHour'   => $DynamicFieldValues{ $Prefix . 'StopHour' }   || '00',
        $Prefix . 'StopMinute' => $DynamicFieldValues{ $Prefix . 'StopMinute' } || '00',
        $Prefix . 'StopSecond' => $DynamicFieldValues{ $Prefix . 'StopSecond' } || '00',
    };

    return {
        $Prefix    => 1,
        ValueStart => $ValueStart,
        ValueStop  => $ValueStop,
    };
}

sub SearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    # set the default type
    $Param{Type} ||= 'TimeSlot';

    # get field value
    my $Value = $Self->SearchFieldValueGet(%Param);

    my $DisplayValue;

    if ( defined $Value && !$Value ) {
        $DisplayValue = '';
    }

    # do not search if value was not checked (useful for customer interface)
    if ( !$Value ) {
        return {
            Parameter => {
                Equals => $Value,
            },
            Display => $DisplayValue,
        };
    }

    # search for a wild card in the value
    if ( $Value && IsHashRefWithData($Value) ) {

        my $Prefix = 'Search_DynamicField_' . $Param{DynamicFieldConfig}->{Name};
        $Prefix .= $Param{Type};

        if (
            $Param{Type} eq 'TimePoint'
            && $Value->{Start}->{ $Prefix . 'Start' }
            && $Value->{Format}->{ $Prefix . 'Format' }
            && $Value->{Value}->{ $Prefix . 'Value' }
            && $Value->{$Prefix}
        ) {

            # to store the search parameters
            my %Parameter;

            # store in local variables for easier handling
            my $Format    = $Value->{Format}->{ $Prefix . 'Format' };
            my $Start     = $Value->{Start}->{ $Prefix . 'Start' };
            my $DiffValue = $Value->{Value}->{ $Prefix . 'Value' };

            my $DiffTimeMinutes = 0;
            if ( $Format eq 'minute' ) {
                $DiffTimeMinutes = $DiffValue;
            }
            elsif ( $Format eq 'hour' ) {
                $DiffTimeMinutes = $DiffValue * 60;
            }
            elsif ( $Format eq 'day' ) {
                $DiffTimeMinutes = $DiffValue * 60 * 24;
            }
            elsif ( $Format eq 'week' ) {
                $DiffTimeMinutes = $DiffValue * 60 * 24 * 7;
            }
            elsif ( $Format eq 'month' ) {
                $DiffTimeMinutes = $DiffValue * 60 * 24 * 30;
            }
            elsif ( $Format eq 'year' ) {
                $DiffTimeMinutes = $DiffValue * 60 * 24 * 365;
            }

            # get time object
            my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

            # get the current time in epoch seconds
            my $Now = $TimeObject->SystemTime();

            # calculate difference time seconds
            my $DiffTimeSeconds = $DiffTimeMinutes * 60;

            $DisplayValue = '';

            # define to search before or after that time stamp
            if ( $Start eq 'Before' ) {

                # we must subtract the difference because it is in the past
                my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
                    SystemTime => $Now - $DiffTimeSeconds,
                );

                # use the last hour from difference time as it will be the upper limit strict
                my $SystemTime = $TimeObject->Date2SystemTime(
                    Year   => $Year,
                    Month  => $Month,
                    Day    => $Day,
                    Hour   => 00,
                    Minute => 00,
                    Second => 00,
                );

                my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
                    SystemTime => $SystemTime,
                );

                # only search dates in the past (before the time stamp)
                $Parameter{SmallerThan} = $TimeStamp;

                # set the display value
                $DisplayValue = '< ' . $Year . '-' . $Month . '-' . $Day;
            }
            elsif ( $Start eq 'Last' ) {

                my ( $NSec, $NMin, $NHour, $NDay, $NMonth, $NYear, $NWeekDay ) = $TimeObject->SystemTime2Date(
                    SystemTime => $Now,
                );

                # use the last hour from today as it will be the upper limit relative
                my $NowSystemTime = $TimeObject->Date2SystemTime(
                    Year   => $NYear,
                    Month  => $NMonth,
                    Day    => $NDay,
                    Hour   => 23,
                    Minute => 59,
                    Second => 59,
                );

                my $NowTimeStamp = $TimeObject->SystemTime2TimeStamp(
                    SystemTime => $NowSystemTime,
                );

                # we must subtract the difference because it is in the past
                my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
                    SystemTime => $Now - $DiffTimeSeconds,
                );

                # use the first hour from difference time as it will be the lower limit relative
                my $SystemTime = $TimeObject->Date2SystemTime(
                    Year   => $Year,
                    Month  => $Month,
                    Day    => $Day,
                    Hour   => 00,
                    Minute => 00,
                    Second => 00,
                );

                my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
                    SystemTime => $SystemTime,
                );

                # search dates in the past (after the time stamp and up to now)
                $Parameter{GreaterThanEquals} = $TimeStamp;
                $Parameter{SmallerThanEquals} = $NowTimeStamp;

                # set the display value
                $DisplayValue = $Year . '-' . $Month . '-' . $Day
                    . ' - '
                    . $NYear . '-' . $NMonth . '-' . $NDay;
            }
            elsif ( $Start eq 'Next' ) {

                my ( $NSec, $NMin, $NHour, $NDay, $NMonth, $NYear, $NWeekDay ) = $TimeObject->SystemTime2Date(
                    SystemTime => $Now,
                );

                # use the first hour from today as it will be the lower limit relative
                my $NowSystemTime = $TimeObject->Date2SystemTime(
                    Year   => $NYear,
                    Month  => $NMonth,
                    Day    => $NDay,
                    Hour   => 00,
                    Minute => 00,
                    Second => 00,
                );

                my $NowTimeStamp = $TimeObject->SystemTime2TimeStamp(
                    SystemTime => $NowSystemTime,
                );

                # we must add the difference because it is in the future
                my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
                    SystemTime => $Now + $DiffTimeSeconds,
                );

                # use the last hour from difference time as it will be the upper limit relative
                my $SystemTime = $TimeObject->Date2SystemTime(
                    Year   => $Year,
                    Month  => $Month,
                    Day    => $Day,
                    Hour   => 23,
                    Minute => 59,
                    Second => 59,
                );

                my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
                    SystemTime => $SystemTime,
                );

                # search dates in the future (after now and up to the time stamp)
                $Parameter{GreaterThanEquals} = $NowTimeStamp;
                $Parameter{SmallerThanEquals} = $TimeStamp;

                # set the display value
                $DisplayValue = $NYear . '-' . $NMonth . '-' . $NDay
                    . ' - '
                    . $Year . '-' . $Month . '-' . $Day;
            }
            elsif ( $Start eq 'After' ) {

                # we must add the difference because it is in the future
                my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
                    SystemTime => $Now + $DiffTimeSeconds,
                );

                # use the last hour from difference time as it will be the lower limit strict
                my $SystemTime = $TimeObject->Date2SystemTime(
                    Year   => $Year,
                    Month  => $Month,
                    Day    => $Day,
                    Hour   => 23,
                    Minute => 59,
                    Second => 59,
                );

                my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
                    SystemTime => $SystemTime,
                );

                # only search dates in the future (after the time stamp)
                $Parameter{GreaterThan} = $TimeStamp;

                # set the display value
                $DisplayValue = '> ' . $Year . '-' . $Month . '-' . $Day;
            }

            # return search parameter structure
            return {
                Parameter => \%Parameter,
                Display   => $DisplayValue,
            };
        }

        my $ValueStart = $Value->{ValueStart}->{ $Prefix . 'StartYear' } . '-'
            . $Value->{ValueStart}->{ $Prefix . 'StartMonth' } . '-'
            . $Value->{ValueStart}->{ $Prefix . 'StartDay' } . ' '
            . $Value->{ValueStart}->{ $Prefix . 'StartHour' } . ':'
            . $Value->{ValueStart}->{ $Prefix . 'StartMinute' } . ':'
            . $Value->{ValueStart}->{ $Prefix . 'StartSecond' };

        my $ValueStop = $Value->{ValueStop}->{ $Prefix . 'StopYear' } . '-'
            . $Value->{ValueStop}->{ $Prefix . 'StopMonth' } . '-'
            . $Value->{ValueStop}->{ $Prefix . 'StopDay' } . ' '
            . $Value->{ValueStop}->{ $Prefix . 'StopHour' } . ':'
            . $Value->{ValueStop}->{ $Prefix . 'StopMinute' } . ':'
            . $Value->{ValueStop}->{ $Prefix . 'StopSecond' };

        my $DisplayValueStart = $Value->{ValueStart}->{ $Prefix . 'StartYear' } . '-'
            . $Value->{ValueStart}->{ $Prefix . 'StartMonth' } . '-'
            . $Value->{ValueStart}->{ $Prefix . 'StartDay' };

        my $DisplayValueStop = $Value->{ValueStop}->{ $Prefix . 'StopYear' } . '-'
            . $Value->{ValueStop}->{ $Prefix . 'StopMonth' } . '-'
            . $Value->{ValueStop}->{ $Prefix . 'StopDay' };

        # return search parameter structure
        return {
            Parameter => {
                GreaterThanEquals => $ValueStart,
                SmallerThanEquals => $ValueStop,
            },
            Display => $DisplayValueStart . ' - ' . $DisplayValueStop,
        };
    }

    return;
}

sub StatsFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    return {
        Name             => $Param{DynamicFieldConfig}->{Label},
        Element          => 'DynamicField_' . $Param{DynamicFieldConfig}->{Name},
        TimePeriodFormat => 'DateInputFormat',
        Block            => 'Time',
    };
}

sub StatsSearchFieldParameterBuild {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    # set operator
    my $Operator = $Param{Operator};
    return {} if !$Operator;

    return { $Operator => undef } if !$Value;

    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # Date field is limited to full calendar days
    # prepare restriction getting date/time fields
    my $SystemTime = $TimeObject->TimeStamp2SystemTime(
        String => $Value,
    );
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
        SystemTime => $SystemTime,
    );

    # set end of day
    if ( $Operator eq 'SmallerThanEquals' ) {
        $Hour = 23;
        $Min  = 59;
        $Sec  = 59;
    }

    # set start of day
    elsif ( $Operator eq 'GreaterThanEquals' ) {
        $Hour = 0;
        $Min  = 0;
        $Sec  = 0;
    }

    # get target time using new values (or same values for unknown operators)
    my $TargetSystemTime = $TimeObject->Date2SystemTime(
        Year   => $Year,
        Month  => $Month,
        Day    => $Day,
        Hour   => $Hour,
        Minute => $Min,
        Second => $Sec,
    );
    $Value = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $TargetSystemTime,
    );

    return {
        $Operator => $Value,
    };
}

sub RandomValueSet {
    my ( $Self, %Param ) = @_;

    # get random value
    my $Year  = int( rand(40) ) + 2000;
    my $Month = sprintf( "%02d", int( rand(12) ) + 1 );
    my $Day   = sprintf( "%02d", int( rand(28) ) + 1 );
    my $Value = $Year . '-' . $Month . '-' . $Day . ' 00:00:00';

    my $Success = $Self->ValueSet(
        %Param,
        Value => $Value,
    );

    if ( !$Success ) {
        return {
            Success => 0,
        };
    }
    return {
        Success => 1,
        Value   => $Value,
    };
}

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    my $Value = defined $Param{Key} ? $Param{Key} : '';

    # check if a translation is possible
    if ( defined $Param{LanguageObject} ) {

        # translate value
        $Value = $Param{LanguageObject}->FormatTimeString(
            $Value,
            'DateFormatShort',
        );
    }

    return $Value;
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
