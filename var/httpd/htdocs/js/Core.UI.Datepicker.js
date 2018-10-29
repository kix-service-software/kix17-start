// --
// Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.UI = Core.UI || {};

/**
 * @namespace Core.UI.Datepicker
 * @memberof Core.UI
 * @author OTRS AG
 * @description
 *      This namespace contains the datepicker functions.
 */
Core.UI.Datepicker = (function (TargetNS) {
    /**
     * @private
     * @name VacationDays
     * @memberof Core.UI.Datepicker
     * @member {Object}
     * @description
     *      Vacation days, defined in SysConfig.
     */
    var VacationDays,

    /**
     * @private
     * @name VacationDaysOneTime
     * @memberof Core.UI.Datepicker
     * @member {Object}
     * @description
     *      One time vacations, defined in SysConfig.
     */
        VacationDaysOneTime,

    /**
     * @private
     * @name LocalizationData
     * @memberof Core.UI.Datepicker
     * @member {Object}
     * @description
     *      Translations.
     */
        LocalizationData,

    /**
     * @private
     * @name DatepickerCount
     * @memberof Core.UI.Datepicker
     * @member {Number}
     * @description
     *      Number of initialized datepicker.
     */
        DatepickerCount = 0;

    if (!Core.Debug.CheckDependency('Core.UI.Datepicker', '$([]).datepicker', 'jQuery UI datepicker')) {
        return false;
    }

    /**
     * @private
     * @name CheckDate
     * @memberof Core.UI.Datepicker
     * @function
     * @returns {Array} First element is always true, second element contains the name of a CSS class, third element a description for the date.
     * @param {DateObject} DateObject - A JS date object to check.
     * @description
     *      Check if date is on of the defined vacation days.
     */
    function CheckDate(DateObject) {
        var DayDescription = '',
            DayClass = '';

        // Get defined days from Config, if not done already
        if (typeof VacationDays === 'undefined') {
            VacationDays = Core.Config.Get('Datepicker.VacationDays').TimeVacationDays;
        }
        if (typeof VacationDaysOneTime === 'undefined') {
            VacationDaysOneTime = Core.Config.Get('Datepicker.VacationDays').TimeVacationDaysOneTime;
        }

        // Check if date is one of the vacation days
        if (typeof VacationDays[DateObject.getMonth() + 1] !== 'undefined' &&
            typeof VacationDays[DateObject.getMonth() + 1][DateObject.getDate()] !== 'undefined') {
            DayDescription += VacationDays[DateObject.getMonth() + 1][DateObject.getDate()];
            DayClass = 'Highlight ';
        }

        // Check if date is one of the one time vacation days
        if (typeof VacationDaysOneTime[DateObject.getFullYear()] !== 'undefined' &&
            typeof VacationDaysOneTime[DateObject.getFullYear()][DateObject.getMonth() + 1] !== 'undefined' &&
            typeof VacationDaysOneTime[DateObject.getFullYear()][DateObject.getMonth() + 1][DateObject.getDate()] !== 'undefined') {
            DayDescription += VacationDaysOneTime[DateObject.getFullYear()][DateObject.getMonth() + 1][DateObject.getDate()];
            DayClass = 'Highlight ';
        }

        if (DayClass.length) {
            return [true, DayClass, DayDescription];
        }
        else {
            return [true, ''];
        }
    }

    /**
     * @name Init
     * @memberof Core.UI.Datepicker
     * @function
     * @returns {Boolean} false, if Parameter Element is not of the correct type.
     * @param {jQueryObject|Object} Element - The jQuery object of a text input field which should get a datepicker.
     *                                        Or a hash with the Keys 'Year', 'Month' and 'Day' and as values the jQueryObjects of the select drop downs.
     * @description
     *      This function initializes the datepicker on the defined elements.
     */
    TargetNS.Init = function (Element) {

        var $DatepickerElement,
            HasDateSelectBoxes = false,
            Options,
            ErrorMessage;

        if (typeof Element.VacationDays === 'object') {
            Core.Config.Set('Datepicker.VacationDays', Element.VacationDays);
        }

        /**
         * @private
         * @name LeadingZero
         * @memberof Core.UI.Datepicker.Init
         * @function
         * @returns {String} A number with leading zero, if needed.
         * @param {Number} Number - A number to convert.
         * @description
         *      Converts a one digit number to a string with leading zero.
         */
        function LeadingZero(Number) {
            if (Number.toString().length === 1) {
                return '0' + Number;
            }
            else {
                return Number;
            }
        }

        if (typeof LocalizationData === 'undefined') {
            LocalizationData = Core.Config.Get('Datepicker.Localization');
            if (typeof LocalizationData === 'undefined') {
                // KIX4OTRS-capeIT
                // throw new Core.Exception.ApplicationError('Datepicker localization data could not be found!', 'InternalError');
                return;
                // EO KIX4OTRS-capeIT
            }
        }

        // Increment number of initialized datepickers on this site
        DatepickerCount++;

        // Check, if datepicker is used with three input element or with three select boxes
        if (typeof Element === 'object' &&
            typeof Element.Day !== 'undefined' &&
            typeof Element.Month !== 'undefined' &&
            typeof Element.Year !== 'undefined' &&
            isJQueryObject(Element.Day, Element.Month, Element.Year) &&
            // Sometimes it can happen that BuildDateSelection was called without placing the full date selection.
            //  Ignore in this case.
            Element.Day.length
        ) {

            $DatepickerElement = $('<input>').attr('type', 'hidden').attr('id', 'Datepicker' + DatepickerCount);
            Element.Year.after($DatepickerElement);

            if (Element.Day.is('select') && Element.Month.is('select') && Element.Year.is('select')) {
                HasDateSelectBoxes = true;
            }
        }
        else {
            return false;
        }

        // Define options hash
        Options = {
            beforeShowDay: function (DateObject) {
                return CheckDate(DateObject);
            },
            showOn: 'focus',
            prevText: LocalizationData.PrevText,
            nextText: LocalizationData.NextText,
            firstDay: Element.WeekDayStart,
            showMonthAfterYear: 0,
            monthNames: LocalizationData.MonthNames,
            monthNamesShort: LocalizationData.MonthNamesShort,
            dayNames: LocalizationData.DayNames,
            dayNamesShort: LocalizationData.DayNamesShort,
            dayNamesMin: LocalizationData.DayNamesMin,
            isRTL: LocalizationData.IsRTL
        };

        Options.onSelect = function (DateText, Instance) {
            var Year = Instance.selectedYear,
                Month = Instance.selectedMonth + 1,
                Day = Instance.selectedDay;

            // Update the three select boxes
            if (HasDateSelectBoxes) {
                Element.Year.find('option[value=' + Year + ']').prop('selected', true);
                Element.Month.find('option[value=' + Month + ']').prop('selected', true);
                Element.Day.find('option[value=' + Day + ']').prop('selected', true);
                // KIX4OTRS-capeIT
                if (Element.Date && Element.Date.length) {
                    Element.Date.val(DateText);
                }
                // EO KIX4OTRS-capeIT
            }
            else {
                Element.Year.val(Year);
                Element.Month.val(LeadingZero(Month));
                Element.Day.val(LeadingZero(Day));

                // KIX4OTRS-capeIT
                if (Element.Date && Element.Date.length) {
                    Element.Date.val(DateText).trigger('change');
                }
                // EO KIX4OTRS-capeIT
            }
        };
        // KIX4OTRS-capeIT
        // Options.beforeShow = function (Input) {
        Options.beforeShow = function (Input, Instance) {
        // EO KIX4OTRS-capeIT
            $(Input).val('');
            return {
                defaultDate: new Date(Element.Year.val(), Element.Month.val() - 1, Element.Day.val())
            };
        };

// KIX-capeIT
        $('#ui-datepicker-div').remove();
// EO KIX-capeIT

        $DatepickerElement.datepicker(Options);

        // Add some DOM notes to the datepicker, but only if it was not initialized previously.
        //      Check if one additional DOM node is already present.
        if (!$('#' + Core.App.EscapeSelector(Element.Day.attr('id')) + 'DatepickerIcon').length) {

            // add datepicker icon and click event
            $DatepickerElement.after('<a href="#" class="DatepickerIcon" id="' + Element.Day.attr('id') + 'DatepickerIcon" title="' + LocalizationData.IconText + '"><i class="fa fa-calendar"></i></a>');

            if (Element.DateInFuture) {
                ErrorMessage = Core.Config.Get('Datepicker.ErrorMessageDateInFuture');

                // KIX4OTRS-capeIT
                $DatepickerElement.datepicker('option', 'minDate', '-0d');
                // EO KIX4OTRS-capeIT
            }
            else if (Element.DateNotInFuture) {
                ErrorMessage = Core.Config.Get('Datepicker.ErrorMessageDateNotInFuture');
            }
            else {
                ErrorMessage = Core.Config.Get('Datepicker.ErrorMessage');
            }

            // Add validation error messages for all dateselection elements
            Element.Year
            .after('<div id="' + Element.Day.attr('id') + 'Error" class="TooltipErrorMessage"><p>' + ErrorMessage + '</p></div>')
            .after('<div id="' + Element.Month.attr('id') + 'Error" class="TooltipErrorMessage"><p>' + ErrorMessage + '</p></div>')
            .after('<div id="' + Element.Year.attr('id') + 'Error" class="TooltipErrorMessage"><p>' + ErrorMessage + '</p></div>');

            // only insert time element error messages if time elements are present
            if (Element.Hour && Element.Hour.length) {
                Element.Hour
                .after('<div id="' + Element.Hour.attr('id') + 'Error" class="TooltipErrorMessage"><p>' + ErrorMessage + '</p></div>')
                .after('<div id="' + Element.Minute.attr('id') + 'Error" class="TooltipErrorMessage"><p>' + ErrorMessage + '</p></div>');
            }
        }

        // KIX4OTRS-capeIT
        if (Element.Date && Element.Date.length) {
            $DatepickerElement.datepicker('option', 'dateFormat', Element.Format);

            // we need some special handling, if the element ID contains :: (CI edit)
            if (Element.Date.attr('id').indexOf('::') > -1) {
                Element.Date.nextAll('a.DatepickerIcon').unbind('click.Datepicker').bind('click.Datepicker', function () {
                    $DatepickerElement.trigger('focus');
                    return false;
                });
            }

            Element.Date
                  .click( function () {
                      $DatepickerElement.trigger('focus');
                      return false;
                  })
                  .change( function () {
                      var date = $(this).val(),
                          YearPos  = Element.Format.search('yy'),
                          MonthPos = Element.Format.search('mm'),
                          DayPos   = Element.Format.search('dd');

                      // some special handling because of 2-digit year format and 4-digit year input
                      if (YearPos < MonthPos)
                          MonthPos += 2;

                      if (YearPos < DayPos)
                          DayPos += 2;

                      Element.Year.val( date.substr( YearPos, 4 ) );
                      Element.Month.val( date.substr( MonthPos, 2 ) );
                      Element.Day.val( date.substr( DayPos, 2 ) );

                      // special handling for CustomerTicketSearch (only OTRS 3.2)
                      if (Core.Config.Get('Action') === 'CustomerTicketSearch') {
                          // remove leading zero from Day and Month
                          if (Element.Day.val().indexOf("0") == 0)
                              Element.Day.val(Element.Day.val().substring(1));
                          if (Element.Month.val().indexOf("0") == 0)
                              Element.Month.val(Element.Month.val().substring(1));
                      }
                      return false;
                  });
        }

        if (Element.Time && Element.Time.length) {
            Element.Time
            .change( function () {
                var times = $(this).val().split(':');
                Element.Hour.val(times[0]);
                Element.Minute.val(times[1]);
                return false;
            });
        }
        // EO KIX4OTRS-capeIT

        $('#' + Core.App.EscapeSelector(Element.Day.attr('id')) + 'DatepickerIcon').unbind('click.Datepicker').bind('click.Datepicker', function () {
            $DatepickerElement.datepicker('show');
            return false;
        });

        // KIX4OTRS-capeIT
        // special handling for AgentStatistics
        if (Core.Config.Get('Action') === 'AgentStatistics') {
            $('#EditDialog #' + Core.App.EscapeSelector(Element.Day.attr('id')) + 'DatepickerIcon').unbind('click.Datepicker').bind('click.Datepicker', function () {
                $DatepickerElement.datepicker('show');
                $('#ui-datepicker-div').prop('style', $('#ui-datepicker-div').attr('style') + '; z-index: 5000 !important');
                return false;
            });
        }
        // EO KIX4OTRS-capeIT

        // do not show the datepicker container div.
        // KIX4OTRS-capeIT
        // in case of multiple datepicker containers created
        // $('#ui-datepicker-div').hide();
        $('.ui-datepicker').hide();
        // EO KIX4OTRS-capeIT
    };

    return TargetNS;
}(Core.UI.Datepicker || {}));
