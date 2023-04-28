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
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace Core.Agent.Admin.GenericInterfaceWebserviceHistory
 * @memberof Core.Agent.Admin
 * @author OTRS AG
 * @description
 *      This namespace contains the special module functions for the GenericInterface WebserviceHistory module.
 */
Core.Agent.Admin.GenericInterfaceWebserviceHistory = (function (TargetNS) {

    /**
     * @name Init
     * @memberof Core.Agent.Admin.GenericInterfaceWebserviceHistory
     * @function
     * @param {Object} Params - Initialization and internationalization parameters.
     * @description
     *      This function initialize the module.
     */
    TargetNS.Init = function (Params) {
        TargetNS.WebserviceID = parseInt(Params.WebserviceID, 10);
        TargetNS.Localization = Params.Localization;
    };

    /**
     * @name GetWebserviceList
     * @memberof Core.Agent.Admin.GenericInterfaceWebserviceHistory
     * @function
     * @description
     *      Get list of webservices via AJAX..
     */
    TargetNS.GetWebserviceList = function() {
        var Data = {
            Action: 'AdminGenericInterfaceWebserviceHistory',
            Subaction: 'GetWebserviceList',
            WebserviceID: TargetNS.WebserviceID,
            FilterRemoteIP: $('#FilterRemoteIP').val() || '',
            FilterType: $('#FilterType').val() || ''
        };

        $('#WebserviceDetails').css('visibility', 'hidden');
        $('.WebserviceListWidget').addClass('Loading');

        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
            var HTML = '',
                Counter;

            if (!Response || !Response.LogData) {
                alert(TargetNS.Localization.WebserviceHistoryErrorMsg);
                return;
            }

            $('.WebserviceListWidget').removeClass('Loading');

            if (!Response.LogData.length) {
                $('#WebserviceList tbody').empty().append('<tr><td colspan="3">' + TargetNS.Localization.NoDataFoundMsg + '</td></tr>');
            }
            else {
                $('#WebserviceList tbody').empty();

                Counter = Response.LogData.length;

                $.each(Response.LogData, function(){
                    HTML += '<tr>';

                    HTML += '<td><a href="#" class="AsBlock">' + Counter +
                        '<input type="hidden" class="WebserviceHistoryID" value="' + this.ID + '" />' +
                        '<input type="hidden" class="WebserviceHistoryVersion" value="' + Counter + '" />' +
                    '</a></td>';
                    HTML += '<td><a href="#" class="AsBlock">' + this.CreateTime + '</a></td>';
                    HTML += '</tr>';
                    Counter--;

                });
                $('#WebserviceList tbody').html(HTML);

                $('#WebserviceList a').on('click', function() {
                    var WebserviceHistoryID = $(this).blur().parents('tr').find('input.WebserviceHistoryID').val(),
                    WebserviceHistoryVersion = $(this).blur().parents('tr').find('input.WebserviceHistoryVersion').val();

                    TargetNS.LoadWebserviceHistoryDetails(WebserviceHistoryID, WebserviceHistoryVersion);

                    return false;
                });

            }
        }, 'json');
    };

    /**
     * @name LoadWebserviceHistoryDetails
     * @memberof Core.Agent.Admin.GenericInterfaceWebserviceHistory
     * @function
     * @param {String} WebserviceHistoryID
     * @param {String} WebserviceHistoryVersion
     * @description
     *      This function initialize the module.
     */
    TargetNS.LoadWebserviceHistoryDetails = function(WebserviceHistoryID, WebserviceHistoryVersion) {

        var Data = {
            Action: 'AdminGenericInterfaceWebserviceHistory',
            Subaction: 'GetWebserviceHistoryDetails',
            WebserviceID: TargetNS.WebserviceID,
            WebserviceHistoryID: WebserviceHistoryID
        };

        $('#WebserviceHistoryDetails').css('visibility', 'hidden');
        $('.WebserviceListWidget').addClass('Loading');

        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function (Response) {
            if (!Response || !Response.LogData) {
                alert(TargetNS.Localization.WebserviceHistoryErrorMsg);
                return;
            }
            $('.WebserviceListWidget').removeClass('Loading');

            if (!Response.LogData.Config) {
                $('#WebserviceHistoryDetails > .Header').empty();
                $('#WebserviceHistoryDetails > .Header').append(
                    '<h2>History Details</h2>'
                );
                $('#WebserviceHistoryDetails .ConfigCode pre').empty();
                $('#WebserviceHistoryDetails .ConfigCode pre').append(
                    '<span class="ErrorMessage">' + TargetNS.Localization.NoDataFoundMsg + '</span>'
                );
                $('#WebserviceHistoryDetails').css('visibility', 'visible').show();
                $('#WebserviceHistoryDetails .LightRow').hide();
            }
            else {

                $('#WebserviceHistoryID').attr('value', WebserviceHistoryID);
                $('#WebserviceHistoryDetails > .Header').empty();
                $('#WebserviceHistoryDetails > .Header').append(
                    '<h2>History Details: Version ' + WebserviceHistoryVersion + ', ' + Response.LogData.CreateTime + '</h2>'
                );

                $('#WebserviceHistoryDetails .ConfigCode pre').empty();
                $('#WebserviceHistoryDetails .ConfigCode pre').append(
                    '<code>' + Response.LogData.Config + '</code>'
                );

                $('#WebserviceHistoryDetails').css('visibility', 'visible').show();
                $('#WebserviceHistoryDetails .LightRow').show();

            }
        }, 'json');
    };

    /**
     * @name ShowRollbackDialog
     * @memberof Core.Agent.Admin.GenericInterfaceWebserviceHistory
     * @function
     * @returns {Boolean} Returns false.
     * @param {Object} Event - The browser event object, e.g. of the clicked DOM element.
     * @description
     *      Shows a dialog to rollback log.
     */
    TargetNS.ShowRollbackDialog = function(Event){

        Core.UI.Dialog.ShowContentDialog(
            $('#RollbackDialogContainer'),
            TargetNS.Localization.RollbackLogMsg,
            '240px',
            'Center',
            true,
            [
                {
                    Label: TargetNS.Localization.CancelMsg,
                    Class: 'Primary',
                    Function: function () {
                        Core.UI.Dialog.CloseDialog($('#RollbackDialog'));
                    }
                },
                {
                    Label: TargetNS.Localization.RollbackLogMsg,
                    Function: function () {
                        $('#Subaction').attr('value', 'Rollback');
                        $('#ActionForm').submit();
                    }
                }
            ]
        );

        Event.stopPropagation();
        return false;
    };


    return TargetNS;
}(Core.Agent.Admin.GenericInterfaceWebserviceHistory || {}));
