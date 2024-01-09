// --
// Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

    function InitCallContacts() {
        $('input.LinkedPersonToCallContact').on('change', function() {
            var Customer = $(this).val().split(':::');
            if ( $(this).is(':checked') ) {
                Core.Agent.CustomerSearch.AddTicketCustomer( 'FromCustomer', Customer[0], Customer[1] );
            } else {
                $('#TicketCustomerContentFromCustomer input.CustomerKey').each(function() {
                    if ( $(this).val() == Customer[1] ) {
                        Core.Agent.CustomerSearch.RemoveCustomerTicket( $(this) );
                    }
                });
            }
        });

        // check existing contacts in list
        $('#TicketCustomerContentFromCustomer input.CustomerKey').each(function() {
            if ( $(this).val() ) {
                $('#LinkedPersons input[name="LinkedPersonToCallContact_' + $(this).val() + '"]').prop( "checked", true );
            }
        });

        // listen to add/remove of call contacts from list and check/uncheck the corresponding checkbox
        Core.App.Subscribe('Core.Agent.CustomerSearch.AddTicketCustomer', function (Result, CustomerValue, CustomerKey) {
            if ( CustomerKey && !$('#LinkedPersons input[name="LinkedPersonToCallContact_' + CustomerKey + '"]').is(':checked') ) {
                $('#LinkedPersons input[name="LinkedPersonToCallContact_' + CustomerKey + '"]').prop( "checked", true );
            }
        });
        Core.App.Subscribe('Core.Agent.CustomerSearch.RemoveTicketCustomer', function ($RemoveObject) {
            var CustomerKey = $RemoveObject.siblings('.CustomerKey').val();
            if ( CustomerKey && $('#LinkedPersons input[name="LinkedPersonToCallContact_' + CustomerKey + '"]').is(':checked') ) {
                $('#LinkedPersons input[name="LinkedPersonToCallContact_' + CustomerKey + '"]').prop( "checked", false );
            }
        });
    }

    function RefreshLinkedPersons() {
        var TicketID,
            URL,
            Frontend = 'Agent';

        $('#LinkedPersonsTable').html('<div class="Loader Center"></div>');

        // determine TicketID
        if ($('#LinkedPersons').closest('form').find('input[name=TicketID]').length) {
            TicketID = $('#LinkedPersons').closest('form').find('input[name=TicketID]').val();
        }
        else if ( $('#LinkedPersons').closest('.LayoutFixedSidebar').children('.ContentColumn').find('input[name=TicketID]').length ) {
            TicketID = $('#LinkedPersons').closest('.LayoutFixedSidebar').children('.ContentColumn').find('input[name=TicketID]').val();
        }

        // determine Frontend
        if ($(location).attr('href').search(/customer\.pl/) > 0) {
            Frontend = 'Customer';
        }

        // do linked persons update
        $('#LinkedPersonsTable').html('<div class="Loader Center"></div>');
        URL = Core.Config.Get('CGIHandle') + '?Action=KIXSidebarLinkedPersonsAJAXHandler;CallingAction=' + $('input[name=Action]').val() + ';Subaction=LoadLinkedPersons;TicketID=' + TicketID + ';Frontend=' + Frontend;

        // check if call contact is active
        if ( $('#CallContactActive').val() ) {
            URL += ';CallContactActive=1';
        }
        Core.AJAX.ContentUpdate($('#LinkedPersonsTable'), URL, function() {
            Core.KIX4OTRS.LinkedPersons.InitList();
        });

        return;
    }

    TargetNS.InitList = function() {
        $('#LinkedPersonsTable tbody > tr').find('.PersonDetails').on('click', function(Event) {
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

        $('.EmailRecipientType').on('change', function(Event) {
            AddAddress($(this).val(), $(this).next('.LinkedPersonMail').val());
        });

        // add or remove contact from call contact list if checkbox is changed
        if ( $('input.LinkedPersonToCallContact').length ) {
            InitCallContacts();
        }

        return true;
    }

    TargetNS.Init = function() {
        $('#LinkedPersons .WidgetAction.Toggle').on('click', function() {
            // load linked persons on first expand
            if ($('#LinkedPersons').hasClass('Collapsed') && $('#LinkedPersons').find('#LinkedPersonsTable tbody').length == 0)
                RefreshLinkedPersons();
        });

        if ( !$('#LinkedPersons').closest('form').length ) {
            if ( $('#LinkedPersons').closest('.LayoutFixedSidebar').children('.ContentColumn').find('input[name=TicketID]').length ) {
                $('#LinkedPersons').closest('.LayoutFixedSidebar').children('.ContentColumn').find('form').on('submit', function(Event) {
                    $('#LinkedPersons').find('input[name=LinkedPersonToInform]:checked').each(function() {
                        $('<input />').attr('type', 'hidden')
                                      .attr('name', 'LinkedPersonToInform')
                                      .attr('value', $(this).val())
                                      .appendTo(Event.target);
                    });
                });
            }
        }

        return true;
    }

    return TargetNS;
}(Core.KIX4OTRS.LinkedPersons || {}));

// init
$(document).ready(function() {
    if ($('#LinkedPersonsTable').length)
        Core.KIX4OTRS.LinkedPersons.Init();
});
