// --
// Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var Core = Core || {};
Core.UI = Core.UI || {};

/**
 * @namespace Core.UI.Pagination
 * @memberof Core.UI
 * @author CAPE-IT
 * @description
 *      This namespace contains the pagination functions.
 */
Core.UI.Pagination = (function (TargetNS) {

    var BaseLinks = {};

    /**
     * @name Init
     * @memberof Core.UI.Pagination
     * @function
     * @returns {Boolean} false, if Parameter IDPrefix is not of the correct type.
     * @param {String} Prefix - prefix to identify the buttons and connect an event
     * @description
     *      This function initializes the click event on the defined ids.
     */
    TargetNS.PageLink = function(IDPrefix) {

        $('[id^=' + IDPrefix + ']').off('click').on('click', function(){
            var StartHit    = $(this).attr('StartHit'),
                StartWindow = $(this).attr('StartWindow'),
                URL         = BaseLinks[IDPrefix];

            if ( $(this).hasClass('PageAJAX') ) {
                var $Container  = $(this).parents('.WidgetSimple'),
                    Identifier  = $(this).attr('Identifier');

                if ( StartHit ) {
                    URL += ';StartHit=' + StartHit;
                }
                if ( StartWindow ) {
                    URL += ';StartWindow=' + StartWindow;
                }

                $Container.addClass('Loading');
                Core.AJAX.ContentUpdate($('#' + Identifier), URL, function () {
                    $Container.removeClass('Loading');
                });
                return false;
            } else {
                $('input[name="StartHit"]').val(StartHit);
                $('input[name="StartWindow"]').val(StartWindow);

                $(this).closest('form').submit();
            }
        });
    };
    /**
     * @name InitSelectItem
     * @memberof Core.UI.Pagination
     * @function
     * @returns {Boolean} false, if Parameter Element is not of the correct type.
     * @description
     *      This function initializes the click event on the defined classes.
     */
    TargetNS.InitSelectItem = function () {
        $('.SelectItem').off('click').on('click', function() {
            var ItemID            = $(this).val(),
                SelectedItems     = $('input[name="SelectedItems"]').val().split(',').filter(function(v){return v!==''}),
                UnselectedItems   = $('input[name="UnselectedItems"]').val().split(',').filter(function(v){return v!==''});

            if ( $(this).is(':checked') ) {
                  var Index = $.inArray(ItemID, UnselectedItems );
                  if ( Index >= 0) {
                      UnselectedItems.splice(Index, 1);
                  }
                  if ( $.inArray(ItemID, SelectedItems ) < 0) {
                      SelectedItems.push(ItemID);
                  }
            } else {
                var Index = $.inArray(ItemID, SelectedItems );
                if ( Index >= 0) {
                    SelectedItems.splice(Index, 1);
                }
                if ( $.inArray(ItemID, UnselectedItems ) < 0) {
                    UnselectedItems.push(ItemID);
                }
            }
            $('input[name="SelectedItems"]').val(SelectedItems.join(','));
            $('input[name="UnselectedItems"]').val(UnselectedItems.join(','));
        });
    }

    /**
     * @name Init
     * @memberof Core.UI.Pagination
     * @function
     * @returns {Boolean} false, if Parameter Element is not of the correct type.
     * @param {String} BaseLink - BaseLink needed to update the contents via ajax
     * @param {String} Prefix - prefix to identify the buttons and connect an event
     * @description
     *      This function initializes the click event on the defined ids.
     */
    TargetNS.Init  = function (BaseLink, IDPrefix) {

        if (!BaseLinks[IDPrefix]) {
            BaseLinks[IDPrefix] = BaseLink;
        }

        TargetNS.PageLink(IDPrefix);
    }

    return TargetNS;
}(Core.UI.Pagination || {}));
