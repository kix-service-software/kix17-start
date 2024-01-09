// --
// Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
// based on the original work of:
// Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};
Core.KIX4OTRS.Agent = Core.KIX4OTRS.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.Agent.CustomerDashboard
 * @description This namespace contains the special module functions for the
 *              customer Dashboard.
 */
Core.KIX4OTRS.Agent.CustomerDashboard = (function(TargetNS) {

    /**
     * @function
     * @return nothing This function initializes the special module functions
     */

    TargetNS.Init = function() {
        Core.UI.DnD.Sortable($('.SidebarColumn'), {
            Handle : '.Header h2',
            Items : '.CanDrag',
            Placeholder : 'DropPlaceholder',
            Tolerance : 'pointer',
            Distance : 15,
            Opacity : 0.6,
            Update : function(event, ui) {
                var url = 'Action=' + Core.Config.Get('Action') + ';Subaction=UpdatePosition;';
                $('.CanDrag').each(function(i) {
                    url = url + ';Backend=' + $(this).attr('id');
                });
                Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), url, function() {});
            }
        });

        Core.UI.DnD.Sortable($('.ContentColumn'), {
            Handle : '.Header h2',
            Items : '.CanDrag',
            Placeholder : 'DropPlaceholder',
            Tolerance : 'pointer',
            Distance : 15,
            Opacity : 0.6,
            Update : function(event, ui) {
                var url = 'Action=' + Core.Config.Get('Action') + ';Subaction=UpdatePosition;';
                $('.CanDrag').each(function(i) {
                    url = url + ';Backend=' + $(this).attr('id');
                });
                Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), url, function() {});
            }
        });
    };

    /**
     * @function
     * @return nothing This function binds a click event on an html element to
     *         update the preferences of the given dahsboard widget
     * @param {jQueryObject}
     *            $ClickedElement The jQuery object of the element(s) that get
     *            the event listener
     * @param {string}
     *            ElementID The ID of the element whose content should be
     *            updated with the server answer
     * @param {jQueryObject}
     *            $Form The jQuery object of the form with the data for the
     *            server request
     */
    TargetNS.RegisterUpdatePreferences = function($ClickedElement, ElementID, $Form) {
        if (isJQueryObject($ClickedElement) && $ClickedElement.length) {
            $ClickedElement.click(function() {
                var URL = Core.Config.Get('Baselink') + Core.AJAX.SerializeForm($Form);
                Core.AJAX.ContentUpdate($('#' + ElementID), URL, function() {
                    Core.UI.ToggleTwoContainer($('#' + ElementID + '-setting'), $('#' + ElementID));
                    Core.UI.Table.InitCSSPseudoClasses();
                });
                return false;
            });
        }
    };

    /**
     * @function
     * @private
     * @param {string}
     *            FieldID Id of the field which is updated via ajax
     * @description Shows and hides an ajax loader for every element which is
     *              updates via ajax
     */
    var AJAXLoaderPrefix = 'AJAXLoader', ActiveAJAXCalls = {};

    function ToggleAJAXLoader(FieldID) {
        var $Element = $('#' + FieldID), $Loader = $('#' + AJAXLoaderPrefix + FieldID), LoaderHTML = '<span id="' + AJAXLoaderPrefix + FieldID
            + '" class="AJAXLoader"></span>';

        if (!$Loader.length) {
            if ($Element.not('[type=hidden]').length) {
                $Element.after(LoaderHTML);
                if (typeof ActiveAJAXCalls[FieldID] === 'undefined') {
                    ActiveAJAXCalls[FieldID] = 0;
                }
                ActiveAJAXCalls[FieldID]++;
            }
        } else if ($Loader.is(':hidden')) {
            $Loader.show();
            if (typeof ActiveAJAXCalls[FieldID] === 'undefined') {
                ActiveAJAXCalls[FieldID] = 0;
            }
            ActiveAJAXCalls[FieldID]++;
        } else {
            ActiveAJAXCalls[FieldID]--;
            if (ActiveAJAXCalls[FieldID] <= 0) {
                $Loader.hide();
                ActiveAJAXCalls[FieldID] = 0;
            }
        }
    }

    /**
     * @function
     * @return nothing This function binds a change event on the customer search
     *         element to update all dashboard widgets
     * @param {jQueryObject}
     *            $ClickedElement The jQuery object of the element(s) that get
     *            the event listener
     * @param {string}
     *            TargetElement The JQuery object of the element which should be
     *            focused on page initialization
     * @param {string}
     *            ChangedElement The JQuery object of the element whose content
     *            was changed and is used as event trigger
     * @param {jQueryObject}
     *            $Form The jQuery object of the form with the data for the
     *            server request
     */
    TargetNS.RegisterCustomerSearch = function($TargetElement, $ChangedElement) {
        $TargetElement.focus();
        $ChangedElement.on('change', function() {
            var CustomerUserLogin = $(this).val(), URL = 'Action=AgentCustomerDashboard;Subaction=ElementsUpdate;CustomerUserLogin=' + CustomerUserLogin;

            Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function(Data) {
                var FieldsToUpdate = new Array();

                $('.CustomerDashboard-box').addClass('Loading');
                $('.CustomerDashboard').each(function(i) {
                    FieldsToUpdate.push($(this).attr('id'));
                    ToggleAJAXLoader($(this).attr('id'));
                });

                if (Data) {
                    $.each(FieldsToUpdate, function(Index, Value) {
                        var $Element = $('#' + Value), ElementData;
                        if ($Element.length && Data) {
                            // direct container replacing
                            if ($Element.is('div,label,p,li') && Data[Value]) {
                                $Element.html(Data[Value]);
                            }
                            // Other form elements
                            else {
                                if (Data[Value]) {
                                    $Element.val(Value);
                                }
                            }
                        }
                    });
                }

                $.each(FieldsToUpdate, function(Index, Value) {
                    ToggleAJAXLoader(Value);
                });

                $('.CustomerDashboard-box').removeClass('Loading');
            });
            return false;
        });
    };

    TargetNS.UpdateRemoteDBSidebar = function (Action, Identifier, Data) {
        var RetryCount = 10, RetryDelay = 100;

        $('#' + Identifier).toggleClass('Request', true);

        if ($('#' + Identifier).data('AJAXRequest')) {
            $('#' + Identifier).data('AJAXRequest').abort();
            $('#' + Identifier).removeData('AJAXRequest');
        }
        // init complete query string
        var CompleteString = 'Action=' + Action + ';Identifier=' + Identifier + ';CallingAction=' + Core.Config.Get('Action') + ';' + Data + ';';

        // add data from form
        var SerializedForm = Core.AJAX.SerializeForm( $('input[name=TicketID]') );
        if (!SerializedForm) {
            SerializedForm = Core.AJAX.SerializeForm( $('input[name=FormID]') );
        }
        CompleteString += SerializedForm;

        // add session data
        var SessionData = {};
        if (!Core.Config.Get('SessionIDCookie')) {
            SessionData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            SessionData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }
        SessionData.ChallengeToken = Core.Config.Get('ChallengeToken');
        $.each(SessionData, function (Key, Value) {
            CompleteString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });

        // build query string
        CompleteString = CompleteString.replace(/;;/g, ";");
        var Cache = new Object();
        var QueryString = "";
        var Params = CompleteString.split(";");
        for (var i = 0; i < Params.length; i++) {
            var KeyValue = Params[i].split("=");
            if (
                KeyValue.length == 2
                && KeyValue[0]
                && typeof Cache[KeyValue[0]] === 'undefined'
                && KeyValue[1] != ''
            ) {
                Cache[KeyValue[0]] = 1;
                QueryString += KeyValue[0] + "=" + encodeURIComponent(KeyValue[1]) + ";";
            }
        }
        QueryString = QueryString.replace(/;$/g, "");
        $('#' + Identifier).data('AJAXRequest', $.ajax({
            type: 'POST',
            url: Core.Config.Get('CGIHandle'),
            data: QueryString,
            dataType: 'html',
            success: function (Response) {
                if (!Response) {
                    Core.Exception.HandleFinalError(new Core.Exception.ApplicationError('No content from: ' + URL, 'CommunicationError'));
                } else {
                    UpdateSearchResult(Identifier, Response, RetryCount, RetryDelay);
                }
            },
            error: function (jqXHR, textStatus, errorThrown) {
                if (textStatus != 'abort') {
                    alert('Error thrown by AJAX: ' + textStatus + ': ' + errorThrown);
                    $('#' + Identifier).toggleClass('Request', false);
                }
            }
        }));

        return false;
    };

    function UpdateSearchResult(Identifier, Response, RetryCount, RetryDelay) {
        var ResultElement = $('#SearchResult' + Identifier);
        if (ResultElement && isJQueryObject(ResultElement) && ResultElement.length) {
            ResultElement.html(Response);
            $('#' + Identifier).toggleClass('Request', false);
            ResultElement.trigger('UpdateResultField');
        } else {
            if (RetryCount > 0) {
                RetryCount--;
                setTimeout( function() { UpdateSearchResult(Identifier, Response, RetryCount, RetryDelay) }, RetryDelay);
            } else {
                $('#' + Identifier).toggleClass('Request', false);
            }
        }
    }

    return TargetNS;
}(Core.KIX4OTRS.Agent.CustomerDashboard || {}));
