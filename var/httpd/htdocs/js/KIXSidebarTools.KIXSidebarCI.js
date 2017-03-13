// --
// Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var KIXSidebarTools = KIXSidebarTools || {};

/**
 * @namespace
 * @exports TargetNS as KIXSidebarTools.KIXSidebarCI
 * @description
 *      This namespace contains the special module functions for the CI search.
 */
KIXSidebarTools.KIXSidebarCI = (function (TargetNS) {

    TargetNS.ChangeCheckbox = function (Element, ObjectID, LinkMode, LinkType) {
        if ( !Core.Debug.CheckDependency('KIXSidebarTools', 'KIXSidebarTools.LinkObject2Ticket', 'KIXSidebarTools.LinkObject2Ticket') ) {
            return;
        }
        if ( !Core.Debug.CheckDependency('KIXSidebarTools', 'KIXSidebarTools.NoActionWithoutSelection', 'KIXSidebarTools.NoActionWithoutSelection') ) {
            return;
        }
        KIXSidebarTools.LinkObject2Ticket('ITSMConfigItem', Element.val(), ObjectID, LinkMode, LinkType, Element.prop('checked'));
        KIXSidebarTools.NoActionWithoutSelection();
    }

    return TargetNS;
}(KIXSidebarTools.KIXSidebarCI || {}));
