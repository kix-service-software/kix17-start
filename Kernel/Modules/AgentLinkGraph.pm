# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentLinkGraph;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Modules::AgentLinkGraph - frontend module for graph visualization

=head1 SYNOPSIS

A frontend module which provides system users access to graph visualization.

=over 4

=cut

sub FinishGraph {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');

    my $Output = $LayoutObject->Header( Type => 'Small' );

    # do preparations for graph
    for my $Edge ( keys %{ $Param{DiscoveredEdges} } ) {
        $Param{Links} .= $Edge . "_-_";
    }
    if ( $Param{Links} ) {
        $Param{Links} =~ s/(.*)_-_$/$1/;
    }

    my $LinkColors = $Self->{Config}->{LinkColors};
    if ( $LinkColors && ref($LinkColors) eq 'HASH' ) {
        for my $LinkColor ( keys %{$LinkColors} ) {
            $Param{LinkColors} .=
                $LinkColor . "=>" . $Self->{Config}->{LinkColors}->{$LinkColor} . "_-_";
        }
    }

    if ( $Param{LinkColors} ) {
        $Param{LinkColors} =~ s/(.*)_-_$/$1/;
    }

    for my $Node ( keys %{ $Param{Nodes} } ) {
        $Param{NodesString} .= $Node . "_-_";
        $Param{HTMLString}  .= $Param{Nodes}{$Node};
    }
    if ( $Param{NodesString} ) {
        $Param{NodesString} =~ s/(.*)_-_$/$1/;
    }

    # get possible link-types of object type with same object type
    my %PossibleLinkTypesList = $LinkObject->PossibleTypesList(
        Object1 => $Param{ObjectType},
        Object2 => $Param{ObjectType},
        UserID  => $Self->{UserID},
    );

    my @PossibleLinkTypesList;
    my $RelLinkTypesString = '';
    for my $PosLinkType ( keys %PossibleLinkTypesList ) {

        # look up wich linktype has same source and target name
        my $STName = $ConfigObject->Get('LinkObject::Type')->{$PosLinkType};
        my $Equal  = 0;

        # if equal, let graph know it so that two arrows will be on link
        if ( $STName->{SourceName} eq $STName->{TargetName} ) {
            $Equal = 1;
        }

        # lookup real name for link-types (translatable)
        my %LinkType = $LinkObject->TypeGet(
            TypeID => $LinkObject->TypeLookup(
                Name   => $PosLinkType,
                UserID => $Self->{UserID},
            ),
            UserID => $Self->{UserID},
        );

        my $Translated = $LayoutObject->{LanguageObject}->Translate( $LinkType{SourceName} );

        # remebmer link-types with translation for graph
        $Param{LinkTypes} .= $PosLinkType . "=>" . $Translated . "=>" . $Equal . "_-_";
        push( @PossibleLinkTypesList, $Translated );

        # remember used link-types in graph-config for print-screen
        if ( $Param{RelevantLinkTypeNames}->{$PosLinkType} ) {
            $RelLinkTypesString .= $Translated . ", ";
        }
    }
    $Param{PossibleLinkTypesList} = \@PossibleLinkTypesList;

    if ( $Param{LinkTypes} ) {
        $Param{LinkTypes} =~ s/(.*)_-_$/$1/;
    }
    $RelLinkTypesString =~ s/, $//;

    # check for service read rights
    my %Groups = $GroupObject->GroupMemberList(
        UserID => $Self->{UserID},
        Type   => 'ro',
        Result => 'HASH',
    );
    $Param{UserServiceRoRight} = 0;
    for my $Group ( values %Groups ) {
        if ( $Group eq 'itsm-service' ) {
            $Param{UserServiceRoRight} = 1;
            last;
        }
    }

    $Param{StartID} = $Param{ObjectType} . '-' . $Param{StartObjectID};

    # get object-specific layout-content
    if ( $Param{ObjectType} eq 'ITSMConfigItem' ) {
        $LayoutObject->GetConfigItemSpecificLayoutContentForGraph( \%Param );
    }

    #    if ( $Param{ObjectType} eq 'Ticket' ) {
    #        $LayoutObject->GetTicketSpecificLayoutContentForGraph(\%Param);
    #    }

    # give divs,links and dropboxes to dtl
    $LayoutObject->Block(
        Name => 'Graph',
        Data => {
            DropBoxLinkTypes => $LayoutObject->BuildSelection(
                Data        => $Param{PossibleLinkTypesList},
                Name        => 'LinkTypes',
                Translation => 0,
                Class       => 'Modernize'
            ),
            RelLinkTypes => $RelLinkTypesString,
            %Param,
        },
    );

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentZoomTabLinkGraphIFrame',
        Data         => \%Param,
    );

    $Output .= $LayoutObject->Footer( Type => 'Small' );

    my %Result = (
        Content     => $Output,
        Size        => length($Output),
        Filename    => $Param{ObjectType} . '_' . $Param{ObjectID} . '.html',
        ContentType => 'text/html',
        Charset     => 'utf-8',
        Type        => 'inline',
    );
    return %Result;
}

sub DoPreparations {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    # define required params...
    for my $CurrKey (
        qw( ObjectID RelevantLinkTypes
        RelevantObjectTypes RelevantObjectSubTypes MaxSearchDepth
        SavedGraphID GraphLayout GraphConfig UsedStrength)
        )
    {
        $Param{$CurrKey} = $ParamObject->GetParam( Param => $CurrKey ) || '';
    }

    # if a saved graph should be loaded
    if ( $Param{SavedGraphID} ) {
        if ( !$Param{GraphLayout} || !$Param{GraphConfig} ) {
            $Param{Layout} = 'NotLoadable';
            $LogObject->Log(
                Priority => 'error',
                Message  => "Kernel::Modules::AgentLinkGraph"
                    . " - got no layout or config for Graph!!",
            );
        }
        else {
            $Param{Layout} = $Param{GraphLayout};
            my @GraphConfig = split( ':::', $Param{GraphConfig} );
            $Param{MaxSearchDepth}         = $GraphConfig[0] || $Param{MaxSearchDepth};
            $Param{RelevantLinkTypes}      = $GraphConfig[1] || $Param{RelevantLinkTypes};
            $Param{UsedStrength}           = $GraphConfig[2] || $Param{UsedStrength};
            $Param{RelevantObjectSubTypes} = $GraphConfig[3] || $Param{RelevantObjectSubTypes};
        }
    }

    # set some default values if required (all linkable objects for current object)...
    if ( !$Param{RelevantObjectTypeNames} ) {
        my @RelevantObjectTypeNameArray;

        #        my %ObjectTypeList = $LinkObject->PossibleObjectsList(
        #            Object => $Param{ObjectType},
        #            UserID => 1,
        #        );
        #        for my $ObjectType ( keys %ObjectTypeList ) {
        #            push(@RelevantObjectTypeNameArray, $ObjectType);
        #        }

        #-- for now just itself --#
        push( @RelevantObjectTypeNameArray, $Param{ObjectType} );

        $Param{RelevantObjectTypeNames} = \@RelevantObjectTypeNameArray;
    }

    $Param{MaxSearchDepth} = $Param{MaxSearchDepth} || 1;

    $Param{RelSubTypeArray}  = [ split( ',', $Param{RelevantObjectSubTypes} ) ];
    $Param{RelLinkTypeArray} = [ split( ',', $Param{RelevantLinkTypes} ) ];

    # prepare link type limit...
    for my $CurrKey ( @{ $Param{RelLinkTypeArray} } ) {
        $Param{RelevantLinkTypeNames}->{$CurrKey} = '1';
    }

    $Param{StartObjectID}   = $Param{ObjectID};
    $Param{StartObjectType} = $Param{ObjectType};

    return %Param;
}

sub LookForNeighbours {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');

    for my $CurrObjectType ( @{ $Param{RelevantObjectTypeNames} } ) {

        my $LinkList = $LinkObject->LinkListWithData(
            Object  => $Param{CurrentObjectType},
            Key     => $Param{CurrentObjectID},
            Object2 => $CurrObjectType,
            State   => 'Valid',
            UserID  => 1,
        );

        if ( $LinkList && ref($LinkList) eq 'HASH' && $LinkList->{ $Param{ObjectType} } ) {

            for my $LinkType ( keys %{ $LinkList->{ $Param{ObjectType} } } ) {

                next if !$Param{RelevantLinkTypeNames}
                        || !$Param{RelevantLinkTypeNames}->{$LinkType};

                for my $NodePosition ( keys %{ $LinkList->{ $Param{ObjectType} }->{$LinkType} } ) {
                    if ( $NodePosition eq 'Source' ) {
                        for my $DestID (
                            keys
                            %{ $LinkList->{ $Param{ObjectType} }->{$LinkType}->{$NodePosition} }
                            )
                        {
                            my $FullTargetID
                                = $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID};
                            my $FullSourceID = $CurrObjectType . '-' . $DestID;

                            # recursion for next level...
                            my $ObjectAdded = $Self->_GetObjectsAndLinks(
                                %Param,
                                CurrentObjectID         => $DestID,
                                CurrentObjectType       => $CurrObjectType,
                                CurrentDepth            => $Param{CurrentDepth} + 1,
                                MaxDepth                => $Param{MaxDepth},
                                VisitedNodes            => $Param{VisitedNodes},
                                DiscoveredEdges         => $Param{DiscoveredEdges},
                                RelevantObjectTypeNames => $Param{RelevantObjectTypeNames},
                            );
                            if (
                                $ObjectAdded
                                &&
                                !$Param{DiscoveredEdges}
                                ->{ $FullSourceID . '==' . $LinkType . '==' . $FullTargetID }
                                &&
                                !$Param{DiscoveredEdges}
                                ->{ $FullTargetID . '==' . $LinkType . '==' . $FullSourceID }
                                )
                            {
                                $Param{DiscoveredEdges}
                                    ->{ $FullSourceID . '==' . $LinkType . '==' . $FullTargetID } =
                                    1;
                            }
                        }
                    }
                    elsif ( $NodePosition eq 'Target' ) {
                        for my $DestID (
                            keys
                            %{ $LinkList->{ $Param{ObjectType} }->{$LinkType}->{$NodePosition} }
                            )
                        {
                            my $FullSourceID
                                = $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID};
                            my $FullTargetID = $CurrObjectType . '-' . $DestID;

                            # recursion for next level...
                            my $ObjectAdded = $Self->_GetObjectsAndLinks(
                                %Param,
                                CurrentObjectID         => $DestID,
                                CurrentObjectType       => $CurrObjectType,
                                CurrentDepth            => $Param{CurrentDepth} + 1,
                                MaxDepth                => $Param{MaxDepth},
                                VisitedNodes            => $Param{VisitedNodes},
                                DiscoveredEdges         => $Param{DiscoveredEdges},
                                RelevantObjectTypeNames => $Param{RelevantObjectTypeNames},
                            );
                            if (
                                $ObjectAdded
                                &&
                                !$Param{DiscoveredEdges}
                                ->{ $FullSourceID . '==' . $LinkType . '==' . $FullTargetID }
                                &&
                                !$Param{DiscoveredEdges}
                                ->{ $FullTargetID . '==' . $LinkType . '==' . $FullSourceID }
                                )
                            {
                                $Param{DiscoveredEdges}
                                    ->{ $FullSourceID . '==' . $LinkType . '==' . $FullTargetID }
                                    = 1;
                            }
                        }
                    }
                }
            }
        }
    }
    return %Param;
}

sub GetSavedGraphs {
    my ( $Self, $Param ) = @_;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $CurObjectID = $ParamObject->GetParam( Param => 'CurID' );

    # check required params...
    if ( !$CurObjectID || !$Param->{ObjectType} ) {
        $LogObject->Log(
            Priority => 'error',
            Message =>
                "Kernel::Modules::AgentLinkGraph::_GetSavedGraphs - param CurObjectID or ObjectType required but not given!",
        );
        return;
    }

    # get saved graph for this object
    my %SavedGraphs = $Kernel::OM->Get('Kernel::System::LinkGraph')->GetSavedGraphs(
        CurID      => $CurObjectID,
        UserID     => $Self->{UserID},
        ObjectType => $Param->{ObjectType},
    );

    my %SavedGraphSelection;
    my $KnownNames;
    if (%SavedGraphs) {
        for my $SavedGraphID ( keys %SavedGraphs ) {

            # separate config options
            $Self->_SeperateGraphConfig(
                GraphConfig => $SavedGraphs{$SavedGraphID},
            );

            # get name for selection
            $SavedGraphSelection{$SavedGraphID} = $SavedGraphs{$SavedGraphID}->{Name};

            # remember name because it has to be unique for this node
            $KnownNames->{ $SavedGraphs{$SavedGraphID}->{Name} } = 1;

            # get right format for changetime
            $SavedGraphs{$SavedGraphID}->{LastChangedTime} = $LayoutObject->Output(
                Template => '[% "'
                    . $SavedGraphs{$SavedGraphID}->{LastChangedTime}
                    . '" | Localize(TimeLong) %]',
            );

            # get agent name for changeby
            my %ChangeUser = $UserObject->GetUserData(
                UserID => $SavedGraphs{$SavedGraphID}->{LastChangedBy},
                Cached => 1,
            );
            $SavedGraphs{$SavedGraphID}->{LastChangedBy} = substr( $ChangeUser{UserLogin}, 0, 15 ) .
                " ("
                . substr( $ChangeUser{UserFirstname} . " " . $ChangeUser{UserLastname}, 0, 15 )
                . ")";
        }
    }
    else {
        $SavedGraphs{NoSavedGraphs} = 1;
    }
    $SavedGraphs{KnownNames} = $KnownNames;

    # build selection
    $SavedGraphs{Selection} = $LayoutObject->BuildSelection(
        Data         => \%SavedGraphSelection,
        Name         => 'SavedGraphSelection',
        Translation  => 0,
        Multiple     => 0,
        PossibleNone => 0,
        Sort         => 'AlphanumericValue',
        Class        => 'Modernize'
    );
    $Param->{SavedGraphs} = \%SavedGraphs;
}

sub ShowServices {
    my ( $Self, $Param ) = @_;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $LinkList = $LinkObject->LinkListWithData(
        Object  => $Param->{ObjectType},
        Key     => $ParamObject->GetParam( Param => 'ObjectID' ),
        Object2 => 'Service',
        State   => 'Valid',
        UserID  => $Self->{UserID},
    );

    my $ServicesString;
    if ( ref($LinkList) eq 'HASH' ) {
        my %PossibleLinkTypesList
            = $LinkObject->PossibleTypesList(
            Object1 => $Param->{ObjectType},
            Object2 => 'Service',
            UserID  => $Self->{UserID},
            );

        # lookup real name for this type (translatable)
        for my $LinkType ( keys %PossibleLinkTypesList ) {
            my %Type = $LinkObject->TypeGet(
                TypeID => $LinkObject->TypeLookup(
                    Name   => $LinkType,
                    UserID => $Self->{UserID},
                ),
                UserID => $Self->{UserID},
            );
            $PossibleLinkTypesList{ $LinkType . '::Source' } = $Type{SourceName};
            $PossibleLinkTypesList{ $LinkType . '::Target' } = $Type{TargetName};
        }

        my %Services;
        if ( $LinkList && ref($LinkList) eq 'HASH' ) {
            for my $LinkType ( keys %{ $LinkList->{Service} } ) {
                for my $Position ( keys %{ $LinkList->{Service}->{$LinkType} } ) {
                    for my $DestID ( keys %{ $LinkList->{Service}->{$LinkType}->{$Position} } )
                    {
                        my $Type =
                            $LayoutObject->{LanguageObject}
                            ->Get( $PossibleLinkTypesList{ $LinkType . '::' . $Position } );
                        $Services{
                            $DestID . '_-_'
                                . $LinkList->{Service}->{$LinkType}->{$Position}->{$DestID}
                                ->{Name}
                            } .= $Type . "<br>";
                    }
                }
            }
        }

        for my $Service ( sort keys %Services ) {
            my @Service = split( '_-_', $Service );
            $Services{$Service} =~ s/(.*)<br>/$1/;
            $LayoutObject->Block(
                Name => 'Service',
                Data => {
                    ServiceName => $Service[1],
                    ServiceID   => $Service[0],
                    LinkType    => $Services{$Service},
                },
            );
            $ServicesString .= $LayoutObject->Output(
                TemplateFile => 'AgentZoomTabLinkGraphAdditional',
                Data         => $Param,
            );
        }
    }
    else {
        $ServicesString =
            '<tr><td>'
            . $LayoutObject->{LanguageObject}->Translate(
            "Something went wrong! Please look into the error-log for more information."
            )
            . '</td><td> </td></tr>';
    }

    $LayoutObject->Block(
        Name => 'Services',
        Data => {
            Name => $ParamObject->GetParam( Param => 'ObjectName' ),
            ServiceTable => $ServicesString
                || '<tr><td>'
                . $LayoutObject->{LanguageObject}->Translate("No linked Services")
                . '</td><td> </td></tr>',
        },
    );
    return $LayoutObject->Output(
        TemplateFile => 'AgentZoomTabLinkGraphAdditional',
        Data         => $Param,
    );
}

sub CreatePrintOutput {
    my ( $Self, $Param ) = @_;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $ObjectFullID = $ParamObject->GetParam( Param => 'ObjectFullID' );

    my $Output = $LayoutObject->Header( Type => 'Small' );

    $LayoutObject->Block(
        Name => 'Printing',
        Data => {},
    );
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentZoomTabLinkGraphAdditional',
        Data         => $Param,
    );

    $Output .= $LayoutObject->Footer( Type => 'Small' );

    my $GraphPrint = $LayoutObject->Attachment(
        Content     => $Output,
        Size        => length($Output),
        Filename    => $ObjectFullID . '_LinkGraph.html',
        ContentType => 'text/html',
        Charset     => 'utf-8',
        Type        => 'inline',
    );

    # remove unnecessary meta information
    if ( $GraphPrint =~ m/.+8;..+8;.*/sig ) {
        $GraphPrint =~ s/(.+8;.).+8;.*(<!DOC.+)/$1\n$2/sig;
    }
    else {
        $GraphPrint =~ s/(.*8;.)(.*Content.*)(<!DOC.*)/$1<div style=\"color:white\">$2<\/div>$3/sig;
    }

    return $GraphPrint;
}

sub SaveGraph {
    my ( $Self, $Param ) = @_;

    # get needed objects
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LinkGraphObject = $Kernel::OM->Get('Kernel::System::LinkGraph');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $LayoutString      = $ParamObject->GetParam( Param => 'Layout' )      || '';
    my $GraphConfigString = $ParamObject->GetParam( Param => 'GraphConfig' ) || '';
    my $CurObjectID       = $ParamObject->GetParam( Param => 'CurID' )       || '';
    my $GraphName         = $ParamObject->GetParam( Param => 'GraphName' )   || '';
    my $GraphID           = $ParamObject->GetParam( Param => 'GraphID' )     || '';

    $LayoutString =~ s/(.*)_-_$/$1/i;

    if ($GraphID) {
        $Param->{Result} = $LinkGraphObject->UpdateGraph(
            LayoutString => $LayoutString,
            GraphID      => $GraphID,
            UserID       => $Self->{UserID},
            GraphConfig  => $GraphConfigString,
        );
    }

    # save graph
    if ($GraphName) {
        $Param->{Result} = $LinkGraphObject->SaveGraph(
            LayoutString => $LayoutString,
            CurID        => $CurObjectID,
            GraphName    => $GraphName,
            UserID       => $Self->{UserID},
            GraphConfig  => $GraphConfigString,
            ObjectType   => $Param->{ObjectType},
        );
    }

    # get readable config (separated and translated)
    $Param->{GraphConfig}->{ConfigString} = $GraphConfigString;
    $Self->_SeperateGraphConfig(
        GraphConfig => $Param->{GraphConfig},
    );

    # get right format for changetime
    if ( $Param->{Result}->{LastChangedTime} ) {
        $Param->{LastChangedTime} = $LayoutObject->Output(
            Template => '$TimeLong{"' . $Param->{Result}->{LastChangedTime} . '"}'
        );
    }

    $Param->{LastChangedBy} = substr( $Self->{UserLogin}, 0, 15 )
        . " (" . substr( $Self->{UserFirstname} . " " . $Self->{UserLastname}, 0, 15 ) . ")",
}

sub SaveCon {
    my ( $Self, $Param ) = @_;

    # get needed objects
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LinkObject  = $Kernel::OM->Get('Kernel::System::LinkObject');

    ( $Param->{SourceType}, $Param->{SourceID} ) =
        split( '-', $ParamObject->GetParam( Param => 'Source' ) );
    ( $Param->{TargetType}, $Param->{TargetID} ) =
        split( '-', $ParamObject->GetParam( Param => 'Target' ) );
    $Param->{LinkType} = $ParamObject->GetParam( Param => 'LinkType' );

    return $LinkObject->LinkAdd(
        SourceObject => $Param->{SourceType},
        SourceKey    => $Param->{SourceID},
        TargetObject => $Param->{TargetType},
        TargetKey    => $Param->{TargetID},
        Type         => $Param->{LinkType},
        State        => 'Valid',
        UserID       => $Self->{UserID},
    );
}

sub DelCon {
    my ( $Self, $Param ) = @_;

    # get needed objects
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LinkObject  = $Kernel::OM->Get('Kernel::System::LinkObject');

    ( $Param->{SourceType}, $Param->{SourceID} ) =
        split( '-', $ParamObject->GetParam( Param => 'Source' ) );
    ( $Param->{TargetType}, $Param->{TargetID} ) =
        split( '-', $ParamObject->GetParam( Param => 'Target' ) );
    $Param->{LinkType} = $ParamObject->GetParam( Param => 'LinkType' );

    return $LinkObject->LinkDelete(
        Object1 => $Param->{SourceType},
        Key1    => $Param->{SourceID},
        Object2 => $Param->{TargetType},
        Key2    => $Param->{TargetID},
        Type    => $Param->{LinkType},
        UserID  => $Self->{UserID},
    );
}

sub _SeperateGraphConfig {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my @GraphConfig    = split( ':::', $Param{GraphConfig}->{ConfigString} );
    my @GraphLinkTypes = split( ',',   $GraphConfig[1] );

    # get real link-names
    my $LinkTypesString = '';
    for my $LinkType (@GraphLinkTypes) {
        my %Type = $LinkObject->TypeGet(
            TypeID => $LinkObject->TypeLookup(
                Name   => $LinkType,
                UserID => $Self->{UserID},
            ),
            UserID => $Self->{UserID},
        );
        $LinkTypesString .=
            $LayoutObject->{LanguageObject}->Translate( $Type{SourceName} ) . ', ';
    }
    $LinkTypesString =~ s/(.*), $/$1/i;

    my %AdjustingStrengthValues = (
        1 => 'Strong',
        2 => 'Medium',
        3 => 'Weak',
    );
    my $Strength =
        $LayoutObject->{LanguageObject}->Translate( $AdjustingStrengthValues{ $GraphConfig[2] } );

    $Param{GraphConfig}->{LinkTypes} = $LinkTypesString;
    $Param{GraphConfig}->{SubTypes}  = $GraphConfig[3];
    $Param{GraphConfig}->{Depth}     = $GraphConfig[0];
    $Param{GraphConfig}->{Strength}  = $Strength;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
