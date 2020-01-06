// --
// Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --

'use strict';

var Core = Core || {};
Core.KIX4OTRS = Core.KIX4OTRS || {};

/**
 * @namespace
 * @exports TargetNS as Core.KIX4OTRS.AgentITSMConfigItemGraph
 * @description This namespace creates the graph in TabLinkGraph
 */

Core.KIX4OTRS.AgentLinkGraphITSMConfigItem = (function(TargetNS) {
    var UserRights = {
        Ro: {},
    };
    var NodesRightAttr = {};
    var $Nodes = {};
    var CIFullID, CIID, $CINode, CIName;
    var $Elements = {}, GraphConfig = GraphConfig || {}, NodeNeighbors = {};
    var $Dialog;

    /**
     * @function
     * @param {Object} userRights An object about the rights of the user for open or linking nodes and showing services
     * @return nothing This function initializes the graph and defines some defaults
     */
    TargetNS.Init = function(nodesString, userRights, graphConfig, $elements) {
        $Elements = $elements;
        GraphConfig = graphConfig;
        // get rights
        var RoRights = userRights.Ro.split('_-_');
        for ( var x = 0, len = RoRights.length; x < len; x++) {
            var RoClass = RoRights[x].split(':::');
            UserRights.Ro[RoClass[0]] = parseInt(RoClass[1]);
        }
        UserRights.Service = userRights.Service;

        // remember attribute for right-check and edit node-link
        if (nodesString != '') {
            var nodes = nodesString.split('_-_');
            for ( var x = 0, len = nodes.length; x < len; x++) {

                // remember node
                $Nodes[nodes[x]] = $('#'+nodes[x]);

                // remember specific attribute of node for rights-check
                NodesRightAttr[nodes[x]] = $Nodes[nodes[x]].find('#RightsAttr').val();

                // edit link (if no rights to open CI, remove link)
                var RegEx = /\d+/.exec(nodes[x]);
                var NodeID = RegEx[0];
                var Link = $('#'+nodes[x]).find('a');
                if ( CheckRights(1, nodes[x]) ) {
                    Link.attr('href', './index.pl?Action=AgentITSMConfigItemZoom&ConfigItemID=' + NodeID + ';SelectedTab=2;'
                            //+ 'RelevantObjectTypes=' + GraphConfig.ObjectTypes + ';'  // not enabled yet...
                            + 'RelevantObjectSubTypes=' + GraphConfig.SubTypes + ';'
                            + 'RelevantLinkTypes=' + GraphConfig.LinkTypes + ';'
                            + 'MaxSearchDepth=' + GraphConfig.SearchDepth + ';'
                            + 'UsedStrength=' + GraphConfig.AdjustingStrength
                            + SerializeData(Core.App.GetSessionInformation())
                    );
                    Link.attr('target', '_parent');
                } else {
                    Link.parent().html(Link.html());
                }
            }
        }

        // bind context-function on all nodes
        $('.GraphNode').bind('contextmenu', function(e) {
            if (!e) {
                e = window.event;
            }
            NodeBindContextmenu(e);
        });

        // register object-functions
        Core.KIX4OTRS.AgentLinkGraph.SetRightFunction(CheckRights, SetRightAttr);
    }
    // prepare context-menu
    function NodeBindContextmenu(e) {
        // get id and name of target
        CIFullID = e.target.id || e.target.parentElement.id || e.target.parentElement.parentElement.id;
        var getID = /\d+/.exec(CIFullID);
        CIID = getID[0];
        $CINode = $Nodes[CIFullID];
        CIName = $CINode.attr('name');

        // if no rights to open CI, gray out 'Open CI' and link options
        if ( !CheckRights(1) ) {
            $Elements.Zoom.addClass('ContextNoRights');
            $Elements.Present.addClass('ContextNoRights');
            $Elements.NotPresent.addClass('ContextNoRights');
        } else {
            $Elements.Zoom.removeClass('ContextNoRights');
            $Elements.Present.removeClass('ContextNoRights');
            $Elements.NotPresent.removeClass('ContextNoRights');
        }
        // if no rights to open services or CI, gray out 'Show linked services'
        if ( !CheckRights(2) || !CheckRights(1) ) {
            $Elements.Service.addClass('ContextNoRights');
        } else {
            $Elements.Service.removeClass('ContextNoRights');
        }

        Core.KIX4OTRS.AgentLinkGraph.NodeBindContextmenu(CIFullID, CIID, $CINode, CIName, e);
    }

    /**
     * @function
     * @return nothing This function opens the selected CI
     */
    TargetNS.OpenObject = function() {
        // only if user have rights to open this CI
        if ( CheckRights(1) ) {
            $Elements.Zoom.attr('href', './index.pl?Action=AgentITSMConfigItemZoom&ConfigItemID=' + CIID + ';'
                    + SerializeData(Core.App.GetSessionInformation()));
            $Elements.Zoom.attr('target', '_parent');
        }
    }
    /**
     * @function
     * @return nothing This function allows to link a CI with another present CI
     */
    TargetNS.PresentNode = function() {
        // only if user have rights to open this CI
        if ( CheckRights(1) ) {
            Core.KIX4OTRS.AgentLinkGraph.PresentNode();
        }
    }

    /**
     * @function
     * @param {Event} Event The event which was triggered
     * @return nothing This function allows to link a node with a not present node
     */
    TargetNS.NotPresentNode = function(Event) {
        // function for: if target and LinkType are submitted
        function ChooseObjectSubmit() {
            var TargetID = $Dialog.find('#AutoCompleteTarget').val();
            if (!TargetID) {
                $Dialog.find('#NoTarget').removeClass('Hidden');
                return;
            }
            $Dialog.find('button').attr('disabled', 'disabled');

            var Target = 'ITSMConfigItem-' + TargetID;
            if (Target == CIFullID) {
                $Dialog.find('#Same').removeClass('Hidden');
                $Dialog.find('button').removeAttr('disabled');
                return;
            }

            var Source = CIFullID, DestObject = Target;
            if ($Dialog.find('#AsSource').is(':checked')) {
                Target = Source;
                Source = DestObject;
            }

            var NotPresent = 1;
            // if "not present node" is present
            $.each($Nodes, function(ID, Object) {
                if (DestObject == ID) {
                    // set connection
                    var Conn = jsPlumb.connect({
                        source: Source,
                        target: Target
                    });
                    NotPresent = 0;
                    Core.KIX4OTRS.AgentLinkGraph.FinishLinking(Source, Target, Conn, '', $Dialog.find('#LinkTypes option:selected').text());
                    return false;
                }
            });
            // if not
            if (NotPresent) {
                Core.KIX4OTRS.AgentLinkGraph.FinishLinking(Source, Target, '', DestObject, $Dialog.find('#LinkTypes option:selected').text());
            }
        }
        // only if user have rights to open this CI
        if ( CheckRights(1) ) {
            // show dialog with selectable target and LinkType
            Core.UI.Dialog.ShowDialog({
                Modal: true,
                Title: CIName + ' ' + $Elements.ChooseBox.find('#ChooseHeader').val(),
                HTML: $Elements.ChooseBox.html(),
                PositionTop: Event.pageY,
                PositionLeft: Event.pageX,
                Buttons: [ {
                    Label: $('#TypeSubmit').val(),
                    Type: 'Submit',
                    Function: ChooseObjectSubmit,
                    Class: 'CallForAction'
                }, {
                    Label: $('#TypeCancel').val(),
                    Type: 'Close'
                } ]
            });
            $Dialog = $('.Dialog');
            Core.KIX4OTRS.AgentLinkGraph.SetDialogPosition(Event.pageX, Event.pageY, '', $Dialog);
            Core.Config.Set('GenericAutoCompleteSearch.MinQueryLength', 3);
            Core.Config.Set('GenericAutoCompleteSearch.QueryDelay', 200);
            Core.Config.Set('GenericAutoCompleteSearch.MaxResultsDisplayed', 20);
            AutoComplete($('.Dialog').find('#TargetObject'), $('.Dialog').find('#AutoCompleteTarget'));

            // hide 'no target' and 'same' notice
            $Dialog.find('#TargetObject').focus(function() {
                $Dialog.find('#NoTarget').addClass('Hidden');
                $Dialog.find('#Same').addClass('Hidden');
                $Dialog.find('#AutoCompleteTarget').val('');
            });
        }
    }

    /**
     * @function
     * @return nothing This function shows linked services
     */
    TargetNS.ShowServices = function() {
        // function for: open dialog if rights are given
        function openDialog() {
            var x = $CINode.offset().left + 15;
            var y = $CINode.offset().top + 15;
            Core.UI.Dialog.ShowDialog({
                Modal: false,
                Title: $Elements.ServicePopup.find('.Header > h2 > span').html(),
                HTML: $Elements.ServicePopup.find('.Content').html(),
                PositionTop: y,
                PositionLeft: x
            });
            $Dialog = $('.Dialog');
            Core.KIX4OTRS.AgentLinkGraph.SetDialogPosition(x, y, 0, $Dialog);
        }
        // only if user have rights for open services or CI
        if ( CheckRights(2) && CheckRights(1) ) {
            var URL = Core.Config.Get('CGIHandle') + '?Action=AgentLinkGraph' + GraphConfig.ObjectType + ';Subaction=ShowServices;'
                    + 'ObjectType=' + GraphConfig.ObjectType + ';ObjectID='
                    + CIID + ';ObjectName=' + CIName;
            Core.AJAX.ContentUpdate($Elements.ServicePopup, URL, function() {
                openDialog();
            });
        }
    }

    /**
     * @function
     * @return nothing This function changes the incident image if one participant has the incident-state "incident" or "warning"
     */
    TargetNS.ChangeInciImage = function(PropStartCI, StateType, Image, LinkType, Direction, Delete) {
        var SetAlt = 'warning', Visited = {};
        if (Delete) {
            SetAlt = 'operational';
        }
        var $Node = $Nodes[PropStartCI];
        var Alt = $Node.find('.IncidentImage').attr('alt');
        if (Alt != SetAlt && Alt != 'incident') {
            $Node.find('.IncidentImage').remove();
            $Node.prepend('<img class="IncidentImage" src=' + Image + ' alt=' + SetAlt + ' title=' + StateType + ';" />');
        }
        Visited[PropStartCI] = 1;

        // function for: checking neighbors, change them too if necessary
        function CheckNeighbors(CurrNode) {
            $.each(NodeNeighbors[CurrNode], function(Direct, NodeList) {
                if (Direction == Direct || Direction == 'Both') {
                    $.each(NodeList, function(NodeFullID, Types) {
                        if (Visited[NodeFullID]) { return true; }
                        $.each(Types, function(Type, Linked) {
                            if (LinkType == Type && Linked) {
                                Visited[NodeFullID] = 1;
                                var $Node = $Nodes[NodeFullID];
                                var Alt = $Node.find('.IncidentImage').attr('alt');
                                if (Alt != SetAlt && Alt != 'incident') {
                                    $Node.find('.IncidentImage').remove();
                                    $Node.prepend('<img class="IncidentImage" src="' + Image + '" alt="' + SetAlt
                                            + '" title="' + StateType + ';" />');
                                } else {
                                    return true;
                                }
                                // check neighbors of current neighbor
                                CheckNeighbors(NodeFullID);
                            }
                        })
                    });
                }
            });
        }
        CheckNeighbors(PropStartCI);
    }

    var CheckRights = function(Which, ID) {
        if ( !ID ) { ID = CIFullID; }
        // read only for CI-class
        if (Which == 1) {
            return UserRights.Ro[NodesRightAttr[ID]];
        }
        // service
        if (Which == 2) {
            return UserRights.Service;
        }
    }
    var SetRightAttr = function(ID, $Node) {
        $Nodes[ID] = $Node;
        NodesRightAttr[ID] = $Nodes[ID].find('#RightsAttr').val();
        $Nodes[ID].bind('contextmenu', function(e) {
            if (!e) {
                e = window.event;
            }
            NodeBindContextmenu(e);
        });
    }

    // register neighbors
    TargetNS.RegisterNeighbor = function(SourceID, TargetID, Type, SourceId) {
        if (!NodeNeighbors[SourceID]) {
            NodeNeighbors[SourceID] = {
                Target: {},
                Source: {}
            };
        }
        if (!NodeNeighbors[SourceID].Target[TargetID]) {
            NodeNeighbors[SourceID].Target[TargetID] = {};
        }
        NodeNeighbors[SourceID].Target[TargetID][Type] = 1;
        if (!NodeNeighbors[TargetID]) {
            NodeNeighbors[TargetID] = {
                Target: {},
                Source: {}
            };
        }
        if (!NodeNeighbors[TargetID].Source[SourceID]) {
            NodeNeighbors[TargetID].Source[SourceID] = {};
        }
        NodeNeighbors[TargetID].Source[SourceID][Type] = 1;
    }
    // delete neighbors
    TargetNS.DeleteNeighbor = function(SourceID, TargetID, Type) {
        NodeNeighbors[SourceID].Target[TargetID][Type] = 0;
        NodeNeighbors[TargetID].Source[SourceID][Type] = 0;
    }

    // initializes the autocomplete for object search
    var Config = {};
    function AutoComplete($Element, $DestElement, ActiveAutoComplete) {

        if (typeof ActiveAutoComplete === 'undefined') {
            ActiveAutoComplete = true;
        } else {
            ActiveAutoComplete = !!ActiveAutoComplete;
        }

        // prevent submit by pressing enter
        $Element.keypress(function(event) {
            if (event.keyCode == 13) {
                return false;
            }
        });

        Config.MaxResultsDisplayed = Core.Config.Get('GenericAutoCompleteSearch.MaxResultsDisplayed');
        $Element.autocomplete({
            minLength: ActiveAutoComplete ? Core.Config.Get('GenericAutoCompleteSearch.MinQueryLength') : 3,
            delay: Core.Config.Get('GenericAutoCompleteSearch.QueryDelay'),
            source: function(Request, Response) {

                var URL = Core.Config.Get('Baselink'), Data = {
                    Action: 'QuickLinkAJAXHandler',
                    Term: Request.term,
                    Module: Core.Config.Get('Action'),
                    ElementID: $DestElement.attr('id'),
                    MaxResults: Config.MaxResultsDisplayed,
                    SourceObject: 'ITSMConfigItem',
                    SourceKey: CIID,
                    TargetObject: 'ITSMConfigItem::' + $('.Dialog').find('#CIClasses option:selected').val(),
                    TypeIdentifier: 'AlternativeTo::Source',
                    Subaction: 'Search'
                };

                Core.AJAX.FunctionCall(URL, Data, function(Result) {
                    var Data = [];
                    $.each(Result, function() {
                        Data.push({
                            label: this.SearchObjectValue + ' (' + this.SearchObjectKey + ')',
                            value: this.SearchObjectValue,
                            id: this.SearchObjectID
                        });
                    });
                    Response(Data);
                });
            },
            select: function(Event, UI) {
                $Element.val(UI.item.value);
                $DestElement.val(UI.item.id);
            }
        });

        if (!ActiveAutoComplete) {
            $Element.after('<button id="' + $Element.attr('id') + 'Search" type="button">'
                    + Core.Config.Get('Autocomplete.SearchButtonText') + '</button>');
            $('#' + $Element.attr('id') + 'Search').click(function() {
                $Element.autocomplete('option', 'minLength', 0);
                $Element.autocomplete('search');
                $Element.autocomplete('option', 'minLength', 500);
            });
        }
    }

    function SerializeData(Data) {
        var QueryString = '';
        $.each(Data, function (Key, Value) {
            QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });
        return QueryString;
    }

    return TargetNS;
}(Core.KIX4OTRS.AgentLinkGraphITSMConfigItem || {}));
