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
 * @exports TargetNS as KIXSidebarTools.KIXSidebarCustomer
 * @description
 *      This namespace contains the special module functions for the CI search.
 */
KIXSidebarTools.KIXSidebarCustomer = (function (TargetNS) {

    TargetNS.ChangeCheckbox = function (Element, ObjectID, LinkMode, LinkType, LinkReverse) {
        if ( !Core.Debug.CheckDependency('KIXSidebarTools', 'KIXSidebarTools.LinkObject2Ticket', 'KIXSidebarTools.LinkObject2Ticket') ) {
            return;
        }
        if ( !Core.Debug.CheckDependency('KIXSidebarTools', 'KIXSidebarTools.NoActionWithoutSelection', 'KIXSidebarTools.NoActionWithoutSelection') ) {
            return;
        }
        KIXSidebarTools.LinkObject2Ticket('Person', Element.val(), ObjectID, LinkMode, LinkType, Element.prop('checked'));
        KIXSidebarTools.NoActionWithoutSelection();
    }

    return TargetNS;
}(KIXSidebarTools.KIXSidebarCustomer || {}));
