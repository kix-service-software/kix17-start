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
Core.UI = Core.UI || {};

/**
 * @namespace Core.UI.Table
 * @memberof Core.UI
 * @author OTRS AG
 * @description
 *      This namespace contains table specific functions.
 */
Core.UI.Table = (function (TargetNS) {
    /**
     * @name InitTableFilter
     * @memberof Core.UI.Table
     * @function
     * @param {jQueryObject} $FilterInput - Filter input element.
     * @param {jQueryObject} $Container - Table or list to be filtered.
     * @param {Number|String} ColumnNumber - Only search in thsi special column of the table (counting starts with 0).
     * @description
     *      This function initializes a filter input field which can be used to
     *      dynamically filter a table or a list with the class TableLike (e.g. in the admin area overviews).
     */
    TargetNS.InitTableFilter = function ($FilterInput, $Container, ColumnNumber) {
        var Timeout;

        $FilterInput.off('keydown.FilterInput').on('keydown.FilterInput', function () {

            window.clearTimeout(Timeout);
            Timeout = window.setTimeout(function () {

                var FilterText = ($FilterInput.val() || '').toLowerCase(),
                    $Rows      = $Container.find('tbody tr:not(.FilterMessage), li:not(.Header):not(.FilterMessage)'),
                    $Elements  = $Rows.closest('tr, li');

                // Only search in one special column of the table
                if (typeof ColumnNumber === 'string' || typeof ColumnNumber === 'number') {
                    $Rows = $Rows.find('td:eq(' + ColumnNumber + ')');
                }

                /**
                 * @private
                 * @name CheckText
                 * @memberof Core.UI.Table.InitTableFilter
                 * @function
                 * @returns {Boolean} True if text was found, false otherwise.
                 * @param {jQueryObject} $Element - Element that will be checked.
                 * @param {String} Filter - The current filter text.
                 * @description
                 *      Check if a text exist inside an element.
                 */
                function CheckText($Element, Filter) {
                    var Text;

                    Text = $Element.text();
                    if (Text && Text.toLowerCase().indexOf(Filter) > -1){
                        return true;
                    }

                    if ($Element.is('li, td')) {
                        Text = $Element.attr('title');
                        if (Text && Text.toLowerCase().indexOf(Filter) > -1) {
                            return true;
                        }
                    }
                    else {
                        $Element.find('td').each(function () {
                            Text = $(this).attr('title');
                            if (Text && Text.toLowerCase().indexOf(Filter) > -1) {
                                return true;
                            }
                        });
                    }

                    return false;
                }

                if (FilterText.length) {
                    $Elements.hide();
                    $Rows.each(function () {
                        if (CheckText($(this), FilterText)) {
                            $(this).closest('tr, li').show();
                        }
                    });
                }
                else {
                    $Elements.show();
                }

                if ($Rows.filter(':visible').length) {
                    $Container.find('.FilterMessage').hide();
                }
                else {
                    $Container.find('.FilterMessage').show();
                }

                Core.App.Publish('Event.UI.Table.InitTableFilter.Change', [$FilterInput, $Container, ColumnNumber]);

            }, 100);
        });

        // Prevent submit when the Return key was pressed
        $FilterInput.off('keypress.FilterInput').on('keypress.FilterInput', function (Event) {
            if ((Event.charCode || Event.keyCode) === 13) {
                Event.preventDefault();
            }
        });
    };

    /**
     * @name InitColumnResize
     * @memberof Core.UI.Table
     * @function
     * @param {jQueryObject} $Element - Table element.
     * @description
     *      This function initializes resizeable columns of a table.
     */
    TargetNS.InitColumnResize = function ($Element, Identifiere, Action, customResizing) {
        var startX,
            startWidth,
            $handle,
            pressed       = false,
            minWidth      = 0,
            tableWidth    = $Element.width(),
            resetIcon     = $Element.closest('.WidgetSimple').find('.ResetColumnWidth'),
            storeResizing = '';

        if ( customResizing ) {
            customResizing = customResizing.split(',');
            if ( customResizing.length === $Element.find('th').length ) {
                resetIcon.removeClass('Hidden');
                $.each(customResizing, function(index, value) {
                    var newWidth = tableWidth * value;
                    $($Element.find('th').get(index)).width(newWidth);
                });
            }
        }

        resetIcon.on('click',function() {
            if ( Identifiere === 'ArticleTable' ) {
                Core.Agent.TicketZoom.AdjustTableHead($Element.children('thead'), $Element.children('tbody'), 0);

            } else {
                $Element.find('th').width('');
            }

            if ( Action.match(/^Customer/) ) {
                Core.Customer.PreferencesUpdate('User' + Identifiere + 'ColumnResizing', '');
            }
            else {
                Core.Agent.PreferencesUpdate('User' + Identifiere + 'ColumnResizing', '');
            }

            Core.Config.Set('UserArticleTableColumnResizing', '');
            customResizing = '';

            resetIcon.addClass('Hidden');
        });

        $Element.addClass('table-resizable');
        $Element.on({
            mousemove: function(event) {
                var curWidth = startWidth + (event.pageX - startX);
                event.preventDefault();
                if (pressed) {
                    if ( minWidth >= curWidth ) {
                        $handle.width(minWidth);
                    } else {
                        $handle.width(curWidth);
                    }
                }
            },
            mouseup: function(event) {
                event.preventDefault();

                if (pressed) {
                    $Element.removeClass('resizing');
                    $handle.removeClass('moved');
                    pressed       = false;
                    storeResizing = '';

                    $.each($Element.find('th'), function () {
                        if ( storeResizing ) {
                            storeResizing += ',';
                        }
                        storeResizing += ($(this).width() / tableWidth ).toFixed(4);
                    });

                    if ( Action.match(/^Customer/) ) {
                        Core.Customer.PreferencesUpdate('User' + Identifiere + 'ColumnResizing', storeResizing);
                    }
                    else {
                        Core.Agent.PreferencesUpdate('User' + Identifiere + 'ColumnResizing', storeResizing);
                    }

                    Core.Config.Set('UserArticleTableColumnResizing', storeResizing);
                    customResizing = storeResizing;

                    resetIcon.removeClass('Hidden');
                }
            }
        });

        $Element.find('th').on('mousedown', function(event) {
            event.preventDefault();

            minWidth    = 0;
            $handle     = $(this);
            pressed     = true;
            startX      = event.pageX;
            startWidth  = $handle.width();

            $Element.addClass('resizing');
            $handle.addClass('moved');

            $.each($handle.find('a,span'), function() {
                minWidth += $(this).width();
            });
        });
    };

    return TargetNS;
}(Core.UI.Table || {}));
