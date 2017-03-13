// --
// Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.LinkedPersons
 * @description Provides functions for linked person support
 */
Core.KIX4OTRS.LinkedPersons = (function(TargetNS) {

    function AddAddress(Target, Mail) {
        if (!$('#' + Target).length)
            return;
        if (!Mail)
            return;

        var DeleteString = 'RemoveCustomerTicket_', EmailFields = new Array('ToCustomer', 'CcCustomer', 'BccCustomer'), RemovePrefix = new Array('', 'Cc',
            'Bcc');

        // remove entries from other recipient fields
        for ( var i = 0; i < 3; i++) {
            if (!$('#' + EmailFields[i]).length)
                continue;
            var Counter = $('#CustomerTicketCounter' + EmailFields[i]).val(), CurrentDeleteObject;

            for ( var j = 1; j <= Counter; j++) {
                $CurrentDeleteObject = $('#' + RemovePrefix[i] + DeleteString + j);
                if ($CurrentDeleteObject.val() == Mail) {
                    Core.Agent.CustomerSearch.RemoveCustomerTicket($CurrentDeleteObject);
                }
            }
        }

        // Add email to selected recipient field
        if ($('#' + Target).length) {
            Core.Agent.CustomerSearch.AddTicketCustomer(Target, Mail);
        }

        return true;
    }

    function RefreshLinkedPersons() {
        var TicketID,
            URL,
            Frontend = 'Agent',
            loaderImage = '<img src="' + Core.Config.Get('Images') + 'loader.gif">';

        $('#LinkedPersonsTable').html(loaderImage);

        // determine TicketID
        if ($('#LinkedPersons').closest('form').find('input[name=TicketID]').length) {
            TicketID = $('#LinkedPersons').closest('form').find('input[name=TicketID]').val();
        }

        // determine Frontend
        if ($(location).attr('href').search(/customer\.pl/) > 0) {
            Frontend = 'Customer';
        }

        // do linked persons update
        $('#LinkedPersonsTable').html('<center><img style="margin-top:5px" src="' + Core.Config.Get('Images') + 'loader.gif"></center>');
        URL = Core.Config.Get('CGIHandle') + '?Action=KIXSidebarLinkedPersonsAJAXHandler;CallingAction=' + $('input[name=Action]').val() + ';Subaction=LoadLinkedPersons;TicketID=' + TicketID + ';Frontend=' + Frontend;
        Core.AJAX.ContentUpdate($('#LinkedPersonsTable'), URL, function() {
            Core.KIX4OTRS.LinkedPersons.InitList();
        });

        return;
    }

    TargetNS.InitList = function() {
        $('#LinkedPersonsTable tbody > tr').find('.PersonDetails').bind('click', function(Event) {
            var PersonID = $(this).find('.LinkedPersonID').val();
            var $Details = $('#LinkedPersonDetails' + PersonID);
            var DetailPosition = Core.KIX4OTRS.GetWidgetPopupPosition($Details.parent(), Event);
            Core.UI.Dialog.ShowDialog({
                Type : "Details",
                Modal : false,
                Title : $Details.find('.Header > h2').html(),
                HTML : $Details.find('.Content').html(),
                PositionTop : DetailPosition.Top,
                PositionLeft : DetailPosition.Left
            });
        });

        $('.EmailRecipientType').bind('change', function(Event) {
            AddAddress($(this).val(), $(this).next('.LinkedPersonMail').val());
        });

        return true;
    }

    TargetNS.Init = function() {
        $('#LinkedPersons .WidgetAction.Toggle a').bind('click', function() {
            // load linked persons on first expand
            if ($('#LinkedPersons').hasClass('Collapsed') && $('#LinkedPersons').find('#LinkedPersonsTable tbody').length == 0)
                RefreshLinkedPersons();
        });

        return true;
    }

    return TargetNS;
}(Core.KIX4OTRS.LinkedPersons || {}));

// init
$(document).ready(function() {
    if ($('#LinkedPersonsTable').length)
        Core.KIX4OTRS.LinkedPersons.Init();
});
