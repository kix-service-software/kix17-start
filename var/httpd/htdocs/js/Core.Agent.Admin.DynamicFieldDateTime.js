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
 * @namespace Core.Agent.Admin.DynamicFieldDateTime
 * @memberof Core.Agent.Admin
 * @author OTRS AG
 * @description
 *      This namespace contains the special module functions for the DynamicFieldDateTime module.
 */
Core.Agent.Admin.DynamicFieldDateTime = (function (TargetNS) {

    /**
     * @name ToogleYearsPeriod
     * @memberof Core.Agent.Admin.DynamicFieldDateTime
     * @function
     * @returns {Boolean} false
     * @param {Number} YearsPeriod - 0 or 1 to show or hide the Years in Future and in Past fields.
     * @description
     *      This function shows or hide two fields (Years In future and Years in Past) depending
     *      on the YearsPeriod parameter
     */
    TargetNS.ToogleYearsPeriod = function (YearsPeriod) {
        if (YearsPeriod === '1') {
            $('#YearsPeriodOption').removeClass('Hidden');
        }
        else {
            $('#YearsPeriodOption').addClass('Hidden');
        }
        return false;
    };

    return TargetNS;
}(Core.Agent.Admin.DynamicFieldDateTime || {}));
