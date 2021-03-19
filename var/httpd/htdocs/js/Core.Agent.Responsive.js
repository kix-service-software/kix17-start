// --
// Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
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
        // This function is deactivated with KIX17.15.
        /*if (!$('#ViewModeSwitch').length) {
            $('#Footer').append('<div id="ViewModeSwitch"><a href="#">' + Core.Config.Get('ViewModeSwitchDesktop') + '</a></div>');
            $('#ViewModeSwitch a').on('click.Responsive', function() {
                localStorage.setItem("DesktopMode", 1);
                location.reload(true);
                return false;
            });
        }*/

        $('.Dashboard .WidgetSimple .Header').off('click.Responsive').on('click.Responsive', function() {
            $(this).find('.ActionMenu').fadeToggle();
        });

        // hide graphs as they're not properly supported on mobile devices
        $('.D3GraphMessage, .D3GraphCanvas').closest('.WidgetSimple').hide();

        // Add trigger icon for pagination
        $('span.Pagination a:first-child').parent().closest('.WidgetSimple').each(function() {
            if (!$(this).find('.ShowPagination').length) {
                $(this)
                    .find('.WidgetAction.Close')
                    .after('<div class="WidgetAction ShowPagination"><a title="Close" href=""><i class="fa fa-angle-double-right"></i></a></div>');
            }
        });

        $('.WidgetAction.ShowPagination').off('click.Responsive').on('click.Responsive', function() {
            $(this).closest('.WidgetSimple').find('.Pagination').toggleClass('AsBlock');
            return false;
        });

        // wrap sidebar modules with an additional container
        $.each($('.SidebarColumn, #NavigationContainer, #ContentItemNavTabs, .ContentColumn > .ActionRow, #ArticleItems .LightRow'), function() {
            var container   = $('<span />', {class: 'ResponsiveSidebarContainer'}),
                closeHandle = $('<button />', {class: 'ResponsiveCloseHandle', type: 'button'}),
                closeIcon   = $('<i />', {class:'fa fa-times fa-3x'}),
                openHandle  = $('<span />', {class: 'ResponsiveHandle'}),
                openIcon    = $('<i />', {class:'fa'}),
                wrapper     = $('<span />', {class: 'ResponsiveWrapperContainer'}),
                isWrapped   = 0,
                direction   = 'right',
                $Element    = $(this);

            if ( $Element.hasClass('SidebarColumn') ) {
                if ( $Element.closest('.ContentColumn').length ) {
                    openHandle.addClass('ResponsiveSubHandle')
                }
                openIcon.addClass('fa-caret-square-o-left');
            }
            else if ( $Element.attr('id') == 'NavigationContainer' ) {
                openHandle.addClass('ResponsiveNavHandle');
                openIcon.addClass('fa-navicon');
                direction = 'left';
            }
            else if ( $Element.attr('id') == 'ContentItemNavTabs' ) {
                openHandle.addClass('ResponsiveTabHandle');
                openIcon.addClass('fa-navicon');
                direction = 'left';
            }
            else if (
                $Element.hasClass('ActionRow')
                || $Element.hasClass('LightRow')
            ) {
                openHandle.addClass('ResponsiveMenuHandle');
                openIcon.addClass('fa-ellipsis-v');
            }

            container.on('click', function(Event) {
                // only react on a direct click on the background
                if (Event.target !== this) {
                    return;
                }

                closeHandle.trigger('click');
            });

            if (
                $Element.children().length
                && !$Element.closest('.ResponsiveSidebarContainer').length
            ) {
                container.addClass('ResponsiveSidebar-' + direction);
                container.append(wrapper);
                $Element.wrap(container);
                isWrapped = 1;
            }

            if ( isWrapped ) {

                openHandle.append(openIcon);

                closeHandle.append(closeIcon);
                closeHandle.prependTo($Element.closest('.ResponsiveSidebarContainer'));
                $Element.closest('.ResponsiveSidebarContainer').before(openHandle);

                // add hide handling
                closeHandle.on('click', function() {
                    $Element.closest('.ResponsiveSidebarContainer').hide();
                    $('html').removeClass('NoScroll');

                    if ( direction == 'left' ) {
                        $Element.closest('.ResponsiveSidebarContainer').children().animate({
                            'left': '-300px'
                        });
                    }
                    else {
                        $Element.closest('.ResponsiveSidebarContainer').children().animate({
                            'right': '-300px'
                        });
                    }

                    return false;
                });

                // add expansion handling
                openHandle.on('click', function() {
                    $Element.closest('.ResponsiveSidebarContainer').show();
                    $('html').addClass('NoScroll');

                    if ( direction == 'left' ) {
                        $Element.closest('.ResponsiveSidebarContainer').children().animate({
                            'left': '0px'
                        });
                    }
                    else {
                        $Element.closest('.ResponsiveSidebarContainer').children().animate({
                            'right': '0px'
                        });
                    }

                    if ( $Element.attr('id') == 'NavigationContainer' ) {
                        $Element.find('ul > li > a').css(
                            {
                                "border":"0px",
                                "float":"none"
                            }
                        );
                    }

                    $Element.find('.MenuClusterIcon, .ClusterLink').off().on('click', function(){
                        if ($(this).closest('li').hasClass('ClusterSelect') ) {
                            $(this).closest('li').removeClass('ClusterSelect');
                        } else {
                            $(this).closest('.ActionRow').find('li').removeClass('ClusterSelect');
                            $(this).closest('li').addClass('ClusterSelect');
                        }
                    });
                    return false;
                });

                if ( $Element.attr('id') == 'ContentItemNavTabs' ) {
                    $( "#ContentItemTabs" ).off("tabsbeforeload").on( "tabsbeforeload", function() {
                        closeHandle.trigger('click');
                    });
                }
            }
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

        // reset dialog container position
        if ( $('.Dialog.Fullsize').length ) {
            $('.Dialog.Fullsize').css({
                top: 0,
                left: 0
            });
        }
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
        $.each($('.ResponsiveSidebarContainer'), function() {
            var $Element = $(this).find('#NavigationContainer, #ContentItemNavTabs, .SidebarColumn, .ActionRow, .LightRow');
            if ( $Element.hasClass('.SidebarColumn, .ActionRow, .LightRow') ) {
                if ( $Element.css('left') === '-300px' ) {
                    $Element.css('left', '0px');
                } else if ( $(this).css('right') === '-300px' ) {
                    $Element.css('right', '0px');
                }
            }
            $(this).prev('.ResponsiveHandle').remove();
            $(this).children('button').remove();
            $Element.unwrap().unwrap();
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

        // reset dialog container position
        if ( $('.Dialog.Fullsize').length ) {
            $('.Dialog').removeClass('Fullsize').css({
                top: '10%',
                left: '30%'
            });
        }
    });

    return TargetNS;

}(Core.Agent.Responsive || {}));
