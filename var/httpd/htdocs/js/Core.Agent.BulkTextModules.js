// --
// Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

/**
 * @namespace
 * @exports TargetNS as Core.Agent.BulkTextModules
 * @description Provides functions for text module support
 */
Core.Agent.BulkTextModules = (function(TargetNS) {
    var TextModules          = new Array(),
        TM_history           = new Array(''),
        SelectedTextModuleID = -1,
        $TMTable             = $('#BulkTextModulesTable'),
        $TMTree              = $('#BulkTextModulesSelection'),
        $TMPreviewContainer  = $('#BulkTextModulePreviewContainer'); // just to have a valid selection object

    function InsertTextmodule(ID) {
        // get data from selected text module and create short alias
        var input      = document.compose.Body,
            subject    = document.compose.Subject,
            TextModule = TargetNS.GetTextmodule(ID), // get TextModule
            focus      = document.compose.BulkTextModulesFocus.value;

        if ( focus == 'Email' ) {
            input   = document.compose.EmailBody;
            subject = document.compose.EmailSubject;
        }
        else if ( focus == '' ) {
            return false;
        }

        // insert subject of text module
        if (typeof subject != 'undefined') {
            subject.value = subject.value + ' ' + TextModule.Subject;
        }

        // save last Body
        TM_history.push(input.value);

        // add text module to WYSIWYG editor in opener window
        if (
            typeof(CKEDITOR) !== "undefined"
            && focus == 'Email'
            && CKEDITOR.instances.EmailBody
        ) {
            CKEDITOR.instances.EmailBody.insertHtml(TextModule.TextModule);
            return;
        }
        else if (
            typeof(CKEDITOR) !== "undefined"
            && focus == 'Note'
            && CKEDITOR.instances.Body
        ) {
            CKEDITOR.instances.Body.insertHtml(TextModule.TextModule);
            return;
        }

        // focus orig input field
        input.focus();

        // IE
        if (typeof document.selection != 'undefined') {
            var range   = document.selection.createRange(),
                insText = range.text;

            range.text = TextModule.TextModule + insText;
            range      = document.selection.createRange();
            range.moveStart('character', document.spelling.Body.value.length + insText.length);
            range.select();
        }
        // gecko
        else if (typeof input.selectionStart != 'undefined') {
            var Start = input.selectionStart,
                End   = input.selectionEnd,
                insText,
                pos;

            // set focus to start, if cursor it not dedicated set to the end
            // (only done automaticaly if more then 400 chars avail)
            if (
                input.value.length > 400
                && End == input.value.length
                && Start == input.value.length
            ) {
                Start = 0;
                End   = 0;
            }

            insText     = input.value.substring(Start, End);
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
        var input      = document.compose.Body,
            subject    = document.compose.Subject,
            TextModule = TargetNS.GetTextmodule(ID), // get TextModule
            focus      = document.compose.BulkTextModulesFocus.value;

        if ( focus == 'Email' ) {
            input   = document.compose.EmailBody;
            subject = document.compose.EmailSubject;
        }
        else if ( focus == '' ) {
            return false;
        }

        // insert subject of text module
        if (typeof subject != 'undefined') {
            subject.value = subject.value + ' ' + TextModule.Subject;
        }

        // save last Body
        TM_history.push(input.value);

        // add text module to WYSIWYG editor in opener window
        if (
            typeof(CKEDITOR) !== "undefined"
            && focus == 'Email'
            && CKEDITOR.instances.EmailBody
        ) {
            CKEDITOR.instances.EmailBody.insertHtml(TextModule.TextModule);
            return;
        }
        else if (
            typeof(CKEDITOR) !== "undefined"
            && focus == 'Note'
            && CKEDITOR.instances.Body
        ) {
            CKEDITOR.instances.Body.insertHtml(TextModule.TextModule);
            return;
        }

        // focus orig input field
        input.focus();

        // IE
        if (typeof document.selection != 'undefined') {
            var range   = document.selection.createRange(),
                insText = range.text;

            range.text = TextModule.TextModule + insText;
            range      = document.selection.createRange();
            range.moveStart('character', document.spelling.Body.value.length + insText.length);
            range.select();
        }
        // gecko
        else if (typeof input.selectionStart != 'undefined') {
            var Start = input.selectionStart,
                End   = input.selectionEnd,
                insText,
                pos;

            // set focus to start, if cursor it not dedicated set to the end
            // (only done automaticaly if more then 400 chars avail)
            if (
                input.value.length > 400
                && End == input.value.length
                && Start == input.value.length
            ) {
                Start = 0;
                End   = 0;
            }

            insText     = input.value.substring(Start, End);
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
        var PositionTop,
            PreviewPosition,
            $Title   = $TMPreviewContainer.find('.Header').find('#TMTitle'),
            $Subject = $TMPreviewContainer.find('.Content').find('#TMSubject'),
            $Body    = $TMPreviewContainer.find('.Content').find('#TMBody'),
            loader   = '<span class="Loader"></span>';

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
        var URL,
            loader = '<span class="Loader"></span>';

        $('#BulkTextModulesSelectionContainer').addClass('Center').html(loader);

        // do textmodule update
        $('#BulkTextModulesSelectionContainer').addClass('Center').html(loader);

        URL = Core.Config.Get('CGIHandle')
            + '?Action=BulkTextModuleAJAXHandler;Subaction=LoadTextModules;';

        Core.AJAX.ContentUpdate($TMTree, URL, function() {
            if (Core.Config.Get('TextModulesDisplayType') == 'List') {
                TargetNS.InitList();
            } else {
                TargetNS.InitTree();
            }
        });

        return;
    }

    TargetNS.GetTextmodule = function(ID) {

        $('#' + ID).addClass('Loader');

        if (!TextModules[ID]) {
            var Data = {
                    Action:    'BulkTextModuleAJAXHandler',
                    Subaction: 'LoadTextModule',
                    ID:        ID,
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
        $TMPreviewContainer = $('#BulkTextModulePreviewContainer');

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
        $('#BulkTextModuleInsert').off('click').on('click', function() {
            SelectedTextModuleID = $('#BulkTextModulesSelectionContainer').find('.TextModule.Selected').attr('id');
            if (SelectedTextModuleID > 0)
                InsertTextmodule(SelectedTextModuleID);
        });

        // bind preview-event on button
        $('#BulkTextModulePreview').off('click').on('click', function(Event) {
            SelectedTextModuleID = $('#BulkTextModulesSelectionContainer').find('.TextModule.Selected').attr('id');
            if (SelectedTextModuleID > 0) {
                PreviewTextmodule(Event, SelectedTextModuleID);
                $TMPreviewContainer.bind('click', function() {
                    $TMPreviewContainer.hide();
                });
            }
        });

        // bind close preview on button
        $('#BulkTextModulePreviewClose').off('click').on('click', function(Event) {
            $TMPreviewContainer.hide();
            Event.preventDefault();
        });

        // bind remove-event on button
        $('#BulkTextModuleUndo').off('click').on('click', function() {
            UndoTextmodule('RichText');
        });

        return;
    }

    TargetNS.InitTree = function() {
        // this is needed, because BulkTextModulePreviewContainer will be loaded dynamically and therefore may be an empty selection during JS init
        $TMPreviewContainer = $('#BulkTextModulePreviewContainer');

        // create tree
        $('#BulkTextModulesSelectionContainer')
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
        $('#BulkCategoryTreeToggle').off('click').on('click', function(Event) {
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

        $('#BulkTextModulesSelectionContainer').on("dblclick", 'a', function(e) {
            if ($(this).children('span').hasClass('TextModule')) {
                UpdateTextmodule($(this).children('span').attr('id'));
            }
        }).on("click", 'a', function(e) {
            if ($(this).children('span').hasClass('TextModuleCategory')) {
                $('#BulkTextModulesSelectionContainer').jstree(true).toggle_node(e.target);
            }
        }).on("mousemove", 'a', function(e) {
            if ($(this).children('span').hasClass('TextModule')) {
                var PreviewPosition = Core.KIX4OTRS.GetWidgetPopupPosition($TMPreviewContainer.parent(), Event);
            }
        });

        // bind insert-event on button
        $('#BulkTextModuleInsert').on('click', function(Event) {
            SelectedTextModuleID = $('#BulkTextModulesSelectionContainer a.jstree-clicked > span').attr('id');
            if (SelectedTextModuleID > 0)
                InsertTextmodule(SelectedTextModuleID);
            Event.preventDefault();
        });

        // bind preview-event on button
        $('#BulkTextModulePreview').on('click', function(Event) {
            SelectedTextModuleID = $('#BulkTextModulesSelectionContainer a.jstree-clicked > span').attr('id');
            if (SelectedTextModuleID > 0) {
                PreviewTextmodule(Event, SelectedTextModuleID);
                $TMPreviewContainer.off('click').on('click', function() {
                    $TMPreviewContainer.hide();
                });
            }
            Event.preventDefault();
        });

        // bind close preview on button
        $('#BulkTextModulePreviewClose').off('click').on('click', function(Event) {
            $TMPreviewContainer.hide();
            Event.preventDefault();
        });

        return;
    }

    TargetNS.Init = function() {

        // get action (first for use with tabs)
        var Action = $('#BulkTextModulesSelectionContainer').closest('form').find('input[name=Action]').val(),
            Config = Core.Config.Get('FocusTypes');

        // get action in TicketEmail / Phone and customer frontend
        if (Action === undefined) {
            Action = $('.ContentColumn').find('input[name=Action]').val();
        }

        // don't use AJAX refresh
        if (Action !== undefined) {

            $('#BulkTextModules .WidgetAction.Toggle').bind('click', function() {
                // load text modules on first expand
                if ($('#BulkTextModules').hasClass('Collapsed') && $TMTable.find('div.TextModule').length == 0)
                    RefreshTextmodules();
            });
        }

        if (Core.Config.Get('TextModulesDisplayType') == 'List') {
            TargetNS.InitList();
        } else {
            TargetNS.InitTree();
        }

        $('#BulkTextModulesFocusType').html(Config.None);
        $('#BulkTextModulesButtons').addClass('Hidden');

        $('.ContentColumn .WidgetAction.Toggle').on('click', function () {
            var ID    = $(this).closest('.WidgetSimple').find('textarea').attr('id'),
                Check = ID.replace('Body',''),
                $Elem = $(this).closest('.WidgetSimple');

            if ( $Elem.hasClass('Expanded') ) {

                $('#BulkTextModulesButtons').removeClass('Hidden');
                if ( Check.length ) {
                    $('#BulkTextModulesFocusType').html(Config.Email);
                    $('#BulkTextModulesFocus').val('Email');
                }
                else {
                    $('#BulkTextModulesFocusType').html(Config.Note);
                    $('#BulkTextModulesFocus').val('Note');
                }
            } else {
                if ( Check.length ) {
                    $Elem = $('#Body' ).closest('.WidgetSimple');
                    if ( $Elem.hasClass('Expanded') ) {
                        $('#BulkTextModulesFocusType').html(Config.Note);
                        $('#BulkTextModulesFocus').val('Note');
                        $('#BulkTextModulesButtons').removeClass('Hidden');
                    }
                    else {
                        $('#BulkTextModulesFocusType').html(Config.None);
                        $('#BulkTextModulesFocus').val('');
                        $('#BulkTextModulesButtons').addClass('Hidden');
                    }
                }
                else {
                    $Elem = $('#EmailBody' ).closest('.WidgetSimple');
                    if ( $Elem.hasClass('Expanded') ) {
                        $('#BulkTextModulesFocusType').html(Config.Email);
                        $('#BulkTextModulesFocus').val('Email');
                        $('#BulkTextModulesButtons').removeClass('Hidden');
                    }
                    else {
                        $('#BulkTextModulesFocusType').html(Config.None);
                        $('#BulkTextModulesFocus').val('');
                        $('#BulkTextModulesButtons').addClass('Hidden');
                    }
                }
            }
        });
        $('.ContentColumn > .WidgetSimple > .Content').on('click', function () {
            var ID    = $(this).find('textarea').attr('id'),
                Check = ID.replace('Body','');

            if ( Check.length ) {
                $('#BulkTextModulesFocusType').html(Config.Email);
                $('#BulkTextModulesFocus').val('Email');
            }
            else {
                $('#BulkTextModulesFocusType').html(Config.Note);
                $('#BulkTextModulesFocus').val('Note');
            }
        });
        return true;
    }

    return TargetNS;
}(Core.Agent.BulkTextModules || {}));
