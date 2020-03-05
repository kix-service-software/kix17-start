// --
// Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.CustomerCompanySearch
 * @description
 *      This namespace contains the special module functions for the customer company search.
 */
Core.Agent.CustomerCompanySearch = (function (TargetNS) {

    function htmlDecode(Text){
        return Text.replace(/&amp;/g, '&');
    }

    /**
     * @function
     * @param {jQueryObject} $Element The jQuery object of the input field with autocomplete
     * @param {Boolean} ActiveAutoComplete Set to false, if autocomplete should only be started by click on a button next to the input field
     * @return nothing
     *      This function initializes the special module functions
     */
    TargetNS.Init = function ($Element, ActiveAutoComplete) {
        if (typeof ActiveAutoComplete === 'undefined') {
            ActiveAutoComplete = true;
        }
        else {
            ActiveAutoComplete = !!ActiveAutoComplete;
        }

        if (isJQueryObject($Element)) {
            $Element.autocomplete({
                minLength: ActiveAutoComplete ? Core.Config.Get('Autocomplete.MinQueryLength') : 500,
                delay: Core.Config.Get('Autocomplete.QueryDelay'),
                source: function (Request, Response) {
                    var URL = Core.Config.Get('Baselink'), Data = {
                        Action: 'AgentCustomerCompanySearch',
                        Term: Request.term,
                        MaxResults: Core.Config.Get('Autocomplete.MaxResultsDisplayed')
                    };
                    Core.AJAX.FunctionCall(URL, Data, function (Result) {
                        var Data = [];
                        $.each(Result, function () {
                            Data.push({
                                label: this.CustomerCompanyValue + " (" + this.CustomerCompanyKey + ")",
                                value: this.CustomerCompanyValue
                            });
                        });
                        Response(Data);
                    });
                },
                select: function (Event, UI) {
                    var CustomerCompanyKey = UI.item.label.replace(/.*\((.*)\)$/, '$1');

                    $Element.val(UI.item.value);

                    // set hidden field SelectedCustomerCompany
                    // escape possible colons (:) in element id because jQuery can not handle it in id attribute selectors
                    $('#' + Core.App.EscapeSelector($Element.attr('id')) + 'Selected').val(CustomerCompanyKey);

                    Event.preventDefault();
                    return false;
                }
            });

            if (!ActiveAutoComplete) {
                $Element.after('<button id="' + $Element.attr('id') + 'Search" type="button">' + Core.Config.Get('Autocomplete.SearchButtonText') + '</button>');
                // escape possible colons (:) in element id because jQuery can not handle it in id attribute selectors
                $('#' + Core.App.EscapeSelector($Element.attr('id')) + 'Search').click(function () {
                    $Element.autocomplete("option", "minLength", 0);
                    $Element.autocomplete("search");
                    $Element.autocomplete("option", "minLength", 500);
                });
            }
        }

        // On unload remove old selected data. If the page is reloaded (with F5) this data stays in the field and invokes an ajax request otherwise
        $(window).bind('unload', function () {
            // escape possible colons (:) in element id because jQuery can not handle it in id attribute selectors
           $('#' + Core.App.EscapeSelector($Element.attr('id')) + 'Selected').val('');
        });
    };

    /**
     * @private
     * @name Init
     * @memberof Core.Agent.CustomerCompanySearch
     * @function
     * @param {jQueryObject} $Element - The jQuery object of the input field with autocomplete.
     * @description
     *      Initializes the module.
     */
    TargetNS.AdminInit = function ($Element) {
        if (isJQueryObject($Element)) {
            Core.UI.Autocomplete.Init($Element, function (Request, Response) {
                var URL = Core.Config.Get('Baselink'),
                    Data = {
                        Action: 'AgentCustomerCompanySearch',
                        Term: Request.term,
                        MaxResults: Core.UI.Autocomplete.GetConfig('MaxResultsDisplayed')
                    };

                $Element.data('AutoCompleteXHR', Core.AJAX.FunctionCall(URL, Data, function (Result) {
                    var ValueData = [];
                    $Element.removeData('AutoCompleteXHR');
                    $.each(Result, function () {
                        ValueData.push({
                            label: this.CustomerCompanyValue + " (" + this.CustomerCompanyKey + ")",
                            value: this.CustomerCompanyValue,
                            key: this.CustomerCompanyKey
                        });
                    });
                    Response(ValueData);
                }));
            }, function (Event, UI) {
                var CustomerCompanyKey   = UI.item.key,
                    CustomerCompanyValue = UI.item.value;

                if (
                    $Element.attr('name') != undefined
                    && $Element.attr('name').substr(0, 13) !== 'DynamicField_'
                ) {
                    TargetNS.AddCustomerID($(Event.target).attr('id'), CustomerCompanyValue, CustomerCompanyKey);
                }
                else {
                    $Element.val(CustomerCompanyKey);
                }

                Event.preventDefault();
                return false;
            }, 'CustomerCompanySearch');

            // initializes the customer fields
            TargetNS.InitCustomerField();
        }
    };

    /**
     * @name AddCustomerID
     * @memberof Core.Agent.CustomerCompanySearch
     * @function
     * @returns {Boolean} Returns false.
     * @param {String} Field
     * @param {String} CustomerCompanyValue - The readable customer identifier.
     * @param {String} CustomerCompanyKey - Customer key on system.
     * @description
     *      This function adds a new ticket customer
     */
    TargetNS.AddCustomerID = function (Field, CustomerCompanyValue, CustomerCompanyKey) {
        var $Clone            = $('.CustomerIDTemplate').clone(),
            CustomerIDCounter = $('#CustomerIDCounter').val(),
            CustomerIDs       = 0,
            IsDuplicated      = false,
            Suffix;

        if (typeof CustomerCompanyKey !== 'undefined') {
            CustomerCompanyKey = htmlDecode(CustomerCompanyKey);
        }
        else {
            $('#' +  Field).val('');
            return true;
        }

        if (CustomerCompanyValue === '') {
            return false;
            Core.App.Publish('Core.Agent.CustomerCompanySearch.AddCustomerID', [false, CustomerCompanyValue, CustomerCompanyKey]);
        }

        // check for duplicated entries
        $('[class*=CustomerIDText]').each(function() {
            if ($(this).val() === CustomerCompanyKey) {
                IsDuplicated = true;
            }
        });

        if ( IsDuplicated ) {
            $('#' +  Field).val('').focus();
            return true;
        }

        // increment customer counter
        CustomerIDCounter++;

        // set sufix
        Suffix = '_' + CustomerIDCounter;

        // remove unnecessary classes
        $Clone.removeClass('Hidden CustomerIDTemplate');

        // copy values and change ids and names
        $Clone.find(':input, a').each(function() {
            var ID = $(this).attr('id');

            $(this).attr('id', ID + Suffix);
            $(this).val(CustomerCompanyKey);

            // set customer key if present
            if($(this).hasClass('CustomerCompanyKey')) {
                $(this).val(CustomerCompanyKey);
            }

            // add event handler to remove button
            if($(this).hasClass('RemoveButton')) {

                // bind click function to remove button
                $(this).on('click', function () {

                    // remove row
                    TargetNS.RemoveCustomerID($(this));

                    return false;
                });
                // set button value
                $(this).val(CustomerCompanyKey);
            }

        });
        // show container
        $('#CustomerIDContent').parent().removeClass('Hidden');
        // append to container
        $('#CustomerIDContent').append($Clone);

        // set new value for CustomerIDCounter
        $('#CustomerIDCounter').val(CustomerIDCounter);

        // return value to search field
        $('#' +  Field).val('').focus();

        Core.App.Publish('Core.Agent.CustomerCompanySearch.AddCustomerID', [true, CustomerCompanyValue, CustomerCompanyKey]);

        return false;
    };

    /**
     * @name RemoveCustomerID
     * @memberof Core.Agent.CustomerCompanySearch
     * @function
     * @param {jQueryObject} Object - JQuery object used as base to delete it's parent.
     * @description
     *      This function removes a customer id entry.
     */
    TargetNS.RemoveCustomerID = function (Object) {
        var $Field = Object.closest('.Field');

        Object.parent().remove();

        if ($Field.find('.CustomerIDText:visible').length === 0) {
            $Field.addClass('Hidden');
        }

        Core.App.Publish('Core.Agent.CustomerCompanySearch.RemoveCustomerID', [Object]);
    };

    /**
     * @name InitCustomerField
     * @memberof Core.Agent.CustomerCompanySearch
     * @function
     * @description
     *      This function initializes the customer fields.
     */
    TargetNS.InitCustomerField = function () {

        // loop over the field with CustomerCompanyAutoComplete class
        $('.CustomerCompanyAutoComplete').each(function() {

            if ($(this).attr('name').substr(0, 13) !== 'DynamicField_') {

                var ObjectId = $(this).attr('id');

                $('#' + ObjectId).bind('change', function () {

                    if (!$('#' + ObjectId).val() || $('#' + ObjectId).val() === '') {
                        return false;
                    }

                    TargetNS.AddCustomerID(ObjectId, $('#' + ObjectId).val(), $('#' + ObjectId).prev('.CustomerCompanyKey').val());
                    return false;
                });

                $('#' + ObjectId).bind('keypress', function (e) {
                    if (e.which === 13){
                        TargetNS.AddCustomerID(ObjectId, $('#' + ObjectId).val(), $('#' + ObjectId).prev('.CustomerCompanyKey').val());
                        return false;
                    }
                });
            }
        });
    };

    return TargetNS;
}(Core.Agent.CustomerCompanySearch || {}));
