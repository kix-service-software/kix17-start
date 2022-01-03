// --
// Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.TicketOverviewHighlight
 * @description Provides functions for ticket highlighting in ticket overviews.
 */
Core.KIX4OTRS.TicketOverviewHighlight = (function(TargetNS) {
    var $TicketOverviewRows = $('.TicketOverviewHighlightClass');

    if (!$TicketOverviewRows.length)
        return;

    $TicketOverviewRows.each(function() {
        // takes stylesheet from parent element
        var CurrTicketState = $(this).attr('style');

        if (CurrTicketState) {
            // reformat style of all child elements
            $(this).children().attr('style', CurrTicketState);
        }
    });

    return TargetNS;
}(Core.KIX4OTRS.TicketOverviewHighlight || {}));
