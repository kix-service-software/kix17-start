// --
// Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var KIXSidebarTools = KIXSidebarTools || {};

/**
 * @namespace
 * @exports TargetNS as KIXSidebarTools.KIXSidebarRemoteDB
 * @description
 *      This namespace contains the special module functions for the remote db search.
 */
KIXSidebarTools.KIXSidebarRemoteDB = (function (TargetNS) {

    /**
    * @function
    * @param {String} Identifier The identifier of sidebar
    * @return nothing
    *      This function handles selection of checkboxes
    */
    TargetNS.ChangeCheckbox = function (Element, Identifier, DynamicFields, ObjectID) {
        if ( !Core.Debug.CheckDependency('KIXSidebarTools', 'KIXSidebarTools.UpdateDynamicField', 'KIXSidebarTools.UpdateDynamicField') ) {
            return;
        }
        if ( !Core.Debug.CheckDependency('KIXSidebarTools', 'KIXSidebarTools.NoActionWithoutSelection', 'KIXSidebarTools.NoActionWithoutSelection') ) {
            return;
        }
        if ( Element.prop('checked') ) {
            $('input[type=checkbox]:checked.ResultCheckbox' + Identifier).each(
                function() {
                    $(this).prop('checked', false);
                }
            );
            Element.prop('checked', true);
            KIXSidebarTools.UpdateDynamicField(DynamicFields, Element.val(), ObjectID);
        } else {
            KIXSidebarTools.UpdateDynamicField(DynamicFields, '', ObjectID);
        }
        KIXSidebarTools.NoActionWithoutSelection();
        return false;
    }

    return TargetNS;
}(KIXSidebarTools.KIXSidebarRemoteDB || {}));
