// --
// Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
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
 * @exports TargetNS as Core.KIX4OTRS.CustomerDetails
 * @description This namespace contains the special module functions for the customer details.
 */
Core.KIX4OTRS.CustomerDetails = (function(TargetNS) {

    /**
     * @function
     * @return nothing This function initializes the customer details
     */
    TargetNS.Init = function() {
        var $CustomerInfo = $('#CustomerInfo, #Dashboard0500-CIC-CustomerInfo'),
            $TicketInfo = $('#TicketInfo'),
            $WidgetPopup = $CustomerInfo.find('.WidgetPopup'),
            $WidgetPopupResponsible = $TicketInfo.find('#ResponsibleDetails'),
            $WidgetPopupOwner       = $TicketInfo.find('#OwnerDetails');

        $CustomerInfo.find('.CustomerDetailsMagnifier').bind('click', function(Event) {
            var DetailPosition = Core.KIX4OTRS.GetWidgetPopupPosition($CustomerInfo, Event);
            Core.UI.Dialog.ShowDialog({
                Type : "CustomerDetails",
                Modal : false,
                Title : $WidgetPopup.find('.Header > h2').html(),
                HTML : $WidgetPopup.find('.Content').html(),
                PositionTop : DetailPosition.Top,
                PositionLeft : DetailPosition.Left
            });

            $('.Dialog > .Content').find('a.AsPopup').bind('click', function (Event) {
                var Matches,
                    PopupType = 'TicketAction';

                Matches = $(this).attr('class').match(/PopupType_(\w+)/);
                if (Matches) {
                    PopupType = Matches[1];
                }

                Core.UI.Popup.OpenPopup($(this).attr('href'), PopupType);
                return false;
            });
        });

        $TicketInfo.find('.ResponsibleDetailsMagnifier').bind('click', function(Event) {
            var DetailPosition = Core.KIX4OTRS.GetWidgetPopupPosition($TicketInfo, Event);
            Core.UI.Dialog.ShowDialog({
                Type : "ResponsibleDetails",
                Modal : false,
                Title : $WidgetPopupResponsible.find('.Header > h2').html(),
                HTML : $WidgetPopupResponsible.find('.Content').html(),
                PositionTop : DetailPosition.Top,
                PositionLeft : DetailPosition.Left
            });

            $('.Dialog > .Content').find('a.AsPopup').bind('click', function (Event) {
                var Matches,
                    PopupType = 'TicketAction';

                Matches = $(this).attr('class').match(/PopupType_(\w+)/);
                if (Matches) {
                    PopupType = Matches[1];
                }

                Core.UI.Popup.OpenPopup($(this).attr('href'), PopupType);
                return false;
            });
        });

        $TicketInfo.find('.OwnerDetailsMagnifier').bind('click', function(Event) {
            var DetailPosition = Core.KIX4OTRS.GetWidgetPopupPosition($TicketInfo, Event);
            Core.UI.Dialog.ShowDialog({
                Type : "OwnerDetails",
                Modal : false,
                Title : $WidgetPopupOwner.find('.Header > h2').html(),
                HTML : $WidgetPopupOwner.find('.Content').html(),
                PositionTop : DetailPosition.Top,
                PositionLeft : DetailPosition.Left
            });

            $('.Dialog > .Content').find('a.AsPopup').bind('click', function (Event) {
                var Matches,
                    PopupType = 'TicketAction';

                Matches = $(this).attr('class').match(/PopupType_(\w+)/);
                if (Matches) {
                    PopupType = Matches[1];
                }

                Core.UI.Popup.OpenPopup($(this).attr('href'), PopupType);
                return false;
            });
        });

    };

    // init
    $(document).ready(function() {
        if ($('#CustomerInfo, #Dashboard0500-CIC-CustomerInfo').length)
            Core.KIX4OTRS.CustomerDetails.Init();
    });

    return TargetNS;
}(Core.KIX4OTRS.CustomerDetails || {}));
