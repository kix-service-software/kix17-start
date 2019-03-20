# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentLinkGraphITSMConfigItem;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::Group',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log',
    'Kernel::System::Web::Request',
);

use base qw(Kernel::Modules::AgentLinkGraph);

=head1 NAME

Kernel::Modules::AgentLinkGraph - frontend module for graph visualization

=head1 SYNOPSIS

A frontend module which provides system users access to graph visualization.

=over 4

=cut

=item new()

create a object

    use Kernel::Config;
    use Kernel::System::Log;
    use Kernel::System::DB;

    my $AgentLinkGraphObject = Kernel::Modules::AgentLinkGraph->new(
        ParamObject  => $ParamObject,
        DBObject  => $DBObject,
        LayoutObject  => $LayoutObject,
        LogObject  => $LogObject,
        ConfigObject => $ConfigObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}         = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{GroupObject}          = $Kernel::OM->Get('Kernel::System::Group');
    $Self->{ConfigItemObject}     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}          = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Config} = $Self->{ConfigObject}->Get("Frontend::Agent::$Self->{Action}");

    $Self->{BaseURL}
        = $Self->{ConfigObject}->Get('HttpType') . '://' . $Self->{ConfigObject}->Get('FQDN')
        . '/' . $Self->{ConfigObject}->Get('ScriptAlias') . 'index.pl';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Param{ObjectType} = 'ITSMConfigItem';

    if ( !$Param{ObjectType} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Kernel::Modules::AgentLinkGraph - got no ObjectType!",
        );
    }

    # get saved graphs and their config
    if ( $Self->{Subaction} eq 'GetSavedGraphs' ) {
        $Self->GetSavedGraphs( \%Param );
        for my $Graph ( keys %{ $Param{SavedGraphs} } ) {
            if ( $Graph =~ m/\d+/ ) {
                $Param{SavedGraphs}->{$Graph}->{SubTypes} = $Self->_GetClassNames(
                    ClassIDString => $Param{SavedGraphs}->{$Graph}->{SubTypes},
                );
            }
        }

        my $JSON = $Self->{LayoutObject}->JSONEncode(
            Data => {
                Graphs => $Param{SavedGraphs},
            },
        );
        return $Self->{LayoutObject}->Attachment(
            ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # get linked services and show them
    elsif ( $Self->{Subaction} eq 'ShowServices' ) {
        return $Self->ShowServices( \%Param );
    }

    # create print output
    elsif ( $Self->{Subaction} eq 'CreatePrintOutput' ) {
        return $Self->CreatePrintOutput( \%Param );
    }

    # save graph
    elsif ( $Self->{Subaction} eq 'SaveGraph' ) {
        $Self->SaveGraph( \%Param );
        $Param{GraphConfig}{SubTypes} = $Self->_GetClassNames(
            ClassIDString => $Param{GraphConfig}{SubTypes}
        );

        my $JSON = $Self->{LayoutObject}->JSONEncode(
            Data => {
                ID => $Param{Result}->{ID} || 0,
                GraphConfig     => $Param{GraphConfig},
                LastChangedTime => $Param{LastChangedTime},
                LastChangedBy   => $Param{LastChangedBy}
            },
        );
        return $Self->{LayoutObject}->Attachment(
            ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # load object data, build it and give it to graph
    elsif ( $Self->{Subaction} eq 'InsertNode' ) {
        return $Self->_InsertCI(%Param);
    }

    # write created connection into database
    elsif ( $Self->{Subaction} eq 'SaveNewConnection' ) {
        $Param{SourceInciStateType} =
            $Self->{ParamObject}->GetParam( Param => 'SourceInciStateType' );
        $Param{TargetInciStateType} =
            $Self->{ParamObject}->GetParam( Param => 'TargetInciStateType' );

        # do saving
        $Param{Result} = $Self->SaveCon( \%Param );

        return $Self->_PropagateInciState(%Param);
    }

    # remove link in database
    elsif ( $Self->{Subaction} eq 'DeleteConnection' ) {
        $Param{SourceInciStateType} =
            $Self->{ParamObject}->GetParam( Param => 'SourceInciStateType' );
        $Param{TargetInciStateType} =
            $Self->{ParamObject}->GetParam( Param => 'TargetInciStateType' );

        # do deletion
        $Param{Result} = $Self->DelCon( \%Param );

        return $Self->_PropagateInciState(%Param);
    }

    # get object names
    elsif ( $Self->{Subaction} eq 'GetObjectNames' ) {
        return $Self->_GetCINamesForLoadedGraph( \%Param );
    }

    #---------------------------------------------------------------------------
    # do general preparations
    %Param = $Self->DoPreparations(%Param);

    # do ConfigItem specific preparations
    %Param = $Self->_PrepareITSMConfigItem(%Param);

    $Param{NodeObject} = 'CI';

    $Param{VisitedNodes}     = {};
    $Param{DiscoveredEdges}  = {};
    $Param{Nodes}            = {};
    $Param{UserCIEditRights} = {};
    %Param                   = $Self->_GetObjectsAndLinks(
        %Param,
        CurrentObjectID   => $Param{ObjectID},
        CurrentObjectType => $Param{ObjectType},
        CurrentDepth      => 1,
    );
    if ( $Param{UserCIEditRights}->{String} ) {
        $Param{UserCIEditRights}->{String} =~ s/(.*)_-_$/$1/;
        $Param{UserCIEditRights} = $Param{UserCIEditRights}->{String};
    }

    my $Graph = $Self->{LayoutObject}->Attachment( $Self->FinishGraph(%Param) );

    # remove unnecessary meta information
    if ( $Graph =~ m/.+8;..+8;.*/sig ) {
        $Graph =~ s/(.+8;.).+8;.*(<!DOC.+)/$1\n$2/sig;
    }
    else {
        $Graph =~ s/(.*8;.)(.*Content.*)(<!DOC.*)/$1<div style=\"color:white\">$2<\/div>$3/sig;
    }
    return $Graph;
}

sub _PrepareITSMConfigItem {
    my ( $Self, %Param ) = @_;

    # prepare object sub type limit...
    for my $CurrID ( @{ $Param{RelSubTypeArray} } ) {
        my $ItemRef = $Self->{GeneralCatalogObject}->ItemGet(
            ItemID => $CurrID,
        );
        if (
            $ItemRef
            && ref($ItemRef) eq 'HASH'
            && $ItemRef->{Class} eq 'ITSM::ConfigItem::Class'
            )
        {
            $Param{RelevantObjectSubTypeNames}->{ $ItemRef->{Name} } = $CurrID;
        }
    }

    # get possible deployment state list for config items to be in color
    # get relevant functionality
    my $ColorDeploymentStatePostproductive = $Self->{ConfigObject}->Get('ConfigItemOverview::ShowDeploymentStatePostproductive');
    my @ColorFunctionality                 = ( 'preproductive', 'productive' );
    if ($ColorDeploymentStatePostproductive) {
        push( @ColorFunctionality, 'postproductive' );
    }
    # get state list
    my $ColorStateList = $Self->{GeneralCatalogObject}->ItemList(
        Class       => 'ITSM::ConfigItem::DeploymentState',
        Preferences => {
            Functionality => \@ColorFunctionality,
        },
    );
    # remove excluded deployment states from state list
    my %ColorDeplStateList = %{$ColorStateList};
    if ( $Self->{ConfigObject}->Get('ConfigItemOverview::ExcludedDeploymentStates') ) {
        my @ExcludedStates = split(
            /,/,
            $Self->{ConfigObject}->Get('ConfigItemOverview::ExcludedDeploymentStates')
        );
        for my $Item ( keys %ColorDeplStateList ) {
            next if !( grep { /^$ColorDeplStateList{$Item}$/ } @ExcludedStates );
            delete $ColorDeplStateList{$Item};
        }
    }
    $Param{DeplStatesColor} = \%ColorDeplStateList;

    $Param{StateHighlighting} = $Self->{ConfigObject}->Get('ConfigItemLinkGraph::HighlightMapping');

    # get all possible linkable CI classes
    my $CIClassListRef = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1,
    );

    # check for Class read rights
    for my $ClassID ( keys %{$CIClassListRef} ) {
        my $RoRight = $Self->{ConfigItemObject}->Permission(
            Scope   => 'Class',
            ClassID => $ClassID,
            UserID  => $Self->{UserID},
            Type    => 'ro',
        ) || 0;
        if ( !$RoRight ) {
            delete $CIClassListRef->{$ClassID};
        }
        $Param{UserClassRoRights} .= $ClassID . ":::" . $RoRight . "_-_";
    }
    if ( $Param{UserClassRoRights} ) {
        $Param{UserClassRoRights} =~ s/(.*)_-_$/$1/;
    }

    # get ro/rw groups for later check of special right for each CI
    $Param{GroupsRO} = [
        $Self->{GroupObject}->GroupMemberList(
            UserID => $Self->{UserID},
            Type   => 'ro',
            Result => 'ID',
            Cached => 1,
            )
    ];

    # get config item specific class selection
    $Param{ObjectSpecificLinkSel} = $Self->{LayoutObject}->BuildSelection(
        Data         => $CIClassListRef,
        SelectedID   => 1,
        Translation  => 1,
        Name         => 'CIClasses',
        Multiple     => 0,
        PossibleNone => 0,
        # Class        => 'Modernize', # bugfix: T#2017062990000842
    );

    # remember selected CI classes for print header
    my @RelCIClasses;
    for my $SubTypeName ( keys %{ $Param{RelevantObjectSubTypeNames} } ) {
        push( @RelCIClasses, $Self->{LayoutObject}->{LanguageObject}->Translate($SubTypeName) );
    }
    $Param{RelSubTypesString} ||= '';
    for my $CIClass ( sort @RelCIClasses ) {
        $Param{RelSubTypesString} .= $CIClass . ", ";
    }
    $Param{RelSubTypesString} =~ s/, $//;

    return %Param;
}

sub _GetObjectsAndLinks {
    my ( $Self, %Param ) = @_;

    # check required params...
    for my $CurrKey (
        qw( CurrentObjectID CurrentObjectType CurrentDepth RelevantObjectSubTypeNames
        MaxSearchDepth VisitedNodes Nodes DiscoveredEdges RelevantObjectTypeNames)
        )
    {
        if ( !$Param{$CurrKey} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Kernel::Modules::AgentLinkGraph::"
                    . "_GetObjectsAndLinks - param $CurrKey "
                    . "required but not given!",
            );
            return 0;
        }
    }

    #---------------------------------------------------------------------------
    # visit node and store information

    # check validity of params
    return 0 if ref( $Param{RelevantObjectTypeNames} ) ne 'ARRAY';

    # if object is already visited and with smaller search depth return --> a known shorter path
    if (
        $Param{VisitedNodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} }
        &&
        $Param{VisitedNodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} } <
        $Param{CurrentDepth}
        )
    {
        return 1;
    }

    # just create link of present CIs if they are at the end of max search depth
    if (
        $Param{Nodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} }
        &&
        $Param{CurrentDepth} == $Param{MaxSearchDepth} + 2
        )
    {
        return 1;
    }

    # stop recursion for max depth reason...  +2 because for links between present CIs on end
    if ( $Param{CurrentDepth} == $Param{MaxSearchDepth} + 2 ) {
        return 0;
    }

    if ( !$Param{Nodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} } ) {
        my $String;

        # get current version data
        my $CurrVersionData;

        # check if xml data is needed
        my $ConsiderAttribute;
        if ( defined $Self->{Config}->{ClassAttributesToConsider} ) {
            $ConsiderAttribute = 1;
        }
        $CurrVersionData = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $Param{CurrentObjectID},
        );

        # look up if special rights for CI are neccessary
        my $KeyName = '';
        for my $ClassAttributeHash ( @{ $CurrVersionData->{XMLDefinition} } ) {
            next if ( $ClassAttributeHash->{Input}->{Type} ne 'CIGroupAccess' );
            $KeyName = $ClassAttributeHash->{Key};
        }
        my $Array = $Self->{ConfigItemObject}->GetAttributeContentsByKey(
            KeyName       => $KeyName,
            XMLData       => $CurrVersionData->{XMLData}->[1]->{Version}->[1],
            XMLDefinition => $CurrVersionData->{XMLDefinition},
        );
        if ( scalar @{$Array} ) {
            my @AccessGroupIDs = ();
            my @AccessGroups = split( /,/, $Array->[0] );
            for my $Group (@AccessGroups) {
                $Group =~ s/^\s+|\s+$//g;
                push @AccessGroupIDs, $Group;
            }

      # if user has no ro rights for object, do not 'build' it and return 0, else remember rw rigths
            my $HasCIAccess = 0;
            for my $MustHaveGroupID (@AccessGroupIDs) {
                if ( grep { $_ eq $MustHaveGroupID } @{ $Param{GroupsRO} } ) {
                    $HasCIAccess = 1;
                }
                last if ($HasCIAccess);
            }
            return 0 if !$HasCIAccess;
        }

        # stop recursion if object sub type is not relevant or invalid... but ignore start object
        if (
            $Param{RelevantObjectSubTypeNames}
            && (
                !$CurrVersionData->{Class}
                || !$Param{RelevantObjectSubTypeNames}->{ $CurrVersionData->{Class} }
            ) && $Param{StartObjectID} ne $Param{CurrentObjectID}
            )
        {
            return 0;
        }

        # check if object has relevant deployment state to show... but ignore start object
        if ( $Param{StartObjectID} ne $Param{CurrentObjectID} ) {
            # get possible deployment state list for config items to be shown
            # get relevant functionality
            my $ShowDeploymentStatePostproductive = $Self->{ConfigObject}->Get('ConfigItemLinkGraph::ShowDeploymentStatePostproductive');
            my @ShowFunctionality                 = ( 'preproductive', 'productive' );
            if ($ShowDeploymentStatePostproductive) {
                push( @ShowFunctionality, 'postproductive' );
            }
            my $ShowStateList = $Self->{GeneralCatalogObject}->ItemList(
                Class       => 'ITSM::ConfigItem::DeploymentState',
                Preferences => {
                    Functionality => \@ShowFunctionality,
                },
            );
            # remove excluded deployment states from state list
            my %ShowDeplStateList = %{$ShowStateList};
            if ( $Self->{ConfigObject}->Get('ConfigItemLinkGraph::ExcludedDeploymentStates') ) {
                my @ExcludedStates =
                    split(
                    /,/,
                    $Self->{ConfigObject}->Get('ConfigItemLinkGraph::ExcludedDeploymentStates')
                );
                for my $Item ( keys %ShowDeplStateList ) {
                    next if !( grep { /^$ShowDeplStateList{$Item}$/ } @ExcludedStates );
                    delete $ShowDeplStateList{$Item};
                }
            }

            # check deployment state
            my $ShowCurrentObject;
            for my $DeplState ( values %ShowDeplStateList ) {
                if ( $CurrVersionData->{CurDeplState} eq $DeplState ) {
                    $ShowCurrentObject = 1;
                }
            }
            if ( !$ShowCurrentObject ) {
                return 0;
            }
        }

        # define border of start object
        my $Start;
        if (
            $Param{StartObjectType}  eq $Param{CurrentObjectType}
            && $Param{StartObjectID} eq $Param{CurrentObjectID}
            )
        {
            $Start = 'border:1px solid #ee9900;';
            $Param{StartName} = $CurrVersionData->{Name};
        }

        my $DeplStateColor;
        if ( $Param{StateHighlighting}->{ $CurrVersionData->{CurDeplState} } )
        {
            $DeplStateColor = $Param{StateHighlighting}->{ $CurrVersionData->{CurDeplState} } . ";";
        }

        $String = $Self->_BuildNodes(
            %Param,
            CurrVersionData   => $CurrVersionData,
            CurrentObjectType => $Param{CurrentObjectType},
            CurrentObjectID   => $Param{CurrentObjectID},
            Start             => $Start,
            DeplStatesColor   => $Param{DeplStatesColor},
            ConsiderAttribute => $ConsiderAttribute,
            DeplStateColor    => $DeplStateColor,
        );
        return 0 if !$String;

        # add node to string-ref to make these nodes dragable and markable as source and target
        $Param{Nodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} } = $String;

        # remember node as visited
        $Param{VisitedNodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} } =
            $Param{CurrentDepth};
    }

    # look for neighbouring nodes ... and return
    return $Self->LookForNeighbours(%Param);
}

sub _BuildNodes {
    my ( $Self, %Param ) = @_;

    # check required params...
    for my $CurrKey (qw( DeplStatesColor CurrentObjectType CurrentObjectID CurrVersionData )) {
        if ( !$Param{$CurrKey} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Kernel::System::LinkGraph::ITSMConfigItem::"
                    . "_BuildNodes - param $CurrKey "
                    . "required but not given!",
            );
            return;
        }
    }

    # check if CI-node should have a no colored images because it is not shown in the CMDB overview
    my $WithColor;
    for my $DeplState ( values %{ $Param{DeplStatesColor} } ) {
        if ( $Param{CurrVersionData}->{CurDeplState} eq $DeplState ) {
            $WithColor = 1;
        }
    }

    # get icon for node
    my $Image;

    # if sysconfig-entry about icons for class-attributes is active, look for defined icon
    if ( $Param{ConsiderAttribute} ) {
        my $AttToConsider =
            $Self->{Config}->{ClassAttributesToConsider}->{ $Param{CurrVersionData}->{Class} };

        # get icon for class-attribute
        if ($AttToConsider) {
            my $AttValue = $Self->{ConfigItemObject}->GetAttributeValuesByKey(
                KeyName       => $AttToConsider,
                XMLData       => $Param{CurrVersionData}->{XMLData}->[1]->{Version}->[1],
                XMLDefinition => $Param{CurrVersionData}->{XMLDefinition},
            );
            if ( $AttValue->[0] ) {

                # get class-attribute icon in gray if necessary
                if ( !$WithColor ) {
                    $Image =
                        $Self->{Config}->{ObjectImagesNotActive}
                        ->{ $Param{CurrVersionData}->{Class} . ':::' . $AttValue->[0] };
                }

                # no image? get class-attribute icon in color
                if ( !$Image ) {
                    $Image =
                        $Self->{Config}->{ObjectImages}
                        ->{ $Param{CurrVersionData}->{Class} . ':::' . $AttValue->[0] };
                }
            }
        }
    }

    # no image? get icon for attribute in gray if necessary
    if ( !$Image && !$WithColor ) {
        $Image = $Self->{Config}->{ObjectImagesNotActive}->{ $Param{CurrVersionData}->{Class} };
    }

    # no image? get class icon in color
    if ( !$Image ) {
        $Image = $Self->{Config}->{ObjectImages}->{ $Param{CurrVersionData}->{Class} };
    }

    # no image? get default icon in gray if necessary
    if ( !$Image && !$WithColor ) {
        $Image = $Self->{Config}->{ObjectImagesNotActive}->{'Default'};
    }

    # last fallback if there is no image until now
    if ( !$Image ) {
        $Image = $Self->{Config}->{ObjectImages}->{'Default'};
    }

    # build object
    $Self->{LayoutObject}->Block(
        Name => 'ITSMConfigItem',
        Data => {
            CurrentObjectType => $Param{CurrentObjectType},
            CurrentObjectID   => $Param{CurrentObjectID},
            Session           => ";$Self->{SessionName}=$Self->{SessionID}",
            IncidentImage     => $Self->{Config}->{IncidentStateImages}
                ->{ $Param{CurrVersionData}->{CurInciStateType} },
            Image                => $Image,
            Start                => $Param{Start},
            Name                 => $Param{CurrVersionData}->{Name},
            DeplStateColor       => $Param{DeplStateColor},
            Number               => $Param{CurrVersionData}->{Number},
            Class                => $Param{CurrVersionData}->{Class},
            ClassID              => $Param{CurrVersionData}->{ClassID},
            CurIncidentState     => $Param{CurrVersionData}->{CurInciState},
            CurIncidentStateType => $Param{CurrVersionData}->{CurInciStateType},
            DeplState            => $Param{CurrVersionData}->{CurDeplState},
        },
    );

    return $Self->{LayoutObject}->Output(
        TemplateFile => 'AgentLinkGraphAdditionalITSMConfigItem',
        Data         => \%Param,
    );
}

sub _GetCINamesForLoadedGraph {
    my ( $Self, $Param ) = @_;

    my $LostNodesString = $Self->{ParamObject}->GetParam( Param => 'LostNodesString' );
    my $NewNodesString  = $Self->{ParamObject}->GetParam( Param => 'NewNodesString' );

    my %LostNodes;
    $LostNodes{None} = 1;
    my @LostNodes = split( ':::', $LostNodesString );
    for my $LostNode (@LostNodes) {
        $LostNode =~ s/ITSMConfigitem-(\d+)/$1/i;
        my $Version = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $LostNode,
        );
        $LostNodes{$LostNode} = {
            'Name'   => $Version->{Name},
            'Number' => $Version->{Number},
        };
        $LostNodes{None} = 0;
    }

    my %NewNodes;
    $NewNodes{None} = 1;
    my @NewNodes = split( ':::', $NewNodesString );
    for my $NewNode (@NewNodes) {
        $NewNode =~ s/ITSMConfigitem-(\d+)/$1/i;
        my $Version = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $NewNode,
        );
        $NewNodes{$NewNode} = {
            'Name'   => $Version->{Name},
            'Number' => $Version->{Number},
        };
        $NewNodes{None} = 0;
    }

    my $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => {
            LostNodes => \%LostNodes,
            NewNodes  => \%NewNodes,
        },
    );
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _PropagateInciState {
    my ( $Self, %Param ) = @_;

    my $Direction      = 0;
    my $PropagateStart = 0;
    my $NewInciState   = 'operational';

    # get relevant link types and their direction
    my $RelevantLinkTypes = $Self->{ConfigObject}->Get('ITSM::Core::IncidentLinkTypeDirection');

    # check if current link type is equal to relevant link type from config
    if (
        $Param{Result}
        && $RelevantLinkTypes->{ $Param{LinkType} }
        )
    {

        # get attributes of source
        my $CIAttsSource = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $Param{SourceID},
            XMLDataGet   => 0,
        );

        # get attributes of target
        my $CIAttsTarget = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $Param{TargetID},
            XMLDataGet   => 0,
        );

        if (
            !$Param{SourceInciStateType}
            || $CIAttsSource->{CurInciStateType} ne $Param{SourceInciStateType}
            )
        {
            $PropagateStart = $Param{SourceType} . '-' . $Param{SourceID};
            $NewInciState   = $CIAttsSource->{CurInciStateType};
        }
        elsif (
            !$Param{TargetInciStateType}
            || $CIAttsTarget->{CurInciStateType} ne $Param{TargetInciStateType}
            )
        {
            $PropagateStart = $Param{TargetType} . '-' . $Param{TargetID};
            $NewInciState   = $CIAttsTarget->{CurInciStateType};
        }

        # get direction
        if ($PropagateStart) {
            $Direction = $RelevantLinkTypes->{ $Param{LinkType} };
        }
    }

    my $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => {
            Result    => $Param{Result},
            Direction => $Direction,
            LinkType  => $Param{LinkType},
            Image     => $Self->{ConfigObject}->Get('Frontend::ImagePath')
                . $Self->{Config}->{IncidentStateImages}->{$NewInciState},
            InciState      => $Self->{LayoutObject}->{LanguageObject}->Translate($NewInciState),
            PropagateStart => $PropagateStart,
        },
    );
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _GetClassNames {
    my ( $Self, %Param ) = @_;

    # get class-names
    my @GraphSubTypes = split( ',', $Param{ClassIDString} );
    my $ClassesString = '';
    for my $ClassID (@GraphSubTypes) {
        my $ItemRef = $Self->{GeneralCatalogObject}->ItemGet(
            ItemID => $ClassID,
        );
        if (
            $ItemRef
            && ref($ItemRef) eq 'HASH'
            && $ItemRef->{Class} eq 'ITSM::ConfigItem::Class'
            )
        {
            $ClassesString .=
                $Self->{LayoutObject}->{LanguageObject}->Translate( $ItemRef->{Name} ) . ', ';
        }
    }
    $ClassesString =~ s/(.*), $/$1/i;
    return $ClassesString;
}

sub _InsertCI {
    my ( $Self, %Param ) = @_;

    my @CurObject = split( '-', $Self->{ParamObject}->GetParam( Param => 'DestObject' ) );

    # get CI attributes
    my $CurrVersionData;

    # check if xml data is needed
    my $ConsiderAttribute;
    if ( defined $Self->{Config}->{ClassAttributesToConsider} ) {
        $CurrVersionData = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $CurObject[1],
        );
        $ConsiderAttribute = 1;
    }
    else {
        $CurrVersionData = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $CurObject[1],
            XMLDataGet   => 0,
        );
    }

    my $CIString = '';
    if ($CurrVersionData) {
        my $DeplStateColor;
        if (
            $Self->{ConfigObject}->Get('ConfigItemLinkGraph::HighlightMapping')->{ $CurrVersionData->{CurDeplState} }
        ) {
            $DeplStateColor = $Self->{ConfigObject}->Get('ConfigItemLinkGraph::HighlightMapping')->{ $CurrVersionData->{CurDeplState} };
        }

        # get possible deployment state list for config items to be in color
        # get relevant functionality
        my $ColorDeploymentStatePostproductive = $Self->{ConfigObject}->Get('ConfigItemOverview::ShowDeploymentStatePostproductive');
        my @ColorFunctionality                 = ( 'preproductive', 'productive' );
        if ($ColorDeploymentStatePostproductive) {
            push( @ColorFunctionality, 'postproductive' );
        }
        # get state list
        my $ColorStateList = $Self->{GeneralCatalogObject}->ItemList(
            Class       => 'ITSM::ConfigItem::DeploymentState',
            Preferences => {
                Functionality => \@ColorFunctionality,
            },
        );
        # remove excluded deployment states from state list
        my %ColorDeplStateList = %{$ColorStateList};
        if ( $Self->{ConfigObject}->Get('ConfigItemOverview::ExcludedDeploymentStates') ) {
            my @ExcludedStates = split(
                /,/,
                $Self->{ConfigObject}->Get('ConfigItemOverview::ExcludedDeploymentStates')
            );
            for my $Item ( keys %ColorDeplStateList ) {
                next if !( grep { /^$ColorDeplStateList{$Item}$/ } @ExcludedStates );
                delete $ColorDeplStateList{$Item};
            }
        }

        $CIString = $Self->_BuildNodes(
            %Param,
            CurrVersionData   => $CurrVersionData,
            CurrentObjectType => $CurObject[0],
            CurrentObjectID   => $CurObject[1],
            DeplStatesColor   => \%ColorDeplStateList,
            ConsiderAttribute => $ConsiderAttribute,
            DeplStateColor    => $DeplStateColor,
        );
    }

    my $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => {
            NodeString => $CIString,
        },
    );

    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
