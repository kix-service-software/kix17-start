// --
// Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var ITSM = ITSM || {};
ITSM.Agent = ITSM.Agent || {};

/**
 * @namespace
 * @exports TargetNS as ITSM.Agent.IncidentState
 * @description
 *      This namespace contains the special module functions for IncidentState.
 */
ITSM.Agent.IncidentState = (function (TargetNS) {

    TargetNS.ShowIncidentState = function (Data) {

        Data.Subaction = 'GetServiceIncidentState';

        Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function (Response) {

            // if a service was selected and an incident state was found
            if (Response.CurInciSignal) {

                // set incident signal
                $('#ServiceIncidentStateSignal').attr('class', Response.CurInciSignal);
                $('#ServiceIncidentStateSignal').attr('title', Response.CurInciState);

                // set incident state
                $('#ServiceIncidentState').html(Response.CurInciState);

                // show service incident signal and state
                $('#ServiceIncidentStateContainer')
                    .show()
                    .prev()
                    .show();
            }
            else {
                // hide service incident signal and state
                $('#ServiceIncidentStateContainer')
                    .hide()
                    .prev()
                    .hide();
            }
        });
    };

    return TargetNS;
}(ITSM.Agent.IncidentState || {}));
