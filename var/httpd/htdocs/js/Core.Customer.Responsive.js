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
Core.Customer = Core.Customer || {};

/**
 * @namespace Core.Customer.Responsive
 * @memberof Core.Customer
 * @author OTRS AG
 * @description
 *      This namespace contains the responsive functionality.
 */
Core.Customer.Responsive = (function (TargetNS) {

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

        // Add switch for Desktopmode
        if (!$('#ViewModeSwitch').length) {
            $('#Footer').append('<div id="ViewModeSwitch"><a href="#">' + Core.Config.Get('ViewModeSwitchDesktop') + '</a></div>');
            $('#ViewModeSwitch a').on('click.Responsive', function() {
                localStorage.setItem("DesktopMode", 1);
                location.reload(true);
                return false;
            });
        }

        // wrap sidebar modules with an additional container
        if (!$('#NavigationContainer').closest('.ResponsiveSidebarContainer').length) {
            $('#NavigationContainer').wrap('<div class="ResponsiveSidebarContainer" />');
        }
        // wrap sidebar modules with an additional container
        if (!$('.SidebarColumn').closest('.ResponsiveSidebarContainer').length) {
            $('.SidebarColumn').wrap('<div class="ResponsiveSidebarContainer" />');
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
        if (!$('#ResponsiveNavigationHandle').length) {
            $('#NavigationContainer').closest('.ResponsiveSidebarContainer').before('<span class="ResponsiveHandle" id="ResponsiveNavigationHandle"><i class="fa fa-navicon"></i></span>');
        }
        if (!$('[id^="ResponsiveSidebarHandle"]').length) {
            var ResponsiveCount = 0;
            $.each($('.SidebarColumn'), function () {
                var ID =  'ResponsiveSidebarHandle_' + ResponsiveCount;

                if ( !ResponsiveCount ) {
                    ID = 'ResponsiveSidebarHandle';
                }
                if ( $(this).children().length ) {
                    $(this).closest('.ResponsiveSidebarContainer').before('<span id="' + ID + '" class="ResponsiveHandle"><i class="fa fa-caret-square-o-left"></i></span>');
                }
                ResponsiveCount++;
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
        $('[id^="ResponsiveSidebarHandle"]').off().on('click', function() {
            var $Element = $(this).next('.ResponsiveSidebarContainer').children('div');
            if (parseInt($Element.css('right'), 10) < 0) {
                $('#ResponsiveNavigationHandle').animate({
                    'left': '-45px'
                });
                if ( $(this).attr('id') !== 'ResponsiveSidebarHandle' ) {
                    $('#ResponsiveSidebarHandle').animate({
                        'right': '-45px'
                    });
                }
                $Element.closest('.ResponsiveSidebarContainer').fadeIn();
                $('html').addClass('NoScroll');
                $Element.animate({
                    'right': '0px'
                });
            }
            else {
                $('#ResponsiveNavigationHandle').animate({
                    'left': '15px'
                });
                if ( $(this).attr('id') !== 'ResponsiveSidebarHandle' ) {
                    $('#ResponsiveSidebarHandle').animate({
                        'right': '15px'
                    });
                }
                $Element.closest('.ResponsiveSidebarContainer').fadeOut();
                $('html').removeClass('NoScroll');
                $Element.animate({
                    'right': '-300px'
                });
            }
            return false;
        });
    });

    Core.App.Subscribe('Event.App.Responsive.ScreenXL', function () {
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

        // remove view mode switch
        $('#ViewModeSwitch').remove();

        $('#ResponsiveSidebarHandle').remove();

        // unwrap sidebar
        $('.ResponsiveSidebarContainer').children('#Navigation').unwrap();
        $.each($('.ResponsiveSidebarContainer > .SidebarColumn'), function() {
            if ( $(this).css('left') === '-300px' ) {
                $(this).css('left', '0px');
            } else if ( $(this).css('right') === '-300px' ) {
                $(this).css('right', '0px');
            }
            $(this).unwrap();
        });
    });

    return TargetNS;

}(Core.Customer.Responsive || {}));
