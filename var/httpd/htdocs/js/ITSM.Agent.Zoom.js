// --
// Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var ITSM = ITSM || {};
ITSM.Agent = ITSM.Agent || {};

/**
 * @namespace ITSM.Agent.Zoom
 * @exports TargetNS as Core.ITSM.TicketZoom
 * @description
 *      This namespace contains the special module functions for ITSM.
 */
ITSM.Agent.Zoom = (function (TargetNS) {

    /**
     * @function
     * @param {String} ITSMTableHeight - The heigth of the table.
     * @description
     *      This function initializes the special module functions.
     */
    TargetNS.Init = function (ITSMTableHeight) {

        Core.UI.Resizable.Init($('#ITSMTableBody'), ITSMTableHeight, function (event, ui, Height) {

            // remember new height for next reload
            window.clearTimeout(TargetNS.ResizeTimeOutScroller);
            TargetNS.ResizeTimeOutScroller = window.setTimeout(function () {
                Core.Agent.PreferencesUpdate('UserConfigItemZoomTableHeight', Height);
            }, 1000);
        });
    };

    return TargetNS;
}(ITSM.Agent.Zoom || {}));
