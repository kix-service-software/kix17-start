// --
// Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var KIXSidebarTools = KIXSidebarTools || {};

/**
 * @namespace
 * @exports TargetNS as KIXSidebarTools.KIXSidebarDisableSidebar
 * @description
 *      This namespace contains the special module functions to disable sidebars.
 */
KIXSidebarTools.KIXSidebarDisableSidebar = (function (TargetNS) {

    TargetNS.Update = function () {
        var CompleteString = 'Action=KIXSidebarDisableSidebarAJAXHandler;CallingAction=' + Core.Config.Get('Action') + ';';
        var SerializedForm = Core.AJAX.SerializeForm( $('input[name=TicketID]') );
        if (!SerializedForm) {
            SerializedForm = Core.AJAX.SerializeForm( $('input[name=FormID]') );
        }
        CompleteString += SerializedForm;

        var SessionData = {};
        if (!Core.Config.Get('SessionIDCookie')) {
            SessionData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            SessionData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }
        SessionData.ChallengeToken = Core.Config.Get('ChallengeToken');
        $.each(SessionData, function (Key, Value) {
            CompleteString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });
        CompleteString = CompleteString.replace(/;;/g, ";");

        var Cache = new Object();
        var QueryString = "";
        var Params = CompleteString.split(";");
        for (var i = 0; i < Params.length; i++) {
            var KeyValue = Params[i].split("=");
            if (!Cache[KeyValue[0]]) {
                Cache[KeyValue[0]] = KeyValue[1];
                QueryString += KeyValue[0] + "=" + KeyValue[1] + ";";
            }
        }
        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), QueryString, function (Response) {
            var DisabledSidebars = Response.split(',');

            // show all hidden sidebars at the beginning to get all needed fields back
            $('.HideSidebar').each(function() {
                for (var i = 0; i < DisabledSidebars.length; i++) {
                    if (DisabledSidebars[i] == '') {
                        continue;
                    }
                    if ($(this).attr('id') == DisabledSidebars[i]) {
                        return true;
                    }
                }
                $(this).toggleClass('HideSidebar', false);
                $(this).children().each(function() {
                    if ($(this).is('select,input,textarea')) {
                        if ($(this).prop('disabled') === true) {
                            $(this).prop('disabled', false);
                        }
                    }
                });
            });

            for (var i = 0; i < DisabledSidebars.length; i++) {
                if (DisabledSidebars[i] == '') {
                    continue;
                }
                $('#' + DisabledSidebars[i] + '.WidgetSimple:not(.HideSidebar)').each(function () {
                    $(this).toggleClass('HideSidebar', true);
                    $(this).children().each(function () {
                        // set field disabled to prevent submitting content
                        if ( $(this).is('select,input,textarea') ) {
                            $(this).attr('disabled','disabled');
                        }
                    });
                    $(this).trigger('HideSidebar');
                });
            }
        }, 'text', false);
    }

    return TargetNS;
}(KIXSidebarTools.KIXSidebarDisableSidebar || {}));
