# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Ricky(dot)Kaiser(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemZoomTabLinkGraph;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    $Self->{Config} = $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $SessionObject        = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $LinkObject           = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get params
    my $ConfigItemID = $ParamObject->GetParam( Param => 'ConfigItemID' ) || 0;

    # possible params if call comes from another graph
    # not enabled yet...
    #my $RelevantObjectTypes = $ParamObject->GetParam( Param => 'RelevantObjectTypes' );
    my $RelevantObjectSubTypes =
        $ParamObject->GetParam( Param => 'RelevantObjectSubTypes' );
    my $RelevantLinkTypes = $ParamObject->GetParam( Param => 'RelevantLinkTypes' );
    my $MaxSearchDepth    = $ParamObject->GetParam( Param => 'MaxSearchDepth' );
    my $UsedStrength      = $ParamObject->GetParam( Param => 'UsedStrength' );
    my $RelevantLinkTypesRef;
    if ($RelevantLinkTypes) {
        $RelevantLinkTypesRef = [ split( ',', $RelevantLinkTypes ) ];
    }
    my $RelevantObjectSubTypesRef;
    if ($RelevantObjectSubTypes) {
        $RelevantObjectSubTypesRef = [ split( ',', $RelevantObjectSubTypes ) ];
    }
    my $DoGraphNow = 0;
    if (
        defined $RelevantObjectSubTypes
        || defined $RelevantLinkTypes
        || defined $MaxSearchDepth
        || defined $UsedStrength
        )
    {
        $DoGraphNow = 1;
    }

    # check needed stuff
    if ( !$ConfigItemID ) {
        return $LayoutObject->ErrorScreen(
            Message => 'No ConfigItemID is given!',
            Comment => 'Please contact the admin.',
        );
    }

    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $Self->{RequestedURL},
    );

    # check for access rights
    my $HasAccess = $ConfigItemObject->Permission(
        Scope  => 'Item',
        ItemID => $ConfigItemID,
        UserID => $Self->{UserID},
        Type   => $Self->{Config}->{Permission},
    );
    if ( !$HasAccess ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => 'Can\'t show item, no access rights for ConfigItem are given!',
            Comment => 'Please contact the admin.',
        );
    }

    #---------------------------------------------------------------------------
    # prepare selection values...
    # max search depth
    my %MaxSearchDepthSelectionValues = ();
    for ( my $Count = 1; $Count < 10; $Count++ ) {
        $MaxSearchDepthSelectionValues{$Count} = $Count;
    }
    my $MaxSearchDepthSelection = $LayoutObject->BuildSelection(
        Name         => 'MaxSearchDepth',
        Data         => \%MaxSearchDepthSelectionValues,
        SelectedID   => $MaxSearchDepth || $Self->{Config}->{DefaultMaxLinkDepth} || 1,
        Translation  => 0,
        Multiple     => 0,
        PossibleNone => 1,
        Class        => 'Modernize',
    );

    my %ObjectTypeSelectionValues = (
        'ITSMConfigItem' => 'Config Items',

        #'Service'        => 'Services',
        #'Tickets'        => 'Tickets',
    );

    # not enabled yet...
    #    my $ObjectTypeSelection = $LayoutObject->BuildSelection(
    #        Name         => 'RelevantObjectTypes',
    #        Data         => \%ObjectTypeSelectionValues,
    #        SelectedID   => 'ITSMConfigItem' || '',
    #        Translation  => 1,
    #        Multiple     => 1,
    #        PossibleNone => 0,
    #    );
    # EO not enabled yet

    # classes
    my $CIClassListRef = $GeneralCatalogObject->ItemList(
        Class => 'ITSM::ConfigItem::Class',
        Valid => 1,
    );

# for later use
# if ( a class is not allowed (seeConfig)) {
#    # check for access rights of classes
#    for my $ClassID (sort { $CIClassListRef->{$a} cmp $CIClassListRef->{$b} } keys $CIClassListRef ) {
#        delete $CIClassListRef->{$ClassID} if !$ConfigItemObject->Permission(
#            Scope   => 'Class',
#            ClassID => $ClassID,
#            UserID  => $Self->{UserID},
#            Type    => $Self->{Config}->{Permission},
#        );
#    }
# }

    if ( !defined $RelevantObjectSubTypesRef ) {
        $RelevantObjectSubTypesRef = [ keys( %{$CIClassListRef} ) ];
    }
    my $CIClassSelection = $LayoutObject->BuildSelection(
        Data         => $CIClassListRef,
        SelectedID   => $RelevantObjectSubTypesRef,
        Translation  => 1,
        Name         => 'RelevantObjectSubTypes',
        Multiple     => 1,
        PossibleNone => 0,
        Class        => 'Modernize',
    );

    $LayoutObject->Block(
        Name => 'ObjectSpecificSelections',
        Data => {
            Title           => "CI-Classes to consider",
            SelectionString => $CIClassSelection
        },
    );
    my $SelectionBlock = $LayoutObject->Output(
        TemplateFile => 'AgentZoomTabLinkGraphAdditional',
        Data         => \%Param,
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

    if ( !defined $RelevantLinkTypesRef ) {
        $RelevantLinkTypesRef = [ keys %LinkTypeSelectionValues ];
    }
    my $LinkTypeSelection = $LayoutObject->BuildSelection(
        Data         => \%LinkTypeSelectionValues,
        SelectedID   => $RelevantLinkTypesRef,
        Translation  => 1,
        Name         => 'RelevantLinkTypes',
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

    my $AdjustingStrengthSelection = $LayoutObject->BuildSelection(
        Data         => \%AdjustingStrengthSelectionValues,
        SelectedID   => $UsedStrength || 2,
        Translation  => 1,
        Name         => 'AdjustingStrength',
        Multiple     => 0,
        PossibleNone => 0,
        Sort         => 'NumericKey',
        Class        => 'Modernize',
    );

    $LayoutObject->Block(
        Name => 'TabContent',
        Data => {
            %{ $Self->{Config}->{IFrameConfig} },
            CurrentObjectType => 'ITSMConfigItem',
            CurrentObjectID   => $ConfigItemID,

            # currently not enabled...
            #ObjectTypeSelStr  => $ObjectTypeSelection,
            ObjectSpecificSelStr    => $SelectionBlock,
            MaxSearchDepthStr       => $MaxSearchDepthSelection,
            LinkTypeSelStr          => $LinkTypeSelection,
            AdjustingStrengthSelStr => $AdjustingStrengthSelection,
        },
    );

    #---------------------------------------------------------------------------
    # generate output...
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentZoomTabLinkGraph',
        Data         => {
            %{ $Self->{Config}->{IFrameConfig} },
            CurrentObjectType => 'ITSMConfigItem',
            CurrentObjectID   => $ConfigItemID,

            # currently not enabled...
            #ObjectTypeSelStr  => $ObjectTypeSelection,
            CIClassSelStr           => $CIClassSelection,
            MaxSearchDepthStr       => $MaxSearchDepthSelection,
            LinkTypeSelStr          => $LinkTypeSelection,
            AdjustingStrengthSelStr => $AdjustingStrengthSelection,
            DoGraphNow              => $DoGraphNow,
        },
    );
    $Output .= $LayoutObject->Footer( Type => 'TicketZoomTab' );
    return $Output;
}

1;
