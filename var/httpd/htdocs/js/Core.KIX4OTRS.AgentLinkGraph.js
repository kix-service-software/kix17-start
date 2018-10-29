// --
// Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
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
 * @exports TargetNS as Core.KIX4OTRS.AgentLinkGraph
 * @description This namespace creates the graph in TabLinkGraph
 */

Core.KIX4OTRS.AgentLinkGraph = (function(TargetNS) {
    var LinkColors = {}, LinkTypes = {}, Nodes = [], TwoArrows = {}, GraphConfig = GraphConfig || {},
        Move = {}, NodesRightCheck = {}, SavedGraphs = {}, AlreadyLinked = {}, Curviness = [ 30, -30, -2, 60, -60 ];
    var OrgValues = {}; // for zooming and saving
    var MousePos = {
        X : 0,
        Y : 0
    }; // for some dialogs and NotPresentNode
    var Max = {
        X : 0,
        Y : 0
    }; // for positioning of some elements (= size of GraphBody + scroll-value)
    var NotPresent = 1, DummyConnection, $Elements, $Dialog,
        CurZoom = 1, $ContextObjectNode, ContextObjectFullID, ContextObjectID, ContextObjectName, $DraggedNode;
    var BroType = navigator.appVersion.substring(0, 1);
    var UserRights = {}, CheckRights, SetRightAttr;

    /**
     * @function
     * @param {String} NodesString All nodes separated by '_-_'
     * @param {String} LinksString All existing connection between nodes separated by '_-_'
     * @param {String} ColorsString All colors defined in config for links separated by '_-_'
     * @param {String} LinkTypesString All link-types with its translation separated by '_-_'
     * @param {Object} Elements An object with needed DOM-elements
     * @param {String} Layout All nodes with their left and top attributes separated by _-_ if graph is loaded
     * @param {Object} Config All data about the used graph configuration
     * @return nothing This function initializes the graph and defines some defaults
     */
    TargetNS.InitGraph = function(NodesString, LinksString, ColorsString, LinkTypesString, Elements, Layout, Config) {
        $Elements = Elements;
        $Elements.Shield.removeClass('Hidden');
        GraphConfig = Config;
        GraphConfig.StartFullID = GraphConfig.StartID;
        var RegEx = /\d+/.exec(GraphConfig.StartFullID);
        GraphConfig.StartID = RegEx[0];
        if ( !GraphConfig.AdjustingStrength ) {
            GraphConfig.AdjustingStrength = 1;
        }
        OrgValues.FontSize = parseInt($Elements.Scale.css('font-size'), 10);
        // prepare print-window
        Core.UI.Popup.ProfileAdd('LinkGraph', {
            WindowURLParams: "dependent=yes,location=no,menubar=no,resizable=yes,scrollbars=yes,status=no,toolbar=no",
            Left:   100,
            Top:    100,
            Width:  $Elements.PrintBox.width() + 20,
            Height: 750
        });

        // get link-colors
        if (ColorsString) {
            var Colors = ColorsString.split('_-_');
            for ( var x = 0, len = Colors.length; x < len; x++) {
                var LinkColorArray = Colors[x].split('=>');
                LinkColors[LinkColorArray[0]] = LinkColorArray[1];
            }
        }

        // make nodes draggable
        jsPlumb.draggable($('.GraphNode'), {
            containment: $Elements.GraphBody,
            scrollSensitivity: 500,
            start: function() {
                $Elements.Body.css('cursor', '');
                MagnifierActive = 0;
                $Elements.MagnifierZoom.removeClass('Magnifier_active');
                $Elements.ZoomArea.addClass("Hidden");
            },
            stop: function() {
                // save position of dragged node on stop-event
                if ($DraggedNode) {
                    SaveOrgValues($DraggedNode, 1);
                    $DraggedNode = '';
                }
            },
            scrollSpeed: 100
        });

        // get link types with translation
        var Types = LinkTypesString.split('_-_');
        for ( var x = 0, len = Types.length; x < len; x++) {
            var TypesArray = Types[x].split('=>');
            LinkTypes[TypesArray[0]] = TypesArray[1];
            // if there should be two arrows on link
            TwoArrows[TypesArray[0]] = parseFloat(TypesArray[2]);
            // if no color for link-type is defined, 'paint' it black
            if (!LinkColors[TypesArray[0]]) {
                LinkColors[TypesArray[0]] = '#000';
            }
        }

        // define some defaults for graph
        jsPlumb.importDefaults({
            HoverPaintStyle: {
                lineWidth: 2,
                strokeStyle: LinkColors["LinkHover"]
            },
            EndpointHoverStyle: {
                fillStyle: LinkColors["LinkHover"]
            },
            Endpoint: 'Blank',
            Connector: 'StateMachine',
            Anchor: [ 'Perimeter', {
                shape: 'Rectangle'
            } ],
            PaintStyle: {
                lineWidth: 2,
                strokeStyle: '#bbbbbb',
                dashstyle: "solid"
            },
            ReattachConnections: true
        });
        jsPlumb.setContainer($Elements.Scale);

        $Elements.GraphBody.height($Elements.Body.height() - $Elements.Options.height());

        // get positions of nodes if a saved graph was loaded
        var NodesPositions = {};
        if (Layout) {
            if (Layout == 'NotLoadable') {
                Layout = '';
                ShowNotice('LoadGraph', '', $('#LoadFailed').val() + '<br/>' + $('#Failed').val());
            } else {
                var layoutNodes = Layout.split('_-_');
                for ( var x = 0, len = layoutNodes.length; x < len; x++) {
                    var nodePos = layoutNodes[x].split('::');
                    NodesPositions[nodePos[0]] = {
                            Left: nodePos[1],
                            Top: nodePos[2]
                    };
                }
            }
        }

        var NewNodes = {};
        // 'build' known nodes and connections
        if (NodesString != '') {
            var nodes = NodesString.split('_-_');
            for ( var x = 0, len = nodes.length; x < len; x++) {
                // add attribute 'target' to existing nodes
                jsPlumb.makeTarget(nodes[x], {
                    dropOptions: {
                        hoverClass: "dragHover"
                    }
                });

                Nodes.push({
                    ID: nodes[x],
                    Object: $('#' + nodes[x])
                });
                // if loaded, use the given values for position of nodes,...
                // if not, position the nodes in the left upper corner
                if (NodesPositions[nodes[x]]) {
                    Nodes[x].Object.css({
                        'left': NodesPositions[nodes[x]].Left + 'px',
                        'top': NodesPositions[nodes[x]].Top + 'px'
                    });
                    delete NodesPositions[nodes[x]];
                } else {
                    NewNodes[nodes[x]] = Nodes[x].Object.attr('name');
                    Nodes[x].Object.css({
                        'left': x + 'px',
                        'top': x + 'px'
                    });
                }

                // save position and size of node for zooming
                SaveOrgValues(Nodes[x].Object);
            }
            if (Nodes[1] != undefined) {
                // create existing connections
                var Links = LinksString.split('_-_');
                // don't draw unless all connections are made
                jsPlumb.doWhileSuspended(function() {
                    for ( var x = 0, len = Links.length; x < len; x++) {
                        var Link = Links[x].split('==');
                        // set connection
                        var Conn = jsPlumb.connect({
                            source: Link[0],
                            target: Link[2]
                        });
                        SetLabelArrowColor(Conn, Link[1]);
                    }
                }, true);
            }

            if (Layout || Nodes[1] == undefined) {
                // draw graph/links
                jsPlumb.repaintEverything();
                $Elements.Shield.addClass('Hidden');
                $Elements.Body.css('cursor', '');
            } else {
                // adjust nodes and draw graph/links
                TargetNS.Adjust();
            }
        } else {
            // show notice if no nodes are present
            Core.UI.Dialog.ShowDialog({
                Modal: false,
                Title: $('#NoObjectsTitle').val(),
                HTML: $('#NoObjectsContent').val(),
                PositionTop: $Elements.GraphBody.height() / 2 - $Elements.Options.height(),
                PositionLeft: 'Center',
                Buttons: [ {
                    Label: 'OK',
                    Type: 'Close'
                } ]
            });
        }

        // show notice about lost and new nodes if graph was loaded
        if (Layout) {
            // get names for lost nodes
            var URL = Core.Config.Get('Baselink');
            var LostNodesString = '';
            $.each(NodesPositions, function(Index, Values) {
                LostNodesString += Index + ':::';
            });
            var NewNodesString = '';
            $.each(NewNodes, function(Index, Values) {
                NewNodesString += Index + ':::';
            });
            var Data = {
                Action: 'AgentLinkGraph' + GraphConfig.ObjectType,
                Subaction: 'GetObjectNames',
                LostNodesString: LostNodesString,
                NewNodesString: NewNodesString
            };
            Core.AJAX.FunctionCall(URL, Data, function(Result) {
                $Elements.Shield.addClass('Hidden');
                // show notice
                Core.UI.Dialog.ShowDialog({
                    Modal: true,
                    Title: $('#GraphLoadedTitle').val(),
                    HTML: $Elements.GraphLoaded.find('.Content'),
                    PositionTop: '45%',
                    PositionLeft: 'center',
                    Buttons: [ {
                        Label: 'Ok',
                        Type: 'Close'
                    } ]
                });
                $Dialog = $('.Dialog');
                var $DialogNewNodes = $('.Dialog #NewNodes');
                var $DialogLostNodes = $('.Dialog #LostNodes');
                if (Result.NewNodes.None) {
                    Result.NewNodes = {
                        'None': {
                            Number: '-',
                            Name: '-'
                        }
                    };
                }
                if (Result.LostNodes.None) {
                    Result.LostNodes = {
                        'None': {
                            Number: '-',
                            Name: '-'
                        }
                    };
                }

                $.each(Result.NewNodes, function(Index, Object) {
                    if (Index == 'None') {
                        return true;
                    }
                    $DialogNewNodes.append('<tr><td>' + Object.Number + '</td><td>' + Object.Name + '</td></tr>');
                });
                $.each(Result.LostNodes, function(Index, Object) {
                    if (Index == 'None') {
                        return true;
                    }
                    $DialogLostNodes.append('<tr><td>' + Object.Number + '</td><td>' + Object.Name + '</td></tr>');
                });
                TargetNS.SetDialogPosition('', '', 1);
            });
        }

        // initiate DefineZoomArea
        var MagnifierActive;
        var DefineZoomArea = {};
        $Elements.MagnifierZoom.bind({
            click: function(e) {
                $Elements.Body.css('cursor', 'crosshair');
                MagnifierActive = 1;
                $Elements.MagnifierZoom.addClass('Magnifier_active');
                $Elements.ZoomArea.removeClass("Hidden");
                $Elements.ZoomArea.css({
                    'left': e.pageX + 1 + 'px',
                    'top': e.pageY + 1 + 'px'
                });
            }
        });

        $Elements.Body.bind({
            mousedown: function(e) {
                // disable selection within graph and on options
                if (MagnifierActive || Move.Start) {
                    $Elements.Body.disableSelection();
                    // for firefox
                    $Elements.GraphBody.addClass('NoSelection');
                    $Elements.Options.addClass('NoSelection');
                }
                if (!e) {
                    e = window.event;
                }
                // hide context menu if necessary
                if (!$Elements.Context.hasClass('Hidden')) {
                    var TargetID = e.target.id || e.target.parentElement.id || e.target.parentElement.parentElement.id;
                    if (!$('#' + TargetID).hasClass('Context')) {
                        $Elements.Context.addClass('Hidden');
                    }
                }
            },
            mousemove: function(e) {
                if (!DefineZoomArea.Active && MagnifierActive) {
                    $Elements.ZoomArea.css({
                        'left': e.pageX + 1 + 'px',
                        'top': e.pageY + 1 + 'px'
                    });
                }
            },
            mouseup: function() {
                // enable selection
                $Elements.Body.enableSelection();
                $Elements.GraphBody.removeClass('NoSelection');
                $Elements.Options.removeClass('NoSelection');

                if (MagnifierActive) {
                    DefineZoomArea.Active = 0;
                    MagnifierActive = 0;
                    $Elements.Body.css('cursor', '');
                    $Elements.MagnifierZoom.removeClass('Magnifier_active');
                    $Elements.ZoomArea.height(10);
                    $Elements.ZoomArea.width(10);
                    // for ie, it scrolls to 0:0 if ZoomArea gets hidden class
                    var ScrollX = $Elements.GraphBody.scrollLeft();
                    var ScrollY = $Elements.GraphBody.scrollTop();
                    $Elements.ZoomArea.addClass('Hidden');
                    if (ScrollX != $Elements.GraphBody.scrollLeft() || ScrollY != $Elements.GraphBody.scrollTop()) {
                        $Elements.GraphBody.scrollLeft(ScrollX);
                        $Elements.GraphBody.scrollTop(ScrollY);
                    }
                }
            }
        });

        // bind mousedown-function on all nodes
        $('.GraphNode').bind('mousedown', function(e) {
            if (!e) {
                e = window.event;
            }
            NodeBindMousdown(e);
        });

        var Twice = 0; // required for scrolling for ie9+, because it fires twice
        $Elements.GraphBody.bind({
            mousedown: function(e) {
                if (!e) {
                    e = window.event;
                }
                if (DummyConnection && !$(e.target).is( "circle" )) {
                    jsPlumb.detach(DummyConnection);
                    DummyConnection = '';
                }
                // start DefineZoomArea if necessary
                if (MagnifierActive) {
                    if ($DraggedNode) {
                        MagnifierActive = 0;
                        $Elements.Body.css('cursor', '');
                        $Elements.MagnifierZoom.removeClass('OptButton_active');
                        $Elements.ZoomArea.height(10);
                        $Elements.ZoomArea.width(10);
                        $Elements.ZoomArea.addClass('Hidden');
                    } else {
                        if (DummyConnection) {
                            jsPlumb.detach(DummyConnection);
                            DummyConnection = '';
                        }
                        $Elements.ZoomArea.removeClass('Hidden');
                        DefineZoomArea.Left = e.pageX;
                        DefineZoomArea.Top = e.pageY;
                        $Elements.ZoomArea.css({
                            'left': e.pageX + 'px',
                            'top': e.pageY + 'px'
                        });
                        DefineZoomArea.Active = 1;
                    }
                }
                // save right- and bottom-corner of viewpoint
                Max.X = $Elements.GraphBody.width() + $Elements.GraphBody.scrollLeft() - 20;
                Max.Y = $Elements.GraphBody.height() + $Elements.GraphBody.scrollTop() - 20;

                // if no node is dragged and no zoom-area will be defined, start move-screen-behavier
                if (!$DraggedNode && !MagnifierActive ) {
                    Move.X = $Elements.GraphBody.scrollLeft() + e.pageX;
                    Move.Y = $Elements.GraphBody.scrollTop() + e.pageY;
                    Move.Start = 1;
                    $Elements.GraphBody.css('cursor', 'move');
                }
            },
            // disable default browser context-menu
            contextmenu: function() {
                return false
            },
            mouseup: function(e) {
                if (!e) {
                    e = window.event;
                }
                // save mouse-position
                MousePos.X = e.pageX;
                MousePos.Y = e.pageY;
                // stop DefineZoomArea
                if (DefineZoomArea.Active) {
                    if ($Elements.ZoomArea.height() > 10 && Elements.ZoomArea.width() > 10) {
                        NowZoom(parseFloat($Elements.ZoomArea.css('top'), 10), parseFloat($Elements.ZoomArea
                            .css('left'), 10), $Elements.ZoomArea.height(), $Elements.ZoomArea.width());
                    }
                }
                Move = {};
                $Elements.GraphBody.css('cursor', '');
            },
            mouseleave: function() {
                Move = {};
                $Elements.GraphBody.css('cursor', '');
            },
            mousemove: function(e) {
                if (!e) {
                    e = window.event;
                }
                // resize ZoomArea
                if (DefineZoomArea.Active) {
                    if ((e.pageY - DefineZoomArea.Top) < 0) {
                        $Elements.ZoomArea.css('top', e.pageY + 1 + 'px');
                        $Elements.ZoomArea.height(DefineZoomArea.Top - e.pageY);
                    } else {
                        $Elements.ZoomArea.height(e.pageY - 2 - parseFloat($Elements.ZoomArea.css('top'), 10));
                    }
                    if ((e.pageX - DefineZoomArea.Left) < 0) {
                        $Elements.ZoomArea.css('left', e.pageX + 1 + 'px');
                        $Elements.ZoomArea.width(DefineZoomArea.Left - e.pageX);
                    } else {
                        $Elements.ZoomArea.width(e.pageX - 2 - parseFloat($Elements.ZoomArea.css('left'), 10));
                    }
                }
                if (Move.Start) {
                    $Elements.GraphBody.scrollLeft(Move.X - e.pageX);
                    $Elements.GraphBody.scrollTop(Move.Y - e.pageY);
                    Move.X = $Elements.GraphBody.scrollLeft() + e.pageX;
                    Move.Y = $Elements.GraphBody.scrollTop() + e.pageY;
                }
            },
            // bind another mousewheel-behavior for zooming
            mousewheel: function(e) {
                if (!e) {
                    e = window.event;
                }
                if (e.originalEvent.wheelDeltaY) { // for chrome and others
                    if (e.originalEvent.wheelDeltaY < 0) {
                        TargetNS.Zoom(1);
                    } else {
                        TargetNS.Zoom(2);
                    }
                    return false;
                } else { // for ie
                    if (!Twice) {
                        if (e.wheelDelta < 0) {
                            TargetNS.Zoom(1);
                        } else {
                            TargetNS.Zoom(2);
                        }
                        if (BroType > 4) {
                            Twice = 1;
                        }
                    } else {
                        Twice = 0;
                    }
                    return false;
                }
            },
            DOMMouseScroll: function(e) { // for firefox
                if (e.originalEvent.axis == 2) {
                    if (e.originalEvent.detail > 0) {
                        TargetNS.Zoom(1);
                    } else {
                        TargetNS.Zoom(2);
                    }
                }
                return false;
            }
        });
    }

    // .GraphNode bind-functions - remember dragged node
    function NodeBindMousdown(e) {
        if (!e) {
            e = window.event;
        }
        var NodeDragID = e.target.id || e.target.parentElement.id || e.target.parentElement.parentElement.id;
        $DraggedNode = $('#' + NodeDragID);
    }
    /**
     * @function
     * @return nothing This function shows an alternative context-menu
     */
    TargetNS.NodeBindContextmenu = function(objectFullID, objectID, $objectNode, objectName, e) {
        if (DummyConnection) {
            jsPlumb.detach(DummyConnection);
            DummyConnection = '';
        }
        $DraggedNode = '';

        ContextObjectFullID = objectFullID;
        ContextObjectID = objectID
        $ContextObjectNode = $objectNode;
        ContextObjectName = objectName;

        $Elements.Context.find('.Header > h2').html(ContextObjectName);
        // get context menu position
        var ContextPos = {
            x: e.pageX + $Elements.GraphBody.scrollLeft() - 5,
            y: e.pageY - $Elements.Options.height() + $Elements.GraphBody.scrollTop() - 5
        };
        if ((ContextPos.x + $Elements.Context.width()) > Max.X) {
            ContextPos.x = Max.X - $Elements.Context.width();
        }
        if ((ContextPos.y + $Elements.Context.height()) > Max.Y) {
            ContextPos.y = Max.Y - $Elements.Context.height();
        }
        // set context menu position
        $Elements.Context.css({
            'left': ContextPos.x + 'px',
            'top': ContextPos.y + 'px'
        });
        $Elements.Context.removeClass('Hidden');
    }

    /**
     * @function
     * @return nothing These two functions open a new site and copy the graph into it for printing
     */
    TargetNS.PrintPre = function() {
        if (DummyConnection) {
            jsPlumb.detach(DummyConnection);
            DummyConnection = '';
        }
        $Elements.Shield.removeClass('Hidden');
        $Elements.Body.css('cursor', 'wait');
        var TempZoom = CurZoom;
        var RotateTop = FitGraph($Elements.PrintGraphBody.width() - 5, $Elements.PrintGraphBody.height() - 5, 1);
        $Elements.PrintScale.html($Elements.Scale.html());
        window.GraphPrint = [ $Elements.PrintBox.html(), RotateTop, CurZoom ];

        var URL = Core.Config.Get('Baselink') + 'Action=AgentLinkGraph' + GraphConfig.ObjectType + ';' + 'Subaction=CreatePrintOutput;'
                + ';ObjectFullID=' + GraphConfig.StartFullID + SerializeData(Core.App.GetSessionInformation());
        Core.UI.Popup.OpenPopup(URL, 'LinkGraph', 'LinkGraph');

        $Elements.PrintScale.html('');
        if (TempZoom != CurZoom) {
            CurZoom = TempZoom;
            SetZoom();
        }
        $Elements.Shield.addClass('Hidden');
        $Elements.Body.css('cursor', '');
    }
    TargetNS.PrintPost = function() {
        $('#PrintWindow').html(window.opener.GraphPrint[0]);
        $.each($('.GraphNode'), function(Index, Object) {
            $('#' + Object.id).find('a').contents().unwrap();
        });
        var RotateDeg = 0;
        if (opener.GraphPrint[1]) {
            $('#PrintScale').css('top', ($('#PrintInfo').height() + opener.GraphPrint[1]*opener.GraphPrint[2] + 10));
            RotateDeg = -90;
        }
        opener.GraphPrint[1] = -90;
        $('#PrintScale').css({
            "-webkit-transform":"scale("+opener.GraphPrint[2]+") rotate("+RotateDeg+"deg)",
            "-webkit-transform-origin": "0% 0%",
            "-moz-transform":"scale("+opener.GraphPrint[2]+") rotate("+RotateDeg+"deg)",
            "-moz-transform-origin": "0% 0%",
            "-ms-transform":"scale("+opener.GraphPrint[2]+") rotate("+RotateDeg+"deg)",
            "-ms-transform-origin": "0% 0%",
            "-o-transform":"scale("+opener.GraphPrint[2]+") rotate("+RotateDeg+"deg)",
            "-o-transform-origin": "0% 0%",
            "transform":"scale("+opener.GraphPrint[2]+") rotate("+RotateDeg+"deg)",
            "transform-origin": "0% 0%",
            "-ms-filter": "progid:DXImageTransform.Microsoft.Matrix(M11="+CurZoom+", M12=0, M21=0, M22="+CurZoom+", SizingMethod='auto expand')"
        });
        jsPlumb.setZoom(CurZoom);
        window.print();
        // window.close();
    }

    /**
     * @function
     * @return nothing This functions saves the graph (current positions of the nodes and config)
     */
    TargetNS.SaveGraph = function() {
        if (DummyConnection) {
            jsPlumb.detach(DummyConnection);
            DummyConnection = '';
        }
        var Overwrite = 0;
        // submit save
        function SaveThisGraph() {
            var GraphID;
            var GraphName;
            if (Overwrite) {
                GraphID = $Dialog.find('#SavedGraphSelection').val();
            } else {
                GraphName = $NewWriteName.val();
                if (!GraphName || GraphName == '0') {
                    $NoSaveName.removeClass('Hidden');
                    return false;
                }
                if (SavedGraphs.KnownNames && SavedGraphs.KnownNames[GraphName]) {
                    $NotUniqueName.removeClass('Hidden');
                    return false;
                }
            }

            // get layout (node positions)
            var LayoutString = '';
            $.each(OrgValues, function(Index, Object) {
                if ( Object.Left == undefined ) {
                    return true;
                }
                LayoutString += Index + '::' + Math.round(Object.Left) + '::' + Math.round(Object.Top) + '_-_';
            });

            var URL = Core.Config.Get('Baselink');
            var Data = {
                Action: 'AgentLinkGraph' + GraphConfig.ObjectType,
                Subaction: 'SaveGraph',
                Layout: LayoutString,
                GraphConfig: GraphConfig.SearchDepth + ':::' + GraphConfig.LinkTypes + ':::' + GraphConfig.AdjustingStrength + ':::' + GraphConfig.SubTypes,
                CurID: GraphConfig.StartID,
                GraphName: GraphName,
                GraphID: GraphID
            };
            // do save
            $Elements.Shield.removeClass('Hidden');
            Core.AJAX.FunctionCall(URL, Data, function(Result) {
                if (!Result.ID) {
                    $Elements.Shield.addClass('Hidden');
                    ShowNotice('SaveGraph');
                } else {
                    if (Result.ID == 'NoID') {
                        SavedGraphs.Selection = '';
                        SavedGraphs.NoSavedGraphs = 0;
                    }
                    if (SavedGraphs.Selection) {
                        if (!Overwrite) {
                            SavedGraphs.Selection = SavedGraphs.Selection.replace("</select>", '<option value="'
                                    + Result.ID + '">' + GraphName + '</option></select>');
                            if (!SavedGraphs.KnownNames) {
                                SavedGraphs.KnownNames = {};
                            }
                            SavedGraphs.KnownNames[GraphName] = 1;
                        }
                        SavedGraphs[Result.ID] = {
                            SubTypes: Result.GraphConfig.SubTypes,
                            LinkTypes: Result.GraphConfig.LinkTypes,
                            Depth: GraphConfig.SearchDepth,
                            Strength: Result.GraphConfig.Strength,
                            LastChangedTime: Result.LastChangedTime,
                            LastChangedBy: Result.LastChangedBy
                        };
                        SavedGraphs.NoSavedGraphs = 0;
                    }
                    $('#GraphSaved').removeClass('Hidden');
                    setTimeout(function() {
                        $('#GraphSaved').addClass('Hidden');
                        $Elements.Shield.addClass('Hidden');
                    }, 1500);
                }
            });
            Core.UI.Dialog.CloseDialog($Dialog);
        }
        // show dialog
        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: $Elements.SOGraph.find('.Header > h2').html(),
            HTML: $Elements.SOGraph.find('.Content').html(),
            PositionTop: '45%',
            PositionLeft: 'center',
            AllowAutoGrow: true,
            Buttons: [ {
                Label: $('#SaveSubmit').val(),
                Type: 'Submit',
                Function: SaveThisGraph,
                Class: 'CallForAction'
            }, {
                Label: $('#SaveCancel').val(),
                Type: 'Close'
            } ]
        });
        $Dialog = $('.Dialog');
        TargetNS.SetDialogPosition('', '', 1);
        var $NewWriteValue = $Dialog.find('#NewWriteValue'), $OverwriteValue = $Dialog.find('#OverwriteValue'),
            $NewWriteName = $Dialog.find('#NewWriteName'), $SavedGraphSelection = $Dialog.find('#SavedGraphSelection'),
            $NoSaveName = $Dialog.find('#NoSaveName'), $NotUniqueName = $Dialog.find('#NotUniqueName'),
            $NewWriteRadio = $Dialog.find('#NewWriteRadio'), $OverwriteRadio = $Dialog.find('#OverwriteRadio')
        $SaveButton = $Dialog.find('#DialogButton1');

        // if saved graphs are not looked up yet
        if (!SavedGraphs.Selection) {
            $SaveButton.attr('disabled', 'disabled');
            $OverwriteRadio.attr('disabled', 'disabled');
            $SaveButton.css('color', 'silver');
            // get all saved graphs for this object
            var URL = Core.Config.Get('Baselink');
            var Data = {
                Action: 'AgentLinkGraph' + GraphConfig.ObjectType,
                Subaction: 'GetSavedGraphs',
                CurID: GraphConfig.StartID
            };
            Core.AJAX.FunctionCall(URL, Data, function(Result) {
                SavedGraphs = Result.Graphs;
                $Dialog.find('#StillWorkingImage').remove();
                $OverwriteRadio.removeAttr('disabled');
                $SaveButton.removeAttr('disabled');
                $SaveButton.css('color', '');
            });
        } else {
            $Dialog.find('#StillWorkingImage').remove();
        }

        function HideSaveErrors() {
            $NoSaveName.addClass('Hidden');
            $NotUniqueName.addClass('Hidden');
        }
        $NewWriteName.focus(function() {
            HideSaveErrors();
        });

        // change between new and overwrite
        $NewWriteRadio.change(function() {
            $NewWriteValue.removeClass('Hidden');
            $OverwriteValue.addClass('Hidden');
            Overwrite = 0;
            HideSaveErrors();
            $Dialog.find('#NoSavedGraphs').addClass('Hidden');
            $SaveButton.removeAttr('disabled');
            $SaveButton.css('color', '');
            TargetNS.SetDialogPosition('', '');
        });
        $OverwriteRadio.change(function() {
            if (!SavedGraphs.NoSavedGraphs) {
                $Dialog.find('#SaveGraphSelection').html(SavedGraphs.Selection);
                var $SavedGraphSelection = $('#SavedGraphSelection');
                $SavedGraphSelection.change(function() {
                    var SavedGraphID = $SavedGraphSelection.val();

                    $Dialog.find('#SaveGraphSubTypes').html(SavedGraphs[SavedGraphID].SubTypes);
                    $Dialog.find('#SaveGraphLinkTypes').html(SavedGraphs[SavedGraphID].LinkTypes);
                    $Dialog.find('#SaveGraphDepth').html(SavedGraphs[SavedGraphID].Depth);
                    $Dialog.find('#SaveGraphStrength').html(SavedGraphs[SavedGraphID].Strength);
                    $Dialog.find('#SaveGraphLastChangedTime').html(SavedGraphs[SavedGraphID].LastChangedTime);
                    $Dialog.find('#SaveGraphLastChangedBy').html(SavedGraphs[SavedGraphID].LastChangedBy);
                });
                $SavedGraphSelection.change();
                $OverwriteValue.removeClass('Hidden');
                Overwrite = 1;
            } else {
                $Dialog.find('#NoSavedGraphs').removeClass('Hidden');
                $SaveButton.attr('disabled', 'disabled');
                $SaveButton.css('color', 'silver');
            }
            TargetNS.SetDialogPosition('', '');
            $NewWriteValue.addClass('Hidden');
            HideSaveErrors();
        });
    }

    /**
     * @function
     * @return nothing This function loads the function for fitting the graph into the visible area
     */
    TargetNS.FitIn = function() {
        if (DummyConnection) {
            jsPlumb.detach(DummyConnection);
            DummyConnection = '';
        }
        $Elements.Body.css('cursor', 'wait');
        $Elements.Shield.removeClass('Hidden');
        FitGraph($Elements.GraphBody.width() - 8, $Elements.GraphBody.height() - 8);
        $Elements.GraphBody.scrollTop(0);
        $Elements.GraphBody.scrollLeft(0);
        $Elements.Shield.addClass('Hidden');
        $Elements.Body.css('cursor', '');
    }

    /**
     * @function
     * @param {Integer} z Defines if should be zoomed in or out
     * @return nothing This function scales the graph
     */
    TargetNS.Zoom = function(z) {
        if (DummyConnection) {
            jsPlumb.detach(DummyConnection);
            DummyConnection = '';
        }
        if (!Nodes[0]) {
            return;
        }
        $Elements.Shield.removeClass('Hidden');
        // which zoom?
        if (z == 1) {
            if ((CurZoom) > 0.5) {
                CurZoom = Math.round(CurZoom * 10 - 1) / 10;
                SetZoom();
            }
        }
        if (z == 2) {
            if ((CurZoom) < 1) {
                CurZoom = Math.round(CurZoom * 10 + 1) / 10;
                SetZoom();
            }
        }
        if (z == 3 && CurZoom != 1) {
            CurZoom = 1;
            SetZoom();
        }
        $Elements.Shield.addClass('Hidden');
    }

    /**
     * @function
     * @return nothing This function adjusts the graph
     */
    TargetNS.Adjust = function(i) {
        if (DummyConnection) {
            jsPlumb.detach(DummyConnection);
            DummyConnection = '';
        }
        $Elements.Body.css('cursor', 'wait');
        $Elements.Shield.removeClass('Hidden');
        var NodesValues = {};
        for ( var x = 0, len = Nodes.length; x < len; x++) {
            NodesValues[Nodes[x].ID] = {
                x: $Elements.GraphBody.width() / 2 - 5 + Math.random() * 10,
                y: $Elements.GraphBody.height() / 2 - 5 + Math.random() * 10,
                fx: 0,
                fy: 0,
                vx: 0,
                vy: 0
            };
        }

        var Strengths = {
            1: 0.9,
            2: 0.6,
            3: 0.3
        };
        var Str = Strengths[GraphConfig.AdjustingStrength];
        var Stable = 0;
        var IterateBreak = 0;
        var Count = 0;
        var ChangeOld = 0;

        // function for: close dialog with notice about 'graph could not be adjusted'
        function AdjustClose() {
            Core.UI.Dialog.CloseDialog($('.Dialog'));
            $Elements.Shield.addClass('Hidden');
            $Elements.Body.css('cursor', '');
        }

        // function for: iterative adjusting
        function Iterate() {
            for ( var a = 0, len = Nodes.length; a < len; a++) {
                var A = Nodes[a].ID;
                for ( var b = 0, len = Nodes.length; b < len; b++) {
                    var B = Nodes[b].ID;
                    if (A == B) {
                        continue;
                    }
                    // Coulomb: repulsion -> push apart
                    var Dis = Math.sqrt((NodesValues[A].x - NodesValues[B].x) * (NodesValues[A].x - NodesValues[B].x)
                            + (NodesValues[A].y - NodesValues[B].y) * (NodesValues[A].y - NodesValues[B].y));
                    var RepDis = 25 / Dis;
                    NodesValues[A].fx += RepDis * (NodesValues[A].x - NodesValues[B].x);
                    NodesValues[A].fy += RepDis * (NodesValues[A].y - NodesValues[B].y);
                    var AlrConn = 0;
                    // Hook: attraction -> pull together
                    if (AlreadyLinked[A + '--' + B] || AlreadyLinked[B + '--' + A]) {
                        var AttDis = Dis / 4200;
                        NodesValues[A].fx += AttDis * (NodesValues[B].x - NodesValues[A].x);
                        NodesValues[A].fy += AttDis * (NodesValues[B].y - NodesValues[A].y);
                        NodesValues[B].fx += AttDis * (NodesValues[A].x - NodesValues[B].x);
                        NodesValues[B].fy += AttDis * (NodesValues[A].y - NodesValues[B].y);
                        if (AlreadyLinked[A + '--' + B]) {
                            $.each(AlreadyLinked[A + '--' + B], function() {
                                AlrConn++;
                            });
                        } else {
                            $.each(AlreadyLinked[B + '--' + A], function() {
                                AlrConn++;
                            });
                        }
                    }
                    // are there min 2 connections between source and target,
                    // push them a bit more apart
                    if (AlrConn > 1) {
                        NodesValues[A].fx -= 0.01 * (NodesValues[B].x - NodesValues[A].x);
                        NodesValues[A].fy -= 0.01 * (NodesValues[B].y - NodesValues[A].y);
                        NodesValues[B].fx -= 0.01 * (NodesValues[A].x - NodesValues[B].x);
                        NodesValues[B].fy -= 0.01 * (NodesValues[A].y - NodesValues[B].y);
                    }
                }
                // Gravity -> pull node to mid
                var AttMid = 3 * len / 120;
                NodesValues[A].fx += AttMid * ($Elements.GraphBody.width() / 2 - NodesValues[A].x);
                NodesValues[A].fy += AttMid * ($Elements.GraphBody.height() / 2 - NodesValues[A].y);
            }

            var Change = 0;
            var Min = {
                left: $Elements.GraphBody.width(),
                top: $Elements.GraphBody.height()
            };
            for ( var x = 0, len = Nodes.length; x < len; x++) {
                NodesValues[Nodes[x].ID].vx = (NodesValues[Nodes[x].ID].vx + NodesValues[Nodes[x].ID].fx) * Str;
                NodesValues[Nodes[x].ID].vy = (NodesValues[Nodes[x].ID].vy + NodesValues[Nodes[x].ID].fy) * Str;
                Change += Math.abs(NodesValues[Nodes[x].ID].fx) + Math.abs(NodesValues[Nodes[x].ID].fy);
                // try it once more if values without sense are given or it
                // takes too much iterations
                if (isNaN(NodesValues[Nodes[x].ID].vx) || isNaN(NodesValues[Nodes[x].ID].vy) || Count > 250) {
                    for ( var x = 0, len = Nodes.length; x < len; x++) {
                        NodesValues[Nodes[x].ID] = {
                            x: $Elements.GraphBody.width() / 2 - 5 + Math.random() * 10,
                            y: $Elements.GraphBody.height() / 2 - 5 + Math.random() * 10,
                            fx: 0,
                            fy: 0,
                            vx: 0,
                            vy: 0
                        };
                    }
                    if ( Nodes.length < 5 ) {
                        Str += 0.2;
                    } else {
                        Str -= 0.2;
                    }
                    Stable = 0;
                    Count = 0
                    ChangeOld = 0;
                    IterateBreak++;
                    break;
                }
                NodesValues[Nodes[x].ID].x = NodesValues[Nodes[x].ID].vx;
                NodesValues[Nodes[x].ID].y = NodesValues[Nodes[x].ID].vy;
                if (NodesValues[Nodes[x].ID].x < Min.left) {
                    Min.left = NodesValues[Nodes[x].ID].x;
                }
                if (NodesValues[Nodes[x].ID].y < Min.top) {
                    Min.top = NodesValues[Nodes[x].ID].y;
                }
            }

            // count how often the change of cordinates is nearly equal
            if (ChangeOld == Math.round(Change)) {
                Stable++;
            } else {
                ChangeOld = Math.round(Change);
                if (Stable > 0) {
                    Stable--;
                }
            }

            Count++;
            // stop adjusting if second try is also not working
            if (IterateBreak > 1) {
                // show notice if graph could not be adjusted
                Core.UI.Dialog.ShowDialog({
                    Modal: false,
                    Title: $('#NotAdjustedTitle').val(),
                    HTML: $('#NotAdjustedContent').val(),
                    PositionTop: $Elements.GraphBody.height() / 2 - $Elements.Options.height(),
                    PositionLeft: 'Center',
                    Buttons: [ {
                        Label: 'OK',
                        Type: 'Close',
                        Function: AdjustClose
                    } ]
                });
                return false;
            }

            // check if graph is almost stable
            if (Stable < 5) {
                Iterate();
            } else {
                // move nodes
                for ( var x = 0, len = Nodes.length; x < len; x++) {
                    Nodes[x].Object.css({
                        'left': NodesValues[Nodes[x].ID].x + Min.left * -1 + 'px',
                        'top': NodesValues[Nodes[x].ID].y + Min.top * -1 + 'px'
                    });
                    SaveOrgValues(Nodes[x].Object, 1);
                    jsPlumb.recalculateOffsets(Nodes[x].ID);
                }
                jsPlumb.repaintEverything();
                // second have do be here because of:
                // https://github.com/sporritt/jsPlumb/issues/93
                jsPlumb.repaintEverything();
                $Elements.Shield.addClass('Hidden');
                $Elements.Body.css('cursor', '');
            }
        }
        Iterate();
    }

    /**
     * @function
     * @return nothing This function allows to link a node with another present node
     */
    TargetNS.PresentNode = function() {
        var $Node = $ContextObjectNode;
        var x = parseFloat($Node.css('left'), 10) + $Node.width() + 30;
        var y = parseFloat($Node.css('top'), 10) + $Node.height() + 30;
        if (x > (Max.X - 5)) {
            x = x - $Node.width() - 50;
        }
        if (y > (Max.Y - 5)) {
            y = y - $Node.height() - 50;
        }
        $Elements.Dummy.css({
            'left': x + 'px',
            'top': y + 'px'
        });
        $Elements.DummyShow.removeClass('Hidden');
        $Elements.DummyShow.css({
            'left': x + 'px',
            'top': y + 'px',
            'width': '1px',
            'height': '1px',
            '-moz-border-radius': '100px',
            'border-radius': '100px'
        });
        $Elements.DummyShow.animate({
            'left': x - 51 + 'px',
            'top': y - 51 + 'px',
            'width': '100px',
            'height': '100px',
            '-moz-border-radius': '100px',
            'border-radius': '100px'
        }, 450, function() {
            $Elements.DummyShow.addClass('Hidden');
        });
        jsPlumb.connect({
            endpoints: [ 'Blank', [ 'Dot', {
                radius: (10 / CurZoom)
            } ] ],
            endpointStyle: {
                fillStyle: '#F58500'
            },
            source: ContextObjectFullID,
            target: 'ConnectionDummy',
            paintStyle: {
                lineWidth: (2 / CurZoom),
                dashstyle: "5 1 2 1",
                strokeStyle: '#F58500'
            },
            overlays: [ [ 'Arrow', {
                width: (15 / CurZoom),
                length: (20 / CurZoom),
                location: 1
            } ] ],
            cssClass: 'DummyConnection'
        });
    }

    // additional functions and settings -------------------------------------------

    /**
     * @function
     * @return nothing This function set the object-specific check-rights-function
     */
    TargetNS.SetRightFunction = function(checkRights, setRightAttr) {
        CheckRights = checkRights;
        SetRightAttr = setRightAttr;
    }

    //////////////////////////////////////////////////////
    // reset dummy-connection if new target and source are the same or user have no rigths to link with target
    jsPlumb.bind('beforeDrop', function(Conn) {
        if ( Conn.sourceId == Conn.targetId || !CheckRights(1, Conn.targetId) ) {
            return false;
        }
        NotPresent = 0;
        return true;
    });

    //////////////////////////////////////////////////////
    // if a new connection is created
    jsPlumb.bind('connection', function(Conn) {

        // function for: close choose-link-dialog with cancel
        function ChooseLinkCancel() {
            // detach connection
            if (Conn) {
                jsPlumb.detach(Conn);
            }
            DummyConnection = '';
            Core.UI.Dialog.CloseDialog($Dialog);
        }

        // function for: submit choose-link-dialog
        function ChooseTypeSubmit() {
            $Dialog.find('button').attr('disabled', 'disabled');
            TargetNS.FinishLinking(Conn.sourceId, Conn.targetId, Conn.connection);
        }

        if (Conn.targetId != 'ConnectionDummy') {
            if (NotPresent) {
                return;
            }
            NotPresent = 1;
            // show dialog with select-able LinkTypes
            var Title = $('#' + Conn.sourceId).attr('Name') + ' ' + $Elements.ChooseBox.find('#ChooseHeader').val()
                    + ' ' + $('#' + Conn.targetId).attr('Name');

            Core.UI.Dialog.ShowDialog({
                Type: 'Question',
                Modal: true,
                Title: Title,
                HTML: $Elements.ChooseBox.html(),
                PositionTop: MousePos.Y,
                PositionLeft: MousePos.X,
                Buttons: [ {
                    Label: $('#TypeSubmit').val(),
                    Type: 'Submit',
                    Function: ChooseTypeSubmit,
                    Class: 'CallForAction'
                }, {
                    Label: $('#TypeCancel').val(),
                    Type: 'Close',
                    Function: ChooseLinkCancel
                } ]
            });
            $Dialog = $('.Dialog');
            TargetNS.SetDialogPosition(MousePos.X, MousePos.Y);
            $Dialog.find('#ChooseTarget').addClass('Hidden');
        } else {
            DummyConnection = Conn;
        }
    });

    //////////////////////////////////////////////////////
    // set new link-type, change direction or remove connections by click on it
    jsPlumb.bind('click', function(Conn) {
        // if graph should be moved, ignore click
        if (Move.Start) {
            return false;
        }
        // if target is ConnectionDummy, just remove DummyConnection and return
        if (Conn.targetId == 'ConnectionDummy') {
            jsPlumb.detach(Conn);
            DummyConnection = '';
            return false;
        }
        // if not, remove DummyConnection either but go on
        if (DummyConnection) {
            jsPlumb.detach(DummyConnection);
            DummyConnection = '';
        }
        var Label = Conn.getOverlay('label').getLabel();

        // function for: if delete is confirmed
        function DeleteSubmit(Type, Callback) {
            $Dialog.find('button').attr('disabled', 'disabled');
            $Elements.Shield.removeClass('Hidden');
            Core.UI.Dialog.CloseDialog($Dialog);

            $.each(LinkTypes, function(Index, Object) {
                if (Label == Object) {
                    // update database
                    var URL = Core.Config.Get('Baselink');
                    var Data = {
                        Action: 'AgentLinkGraph' + GraphConfig.ObjectType,
                        Subaction: 'DeleteConnection',
                        Source: Conn.sourceId,
                        SourceInciStateType: $('#'+Conn.sourceId).find('.IncidentImage').attr('alt'),
                        Target: Conn.targetId,
                        TargetInciStateType: $('#'+Conn.targetId).find('.IncidentImage').attr('alt'),
                        LinkType: Index
                    };
                    Core.AJAX.FunctionCall(URL, Data, function(Result) {
                        if (!Result.Result) {
                            ShowNotice('DeleteLink');
                        } else {
                            if (!Type) {
                                jsPlumb.detach(Conn);
                            }
                            AlreadyLinked[Conn.sourceId + '--' + Conn.targetId][Index] = 0;
                            AlreadyLinked[Conn.targetId + '--' + Conn.sourceId][Index] = 0;

                            if (GraphConfig.ObjectType == 'ITSMConfigItem') {
                                // change incident image of source if necessary
                                Core.KIX4OTRS.AgentLinkGraphITSMConfigItem.DeleteNeighbor(Conn.sourceId, Conn.targetId, Index, Conn.sourceId);
                                if (Result.PropagateStart != 0) {
                                    Core.KIX4OTRS.AgentLinkGraphITSMConfigItem.ChangeInciImage(Result.PropagateStart, Result.InciState, Result.Image, Result.LinkType,
                                        Result.Direction, 1);
                                }
                            }
                        }
                        if (!Type) {
                            $Elements.Shield.addClass('Hidden');
                        } else {
                            Callback();
                        }
                    });
                    return false;
                }
            });
        }

        // function for: if type is submitted
        function TypeSubmit() {
            $Dialog.find('button').attr('disabled', 'disabled');
            var Source = Conn.sourceId, Target = Conn.targetId;
            var ChangeDirection = 0;
            if ($Dialog.find('#ChangeDirection').is(':checked')) {
                ChangeDirection = 1;
                var Temp = Source;
                Source = Target;
                Target = Temp;
            }

            var Type = $('.Dialog').find('#LinkTypes option:selected').text();
            $.each(LinkTypes, function(Index, Object) {
                if (Type == Object) {
                    // check for duplication -> just 1 connection per type is possible
                    if ((AlreadyLinked[Source + '--' + Target] && AlreadyLinked[Source + '--' + Target][Index])
                            || (Label != Type && (AlreadyLinked[Target + '--' + Source] && AlreadyLinked[Target
                                    + '--' + Source][Index]))) {
                        ShowNotice('Double', '', $('#Double').val());
                        $Elements.Shield.addClass('Hidden');
                        return;
                    }

                    // delete connection and add new connection
                    DeleteSubmit(Type, function() {
                        // update database
                        var URL = Core.Config.Get('Baselink');
                        var Data = {
                            Action: 'AgentLinkGraph' + GraphConfig.ObjectType,
                            Subaction: 'SaveNewConnection',
                            Source: Source,
                            SourceInciStateType: $('#'+Source).find('.IncidentImage').attr('alt'),
                            Target: Target,
                            TargetInciStateType: $('#'+Target).find('.IncidentImage').attr('alt'),
                            LinkType: Index
                        };
                        Core.AJAX.FunctionCall(URL, Data, function(Result) {
                            // if it failed show notice
                            if (!Result.Result) {
                                ShowNotice('CreateLink');
                            } else {
                                var Connection;
                                // change connection
                                if (ChangeDirection) {
                                    jsPlumb.detach(Conn);
                                    Connection = jsPlumb.connect({
                                        source: Source,
                                        target: Target
                                    });
                                } else {
                                    Connection = Conn;
                                }

                                Connection.removeAllOverlays();
                                SetLabelArrowColor(Connection, Index);

                                if (GraphConfig.ObjectType == 'ITSMConfigItem') {
                                    // change incident image of source if necessary
                                    if (Result.PropagateStart != 0) {
                                        Core.KIX4OTRS.AgentLinkGraphITSMConfigItem.ChangeInciImage(Result.PropagateStart, Result.Warning, Result.Image,
                                            Result.LinkType, Result.Direction, '');
                                    }
                                }
                            }
                            $Elements.Shield.addClass('Hidden');
                            return false;
                        });
                    });
                }
            });
        }

        if (CheckRights(1, Conn.sourceId) && CheckRights(1, Conn.targetId)) {

            // show dialog
            Core.UI.Dialog.ShowDialog({
                Modal: true,
                Title: $('#' + Conn.sourceId).attr('name') + ' --- ' + Conn.getOverlay('label').getLabel() + ' ---> '
                        + $('#' + Conn.targetId).attr('name'),
                HTML: $Elements.SetTODL.find('.Content').html(),
                PositionTop: MousePos.Y,
                PositionLeft: MousePos.X,
                Buttons: [ {
                    Label: $('#SetTypeSubmit').val(),
                    Type: 'Submit',
                    Function: TypeSubmit,
                    Class: 'CallForAction'
                }, {
                    Label: $('#DeleteSubmit').val(),
                    Type: 'Submit',
                    Function: DeleteSubmit,
                    Class: 'CallForAction'
                }, {
                    Label: $('#DeleteCancel').val(),
                    Type: 'Close'
                } ]
            });
            $Dialog = $('.Dialog');
            TargetNS.SetDialogPosition(MousePos.X, MousePos.Y);
        }
    });

    //////////////////////////////////////////////////////
    // function for zooming in if ZoomArea is defined
    function NowZoom(Top, Left, Height, Width) {
        var Zoom = 1;
        var Props = {
            MidX: (Left + Width / 2 + $Elements.GraphBody.scrollLeft()) / CurZoom,
            MidY: (Top + Height / 2 - $Elements.Options.height() + $Elements.GraphBody.scrollTop()) / CurZoom,
            GBMidX: $Elements.GraphBody.width() / 2,
            GBMidY: $Elements.GraphBody.height() / 2,
            Width: Width / CurZoom,
            Height: Height / CurZoom,
            MaxWidth: $Elements.GraphBody.width(),
            MaxHeight: $Elements.GraphBody.height()
        };
        while (Props.Width * Zoom > Props.MaxWidth || Props.Height * Zoom > Props.MaxHeight) {
            Zoom = Math.round(Zoom * 10 - 1) / 10;
        }
        if (Zoom > CurZoom) {
            CurZoom = Zoom;
            SetZoom();
        }
        // move mid of ZoomArea to mid of GraphBody
        var ScrollLeft = Props.MidX * CurZoom - Props.GBMidX;
        if (ScrollLeft < 0) {
            ScrollLeft = 0;
        }
        var ScrollTop = Props.MidY * CurZoom - Props.GBMidY;
        if (ScrollTop < 0) {
            ScrollTop = 0;
        }
        $Elements.GraphBody.scrollLeft(ScrollLeft);
        $Elements.GraphBody.scrollTop(ScrollTop);
    }

    //////////////////////////////////////////////////////
    // fits graph in given proporsitions
    function FitGraph(width, height, Print) {
        var Position = {
            MinX: 100000000000,
            MinY: 100000000000,
            MaxX: 0,
            MaxY: 0
        };
        // get values based on positions of the nodes
        for ( var x = 0, len = Nodes.length; x < len; x++) {
            var Left = OrgValues[Nodes[x].ID].Left;
            var Right = Left + Nodes[x].Object.width() + 5;
            if (Position.MinX > Left) {
                Position.MinX = Left;
            }
            if (Position.MaxX < Right) {
                Position.MaxX = Right;
            }
            var Top = OrgValues[Nodes[x].ID].Top;
            var Bottom = Top + Nodes[x].Object.height() + 5;
            if (Position.MinY > Top) {
                Position.MinY = Top;
            }
            if (Position.MaxY < Bottom) {
                Position.MaxY = Bottom;
            }
        }
        var Size = {
            Left: Position.MinX,
            Top: Position.MinY,
            Height: Position.MaxY - Position.MinY,
            Width: Position.MaxX - Position.MinX,
            MaxHeight: height,
            MaxWidth: width
        };

        // move graph (nodes) to top left corner if necessary
        if (Size.Left != 0 || Size.Top != 0) {
            for ( var x = 0, len = Nodes.length; x < len; x++) {
                Nodes[x].Object.css({
                    'left': (OrgValues[Nodes[x].ID].Left - Size.Left) + 'px',
                    'top': (OrgValues[Nodes[x].ID].Top - Size.Top) + 'px'
                });
                SaveOrgValues(Nodes[x].Object, 1);
            }
        }
        var ScaleVal = 1, RotateTop;
        // if graph bigger than view-container
        if (Size.Height > Size.MaxHeight || Size.Width > Size.MaxWidth) {
            // rotate graph for print if graph is wider than high and browser
            // knows transform:rotate
            if (Print && (Size.Height * 1.7) < Size.Width && BroType > 4) {
                var Temp = Size.Height;
                Size.Height = Size.Width;
                Size.Width = Temp;
                RotateTop = Size.Height;
            }
            // calculate value for scaling
            if (Size.Width > Size.MaxWidth) {
                ScaleVal = Size.MaxWidth / Size.Width;
            }
            if (Size.Height * ScaleVal > Size.MaxHeight) {
                ScaleVal = Size.MaxHeight / Size.Height;
            }
        }

        // if graph is bigger, scale it
        if (ScaleVal < 1 && ScaleVal != CurZoom) {
            if (!Print) {
                CurZoom = Math.floor(ScaleVal * 10) / 10;
                if (CurZoom < 0.1) {
                    CurZoom = 0.1;
                }
                SetZoom();
            } else {
                CurZoom = Math.floor(ScaleVal * 100) / 100;
            }
        }
        else {
            // if graph not bigger, check if CurZoom < 1
            if (CurZoom < 1) {
                CurZoom = 1;
            }
            if (!Print) {
                SetZoom();
            }
        }
        if (Size.Left != 0 || Size.Top != 0) {
            jsPlumb.repaintEverything();
            // second have do be here because of:
            // https://github.com/sporritt/jsPlumb/issues/93
            jsPlumb.repaintEverything();
        }
        if (Print) {
            return (RotateTop);
        }
    }

    //////////////////////////////////////////////////////
    // set new values if zoomed
    function SetZoom() {
        $Elements.Scale.css({
            "-webkit-transform":"scale("+CurZoom+")",
            "-webkit-transform-origin": "0% 0%",
            "-moz-transform":"scale("+CurZoom+")",
            "-moz-transform-origin": "0% 0%",
            "-ms-transform":"scale("+CurZoom+")",
            "-ms-transform-origin": "0% 0%",
            "-o-transform":"scale("+CurZoom+")",
            "-o-transform-origin": "0% 0%",
            "transform":"scale("+CurZoom+")",
            "transform-origin": "0% 0%",
            "-ms-filter": "progid:DXImageTransform.Microsoft.Matrix(M11="+CurZoom+", M12=0, M21=0, M22="+CurZoom+", SizingMethod='auto expand')"
        });
        jsPlumb.setZoom(CurZoom);
        $Elements.ZoomValue.html(CurZoom * 100 + '%');
    }

    //////////////////////////////////////////////////////
    // save original values of nodes
    function SaveOrgValues($Node, Pos) {
        if (Pos) {
            // just position
            OrgValues[$Node.attr('id')].Left = parseFloat($Node.css('left'), 10);
            OrgValues[$Node.attr('id')].Top = parseFloat($Node.css('top'), 10);
        } else {
            OrgValues[$Node.attr('id')] = {
                Left: parseFloat($Node.css('left'), 10),
                Top: parseFloat($Node.css('top'), 10),
                Width: parseFloat($Node.css('min-width'), 10),
                Height: parseFloat($Node.css('min-height'), 10),
            };

            if (GraphConfig.ObjectType == 'ITSMConfigItem' && !OrgValues.InciImgWidth) {
                OrgValues.InciImgWidth = $Node.find('.IncidentImage').width();
            }
        }
    }

    /**
     * @function
     * @return nothing This function completes linking-process
     */
    TargetNS.FinishLinking = function(Source, Target, Conn, DestObject, type) {
        var Type = type || $Dialog.find('#LinkTypes option:selected').text();
        $Elements.Shield.removeClass('Hidden');
        Core.UI.Dialog.CloseDialog($Dialog);
        DummyConnection = '';

        function ChangeInciImgForConfigItem(Result) {
            if (GraphConfig.ObjectType == 'ITSMConfigItem') {
                // change incident image of source if necessary
                if (Result.PropagateStart != 0) {
                    Core.KIX4OTRS.AgentLinkGraphITSMConfigItem.ChangeInciImage(Result.PropagateStart, Result.InciState, Result.Image, Result.LinkType,
                        Result.Direction, '');
                }
            }
        }
        $.each(LinkTypes, function(Index, Object) {
            if (Type == Object) {

                // check for duplication -> just 1 connection of type is possible
                if ((AlreadyLinked[Source + '--' + Target] && AlreadyLinked[Source + '--' + Target][Index])
                        || (AlreadyLinked[Target + '--' + Source] && AlreadyLinked[Target + '--' + Source][Index])) {
                    ShowNotice('Double', Conn, $('#Double').val());
                    $Elements.Shield.addClass('Hidden');
                    return false;
                }

                // save connection in database
                var URL = Core.Config.Get('Baselink');
                var Data = {
                    Action: 'AgentLinkGraph' + GraphConfig.ObjectType,
                    Subaction: 'SaveNewConnection',
                    Source: Source,
                    SourceInciStateType: $('#'+Source).find('.IncidentImage').attr('alt'),
                    Target: Target,
                    TargetInciStateType: $('#'+Target).find('.IncidentImage').attr('alt'),
                    LinkType: Index
                };

                Core.AJAX.FunctionCall(URL, Data, function(SaveResult) {

                    // if it failed show notice
                    if (!SaveResult.Result) {
                        ShowNotice('CreateLink', Conn);
                        $Elements.Shield.addClass('Hidden');
                    } else {
                        // if new connection is with a not present node
                        if (DestObject) {
                            // insert new node-div
                            Data = {
                                Action: 'AgentLinkGraph' + GraphConfig.ObjectType,
                                Subaction: 'InsertNode',
                                DestObject: DestObject
                            };

                            Core.AJAX.FunctionCall(URL, Data, function(InsertResult) {
                                if (!InsertResult.NodeString) {
                                    ShowNotice('CreateLink');
                                    $Elements.Shield.addClass('Hidden');
                                    return;
                                }
                                // add new node
                                $Elements.Scale.append(InsertResult.NodeString);
                                var $DestNode = $('#' + DestObject);
                                var Pos = {}
                                if (OrgValues[Source]) {
                                    Pos.Left = OrgValues[Source].Left + 150 + Math.random() * 10;
                                    Pos.Top = OrgValues[Source].Top + 150 + Math.random() * 10;
                                } else {
                                    Pos.Left = OrgValues[Target].Left + 150 + Math.random() * 10;
                                    Pos.Top = OrgValues[Target].Top + 150 + Math.random() * 10;
                                }
                                $DestNode.css({
                                    'left': Pos.Left + 'px',
                                    'top': Pos.Top + 'px'
                                });
                                SaveOrgValues($DestNode);

                                // make new node draggable
                                jsPlumb.draggable(DestObject, {
                                    containment: $Elements.GraphBody,
                                    stop: function() {
                                        // save position of dragged node
                                        if ($DraggedNode) {
                                            SaveOrgValues($DraggedNode, 1);
                                            $DraggedNode = '';
                                        }
                                    },
                                    scrollSensitivity: 500,
                                    scrollSpeed: 100
                                });
                                jsPlumb.makeTarget(DestObject, {
                                    dropOptions: {
                                        hoverClass: "dragHover"
                                    }
                                });
                                Nodes.push({
                                    ID: DestObject,
                                    Object: $DestNode
                                });

                                // remeber attribut for rights-check
                                SetRightAttr(DestObject, $DestNode);

                                // bind function
                                $('#' + DestObject).bind('mousedown', function(e) {
                                    NodeBindMousdown(e);
                                });

                                // set connection
                                Conn = jsPlumb.connect({
                                    source: Source,
                                    target: Target
                                });
                                SetLabelArrowColor(Conn, Index);
                                ChangeInciImgForConfigItem(SaveResult);
                                $Elements.Shield.addClass('Hidden');
                            });
                        } else {
                            SetLabelArrowColor(Conn, Index);
                            ChangeInciImgForConfigItem(SaveResult);
                            $Elements.Shield.addClass('Hidden');
                        }
                    }
                });
                return false;
            }
        });
    }

    // dialog for failed or success
    function ShowNotice(Type, Conn, HTML) {
        if (Conn && (Type == 'Double' || Type == 'CreateLink')) {
            jsPlumb.detach(Conn);
        }
        ;
        Core.UI.Dialog.ShowDialog({
            Modal: true,
            Title: $Elements.Notice.find('#' + Type + 'NoticeTitle').val(),
            HTML: HTML || $('#Failed').val(),
            PositionTop: '45%',
            PositionLeft: '45%',
            Buttons: [ {
                Label: 'Ok',
                Type: 'Close'
            } ]
        });
        $Dialog = $('.Dialog');
        TargetNS.SetDialogPosition('', '', 1);
    }

    /**
     * @function
     * @return nothing This function changes the dialog position if it would be behind a corner
     */
    TargetNS.SetDialogPosition = function(x, y, Mid, $dialog) {
        $Dialog = $dialog || $Dialog;
        var Left = x, Top = y;
        if (Mid) {
            Left = ($Elements.Body.width() - $Dialog.width()) / 2;
            Top = ($Elements.Body.height() - $Dialog.height()) / 2
        } else {
            if ((x + $Dialog.width()) > $Elements.Body.width()) {
                var Left = $Elements.Body.width() - $Dialog.width() - 20;
            }
            if ((y + $Dialog.height()) > $Elements.Body.height()) {
                var Top = $Elements.Body.height() - $Dialog.height() - 20;
            }
        }
        if (Left < 0) {
            Left = 0;
        }
        if (Top < 0) {
            Top = 0;
        }
        $Dialog.css({
            'left': Left + 'px',
            'top': Top + 'px'
        });
    }

    // function to set label, arrows and color
    function SetLabelArrowColor(Conn, LabelText, Zoom) {
        if (GraphConfig.ObjectType == 'ITSMConfigItem') {
            // register neighbors
            Core.KIX4OTRS.AgentLinkGraphITSMConfigItem.RegisterNeighbor(Conn.sourceId, Conn.targetId, LabelText);
        }

        // remember created connection and change connector-curviness
        if (!Zoom) {
            // register connection
            var Link, z = 1, Curves = [];
            var LinkTo = Conn.sourceId + '--' + Conn.targetId;
            var LinkBack = Conn.targetId + '--' + Conn.sourceId;
            if (!AlreadyLinked[LinkTo]) {
                AlreadyLinked[LinkTo] = {};
                AlreadyLinked[LinkBack] = {};
            }
            // check which positions are free
            $.each(AlreadyLinked[LinkTo], function(Index, Object) {
                var Linked = Object || AlreadyLinked[LinkBack][Index] || 0;
                if (Linked) {
                    Curves[Linked - 1] = 1;
                }
            });
            for ( var x = 0, len = Curviness.length; x < len; x++) {
                if (Curves[x]) {
                    z++
                } else {
                    break;
                }
            }
            // mark position "z" as occupied with link-type "LabelText" for connection "LinkTo"
            AlreadyLinked[LinkTo][LabelText] = z;
            AlreadyLinked[LinkBack][LabelText] = 0;
            Conn.setParameter('Curv', Curviness[z - 1]);
        } else {
            Conn.removeAllOverlays();
        }
        var Connector = [ 'StateMachine', {
            curviness: (Conn.getParameter('Curv') * CurZoom),
            proximityLimit: (50 * CurZoom),
            endpointHoverStyle: {
                fillStyle: LinkColors["LinkHover"]
            }
        } ];
        Conn.setConnector(Connector);
        Conn.removeClass('DummyConnection');

        // change color of link as specified in config for selected LinkType
        Conn.setPaintStyle({
            lineWidth: 2,
            strokeStyle: LinkColors[LabelText],
            dashstyle: "solid"
        });
        Conn.setHoverPaintStyle({
            dashstyle: "solid",
            lineWidth: 2,
            strokeStyle: LinkColors["LinkHover"]
        });

        // set overlays
        Conn.addOverlay([ 'Arrow', {
            width: 15,
            length: 20,
            location: 1
        } ]);
        Conn.addOverlay([ 'Label', {
            label: LinkTypes[LabelText],
            id: 'label',
            location: 0.5,
            cssClass: 'LinkLabel'
        } ]);
        $('#' + Conn.getOverlay('label').getElement().id).css('border', '1px dotted ' + LinkColors[LabelText]);
        // add additional arrow on connection if necessary
        if (TwoArrows[LabelText]) {
            Conn.addOverlay([ 'Arrow', {
                width: 15,
                length: 20,
                location: 0,
                direction: -1
            } ]);
        }
        ;
    }

    // for session information
    function SerializeData(Data) {
        var QueryString = '';
        $.each(Data, function (Key, Value) {
            QueryString += ';' + encodeURIComponent(Key) + '=' + encodeURIComponent(Value);
        });
        return QueryString;
    }

    return TargetNS;
}(Core.KIX4OTRS.AgentLinkGraph || {}));
