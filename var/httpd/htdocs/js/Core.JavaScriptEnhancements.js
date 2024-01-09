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

(function () {

    /**
     * @name isJQueryObject
     * @memberof window
     * @function
     * @returns {Boolean} Returns true if all parameter objects are jQuery objects, false otherwise.
     * @description
     *      This function checks if all given parameter objects are jQuery objects.
     */
    window.isJQueryObject = function () {
        var I;
        if (typeof jQuery === 'undefined') {
            return false;
        }
        for (I = 0; I < arguments.length; I++) {
            if (!(arguments[I] instanceof jQuery)) {
                return false;
            }
        }
        return true;
    };
}());
