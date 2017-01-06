// --
// KIXSidebarTools.KIXSidebarFAQ.js - provides the special module functions for the ticket search
// Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de\n";
//
// written/edited by:
// * Stefan(dot)Mehlig(at)cape-it(dot)de
// * Mario(dot)Illinger(at)cape-it(dot)de
// --
// $Id$
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var KIXSidebarTools = KIXSidebarTools || {};

/**
 * @namespace
 * @exports TargetNS as KIXSidebarTools.KIXSidebarFAQ
 * @description
 *      This namespace contains the special module functions for the CI classes search.
 */
KIXSidebarTools.KIXSidebarFAQ = (function (TargetNS) {

    TargetNS.ShowContent = function (ID) {
        var CallingAction = Core.Config.Get('Action');
        var Action        = 'FAQZoom';
        if ( ( CallingAction.search(/^Agent/) ) != -1 ) {
            Action = 'Agent' + Action;
        } else if ( ( CallingAction.search(/^Customer/) ) != -1 ) {
            Action = 'Customer' + Action;
        } else {
            Action = 'Public' + Action;
        }

        var SessionData = {};
        if (!Core.Config.Get('SessionIDCookie')) {
            SessionData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            SessionData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }
        SessionData.ChallengeToken = Core.Config.Get('ChallengeToken');

        var SessionString = '';
        $.each(SessionData, function (Key, Value) {
            SessionString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });

        var FAQIFrame = '<iframe class="TextOption FAQ" src="' + Core.Config.Get('CGIHandle') + '?Action=' + Action + ';ItemID=' + ID + ';Nav=None' + SessionString + '"> </iframe>';
        Core.UI.Dialog.ShowContentDialog(FAQIFrame, '', '10px', 'Center', true);
        return false;
    }

    return TargetNS;
}(KIXSidebarTools.KIXSidebarFAQ || {}));
