// --
// Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.UI = Core.UI || {};

/**
 * @namespace
 * @exports TargetNS as Core.UI.GeoCoordinate
 * @description
 *      This namespace contains the special module functions for the Zoom.
 */
Core.UI.GeoCoordinate = (function (TargetNS) {

    function inputFilter (pattern, obj) {
        if (pattern.test(obj.value)) {
            obj.oldValue          = obj.value;
            obj.oldSelectionStart = obj.selectionStart;
            obj.oldSelectionEnd   = obj.selectionEnd;
            return true;
        } else if (obj.hasOwnProperty("oldValue")) {
            obj.value = obj.oldValue;
            obj.setSelectionRange(obj.oldSelectionStart, obj.oldSelectionEnd);
            return false;
        }
    }

    function addLeadingZeros (str, max) {
        str = str.toString();
        return str.length < max ? addLeadingZeros("0" + str, max) : str;
    }

    function addTrailingZeros (str, max) {
        str = str.toString();
        return str.length < max ? addTrailingZeros(str + "0", max) : str;
    }

    TargetNS.CoordinateInputInit = function() {

        $('input[data-id="CoordDegree"]').off('focus').on('focus', function() {
            $(this).select();
        });
        $('input[data-id="CoordDegree"]').off('input').on("input", function(event) {
            var maxLength = $(this).attr('maxlength'),
                nextField = $(this).attr('data-followup');

            if ( event.keyCode == 9 ) {
                event.preventDefault();
                return false;
            }

            if ( inputFilter(/^[-+]?\d*$/, this) ) {
                if (
                    maxLength == $(this).val().length
                    && nextField !== undefined
                ) {
                    $('[name="' + nextField + '"]').focus();
                }
            }
        });
        $('input[data-id="CoordDegree"]').off('blur').on('blur', function() {
            var pattern   = /^(\+|-|)(\d+)$/g,
                maxLength = $(this).attr('maxlength'),
                operator, digit, result;

            result = pattern.exec($(this).val());

            if ( result === null ) {
                operator = '+';
                digit    = addLeadingZeros('0', maxLength-1);
                $(this).val(operator + digit);
            }
            else if (result[1] !== '' ) {
                operator = result[1];
                digit    = addLeadingZeros(result[2], maxLength-1);
                $(this).val(operator + digit);
            } else {
                operator = '+';
                if ( result[2].length == maxLength ) {
                    digit = result[2].replace(/\d$/, '');
                } else {
                    digit = addLeadingZeros(result[2], maxLength-1);
                }

                $(this).val(operator + digit);
            }
        });

        $.each( $('input[data-id^="Coord"]'), function() {
            if ( /Coord(?!Degree)/g.exec($(this).attr('data-id')) ) {
                $(this).off('focus').on('focus', function() {
                    $(this).select();
                });
                $(this).off('input').on("input", function(event) {
                    var maxLength = $(this).attr('maxlength'),
                    nextField = $(this).attr('data-followup');

                    if ( event.keyCode == 9 ) {
                        event.preventDefault();
                        return false;
                    }

                    if ( inputFilter(/^\d*$/, this) ) {
                        if (
                            maxLength == $(this).val().length
                            && nextField !== undefined
                        ) {
                            $('[name="' + nextField + '"]').focus();
                        }
                    }
                });
                $(this).off('blur').on('blur', function() {
                    var maxLength = $(this).attr('maxlength');

                    if (
                        $(this).val() === null
                        || $(this).val() === ''
                        || $(this).val() === undefined
                    ) {
                        if ( /CoordDecimal/g.exec($(this).attr('data-id')) ) {
                            $(this).val(addTrailingZeros('0', maxLength));
                        }
                        else {
                            $(this).val(addLeadingZeros('0', maxLength));
                        }
                    } else {
                        if ( /CoordDecimal/g.exec($(this).attr('data-id')) ) {
                            $(this).val(addTrailingZeros($(this).val(), maxLength));
                        }
                        else {
                            $(this).val(addLeadingZeros($(this).val(), maxLength));
                        }
                    }
                });
            }
        });
    }

    return TargetNS;
}(Core.UI.GeoCoordinate || {}));