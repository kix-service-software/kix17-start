// --
// Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
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
 * @exports TargetNS as Core.KIX4OTRS.KIXSidebarCustomerInfo
 * @description This namespace contains the special module functions for the Dashboard.
 */
Core.KIX4OTRS.KIXSidebarCustomerInfo = (function(TargetNS) {


    /**
     * @function
     * @return nothing This function initializes the special module functions
     */

    TargetNS.UpdateContactSelection = function(CGIHandle,TicketID,ArticleID,SelectedCustomerID,Type) {

        if ( ArticleID == '' || ArticleID == TicketID ) {
            var ArticleLoaded = 0,
                ActiveInterval;

            // wait for article tab to be displayed and load customer info
            ActiveInterval = window.setInterval(function(){
                var $ArticleBox = $('#ArticleItems > div > div.WidgetSimple.Expanded');

                // check if article already loaded
                ArticleLoaded = $ArticleBox.length;

                // if article loaded
                if ( ArticleLoaded != 0 ) {
                    window.clearInterval(ActiveInterval);
                    // get article id and do content update
                    if ( $ArticleBox.prev('a').attr('name') !== undefined ) {
                        ArticleID = $ArticleBox.prev('a').attr('name').substring(7);
                        URL = CGIHandle + 'Action=KIXSidebarCustomerInfoAJAXHandler;Subaction=LoadCustomerEmails;TicketID='+TicketID+';ArticleID='+ArticleID+';SelectedCustomerID='+SelectedCustomerID+';';
                        Core.AJAX.ContentUpdate($('#CustomerUserEmail'), URL, function () {
                            Core.Agent.CustomerSearch.ReloadCustomerInfo($('#CustomerUserEmail').val(),'AgentKIXSidebarCustomerInfo',Type);
                        },false);
                    }
                }
                else {
                    // no article loaded, load customer info based on TicketID only
                    window.clearInterval(ActiveInterval);
                    URL = CGIHandle + 'Action=KIXSidebarCustomerInfoAJAXHandler;Subaction=LoadCustomerEmails;TicketID='+TicketID+';SelectedCustomerID='+SelectedCustomerID+';';
                    Core.AJAX.ContentUpdate($('#CustomerUserEmail'), URL, function () {
                        Core.Agent.CustomerSearch.ReloadCustomerInfo($('#CustomerUserEmail').val(),'AgentKIXSidebarCustomerInfo',Type);
                    },false);
                }
            }, 100);
        }

        else {
            URL = CGIHandle + 'Action=KIXSidebarCustomerInfoAJAXHandler;Subaction=LoadCustomerEmails;TicketID='+TicketID+';ArticleID='+ArticleID+';SelectedCustomerID='+SelectedCustomerID+';';
            Core.AJAX.ContentUpdate($('#CustomerUserEmail'), URL, function () {
                Core.Agent.CustomerSearch.ReloadCustomerInfo($('#CustomerUserEmail').val(),'AgentKIXSidebarCustomerInfo',Type);
            },false);
        }

    }

    return TargetNS;
}(Core.KIX4OTRS.KIXSidebarCustomerInfo || {}));
