// --
// Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
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
 * @namespace Core.Customer
 * @memberof Core
 * @author OTRS AG
 * @description
 *      This namespace contains all global functions for the customer interface.
 */
Core.Customer = (function (TargetNS) {
    if (!Core.Debug.CheckDependency('Core.Customer', 'Core.UI', 'Core.UI')) {
        return false;
    }
    if (!Core.Debug.CheckDependency('Core.Customer', 'Core.Form', 'Core.Form')) {
        return false;
    }
    if (!Core.Debug.CheckDependency('Core.Customer', 'Core.Form.Validate', 'Core.Form.Validate')) {
        return false;
    }
    if (!Core.Debug.CheckDependency('Core.Customer', 'Core.UI.Accessibility', 'Core.UI.Accessibility')) {
        return false;
    }
    if (!Core.Debug.CheckDependency('Core.Agent', 'Core.UI.InputFields', 'Core.UI.InputFields')) {
        return false;
    }

    /**
     * @private
     * @name InitNavigation
     * @memberof Core.Customer
     * @function
     * @description
     *      This function initializes the main navigation.
     */
    function InitNavigation() {
        /*
         * private variables for navigation
         */
        var NavigationTimer = {},
            NavigationDuration = 500,
            NavigationHoverTimer = {},
            NavigationHoverDuration = 350,
            InitialNavigationContainerHeight = $('#NavigationContainer').css('height');

        /**
         * @private
         * @name CreateSubnavCloseTimeout
         * @memberof Core.Customer.InitNavigation
         * @function
         * @param {jQueryObject} $Element
         * @param {Function} TimeoutFunction
         * @description
         *      This function sets the Timeout for closing a subnav.
         */
        function CreateSubnavCloseTimeout($Element, TimeoutFunction) {
            NavigationTimer[$Element.attr('id')] = setTimeout(TimeoutFunction, NavigationDuration);
        }

        /**
         * @private
         * @name ClearSubnavCloseTimeout
         * @memberof Core.Customer.InitNavigation
         * @function
         * @param {jQueryObject} $Element
         * @description
         *      This function clears the Timeout for a subnav.
         */
        function ClearSubnavCloseTimeout($Element) {
            if (typeof NavigationTimer[$Element.attr('id')] !== 'undefined') {
                clearTimeout(NavigationTimer[$Element.attr('id')]);
            }
        }

        /**
         * @private
         * @name CreateSubnavOpenTimeout
         * @memberof Core.Customer.InitNavigation
         * @function
         * @param {jQueryObject} $Element
         * @param {Function} TimeoutFunction
         * @description
         *      This function sets the Timeout for closing a subnav.
         */
        function CreateSubnavOpenTimeout($Element, TimeoutFunction) {
            NavigationHoverTimer[$Element.attr('id')] = setTimeout(TimeoutFunction, NavigationHoverDuration);
        }

        /**
         * @private
         * @name ClearSubnavOpenTimeout
         * @memberof Core.Customer.InitNavigation
         * @function
         * @param {jQueryObject} $Element
         * @description
         *      This function clears the Timeout for a subnav.
         */
        function ClearSubnavOpenTimeout($Element) {
            if (typeof NavigationHoverTimer[$Element.attr('id')] !== 'undefined') {
                clearTimeout(NavigationHoverTimer[$Element.attr('id')]);
            }
        }

        /**
         * @private
         * @name SetNavContainerHeight
         * @memberof Core.Customer.InitNavigation
         * @function
         * @param {jQueryObject} $ParentElement
         * @description
         *      This function sets the nav container height according to the required height of the currently expanded sub menu
         *      Due to the needed overflow: hidden property of the container, they would be hidden otherwise
         */
        function SetNavContainerHeight($ParentElement) {
            if ($ParentElement.find('ul').length) {
                $('#NavigationContainer').css('height', parseInt(InitialNavigationContainerHeight, 10) + parseInt($ParentElement.find('ul').outerHeight(), 10));
            }
        }

        $('#Navigation > li')
            .filter(function () {
                return $('ul', this).length;
            })
            .on('mouseenter', function () {
                var $Element = $(this);

                // clear close timeout on mouseenter, even if OpenMainMenuOnHover is not enabled
                // this makes sure, that leaving the subnav for a short time and coming back
                // will leave the subnav opened
                ClearSubnavCloseTimeout($Element);

                // special treatment for the first menu level: by default this opens submenus only via click,
                //  but the config setting "OpenMainMenuOnHover" also activates opening on hover for it.
                if (
                    $('body').hasClass('Visible-ScreenXL')
                    && !Core.App.Responsive.IsTouchDevice()
                    && (
                        $Element.parent().attr('id') !== 'Navigation'
                        || Core.Config.Get('OpenMainMenuOnHover')
                    )
                ) {

                    // Set Timeout for opening nav
                    CreateSubnavOpenTimeout($Element, function () {
                        $Element.addClass('Active').attr('aria-expanded', true)
                            .siblings().removeClass('Active');

                        // resize the nav container
                        SetNavContainerHeight($Element);

                        // If Timeout is set for this nav element, clear it
                        ClearSubnavCloseTimeout($Element);
                    });
                }
            })
            .on('mouseleave', function () {

                var $Element = $(this);

                if ($('body').hasClass('Visible-ScreenXL')) {

                    // Clear Timeout for opening items on hover. Submenus should only be opened intentional,
                    // so if the user doesn't hover long enough, he probably doesn't want the submenu to be opened.
                    // If Timeout is set for this nav element, clear it
                    ClearSubnavOpenTimeout($Element);

                    if (!$Element.hasClass('Active')) {
                        return false;
                    }

                    // Set Timeout for closing nav
                    CreateSubnavCloseTimeout($Element, function () {
                        $Element.removeClass('Active').attr('aria-expanded', false);
                        if (!$('#Navigation > li.Active').length) {
                            $('#NavigationContainer').css('height', InitialNavigationContainerHeight);
                        }
                    });
                }
            })
            .on('click', function (Event) {

                var $Element = $(this),
                    $Target = $(Event.target);

                // if an onclick attribute is present, the attribute should win
                if ($Target.attr('onclick')) {
                    return false;
                }

                // if OpenMainMenuOnHover is enabled, clicking the item
                // should lead to the link as regular
                if ($('body').hasClass('Visible-ScreenXL') && !Core.App.Responsive.IsTouchDevice() && Core.Config.Get('OpenMainMenuOnHover')) {
                    return true;
                }

                // ddoerffel - business code removed

                // Workaround for Windows Phone IE
                // In Windows Phone IE the event does not bubble up like in other browsers
                // That means that a subnavigation in mobile mode is still collapsed/expanded,
                // although the link to the new page is clicked
                // we force the redirect with this workaround
                if (navigator && navigator.userAgent && navigator.userAgent.match(/Windows Phone/i) && $Target.closest('ul').attr('id') !== 'Navigation') {
                    window.location.href = $Target.closest('a').attr('href');
                    Event.stopPropagation();
                    Event.preventDefault();
                    return true;
                }

                if ($Element.hasClass('Active')) {
                    $Element.removeClass('Active').attr('aria-expanded', false);

                    if ($('body').hasClass('Visible-ScreenXL')) {
                        // restore initial container height
                        $('#NavigationContainer').css('height', InitialNavigationContainerHeight);
                    }
                }
                else {
                    $Element.addClass('Active').attr('aria-expanded', true)
                        .siblings().removeClass('Active');

                    if ($('body').hasClass('Visible-ScreenXL')) {

                        // resize the nav container
                        SetNavContainerHeight($Element);

                        // If Timeout is set for this nav element, clear it
                        ClearSubnavCloseTimeout($Element);
                    }
                }

                // If element has subnavigation, prevent the link
                if ($Target.closest('li').find('ul').length) {
                    Event.preventDefault();
                    Event.stopPropagation();
                    return false;
                }
            })
            /*
             * Accessibility support code
             *      Initialize each <li> with subnavigation with aria-controls and
             *      aria expanded to indicate what will be opened by that element.
             */
            .each(function () {
                var $Li = $(this),
                    ARIAControlsID = $Li.children('ul').attr('id');

                if (ARIAControlsID && ARIAControlsID.length) {
                    $Li.attr('aria-controls', ARIAControlsID).attr('aria-expanded', false);
                }
            });

            // disable sortable on smaller screens
            Core.App.Subscribe('Event.App.Responsive.SmallerOrEqualScreenL', function () {
                if ($('#Navigation').sortable("instance")) {
                    $('#Navigation').sortable("destroy");
                    $('#NavigationContainer').css('height', '100%');
                }
            });
        /*
         * The navigation elements don't have a class "ARIAHasPopup" which automatically generates the aria-haspopup attribute,
         * because of some code limitation while generating the nav data.
         * Therefore, the aria-haspopup attribute for the navigation is generated manually.
         */
        $('#Navigation li').filter(function () {
            return $('ul', this).length;
        }).attr('aria-haspopup', 'true');

    }

    /**
     * @name SupportedBrowser
     * @memberof Core.Customer
     * @member {Boolean}
     * @description
     *     Indicates a supported browser.
     */
    TargetNS.SupportedBrowser = true;

    /**
     * @name IECompatibilityMode
     * @memberof Core.Customer
     * @member {Boolean}
     * @description
     *     IE Compatibility Mode is active.
     */
    TargetNS.IECompatibilityMode = false;

    /**
     * @name Init
     * @memberof Core.Customer
     * @function
     * @description
     *      This function initializes the application and executes the needed functions.
     */
    TargetNS.Init = function () {
        TargetNS.SupportedBrowser = Core.App.BrowserCheck('Customer');
        TargetNS.IECompatibilityMode = Core.App.BrowserCheckIECompatibilityMode();

        if (TargetNS.IECompatibilityMode) {
            TargetNS.SupportedBrowser = false;
            alert(Core.Config.Get('TurnOffCompatibilityModeMsg'));
        }

        if (!TargetNS.SupportedBrowser) {
            alert(
                Core.Config.Get('BrowserTooOldMsg')
                + ' '
                + Core.Config.Get('BrowserListMsg')
                + ' '
                + Core.Config.Get('BrowserDocumentationMsg')
            );
        }

        InitNavigation();
        Core.Exception.Init();

        Core.Form.Validate.Init();
        Core.UI.Popup.Init();

        // late execution of accessibility code
        Core.UI.Accessibility.Init();

        // Modernize input fields
        Core.UI.InputFields.Init();

        // Init tree selection/tree view for dynamic fields
        Core.UI.TreeSelection.InitTreeSelection();
        Core.UI.TreeSelection.InitDynamicFieldTreeViewRestore();

        // unveil full error details only on click
        $('.TriggerFullErrorDetails').on('click', function() {
            $('.Content.ErrorDetails').toggle();
        });

        // added class FieldPlain on field container if not empty but has no subelements
        if ( $('.Field').length ) {
            $.each($('.Field:not(:has(*))'), function() {
                if ( !$(this).is(':empty') ) {
                    $(this).addClass('FieldPlain');
                }
            });
            $.each($('.Field:has(*)'), function() {
                var Empty = 1;
                if (
                    $(this).hasClass('Hidden')
                    || $(this).hasClass('Options')
                ) {
                        return false;
                }
                $.each($(this).children(), function() {
                    if (
                        (
                            $(this).is(':input')
                            || $(this).hasClass('InputField_Container')
                            || $(this).find('#AttachmentUpload').length
                        )
                        && $(this).css('display') != 'none'
                    ) {
                        Empty = 0;
                        return false;
                    }
                });
                if ( Empty ) {
                    $(this).addClass('FieldPlain');
                }
                else {
                    $(this).removeClass('FieldPlain');
                }
            });
        }
    };

    /**
     * @name PreferencesUpdate
     * @memberof Core.Customer
     * @function
     * @returns {Boolean} returns true.
     * @param {jQueryObject} Key - The name of the setting.
     * @param {jQueryObject} Value - The value of the setting.
     * @description
     *      This function sets session and preferences setting at runtime.
     */
    TargetNS.PreferencesUpdate = function (Key, Value) {
        var URL = Core.Config.Get('Baselink'),
            Data = {
                Action: 'CustomerPreferences',
                Subaction: 'UpdateAJAX',
                Key: Key,
                Value: Value
            };
        // We need no callback here, but the called function needs one, so we send an "empty" function
        Core.AJAX.FunctionCall(URL, Data, $.noop);
        return true;
    };

    /**
     * @name ClickableRow
     * @memberof Core.Customer
     * @function
     * @description
     *      This function makes the whole row in the MyTickets and CompanyTickets view clickable.
     */
    TargetNS.ClickableRow = function(){
        $("table tr").click(function(){
            window.location.href = $("a", this).attr("href");
            return false;
        });
    };

    /**
     * @name Enhance
     * @memberof Core.Customer
     * @function
     * @description
     *      This function adds the class 'JavaScriptAvailable' to the 'Body' div to enhance the interface (clickable rows).
     */
    TargetNS.Enhance = function(){
        $('body').removeClass('NoJavaScript').addClass('JavaScriptAvailable');
    };

    return TargetNS;
}(Core.Customer || {}));
