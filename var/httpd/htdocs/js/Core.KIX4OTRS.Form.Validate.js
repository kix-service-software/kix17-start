// --
// Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};
Core.KIX4OTRS.Form = Core.KIX4OTRS.Form || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.Form.Validate
 * @description This namespace contains addittional validation functions.
 * @requires Core.UI.Accessibility
 */
Core.KIX4OTRS.Form.Validate = (function(TargetNS) {
    function DateValidator(Prefix, DateInFuture) {
        var DateObject,
            DateCheck,
            YearValue   = $('#' + Prefix + 'Year').val(),
            MonthValue  = $('#' + Prefix + 'Month').val(),
            DayValue    = $('#' + Prefix + 'Day').val(),
            HourValue   = $('#' + Prefix + 'Hour').val(),
            MinuteValue = $('#' + Prefix + 'Minute').val(),
            $UsedObject = $('#' + Prefix + 'Used');

        // Skip validation if field is not used
        if ($UsedObject.length > 0 && $UsedObject.is(':checked') === false) {
            return true;
        }

        if (YearValue && MonthValue && DayValue) {
            DateObject = new Date(YearValue, MonthValue - 1, DayValue);
            if (DateObject.getFullYear() === parseInt(YearValue, 10) && DateObject.getMonth() + 1 === parseInt(MonthValue, 10) && DateObject.getDate() === parseInt(DayValue, 10)) {
                if (DateInFuture) {
                    DateCheck = new Date();

                    if ( MinuteValue !== undefined
                        && HourValue !== undefined
                        && MinuteValue.length
                        && HourValue.length
                    ) {
                        DateObject.setHours(HourValue, MinuteValue, 0, 0);
                    }
                    else {
                        DateCheck.setHours(0, 0, 0, 0);
                    }
                    if (DateObject >= DateCheck) {
                        return true;
                    }
                } else {
                    return true;
                }
            }
        }
        return false;
    }

    $.validator.addMethod('Validate_DateFull', function(Value, Element) {
        var Prefix = $(Element).attr('id').replace(/Date$/, '');
        return DateValidator(Prefix, false);
    }, '');
    $.validator.addMethod('Validate_DateFullInFuture', function(Value, Element) {
        var Prefix = $(Element).attr('id').replace(/Date$/, '');
        return DateValidator(Prefix, true);
    }, '');

    $.validator.addMethod('Validate_DateTime', function(Value, Element) {
        var times = Value.split(':'), Hour = parseInt(times[0], 10), Minute = parseInt(times[1], 10);

        return (Hour >= 0 && Hour < 24 && Minute >= 0 && Minute < 60);
    }, '');

    $.validator.addClassRules('Validate_DateFull', {
        Validate_DateFull : true
    });

    $.validator.addClassRules('Validate_DateFullInFuture', {
        Validate_DateFullInFuture : true
    });

    $.validator.addClassRules('Validate_DateTime', {
        Validate_DateTime : true
    });

    $.validator.addMethod('Validate_MaxLength', function(Value, Element) {
        var Classes = $(Element).attr('class'), Length = 0, LengthClassPrefix = 'Validate_Length_', RegExLength = new RegExp(LengthClassPrefix);

        $.each(Classes.split(' '), function(Index, Class) {
            if (RegExLength.test(Class)) {
                Length = Class.replace(LengthClassPrefix, '');
            } else if ($(Element).data("maxlength") !== undefined && $(Element).data("maxlength") != '' && $(Element).data("maxlength") > 0) {
                Length = $(Element).data("maxlength");
            }
        });

        return (Value.length <= Length);
    }, '');

    $.validator.addMethod('Validate_MinLength', function(Value, Element) {
        var Classes = $(Element).attr('class'), Length = 0, LengthClassPrefix = 'Validate_Length_', RegExLength = new RegExp(LengthClassPrefix);

        $.each(Classes.split(' '), function(Index, Class) {
            if (RegExLength.test(Class)) {
                Length = Class.replace(LengthClassPrefix, '');
            }
        });

        return (Value.length > Length);
    }, '');

    $.validator.addClassRules('Validate_MaxLength', {
        Validate_MaxLength : true
    });

    $.validator.addClassRules('Validate_MinLength', {
        Validate_MinLength : true
    });

    $.validator.addClassRules('Validate_Length', {
        Validate_MinLength : true,
        Validate_MaxLength : true
    });

    return TargetNS;
}(Core.KIX4OTRS.Form.Validate || {}));
