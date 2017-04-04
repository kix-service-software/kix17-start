# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::LinkGraph;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::LinkGraph

=head1 SYNOPSIS

graph visualization backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a LinkGraph object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LinkGraphObject = $Kernel::OM->Get('Kernel::System::LinkGraphField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{DBObject}   = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{LogObject}  = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TimeObject} = $Kernel::OM->Get('Kernel::System::Time');
    return $Self;
}

=item SaveGraph()

Saves the graph into the database

    my $Graph = $LinkGraphObject->SaveGraph(
        LayoutString  => $LayoutString e.g. "ITSMConfigItem-3::691::96_-_ITSMConfigItem-1::29::274",
        GraphConfig   => $GraphConfig e.g. "1:::AlternativeTo,Includes:::2:::22,23",
        GraphName     => $GraphName,
        CurID         => $CurID,
        UserID        => $UserID
        ObjectType    => $ObjectType
    );

    returns

    $Graph = {
        ID              => 1,
        LastChangedTime => Timestamp
    };

=cut

sub SaveGraph {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(LayoutString GraphConfig CurID GraphName UserID ObjectType)) {
        if ( !$Param{$Key} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Kernel::System::LinkGraph::SaveGraph: Need $Key!"
            );
            return;
        }
    }

    # do insert
    if (
        !$Self->{DBObject}->Do(
            SQL => '
            INSERT INTO kix_link_graph ( name, object_id, object_type, layout, config, create_time, create_by, change_time, change_by )
            VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [
                \$Param{GraphName}, \$Param{CurID}, \$Param{ObjectType}, \$Param{LayoutString},
                \$Param{GraphConfig},
                \$Param{UserID}, \$Param{UserID}
            ],
        )
        )
    {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Could not save Graph $Param{GraphName}!",
        );
        return;
    }

    # get inserted id and change time
    my %Graph;
    if (
        !$Self->{DBObject}->Prepare(
            SQL =>
                'SELECT id, change_time FROM kix_link_graph WHERE object_id = ? AND object_type = ?',
            Bind => [ \$Param{CurID}, \$Param{ObjectType} ],
            Limit => 1,
        )
        )
    {
        $Self->{LogObject}
            ->Log(
            Priority => 'error',
            Message =>
                "Could not get ID and change_time of saved graph $Param{GraphName} for object '$Param{ObjectType}'!",
            );
        $Graph{ID} = 'NoID';
        return \%Graph;
    }

    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Graph{ID}              = $Row[0];
        $Graph{LastChangedTime} = $Row[1];
    }

    return \%Graph;
}

=item GetSavedGraphs()

Gets the saved the graph back from the database

    my %Graphs = $LinkGraphObject->GetSavedGraphs(
        ObjectType    => $ObjectType,
        CurID         => $CurID,
    );

    returns

    %Graphs = {
        Name            => GraphA,
        ConfigString    => config as string e.g. "1:::AlternativeTo,Includes:::2:::22,23",
        Layout          => layout as string e.g. "ITSMConfigItem-3::691::96_-_ITSMConfigItem-1::29::274",
        LastChangedTime => Timestamp,
        LastChangedBy   => 1,
    };

=cut

sub GetSavedGraphs {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(CurID ObjectType)) {
        if ( !$Param{$Key} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Kernel::System::LinkGraph::GetSavedGraphs: Need $Key!"
            );
            return;
        }
    }

    return if !$Self->{DBObject}->Prepare(
        SQL =>
            'SELECT id, name, config, layout, change_time, change_by FROM kix_link_graph WHERE object_id = ? AND object_type = ?',
        Bind => [ \$Param{CurID}, \$Param{ObjectType} ],
    );

    my %Graphs;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Graphs{ $Row[0] } = {
            Name            => $Row[1],
            ConfigString    => $Row[2],
            Layout          => $Row[3],
            LastChangedTime => $Row[4],
            LastChangedBy   => $Row[5],
        };
    }

    return %Graphs;
}

=item UpdateGraph()

Updates the graph

    my $Graph = $LinkGraphObject->UpdateGraph(
        LayoutString  => $LayoutString e.g. "ITSMConfigItem-3::691::96_-_ITSMConfigItem-1::29::274",
        GraphConfig   => $GraphConfig e.g. "1:::AlternativeTo,Includes:::2:::22,23",
        UserID        => $UserID,
        GraphID       => $GraphID
    );

    returns

    $Graph = {
        ID              => 1,
        LastChangedTime => Timestamp
    };
=cut

sub UpdateGraph {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(LayoutString GraphConfig GraphID UserID)) {
        if ( !$Param{$Key} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Kernel::System::LinkGraph::UpdateGraph: Need $Key!"
            );
            return;
        }
    }

    # get timestamp, so that a select on table is not necessary
    my $Timestamp = $Self->{TimeObject}->CurrentTimestamp();

    # do update
    if (
        !$Self->{DBObject}->Do(
            SQL =>
                'UPDATE kix_link_graph SET layout = ?, config = ?, change_time = ?, change_by = ? WHERE id = ?',
            Bind =>
                [
                \$Param{LayoutString}, \$Param{GraphConfig}, \$Timestamp,
                \$Param{UserID}, \$Param{GraphID},
                ],
        )
        )
    {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'Could not update saved graph!' );
        return;
    }

    my %Graph = (
        'ID'              => $Param{GraphID},
        'LastChangedTime' => $Timestamp,
    );

    return \%Graph;
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
