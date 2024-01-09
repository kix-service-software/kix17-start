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
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace Core.Agent.Admin.SysConfig
 * @memberof Core.Agent.Admin
 * @author OTRS AG
 * @description
 *      This namespace contains the special module functions for the SysConfig module.
 */
Core.Agent.Admin.SysConfig = (function (TargetNS) {
    /**
     * @name Init
     * @memberof Core.Agent.Admin.SysConfig
     * @function
     * @description
     *      Initializes SysConfig screen.
     */
    TargetNS.Init = function () {
        $('#AdminSysConfig h3 input[type="checkbox"]').click(function () {
            $(this).parent('h3').parent('fieldset').toggleClass('Invalid');
        });

        // don't allow editing disabled fields
        $('#AdminSysConfig').on('focus', '.Invalid input', function() {
            $(this).blur();
        });
    };

    return TargetNS;
}(Core.Agent.Admin.SysConfig || {}));
