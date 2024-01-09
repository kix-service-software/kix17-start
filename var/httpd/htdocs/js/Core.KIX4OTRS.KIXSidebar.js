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
 * @exports TargetNS as Core.KIX4OTRS.KIXSidebar
 * @description This namespace contains the special module functions for the
 *              Dashboard.
 */
Core.KIX4OTRS.KIXSidebar = (function(TargetNS) {

    /**
     * @function
     * @return nothing This function initializes the special module functions
     */

    TargetNS.ArticleAttachmentPager = function() {
        var PagerString = '';

        // create pages
        var PageCount = 0;
        for ( var i = 1; i <= $('.ArticleAttachmentPageDiv').length; i++)
            PagerString = PagerString + ' <a href="#" class="ArticleAttachmentPageLink">' + i + '</a> ';

        if ($('.ArticleAttachmentPageDiv').length > 1) {
            $('#ArticleAttachmentPager .Pagination').html(PagerString);
        } else {
            $('#ArticleAttachmentPager').css('display', 'none');
            $('#ArticleAttachmentPageDiv1').css('display', 'block');
        }

        // bind page click
        $('.ArticleAttachmentPageLink').on('click', function(event) {
            var CurrentDivID = $(this).html();

            // hide all page divs
            $('.ArticleAttachmentPageDiv').css('display', 'none');

            // show new page div
            $('#ArticleAttachmentPageDiv' + CurrentDivID).css('display', 'block');

            $('.ArticleAttachmentPageLink').css('font-weight', 'normal');
            $(this).css('font-weight', 'bold');

            event.preventDefault();
        }).first().trigger('click');
    }

    /**
     * @function
     * @return nothing This function initializes the special module functions
     */

    TargetNS.LinkedCIPager = function($Element) {
        var PagerString = '';
        var ParentID = '';

        var $PageDivList = $('.LinkedCIPageDiv');
        if ($Element) {
            $PageDivList = $Element.find('.LinkedCIPageDiv');
            ParentID = $Element.attr('id');
        }

        // create pages
        var PageCount = 0;
        for ( var i = 1; i <= $PageDivList.length; i++)
            PagerString = PagerString + ' <a href="#" class="LinkedCIPageLink">' + i + '</a> ';

        if ($PageDivList.length > 1) {
            $('#LinkedCIPager .Pagination').html(PagerString);
            $('#LinkedCIPager').css('display', 'block');
        } else {
            $('#LinkedCIPager').css('display', 'none');
            $('#LinkedCIPageDiv1' + ParentID).css('display', 'block');
        }

        // bind page click
        $('.LinkedCIPageLink').on('click', function(event) {
            var CurrentDivID = $(this).html();

            // hide all page divs
            $('.LinkedCIPageDiv').css('display', 'none');

            // show new page div
            $('#LinkedCIPageDiv' + CurrentDivID + ParentID).css('display', 'block');

            $('.LinkedCIPageLink').css('font-weight', 'normal');
            $(this).css('font-weight', 'bold');

            event.preventDefault();
        }).first().trigger('click');
    }

    /**
     * @function
     * @return nothing This function initializes the special module functions
     */

    TargetNS.Init = function(SidebarWidth, Action, ExtendedUrlContent) {

        // to get the text module preview (doesn't work if jQuery "resizable" is
        // active)
        if ($('#TextModulePreviewContainer').length) {
            $('.SidebarColumn').find('#TextModulePreviewContainer').insertBefore('div.SidebarColumn');
        }

        // resize (first init)
        var Tab = '';
        if (Action.match(/(.*)Tab(.*)/)) {
            Tab = 'Tab';
        }

        $('.SidebarColumn' + Tab).css({
            "width" : SidebarWidth
        })

        .resizable({
            resize : function(e, ui) {
                ui.position.left = '0px';
                $('.SidebarColumn').css({
                    "left" : "0px"
                });
            },
            stop : function(e, ui) {
                var Width = ui.size.width, MinWidth = 150;

                // Set minimal width
                if (Width < MinWidth) {
                    Width = MinWidth;
                    $('.SidebarColumn' + Tab).css({ "width" : Width + "px" });
                }
                if (Action.match(/^Customer/)) {
                    Core.Customer.PreferencesUpdate(Action + 'SidebarWidth', Width);
                } else {
                    Core.Agent.PreferencesUpdate(Action + 'SidebarWidth', Width);
                }

            },
            handles : "w"
        });

        // drag and drop
        Core.UI.DnD.Sortable($('.SidebarColumn' + Tab), {
            Handle : '.Header h2',
            Items : '.CanDrag',
            Placeholder : 'DropPlaceholder',
            Tolerance : 'pointer',
            Distance : 15,
            Opacity : 0.6,
            Update : function(event, ui) {
                var url = 'Action=' + Action + ';Subaction=UpdatePosition;' + ExtendedUrlContent;
                $('.WidgetSimple.CanDrag').each(function(i) {
                    url = url + ';Backend=' + $(this).attr('id');
                });
                Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), url, function() {}, 'text');
            }
        });

        if ($('.SpanPager').length) {
            TargetNS.LinkedCIPager();
        }
    };

    return TargetNS;
}(Core.KIX4OTRS.KIXSidebar || {}));
