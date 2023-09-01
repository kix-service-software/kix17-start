// --
// Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.UI = Core.UI || {};

/**
 * @namespace
 * @exports TargetNS as Core.UI.SystemMessage
 * @description
 *      This namespace contains the special module functions for the system message.
 */
Core.UI.SystemMessage = (function (TargetNS) {
    var ShownModule,
        ShownIdentifier;

    TargetNS.Init = function (Module, Identifier) {

        if ( Module === 'KIXSidebar' ) {
            ShownModule     = Module;
            ShownIdentifier = Identifier;

            KIXSidebarTools.UpdateSidebar(
                'SystemMessageAJAXHandler',
                Identifier,
                {
                    'CallingAction': Core.Config.Get('Action'),
                    'Module': Module
                },
                window['KIXSidebarCallback' + Identifier]
            );
        }

        else if ( Module === 'Login' ) {
            $('body.LoginScreen > .MainBox')
                .removeClass('SpacingTopLarge')
                .css({
                    'padding-top': '89px'
                });

            $('.SystemMessageOpenDialog').on('click', function() {
                var ID = $(this).attr('data-id');
                TargetNS.ShowContent(Module, Identifier, ID);
            });

            if ( $('.SystemMessageOpenDialog.Popup').length === 1 ) {
                var ID = $('.SystemMessageOpenDialog.Popup').attr('data-id');
                TargetNS.ShowContent(Module, Identifier, ID);
            }
        }

        else if ( Module === 'Dashboard' ) {
            ShownModule     = Module;
            ShownIdentifier = Identifier;

            $('.AutoColspan').each(function() {
                var ColspanCount = $(this).closest('table').find('th').length;
                $(this).attr('colspan', ColspanCount);
            });

            $('.SystemMessageOpenDialog').on('click', function() {
                var ID = $(this).closest('tr').attr('data-id');
                TargetNS.ShowContent(Module, Identifier,  ID);
            });
        }

        else if ( Module === 'Header' ) {
            TargetNS.ShowWidget();
        }
    }

    TargetNS.ShowWidget = function () {
        var CallingAction = Core.Config.Get('Action'),
        Data          = {
            Action: 'SystemMessageAJAXHandler',
            Subaction: 'AJAXWidget',
            Module: 'Header',
            CallingAction: CallingAction
        };

        Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function (Response) {
            if ( Response.PopupID ) {
                TargetNS.ShowContent(ShownModule, ShownIdentifier, Response.PopupID);
            }

            if ( !Response.Content ) {
                return false;
            }

            if ( $('#MainBox').length ) {
                $('#MainBox').prepend(Response.Content);
                if ( Core.Config.Get('Baselink').match(/public.pl/) ) {
                    $('#SystemMessageWidget').addClass('SystemMessageWidget');
                }
            }
            else if ( $('.MainBox').length ) {
                $('.MainBox').prepend(Response.Content);
            }
            else if ( $('#NavigationContainer').length ) {
                $('#NavigationContainer').after(Response.Content);
                $('#SystemMessageWidget').addClass('SystemMessageWidget');
            }
            else {
                return false;
            }

            $('.SystemMessageOpenDialog').on('click', function() {
                var ID = $(this).closest('tr').attr('data-id');
                TargetNS.ShowContent('Header', null,  ID);
            });
        });
        return false;
    }

    TargetNS.ShowContent = function (Module, Identifier, ID) {
        var CallingAction = Core.Config.Get('Action'),
            Data          = {
                Action: 'SystemMessageAJAXHandler',
                Subaction: 'AJAXMessageGet',
                MessageID: ID,
                CallingAction: CallingAction
            },
            BaseLink = Core.Config.Get('Baselink');

        if ( Module === 'Login' ) {
            var Pattern = new RegExp("(index|customer)(.pl)", 'g');
            BaseLink = BaseLink.replace(Pattern, 'public$2' );
        }

        Core.AJAX.FunctionCall(BaseLink, Data, function (Response) {
            var Button,
                Data;

            // 'Confirmation' opens a dialog with 2 buttons: MarkAsRead and close
            if (
                Response.MarkAsRead === '1'
                && Module !== 'Login'
            ) {
                Data = {
                    Action: 'SystemMessageAJAXHandler',
                    Subaction: 'AJAXUpdate',
                    MessageID: Response.MessageID
                }

                Button = [
                    {
                        Label: '<i class="fa fa-eye" ></i> ' + Response.TranslateText.MarkAsRead,
                        Class: "Primary",

                        // define the function that is called when the 'Yes' button is pressed
                        Function: function(){
                            Core.AJAX.FunctionCall(BaseLink, Data, function (Response) {
                                if ( Module === 'KIXSidebar' ) {
                                    KIXSidebarTools.UpdateSidebar(
                                        'SystemMessageAJAXHandler',
                                        Identifier,
                                        {
                                            'CallingAction': CallingAction,
                                            'Module': Module
                                        },
                                        window['KIXSidebarCallback' + Identifier]
                                   );
                                }
                                else if ( Module === 'Dashboard' ) {
                                    var URL = Core.Config.Get('Baselink') + 'Action=AgentDashboard;Subaction=Element;Name=' + Identifier;

                                    Core.AJAX.ContentUpdate($('#Dashboard' + Identifier), URL, function() {
                                        TargetNS.Init(Module, Identifier, null);
                                    });
                                }
                                else if ( Module === 'Header' ) {
                                    $('#SystemMessageWidget').remove();
                                    TargetNS.ShowWidget();
                                }
                                Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                            });
                        },
                    },
                    {
                        Label: Response.TranslateText.Close,
                        Type:'Close',
                    }
                ];
            } else {
                Button = [
                    {
                        Label: Response.TranslateText.Close,
                        Type:'Close',
                    }
                ];
            }

            Core.UI.Dialog.ShowContentDialog(
                Response.Content,
                Response.Title,
                '20%',
                'Center',
                true,
                Button
            );
        });
        return false;
    }

    TargetNS.KIXSidebarButtons = function (Identifier) {
        $('.SystemMessageOpenDialog').on('click', function() {
            var ID = $(this).closest('tr').attr('data-id');
            TargetNS.ShowContent('KIXSidebar', Identifier, ID);
        });
    }

    return TargetNS;
}(Core.UI.SystemMessage || {}));
