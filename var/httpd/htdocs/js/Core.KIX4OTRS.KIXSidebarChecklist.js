// --
// Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
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
 * @exports TargetNS as Core.KIX4OTRS.KIXSidebarChecklist
 * @description This namespace contains the special module functions for the checklist sidebar.
 */
Core.KIX4OTRS.KIXSidebarChecklist = (function(TargetNS) {

    /**
     * @function
     * @return nothing This function initializes the special module functions
     */

    TargetNS.Init = function(AvailableStates,AvailableStateStyles,Access) {

        if ( Access == 0 ) {
            return false;
        }

        // show or hide settings
        $('#Checklist .ActionMenu .WidgetAction.Settings a').unbind('click.WidgetToggle').bind('click', function() {

            // show settings hide edit fields
            if ( $('#KIXSidebarChecklistEdit').hasClass('Hidden') ) {
                $('#KIXSidebarChecklistDisplay').addClass('Hidden');
                $('#KIXSidebarChecklistEdit').removeClass('Hidden');
            }
            // show edit fields hide settings
            else {
                $('#KIXSidebarChecklistEdit').addClass('Hidden');
                $('#KIXSidebarChecklistDisplay').removeClass('Hidden');
            }
        });

        // checklist actions
        var States = AvailableStates,
            StateStyles = AvailableStateStyles;

            // on submit update the task list
            $('#ChecklistSubmit').bind('click', function (Event) {
                var TicketID        = $('input[name="TicketID"]').val(),
                    TaskString      = $('#ChecklistTasks').val(),
                    Data = {
                        Action : 'KIXSidebarChecklistAJAXHandler',
                        Subaction : 'UpdateTasks',
                        TicketID : TicketID,
                        TaskString : TaskString
                    };
                    Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function(Result) {
                        // create new list to display
                        $('#ChecklistTable').html(Result);
                        // hide edit mode and show display mode
                        $('#KIXSidebarChecklistEdit').addClass('Hidden');
                        $('#KIXSidebarChecklistDisplay').removeClass('Hidden');
                    });
            });

            // show available states to select one of them
            $(document).on('click','td[id^="ChecklistIcon_"]', function (Event) {
                var IconString = '',
                    TaskIDArray = $(this).attr('id').split("_"),
                    Icon = $(this).find('i').attr('class'),
                    TaskID = TaskIDArray[1];

                // show list
                if ( $(this).find('div').hasClass('Hidden') ) {
                    // hide already shown icons
                    $('.ChecklistIconList').addClass('Hidden');

                    // show clicked item
                    $(this).find('div').removeClass('Hidden');
                    // create list
                    $.each(States,function(Key,Value) {
                        var matchRegExp = new RegExp(Value);
                        if ( Icon.match(matchRegExp) )
                            return true;
                        IconString += '<span id="ChecklistIconItem_'+TaskID+'_'+Key+'" class="ChecklistIconItem"><i class="fa '+Value+'" style="'+StateStyles[Key]+'"></i></span>';
                    });
                    $('#ChecklistIconList_'+TaskID).html(IconString);
                }
                else {
                    $(this).find('div').addClass('Hidden');
                }
            });

            // change state for this task on click
            $(document).on('click','.ChecklistIconItem',function(){
                var ListIconItemArray = $(this).attr('id').split("_"),
                    TicketID = $('#TicketID').val(),
                    TaskID = ListIconItemArray[1],
                    State = ListIconItemArray[2],

                    Data = {
                        Action : 'KIXSidebarChecklistAJAXHandler',
                        Subaction : 'SaveTaskState',
                        TicketID : TicketID,
                        State : State,
                        TaskID : TaskID
                    };
                    Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function(Result) {
                        if ( Result == 1 ) {
                            $("#ChecklistIconList_"+TaskID).addClass('Hidden');
                            $("#ChecklistIcon_"+TaskID).find('i').removeClass().addClass('fa ' + States[State]).attr('style',StateStyles[State]);
                        }
                    });
                $(this).parent().addClass('Hidden');
            });
    }

    return TargetNS;
}(Core.KIX4OTRS.KIXSidebarChecklist || {}));
