// --
// Copyright (C)  cape-it, http://www.cape-it.de/
// Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
//
// written/edited by:
// * Andreas(dot)Hergert(at)cape(dash)it(dot)de
// * Frank(dot)Jacquemin(at)cape(dash)it(dot)de
//
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.HidePendingTime
 * @memberof Core.Agent
 * @author c.a.p.e. IT
 * @description
 *      This namespace contains the special module functions for hiding Pending-Input-Fields in the Agent Frontend depending on the next chosen TicketState.
 */
Core.Agent.HidePendingTimeInput = (function (TargetNS) {

    /**
     * @name Init
     * @memberof Core.Agent.HidePendingTimeInput
     * @function
     * @description
     *      This function initializes the special module functions.
     */
    TargetNS.Init = function (Data, Name) {

        $('#' + Name).change(function(){
            var Value = $(this).val();
            if(Data[Value]){
                $('.HidePendingTimeInput').show();
            }else{
                $('.HidePendingTimeInput').hide();
            }
        }).trigger('change');
    };

    return TargetNS;
}(Core.Agent.HidePendingTimeInput || {}));
