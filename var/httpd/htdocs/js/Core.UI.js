// --
// Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
// based on the original work of:
// Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};

/**
 * @namespace Core.UI
 * @memberof Core
 * @author OTRS AG
 * @description
 *      This namespace contains all UI functions.
 */
Core.UI = (function (TargetNS) {

    /**
     * @private
     * @name IDGeneratorCount
     * @memberof Core.UI
     * @member {Number}
     * @description
     *      Counter for automatic HTML element ID generation.
     */
    var IDGeneratorCount = 0;

    /**
     * @name InitWidgetActionToggle
     * @memberof Core.UI
     * @function
     * @description
     *      This function initializes the toggle mechanism for all widgets with a WidgetAction toggle icon.
     */
    TargetNS.InitWidgetActionToggle = function () {
        $(".WidgetAction.Toggle").each(function () {
            var $WidgetElement = $(this).closest("div.Header").parent('div'),
                ContentDivID   = TargetNS.GetID($WidgetElement.children('.Content'));

            // fallback to Expanded if default state was not given
            if (!$WidgetElement.hasClass('Expanded') && !$WidgetElement.hasClass('Collapsed')){
                $WidgetElement.addClass('Expanded');
            }

            $(this)
                .attr('aria-controls', ContentDivID)
                .attr('aria-expanded', $WidgetElement.hasClass('Expanded'))
                .closest("div.Header").children('h2').addClass('WithToggle');
        })
        .off('click.WidgetToggle')
        .on('click.WidgetToggle', function (Event) {
            var $WidgetElement = $(this).closest("div.Header").parent('div'),
                Animate        = $WidgetElement.hasClass('Animate'),
                $that          = $(this);

            function ToggleWidget() {
                $WidgetElement
                    .toggleClass('Collapsed')
                    .toggleClass('Expanded')
                    .end()
                    .end()
                    .attr('aria-expanded', $that.closest("div.Header").parent('div').hasClass('Expanded'));
                    Core.App.Publish('Event.UI.ToggleWidget', [$WidgetElement]);
            }

            if (Animate && Core.Config.Get('AnimationEnabled')) {
                $WidgetElement.addClass('AnimationRunning').find('.Content').slideToggle("fast", function () {
                    ToggleWidget();
                    $WidgetElement.removeClass('AnimationRunning');
                });
            } else {
                ToggleWidget();
            }

            Event.preventDefault();
            Event.stopPropagation();
        });
    };

    /**
     * @name InitWidgetActionTabToggle
     * @memberof Core.UI
     * @function
     * @description
     *      This function initializes the toggle mechanism for all widgets with a WidgetAction toggle icon in tabs.
     */
    TargetNS.InitWidgetActionTabToggle = function () {
        $("#ContentItemTabs .WidgetAction.Toggle").each(function () {
            var $WidgetElement = $(this).closest("div.Header").parent('div'),
                ContentDivID   = Core.UI.GetID($WidgetElement.children('.Content'));

            // fallback to Expanded if default state was not given
            if (!$WidgetElement.hasClass('Expanded') && !$WidgetElement.hasClass('Collapsed')){
                $WidgetElement.addClass('Expanded');
            }

            $(this)
                .attr('aria-controls', ContentDivID)
                .attr('aria-expanded', $WidgetElement.hasClass('Expanded'))
                .closest("div.Header").children('h2').addClass('WithToggle');
        })
        .off('click.WidgetToggle')
        .on('click.WidgetToggle', function () {
            var $WidgetElement = $(this).closest("div.Header").parent('div'),
                Animate        = $WidgetElement.hasClass('Animate'),
                $that          = $(this);

            function ToggleWidget() {
                $WidgetElement
                    .toggleClass('Collapsed')
                    .toggleClass('Expanded')
                    .end()
                    .end()
                    .attr('aria-expanded', $that.closest("div.Header").parent('div').hasClass('Expanded'));
                    Core.App.Publish('Event.UI.ToggleWidget', [$WidgetElement]);
            }

            if (Animate && Core.Config.Get('AnimationEnabled')) {
                $WidgetElement.addClass('AnimationRunning').find('.Content').slideToggle("fast", function () {
                    ToggleWidget();
                    $WidgetElement.removeClass('AnimationRunning');
                });
            } else {
                ToggleWidget();
            }

            return false;
        });
    }

    /**
     * @name InitMessageBoxClose
     * @memberof Core.UI
     * @function
     * @description
     *      This function initializes the close buttons for the message boxes that show server messages.
     */
    TargetNS.InitMessageBoxClose = function () {
        $(".MessageBox > a.Close")
            .off('click.MessageBoxClose')
            .on('click.MessageBoxClose', function (Event) {
                $(this).parent().fadeOut("slow");
                Core.Agent.PreferencesUpdate('UserAgentDoNotShowNotifiyMessage_' + $(this).parent('div').attr('id') , Core.Config.Get('SessionID'));
            });
    };

    /**
     * @name GetID
     * @memberof Core.UI
     * @function
     * @returns {String} ID of the element
     * @param {jQueryObject} $Element - The HTML element
     * @description
     *      Returns the ID of the Element and creates one for it if nessessary.
     */
    TargetNS.GetID = function ($Element) {
        var ID = $Element.attr('id');
        if (!ID) {
            $Element.attr('id', ID = 'Core_UI_AutogeneratedID_' + IDGeneratorCount++);
        }
        return ID;
    };

    /**
     * @name ToggleTwoContainer
     * @memberof Core.UI
     * @function
     * @param {jQueryObject} $Element1 - First container element.
     * @param {jQueryObject} $Element2 - Second container element.
     * @description
     *      This functions toggles two Containers with a nice slide effect.
     */
    TargetNS.ToggleTwoContainer = function ($Element1, $Element2) {
        if (isJQueryObject($Element1, $Element2) && $Element1.length && $Element2.length) {
            $Element1.slideToggle('fast', function () {
                $Element2.slideToggle('fast', function() {
                    Core.UI.InputFields.InitSelect($Element2.find('.Modernize'));
                });
                Core.UI.InputFields.InitSelect($Element1.find('.Modernize'));
            });
        }
    };

    /**
     * @name RegisterToggleTwoContainer
     * @memberof Core.UI
     * @function
     * @param {jQueryObject} $ClickedElement
     * @param {jQueryObject} $Element1 - First container element.
     * @param {jQueryObject} $Element2 - Second container element.
     * @description
     *      Registers click event to toggle the container.
     */
    TargetNS.RegisterToggleTwoContainer = function ($ClickedElement, $Element1, $Element2) {
        if (isJQueryObject($ClickedElement) && $ClickedElement.length) {
            $ClickedElement.click(function () {
                if ($Element1.is(':visible')) {
                    TargetNS.ToggleTwoContainer($Element1, $Element2);
                }
                else {
                    TargetNS.ToggleTwoContainer($Element2, $Element1);
                }
                return false;
            });
        }
    };

    /**
     * @name ScrollTo
     * @memberof Core.UI
     * @function
     * @param {jQueryObject} $Element
     * @description
     *      Scrolls the active window until an element is visible.
     */
    TargetNS.ScrollTo = function ($Element) {
        if (isJQueryObject($Element) && $Element.length) {
            window.scrollTo(0, $Element.offset().top);
        }
    };

    /**
     * @name InitCheckboxSelection
     * @memberof Core.UI
     * @function
     * @param {jQueryObject} $Element - The element selector which describes the element(s) which surround the checkboxes.
     * @description
     *      This function initializes a click event for tables / divs with checkboxes.
     *      If you click in the table cell / div around the checkbox the checkbox will be selected.
     *      A possible MasterAction will not be executed.
     */
    TargetNS.InitCheckboxSelection = function ($Element) {
        if (!$Element.length) {
            return;
        }

        // e.g. 'table td.Checkbox' or 'div.Checkbox'
        $Element.off('click.CheckboxSelection').on('click.CheckboxSelection', function (Event) {
            var $Checkbox = $(this).find('input[type="checkbox"]');

            if (!$Checkbox.length) {
                return;
            }

            if ($(Event.target).is('input[type="checkbox"]')) {
                return;
            }

            Event.stopPropagation();

            $Checkbox
                .prop('checked', !$Checkbox.prop('checked'))
                .triggerHandler('click');


        });
    };

    /**
     * @private
     * @name ShakeMe
     * @memberof Core.UI
     * @function
     * @param {jQueryObject} $id - The element to shake.
     * @param {Array} Position - Array of positions where the bo should be moved to.
     * @param {Number} PostionEnd - The end position.
     * @description
     *      "Shakes" the element.
     */
    function ShakeMe($id, Position, PostionEnd) {
        var PositionStart = Position.shift();
        $id.css('left', PositionStart + 'px');
        if (Position.length > 0) {
            setTimeout(function () {
                ShakeMe($id, Position, PostionEnd);
            }, PostionEnd);
        }
        else {
            try {
                $id.css('position', 'static');
            }
            catch (Event) {
                // no code here
                $.noop(Event);
            }
        }
    }

    /**
     * @name Shake
     * @memberof Core.UI
     * @function
     * @param {jQueryObject} $id - The element to shake.
     * @description
     *      "Shakes" the element.
     */
    TargetNS.Shake = function ($id) {
        var Position = [15, 30, 15, 0, -15, -30, -15, 0];
        Position = Position.concat(Position.concat(Position));
        $id.css('position', 'relative');
        ShakeMe($id, Position, 20);
    };

    return TargetNS;
}(Core.UI || {}));
