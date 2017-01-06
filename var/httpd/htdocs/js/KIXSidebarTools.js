// --
// KIXSidebarTools.js - provides the functionality for AJAX calls of KIXSidebarTools
// Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
//
// written/edited by:
//   Mario(dot)Illinger(at)cape(dash)it(dot)de
//
// --
// $Id$
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

/**
 * @namespace
 * @exports TargetNS as KIXSidebarTools
 * @description
 *      This namespace contains the functionality for AJAX calls of KIXSidebarTools.
 */
var KIXSidebarTools = (function (TargetNS) {

    /**
     * @private
     * @name SerializeData
     * @memberof KIXSidebarTools
     * @function
     * @returns {String} Query string of the data.
     * @param {Object} Data - The data that should be converted
     * @description
     *      Converts a given hash into a query string.
     */
    function SerializeData(Data) {
        var QueryString = '';
        $.each(Data, function (Key, Value) {
            QueryString += encodeURIComponent(Key) + '=' + encodeURIComponent(Value) + ';';
        });
        return QueryString;
    }

    /**
     * @private
     * @name GetSessionInformation
     * @memberof KIXSidebarTools
     * @function
     * @returns {Object} Hash with session data, if needed.
     * @description
     *      Collects session data in a hash if available.
     */
    function GetSessionInformation() {
        var Data = {};
        if (!Core.Config.Get('SessionIDCookie')) {
            Data[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            Data[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }
        Data.ChallengeToken = Core.Config.Get('ChallengeToken');
        return Data;
    }

    var FirstInit = true;
    /**
     * @function
     *      Initialize the sidebar
     * @param {String} Identifier The identifier of sidebar which should be initialized
     * @return nothing
     */
    TargetNS.Init = function (Identifier) {
        if (FirstInit) {
            FirstInit = false;
            KIXSidebarTools.NoActionWithoutSelection();
        }
    };

    /**
     * @function
     *      Calls via Ajax and updates a sidebar with the answer html of the server after delay
     * @param {String} Action The action returnung the result for this sidebar
     * @param {String} Identifier The identifier of sidebar which should be updated
     * @param {String} Data The data to be used in call
     * @param {Function} Callback The additional callback function which is called after the request returned from the server
     * @param {Integer} QueryDelay The number of miliseconds to wait before executing ajaxrequest
     * @param {Integer} RetryCount The number of tries for updating the sidebar
     * @param {Integer} RetryDelay The number of miliseconds to wait after a failed try
     * @return nothing
     */
    TargetNS.DelayUpdateSidebar = function (Action, Identifier, Data, Callback, QueryDelay, RetryCount, RetryDelay) {
        QueryDelay = (typeof QueryDelay === 'undefined' || QueryDelay < 0) ? 500 : QueryDelay;

        if ($('#' + Identifier).data('AJAXDelay')) {
            clearTimeout($('#' + Identifier).data('AJAXDelay'));
            $('#' + Identifier).removeData('AJAXDelay');
        }

        $('#' + Identifier).data('AJAXDelay', setTimeout(function() {KIXSidebarTools.UpdateSidebar(Action, Identifier, Data, Callback, RetryCount, RetryDelay)}, QueryDelay));
    };

    /**
     * @function
     *      Stops delayed calls via Ajax and updates a sidebar with the answer html of the server
     * @param {String} Identifier The identifier of sidebar which should be updated
     * @return nothing
     */
    TargetNS.StopDelayUpdateSidebar = function (Identifier) {
        if ($('#' + Identifier).data('AJAXDelay')) {
            clearTimeout($('#' + Identifier).data('AJAXDelay'));
            $('#' + Identifier).removeData('AJAXDelay');
        }
    };

    /**
     * @function
     *      Calls via Ajax and updates a sidebar with the answer html of the server
     * @param {String} Action The action returnung the result for this sidebar
     * @param {String} Identifier The identifier of sidebar which should be updated
     * @param {String} Data The data to be used in call
     * @param {Function} Callback The additional callback function which is called after the request returned from the server
     * @param {Integer} RetryCount The number of tries for updating the sidebar
     * @param {Integer} RetryDelay The number of miliseconds to wait after a failed try
     * @return nothing
     */
    TargetNS.UpdateSidebar = function (Action, Identifier, Data, Callback, RetryCount, RetryDelay) {
        RetryCount = (typeof RetryCount === 'undefined') ? 10 : RetryCount;
        RetryDelay = (typeof RetryDelay === 'undefined' || RetryDelay < 0) ? 100 : RetryDelay;

        $('#' + Identifier).toggleClass('Request', true);

        if ($('#' + Identifier).data('AJAXRequest')) {
            $('#' + Identifier).data('AJAXRequest').abort();
            $('#' + Identifier).removeData('AJAXRequest');
        }

        // add default data
        var Data = Data || {};
        Data.Action         = Action;
        Data.Identifier     = Identifier;
        Data.CallingAction  = Core.Config.Get('Action');

        // add data from session
        $.extend(Data, GetSessionInformation());

        // get data from form
        var SerializedForm = Core.AJAX.SerializeForm( $('input[name=TicketID]'), Data );
        if (!SerializedForm) {
            SerializedForm = Core.AJAX.SerializeForm( $('input[name=FormID]'), Data );
        }

        // build query
        var QueryString = SerializedForm + SerializeData(Data);
        $('#' + Identifier).data('AJAXRequest', $.ajax({
            type: 'POST',
            url: Core.Config.Get('CGIHandle'),
            data: QueryString,
            dataType: 'html',
            success: function (Response) {
                if (!Response) {
                    Core.Exception.HandleFinalError(new Core.Exception.ApplicationError('No content from: ' + URL, 'CommunicationError'));
                } else {
                    updateSidebar(Identifier, Response, RetryCount, RetryDelay, Callback);
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

    function updateSidebar(Identifier, Response, RetryCount, RetryDelay, Callback) {
        var ResultElement = $('#SearchResult' + Identifier);
        if (ResultElement && isJQueryObject(ResultElement) && ResultElement.length) {
            ResultElement.html(Response);
            $('#' + Identifier).toggleClass('Request', false);
            ResultElement.trigger('UpdateResultField');
            if ($.isFunction(Callback)) {
                Callback(Response);
            }
            KIXSidebarTools.NoActionWithoutSelection();
        } else {
            if (RetryCount > 0) {
                RetryCount--;
                setTimeout( function() { updateSidebar(Identifier, Response, RetryCount, RetryDelay, Callback) }, RetryDelay);
            } else {
                $('#' + Identifier).toggleClass('Request', false);
            }
        }
    }

    /**
     * @function
     * @param {String} SourceObject The type of Entry to link
     * @param {String} SourceKey The ID of Entry to link
     * @param {String} TargetKey The ID of Ticket
     * @param {String} Mode The mode for Link
     * @param {String} LinkType The LinkType for Link
     * @param {Boolean} Create Set to true, if link should be created, else existing link will be deleted
     * @return nothing
     */
    TargetNS.LinkObject2Ticket = function (SourceObject, SourceKey, TargetKey, Mode, LinkType, Create) {
        var CallingAction = Core.Config.Get('Action');
        var Action        = 'LinkObject';
        if ( ( CallingAction.search(/^Agent/) ) != -1 ) {
            Action = 'Agent' + Action;
        } else if ( ( CallingAction.search(/^Customer/) ) != -1 ) {
            Action = 'Customer' + Action;
        } else {
            return;
        }

        var SubAction = 'SingleLink';
        if (Create) {
            SubAction = SubAction + 'Add';
        } else {
            SubAction = SubAction + 'Delete';
        }

        var URL = 'Action=' + Action + ';SubAction=' + SubAction + ';SourceObject=' + SourceObject + ';TargetIdentifier=Ticket;SourceKey=' + SourceKey +';TargetKey=' + TargetKey + ';Mode='+ Mode + ';LinkType=' + LinkType;
        var SessionData = {};
        if (!Core.Config.Get('SessionIDCookie')) {
            SessionData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            SessionData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }
        SessionData.ChallengeToken = Core.Config.Get('ChallengeToken');

        $.each(SessionData, function (Key, Value) {
            URL += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });

        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function () {}, 'text', false);
    }

    /**
     * @function
     * @param {String} DynamicField The name of DynamicField
     * @param {String} Value The value to set
     * @param {String} ObjectID The ID of Ticket or Article
     * @return nothing
     */
    TargetNS.UpdateDynamicField = function (DynamicFields, Value, ObjectID) {
        var Reload = 0;
        var SplitDynamicField = DynamicFields.split(",");
        var SplitValue = Value.split(",");
        for(var i = 0; i < SplitDynamicField.length; i++) {
            var EntryDynamicField = SplitDynamicField[i];
            var EntryValue = '';
            if (SplitValue[i]) {
                EntryValue = SplitValue[i];
            }
            if ( $('#DynamicField_' + EntryDynamicField).length > 0 ) {
                $('#DynamicField_' + EntryDynamicField).val(decodeURIComponent(EntryValue));
                $('#DynamicField_' + EntryDynamicField).trigger('change');
            } else if ( EntryDynamicField && ObjectID ) {
                var URL = 'Action=DynamicFieldAJAXHandler;DynamicField=' + EntryDynamicField + ';Value=' + EntryValue + ';ObjectID=' + ObjectID;

                var SessionData = {};
                if (!Core.Config.Get('SessionIDCookie')) {
                    SessionData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
                    SessionData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
                }
                SessionData.ChallengeToken = Core.Config.Get('ChallengeToken');
                $.each(SessionData, function (Key, Value) {
                    URL += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
                });

                Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function () {}, 'text', false);
                Reload = 1;
            }
        }
        if (Reload) {
            location.reload();
        }
    }

    TargetNS.NoActionWithoutSelection = function () {
        var disableSubmit = false;
        $('.NoActionWithoutSelection:not(.HideSidebar)').each(function (index) {
            var noneChecked = true;
            $('input:checkbox.ResultCheckbox' + $(this).attr('id')).each(function() {
                if ($(this).prop('checked')) {
                    noneChecked = false;
                }
            });

            if (noneChecked){
                disableSubmit = true;
                $(this).addClass('NoActionWithoutSelectionHit');
            } else {
                $(this).removeClass('NoActionWithoutSelectionHit');
            }
        });
        $('#submitRichText').prop('disabled', disableSubmit);
        if (disableSubmit) {
            Core.Data.Set($('#submitRichText'), 'OldDisabledStatus', 'disabled');
        } else {
            Core.Data.Set($('#submitRichText'), 'OldDisabledStatus', '');
        }
    }

    return TargetNS;
}(KIXSidebarTools || {}));
