// --
// Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.Responsive
 * @memberof Core.Agent
 * @author OTRS AG
 * @description
 *      This namespace contains the responsive functionality.
 */
Core.Agent.Responsive = (function (TargetNS) {

    Core.App.Subscribe('Event.App.Responsive.SmallerOrEqualScreenL', function () {
        Core.App.Subscribe('Event.UI.RichTextEditor.InstanceReady',function(Editor) {
            var ContentWidth = Core.Config.Get('RichText.Width', 620);
            if ( $('#cke_' + Editor.editor.name).closest('.Content').length ) {
                ContentWidth = $('#cke_' + Editor.editor.name).closest('.Content').width();
            }
            else if ($('#cke_' + Editor.editor.name).closest('.ContentColumn').length) {
                ContentWidth = $('#cke_' + Editor.editor.name).closest('.ContentColumn').width();
            }
            if ( ContentWidth < Core.Config.Get('RichText.Width', 620)) {
                Editor.editor.resize(ContentWidth, Core.Config.Get('RichText.Height', 320), true);
            }
        });

        $(window).resize(function() {
            if ( typeof CKEDITOR !== 'undefined' ) {
                $.each( CKEDITOR.instances, function(ID) {
                    var ContentWidth = Core.Config.Get('RichText.Width', 620);
                    if ( $('#cke_' + CKEDITOR.instances[ID].name).closest('.Content').length ) {
                        ContentWidth = $('#cke_' + CKEDITOR.instances[ID].name).closest('.Content').width();
                    }
                    else if ($('#cke_' + CKEDITOR.instances[ID].name).closest('.ContentColumn').length) {
                        ContentWidth = $('#cke_' + CKEDITOR.instances[ID].name).closest('.ContentColumn').width();
                    }
                    if ( ContentWidth < Core.Config.Get('RichText.Width', 620)) {
                        CKEDITOR.instances[ID].resize(ContentWidth, Core.Config.Get('RichText.Height', 320), true);
                    }
                });
            }
        });

        // Add class to toolbar
        $('#ToolBarToggle').addClass('ResponsiveToolbar');
        $('.ResponsiveToolbar').off('.ResponsiveToolbar').on('click.ResponsiveToolbar', function() {
            $('body').removeClass('OpenToolbar');
            if ( $(this).hasClass('Hide') ) {
                $('body').addClass('OpenToolbar');
            }
        });
        if ( $('#ToolBarToggle').hasClass('Hide') ) {
            $('body').addClass('OpenToolbar');
        }

        // Add switch for Desktopmode
        if (!$('#ViewModeSwitch').length) {
            $('#Footer').append('<div id="ViewModeSwitch"><a href="#">' + Core.Config.Get('ViewModeSwitchDesktop') + '</a></div>');
            $('#ViewModeSwitch a').on('click.Responsive', function() {
                localStorage.setItem("DesktopMode", 1);
                location.reload(true);
                return false;
            });
        }

        $('.Dashboard .WidgetSimple .Header').off('click.Responsive').on('click.Responsive', function() {
            $(this).find('.ActionMenu').fadeToggle();
        });

        // hide graphs as they're not properly supported on mobile devices
        $('.D3GraphMessage, .D3GraphCanvas').closest('.WidgetSimple').hide();

        // Add trigger icon for pagination
        $('span.Pagination a:first-child').parent().closest('.WidgetSimple').each(function() {
            if (!$(this).find('.ShowPagination').length) {
                $(this).find('.WidgetAction.Close').after('<div class="WidgetAction ShowPagination"><a title="Close" href=""><i class="fa fa-angle-double-right"></i></a></div>');
            }
        });

        $('.WidgetAction.ShowPagination').off('click.Responsive').on('click.Responsive', function() {
            $(this).closest('.WidgetSimple').find('.Pagination').toggleClass('AsBlock');
            return false;
        });

        // wrap sidebar modules with an additional container
        if ($('.SidebarColumn').children().length && !$('.SidebarColumn').closest('.ResponsiveSidebarContainer').length) {
            $('.SidebarColumn').wrap('<div class="ResponsiveSidebarContainer" />');
        }
        if (!$('#NavigationContainer').closest('.ResponsiveSidebarContainer').length) {
            $('#NavigationContainer').wrap('<div class="ResponsiveSidebarContainer" />');
            $('#NavigationContainer').css('height', '100%');
        }
        // wrap sidebar modules with an additional container
        if ($('.ContentColumn > .ActionRow').children().length && !$('.ContentColumn > .ActionRow').closest('.ResponsiveSidebarContainer').length) {
            $('.ContentColumn > .ActionRow').wrap('<div class="ResponsiveSidebarContainer" />');
        }
        // wrap sidebar modules with an additional container
        if ($('#ArticleItems .LightRow').length) {
            var ResponsiveCount = 0;
            $.each($('#ArticleItems .LightRow'), function () {
                if ( $(this).children().length && !$(this).closest('.ResponsiveSidebarContainer').length) {
                    $(this).wrap('<div id="ResponsiveMenu_' + ResponsiveCount + '" class="ResponsiveSidebarContainer ResponsiveArticleMenu" />');
                    ResponsiveCount++;
                }
            });
        }
        // make sure the relevant sidebar is being collapsed on clicking
        // on the background
        $('.ResponsiveSidebarContainer').off().on('click', function(Event) {

            // only react on a direct click on the background
            if (Event.target !== this) {
                return;
            }

            $(this).prev('.ResponsiveHandle').trigger('click');
        });

        // add handles for navigation and sidebar
        if (!$('#ResponsiveSidebarHandle').length) {
            $('.SidebarColumn').closest('.ResponsiveSidebarContainer').before('<span class="ResponsiveHandle" id="ResponsiveSidebarHandle"><i class="fa fa-caret-square-o-left"></i></span>');
        }
        if (!$('#ResponsiveNavigationHandle').length) {
            $('#NavigationContainer').closest('.ResponsiveSidebarContainer').before('<span class="ResponsiveHandle" id="ResponsiveNavigationHandle"><i class="fa fa-navicon"></i></span>');
        }
        if (!$('#ResponsiveTicketMenuHandle').length) {
            $('.ContentColumn .ActionRow').closest('.ResponsiveSidebarContainer').before('<span class="ResponsiveHandle ResponsiveMenuHandle" id="ResponsiveTicketMenuHandle"><i class="fa fa-ellipsis-v"></i></span>');
        }
        if (!$('.ResponsibleMenuHandle').length) {
            $.each($('div[id^=ResponsiveMenu_'), function () {
                $(this).before('<span class="ResponsiveHandle ResponsiveMenuHandle"><i class="fa fa-ellipsis-v"></i></span>');
            });
        }

        // add navigation sidebar expansion handling
        $('#ResponsiveNavigationHandle').off().on('click', function() {
            if (
                parseInt($('#NavigationContainer').css('left'), 10) < 0
                || parseInt($('#NavigationContainer').css('left'), 10) === 10
            ) {
                $('#ResponsiveSidebarHandle').animate({
                    'right': '-45px'
                });
                $('#NavigationContainer').closest('.ResponsiveSidebarContainer').fadeIn();
                $('html').addClass('NoScroll');
                $('#NavigationContainer').animate({
                    'left': '0px'
                });

                $('.ResponsiveSidebarContainer > div > ul > li > a').css(
                    {
                        "border":"0px",
                        "float":"none"
                    }
                );
            }
            else {
                $('#ResponsiveSidebarHandle').animate({
                    'right': '15px'
                });
                $('#NavigationContainer').closest('.ResponsiveSidebarContainer').fadeOut();
                $('html').removeClass('NoScroll');
                $('#NavigationContainer').animate({
                    'left': '-280px'
                });
            }
            return false;
        });

        // add sidebar column expansion handling
        $('#ResponsiveSidebarHandle').off().on('click', function() {
            if (parseInt($('.SidebarColumn').css('right'), 10) < 0) {
                $('#ResponsiveNavigationHandle').animate({
                    'left': '-45px'
                });
                $('.SidebarColumn').closest('.ResponsiveSidebarContainer').fadeIn();
                $('html').addClass('NoScroll');
                $('.ResponsiveSidebarContainer .SidebarColumn').animate({
                    'right': '0px'
                });
            }
            else {
                $('#ResponsiveNavigationHandle').animate({
                    'left': '15px'
                });
                $('.SidebarColumn').closest('.ResponsiveSidebarContainer').fadeOut();
                $('html').removeClass('NoScroll');
                $('.ResponsiveSidebarContainer .SidebarColumn').animate({
                    'right': '-300px'
                });
            }
            return false;
        });

        // add sidebar column expansion handling
        $('.ResponsiveMenuHandle').off().on('click', function() {
            var $Element = $(this).next('.ResponsiveSidebarContainer').children('div');
            if (parseInt($Element.css('right'), 10) < 0) {
                $('#ResponsiveNavigationHandle').animate({
                    'left': '-45px'
                });
                $('#ResponsiveSidebarHandle').animate({
                    'right': '-45px'
                });
                $Element.closest('.ResponsiveSidebarContainer').fadeIn();
                $('html').addClass('NoScroll');
                $Element.animate({
                    'right': '0px'
                });
                $Element.find('.MenuClusterIcon, .ClusterLink').off().on('click', function(){
                    if ($(this).closest('li').hasClass('ClusterSelect') ) {
                        $(this).closest('li').removeClass('ClusterSelect');
                    } else {
                        $('.ResponsiveSidebarContainer .ActionRow li').removeClass('ClusterSelect');
                        $(this).closest('li').addClass('ClusterSelect');
                    }
                });
            }
            else {
                $('#ResponsiveNavigationHandle').animate({
                    'left': '15px'
                });
                $('#ResponsiveSidebarHandle').animate({
                    'right': '15px'
                });
                $Element.closest('.ResponsiveSidebarContainer').fadeOut();
                $('html').removeClass('NoScroll');
                $Element.animate({
                    'right': '-300px'
                });
            }
            return false;
        });

        // check if there are any changes in the sidebar that we should notify the user about
        Core.App.Subscribe('Event.Agent.CustomerSearch.GetCustomerInfo.Callback', function() {
            $('#ResponsiveSidebarHandle').after('<span class="ResponsiveHandle" id="ResponsiveSidebarNotification"><i class="fa fa-exclamation"></i></span>');
            $('#ResponsiveSidebarNotification').fadeIn().delay(3000).fadeOut(function() {
                $(this).remove();
            });
        });

        // hide options on ticket creations
        $('#OptionCustomer').closest('.Field').hide().prev('label').hide();

        // initially hide navigation container
        $('#NavigationContainer').css('left', '-280px');

        // move toolbar to navigation container
        $('#ToolBar').detach().prependTo('#AppWrapper');

        // make fields which have a following icon not as wide as other fields
        $('.FormScreen select').each(function() {
            if ($(this).nextAll('a:visible:not(".DatepickerIcon")').length) {
                $(this).css('width', '85%');
            }
        });

        // Collapse widgets in preferences screen for better overview
        $('.PreferencesScreen .Size1of3 > .WidgetSimple').removeClass('Expanded').addClass('Collapsed');
    });

    Core.App.Subscribe('Event.App.Responsive.ScreenXL', function () {
        // remove class to toolbar
        $('.ResponsiveToolbar').off('.ResponsiveToolbar');
        $('#ToolBarToggle').removeClass('ResponsiveToolbar');
        $('body').removeClass('OpenToolbar');

        Core.App.Subscribe('Event.UI.RichTextEditor.InstanceReady',function(Editor) {
            var ContentWidth = Core.Config.Get('RichText.Width', 620),
                LabelWidth   = 0;
            if ( $('#cke_' + Editor.editor.name).closest('.Content').length ) {
                ContentWidth = $('#cke_' + Editor.editor.name).closest('.Content').width();
                LabelWidth   = $('#cke_' + Editor.editor.name).closest('.Content').find('label').first().width();
            }
            else if ($('#cke_' + Editor.editor.name).closest('.ContentColumn').length) {
                ContentWidth = $('#cke_' + Editor.editor.name).closest('.ContentColumn').width();
                LabelWidth   = $('#cke_' + Editor.editor.name).closest('.ContentColumn').find('label').first().width();
            }
            // real content = content - padding - label;
            ContentWidth = ContentWidth - 25 - LabelWidth;
            if ( ContentWidth < Core.Config.Get('RichText.Width', 620)) {
                Editor.editor.resize(ContentWidth, Core.Config.Get('RichText.Height', 320), true);
            } else {
                Editor.editor.resize(Core.Config.Get('RichText.Width', 620), Core.Config.Get('RichText.Height', 320), true);
            }
        });

        $(window).resize(function() {
            if ( typeof CKEDITOR !== 'undefined' ) {
                $.each( CKEDITOR.instances, function(ID) {
                    var ContentWidth = Core.Config.Get('RichText.Width', 620),
                        LabelWidth   = 0;
                    if ( $('#cke_' + CKEDITOR.instances[ID].name).closest('.Content').length ) {
                        ContentWidth = $('#cke_' + CKEDITOR.instances[ID].name).closest('.Content').width();
                        LabelWidth   = $('#cke_' + CKEDITOR.instances[ID].name).closest('.Content').first('label').width();
                    }
                    else if ($('#cke_' + CKEDITOR.instances[ID].name).closest('.ContentColumn').length) {
                        ContentWidth = $('#cke_' + CKEDITOR.instances[ID].name).closest('.ContentColumn').width();
                        LabelWidth   = $('#cke_' + CKEDITOR.instances[ID].name).closest('.ContentColumn').first('label').width();
                    }
                    // real content = content - padding - label;
                    ContentWidth = ContentWidth - 25 - LabelWidth;
                    if ( ContentWidth < Core.Config.Get('RichText.Width', 620)) {
                        CKEDITOR.instances[ID].resize(ContentWidth, Core.Config.Get('RichText.Height', 320), true);
                    } else {
                        CKEDITOR.instances[ID].resize(Core.Config.Get('RichText.Width', 620), Core.Config.Get('RichText.Height', 320), true);
                    }
                });
            }
        });

        // remove show pagination trigger icons
        $('.WidgetAction.ShowPagination, #ViewModeSwitch').remove();

        // show graphs again
        $('.D3GraphMessage, .D3GraphCanvas').closest('.WidgetSimple').show();

        // remove the additional container again
        $('.ResponsiveSidebarContainer').children('#NavigationContainer').unwrap();
        $.each($('.ResponsiveSidebarContainer').children('.SidebarColumn, .ActionRow, .LightRow'), function() {
            if ( $(this).css('left') === '-300px' ) {
                $(this).css('left', '0px');
            } else if ( $(this).css('right') === '-300px' ) {
                $(this).css('right', '0px');
            }
            $(this).unwrap();
        });

        $('#OptionCustomer').closest('.Field').show().prev('label').show();

        // reset navigation container position
        $('#NavigationContainer').css(
            {
                'left': '100px',
                'height': '35px'
            }
        );

        // re-add toolbar to header
        $('#ToolBar').detach().prependTo('#Header');

        // reset field widths
        $('.FormScreen select').each(function() {
            if ($(this).nextAll('a:visible:not(".DatepickerIcon")').length) {
                $(this).css('width', '');
            }
        });

        // re-expand widgets in preferences screen
        $('.PreferencesScreen .WidgetSimple').removeClass('Collapsed').addClass('Expanded');
    });

    return TargetNS;

}(Core.Agent.Responsive || {}));
