// --
// Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};
Core.KIX4OTRS.Agent = Core.KIX4OTRS.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.Agent.TicketMergeToCustomer
 * @description This namespace contains the special module functions for
 *              AgentTicketMergeToCustomer
 */
Core.KIX4OTRS.Agent.TicketMergeToCustomer = (function(TargetNS) {
    // Toggle Checkbox Status of all Tickets with JQuery
    TargetNS.Init = function() {
        $('#ToggleChecker').on('click', function() {
            $('.CheckTicket').prop('checked', $(this).prop('checked'));
        });
        $('.TicketToMerge > td').on('click', function() {
            var $CheckBox = $(this).parent().find('.CheckTicket'),

            CheckState = $CheckBox.prop('checked');

            $CheckBox.prop('checked', !CheckState);
            if (CheckState) {
                $('#ToggleChecker').prop('checked', false);
            }
        });
        $('.CheckTicket').on('click', function(event) {
            event.stopPropagation();
        });
    };

    return TargetNS;
}(Core.KIX4OTRS.Agent.TicketMergeToCustomer || {}));
