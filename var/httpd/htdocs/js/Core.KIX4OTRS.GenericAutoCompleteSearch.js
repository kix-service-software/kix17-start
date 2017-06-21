// --
// Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.AgentGenericAutoCompleteSearch
 * @description This namespace contains the special module functions for the
 *              queue search.
 */

Core.KIX4OTRS.GenericAutoCompleteSearch = (function(TargetNS) {
    var BackupData = {
        SearchObjectKey : '',
        SearchObjectName : ''
    };
    var Config = {
        MayResultsDisplayed : 20 // neccessary because of Config reset in TabView
    };

    // KIX4OTRS-capeIT

    /**
     * @function
     * @param {jQueryObject}
     *            $Element The jQuery object of the input field with
     *            autocomplete
     * @param {Boolean}
     *            ActiveAutoComplete Set to false, if autocomplete should only
     *            be started by click on a button next to the input field
     * @return nothing This function initializes the special module functions
     */
    TargetNS.Init = function($Element, $DestElement, ActiveAutoComplete) {

        if (typeof ActiveAutoComplete === 'undefined') {
            ActiveAutoComplete = true;
        } else {
            ActiveAutoComplete = !!ActiveAutoComplete;
        }
        // only AgentTicketZoom and QueueMove autocompete then unbind change
        if (Core.Config.Get('Action') === 'AgentTicketZoom') {
            if (ActiveAutoComplete && $Element.val() && $Element.val().length && !$('#DestQueueID').val().length) {
                $('#DestQueueID').unbind('change');
            }
        }

        $Element.keypress(function(event) {
            if (event.keyCode == 13) {
                return false;
            }
        });

        if (isJQueryObject($Element)) {
            Config.MaxResultsDisplayed = Core.Config.Get('GenericAutoCompleteSearch.MaxResultsDisplayed');
            $Element.autocomplete({
                minLength : ActiveAutoComplete ? Core.Config.Get('GenericAutoCompleteSearch.MinQueryLength') : 500,
                delay : Core.Config.Get('GenericAutoCompleteSearch.QueryDelay'),
                source : function(Request, Response) {

                    var Action = 'AgentGenericAutoCompleteSearch', Subaction = '', LinkedObject = '', LinkedDirection = '', ElementID = $DestElement.attr('id');

                    // get action
                    if (ElementID === 'QuickLinkAttribute') {
                        Action = 'QuickLinkAJAXHandler';
                        Subaction = 'Search';
                    }

                    else if (ElementID === 'MainTicketNumber') {
                        Action = 'AgentTicketMerge';
                        Subaction = 'SearchTicketID';
                    }

                    else if (ElementID === 'NewTicketNumberArticleCopy' || ElementID === 'NewTicketNumberArticleMove') {
                        Action = 'AgentArticleEdit';
                        Subaction = 'SearchTicketID';
                    }

                    var URL = Core.Config.Get('Baselink'), Data = {
                        Action : Action,
                        Term : Request.term,
                        Module : Core.Config.Get('Action'),
                        TicketID : $('input[name=TicketID]').first().val(),
                        ArticleID : $('input[name=ArticleID]').first().val(),
                        ElementID : $DestElement.attr('id'),
                        MaxResults : Config.MaxResultsDisplayed,
                        SourceObject : $('#SourceObject').val(),
                        SourceKey : $('#SourceKey').val(),
                        TargetObject : $('#TargetIdentifier').find('option:selected').val(),
                        TypeIdentifier : $('#TypeIdentifier').find('option:selected').val(),
                        Subaction : Subaction
                    };

                    Core.AJAX.FunctionCall(URL, Data, function(Result) {
                        var Data = [];
                        $.each(Result, function() {
                            Data.push({
                                label : this.SearchObjectValue + " (" + this.SearchObjectKey + ")",
                                value : this.SearchObjectValue
                            });
                        });
                        Response(Data);
                    });
                },
                select : function(Event, UI) {
                    var Key = UI.item.label.replace(/.*\((.*)\)$/, '$1');
                    BackupData.SearchObjectKey = Key;
                    BackupData.SearchObjectName = UI.item.value;
                    $Element.val(UI.item.value);
                    $DestElement.val(Key);

                    if (Core.Config.Get('Action').match(/AgentTicketZoom/) && $Element.parents('.Actions').length > 0) {
                        $Element.closest('form').submit();
                    }
                }
            });

            if (!ActiveAutoComplete) {
                $Element.after('<button id="' + $Element.attr('id') + 'Search" type="button">' + Core.Config.Get('Autocomplete.SearchButtonText') + '</button>');
                $('#' + $Element.attr('id') + 'Search').click(function() {
                    $Element.autocomplete("option", "minLength", 0);
                    $Element.autocomplete("search");
                    $Element.autocomplete("option", "minLength", 500);
                });
            }
        }

        // On unload remove old selected data. If the page is reloaded (with F5)
        // this data stays in the field and invokes an ajax request otherwise
        $(window).bind('unload', function() {
            $Element.val('');
        });
    };

    return TargetNS;
}(Core.KIX4OTRS.GenericAutoCompleteSearch || {}));
