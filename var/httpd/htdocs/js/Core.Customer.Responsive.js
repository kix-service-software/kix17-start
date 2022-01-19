// --
// Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
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
        // This function is deactivated with KIX17.15.
        /*if (!$('#ViewModeSwitch').length) {
            $('#Footer').append('<div id="ViewModeSwitch"><a href="#">' + Core.Config.Get('ViewModeSwitchDesktop') + '</a></div>');
            $('#ViewModeSwitch a').on('click.Responsive', function() {
                localStorage.setItem("DesktopMode", 1);
                location.reload(true);
                return false;
            });
        }*/

        // wrap sidebar modules with an additional container
        $.each($('.SidebarColumn, #NavigationContainer'), function() {
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

                    return false;
                });
            }
        });

        // reset dialog container position
        if ( $('.Dialog.Fullsize').length ) {
            $('.Dialog.Fullsize').css({
                top: 0,
                left: 0
            });
        }
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

        // remove the additional container again
        $.each($('.ResponsiveSidebarContainer'), function() {
            var $Element = $(this).find('#NavigationContainer, .SidebarColumn');
            if ( $Element.hasClass('.SidebarColumn') ) {
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

        // reset dialog container position
        if ( $('.Dialog.Fullsize').length ) {
            $('.Dialog').removeClass('Fullsize').css({
                top: '10%',
                left: '30%'
            });
        }
    });

    return TargetNS;

}(Core.Customer.Responsive || {}));
