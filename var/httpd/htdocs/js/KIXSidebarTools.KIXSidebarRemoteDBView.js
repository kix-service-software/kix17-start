// --
// KIXSidebarTools.KIXSidebarRemoteDBView.js - provides the special module functions for the remote db
// Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de\n";
//
// written/edited by:
// * Mario(dot)Illinger(at)cape-it(dot)de
// --
// $Id$
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var KIXSidebarTools = KIXSidebarTools || {};

/**
 * @namespace
 * @exports TargetNS as KIXSidebarTools.KIXSidebarRemoteDBView
 * @description
 *      This namespace contains the special module functions for the remote db search.
 */
KIXSidebarTools.KIXSidebarRemoteDBView = (function (TargetNS) {

    /**
    * @function
    * @param {String} Identifier The identifier of sidebar
    * @return nothing
    *      This function handles selection of checkboxes
    */
    TargetNS.UpdatePages = function (Identifier) {
        var Counter = 0;

        if ( $('.' + Identifier + 'Page').length > 1 ) {
            $('.' + Identifier + 'Page').each(function() {
                var Page = $(this);
                Counter++;
                var $PageAction = $('<a/>', {
                    id: Identifier + 'Page' + Counter,
                    class: Identifier + 'PageAction',
                    href: '#',
                    text: Counter,
                });
                $('#' + Identifier + 'Pagination').append($PageAction).append('&nbsp;');
                $('#' + Identifier + 'Page' + Counter).bind('click', function() {
                    $('.' + Identifier + 'Page').hide();
                    Page.show();

                    $('.' + Identifier + 'PageAction').css('font-weight', 'normal');
                    $(this).css('font-weight', 'bold');

                    return false;
                });
            })

            $('.' + Identifier + 'PageAction').first().trigger('click');
        }
    }

    return TargetNS;
}(KIXSidebarTools.KIXSidebarRemoteDBView || {}));
