// --
// Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var KIXSidebarTools = KIXSidebarTools || {};

/**
 * @namespace
 * @exports TargetNS as KIXSidebarTools.KIXSidebarConfigItemView
 * @description
 *      This namespace contains the special module functions for the config item view.
 */
KIXSidebarTools.KIXSidebarConfigItemView = (function (TargetNS) {

    /**
    * @function
    * @param {String} Identifier The identifier of sidebar
    * @return nothing
    *      This function handles pagination
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
}(KIXSidebarTools.KIXSidebarConfigItemView || {}));
