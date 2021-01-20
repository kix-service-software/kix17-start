// --
// Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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

    TargetNS.Init = function (Module, Identifier, Force) {

        if ( Module === 'KIXSidebar' ) {
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
        }

        else if ( Module === 'Dashboard' ) {
            if ( Force ) {
                TargetNS.ShowContent(Module, Identifier,  Force);
            }

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
            var Pattern = new RegExp(/(index|customer)(.pl)/, 'g');
            BaseLink = BaseLink.replace(Pattern, 'public$2' );
        }

        Core.AJAX.FunctionCall(BaseLink, Data, function (Response) {
            var Button,
                Data;

            // 'Confirmation' opens a dialog with 2 buttons: MarkAsRead and close
            if ( Response.MarkAsRead === '1'
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
                                if ( Module === 'KIXSidebar') {
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

        $('.SystemMessageMarkAsRead').on('click', function(){
            var Data = {
                    Action: 'SystemMessageAJAXHandler',
                    Subaction: 'AJAXUpdate',
                    MessageID: $(this).closest('tr').attr('data-id')
                },
                CallingAction = Core.Config.Get('Action');

            Core.AJAX.FunctionCall(Core.Config.Get('Baselink'), Data, function (Response) {
                KIXSidebarTools.UpdateSidebar(
                     'SystemMessageAJAXHandler',
                     Identifier,
                     {
                         'CallingAction': CallingAction,
                         'Module': 'KIXSidebar'
                     },
                     window['KIXSidebarCallback' + Identifier]
                );
            });
        });
    }

    return TargetNS;
}(Core.UI.SystemMessage || {}));
