// --
// Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
// based on the original work of:
// Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.UI = Core.UI || {};

/**
 * @namespace Core.UI.AllocationList
 * @memberof Core.UI
 * @author OTRS AG
 * @description
 *      Support for Allocation Lists (sortable lists).
 */
Core.UI.AllocationList = (function (TargetNS) {
    if (!Core.Debug.CheckDependency('Core.UI.AllocationList', '$([]).sortable', 'jQuery UI sortable')) {
        return false;
    }

    /**
     * @name GetResult
     * @memberof Core.UI.AllocationList
     * @function
     * @return {Array} An array of values defined by DataAttribute.
     * @param {String} ResultListSelector - The selector for the list which will be evaluated for the result.
     * @param {String} DataAttribute - The data attribute to determine the selection.
     * @description
     *      Gets the result of an allocation list.
     */
    TargetNS.GetResult = function (ResultListSelector, DataAttribute) {
        var $List = $(ResultListSelector),
            Result = [];

        if (!$List.length || !$List.children('li').length) {
            return [];
        }

        $List.children('li').each(function () {
            var Value = $(this).data(DataAttribute);
            if (typeof Value !== 'undefined') {
                Result.push(Value);
            }
        });

        return Result;
    };

    /**
     * @name Init
     * @memberof Core.UI.AllocationList
     * @function
     * @param {String} ListSelector - The selector for the lists to initialize
     * @param {String} ConnectorSelector - The selector for the connection (dnd), probably a class
     * @param {Function} ReceiveCallback - The Callback which is called if a list receives an element
     * @param {Function} RemoveCallback - The Callback which is called if an element is removed from a list
     * @param {Function} SortStopCallback - The Callback which is called if the sorting has stopped.
     * @description
     *      Initializes an allocation list.
     */
    TargetNS.Init = function (ListSelector, ConnectorSelector, ReceiveCallback, RemoveCallback, SortStopCallback) {
        var $Lists = $(ListSelector);

        if (!$Lists.length) {
            return;
        }

        $Lists.children('li').removeClass('Even').end().sortable({
            connectWith: ConnectorSelector,
            items: '.sorting-initialize',
            receive: function (Event, UI) {
                if ($.isFunction(ReceiveCallback)) {
                    ReceiveCallback(Event, UI);
                }
            },
            remove: function (Event, UI) {
                if ($.isFunction(RemoveCallback)) {
                    RemoveCallback(Event, UI);
                }
            },
            stop: function (Event, UI) {
                if ($.isFunction(SortStopCallback)) {
                    SortStopCallback(Event, UI);
                }
            }
        }).disableSelection();

        $Lists.children('li').one("mouseover",function(){
            if ( !$(this).hasClass('sorting-initialize') ) {
                $(this).prev('li').addClass("sorting-initialize");
                $(this).addClass("sorting-initialize");
                $(this).next('li').addClass("sorting-initialize");
                $Lists.children('li').off('remove');
                $Lists.sortable('refresh');
            }
        });
    };

    return TargetNS;
}(Core.UI.AllocationList || {}));
