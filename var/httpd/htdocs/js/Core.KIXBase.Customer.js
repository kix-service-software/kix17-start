// --
// Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIXBase = Core.KIXBase || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIXBase.Customer
 * @description This namespace contains the special module functions for
 *              KIXBase
 */
Core.KIXBase.Customer = (function(TargetNS) {

    TargetNS.Init = function() {
        // move UserInfo and NavigationContainer to Header
        $('#UserInfo').detach().appendTo('#Header');
        $('#NavigationContainer').detach().appendTo('#Header');

        // handle switch button
        $('#SwitchButtonDummyContainer > li.Last').remove();
        $('#SwitchButtonDummyContainer > li > a').html('<i class="fa fa-exchange"></i>');
        $('#SwitchButtonDummyContainer > li > a').detach().insertBefore('#SwitchButtonDummyContainer');
        $('#SwitchButtonDummyContainer').remove();

        // move BottomActionRow into fieldset, but not in search dialog
        if ($('#BottomActionRow').parents('div#MainBox.Search').length == 0 ) {
            if ( !$('#CustomerIDSelection').length) {
                var $ButtonDiv = $('<div class="Field SpacingTop" style="margin-left: ' + $('form[name=compose] fieldset div label').width() + 'px"></div>');
                $('#BottomActionRow > button').css('margin-left', $('form[name=compose] fieldset div label').css('padding-right')).appendTo($ButtonDiv);
                $('form[name=compose] fieldset').parent().append($ButtonDiv);
                $('#BottomActionRow').remove();
            }
            else {
                $('#BottomActionRow > button').detach().appendTo('form[name=compose] fieldset');
                $('#BottomActionRow').remove();
            }
        }

        // add padding to WidgetSimple Header h2 and h3 if Toggle element exists before
        $('.WidgetSimple > .Header > h2, .WidgetSimple > .Header > h3, .VotingBox .MessageHeader h3').each(function () {
            if ($(this).parent('.Header').children().index($(this)) > 0 && $(this).parent('.Header').children('.Toggle').length == 1) {
                $(this).addClass('WithToggle');
            }

            // enclose text into span element for positioning (we have to check html() here, because otherwise it won't work in FAQ)
            if ($(this).html().length > 0 && !$(this).html().indexOf('<span') == 0) {
                $(this).html('<span>' + $(this).html() + '</span>');
            }
        });

        // add span to ZoomSidebar header
        $('#ZoomSidebar > #Metadata > .Header > div > h3').each(function () {

            // enclose text into span element for positioning (we have to check html() here, because otherwise it won't work in FAQ)
            if ($(this).html().length > 0 && !$(this).html().indexOf('<span') == 0) {
                $(this).html('<span>' + $(this).html() + '</span>');
            }
        });
        $('#Messages > li > .MessageHeader > h3').each(function () {

            // enclose text into span element for positioning (we have to check html() here, because otherwise it won't work in FAQ)
            if ($(this).html().length > 0 && !$(this).html().indexOf('<span') == 0) {
                $(this).html('<span>' + $(this).html() + '</span>');
            }
        });

        // move sidebar header to div
        var Counter = 0;

        $('#ZoomSidebar').find('ul').each(function(){
            // get header
            var HeaderContent = $(this).find('li.Header > .MessageHeader > h3').html();

            // insert div to contain header
            if ( Counter == 0 )
                $('#ZoomSidebar').before('<div class="WidgetSimple ZoomSidebarKIX" id="ZoomSidebarKIX_'+Counter+'"><div class="Header"><h2>'+HeaderContent+'</h2></div>');
            else
                $('#ZoomSidebar').before('<div class="WidgetSimple ZoomSidebarKIX" id="ZoomSidebarKIX_'+Counter+'"><div class="Header"><h2><span>'+HeaderContent+'</span></h2></div>');

            // insert div to contain fieldset
            $("#ZoomSidebarKIX_"+Counter).after('<div id="ZoomSidebar_'+Counter+'" class="ZoomSidebar"><div class="Content"><fieldset class="TableLike FixedLabelSmall" id="MetadataFieldset_'+Counter+'"></fieldset></div>');

            // remove old header content
            $(this).find('li.Header').remove();

            if ( Counter == 0 ) {
                $(this).find('li').each(function(){
                    if ($(this).hasClass('KeywordsContainer')) {
                        $('#MetadataFieldset_'+Counter).append('<label>'+$(this).find('span.Key').html()+'</label>');
                        $(this).find('span.Keyword').each(function(){
                           $('#MetadataFieldset_'+Counter).append('<p class="Value" title="'+$(this).text().trim()+'"><span>'+$(this).html()+'</span></p>');
                        });
                        $('#MetadataFieldset_'+Counter).append('<div class="Clear"></div>');
                    } else {
                        var Key             = $(this).find('span.Key').html(),
                            IsRatingLabel   = $(this).find('span.Key').hasClass('RatingLabel'),
                            NextValue       = $(this).find('span.Key').next(),
                            Value           = NextValue.html(),
                            Title           = Value;

                        if ( IsRatingLabel ) {
                            while ( NextValue.hasClass('RateStar') ) {
                                NextValue = NextValue.next();
                                Value = Value + NextValue.html();
                                Title = NextValue.html().trim();
                            }
                        }
                        $('#MetadataFieldset_'+Counter).append('<label>'+Key+'</label><p class="Value" title="'+Title+'"><span>'+Value+'</span></p><div class="Clear"></div>');
                    }
                    $(this).remove();
                });
            }
            else {
                $(this).find('li').each(function(){
                    var Value = $(this).html();
                    $('#MetadataFieldset_'+Counter).append(Value+'<div class="Clear"></div>');
                    $(this).remove();
                });
            }
            Counter++;
        });

        $('#ZoomSidebar').remove();
        $('.ErrorScreen .MessageBox').remove();
    }

    /**
     * @private
     * @name ToggleLabel
     * @memberof Core.KIXBase.Customer.js based upon Core.Customer.Login
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
     * @memberof Core.KIXBase.Customer.js based upon Core.Customer.Login
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
    TargetNS.CustomerLoginInit = function (Options) {
        var $Inputs = $('input:not(:checked, :hidden, :radio)'),
            $LocalInputs,
            Location,
            Now = new Date(),
            Diff = Now.getTimezoneOffset(),
            $Label,
            $SliderNavigationLinks = $('#Slider a');

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
            .bind('keyup change', function () {
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

        // detect the location ("SignUp", "Reset" or "Login"):
        // default location is "Login"
        Location = '#LoginBox';

        // check if the url contains an anchor
        if (document.location.toString().match('#')) {

            // cut out the anchor
            Location = '#' + document.location.toString().split('#')[1];
        }

        // get the input fields of the current location
        $LocalInputs = $(Location).find('input:not(:checked, :hidden, :radio)');

        // focus the first one
        $LocalInputs.first().focus();

        // add all tab-able inputs
        $LocalInputs.add($(Location + ' a, button'));

        // collect all global tab-able inputs
        // give the input fields of all other slides a negative 'tabindex' to prevent
        // the user from accidentally jumping to a hidden input field via the tab key
        $Inputs.add('a, button').not($LocalInputs).attr('tabindex', -1);

        // Change the 'tabindex' according to the navigation of the user
        $SliderNavigationLinks.click(function () {
            var I = 0,
                TargetID,
                $TargetInputs;

            TargetID = $(this).attr('href');

            // get the target id out of the href attribute of the anchor
            $TargetInputs = $(TargetID + ' input:not(:checked, :hidden, :radio), ' + TargetID + ' a, ' + TargetID + ' button');

            // give the inputs on the slide the user just leaves all a 'tabindex' of '-1'
            $(this).parentsUntil('#SlideArea').last().find('input:not(:checked, :hidden, :radio), a, button').attr('tabindex', -1);

            // give all inputs on the new shown slide an increasing 'tabindex'
            for (var I; I < $TargetInputs.length; I++) {
                $TargetInputs.eq(I).attr('tabindex', I + 1);
            }
        });

        // shake login box on authentication failure
        if (Options && Options.LastLoginFailed) {
            Core.UI.Shake($('#Login'));
        }
    }

    return TargetNS;
}(Core.KIXBase.Customer || {}));
