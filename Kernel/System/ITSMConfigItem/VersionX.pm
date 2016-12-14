# --
# Kernel/System/ITSMConfigItem/VersionX.pm - additional sub module of ITSMConfigItem.pm with additional or modified functions
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::VersionX;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(:all);

use Storable;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ITSMConfigItem::Version - sub module of Kernel::System::ITSMConfigItem

=head1 SYNOPSIS

All version functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

# EO REPLACE ORIGINAL METHODS DUE TO OTRS-BUG 7830
#-------------------------------------------------------------------------------

=item VersionAdd()

add a new version

    my $VersionID = $ConfigItemObject->VersionAdd(
        ConfigItemID => 123,
        Name         => 'The Name',
        DefinitionID => 1212,
        DeplStateID  => 8,
        InciStateID  => 4,
        XMLData      => $ArrayHashRef,  # (optional)
        UserID       => 1,
    );

=cut

sub VersionAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Attribute (qw(ConfigItemID Name DefinitionID DeplStateID InciStateID UserID)) {
        if ( !$Param{$Attribute} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Attribute!",
            );
            return;
        }
    }

    # get deployment state list
    my $DeplStateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::DeploymentState',
    );

    return if !$DeplStateList;
    return if ref $DeplStateList ne 'HASH';

    # check the deployment state id
    if ( !$DeplStateList->{ $Param{DeplStateID} } ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No valid deployment state id given!',
        );
        return;
    }

    # get incident state list
    my $InciStateList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::Core::IncidentState',
    );

    return if !$InciStateList;
    return if ref $InciStateList ne 'HASH';

    # check the incident state id
    if ( !$InciStateList->{ $Param{InciStateID} } ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No valid incident state id given!',
        );
        return;
    }

    # get VersionList
    my $VersionList = $Self->VersionList(
        ConfigItemID => $Param{ConfigItemID},
    );

    my $ConfigItemInfo = {};

    if ( @{$VersionList} ) {

        # get old version info for comparisons with current version
        # this is needed to trigger some events
        $ConfigItemInfo = $Self->VersionGet(
            ConfigItemID => $Param{ConfigItemID},
            XMLDataGet   => 0,
        );
    }
    else {

        # get config item
        $ConfigItemInfo = $Self->ConfigItemGet(
            ConfigItemID => $Param{ConfigItemID},
        );
    }

    return if !$ConfigItemInfo;
    return if ref $ConfigItemInfo ne 'HASH';

    # check, whether the feature to check for a unique name is enabled
    if ( $Kernel::OM->Get('Kernel::Config')->Get('UniqueCIName::EnableUniquenessCheck') ) {

        my $NameDuplicates = $Self->UniqueNameCheck(
            ConfigItemID => $Param{ConfigItemID},
            ClassID      => $ConfigItemInfo->{ClassID},
            Name         => $Param{Name},
        );

        # stop processing if the name is not unique
        if ( IsArrayRefWithData($NameDuplicates) ) {

            # build a string of all duplicate IDs
            my $Duplicates = join ', ', @{$NameDuplicates};

            # write an error log message containing all the duplicate IDs
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "The name $Param{Name} is already in use (ConfigItemIDs: $Duplicates)!",
            );
            return;
        }
    }

    my $Events = $Self->_GetEvents(
        Param          => \%Param,
        ConfigItemInfo => $ConfigItemInfo,
    );

    my $ReturnVersionID = scalar @{$VersionList} ? $VersionList->[-1] : 0;
    return $ReturnVersionID if !( $Events && keys %{$Events} );

    # KIX4OTRS-capeIT
    my $Result = 0;

    # trigger Pre-VersionCreate event
    $Result = $Self->PreEventHandler(
        Event => 'VersionCreate',
        Data  => {
            ConfigItemID => $Param{ConfigItemID},
            Name         => $Param{Name},
            DefinitionID => $Param{DefinitionID},
            DeplStateID  => $Param{DeplStateID},
            InciStateID  => $Param{InciStateID},
            XMLData      => $Param{XMLData},
            SkipPreEvent => $Param{SkipPreEvent},
            Comment      => '',
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Pre-VersionCreate refused version update.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }

    # trigger Pre-ValudeUpdate event
    if ( $Events->{ValueUpdate} ) {
        $Result = $Self->_PreEventHandlerForChangedXMLValues(
            ConfigItemID => $Param{ConfigItemID},
            Name         => $Param{Name},
            DefinitionID => $Param{DefinitionID},
            DeplStateID  => $Param{DeplStateID},
            InciStateID  => $Param{InciStateID},
            XMLData      => $Param{XMLData},
            SkipPreEvent => $Param{SkipPreEvent},
            UpdateValues => $Events->{ValueUpdate},
            UserID       => $Param{UserID},
        );
        if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Pre-ValueUpdate refused version update.",
            );
            return $Result;
        }
        elsif ( ref($Result) eq 'HASH' ) {
            for my $ResultKey ( keys %{$Result} ) {
                $Param{$ResultKey} = $Result->{$ResultKey};
            }
        }
    }

    # trigger Pre-definition update event
    if ( $Events->{DefinitionUpdate} ) {
        $Result = $Self->PreEventHandler(
            Event => 'DefinitionUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Name         => $Param{Name},
                DefinitionID => $Param{DefinitionID},
                DeplStateID  => $Param{DeplStateID},
                InciStateID  => $Param{InciStateID},
                XMLData      => $Param{XMLData},
                SkipPreEvent => $Param{SkipPreEvent},
                Comment      => $Events->{DefinitionUpdate},
            },
            UserID => $Param{UserID},
        );
        if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Pre-DefinitionUpdate refused version update.",
            );
            return $Result;
        }
        elsif ( ref($Result) eq 'HASH' ) {
            for my $ResultKey ( keys %{$Result} ) {
                $Param{$ResultKey} = $Result->{$ResultKey};
            }
        }
    }

    # check old and new name
    if ( $Events->{NameUpdate} ) {
        $Result = $Self->PreEventHandler(
            Event => 'NameUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Name         => $Param{Name},
                DefinitionID => $Param{DefinitionID},
                DeplStateID  => $Param{DeplStateID},
                InciStateID  => $Param{InciStateID},
                XMLData      => $Param{XMLData},
                SkipPreEvent => $Param{SkipPreEvent},
                Comment      => $Events->{NameUpdate},
            },
            UserID => $Param{UserID},
        );
        if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Pre-NameUpdate refused version update.",
            );
            return $Result;
        }
        elsif ( ref($Result) eq 'HASH' ) {
            for my $ResultKey ( keys %{$Result} ) {
                $Param{$ResultKey} = $Result->{$ResultKey};
            }
        }
    }

    # trigger incident state update event
    if ( $Events->{IncidentStateUpdate} ) {
        $Result = $Self->PreEventHandler(
            Event => 'IncidentStateUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Name         => $Param{Name},
                DefinitionID => $Param{DefinitionID},
                DeplStateID  => $Param{DeplStateID},
                InciStateID  => $Param{InciStateID},
                XMLData      => $Param{XMLData},
                SkipPreEvent => $Param{SkipPreEvent},
                Comment      => $Events->{IncidentStateUpdate},
            },
            UserID => $Param{UserID},
        );
        if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Pre-IncidentStateUpdate refused version update.",
            );
            return $Result;
        }
        elsif ( ref($Result) eq 'HASH' ) {
            for my $ResultKey ( keys %{$Result} ) {
                $Param{$ResultKey} = $Result->{$ResultKey};
            }
        }
    }

    # trigger deployment state update event
    if ( $Events->{DeploymentStateUpdate} ) {
        $Result = $Self->PreEventHandler(
            Event => 'DeploymentStateUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                UserID       => $Param{UserID},
                DefinitionID => $Param{DefinitionID},
                DeplStateID  => $Param{DeplStateID},
                InciStateID  => $Param{InciStateID},
                XMLData      => $Param{XMLData},
                SkipPreEvent => $Param{SkipPreEvent},
                Comment      => $Events->{DeploymentStateUpdate},
            },
            UserID => $Param{UserID},
        );
        if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Pre-DeploymentStateUpdate refused version update.",
            );
            return $Result;
        }
        elsif ( ref($Result) eq 'HASH' ) {
            for my $ResultKey ( keys %{$Result} ) {
                $Param{$ResultKey} = $Result->{$ResultKey};
            }
        }
    }

    # EO KIX4OTRS-capeIT

    # insert new version
    my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO configitem_version '
            . '(configitem_id, name, definition_id, '
            . 'depl_state_id, inci_state_id, create_time, create_by) VALUES '
            . '(?, ?, ?, ?, ?, current_timestamp, ?)',
        Bind => [
            \$Param{ConfigItemID},
            \$Param{Name},
            \$Param{DefinitionID},
            \$Param{DeplStateID},
            \$Param{InciStateID},
            \$Param{UserID},
        ],
    );

    return if !$Success;

    # delete cache
    for my $VersionID ( @{$VersionList} ) {
        delete $Self->{Cache}->{VersionGet}->{$VersionID};
    }

    # get id of new version
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, create_time FROM configitem_version WHERE '
            . 'configitem_id = ? ORDER BY id DESC',
        Bind  => [ \$Param{ConfigItemID} ],
        Limit => 1,
    );

    # fetch the result
    my $VersionID;
    my $CreateTime;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $VersionID  = $Row[0];
        $CreateTime = $Row[1];
    }

    # check version id
    if ( !$VersionID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't get the new version id!",
        );
        return;
    }

    # add xml data
    if ( $Param{XMLData} && ref $Param{XMLData} eq 'ARRAY' ) {
        $Self->_XMLVersionAdd(
            ClassID      => $ConfigItemInfo->{ClassID},
            ConfigItemID => $Param{ConfigItemID},
            VersionID    => $VersionID,
            XMLData      => $Param{XMLData},
        );
    }

    # update last_version_id, cur_depl_state_id, cur_inci_state_id, change_time and change_by
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE configitem SET last_version_id = ?, '
            . 'cur_depl_state_id = ?, cur_inci_state_id = ?, '
            . 'change_time = ?, change_by = ? '
            . 'WHERE id = ?',
        Bind => [
            \$VersionID,
            \$Param{DeplStateID},
            \$Param{InciStateID},
            \$CreateTime,
            \$Param{UserID},
            \$Param{ConfigItemID},
        ],
    );

    # trigger VersionCreate event
    $Self->EventHandler(
        Event => 'VersionCreate',
        Data  => {
            ConfigItemID => $Param{ConfigItemID},
            Comment      => $VersionID,
        },
        UserID => $Param{UserID},
    );

    # compare current and old values
    if ( $Events->{ValueUpdate} ) {
        $Self->_EventHandlerForChangedXMLValues(
            ConfigItemID => $Param{ConfigItemID},
            UpdateValues => $Events->{ValueUpdate},
            UserID       => $Param{UserID},
        );
    }

    # trigger definition update event
    if ( $Events->{DefinitionUpdate} ) {
        $Self->EventHandler(
            Event => 'DefinitionUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Comment      => $Events->{DefinitionUpdate},
            },
            UserID => $Param{UserID},
        );
    }

    # check old and new name
    if ( $Events->{NameUpdate} ) {
        $Self->EventHandler(
            Event => 'NameUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Comment      => $Events->{NameUpdate},
            },
            UserID => $Param{UserID},
        );
    }

    # trigger incident state update event
    if ( $Events->{IncidentStateUpdate} ) {
        $Self->EventHandler(
            Event => 'IncidentStateUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Comment      => $Events->{IncidentStateUpdate},
            },
            UserID => $Param{UserID},
        );
    }

    # trigger deployment state update event
    if ( $Events->{DeploymentStateUpdate} ) {
        $Self->EventHandler(
            Event => 'DeploymentStateUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Comment      => $Events->{DeploymentStateUpdate},
            },
            UserID => $Param{UserID},
        );
    }

    # recalculate the current incident state of all linked config items
    $Self->CurInciStateRecalc(
        ConfigItemID => $Param{ConfigItemID},
    );

    return $VersionID;
}

=item VersionDelete()

delete an existing version or versions

    my $True = $ConfigItemObject->VersionDelete(
        VersionID => 123,
        UserID    => 1,
    );

    or

    my $True = $ConfigItemObject->VersionDelete(
        ConfigItemID => 321,
        UserID       => 1,
    );

=cut

sub VersionDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }
    if ( !$Param{VersionID} && !$Param{ConfigItemID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need VersionID or ConfigItemID!',
        );
        return;
    }

    my $VersionList = [];
    if ( $Param{VersionID} ) {

        push @{$VersionList}, $Param{VersionID};
    }
    else {

        # get version list
        $VersionList = $Self->VersionList(
            ConfigItemID => $Param{ConfigItemID},
        );
    }

    return 1 if !scalar @{$VersionList};

    # KIX4OTRS-capeIT
    my $Result = $Self->PreEventHandler(
        Event => 'VersionDelete',
        Data  => {
            ConfigItemID => $Param{ConfigItemID} || '',
            VersionID    => $Param{VersionID}    || '',
        },
        UserID => $Param{UserID},
    );
    if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Pre-VersionDelete refused version delete.",
        );
        return $Result;
    }
    elsif ( ref($Result) eq 'HASH' ) {
        for my $ResultKey ( keys %{$Result} ) {
            $Param{$ResultKey} = $Result->{$ResultKey};
        }
    }

    # EO KIX4OTRS-capeIT

    my $Success;
    for my $VersionID ( @{$VersionList} ) {

        # get config item id for version (needed for event handling)
        my $ConfigItemID = $Param{ConfigItemID};
        if ( $Param{VersionID} ) {
            $ConfigItemID = $Self->VersionConfigItemIDGet(
                VersionID => $Param{VersionID},
            );
        }

        # delete the xml version data
        $Self->_XMLVersionDelete(
            VersionID => $VersionID,
            UserID    => $Param{UserID},
        );

        # delete version
        $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => "DELETE FROM configitem_version WHERE id = ?",
            Bind => [ \$VersionID ],
        );

        # trigger VersionDelete event when deletion was successful
        if ($Success) {

            $Self->EventHandler(
                Event => 'VersionDelete',
                Data  => {
                    ConfigItemID => $ConfigItemID,
                    Comment      => $VersionID,
                },
                UserID => $Param{UserID},
            );

            # delete cache
            delete $Self->{Cache}->{VersionGet}->{$VersionID};
            delete $Self->{Cache}->{VersionConfigItemIDGet}->{$VersionID};
        }
    }

    return $Success;
}

# REPLACE ORIGINAL METHODS DUE TO OTRS-BUG 7830

=item VersionSearch()

return a config item list as an array reference

    my $ConfigItemIDs = $ConfigItemObject->VersionSearch(
        Name         => 'The Name',      # (optional)
        ClassIDs     => [ 9, 8, 7, 6 ],  # (optional)
        DeplStateIDs => [ 321, 123 ],    # (optional)
        InciStateIDs => [ 321, 123 ],    # (optional)

        PreviousVersionSearch => 1,  # (optional) default 0 (0|1)

        OrderBy => [ 'ConfigItemID', 'Number' ],                  # (optional)
        # default: [ 'ConfigItemID' ]
        # (ConfigItemID, Name, Number, ClassID, DeplStateID, InciStateID
        # CreateTime, CreateBy, ChangeTime, ChangeBy)

        # Additional information for OrderBy:
        # The OrderByDirection can be specified for each OrderBy attribute.
        # The pairing is made by the array indices.

        OrderByDirection => [ 'Up', 'Down' ],                    # (optional)
        # default: [ 'Up' ]
        # (Down | Up)

        Limit          => 122,  # (optional)
        UsingWildcards => 0,    # (optional) default 1
    );

=cut

sub VersionSearch {
    my ( $Self, %Param ) = @_;

    # set default values
    if ( !defined $Param{UsingWildcards} ) {
        $Param{UsingWildcards} = 1;
    }

    # verify that all passed array parameters contain an arrayref
    ARGUMENT:
    for my $Argument (
        qw(
        OrderBy
        OrderByDirection
        )
        )
    {
        if ( !defined $Param{$Argument} ) {
            $Param{$Argument} ||= [];

            next ARGUMENT;
        }

        if ( ref $Param{$Argument} ne 'ARRAY' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$Argument must be an array reference!",
            );
            return;
        }
    }

    # set default order and order direction
    if ( !@{ $Param{OrderBy} } ) {
        $Param{OrderBy} = ['ConfigItemID'];
    }
    if ( !@{ $Param{OrderByDirection} } ) {
        $Param{OrderByDirection} = ['Up'];
    }

    # define order table
    my %OrderByTable = (
        ConfigItemID => 'vr.configitem_id',
        Name         => 'vr.name',
        Number       => 'ci.configitem_number',
        ClassID      => 'ci.class_id',
        DeplStateID  => 'vr.depl_state_id',
        InciStateID  => 'vr.inci_state_id',
        CreateTime   => 'ci.create_time',
        CreateBy     => 'ci.create_by',

        # the change time of the CI is the same as the create time of the version!
        ChangeTime => 'vr.create_time',

        ChangeBy => 'ci.change_by',
    );

    # check if OrderBy contains only unique valid values
    my %OrderBySeen;

    # KIX4OTRS-capeIT
    my @TempArray = ();

    # EO KIX4OTRS-capeIT

    for my $OrderBy ( @{ $Param{OrderBy} } ) {

        # KIX4OTRS-capeIT
        # if ( !$OrderBy || !$OrderByTable{$OrderBy} || $OrderBySeen{$OrderBy} ) {
        #
        # # found an error
        #     $Kernel::OM->Get('Kernel::System::Log')->Log(
        #         Priority => 'error',
        #         Message  => "OrderBy contains invalid value '$OrderBy' "
        #             . 'or the value is used more than once!',
        #     );
        #     return;
        # }

        if ( $OrderBy && $OrderByTable{$OrderBy} && !$OrderBySeen{$OrderBy} ) {
            push @TempArray, $OrderBy;
        }

        # EO KIX4OTRS-capeIT

        # remember the value to check if it appears more than once
        $OrderBySeen{$OrderBy} = 1;
    }

    # KIX4OTRS-capeIT
    if ( !scalar @TempArray ) {
        push @TempArray, 'Number';
    }
    $Param{OrderBy} = \@TempArray;

    # EO KIX4OTRS-capeIT

    # check if OrderByDirection array contains only 'Up' or 'Down'
    DIRECTION:
    for my $Direction ( @{ $Param{OrderByDirection} } ) {

        # only 'Up' or 'Down' allowed
        next DIRECTION if $Direction eq 'Up';
        next DIRECTION if $Direction eq 'Down';

        # found an error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "OrderByDirection can only contain 'Up' or 'Down'!",
        );
        return;
    }

    # assemble the ORDER BY clause
    my @SQLOrderBy;
    my $Count = 0;
    my @OrderBySelectColumns;
    for my $OrderBy ( @{ $Param{OrderBy} } ) {

        # set the default order direction
        my $Direction = 'DESC';

        # add the given order direction
        if ( $Param{OrderByDirection}->[$Count] ) {
            if ( $Param{OrderByDirection}->[$Count] eq 'Up' ) {
                $Direction = 'ASC';
            }
            elsif ( $Param{OrderByDirection}->[$Count] eq 'Down' ) {
                $Direction = 'DESC';
            }
        }

        # add SQL
        push @SQLOrderBy,           "$OrderByTable{$OrderBy} $Direction";
        push @OrderBySelectColumns, $OrderByTable{$OrderBy};

    }
    continue {
        $Count++;
    }

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString
        = $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('LikeEscapeString');

    # add name to sql where array
    my @SQLWhere;
    if ( defined $Param{Name} && $Param{Name} ne '' ) {

        # duplicate the name
        my $Name = $Param{Name};

        # quote
        $Name = $Kernel::OM->Get('Kernel::System::DB')->Quote($Name);

        if ( $Param{UsingWildcards} ) {

            # prepare like string
            $Self->_PrepareLikeString( \$Name );

            push @SQLWhere, "LOWER(vr.name) LIKE LOWER('$Name') $LikeEscapeString";
        }
        else {
            push @SQLWhere, "LOWER(vr.name) = LOWER('$Name')";
        }
    }

    # set array params
    my %ArrayParams = (
        ClassIDs     => 'ci.id = vr.configitem_id AND ci.class_id',
        DeplStateIDs => 'vr.depl_state_id',
        InciStateIDs => 'vr.inci_state_id',
    );

    ARRAYPARAM:
    for my $ArrayParam ( sort keys %ArrayParams ) {

        next ARRAYPARAM if !$Param{$ArrayParam};

        if ( ref $Param{$ArrayParam} ne 'ARRAY' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$ArrayParam must be an array reference!",
            );
            return;
        }

        next ARRAYPARAM if !@{ $Param{$ArrayParam} };

        # quote as integer
        for my $OneParam ( @{ $Param{$ArrayParam} } ) {
            $OneParam = $Kernel::OM->Get('Kernel::System::DB')->Quote( $OneParam, 'Integer' );
        }

        # create string
        my $InString = join q{, }, @{ $Param{$ArrayParam} };

        push @SQLWhere, "$ArrayParams{ $ArrayParam } IN ($InString)";
    }

    # add previous version param
    if ( !$Param{PreviousVersionSearch} ) {
        push @SQLWhere, 'ci.last_version_id = vr.id';
    }

    # create where string
    my $WhereString = @SQLWhere ? ' WHERE ' . join q{ AND }, @SQLWhere : '';

    # set limit, quote as integer
    if ( $Param{Limit} ) {
        $Param{Limit} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{Limit}, 'Integer' );
    }

    # add the order by columns also to the selected columns
    my $OrderBySelectString = '';
    if (@OrderBySelectColumns) {
        $OrderBySelectString = join ', ', @OrderBySelectColumns;
        $OrderBySelectString = ', ' . $OrderBySelectString;
    }

    # build SQL
    # KIX4OTRS-capeIT
    # my $SQL = 'SELECT DISTINCT(vr.configitem_id) '
    #     . 'FROM configitem ci, configitem_version vr '
    #     . $WhereString;
    my $SQL = 'SELECT DISTINCT(vr.configitem_id) ';
    if (@SQLOrderBy) {
        my $SQLOrderBy = join ', ', @SQLOrderBy;
        $SQLOrderBy =~ s/DESC//;
        $SQLOrderBy =~ s/ASC//;
        $SQL .= ', ' . $SQLOrderBy . ' ';
    }
    $SQL .= 'FROM configitem ci, configitem_version vr '
        . $WhereString;

    # EO KIX4OTRS-capeIT

    # add the ORDER BY clause
    if (@SQLOrderBy) {
        $SQL .= ' ORDER BY ';
        $SQL .= join ', ', @SQLOrderBy;
        $SQL .= ' ';
    }

    # ask the database
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => $SQL,
        Limit => $Param{Limit},
    );

    # fetch the result
    my @ConfigItemList;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push @ConfigItemList, $Row[0];
    }

    return \@ConfigItemList;
}

=begin Internal:

# KIX4OTRS-capeIT

=item _PreEventHandlerForChangedXMLValues()

    my $Events = $CIObject->_PreEventHandlerForChangedXMLValues(
        UpdateValues => HASHRef,
        ConfigItemID => 123,
        UserID => 123,
    );

    print keys %{$Events}; # prints "DeploymentStateUpdate"

=cut

sub _PreEventHandlerForChangedXMLValues {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check needed stuff
    for my $Needed (qw(UpdateValues ConfigItemID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # trigger Pre-ValueUpdate event for each changed value
    for my $Key ( keys %{ $Param{UpdateValues} } ) {
        $Result = $Self->PreEventHandler(
            Event => 'ValueUpdate',
            Data  => {
                ConfigItemID => $Param{ConfigItemID},
                Comment      => $Key . '%%' . $Param{UpdateValues}->{$Key},
            },
            UserID => $Param{UserID},
        );
        if ( ( ref($Result) eq 'HASH' ) && ( $Result->{Error} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Pre-ValueUpdate refused version update.",
            );
            return $Result;
        }
        elsif ( ref($Result) eq 'HASH' ) {
            for my $ResultKey ( keys %{$Result} ) {
                $Param{$ResultKey} = $Result->{$ResultKey};
            }
        }
    }

    return 1;
}

# EO KIX4OTRS-capeIT

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
