// --
// Core.KIX4OTRS.KIXSidebarDynamicField.js - provides the special module functions for the KIXSidebarDynamicField
// Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
//
// written/edited by:
//   Dorothea(dot)Doerffel(at)cape(dash)it.de
//
// --
// $Id$
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.KIXSidebarCustomerInfo
 * @description This namespace contains the special module functions for the Dashboard.
 */
Core.KIX4OTRS.KIXSidebarDynamicField = (function(TargetNS) {

    /**
     * @function
     * @return nothing This function initializes the special module functions
     */

    TargetNS.Init = function() {
        // set new width
        $('#DisplayedDynamicFields').css({"min-width":"150px"});
        $('#KIXSidebarDynamicField').find('a').css({"width":"30px"});

        // show or hide settings
        $('#DynamicField .ActionMenu .WidgetAction.Settings a').unbind('click.WidgetToggle').bind('click', function() {

            // show settings hide edit fields
            if ( $('#KIXSidebarDynamicFieldSelect').hasClass('Hidden') ) {
                $('#KIXSidebarDynamicFieldSelect').removeClass('Hidden');
                if ( $('#KIXSidebarDynamicFieldEdit').length )
                    $('#KIXSidebarDynamicFieldEdit').addClass('Hidden');
                else
                    $('#KIXSidebarDynamicFieldDisplay').addClass('Hidden');
            }
            // show edit fields hide settings
            else {
                $('#KIXSidebarDynamicFieldSelect').addClass('Hidden');
                if ( $('#KIXSidebarDynamicFieldEdit').length )
                    $('#KIXSidebarDynamicFieldEdit').removeClass('Hidden');
                else
                    $('#KIXSidebarDynamicFieldDisplay').removeClass('Hidden');
            }
        });

        // update dymanic fields - AJAX request
        $(document).on('click','#UpdateDynamicFields',function(event){
            var Data = Core.AJAX.SerializeForm($(this).closest('form'));
            Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function () {},'text');
            $('#DynamicFieldsSaved').removeClass('Hidden');
        });

        // select dymanic fields - AJAX request
        $(document).on('click','#SelectDynamicFields',function(event){
            var Data = Core.AJAX.SerializeForm($(this).closest('form'));
            if ( $('#KIXSidebarDynamicFieldEdit').length ) {
                Core.AJAX.ContentUpdate($('#KIXSidebarDynamicFieldEdit').find('fieldset'), Core.Config.Get('CGIHandle') + '?' + Data, function () {});
                $('#KIXSidebarDynamicFieldSelect').addClass('Hidden');
                $('#KIXSidebarDynamicFieldEdit').removeClass('Hidden');
            }
            else {
                Core.AJAX.ContentUpdate($('#KIXSidebarDynamicFieldDisplay').find('fieldset'), Core.Config.Get('CGIHandle') + '?' + Data, function () {});
                $('#KIXSidebarDynamicFieldSelect').addClass('Hidden');
                $('#KIXSidebarDynamicFieldDisplay').removeClass('Hidden');
            }
        });
    }

    return TargetNS;
}(Core.KIX4OTRS.KIXSidebarDynamicField || {}));
