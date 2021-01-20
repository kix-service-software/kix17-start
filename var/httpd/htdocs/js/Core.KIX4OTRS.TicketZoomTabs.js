// --
// Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
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
 * @exports TargetNS as Core.KIX4OTRS.TicketZoomTabs
 * @description This namespace contains the special module functions for
 *              TicketZoomTab.
 */
Core.KIX4OTRS.TicketZoomTabs = (function(TargetNS) {

    /**
     * @function
     * @param {String}
     *            TicketID of ticket which get's shown
     * @param {String}
     *            Timeout in miliseconds to wait before function call
     * @return nothing Mark all articles as seen in frontend and backend.
     *         Article Filters will not be considered
     */
    TargetNS.MarkTicketAsSeen = function (TicketID, Timeout) {
        if (isNaN(Timeout)) {
            Timeout = 3000;
        }
        TargetNS.TicketMarkAsSeenTimeout = window.setTimeout(function () {
            // Mark old row as readed
            $('#ArticleTable .ArticleID').closest('tr').removeClass('UnreadArticles').find('span.UnreadArticles').remove();

            // Mark article as seen in backend
            var Data = {
                // Action: 'AgentTicketZoom',
                Action : 'AgentTicketZoomTabArticle',
                Subaction: 'TicketMarkAsSeen',
                TicketID: TicketID
            };
            Core.AJAX.FunctionCall(
                Core.Config.Get('CGIHandle'),
                Data,
                function () {}
            );
        }, Timeout);
    };

    /**
     * @function
     * @param {String}
     *            TicketID of ticket which get's shown
     * @param {String}
     *            ArticleID of article which get's shown
     * @return nothing Mark an article as seen in frontend and backend.
     */
    TargetNS.MarkAsSeen = function(TicketID, ArticleID) {
        TargetNS.MarkAsSeenTimeout = window.setTimeout(function() {
            // Mark old row as readed
            $('#ArticleTable .ArticleID[value=' + ArticleID + ']').closest('tr').removeClass('UnreadArticles').find('span.UnreadArticles').remove();

            // Mark article as seen in backend
            var Data = {
                    // Action: 'AgentTicketZoom',
                    Action : 'AgentTicketZoomTabArticle',
                    Subaction : 'MarkAsSeen',
                    TicketID : TicketID,
                    ArticleID : ArticleID
                };
            Core.AJAX.FunctionCall(
                Core.Config.Get('CGIHandle'),
                Data,
                function () {}
            );
        }, 3000);
    };

    /**
     * @function
     * @return nothing This function sets a new width for the column which
     *         contents the article flag icons
     */
    TargetNS.SetArticleFlagColumnWidth = function() {
        var CounterArray = new Array(), CountMax = 0, IconWidth = 16; // used space for one icon (pixel)

        // count flag icons for each article
        $(' td .UnreadArticles').find('.FlagIcon').each(function() {
            var InformationArray = $(this).attr('id').split("_"), ArticleID = InformationArray[1];

            if (CounterArray[ArticleID]) {
                CounterArray[ArticleID]++;
            } else {
                CounterArray[ArticleID] = 1;
            }

            // get max count
            if (CounterArray[ArticleID] > CountMax) {
                CountMax = CounterArray[ArticleID];
            }

        });

        // set new width for column
        if (CountMax) {
            var TdWidth = CountMax * IconWidth;
            $('td .UnreadArticles').css({
                "width" : TdWidth
            });
        }
    };

    /**
     * @function
     * @return nothing This function shows the article flag options dialog box (
     *         edit / delete )
     */
    TargetNS.ShowArticleFlagOptionsDialog = function(ArticleOptionsText) {
        $('#ArticleTable .FlagIcon').each(function() {
            var FlagInformationArray = $(this).attr('id').split("_"),
                ArticleID = FlagInformationArray[1],
                ArticleFlagKey = FlagInformationArray[2],
                Position = $(this).offset();

            $(this).unbind('click').bind('click', function(event) {
                if ( $('#ArticleFlagOptions_' + ArticleID + '_' + ArticleFlagKey).length ) {
                    Core.UI.Dialog.ShowContentDialog($('#ArticleFlagOptions_' + ArticleID + '_' + ArticleFlagKey), ArticleOptionsText, Position.top, parseInt(Position.left, 10) + 25);
                }
                event.preventDefault();
                return false;
            });
        });
    };

    /**
     * @function
     * @return nothing This function adds a new flag to an article
     */
    TargetNS.ArticleFlagAdd = function($Element, ApplyText, SetText) {

        var ArticleFlagKey = $Element.val(),
            ArticleFlagValue = $Element.html(),
            FormID = $Element.parent().attr('id').split('_'),
            ArticleID = FormID[1],
            $DialogBox = $('#ArticleFlagDialog');

        $DialogBox.find('input[name=ArticleFlagKey]').val(ArticleFlagKey);
        $DialogBox.find('input[name=ArticleID]').val(ArticleID);

        if (ArticleFlagKey != 0) {
            if (Core.Config.Get('ArticleFlagsWithoutEdit::' + ArticleFlagKey) === "1") {
                var $FormID = $('#ArticleFlagDialogForm'), Data = Core.AJAX.SerializeForm($FormID);

                Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function() {
                    location.reload();
                }, 'text');

                // show overlay screen as reaction
                $('<div id="Overlay" tabindex="-1">').appendTo('body');
                $('body').css({
                    'overflow': 'hidden'
                });
                $('#Overlay').height($(document).height()).css('top', 0).css('cursor', 'wait');
                $('body').css('min-height', $(window).height());
            }
            else {

                Core.UI.Dialog.ShowContentDialog(
                    $('#ArticleFlagDialog'),
                    SetText + ' ' + ArticleFlagValue + ' for Article #' + ArticleID,
                    '20px',
                    'Center',
                    true,
                    [
                        {
                            Label : ApplyText,
                            Function : function() {
                                var $FormID = $('#ArticleFlagDialogForm'), Data = Core.AJAX.SerializeForm($FormID);

                                Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function() {
                                    location.reload();
                                }, 'text');
                            }
                        }
                    ]
                );
            }
        }
        return false;
    };

    /**
     * @function
     * @return nothing This function executes the article flag options like
     *         edit, show or delete
     */
    TargetNS.ArticleFlagOptions = function(TicketID, ApplyText, SetText, ArticleText) {

        $(document.body).on('click', '.ArticleFlagOptionsDialog > a', function(event) {

            var FlagString = $(this).attr('rel'),
                FlagInformationArray = FlagString.split("_"),
                ArticleFlagKey = FlagInformationArray[1],
                Title = $(this).attr('title'),
                TitleArray = Title.split(" "),
                ArticleFlagValue = TitleArray[4],
                Action = $(this).attr('data-action'),
                ArticleID = FlagInformationArray[0];

            if (Action == 'show') {
                if ( $('#ArticleFlagDialog_' + FlagString + ' input[readonly=readonly]').length ) {
                    Core.UI.Dialog.ShowContentDialog(
                        $('#ArticleFlagDialog_' + FlagString),
                        SetText + ' ' + ArticleFlagValue + ' ' + ArticleText + ' #' + ArticleID,
                        '20px',
                        'Center',
                        true,
                        []
                    );
                }
                else {
                    Core.UI.Dialog.ShowContentDialog(
                        $('#ArticleFlagDialog_' + FlagString),
                        SetText + ' ' + ArticleFlagValue + ' for Article #' + ArticleID,
                        '20px',
                        'Center',
                        true,
                        [
                            {
                                Label : ApplyText,
                                Function : function() {
                                    var $FormID = $('#ArticleFlagDialog_' + FlagString + '_Form'),
                                        Data = Core.AJAX.SerializeForm($FormID);

                                    Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), Data, function() {
                                        location.reload();
                                    }, 'text');
                                }
                            }
                        ]
                    );
                }
                $('.Dialog').css({ "width" : "530px" });
            } else {
                var URL = Core.Config.Get('CGIHandle') + '?Action=AgentTicketZoomTabArticle;Subaction=ArticleFlagDelete;TicketID=' + TicketID
                    + ';ArticleID=' + ArticleID + ';ArticleFlagKey=' + ArticleFlagKey;

                Core.AJAX.ContentUpdate($('#ArticleFlag_' + FlagString), URL, function() {});
            }

            $('.ArticleFlagOptionsDialog').closest('.Dialog').addClass('Hidden');
            event.preventDefault();
        });
    };

    /**
     * @function
     * @return nothing This function initializes the application and executes
     *         the needed functions the differenct to the global init function
     *         is the disabled InitNavigation call.
     */
    TargetNS.Init = function() {
        var Action = Core.Config.Get('Action');

        // for tab init we must not run InitNavigation again
        // InitNavigation();
        Core.Exception.Init();

        // init widget toggle
        if ( Action.match(/AgentTicketZoomTab/) ) {
            Core.UI.InitWidgetActionTabToggle();
        }
        Core.UI.InitMessageBoxClose();
        Core.Form.Validate.Init();
        if ( Action.match(/AgentTicketZoomTab/) ) {
            Core.UI.InputFields.Init();
            Core.UI.InputFields.CloseAllOpenFieldsInTabs();
            Core.UI.Popup.Init();
        }
        // late execution of accessibility code
        Core.UI.TreeSelection.InitTreeSelection();
        Core.UI.TreeSelection.InitDynamicFieldTreeViewRestore();
        // late execution of accessibility code
        Core.UI.Accessibility.Init();
    };

    /**
     * @function
     * @return nothing This function initializes the pop up views for all
     *         relevant ticket actions
     */
    TargetNS.PopUpInit = function() {
        // $('a.TabAsPopup').removeAttr('onClick');
        $('a.TabAsPopup').bind('click', function(Event) {
            var Matches, PopupType = 'TicketAction';

            Matches = $(this).attr('class').match(/PopupType_(\w+)/);
            if (Matches) {
                PopupType = Matches[1];
            }
            $(this).addClass('PopupCalled');
            $('a.TabAsPopup.PopupCalled').removeAttr('onClick');
            $('a.TabAsPopup.PopupCalled').bind('click', function(Event) {
                $(this).removeClass('PopupCalled');
                return false;
            });
            Core.UI.Popup.OpenPopup($(this).attr('href'), PopupType);
            return false;
        });
    };

    /**
     * @function
     * @return nothing
     * @description This namespace contains the special module functions for
     *              TicketZoomTabAttachments.
     */
    TargetNS.AttachmentsInit = function(Options) {
        var $THead = $('#AttachmentTable thead'), $TBody = $('#AttachmentTable tbody');

        // Table sorting
        Core.UI.Table.Sort.Init($('#AttachmentTable'), function() {
            $(this).find('tr').removeClass('Even').filter(':even').addClass('Even').end().removeClass('Last').filter(':last').addClass('Last');
        });
    };

    return TargetNS;
}(Core.KIX4OTRS.TicketZoomTabs || {}));
