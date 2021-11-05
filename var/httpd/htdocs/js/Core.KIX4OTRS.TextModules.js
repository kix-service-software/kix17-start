// --
// Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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
 * @exports TargetNS as Core.KIX4OTRS.TextModules
 * @description Provides functions for text module support
 */
Core.KIX4OTRS.TextModules = (function(TargetNS) {
    var TextModules = new Array(),
        TM_history = new Array(''),
        SelectedTextModuleID = -1,
        $TMTable = $('#TextModulesTable'),
        $TMTree = $('#TextModulesSelection'),
        $TMPreviewContainer = $('#TextModulePreviewContainer'); // just to have a valid selection object

    function InsertTextmodule(ID) {
        // get data from selected text module and create short alias
        var input = document.compose.Body, subject = document.compose.Subject;

        // get TextModule
        var TextModule = TargetNS.GetTextmodule(ID);

        // insert subject of text module
        if (typeof subject != 'undefined') {
            subject.value = subject.value + ' ' + TextModule.Subject;
        }

        // save last Body
        TM_history.push(input.value);

        // add text module to WYSIWYG editor in opener window
        if ( typeof(CKEDITOR) !== "undefined" && CKEDITOR.instances.RichText) {
            CKEDITOR.instances.RichText.insertHtml(TextModule.TextModule);
            return;
        }

        // focus orig input field
        input.focus();

        // IE
        if (typeof document.selection != 'undefined') {
            var range = document.selection.createRange(),
                insText = range.text;

            range.text = TextModule.TextModule + insText;
            range = document.selection.createRange();
            range.moveStart('character', document.spelling.Body.value.length + insText.length);
            range.select();
        }
        // gecko
        else if (typeof input.selectionStart != 'undefined') {
            var Start = input.selectionStart,
                End = input.selectionEnd,
                insText,
                pos;

            // set focus to start, if cursor it not dedicated set to the end
            // (only done automaticaly if more then 400 chars avail)
            if (input.value.length > 400 && End == input.value.length && Start == input.value.length) {
                Start = 0;
                End = 0;
            }

            insText = input.value.substring(Start, End);
            input.value = input.value.substr(0, Start) + TextModule.TextModule + insText + input.value.substr(End);

            if (insText.length == 0)
                pos = Start + TextModule.TextModule.length;
            else
                pos = Start + TextModule.TextModule.length + insText.length;

            input.selectionStart = pos;
            input.selectionEnd = pos;
        }
        // other, insert on top
        else {
            input.value = TextModule.TextModule + input.value;
        }

        return;
    }

    function UpdateTextmodule(ID) {
        // get data from selected text module and create short alias
        var input = document.compose.Body,
            subject = document.compose.Subject;

        // get TextModule
        var TextModule = TargetNS.GetTextmodule(ID);

        // insert subject of text module
        if (typeof subject != 'undefined') {
            subject.value = subject.value + ' ' + TextModule.Subject;
        }

        // save last Body
        TM_history.push(input.value);

        // add text module to WYSIWYG editor in opener window
        if ( typeof(CKEDITOR) !== "undefined" && CKEDITOR.instances.RichText) {
            CKEDITOR.instances.RichText.insertHtml(TextModule.TextModule);
            return;
        }

        // focus orig input field
        input.focus();

        // IE
        if (typeof document.selection != 'undefined') {
            var range = document.selection.createRange(),
                insText = range.text;
            range.text = TextModule.TextModule + insText;
            range = document.selection.createRange();
            range.moveStart('character', document.spelling.Body.value.length + insText.length);
            range.select();
        }
        // gecko
        else if (typeof input.selectionStart != 'undefined') {
            var Start = input.selectionStart,
                End = input.selectionEnd,
                insText, pos;

            // set focus to start, if cursor it not dedicated set to the end
            // (only done automaticaly if more then 400 chars avail)
            if (input.value.length > 400 && End == input.value.length && Start == input.value.length) {
                Start = 0;
                End = 0;
            }

            insText = input.value.substring(Start, End);
            input.value = input.value.substr(0, Start) + TextModule.TextModule + insText + input.value.substr(End);

            if (insText.length == 0)
                pos = Start + TextModule.TextModule.length;
            else
                pos = Start + TextModule.TextModule.length + insText.length;

            input.selectionStart = pos;
            input.selectionEnd = pos;
        }
        // other, insert on top
        else {
            input.value = TextModule.TextModule + input.value;
        }

        return;
    }

    function PreviewTextmodule(Event, ID) {
        var PositionTop, PreviewPosition;

        var $Title = $TMPreviewContainer.find('.Header').find('#TMTitle'),
            $Subject = $TMPreviewContainer.find('.Content').find('#TMSubject'),
            $Body = $TMPreviewContainer.find('.Content').find('#TMBody'),
            loader = '<span class="Loader"></span>';

        $Title.html(loader);
        $Subject.html(loader);
        $Body.html(loader);

        PreviewPosition = Core.KIX4OTRS.GetWidgetPopupPosition($TMPreviewContainer.parent(), Event);

        // move PreviewContainer if close to bottom
        if (Math.round(screen.availHeight * 0.3) <= PreviewPosition.Top) {
            PositionTop = Math.round(screen.availHeight * 0.3);
        } else {
            PositionTop = PreviewPosition.Top;
        }

        $TMPreviewContainer.css('left', PreviewPosition.Left).css('top', PositionTop).show();

        // get TextModule for preview
        var TextModule = TargetNS.GetTextmodule(ID);

        $Title.text(TextModule.Name);
        $Subject.text(TextModule.Subject);
        $Body.html(TextModule.TextModule);

        return;
    }

    function UndoTextmodule(index) {
        var history_length = TM_history.length;

        // restore last content
        $('#' + index).val(TM_history[history_length - 1]);

        // keep at least the empty content value
        if (history_length > 1)
            TM_history.pop();

        return;
    }

    function RefreshTextmodules() {
        var QueueID,
            TicketID,
            TypeID,
            StateID,
            CustomerUserID,
            URL,
            Frontend = 'Agent',
            loader = '<span class="Loader"></span>';

        $('#TextModulesSelectionContainer').addClass('Center').html(loader);

        // determine QueueID
        if ($('#NewQueueID').length) {
            QueueID = $('#NewQueueID').val();
        } else if ($('#Dest').length) {
            if ( $('#Dest').val() !== ''
                 && $('#Dest').val() !== undefined
                 && $('#Dest').val() !== null
            ) {
                QueueID = $('#Dest').val().split('||')[0];
            } else {
                QueueID = '';
            }
        }

        // determine TicketID
        if ($('#TextModulesSelectionContainer').closest('form').find('input[name=TicketID]').length) {
            TicketID = $('#TextModulesSelectionContainer').closest('form').find('input[name=TicketID]').val();
        }
        else if ($('#Compose').find('input[name=TicketID]').length) {
             TicketID = $('#Compose').find('input[name=TicketID]').val();
        }

        // determine TypeID
        if ($('#TypeID').length) {
            TypeID = $('#TypeID').val();
        }

        // determine StateID
        if ($('#NextStateID').length) {
            StateID = $('#NextStateID').val();
        }

        // determine CustomerUserID
        if ($('#SelectedCustomerUser').length) {
            CustomerUserID = $('#SelectedCustomerUser').val();
        }

        // determine Frontend
        if ($(location).attr('href').search(/customer\.pl/) > 0) {
            Frontend = 'Customer';
        }

        // do textmodule update
        $('#TextModulesSelectionContainer').addClass('Center').html(loader);
        URL = Core.Config.Get('CGIHandle') + '?Action=TextModuleAJAXHandler;Subaction=LoadTextModules;TicketID=' + TicketID + ';TypeID=' + TypeID + ';QueueID='
            + QueueID + ';StateID=' + StateID + ';CustomerUserID=' + CustomerUserID + ';Frontend=' + Frontend;
        Core.AJAX.ContentUpdate($TMTree, URL, function() {
            if (Core.Config.Get('TextModulesDisplayType') == 'List') {
                Core.KIX4OTRS.TextModules.InitList();
            } else {
                Core.KIX4OTRS.TextModules.InitTree();
            }
        });

        return;
    }

    TargetNS.GetTextmodule = function(ID) {
        var Frontend = 'Agent',
            QueueID,
            TicketID,
            TypeID,
            CustomerUserID,
            URL;

        $('#' + ID).addClass('Loader');

        // determine QueueID
        if ($('#NewQueueID').length) {
            QueueID = $('#NewQueueID').val();
        } else if ($('#Dest').length) {
            QueueID = $('#Dest').val().split('||')[0];
        }

        // determine TicketID
        if ($('#TextModulesSelectionContainer').closest('form').find('input[name=TicketID]').length) {
            TicketID = $('#TextModulesSelectionContainer').closest('form').find('input[name=TicketID]').val();
        }
        else if ($('#Compose').find('input[name=TicketID]').length) {
             TicketID = $('#Compose').find('input[name=TicketID]').val();
        }

        // determine TypeID
        if ($('#TypeID').length) {
            TypeID = $('#TypeID').val();
        }

        // determine CustomerUserID
        if ($('#SelectedCustomerUser').length) {
            CustomerUserID = $('#SelectedCustomerUser').val();
        }

        // determine Frontend
        if ($(location).attr('href').search(/customer\.pl/) > 0) {
            Frontend = 'Customer';
        }

        if (!TextModules[ID]) {
            var Data = {
                    Action : 'TextModuleAJAXHandler',
                    Subaction : 'LoadTextModule',
                    ID : ID,
                    TicketID : TicketID,
                    QueueID : QueueID,
                    TypeID : TypeID,
                    CustomerUserID : CustomerUserID,
                    Frontend : Frontend
                };
            Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function(Response) {
                TextModules[ID] = Response;
            }, 'json', false);
        }

        $('#' + ID).removeClass('Loader');

        return TextModules[ID];
    }

    TargetNS.InitList = function() {
        // this is needed, because TextModulePreviewContainer will be loaded dynamically and therefore may be an empty selection during JS init
        $TMPreviewContainer = $('#TextModulePreviewContainer');

        $TMTable.find('div.TextModule').on({
            click : function(Event) {
                if ($(this).attr('id') != SelectedTextModuleID) {
                    // remove old selection
                    $(this).parent().find('div.TextModule.Selected').each(function() {
                        $(this).removeClass('Selected');
                    });
                    SelectedTextModuleID = $(this).attr('id');
                    $(this).addClass('Selected');
                } else {
                    SelectedTextModuleID = -1;
                    $(this).removeClass('Selected');
                }
            },
            dblclick : function(Event) {
                SelectedTextModuleID = $(this).attr('id');
                InsertTextmodule($(this).attr('id'));
            }
        });

        // bind insert-event on button
        $('#TextModuleInsert').on('click', function() {
            SelectedTextModuleID = $('#TextModulesSelectionContainer').find('.TextModule.Selected').attr('id');
            if (SelectedTextModuleID > 0)
                InsertTextmodule(SelectedTextModuleID);
        });

        // bind preview-event on button
        $('#TextModulePreview').on('click', function(Event) {
            SelectedTextModuleID = $('#TextModulesSelectionContainer').find('.TextModule.Selected').attr('id');
            if (SelectedTextModuleID > 0) {
                PreviewTextmodule(Event, SelectedTextModuleID);
                $TMPreviewContainer.on('click', function() {
                    $TMPreviewContainer.hide();
                });
            }
        });

        // bind close preview on button
        $('#TextModulePreviewClose').on('click', function(Event) {
            $TMPreviewContainer.hide();
            Event.preventDefault();
        });

        // bind remove-event on button
        $('#TextModuleUndo').on('click', function() {
            UndoTextmodule('RichText');
        });

        return;
    }

    TargetNS.InitTree = function() {
        // this is needed, because TextModulePreviewContainer will be loaded dynamically and therefore may be an empty selection during JS init
        $TMPreviewContainer = $('#TextModulePreviewContainer');

        // create tree
        $('#TextModulesSelectionContainer')
            .jstree({
                core: {
                    animation: 70,
                    dblclick_toggle: false,
                    expand_selected_onload: true,
                    themes: {
                        name: 'InputField',
                        variant: 'Tree',
                        icons: true,
                        dots: true,
                    }
                },
                types : {
                default : {
                  icon : 'fa fa-file-text-o'
                },
                category : {
                    icon : 'fa fa-folder-open-o'
                  },
              },
              plugins: [ 'types' ]
        });

        // expand or collapse text module view
        $('#CategoryTreeToggle').on('click', function(Event) {
            // get more space for ticket list
            if (!$('.SidebarColumn').hasClass('Collapsed W35px')) {
                $('.ContentColumn').css({
                    "margin-left" : "0px"
                });
            } else {
                $('.ContentColumn').css({
                    "margin-left" : SidebarWidth
                });
            }

            $('.CategoryTreeContent').animate({
                width : 'toggle'
            }, 100);
            $('#CategoryTreeControl').animate({
                width : 'toggle'
            }, {
                duration : 50,
                complete : function() {
                    $(this).closest('.SidebarColumn').toggleClass('Collapsed W35px');
                    Core.UI.InitTableHead($('#FixedTable thead'), $('#FixedTable tbody'));
                }
            });
        });

        $('#TextModulesSelectionContainer').on("dblclick", 'a', function(e) {
            if ($(this).children('span').hasClass('TextModule')) {
                UpdateTextmodule($(this).children('span').attr('id'));
            }
        }).on("click", 'a', function(e) {
            if ($(this).children('span').hasClass('TextModuleCategory')) {
                $('#TextModulesSelectionContainer').jstree(true).toggle_node(e.target);
            }
        }).on("mousemove", 'a', function(e) {
            if ($(this).children('span').hasClass('TextModule')) {
                var PreviewPosition = Core.KIX4OTRS.GetWidgetPopupPosition($TMPreviewContainer.parent(), Event);
            }
        });

        // bind insert-event on button
        $('#TextModuleInsert').on('click', function(Event) {
            SelectedTextModuleID = $('#TextModulesSelectionContainer a.jstree-clicked > span').attr('id');
            if (SelectedTextModuleID > 0)
                InsertTextmodule(SelectedTextModuleID);
            Event.preventDefault();
        });

        // bind preview-event on button
        $('#TextModulePreview').on('click', function(Event) {
            SelectedTextModuleID = $('#TextModulesSelectionContainer a.jstree-clicked > span').attr('id');
            if (SelectedTextModuleID > 0) {
                PreviewTextmodule(Event, SelectedTextModuleID);
                $TMPreviewContainer.on('click', function() {
                    $TMPreviewContainer.hide();
                });
            }
            Event.preventDefault();
        });

        // bind close preview on button
        $('#TextModulePreviewClose').on('click', function(Event) {
            $TMPreviewContainer.hide();
            Event.preventDefault();
        });

        return;
    }

    TargetNS.Init = function() {

        // get action (first for use with tabs)
        var Action = $('#TextModulesSelectionContainer').closest('form').find('input[name=Action]').val();
        // get action in TicketEmail / Phone and customer frontend
        if (Action === undefined) {
            Action = $('.ContentColumn').find('input[name=Action]').val();
        }

        // don't use AJAX refresh in CustomerTicketMessage
        if (Action !== undefined) {

            if ($('#TypeID').length) {
                // bind ajax reload on TypeID dropdown
                $('#TypeID').on('change', function() {
                    RefreshTextmodules();
                });
            }

            if ($('#NewQueueID').length) {
                // bind ajax reload on NewQueueID dropdown (AgentTicketActionCommon)
                $('#NewQueueID').on('change', function() {
                    RefreshTextmodules();
                });
            }

            else if ($('#Dest').length) {
                // bind ajax reload on Dest dropdown (AgentTicketPhone)
                $('#Dest').on('change', function() {
                    RefreshTextmodules();
                });
            }

            if ($('#SelectedCustomerUser').length) {
                // bind ajax reload on SelectedCustomerUser dropdown (AgentTicketPhone / AgentTicketEmail)
                $('#SelectedCustomerUser').on('change', function() {
                    RefreshTextmodules();
                });
            }

            if ($('#NextStateID').length) {
                // bind ajax reload on NextState dropdown (AgentTicketPhone / AgentTicketEmail)
                $('#NextStateID').on('change', function() {
                    RefreshTextmodules();
                });
            }

            $('#TextModules .WidgetAction.Toggle').on('click', function() {
                // load text modules on first expand
                if ($('#TextModules').hasClass('Collapsed') && $TMTable.find('div.TextModule').length == 0)
                    RefreshTextmodules();
            });
        }

        if (Core.Config.Get('TextModulesDisplayType') == 'List') {
            TargetNS.InitList();
        } else {
            TargetNS.InitTree();
        }
        return true;
    }

    return TargetNS;
}(Core.KIX4OTRS.TextModules || {}));
