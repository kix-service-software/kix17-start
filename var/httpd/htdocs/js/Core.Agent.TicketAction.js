// --
// Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
// based on the original work of:
// Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.TicketAction
 * @memberof Core.Agent
 * @author OTRS AG
 * @description
 *      This namespace contains functions for all ticket action popups.
 */
Core.Agent.TicketAction = (function (TargetNS) {

    /**
     * @private
     * @name SerializeData
     * @memberof Core.Agent.TicketAction
     * @function
     * @returns {String} A query string based on the given hash.
     * @param {Object} Data - The data that should be serialized
     * @description
     *      Converts a given hash into a query string.
     */
    function SerializeData(Data) {
        var QueryString = '';
        $.each(Data, function (Key, Value) {
            QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });
        return QueryString;
    }

    /**
     * @private
     * @name OpenAddressBook
     * @memberof Core.Agent.TicketAction
     * @function
     * @description
     *      Open the AddressBook screen.
     */
    function OpenAddressBook() {
        var AddressBookIFrameURL, AddressBookIFrame;
        AddressBookIFrameURL = Core.Config.Get('CGIHandle') +
            '?Action=AgentBook;ToCustomer=' + encodeURIComponent($('#CustomerAutoComplete, #ToCustomer').val()) +
            ';CcCustomer=' + encodeURIComponent($('#Cc, #CcCustomer').val()) +
            ';BccCustomer=' + encodeURIComponent($('#Bcc, #BccCustomer').val());
        AddressBookIFrameURL += SerializeData(Core.App.GetSessionInformation());
        AddressBookIFrame = '<iframe class="TextOption" src="' + AddressBookIFrameURL + '"></iframe>';
        Core.UI.Dialog.ShowContentDialog(AddressBookIFrame, '', '10px', 'Center', true);
    }

    /**
     * @private
     * @name GetSize
     * @memberof Core.Agent.TicketAction
     * @function
     * @description
     *      Get new width and height for the iframe.
     */
    function GetSize() {
        var wWidth      = $(window).width(),
            wHeight     = $(window).height(),
            wScrollTop  = $(window).scrollTop(),
            wScrollLeft = $(window).scrollLeft(),
            dHeight     = wHeight - ((10 - wScrollTop) * 2) - 100,
            dWidth      = wWidth - ((10 - wScrollLeft) * 2) - 100;

        return {
            width: dWidth,
            height: dHeight
        };
    }

    /**
     * @private
     * @name OpenCustomerDialog
     * @memberof Core.Agent.TicketAction
     * @function
     * @description
     *      Open the CustomerDialog screen.
     */
    function OpenCustomerDialog() {
        var CustomerIFrameURL,
            CustomerIFrame,
            data = GetSize();

        CustomerIFrameURL = Core.Config.Get('CGIHandle') + '?Action=AdminCustomerUser;Nav=None;';
        CustomerIFrameURL += SerializeData(Core.App.GetSessionInformation());

        CustomerIFrame = '<iframe id="OptionCustomerIframe" width="' + data.width + '" height="' + data.height + '" src="' + CustomerIFrameURL + '"></iframe>';
        Core.UI.Dialog.ShowContentDialog(CustomerIFrame, '', '10px', 'Center', true, []);
    }

    /**
     * @private
     * @name AddMailAddress
     * @memberof Core.Agent.TicketAction
     * @function
     * @param {Object} $Link - Element link type that will receive the new email adrress in its value attribute
     * @description
     *      Add email address.
     */
    function AddMailAddress($Link) {
        var $Element = $('#' + $Link.attr('rel')),
            NewValue = $Element.val(), NewData, NewDataItem, Length;

        if (NewValue.length) {
            NewValue = NewValue + ', ';
        }
        NewValue = NewValue +
            Core.Data.Get($Link.closest('tr'), 'Email')
            .replace(/&quot;/g, '"')
            .replace(/&lt;/g, '<')
            .replace(/&gt;/g, '>');
        $Element.val(NewValue);

        Length = $Element.val().length;
        $Element.focus();
        $Element[0].setSelectionRange(Length, Length);

        // set customer data for customer user information (AgentTicketEmail) in the compose screen
        if ($Link.attr('rel') === 'ToCustomer' && Core.Config.Get('CustomerInfoSet')){

            NewData = $('#CustomerData').val();
            NewDataItem = Core.Data.Get($Link.closest('a'), 'customerdatajson');

            if(NewData){
                NewData = Core.JSON.Parse(NewData);
                $.each(NewDataItem, function(CustomerMail, CustomerKey) {
                    NewData[CustomerMail] = CustomerKey;
                });
                $('#CustomerData').val(Core.JSON.Stringify(NewData));
            }
            else
            {
                $('#CustomerData').val(Core.JSON.Stringify(NewDataItem));
            }
        }
    }

    /**
     * @private
     * @name MarkPrimaryCustomer
     * @memberof Core.Agent.TicketAction
     * @function
     * @description
     *      Mark the primary customer.
     */
    function MarkPrimaryCustomer() {
        $('.CustomerContainer').children('div').each(function() {
            var $InputObj = $(this).find('.CustomerTicketText'),
                $RadioObj = $(this).find('.CustomerTicketRadio');

            if ($RadioObj.prop('checked')) {
                $InputObj.addClass('MainCustomer');
            }
            else {
                $InputObj.removeClass('MainCustomer');
            }
        });
    }

    /**
     * @name Init
     * @memberof Core.Agent.TicketAction
     * @function
     * @description
     *      This function initializes the ticket action popups.
     */
    TargetNS.Init = function () {

        // Register event for addressbook dialog
        $('#OptionAddressBook').on('click', function () {
            OpenAddressBook();
            return false;
        });

        // Register event for customer dialog
        $('#OptionCustomer').on('click', function () {
            OpenCustomerDialog();
            return false;
        });

        $(window).on('resize',function() {
            if (
                $('#OptionCustomerIframe').length
                && !$('.Dialog:visible').hasClass('Fullsize')
            ) {
                var data      = GetSize(),
                    ScrollTop = $(window).scrollTop();
                $('#OptionCustomerIframe').width(data.width);
                $('#OptionCustomerIframe').height(data.height);

                $('.Dialog:visible').css({
                    top: (10 + ScrollTop) + 'px',
                    left: Math.round(($(window).width() - $('.Dialog:visible').width()) / 2) + 'px'
                });
            }
        });

        // Subscribe to the reloading of the CustomerInfo box to
        // specially mark the primary customer
        MarkPrimaryCustomer();
        Core.App.Subscribe('Event.Agent.CustomerSearch.GetCustomerInfo.Callback', function() {
            MarkPrimaryCustomer();
        });

        // Prevent form submit, if To, CC or Bcc are not correctly saved yet
        // see http://bugs.otrs.org/show_bug.cgi?id=10022 for details
        $('#submitRichText').on('click', function (Event) {
            var ToCustomer = $('#ToCustomer').val() || '',
                CcCustomer = $('#CcCustomer').val() || '',
                BccCustomer = $('#BccCustomer').val() || '',
                // only for AgentTicketPhone
                FromCustomer = $('#FromCustomer').val() || '';

            if (ToCustomer.length || CcCustomer.length || BccCustomer.length || FromCustomer.length) {
                window.setTimeout(function () {
                    $('#submitRichText').trigger('click');
                }, 100);
                Event.preventDefault();
                Event.stopPropagation();
                return false;
            }
        });

        // Subscribe to ToggleWidget event to handle special behaviour in ticket action screens
        Core.App.Subscribe('Event.UI.ToggleWidget', function ($WidgetElement) {
            if ($WidgetElement.attr('id') !== 'WidgetArticle') {
                return;
            }

            if ($WidgetElement.hasClass('Expanded')) {
                // if widget is being opened, add checbkox to create article
                $('#CreateArticle').prop('checked', true);
            }
        });
    };

    /**
     * @name InitAddressBook
     * @memberof Core.Agent.TicketAction
     * @function
     * @description
     *      This function initializes the necessary stuff for address book link in TicketAction screens.
     */
    TargetNS.InitAddressBook = function () {
        // Register event for copying mail address to input field
        $('#SearchResult a').on('click', function () {
            AddMailAddress($(this));
            return false;
        });

        // Register Apply button event
        $('#Apply').on('click', function () {
            // Update ticket action popup fields
            var $To, $Cc, $Bcc, CustomerData;

            // Because we are in an iframe, we need to call the parent frames javascript function
            // with a jQuery object which is in the parent frames context

            // check if the multi selection feature is present
            if ($('#CustomerAutoComplete', parent.document).length) {
                // no multi select (AgentTicketForward)
                $To = $('#CustomerAutoComplete', parent.document);
                $Cc = $('#Cc', parent.document);
                $Bcc = $('#Bcc', parent.document);

                $To.val($('#ToCustomer').val());
                $Cc.val($('#CcCustomer').val());
                $Bcc.val($('#BccCustomer').val());
            }
            else {
                // multi select is present
                $To = $('#ToCustomer', parent.document);
                $Cc = $('#CcCustomer', parent.document);
                $Bcc = $('#BccCustomer', parent.document);

                // check is set customer data for customer user information
                // it will not be set if it is used CustomerAutoComplete ( e.g for forwrad, reply ticket )
                if ($('#CustomerData').val()) {
                    CustomerData = Core.JSON.Parse($('#CustomerData').val());
                    $.each(CustomerData, function(CustomerMail, CustomerKey) {
                        $To.val(CustomerMail);
                        parent.Core.Agent.CustomerSearch.AddTicketCustomer('ToCustomer', CustomerMail, CustomerKey);

                    });
                }
                else{
                    $.each($('#ToCustomer').val().split(/, ?/), function(Index, Value){
                        $To.val(Value);
                        parent.Core.Agent.CustomerSearch.AddTicketCustomer('ToCustomer', Value);
                    });
                }

                $.each($('#CcCustomer').val().split(/, ?/), function(Index, Value){
                    $Cc.val(Value);
                    parent.Core.Agent.CustomerSearch.AddTicketCustomer('CcCustomer', Value);
                });

                $.each($('#BccCustomer').val().split(/, ?/), function(Index, Value){
                    $Bcc.val(Value);
                    parent.Core.Agent.CustomerSearch.AddTicketCustomer('BccCustomer', Value);
                });
            }

            parent.Core.UI.Dialog.CloseDialog($('.Dialog', parent.document));
        });

        // Register Cancel button event
        $('#Cancel').on('click', function () {
            // Because we are in an iframe, we need to call the parent frames javascript function
            // with a jQuery object which is in the parent frames context
            parent.Core.UI.Dialog.CloseDialog($('.Dialog', parent.document));
        });
    };

    /**
     * @name UpdateCustomer
     * @memberof Core.Agent.TicketAction
     * @function
     * @param {String} Customer - The customer that was selected in the customer popup window.
     * @description
     *      In some screens, the customer management dialog can be used as a borrowed view
     *      (iframe in a dialog). This function is used to take over the currently selected
     *      customer into the main window, closing the dialog.
     */
    TargetNS.UpdateCustomer = function (Customer) {
        var $UpdateForm = $('form[name=compose]', parent.document);
        $UpdateForm
            .find('#ExpandCustomerName').val('2')
            .end()
            .find('#PreSelectedCustomerUser').val(Customer)
            .end()
            .submit();

        // Because we are in an iframe, we need to call the parent frames javascript function
        // with a jQuery object which is in the parent frames context
        parent.Core.UI.Dialog.CloseDialog($('.Dialog', parent.document));
    };

    /**
     * @name SelectRadioButton
     * @memberof Core.Agent.TicketAction
     * @function
     * @param {String} Value - The value attribute of the radio button to be selected.
     * @param {String} Name - The name of the radio button to be selected.
     * @description
     *      Selects a radio button by name and value.
     */
    TargetNS.SelectRadioButton = function (Value, Name) {
        $('input[type="radio"][name=' + Name + '][value=' + Value + ']').prop('checked', true);
    };

    /**
     * @name ConfirmTemplateOverwrite
     * @memberof Core.Agent.TicketAction
     * @function
     * @param {String} FieldName - The ID of the content field (textarea or RTE). ID without selector (#).
     * @param {jQueryObject} $TemplateSelect - Selector of the dropdown element for the template selection.
     * @param {Function} Callback - Callback function to execute if overwriting is confirmed.
     * @description
     *      After a template was selected, this function lets the user confirm that all already existing content
     *      in the textarea or RTE will be overwritten with the template content.
     */
    TargetNS.ConfirmTemplateOverwrite = function (FieldName, $TemplateSelect, Callback) {
        var Content = '',
            LastValue = $TemplateSelect.data('LastValue') || '';

        // Fallback for non-richtext content
        Content = $('#' + FieldName).val();

        // get RTE content
        if (typeof CKEDITOR !== 'undefined' && CKEDITOR.instances[FieldName]) {
            Content = CKEDITOR.instances[FieldName].getData();
        }

        // if content already exists let user confirm to really overwrite that content with a template
        if (
            Content.length &&
            !window.confirm(Core.Config.Get('TicketActionTemplateOverwrite') + ' ' + Core.Config.Get('TicketActionTemplateOverwriteConfirm')))
            {
                // if user cancels confirmation, reset template selection
                $TemplateSelect.val(LastValue).trigger('redraw');

        }
        else if ($.isFunction(Callback)) {
            Callback();
            $TemplateSelect.data('LastValue', $TemplateSelect.val());
        }
    }

    return TargetNS;
}(Core.Agent.TicketAction || {}));
