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
Core.Customer = Core.Customer || {};

/**
 * @namespace Core.Customer.Login
 * @memberof Core.Customer
 * @author OTRS AG
 * @description
 *      This namespace contains all functions for the Customer login.
 */
Core.Customer.Login = (function (TargetNS) {
    if (!Core.Debug.CheckDependency('Core.Customer.Login', 'Core.UI', 'Core.UI')) {
        return false;
    }

    /**
     * @private
     * @name ToggleLabel
     * @memberof Core.Customer.Login
     * @function
     * @param {DOMObject} PopulatedInput - DOM representation of an input field
     * @description
     *      This function hides the label of the given field if there is value in the field
     *      or the field has focus, otherwise the label is made visible.
     */
    function ToggleLabel(PopulatedInput) {
        var $PopulatedInput = $(PopulatedInput),
            $Label = $PopulatedInput.prev('label');

        if ($PopulatedInput.val() !== "" || $PopulatedInput[0] === document.activeElement) {
            $Label.hide();
        }
        else {
            $Label.show();
        }
    }

    /**
     * @name Init
     * @memberof Core.Customer.Login
     * @function
     * @returns {Boolean} False if browser is not supported
     * @param {Object} Options - Options, mainly passed through from the sysconfig
     * @description
     *      This function initializes the login functions.
     *      Time gets tracked in a hidden field.
     *      In the login we have four steps:
     *      1. input field gets focused -> label gets greyed out via class="Focused"
     *      2. something is typed -> label gets hidden
     *      3. user leaves input field -> if the field is blank the label gets shown again, 'focused' class gets removed
     *      4. first input field gets focused
     */
    TargetNS.Init = function (Options) {
        var $Inputs = $('input:not(:checked, :hidden, :radio)'),
            Now = new Date(),
            Diff = Now.getTimezoneOffset(),
            $Label;

        // Browser is too old
        if (!Core.Customer.SupportedBrowser) {
            $('#Login').hide();
            $('#Reset').hide();
            $('#Signup').hide();
            $('#PreLogin').hide();
            $('#OldBrowser').show();
            return false;
        }

        // enable login form
        Core.Form.EnableForm($('#Login form, #Reset form, #Signup form'));

        $('#TimeOffset').val(Diff);

        if ($('#PreLogin').length) {
            $('#PreLogin form').submit();
            return false;
        }

        $Inputs
            .focus(function () {
                $Label = $(this).prev('label');
                $(this).prev('label').addClass('Focused');
                if ($(this).val()) {
                    $Label.hide();
                }
            })
            .on('keyup change', function () {
                ToggleLabel(this);
            })
            .blur(function () {
                $Label = $(this).prev('label');
                if (!$(this).val()) {
                    $Label.show();
                }
                $Label.removeClass('Focused');
            });

         $('#User').blur(function () {
            if ($(this).val()) {
                // set the username-value and hide the field's label
                $('#ResetUser').val('').prev('label').hide();
            }
         });

         // check labels every 250ms, not all changes can be caught via
         //     events (e. g. when the user selects a predefined value
         //     from a browser auto completion list).
         window.setInterval(function(){
             $.each($Inputs, function(Index, Input) {
                 if($(Input).val()){
                     ToggleLabel(Input);
                 }
             });
         }, 250);

        // Fill the reset-password input field with the same value the user types in the login screen
        // so that the user doesnt have to type in his user name again if he already did
        $('#User').blur(function () {
            if ($(this).val()) {
                // clear the username-value and hide the field's label
                $('#ResetUser').val($(this).val()).prev('label').hide();
            }
        });

        // shake login box on authentication failure
        if (Options && Options.LastLoginFailed) {
            Core.UI.Shake($('#Login'));
        }
    };

    return TargetNS;
}(Core.Customer.Login || {}));
