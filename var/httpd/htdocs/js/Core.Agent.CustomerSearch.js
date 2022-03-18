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
Core.Agent = Core.Agent || {};

/**
 * @namespace Core.Agent.CustomerSearch
 * @memberof Core.Agent
 * @author OTRS AG
 * @description
 *      This namespace contains the special module functions for the customer search.
 */
Core.Agent.CustomerSearch = (function (TargetNS) {
    /**
     * @private
     * @name BackupData
     * @memberof Core.Agent.CustomerSearch
     * @member {Object}
     * @description
     *      Saves Customer data for later restore.
     */
    var BackupData = {
            CustomerInfo: '',
            CustomerEmail: '',
            CustomerKey: ''
        },
    /**
     * @private
     * @name CustomerFieldChangeRunCount
     * @memberof Core.Agent.CustomerSearch
     * @member {Object}
     * @description
     *      Needed for the change event of customer fields, if ActiveAutoComplete is false (disabled).
     */
        CustomerFieldChangeRunCount = {};

    /**
     * @name ExistsCustomerUser
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {String} UserID
     * @description
     *      This function check if exists a customer user to this agent.
     */
    function ExistsCustomerUser(UserID) {
        var Data = {
                Action: 'AgentCustomerSearch',
                Subaction: 'ExistsCustomerUser',
                UserID: UserID,
            },
            Customer = 0;

        Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function (Response) {
            if (!$.isEmptyObject(Response.Customer)) {
                Customer = 1;
            }
        },'',false);

        return Customer;
    }

    /**
     * @private
     * @name GetUserInfo
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {String} UserID
     * @param {String} CallingAction
     * @description
     *      This function gets user data for customer info table.
     */
    function GetUserInfo(UserID, CallingAction) {
        var MagnifierString = '<i class="fa fa-search"></i>',
            Async = true,
            Data = {
                Action: 'AgentCustomerSearch',
                Subaction: 'UserInfo',
                UserID: UserID,
                CallingAction : CallingAction || ''
            };

        if ( CallingAction == 'AgentTicketZoomTabArticle' ) {
            Async = false;
        }

        // get ticket ID for customer info sidebar (for possible links in user attributes)
        if ( CallingAction == 'AgentKIXSidebarCustomerInfo' ) {
            Data.TicketID = $('input[name="TicketID"]').val();
        }

        Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function (Response) {
            // Publish information for subscribers
            Core.App.Publish('Event.Agent.UserSearch.GetCustomerInfo.Callback', [Response.UserID]);

            // show customer info
            $('#CustomerInfo .Content').html(Response.UserTableHTMLString);

            Core.KIXBase.Agent.AutoToggleSidebars();
        },'',Async);
    }

    /**
     * @private
     * @name GetCustomerInfo
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {String} CustomerUserID
     * @description
     *      This function gets customer data for customer info table.
     */
    function GetCustomerInfo(CustomerUserID, CustomerID, CallingAction) {
        var MagnifierString = '<i class="fa fa-search"></i>',
            Async             = true,
            Data              = {
                Action:         'AgentCustomerSearch',
                Subaction:      'CustomerInfo',
                CustomerUserID: CustomerUserID,
                CustomerID:     CustomerID,
                CallingAction : CallingAction || ''
            };

        if ( CallingAction == 'AgentTicketZoomTabArticle' ) {
            Async = false;
        }
        // get ticket ID for customer info sidebar (for possible links in customer attributes)
        if ( CallingAction == 'AgentKIXSidebarCustomerInfo' ) {
            Data.TicketID = $('input[name="TicketID"]').val();
        }

        Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function (Response) {
            // set CustomerID
            if (Response.CustomerID !== '') {
                $('#CustomerID').val(Response.CustomerID);
                $('#ShowCustomerID').html(Response.CustomerID);
            }
            else {
                $('#CustomerID').val(CustomerUserID);
                $('#ShowCustomerID').html(CustomerUserID);
            }

            // show customer info
            $('#CustomerInfo .Content').html(Response.CustomerTableHTMLString);

            // insert magnifier again
            if (MagnifierString != '') {
                $('#CustomerInfo .Content').prepend('<span class="CustomerDetailsMagnifier">' + MagnifierString + '</span>');
            }

            // bind click to popup customer details
            Core.KIX4OTRS.CustomerDetails.Init();
            // fill detail popup content
            $('#CustomerInfo .WidgetPopup .Content').html(Response.CustomerDetailsTableHTMLString);

            // only execute this part, if service selection is combined with customer selection and keep selected service
            if (CallingAction != 'AgentKIXSidebarCustomerInfo' && $('#ServiceID').length) {
                Core.AJAX.FormUpdate($('#CustomerID').closest('form'), 'AJAXUpdate', 'ServiceID', [ 'Dest', 'SelectedCustomerUser', 'TypeID', 'NewUserID', 'NewResponsibleID', 'NextStateID', 'PriorityID', 'SLAID', 'CryptKeyID', 'OwnerAll', 'ResponsibleAll' ]);
            }

            if (Core.Config.Get('Action') === 'AgentTicketProcess'){
                // reset service
                $('#ServiceID').attr('selectedIndex', 0);
                // update services (trigger ServiceID change event)
                Core.AJAX.FormUpdate($('#CustomerID').closest('form'), 'AJAXUpdate', 'ServiceID', Core.Config.Get('ProcessManagement.UpdatableFields'));
            }

            // Publish information for subscribers
            Core.App.Publish('Event.Agent.CustomerSearch.GetCustomerInfo.Callback', [Response.CustomerID]);

            Core.KIXBase.Agent.AutoToggleSidebars();
        },'',Async);
    }

    /**
     * @private
     * @name GetCustomerTickets
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {String} CustomerUserID
     * @param {String} CustomerID
     * @description
     *      This function gets customer tickets.
     */
    function GetCustomerTickets(CustomerUserID, CustomerID) {

        var Data = {
            Action: 'AgentCustomerSearch',
            Subaction: 'CustomerTickets',
            CustomerUserID: CustomerUserID,
            CustomerID: CustomerID
        };

        // check if customer tickets should be shown
        if (!parseInt(Core.Config.Get('CustomerSearch.ShowCustomerTickets'), 10)) {
            return;
        }

        if ($('#CustomerTickets').length) {
            Core.AJAX.ContentUpdate($('#CustomerTickets'), Core.Config.Get('Baselink') + $.param(Data), function(){
                TargetNS.ReplaceCustomerTicketLinks();
            }, true);
        }
    }

    /**
     * @private
     * @name CheckPhoneCustomerCountLimit
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @description
     *      In AgentTicketPhone, this checks if more than one entry is allowed
     *      in the customer list and blocks/unblocks the autocomplete field as needed.
     */
    function CheckPhoneCustomerCountLimit() {

        // Only operate in AgentTicketPhone
        if (Core.Config.Get('Action') !== 'AgentTicketPhone') {
            return;
        }

        // Check if multiple from entries are allowed
        if (Core.Config.Get('Ticket::Frontend::AgentTicketPhone::AllowMultipleFrom') === "1") {
            return;
        }

        if ($('#TicketCustomerContentFromCustomer input.CustomerTicketText').length > 0) {
            $('#FromCustomer').val('').prop('disabled', true).prop('readonly', true);
            $('#Dest').trigger('focus');
        }
        else {
            $('#FromCustomer').val('').prop('disabled', false).prop('readonly', false);
        }
    }

    /**
     * @private
     * @name Init
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {jQueryObject} $Element - The jQuery object of the input field with autocomplete.
     * @description
     *      Initializes the module.
     */
    TargetNS.Init = function ($Element) {

        if (
            Core.Config.Get('Action') !== 'AgentBook'
            && $Element.attr('name') != undefined
            && $Element.attr('name').substr(0, 13) !== 'DynamicField_'
        ) {
            // get customer tickets for AgentTicketCustomer
            if (Core.Config.Get('Action') === 'AgentTicketCustomer') {
                GetCustomerTickets($('#CustomerAutoComplete').val(), $('#CustomerID').val());

                $Element.blur(function () {
                    if ($Element.val() === '') {
                        TargetNS.ResetCustomerInfo();
                        $('#CustomerTickets').empty();
                    }
                });
            }

            // get customer tickets for AgentTicketPhone and AgentTicketEmail
            if (
                (
                    Core.Config.Get('Action') === 'AgentTicketEmail'
                    || Core.Config.Get('Action') === 'AgentTicketEmailQuick'
                    || Core.Config.Get('Action') === 'AgentTicketEmailOutbound'
                    || Core.Config.Get('Action') === 'AgentTicketForward'
                    || Core.Config.Get('Action') === 'AgentTicketPhoneQuick'
                    || Core.Config.Get('Action') === 'AgentTicketPhoneOutbound'
                    || Core.Config.Get('Action') === 'AgentTicketPhoneInbound'
                    || Core.Config.Get('Action') === 'AgentTicketPhone'
                )
                && $('#SelectedCustomerUser').val() !== ''
            ) {
                GetCustomerTickets($('#SelectedCustomerUser').val(), $('#CustomerID').val());
            }

            // just save the initial state of the customer info
            if ($('#CustomerInfo').length) {
                BackupData.CustomerInfo = $('#CustomerInfo .Content').html();
            }
        }

        if ($('#CustomerInfo').length) {
            BackupData.CustomerInfo = $('#CustomerInfo .Content').html();
        }

        if (isJQueryObject($Element)) {
            // Hide tooltip in autocomplete field, if user already typed something to prevent the autocomplete list
            // to be hidden under the tooltip. (Only needed for serverside errors)
            $Element.off('keyup.Validate').on('keyup.Validate', function () {
               var Value = $Element.val();
               if ($Element.hasClass('ServerError') && Value.length) {
                   $('#OTRS_UI_Tooltips_ErrorTooltip').hide();
               }
            });

            Core.UI.Autocomplete.Init($Element, function (Request, Response) {
                var URL = Core.Config.Get('Baselink'),
                    Data = {
                        Action: 'AgentCustomerSearch',
                        Term: Request.term,
                        MaxResults: Core.UI.Autocomplete.GetConfig('MaxResultsDisplayed')
                    };

                $Element.data('AutoCompleteXHR', Core.AJAX.FunctionCall(URL, Data, function (Result) {
                    var ValueData = [];
                    $Element.removeData('AutoCompleteXHR');
                    $.each(Result, function () {
                        ValueData.push({
                            label: this.CustomerValue + " (" + this.CustomerKey + ")",
                            // customer list representation (see CustomerUserListFields from Defaults.pm)
                            value: this.CustomerValue,
                            // customer user id
                            key: this.CustomerKey
                        });
                    });
                    Response(ValueData);
                }));
            }, function (Event, UI) {
                var CustomerKey = UI.item.key,
                    CustomerValue = UI.item.value;

                if ($Element.attr('name') != undefined && $Element.attr('name').substr(0, 13) !== 'DynamicField_') {

                    BackupData.CustomerKey = CustomerKey;
                    BackupData.CustomerEmail = CustomerValue;

                    if (Core.Config.Get('Action') === 'AgentBook') {
                        $(Event.target).val(CustomerValue);
                        return false;
                    }

                    $Element.val(CustomerValue);

                    if (
                        Core.Config.Get('Action') !== 'AgentTicketEmail'
                        && Core.Config.Get('Action') !== 'AgentTicketPhone'
                    ) {
                        // reset selected customer id
                        $('#CustomerID').val('');
                    }

                    if (
                        Core.Config.Get('Action') === 'AgentTicketEmail'
                        || Core.Config.Get('Action') === 'AgentTicketEmailQuick'
                        || Core.Config.Get('Action') === 'AgentTicketEmailOutbound'
                        || Core.Config.Get('Action') === 'AgentTicketForward'
                        || Core.Config.Get('Action') === 'AgentTicketCompose'
                        || Core.Config.Get('Action') === 'AgentTicketEmailQuick'
                    ) {
                        $Element.val('');
                    }

                    if (
                        Core.Config.Get('Action') !== 'AgentTicketPhone'
                        && Core.Config.Get('Action') !== 'AgentTicketPhoneQuick'
                        && Core.Config.Get('Action') !== 'AgentTicketPhoneOutbound'
                        && Core.Config.Get('Action') !== 'AgentTicketPhoneInbound'
                        && Core.Config.Get('Action') !== 'AgentTicketEmailQuick'
                        && Core.Config.Get('Action') !== 'AgentTicketEmail'
                        && Core.Config.Get('Action') !== 'AgentTicketEmailOutbound'
                        && Core.Config.Get('Action') !== 'AgentTicketCompose'
                        && Core.Config.Get('Action') !== 'AgentTicketForward'
                        && Core.Config.Get('Action') !== 'AdminQuickTicketConfigurator'
                    ) {
                        // get customer data for customer info table
                        GetCustomerInfo(CustomerKey, '', Core.Config.Get('Action'));

                        // get customer tickets
                        GetCustomerTickets(CustomerKey);

                        // set hidden field SelectedCustomerUser
                        // trigger change-event to allow event handler after selecting the customer
                        if ($('#SelectedCustomerUser').val() != CustomerKey) {
                            $('#SelectedCustomerUser').val(CustomerKey).trigger('change');
                        }

                        // needed for AgentTicketCustomer.pm
                        if ($('#CustomerUserID').length) {
                            $('#CustomerUserID').val(CustomerKey);
                            if ($('#CustomerUserOption').length) {
                                $('#CustomerUserOption').val(CustomerKey);
                            }
                            else {
                                $('<input type="hidden" name="CustomerUserOption" id="CustomerUserOption">').val(CustomerKey).appendTo($Element.closest('form'));
                            }
                        }
                    }
                    else if (Core.Config.Get('Action') === 'AdminQuickTicketConfigurator') {
                        if ($Element.attr('id') == 'ToCustomer') {
                            if ($('#SelectedCustomerUser').val() != CustomerKey) {
                                $('#SelectedCustomerUser').val(CustomerKey).trigger('change');
                            }
                            $('#CustomerLogin').val(CustomerKey);
                            GetCustomerInfo(CustomerKey, $('#CustomerID').val());
                            Core.AJAX.FormUpdate($('#TicketTemplateForm'), 'AJAXUpdate', 'From', [ 'ServiceID', 'SLAID' ] );
                        }
                        if ($Element.attr('id') == 'CcCustomer') {
                            $('#CcCustomerLogin').val(CustomerKey);
                        }
                        if ($Element.attr('id') == 'BccCustomer') {
                            $('#BccCustomerLogin').val(CustomerKey);
                        }
                    } else if (Core.Config.Get('Action') === 'AgentTicketCustomer') {
                        TargetNS.AddTicketCustomer($(Event.target).attr('id'), CustomerValue, CustomerKey);

                        // get customer tickets
                        GetCustomerTickets(CustomerKey);
                    } else {
                        TargetNS.AddTicketCustomer($(Event.target).attr('id'), CustomerValue, CustomerKey);
                    }
                }
                else {
                    $Element.val(CustomerKey);
                }

                Event.preventDefault();
                return false;
            }, 'CustomerSearch');

            if (
                $Element.attr('name') != undefined 
                && $Element.attr('name').substr(0, 13) !== 'DynamicField_'
                && Core.Config.Get('Action') !== 'AgentBook'
                && Core.Config.Get('Action') !== 'AgentTicketCustomer'
                && Core.Config.Get('Action') !== 'AgentTicketPhone'
                && Core.Config.Get('Action') !== 'AgentTicketEmail'
                && Core.Config.Get('Action') !== 'AgentTicketEmailOutbound'
                && Core.Config.Get('Action') !== 'AgentTicketPhoneQuick'
                && Core.Config.Get('Action') !== 'AgentTicketPhoneOutbound'
                && Core.Config.Get('Action') !== 'AgentTicketPhoneInbound'
                && Core.Config.Get('Action') !== 'AgentTicketEmailQuick'
                && Core.Config.Get('Action') !== 'AgentTicketCompose'
                && Core.Config.Get('Action') !== 'AgentTicketForward'
                && Core.Config.Get('Action') !== 'AdminQuickTicketConfigurator'
            ) {
                $Element.blur(function () {
                    var FieldValue = $(this).val();
                    if (
                        FieldValue !== BackupData.CustomerEmail
                        && FieldValue !== BackupData.CustomerKey
                    ) {
                        $('#SelectedCustomerUser').val('');
                        $('#CustomerUserID').val('');
                        $('#CustomerID').val('');
                        $('#CustomerUserOption').val('');
                        $('#ShowCustomerID').html('');

                        // reset customer info table
                        $('#CustomerInfo .Content').html(BackupData.CustomerInfo);

                        if (Core.Config.Get('Action') === 'AgentTicketProcess'){
                            // update services (trigger ServiceID change event)
                            Core.AJAX.FormUpdate($('#CustomerID').closest('form'), 'AJAXUpdate', 'ServiceID', Core.Config.Get('ProcessManagement.UpdatableFields'));
                        }
                    }
                });
            }
            else {
                // initializes the customer fields
                TargetNS.InitCustomerField();
            }
        }

        // On unload remove old selected data. If the page is reloaded (with F5) this data
        // stays in the field and invokes an ajax request otherwise. We need to use beforeunload
        // here instead of unload because the URL of the window does not change on reload which
        // doesn't trigger pagehide.
        $(window).on('beforeunload.CustomerSearch', function () {
            $('#SelectedCustomerUser').val('');
            return; // return nothing to suppress the confirmation message
        });

        CheckPhoneCustomerCountLimit();
    };

    function htmlDecode(Text){
        return Text.replace(/&amp;/g, '&');
    }

    /**
     * @name AddTicketCustomer
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @returns {Boolean} Returns false.
     * @param {String} Field
     * @param {String} CustomerValue - The readable customer identifier.
     * @param {String} CustomerKey - Customer key on system.
     * @param {String} SetAsTicketCustomer -  Set this customer as main ticket customer.
     * @description
     *      This function adds a new ticket customer
     */
    TargetNS.AddTicketCustomer = function (Field, CustomerValue, CustomerKey, SetAsTicketCustomer) {

        var $Clone = $('.CustomerTicketTemplate' + Field).clone(),
            CustomerTicketCounter = $('#CustomerTicketCounter' + Field).val(),
            TicketCustomerIDs = 0,
            IsDuplicated = false,
            Suffix;

        if (typeof CustomerKey !== 'undefined') {
            CustomerKey = htmlDecode(CustomerKey);
        }
        else {
            CustomerKey = CustomerValue;
        }

        if (CustomerValue === '') {
            return false;
            Core.App.Publish('Core.Agent.CustomerSearch.AddTicketCustomer', [false, CustomerValue, CustomerKey]);
        }

        // check for duplicated entries
        $('[class*=CustomerTicketText]').each(function() {
            if ($(this).val() === CustomerValue) {
                IsDuplicated = true;
            }
        });
        if (IsDuplicated) {
            TargetNS.ShowDuplicatedDialog(Field);
            Core.App.Publish('Core.Agent.CustomerSearch.AddTicketCustomer', [false, CustomerValue, CustomerKey]);
            return false;
        }

        // get number of how much customer ticket are present
        TicketCustomerIDs = $('.CustomerContainer input[type="radio"]').length;

        // increment customer counter
        CustomerTicketCounter++;

        // set sufix
        Suffix = '_' + CustomerTicketCounter;

        // remove unnecessary classes
        $Clone.removeClass('Hidden CustomerTicketTemplate' + Field);

        // copy values and change ids and names
        $Clone.find(':input, a').each(function(){
            var ID = $(this).attr('id');
            $(this).attr('id', ID + Suffix);
            $(this).val(CustomerValue);
            if (ID !== 'CustomerSelected') {
                $(this).attr('name', ID + Suffix);
            }

            // add event handler to radio button
            if($(this).hasClass('CustomerTicketRadio')) {

                if (TicketCustomerIDs === 0) {
                    $(this).prop('checked', true);
                }

                // set counter as value
                $(this).val(CustomerTicketCounter);

                // bind change function to radio button to select customer
                $(this).on('change', function () {
                    // remove row
                    if ($(this).prop('checked')){
                        // reset selected customer id
                        $('#CustomerID').val('');

                        // reload information
                        TargetNS.ReloadCustomerInfo(CustomerKey);
                    }
                    return false;
                });
            }

            // set customer key if present
            if($(this).hasClass('CustomerKey')) {
                $(this).val(CustomerKey);
            }

            // add event handler to remove button
            if($(this).hasClass('RemoveButton')) {

                // bind click function to remove button
                $(this).on('click', function () {

                    // remove row
                    TargetNS.RemoveCustomerTicket($(this));

                    // clear CustomerHistory table if there are no selected customer users
                    if ($('#TicketCustomerContent' + Field + ' .CustomerTicketRadio').length === 0) {
                        $('#CustomerTickets').empty();
                    }
                    return false;
                });
                // set button value
                $(this).val(CustomerValue);
            }

        });
        // show container
        $('#TicketCustomerContent' + Field).parent().removeClass('Hidden');
        // append to container
        $('#TicketCustomerContent' + Field).append($Clone);

        // set new value for CustomerTicketCounter
        $('#CustomerTicketCounter' + Field).val(CustomerTicketCounter);
        if (
            (
                CustomerKey !== ''
                && TicketCustomerIDs === 0
                && (
                    Field === 'ToCustomer'
                    || Field === 'FromCustomer'
                )
            )
            || SetAsTicketCustomer
        ) {
            if (SetAsTicketCustomer) {
                $('#CustomerSelected_' + CustomerTicketCounter).prop('checked', true).trigger('change');
            }
            else {
                $('.CustomerContainer input[type="radio"]:first').prop('checked', true).trigger('change');
            }
        }

        // return value to search field
        $('#' + Field).val('').focus();

        CheckPhoneCustomerCountLimit();

        // reload Crypt options on AgentTicketEMail, AgentTicketCompose and AgentTicketForward
        if (
            (
                Core.Config.Get('Action') === 'AgentTicketEmail'
                || Core.Config.Get('Action') === 'AgentTicketEmailQuick'
                || Core.Config.Get('Action') === 'AgentTicketCompose'
                || Core.Config.Get('Action') === 'AgentTicketForward'
                || Core.Config.Get('Action') === 'AgentTicketEmailOutbound'
            )
            && $('#CryptKeyID').length
        ) {
            Core.AJAX.FormUpdate($('#' + Field).closest('form'), 'AJAXUpdate', '', [ 'CryptKeyID' ]);
        }

        // now that we know that at least one customer has been added,
        // we can remove eventual errors from the customer field
        $('#FromCustomer, #ToCustomer')
            .removeClass('Error ServerError')
            .closest('.Field')
            .prev('label')
            .removeClass('LabelError');
        Core.Form.ErrorTooltips.HideTooltip();

        Core.App.Publish('Core.Agent.CustomerSearch.AddTicketCustomer', [true, CustomerValue, CustomerKey]);

        return false;
    };

    /**
     * @name RemoveCustomerTicket
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {jQueryObject} Object - JQuery object used as base to delete it's parent.
     * @description
     *      This function removes a customer ticket entry.
     */
    TargetNS.RemoveCustomerTicket = function (Object) {
        var TicketCustomerIDs = 0,
        $Field = Object.closest('.Field'),
        $Form;

        if (
            Core.Config.Get('Action') === 'AgentTicketEmail'
            || Core.Config.Get('Action') === 'AgentTicketEmailQuick'
            || Core.Config.Get('Action') === 'AgentTicketCompose'
            || Core.Config.Get('Action') === 'AgentTicketForward'
            || Core.Config.Get('Action') === 'AgentTicketEmailOutbound'
        ) {
            $Form = Object.closest('form');
        }
        Object.parent().remove();
        TicketCustomerIDs = $('.CustomerContainer input[type="radio"]').length;

        if (
            TicketCustomerIDs === 0
            && Core.Config.Get('Action') !== 'AgentTicketCompose'
            && Core.Config.Get('Action') !== 'AgentTicketPhoneOutbound'
            && Core.Config.Get('Action') !== 'AgentTicketPhoneInbound'
        ) {
            TargetNS.ResetCustomerInfo();
        }

        // reload Crypt options on AgentTicketEMail, AgentTicketCompose and AgentTicketForward
        if (
            (
                Core.Config.Get('Action') === 'AgentTicketEmail'
                || Core.Config.Get('Action') === 'AgentTicketEmailQuick'
                || Core.Config.Get('Action') === 'AgentTicketCompose'
                || Core.Config.Get('Action') === 'AgentTicketForward'
                || Core.Config.Get('Action') === 'AgentTicketEmailOutbound'
            )
            && $('#CryptKeyID').length
        ) {
            Core.AJAX.FormUpdate($Form, 'AJAXUpdate', '', ['CryptKeyID']);
        }

        if(!$('.CustomerContainer input[type="radio"]').is(':checked')) {
            //set the first one as checked
            $('.CustomerContainer input[type="radio"]:first').prop('checked', true).trigger('change');
        }

        if ($Field.find('.CustomerTicketText:visible').length === 0) {
            $Field.addClass('Hidden');
        }

        Core.App.Publish('Core.Agent.CustomerSearch.RemoveTicketCustomer', [Object]);

        CheckPhoneCustomerCountLimit();
    };

    /**
     * @name ResetCustomerInfo
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @description
     *      This function clears all selected customer info.
     */
    TargetNS.ResetCustomerInfo = function () {
            $('#SelectedCustomerUser').val('');
            $('#CustomerUserID').val('');
            $('#CustomerID').val('');
            $('#CustomerUserOption').val('');
            $('#ShowCustomerID').html('');

            // reset customer info table
            $('#CustomerInfo .Content').html('none');
    };

    /**
     * @name ReloadCustomerInfo
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {String} CustomerKey
     * @description
     *      This function reloads info for selected customer.
     */
    TargetNS.ReloadCustomerInfo = function (CustomerKey,CallingAction,Type) {

        if (
            Type == 'Agent'
            && !ExistsCustomerUser(CustomerKey)
        ) {
            var Action = Core.Config.Get('Action');
            if (
                CallingAction !== undefined
                && CallingAction != ''
            ) {
                Action = CallingAction;
            }
            GetUserInfo(CustomerKey,Action);
        } else {
            // get customer tickets
            GetCustomerTickets(CustomerKey);

            // get customer data for customer info table
            var Action = Core.Config.Get('Action');
            if ( CallingAction !== undefined && CallingAction != '' ) {
                Action = CallingAction;
            }
            GetCustomerInfo(CustomerKey, $('#CustomerID').val(), Action);

            // set hidden field SelectedCustomerUser
            if ($('#SelectedCustomerUser').val() != CustomerKey) {
                $('#SelectedCustomerUser').val(CustomerKey).trigger('change');
            }
        }
    };

    /**
     * @name InitCustomerField
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @description
     *      This function initializes the customer fields.
     */
    TargetNS.InitCustomerField = function () {

        // SelectedCustomerUser set and customer info empty - set customer info again
        if (
            $('#SelectedCustomerUser').length
            && $('#SelectedCustomerUser').val() != ""
        ) {
            TargetNS.ReloadCustomerInfo($('#SelectedCustomerUser').val());
        }

        // loop over the field with CustomerAutoComplete class
        $('.CustomerAutoComplete').each(function() {

            if ($(this).attr('name').substr(0, 13) !== 'DynamicField_') {

                var ObjectId = $(this).attr('id');

                $('#' + ObjectId).on('change', function () {

                    if (!$('#' + ObjectId).val() || $('#' + ObjectId).val() === '') {
                        return false;
                    }

                    // if autocompletion is disabled and only avaible via the click
                    // of a button next to the input field, we cannot handle this
                    // change event the normal way.
                    if (!Core.UI.Autocomplete.GetConfig('ActiveAutoComplete')) {
                        // we wait some time after this event to check, if the search button
                        // for this field was pressed. If so, no action is needed
                        // If the change event was fired without clicking the search button,
                        // probably the user clicked out of the field.
                        // This should also add the customer (the enetered value) to the list

                        if (typeof CustomerFieldChangeRunCount[ObjectId] === 'undefined') {
                            CustomerFieldChangeRunCount[ObjectId] = 1;
                        }
                        else {
                            CustomerFieldChangeRunCount[ObjectId]++;
                        }

                        if (Core.UI.Autocomplete.SearchButtonClicked[ObjectId]) {
                            delete CustomerFieldChangeRunCount[ObjectId];
                            delete Core.UI.Autocomplete.SearchButtonClicked[ObjectId];
                            return false;
                        }
                        else {
                            if (CustomerFieldChangeRunCount[ObjectId] === 1) {
                                window.setTimeout(function () {
                                    $('#' + ObjectId).trigger('change');
                                }, 200);
                                return false;
                            }
                            delete CustomerFieldChangeRunCount[ObjectId];
                        }
                    }

                    // If the autocomplete popup window is visible, delay this change event.
                    // It might be caused by clicking with the mouse into the autocomplete list.
                    // Wait until it is closed to be sure that we don't add a customer twice.
                    if ($(this).autocomplete("widget").is(':visible')) {
                        window.setTimeout(function(){
                            $('#' + ObjectId).trigger('change');
                        }, 200);
                        return false;
                    }

                    // clear search input
                    $('#' + ObjectId).val('');
                    return false;
                });

                $('#' + ObjectId).on('keypress', function (e) {
                    if (e.which === 13){
                        Core.Agent.CustomerSearch.AddTicketCustomer(ObjectId, $('#' + ObjectId).val(), $('#' + ObjectId).prev('.CustomerKey').val());
                        return false;
                    }
                });
            }
        });
    };

    /**
     * @name ShowDuplicatedDialog
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @param {String} Field - ID object of the element should receive the focus on close event.
     * @description
     *      This function shows an alert dialog for duplicated entries.
     */
    TargetNS.ShowDuplicatedDialog = function(Field){
        Core.UI.Dialog.ShowAlert(
            Core.Config.Get('Duplicated.TitleText'),
            Core.Config.Get('Duplicated.ContentText') + ' ' + Core.Config.Get('Duplicated.RemoveText'),
            function () {
                Core.UI.Dialog.CloseDialog($('.Alert'));
                $('#' + Field).val('');
                $('#' + Field).focus();
                return false;
            }
        );
    };

    /**
     * @private
     * @name ReplaceCustomerTicketLinks
     * @memberof Core.Agent.CustomerSearch
     * @function
     * @returns {Boolean} Returns false.
     * @description
     *      This function replaces and shows customer ticket links.
     */
    TargetNS.ReplaceCustomerTicketLinks = function() {
        $('#CustomerTickets').find('.AriaRoleMain').removeAttr('role').removeClass('AriaRoleMain');

        // Replace overview mode links (S, M, L view)
        $('#CustomerTickets').find('.OverviewZoom a, .TableSmall th a').click(function () {
            Core.AJAX.ContentUpdate($('#CustomerTickets'), $(this).attr('href'), function(){
                TargetNS.ReplaceCustomerTicketLinks();
            }, true);
            return false;
        });

        // Init accordion of overview article preview
        Core.UI.Accordion.Init($('.Preview > ul'), 'li h3 a', '.HiddenBlock');

        if (Core.Config.Get('Action') === 'AgentTicketCustomer') {
            $('a.MasterActionLink').on('click', function () {
                var that = this;
                Core.UI.Popup.ExecuteInParentWindow(function(WindowObject) {
                    WindowObject.Core.UI.Popup.FirePopupEvent('URL', { URL: that.href });
                });
                Core.UI.Popup.ClosePopup();
                return false;
            });
        }
        return false;
    }

    return TargetNS;
}(Core.Agent.CustomerSearch || {}));
