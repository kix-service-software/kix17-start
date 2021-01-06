// --
// Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        $('#ToggleChecker').bind('click', function() {
            // Changed with use of JQuery 1.6.4
            // $('.CheckTicket').attr('checked', $(this).attr('checked') );
            $('.CheckTicket').prop('checked', $(this).prop('checked'));
        });
        $('.TicketToMerge > td').bind('click', function() {
            var $CheckBox = $(this).parent().find('.CheckTicket'),
            // Changed with use of JQuery 1.6.4
            // CheckState = $CheckBox.attr('checked');
            CheckState = $CheckBox.prop('checked');

            // Changed with use of JQuery 1.6.4
            // $CheckBox.attr('checked', !CheckState );
            $CheckBox.prop('checked', !CheckState);
            if (CheckState)
                $('#ToggleChecker').removeAttr('checked');
        });
        $('.CheckTicket').bind('click', function(event) {
            event.stopPropagation();
        });
    };

    return TargetNS;
}(Core.KIX4OTRS.Agent.TicketMergeToCustomer || {}));
