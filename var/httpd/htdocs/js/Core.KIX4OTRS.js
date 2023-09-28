// --
// Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS
 * @description This namespace contains the special module functions for
 *              KIX4OTRS
 */
Core.KIX4OTRS = (function(TargetNS) {

    TargetNS.GetWidgetPopupPosition = function(Element, Event) {
        if (!$(Element).find('.WidgetPopup').length) {
            return {
                Left : 0,
                Top : 0
            };
        }

        var $Details = $(Element).find('.WidgetPopup'),
            MousePositionLeft = parseInt(Event.pageX, 10),
            MousePositionTop = parseInt(Event.pageY, 10),
            DetailHeight = $Details.height(),
            DetailWidth = $Details.width(),
            DetailPositionLeft = MousePositionLeft - 30,
            DetailPositionTop = MousePositionTop + 30;

        if (DetailPositionLeft + DetailWidth + 15 > $(window).width()) {
            DetailPositionLeft = DetailPositionLeft - DetailWidth - 30;
        }
        if (DetailPositionTop + DetailHeight + 15 > $(window).height()) {
            DetailPositionTop = DetailPositionTop - DetailHeight - 30;
        }
        if (DetailPositionTop < 0) {
            DetailPositionTop = MousePositionTop + 30;
        }

        return {
            Left : DetailPositionLeft,
            Top : DetailPositionTop
        };
    }

    TargetNS.SelectLinkedObjects = function(Action) {

        var $Tabs = $(".ui-tabs-tab"),
            $CurrentTab,
            TabIndex,
            search    = window.location.search,
            hash      = window.location.hash,
            origin    = window.location.origin,
            path      = window.location.pathname,
            patternST = /.*SelectedTab=\d+/g,
            hasST     = patternST.exec(search),
            uri;

        $.each($Tabs, function() {
            if ($(this).attr('aria-expanded') == 'true') {
                var TabID   = $(this).attr('aria-controls'),
                    Link    = $(this).children().attr('href'),
                    patternTI = /.*TabIndex=(\d+)/g;

                $CurrentTab = $('#' + TabID);
                if ( hasST == null ) {
                    TabIndex = patternTI.exec(Link);
                    if (TabIndex.length == 2) {
                        uri = origin + path + search + ';SelectedTab=' + TabIndex[1] + hash;
                    }
                }
                return false;
            }
        });

        // bind delete button
        $CurrentTab.find('.Primary').on('click', function() {
            var $SelectedLinks = $(this).parent().parent().find('input:checked');

            if ($SelectedLinks.length == 0) {
                return;
            }

            // ask the user
            var Type     = Core.Config.Get('Question'),
                Question = '<p class="Spacing">' + Core.Config.Get('DeleteLinksQuestion') + '</p>',
                Yes      = Core.Config.Get('Yes'),
                No       = Core.Config.Get('No');

            Core.KIX4OTRS.Dialog.ShowQuestion(Type, Question, Yes, function() {
                // Yes - delete links
                Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                $SelectedLinks.each(function() {
                    var LinkDef = $(this).val().split(/::/),
                        URL = 'Action=AgentLinkObjectUtils;Subaction=DeleteLink;IsAJAXCall=1;OrgAction=' + Action
                        + ';SourceObject=' + LinkDef[0] + ';SourceKey=' + LinkDef[1] + ';TargetObject=' + LinkDef[2] + ';TargetKey=' + LinkDef[3]
                        + ';LinkType=' + LinkDef[4];
                    if ( LinkDef[0] === 'on' ) {
                        return true;
                    }
                    // synchronous call
                    Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'text', false);
                });
                if ( uri ) {
                    location.replace(uri);
                }
                else {
                    location.reload();
                }
            }, No, function() {
                // No
                Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
            });
        });
    }

    /**
     * @function
     * @private
     * @description Load a draft
     */

    TargetNS.LoadDraft = function(Action, TicketID, FormID, Question) {
        // if not given, determine Action

        if ( !Action )
            Action = $('#SaveAsDraft').closest('form').children('input[name=Action]').val();

        // if not given, determine FormID
        if ( !FormID ) {
            var ID = $('#SaveAsDraft').closest('form').children('input[name=FormID]').val();
            if ( ID && ID != '' ) {
                FormID = $('#SaveAsDraft').closest('form').children('input[name=FormID]').val();
            }
            else {
                FormID = 0;
            }
        }

        // if not given, determine TicketID
        if ( !TicketID ) {
            var ID = $('#SaveAsDraft').closest('form').children('input[name=TicketID]').val();
            if ( ID && ID != '' ) {
                TicketID = $('#SaveAsDraft').closest('form').children('input[name=TicketID]').val();
            }
            else {
                TicketID = 0;
            }
        }

        // no action and TicketID - return
        if ( !Action )
            return;

        // get saved form
        var URL = Core.Config.Get('Baselink'),
            Data = {
            Action : 'SaveAsDraftAJAXHandler',
            Subaction : 'GetFormContent',
            CallingAction : Action,
            FormID : FormID,
            TicketID : TicketID
            },
            ContentExists = false,
            Content;

        Core.AJAX.FunctionCall(URL, Data, function(Result) {
            Content = Result;
            $.each(Result, function() {
                if (this.Label == 'Body' && window.CKEDITOR && CKEDITOR.instances.RichText) {
                    ContentExists = ContentExists || (this.Value != '');
                } else {
                    ContentExists = ContentExists || (($('#' + this.Label).length) && (this.Value != ''));
                }
            });

            // if form exists, ask to use or to delete it
            if (ContentExists === true) {
                if (!Question)
                    Question = Core.Config.Get('LoadDraftMsg');

                Core.KIX4OTRS.Dialog.ShowQuestion(Core.Config.Get('Question'), Question, Core.Config.Get('Load'), function() {
                    // Yes - load form content from WebUpload Cache
                    Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
                    $.each(Content, function() {
                        if ($('#' + this.Label).length) {
                            $('#' + this.Label).val(this.Value);
                        } else if (this.Label == 'Body' && window.CKEDITOR && CKEDITOR.instances.RichText) {
                            CKEDITOR.instances.RichText.setData(this.Value, function() {
                                this.updateElement();   // sync data to base element
                            });
                        }
                        else if (this.Label == 'Body' && !$('#' + this.Label).length && $('#RichText').length) {
                            $('#RichText').val(this.Value);
                        }
                    });
                }, Core.Config.Get('Delete'), function() {
                    DeleteDraft(Action, TicketID);
                });
            }
        }, 'json');
    }

    /**
     * @function
     * @private
     * @description Saves form content as draft
     */

    function SaveDraft() {
        var $Form = $('#SaveAsDraft').closest('form'),
            Data;

        // some special handling for CKEDITOR
        if ( typeof(CKEDITOR) !== "undefined" && CKEDITOR.instances.RichText) {
            CKEDITOR.instances.RichText.updateElement();
        }

        // prepare data
        Data = Core.AJAX.SerializeForm($Form);
        Data = Data.replace(/Action=/g, 'CallingAction=');
        Data = Data.replace(/Subaction=(.*?)\;/g, '');

        // prepare url
        URL = 'Action=SaveAsDraftAJAXHandler;Subaction=SaveFormContent;' + Data;

        // save content and do not submit form
        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'json');
        return false;
    }

    /**
     * @function
     * @private
     * @description delete a saved draft
     */

    function DeleteDraft(Action, TicketID) {

        // No - delete form content from WebUpload Cache
        Core.UI.Dialog.CloseDialog($('.Dialog:visible'));
        URL = 'Action=SaveAsDraftAJAXHandler;Subaction=DeleteFormContent;CallingAction=' + Action + ';TicketID=' + TicketID;
        Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), URL, function() {}, 'json');
    }

    /**
     * @function Saves form content as draft, deletes old drafts
     * @param {String}
     *            calling action
     * @param {String}
     *            dialog question
     * @param {String}
     *            save interval in milliseconds
     */

    TargetNS.InitSaveAsDraft = function(Action, Question, Interval, InitialLoadDraft) {
        // get form
        var $Form = $('#SaveAsDraft').closest('form'),
            ActiveInterval,
            Attributes = Core.Config.Get('Attributes').split(","),
            AttributeString = '',
            FormID = $Form.find('input[name="FormID"]').val() || '';
            TicketID = $Form.find('input[name="TicketID"]').val() || '';

        // on submit stop timer
        $Form.submit(function() {
            clearInterval(ActiveInterval);
        });

        // delete draft when clicking on Cancel link
        $('div.Header a.CancelClosePopup').on('click', function() {
            DeleteDraft(Action, TicketID);
        });

        // save content after clicking the "Save As Draft" button
        $(document).on('click', '#SaveAsDraft', function(event) {
            SaveDraft();
        });

        // reset intervall if keypressed in RichTextEditor
        if (window.CKEDITOR && CKEDITOR.instances.RichText) {
            CKEDITOR.instances.RichText.on('key', function() {
                window.clearTimeout(ActiveInterval);
                ActiveInterval = window.setTimeout(function() {
                    SaveDraft();
                }, Interval);
            });
        }

        // reset intervall if keypressed in other input fields
        $.each(Attributes, function(Key, Value) {
            Attributes[Key] = '#' + Value;
        });
        AttributeString = Attributes.join(', ');
        $(AttributeString).on('keydown', function(event) {
            window.clearTimeout(ActiveInterval);
            ActiveInterval = window.setTimeout(function() {
                SaveDraft();
            }, Interval);
        });

        if ( InitialLoadDraft !== 'false' ) {
            // show dialog on load if saved form is available
            $(window).on("load", function() {
                TargetNS.LoadDraft(Action, TicketID, FormID, Question);
            });

            // initial call to check for loadable content (necessary for Ticket Tabs)
            TargetNS.LoadDraft(Action, TicketID, FormID, Question);
        }
    }

    /**
     * @function
     * @return nothing
     *      Sets queue if service assigned queue defined
     */

    TargetNS.ServiceAssignedQueue = function() {
        var $Form       = $('#ServiceID').closest('form'),
            $Action     = $Form.find('input[name="Action"]'),
            Selected    = "",
            ActionValue = $Action.val();

        if ( $("#ServiceID").val() != "" ) {
            // set action for AJAX handler
            $Action.val('ServiceAssignedQueueAJAXHandler');

            // get new queue id to set
            Core.AJAX.FunctionCall(Core.Config.Get('Baselink'),Core.AJAX.SerializeForm($Form),function(Response){

                // if queue id given
                if ( Response.AssignedQueue != 0
                     && Response.AssignedQueue !== undefined
                ) {
                    // set queue id for note, close, etc.
                    if ( $("#NewQueueID").length ) {
                        if ( $("#NewQueueID").val() !== Response.AssignedQueue ) {
                            $("#NewQueueID").val(Response.AssignedQueue).trigger('change');
                        }
                    }
                    // set queue id for phone, email, etc.
                    else if ( $("#Dest").length ) {
                        $("#Dest").find("option").each(function(Key,Value){
                            var Expression = "^"+Response.AssignedQueue+"\\|+";
                                CompareRegExp = new RegExp(Expression, "i");
                            if ( CompareRegExp.test($(this).val()) ) {

                                // set new queue
                                $("#Dest").attr($(this).val());

                                // prepare to set new signature
                                var Dest = $("#Dest").val() || '',
                                    Signature,
                                    OldSignature = $("#Signature").length > 0 ? $("#Signature").attr('src') : '',
                                    OldSignatureArray = OldSignature.split(";"),
                                    NewSignatureArray = new Array();

                                // use old values except Dest
                                $.each(OldSignatureArray,function(Key,Value){
                                    if ( Value.match(/^(?!Dest\=).+/)) {
                                        NewSignatureArray.push(Value);
                                    }
                                });

                                // push new queue value
                                NewSignatureArray.push("Dest="+Dest);
                                Signature = NewSignatureArray.join(";");

                                // set signature if given
                                if ( Response.Signature != '' ) {
                                    var CustomerUser = $('#SelectedCustomerUser').val() || '',
                                        SignatureURL = Core.Config.Get("Baselink") + "Action=" + Core.Config.Get("Action") + ";Subaction=Signature;Dest=" + Dest + ';SelectedCustomerUser=' + CustomerUser;

                                    if (!Core.Config.Get('SessionIDCookie')) {
                                        SignatureURL += ';' + Core.Config.Get('SessionName') + '=' + Core.Config.Get('SessionID');
                                    }

                                    $('#Signature').attr('src', SignatureURL);
                                }
                            }
                        });
                    }
                }
            });

            // reset action
            $Action.val(ActionValue);
        }
    }

    return TargetNS;
}(Core.KIX4OTRS || {}));
