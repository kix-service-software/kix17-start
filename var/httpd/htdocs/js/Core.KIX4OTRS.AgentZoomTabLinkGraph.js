// --
// Core.KIX4OTRS.AgentZoomTabLinkGraph.js- provides custom functions for Tab LinkGraph
// Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
//
// written/edited by:
//   Torsten(dot)Thau(at)cape(dash)it(dot)de
//   Martin(dot)Balzarek(at)cape(dash)it(dot)de
//   Ricky(dot)Kaiser(at)cape(dash)it(dot)de
//
// --
// $Id$
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
 * @exports TargetNS as Core.KIX4OTRS.AgentZoomTabLinkGraph
 * @description This namespace contains custom functions for tabs
 */

Core.KIX4OTRS.AgentZoomTabLinkGraph = ( function (TargetNS) {
    /**
     * @function
     * @private
     * @param {Object} Data The data that should be converted
     * @return {string} query string of the data
     * @description Converts a given hash into a query string
     */
    function SerializeData(Data) {
        var QueryString = '';
        $.each(Data, function (Key, Value) {
            QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });
        return QueryString;
    }

    // load iframe-content
    TargetNS.LoadIFrameContent = function (LoadGraph, UnfoldGraphBlock) {
        var $iframe = $('#displayGraphIFrame'),
            SourceURL,
            CurrentObjectType = $('#CurrentObjectType').val(),
            CurrentObjectID = $('#CurrentObjectID').val(),
            RelevantObjectTypeSel = $('#RelevantObjectTypes').val(),
            MaxSearchDepthSel = $('#MaxSearchDepth').val(),
            AdjustingStrengthSel = $('#AdjustingStrength').val(),
            RelevantLinkTypesSel = $('#RelevantLinkTypes').val(),
            RelevantObjectSubTypesSel = $('#RelevantObjectSubTypes').val();

        if ($iframe.length == 0) {
            return;
        }

        SourceURL = './index.pl?Action=AgentLinkGraph' + CurrentObjectType + ';';
        SourceURL += 'ObjectID=' + CurrentObjectID + ';';
        SourceURL += 'ObjectType=' + CurrentObjectType + ';';
        SourceURL += 'RelevantLinkTypes=' + RelevantLinkTypesSel + ';';
        SourceURL += 'RelevantObjectTypes=' + RelevantObjectTypeSel + ';';
        SourceURL += 'RelevantObjectSubTypes=' + RelevantObjectSubTypesSel + ';';
        SourceURL += 'MaxSearchDepth=' + MaxSearchDepthSel + ';';
        SourceURL += 'UsedStrength=' + AdjustingStrengthSel + ';';

        function DoGraph() {
            SourceURL += SerializeData(Core.App.GetSessionInformation());
            $iframe.attr('src', SourceURL).load();
            if ( LoadGraph ) {
                UnfoldGraphBlock();
            }
            return 0;
        }
        // check if a graph should be loaded
        if ( !LoadGraph ) {
            DoGraph();
        } else {
            $('body').css('cursor', 'wait');
               var URL = Core.Config.Get('Baselink');
            var Data = {
                    Action:     'AgentLinkGraph' + CurrentObjectType,
                    Subaction:  'GetSavedGraphs',
                    CurID:      CurrentObjectID,
                    ObjectType: CurrentObjectType
            };

            Core.AJAX.FunctionCall(URL, Data, function (Result) {
                $('body').css('cursor', '');
                var SavedGraphs = Result.Graphs;
                var SavedGraphID;

                function SetLoadGraph() {
                    SourceURL += 'SavedGraphID=' + SavedGraphID + ';';
                    SourceURL += 'GraphConfig=' + SavedGraphs[SavedGraphID].ConfigString + ';';
                    SourceURL += 'GraphLayout=' + SavedGraphs[SavedGraphID].Layout + ';';
                    Core.UI.Dialog.CloseDialog( $('.Dialog') );
                    DoGraph();
                }

                // show dialog with selectable saved graphs
                Core.UI.Dialog.ShowDialog({
                    Modal: true,
                    Title: $('#LoadGraphTitle').val(),
                    HTML:  $('#LoadGraphContent').html(),
                    PositionTop:  '45%',
                    PositionLeft: '45%',
                    Buttons: [
                        {
                            Label:    $('#LoadGraphSubmit').val(),
                            Type:     'Submit',
                            Function: SetLoadGraph,
                            Class: 'CallForAction'
                        },
                        {
                            Label:    $('#LoadGraphCancel').val(),
                            Type:     'Close'
                        }
                    ]
                });
                var $Dialog = $('.Dialog');
                $Dialog.find('.Header h1').css('padding-right', '25px');
                if ( !Result.Graphs.NoSavedGraphs ) {
                    $Dialog.find('#LoadGraphSelection').html(SavedGraphs.Selection);
                    $Dialog.find('#SavedGraphs').removeClass('Hidden');
                    var $SavedGraphSelection = $('#SavedGraphSelection');
                    $SavedGraphSelection.change( function () {
                        SavedGraphID = $SavedGraphSelection.val();
                        $Dialog.find('#LoadGraphSubTypes').html(SavedGraphs[SavedGraphID].SubTypes);
                        $Dialog.find('#LoadGraphLinkTypes').html(SavedGraphs[SavedGraphID].LinkTypes);
                        $Dialog.find('#LoadGraphDepth').html(SavedGraphs[SavedGraphID].Depth);
                        $Dialog.find('#LoadGraphStrength').html(SavedGraphs[SavedGraphID].Strength);
                        $Dialog.find('#LoadGraphLastChangedTime').html(SavedGraphs[SavedGraphID].LastChangedTime);
                        $Dialog.find('#LoadGraphLastChangedBy').html(SavedGraphs[SavedGraphID].LastChangedBy);
                    });
                    $SavedGraphSelection.change();
                } else {
                    $Dialog.find('#NoSavedGraphs').removeClass('Hidden');
                    $Dialog.find('#DialogButton1').attr('disabled', 'disabled');
                    $Dialog.find('#DialogButton1').css('color', 'silver');
                }
                $Dialog.css({
                    left: ($('body').width()-$Dialog.width())/2,
                    top:  ($('body').height()-$Dialog.height())/2
                });
            });
        }
    };

    return TargetNS;
}(Core.KIX4OTRS.AgentZoomTabLinkGraph || {}));
