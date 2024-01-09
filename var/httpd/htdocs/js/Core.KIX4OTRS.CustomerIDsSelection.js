// --
// Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.CustomerIDsSelection
 * @description This namespace contains special functions for customer IDs selection in the agents frontend.
 */
Core.KIX4OTRS.CustomerIDsSelection = (function(TargetNS) {

    /**
     * @function
     * @return nothing This function initializes the customer ID selection
     */
    TargetNS.Init = function() {
        var $CustomerIDs = $('.SelectedCustomerIDRadio'),
            $CustomerID = $('#CustomerID'),
            $Form = $('input[name="FormID"]').closest('form');

        if (!$CustomerIDs.length || !$CustomerID.length)
            return;

        $CustomerIDs.on('click', function() {
            $CustomerID.val($(this).val()).trigger('change');
            if ($Form.length) {
                Core.AJAX.FormUpdate($Form, 'AJAXUpdate', 'CustomerID', ['TypeID', 'Dest', 'NewUserID', 'NewResponsibleID', 'NextStateID', 'PriorityID', 'ServiceID', 'SLAID']);
                Core.Agent.CustomerSearch.ReloadCustomerInfo($('#SelectedCustomerUser').val());
            }
        });

        Core.App.Subscribe('Event.Agent.CustomerSearch.GetCustomerInfo.Callback', function(){
            $('.SelectedCustomerIDRadio[value="' + $('#CustomerID').val() + '"]').prop("checked", true);
        });
    };

    return TargetNS;
}(Core.KIX4OTRS.CustomerIDsSelection || {}));
