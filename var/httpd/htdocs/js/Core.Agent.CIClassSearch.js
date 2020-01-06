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
 * @exports TargetNS as Core.Agent.CIClassSearch
 * @description
 *      This namespace contains the special module functions for the CI classes search.
 */
Core.Agent.CIClassSearch = (function (TargetNS) {

   /**
     * @function
     * @param {jQueryObject} $Element The jQuery object of the input field with autocomplete
     * @param {Boolean} ActiveAutoComplete Set to false, if autocomplete should only be started by click on a button next to the input field
     * @return nothing
     *      This function initializes the special module functions
     */
    TargetNS.Init = function ($Element, ClassID ,ActiveAutoComplete) {

        if (typeof ClassID === 'undefined') {
            ClassID = $('#' + Core.App.EscapeSelector($Element.attr('id'))).attr('classid');
        }

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
                        Action: 'AgentCIClassSearch',
                        ClassID: ClassID,
                        Term: Request.term,
                        MaxResults: Core.Config.Get('Autocomplete.MaxResultsDisplayed')
                    };
                    Core.AJAX.FunctionCall(URL, Data, function (Result) {
                        var Data = [];
                        $.each(Result, function () {
                            Data.push({
                                label: this.CIClassValue,
                                value: this.CIClassKey
                            });
                        });
                        Response(Data);
                    });
                },
                select: function (Event, UI) {
                    var CIClassKey = UI.item.value;

                    $Element.val(UI.item.label);

                    // set hidden field SelectedQueue
                    $('#' + Core.App.EscapeSelector($Element.attr('id')) + 'Selected').val(CIClassKey);

                    Event.preventDefault();
                    return false;
                }
            });

            if (!ActiveAutoComplete) {
                $Element.after('<button id="' + $Element.attr('id') + 'Search" type="button">' + Core.Config.Get('Autocomplete.SearchButtonText') + '</button>');
                $('#' + Core.App.EscapeSelector($Element.attr('id')) + 'Search').click(function () {
                    $Element.autocomplete("option", "minLength", 0);
                    $Element.autocomplete("search");
                    $Element.autocomplete("option", "minLength", 500);
                });
            }
        }

        // On unload remove old selected data. If the page is reloaded (with F5) this data stays in the field and invokes an ajax request otherwise
        $(window).bind('unload', function () {
           $('#' + Core.App.EscapeSelector($Element.attr('id')) + 'Selected').val('');
        });
    };

    return TargetNS;
}(Core.Agent.CIClassSearch || {}));
