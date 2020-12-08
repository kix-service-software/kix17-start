# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    $Self->{Config} = $ConfigObject->Get("Frontend::Agent::$Self->{Action}");

    $Self->{BaseURL} = $ConfigObject->Get('HttpType')
        . '://'
        . $ConfigObject->Get('FQDN')
        . '/'
        . $ConfigObject->Get('ScriptAlias')
        . 'index.pl';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $LinkObject           = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my %GetParam = ();
    for my $Param (
        qw(
            ObjectType ObjectID Template OpenWindow
            MaxSearchDepth RelevantLinkTypes RelevantObjectSubTypes AdjustingStrength
        )
    ) {
        $GetParam{$Param} = $ParamObject->GetParam( Param => $Param ) || '';
    }

    # check needed stuff
    for ( qw(ObjectType ObjectID) ) {
        if ( !$GetParam{$_} ) {
            return $LayoutObject->ErrorScreen(
                Message => 'No ' . $_ . ' is given!',
                Comment => 'Please contact the admin.',
            );
        }
    }
    if ( $GetParam{ObjectType} ne 'ITSMConfigItem' ) {
        return $LayoutObject->ErrorScreen(
            Message => 'Wrong ObjectType is given!',
            Comment => 'Please contact the admin.',
        );
    }

    if ( $GetParam{Template} ) {
        # reset template
        if ( $Self->{Subaction} eq 'ResetTemplate' ) {
            for my $Param ( qw(MaxSearchDepth RelevantLinkTypes RelevantObjectSubTypes AdjustingStrength) ) {
                $UserObject->SetPreferences(
                    Key    => 'CIGTemplate::' . $GetParam{Template} . '::' . $Param,
                    Value  => '',
                    UserID => $Self->{UserID},
                );
            }
        }
        # edit template
        elsif ( $Self->{Subaction} eq 'SetTemplate' ) {
            for my $Param ( qw(MaxSearchDepth RelevantLinkTypes RelevantObjectSubTypes AdjustingStrength) ) {
                $UserObject->SetPreferences(
                    Key    => 'CIGTemplate::' . $GetParam{Template} . '::' . $Param,
                    Value  => $GetParam{$Param} || '',
                    UserID => $Self->{UserID},
                );
            }
        }
    }

    # prepare templates
    my %UserPreferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );
    if ( !$GetParam{Template} ) {
        $GetParam{Template} = $UserPreferences{CIGTemplate} || $Self->{Config}->{DefaultTemplate} || '';
    }

    # set preference
    $UserObject->SetPreferences(
        Key    => 'CIGTemplate',
        Value  => $GetParam{Template},
        UserID => $Self->{UserID},
    );

    my $TemplateConfig = $ConfigObject->Get('CIGraphConfigTemplate');
    my %Templates      = ();
    TEMPLATE:
    for my $Template ( keys ( %{ $TemplateConfig->{Name} } ) ) {
        # check template
        next TEMPLATE if (
            !$Template
            || !$TemplateConfig->{Name}->{$Template}
            || !$TemplateConfig->{Permission}->{$Template}
        );

        # check for access rights
        my $HasAccess = $ConfigItemObject->Permission(
            Scope  => 'Item',
            ItemID => $GetParam{ObjectID},
            UserID => $Self->{UserID},
            Type   => $TemplateConfig->{Permission}->{$Template},
        );
        next TEMPLATE if ( !$HasAccess );

        # add template
        $Templates{$Template} = $TemplateConfig->{Name}->{$Template};

        # check current template
        if ( $Template eq $GetParam{Template} ) {
            $GetParam{MaxSearchDepth}         = $UserPreferences{'CIGTemplate::' . $GetParam{Template} . '::MaxSearchDepth'}         || $TemplateConfig->{MaxSearchDepth}->{$Template}         || '';
            $GetParam{RelevantLinkTypes}      = $UserPreferences{'CIGTemplate::' . $GetParam{Template} . '::RelevantLinkTypes'}      || $TemplateConfig->{RelevantLinkTypes}->{$Template}      || '';
            $GetParam{RelevantObjectSubTypes} = $UserPreferences{'CIGTemplate::' . $GetParam{Template} . '::RelevantObjectSubTypes'} || $TemplateConfig->{RelevantObjectSubTypes}->{$Template} || '';
            $GetParam{AdjustingStrength}      = $UserPreferences{'CIGTemplate::' . $GetParam{Template} . '::AdjustingStrength'}      || $TemplateConfig->{AdjustingStrength}->{$Template}      || '';

            if ($GetParam{RelevantObjectSubTypes} =~ m/[A-Za-z]/) {
                my @Temp = split(/,/, $GetParam{RelevantObjectSubTypes});
                my @IDs  = ();
                for my $SubTyp ( @Temp ) {
                    my $ItemRef = $GeneralCatalogObject->ItemGet(
                        Class => 'ITSM::ConfigItem::Class',
                        Name  => $SubTyp,
                    );
                    push(@IDs, $ItemRef->{ItemID});
                }
                $GetParam{RelevantObjectSubTypes} = join(',', @IDs);
            }
        }
    }

    $GetParam{TemplateString} = $LayoutObject->BuildSelection(
        Name         => 'Template',
        Data         => \%Templates,
        SelectedID   => $GetParam{Template},
        Translation  => 1,
        Multiple     => 0,
        PossibleNone => 1,
        Class        => 'Modernize',
    );

    # max search depth
    my %MaxSearchDepthSelectionValues = ();
    for ( my $Count = 1; $Count < 10; $Count++ ) {
        $MaxSearchDepthSelectionValues{$Count} = $Count;
    }
    $GetParam{MaxSearchDepthString} = $LayoutObject->BuildSelection(
        Name         => 'TemplateMaxSearchDepth',
        Data         => \%MaxSearchDepthSelectionValues,
        SelectedID   => $GetParam{MaxSearchDepth},
        Translation  => 0,
        Multiple     => 0,
        PossibleNone => 0,
        Class        => 'Modernize',
    );

    # link types
    my %LinkTypeSelectionValues;
    my %LinkTypeList = $LinkObject->PossibleTypesList(
        UserID  => $Self->{UserID},
        Object1 => 'ITSMConfigItem',
        Object2 => 'ITSMConfigItem',
    );

    for my $CurrKey ( keys %LinkTypeList ) {

        # lookup real name for this type (two steps needed)
        my $TypeID = $LinkObject->TypeLookup(
            Name   => $CurrKey,
            UserID => 1,
        );
        my %Type = $LinkObject->TypeGet(
            TypeID => $TypeID,
            UserID => 1,
        );

        $LinkTypeSelectionValues{$CurrKey}
            = $Type{SourceName};
    }
    my @RelevantLinkTypeIDs;
    if ( $GetParam{RelevantLinkTypes} ) {
        @RelevantLinkTypeIDs = split(/,/, $GetParam{RelevantLinkTypes});
    }
    $GetParam{RelevantLinkTypesString} = $LayoutObject->BuildSelection(
        Data         => \%LinkTypeSelectionValues,
        SelectedID   => \@RelevantLinkTypeIDs,
        Translation  => 1,
        Name         => 'TemplateRelevantLinkTypes',
        Multiple     => 1,
        PossibleNone => 0,
        Class        => 'Modernize',
    );

    # classes
    my $CIClassListRef = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1,
    );
    my @RelevantObjectSubTypeIDs;
    if ( $GetParam{RelevantObjectSubTypes} ) {
        for my $SubTypeID ( split(/,/, $GetParam{RelevantObjectSubTypes}) ) {
            next if $SubTypeID eq '';
            push( @RelevantObjectSubTypeIDs, $SubTypeID);
        }
    }

    $GetParam{RelevantObjectSubTypesString} = $LayoutObject->BuildSelection(
        Data         => $CIClassListRef,
        SelectedID   => \@RelevantObjectSubTypeIDs,
        Translation  => 1,
        Name         => 'TemplateRelevantObjectSubTypes',
        Multiple     => 1,
        PossibleNone => 0,
        Class        => 'Modernize',
    );

    # strength
    my %AdjustingStrengthSelectionValues = (
        1 => 'Strong',
        2 => 'Medium',
        3 => 'Weak',
    );

    $GetParam{AdjustingStrengthString} = $LayoutObject->BuildSelection(
        Data         => \%AdjustingStrengthSelectionValues,
        SelectedID   => $GetParam{AdjustingStrength},
        Translation  => 1,
        Name         => 'TemplateAdjustingStrength',
        Multiple     => 0,
        PossibleNone => 0,
        Sort         => 'NumericKey',
        Class        => 'Modernize',
    );

    # get saved graphs and their config
    if ( $Self->{Subaction} eq 'GetSavedGraphs' ) {
        my %Graphs = $Self->GetSavedGraphs( %GetParam );
        for my $Graph ( keys %Graphs ) {
            if ( $Graph =~ m/\d+/ ) {
                $Graphs{$Graph}->{SubTypes} = $Self->_GetClassNames(
                    ClassIDString => $Graphs{$Graph}->{SubTypes},
                );
            }
        }

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                Graphs => \%Graphs,
            },
        );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # get linked services and show them
    elsif ( $Self->{Subaction} eq 'ShowServices' ) {
        return $Self->ShowServices( %GetParam );
    }

    # create print output
    elsif ( $Self->{Subaction} eq 'CreatePrintOutput' ) {
        return $Self->CreatePrintOutput( %GetParam );
    }

    # save graph
    elsif ( $Self->{Subaction} eq 'SaveGraph' ) {
        my %Result = $Self->SaveGraph( %GetParam );
        $Result{GraphConfig}->{SubTypes} = $Self->_GetClassNames(
            ClassIDString => $Result{GraphConfig}->{SubTypes},
        );

        my $JSON = $LayoutObject->JSONEncode(
            Data => {
                ID              => $Result{Result}->{ID} || 0,
                GraphConfig     => $Result{GraphConfig},
                LastChangedTime => $Result{LastChangedTime},
                LastChangedBy   => $Result{LastChangedBy}
            },
        );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # load object data, build it and give it to graph
    elsif ( $Self->{Subaction} eq 'InsertNode' ) {
        return $Self->_InsertCI(%GetParam);
    }

    # write created connection into database
    elsif ( $Self->{Subaction} eq 'SaveNewConnection' ) {
        $GetParam{SourceInciStateType} = $ParamObject->GetParam( Param => 'SourceInciStateType' );
        $GetParam{TargetInciStateType} = $ParamObject->GetParam( Param => 'TargetInciStateType' );

        # do saving
        $GetParam{Result} = $Self->SaveCon(%GetParam);

        return $Self->_PropagateInciState(%GetParam);
    }

    # remove link in database
    elsif ( $Self->{Subaction} eq 'DeleteConnection' ) {
        $GetParam{SourceInciStateType} = $ParamObject->GetParam( Param => 'SourceInciStateType' );
        $GetParam{TargetInciStateType} = $ParamObject->GetParam( Param => 'TargetInciStateType' );

        # do deletion
        $GetParam{Result} = $Self->DelCon(%GetParam);

        return $Self->_PropagateInciState(%GetParam);
    }

    # get object names
    elsif ( $Self->{Subaction} eq 'GetObjectNames' ) {
        return $Self->_GetCINamesForLoadedGraph(%GetParam);
    }

    #---------------------------------------------------------------------------
    # do general preparations
    %GetParam = $Self->DoPreparations(%GetParam);

    # do ConfigItem specific preparations
    %GetParam = $Self->_PrepareITSMConfigItem(%GetParam);

    $GetParam{NodeObject}       = 'CI';
    $GetParam{VisitedNodes}     = {};
    $GetParam{DiscoveredEdges}  = {};
    $GetParam{Nodes}            = {};
    $GetParam{UserCIEditRights} = {};
    %GetParam = $Self->_GetObjectsAndLinks(
        %Param,
        %GetParam,
        CurrentObjectID   => $GetParam{ObjectID},
        CurrentObjectType => $GetParam{ObjectType},
        CurrentDepth      => 1,
    );
    if ( $GetParam{UserCIEditRights}->{String} ) {
        $GetParam{UserCIEditRights}->{String} =~ s/(.*)_-_$/$1/;
        $GetParam{UserCIEditRights} = $GetParam{UserCIEditRights}->{String};
    }

    my $Graph = $LayoutObject->Attachment( $Self->FinishGraph(%GetParam) );

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

    # create needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $GroupObject          = $Kernel::OM->Get('Kernel::System::Group');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # prepare object sub type limit...
    for my $CurrID ( @{ $Param{RelSubTypeArray} } ) {
        next if $CurrID eq '';

        my $ItemRef = $GeneralCatalogObject->ItemGet(
            ItemID => $CurrID,
        );
        if (
            $ItemRef
            && ref($ItemRef) eq 'HASH'
            && $ItemRef->{Class} eq 'ITSM::ConfigItem::Class'
        ) {
            $Param{RelevantObjectSubTypeNames}->{ $ItemRef->{Name} } = $CurrID;
        }
    }

    # get possible deployment state list for config items to be in color
    # get relevant functionality
    my $ShowDeploymentStatePostproductive = $ConfigObject->Get('ConfigItemOverview::ShowDeploymentStatePostproductive');
    my @Functionality                     = ( 'preproductive', 'productive' );
    if ($ShowDeploymentStatePostproductive) {
        push( @Functionality, 'postproductive' );
    }
    # get state list
    my $StateList = $GeneralCatalogObject->ItemList(
        Class       => 'ITSM::ConfigItem::DeploymentState',
        Preferences => {
            Functionality => \@Functionality,
        },
    );

    # remove excluded deployment states from state list
    my %DeplStateList = %{$StateList};
    if ( $ConfigObject->Get('ConfigItemOverview::ExcludedDeploymentStates') ) {
        my @ExcludedStates = split( /,/, $ConfigObject->Get('ConfigItemOverview::ExcludedDeploymentStates') );
        for my $Item ( keys %DeplStateList ) {
            next if !( grep( {/$DeplStateList{$Item}/} @ExcludedStates ) );
            delete $DeplStateList{$Item};
        }
    }
    $Param{DeplStatesColor} = \%DeplStateList;

    $Param{StateHighlighting} = $ConfigObject->Get('ConfigItemOverview::HighlightMapping');

    # get all possible linkable CI classes
    my $CIClassListRef = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1,
    );

    # check for Class read rights
    for my $ClassID ( keys %{$CIClassListRef} ) {
        my $RoRight = $ConfigItemObject->Permission(
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
        $GroupObject->GroupMemberList(
            UserID => $Self->{UserID},
            Type   => 'ro',
            Result => 'ID',
            Cached => 1,
            )
    ];

    # get config item specific class selection
    $Param{ObjectSpecificLinkSel} = $LayoutObject->BuildSelection(
        Data         => $CIClassListRef,
        SelectedID   => 1,
        Translation  => 1,
        Name         => 'CIClasses',
        Multiple     => 0,
        PossibleNone => 0,
        Class        => 'Modernize',
    );

    # remember selected CI classes for print header
    my @RelCIClasses;
    for my $SubTypeName ( keys %{ $Param{RelevantObjectSubTypeNames} } ) {
        push( @RelCIClasses, $LayoutObject->{LanguageObject}->Translate($SubTypeName) );
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

    # create needed objects
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $LogObject            = $Kernel::OM->Get('Kernel::System::Log');
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # check required params...
    for my $CurrKey (
        qw( CurrentObjectID CurrentObjectType CurrentDepth RelevantObjectSubTypeNames
        MaxSearchDepth VisitedNodes Nodes DiscoveredEdges RelevantObjectTypeNames)
    ) {
        if ( !$Param{$CurrKey} ) {
            $LogObject->Log(
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
        && $Param{VisitedNodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} } < $Param{CurrentDepth}
    ) {
        return 1;
    }

    # just create link of present CIs if they are at the end of max search depth
    if (
        $Param{Nodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} }
        &&
        $Param{CurrentDepth} == $Param{MaxSearchDepth} + 2
    ) {
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
        $CurrVersionData = $ConfigItemObject->VersionGet(
            ConfigItemID => $Param{CurrentObjectID},
        );

        # look up if special rights for CI are neccessary
        my $KeyName = '';
        for my $ClassAttributeHash ( @{ $CurrVersionData->{XMLDefinition} } ) {
            next if ( $ClassAttributeHash->{Input}->{Type} ne 'CIGroupAccess' );
            $KeyName = $ClassAttributeHash->{Key};
        }
        my $Array = $ConfigItemObject->GetAttributeContentsByKey(
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
        ) {
            return 0;
        }

        # check if object has relevant deployment state to show... but ignore start object
        if ( $Param{StartObjectID} ne $Param{CurrentObjectID} ) {
            # get possible deployment state list for config items to be shown
            # get relevant functionality
            my $ShowDeploymentStatePostproductive = $ConfigObject->Get('ConfigItemLinkGraph::ShowDeploymentStatePostproductive');
            my @ShowFunctionality                 = ( 'preproductive', 'productive' );
            if ($ShowDeploymentStatePostproductive) {
                push( @ShowFunctionality, 'postproductive' );
            }
            my $ShowStateList = $GeneralCatalogObject->ItemList(
                Class       => 'ITSM::ConfigItem::DeploymentState',
                Preferences => {
                    Functionality => \@ShowFunctionality,
                },
            );
            # remove excluded deployment states from state list
            my %ShowDeplStateList = %{$ShowStateList};
            if ( $ConfigObject->Get('ConfigItemLinkGraph::ExcludedDeploymentStates') ) {
                my @ExcludedStates =
                    split(
                    /,/,
                    $ConfigObject->Get('ConfigItemLinkGraph::ExcludedDeploymentStates')
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
        ) {
            $Start = 'border:1px solid #ee9900;';
            $Param{StartName} = $CurrVersionData->{Name};
        }

        my $DeplStateColor;
        if ( $Param{StateHighlighting}->{ $CurrVersionData->{CurDeplState} } ) {
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
        $Param{VisitedNodes}->{ $Param{CurrentObjectType} . '-' . $Param{CurrentObjectID} } = $Param{CurrentDepth};
    }

    # look for neighbouring nodes ... and return
    return $Self->LookForNeighbours(%Param);
}

sub _BuildNodes {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $LogObject        = $Kernel::OM->Get('Kernel::System::Log');

    # check required params...
    for my $CurrKey (qw( DeplStatesColor CurrentObjectType CurrentObjectID CurrVersionData )) {
        if ( !$Param{$CurrKey} ) {
            $LogObject->Log(
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
        my $AttToConsider = $Self->{Config}->{ClassAttributesToConsider}->{ $Param{CurrVersionData}->{Class} };

        # get icon for class-attribute
        if ($AttToConsider) {
            my $AttValue = $ConfigItemObject->GetAttributeValuesByKey(
                KeyName       => $AttToConsider,
                XMLData       => $Param{CurrVersionData}->{XMLData}->[1]->{Version}->[1],
                XMLDefinition => $Param{CurrVersionData}->{XMLDefinition},
            );
            if ( $AttValue->[0] ) {

                # get class-attribute icon in gray if necessary
                if ( !$WithColor ) {
                    $Image = $Self->{Config}->{ObjectImagesNotActive}->{ $Param{CurrVersionData}->{Class} . ':::' . $AttValue->[0] };
                }

                # no image? get class-attribute icon in color
                if ( !$Image ) {
                    $Image = $Self->{Config}->{ObjectImages}->{ $Param{CurrVersionData}->{Class} . ':::' . $AttValue->[0] };
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
    $LayoutObject->Block(
        Name => 'ITSMConfigItem',
        Data => {
            CurrentObjectType    => $Param{CurrentObjectType},
            CurrentObjectID      => $Param{CurrentObjectID},
            Session              => ";$Self->{SessionName}=$Self->{SessionID}",
            IncidentImage        => $Self->{Config}->{IncidentStateImages}->{ $Param{CurrVersionData}->{CurInciStateType} },
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

    return $LayoutObject->Output(
        TemplateFile => 'AgentLinkGraphAdditionalITSMConfigItem',
        Data         => \%Param,
    );
}

sub _GetCINamesForLoadedGraph {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $LostNodesString = $ParamObject->GetParam( Param => 'LostNodesString' );
    my $NewNodesString  = $ParamObject->GetParam( Param => 'NewNodesString' );

    my %LostNodes;
    $LostNodes{None} = 1;
    my @LostNodes = split( ':::', $LostNodesString );
    for my $LostNode (@LostNodes) {
        $LostNode =~ s/ITSMConfigitem-(\d+)/$1/i;
        my $Version = $ConfigItemObject->VersionGet(
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
        my $Version = $ConfigItemObject->VersionGet(
            ConfigItemID => $NewNode,
        );
        $NewNodes{$NewNode} = {
            'Name'   => $Version->{Name},
            'Number' => $Version->{Number},
        };
        $NewNodes{None} = 0;
    }

    my $JSON = $LayoutObject->JSONEncode(
        Data => {
            LostNodes => \%LostNodes,
            NewNodes  => \%NewNodes,
        },
    );
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _PropagateInciState {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    my $Direction      = 0;
    my $PropagateStart = 0;
    my $NewInciState   = 'operational';

    # get relevant link types and their direction
    my $RelevantLinkTypes = $ConfigObject->Get('ITSM::Core::IncidentLinkTypeDirection');

    # check if current link type is equal to relevant link type from config
    if (
        $Param{Result}
        && $RelevantLinkTypes->{ $Param{LinkType} }
    ) {

        # get attributes of source
        my $CIAttsSource = $ConfigItemObject->VersionGet(
            ConfigItemID => $Param{SourceID},
            XMLDataGet   => 0,
        );

        # get attributes of target
        my $CIAttsTarget = $ConfigItemObject->VersionGet(
            ConfigItemID => $Param{TargetID},
            XMLDataGet   => 0,
        );

        if (
            !$Param{SourceInciStateType}
            || $CIAttsSource->{CurInciStateType} ne $Param{SourceInciStateType}
        ) {
            $PropagateStart = $Param{SourceType} . '-' . $Param{SourceID};
            $NewInciState   = $CIAttsSource->{CurInciStateType};
        }
        elsif (
            !$Param{TargetInciStateType}
            || $CIAttsTarget->{CurInciStateType} ne $Param{TargetInciStateType}
        ) {
            $PropagateStart = $Param{TargetType} . '-' . $Param{TargetID};
            $NewInciState   = $CIAttsTarget->{CurInciStateType};
        }

        # get direction
        if ($PropagateStart) {
            $Direction = $RelevantLinkTypes->{ $Param{LinkType} };
        }
    }

    my $JSON = $LayoutObject->JSONEncode(
        Data => {
            Result         => $Param{Result},
            Direction      => $Direction,
            LinkType       => $Param{LinkType},
            Image          => $ConfigObject->Get('Frontend::ImagePath') . $Self->{Config}->{IncidentStateImages}->{$NewInciState},
            InciState      => $LayoutObject->{LanguageObject}->Translate($NewInciState),
            PropagateStart => $PropagateStart,
        },
    );
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _GetClassNames {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # get class-names
    my $ClassesString = '';
    if ( $Param{ClassIDString} ) {
        my @GraphSubTypes = split( ',', $Param{ClassIDString} );
        for my $ClassID (@GraphSubTypes) {
            my $ItemRef = $GeneralCatalogObject->ItemGet(
                ItemID => $ClassID,
            );
            if (
                $ItemRef
                && ref($ItemRef) eq 'HASH'
                && $ItemRef->{Class} eq 'ITSM::ConfigItem::Class'
            ) {
                $ClassesString .= $LayoutObject->{LanguageObject}->Translate( $ItemRef->{Name} ) . ', ';
            }
        }
        $ClassesString =~ s/(.*), $/$1/i;
    }
    return $ClassesString;
}

sub _InsertCI {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');

    my @CurObject = split( '-', $ParamObject->GetParam( Param => 'DestObject' ) );

    # get CI attributes
    my $CurrVersionData;

    # check if xml data is needed
    my $ConsiderAttribute;
    if ( defined $Self->{Config}->{ClassAttributesToConsider} ) {
        $CurrVersionData = $ConfigItemObject->VersionGet(
            ConfigItemID => $CurObject[1],
        );
        $ConsiderAttribute = 1;
    }
    else {
        $CurrVersionData = $ConfigItemObject->VersionGet(
            ConfigItemID => $CurObject[1],
            XMLDataGet   => 0,
        );
    }

    my $CIString = '';
    if ($CurrVersionData) {
        my $DeplStateColor;
        if (
            $ConfigObject->Get('ConfigItemOverview::HighlightMapping')->{ $CurrVersionData->{CurDeplState} }
        ) {
            $DeplStateColor = $ConfigObject->Get('ConfigItemOverview::HighlightMapping')->{ $CurrVersionData->{CurDeplState} };
        }

        # get possible deployment state list for config items to be in color
        my $ShowDeploymentStatePostproductive = $ConfigObject->Get('ConfigItemOverview::ShowDeploymentStatePostproductive');
        my @Functionality                     = ( 'preproductive', 'productive' );
        if ($ShowDeploymentStatePostproductive) {
            push( @Functionality, 'postproductive' );
        }
        my $StateList = $GeneralCatalogObject->ItemList(
            Class       => 'ITSM::ConfigItem::DeploymentState',
            Preferences => {
                Functionality => \@Functionality,
            },
        );

        # remove excluded deployment states from state list
        my %DeplStateList = %{$StateList};
        if ( $ConfigObject->Get('ConfigItemOverview::ExcludedDeploymentStates') ) {
            my @ExcludedStates = split( /,/, $ConfigObject->Get('ConfigItemOverview::ExcludedDeploymentStates') );
            for my $Item ( keys %DeplStateList ) {
                next if !( grep( {/$DeplStateList{$Item}/} @ExcludedStates ) );
                delete $DeplStateList{$Item};
            }
        }

        $CIString = $Self->_BuildNodes(
            %Param,
            CurrVersionData     => $CurrVersionData,
            CurrentObjectType   => $CurObject[0],
            CurrentObjectID     => $CurObject[1],
            DeplStatesColor     => \%DeplStateList,
            ConsiderAttribute   => $ConsiderAttribute,
            DeplStateColor      => $DeplStateColor,
        );
    }

    my $JSON = $LayoutObject->JSONEncode(
        Data => {
            NodeString => $CIString,
        },
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
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
