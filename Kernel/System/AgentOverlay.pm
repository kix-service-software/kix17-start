# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AgentOverlay;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::AgentOverlay

=head1 SYNOPSIS

All notificatioin overlay functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AgentOverlayObject = $Kernel::OM->Get('Kernel::System::AgentOverlay');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # setup cache
    $Self->{CacheObject} = $Kernel::OM->Get('Kernel::System::Cache');
    $Self->{CacheTTL}    = 60 * 60 * 24;
    $Self->{CacheType}   = 'AgentOverlay';

    return $Self;
}

=item AgentOverlayList()

return a list of agent overlays as hash (ID => Show)

    my %List = $AgentOverlayObject->AgentOverlayList(
        UserID => $UserID,
    );

=cut

sub AgentOverlayList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # clean decayed overlays
    $Self->_AgentOverlayCleanup();

    # read cache
    my $CacheKey  = 'UserID::' . $Param{UserID};
    my $Cache     = $Self->{CacheObject}->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    return if !$DBObject->Prepare(
        SQL => "SELECT id, popup "
             . "FROM overlay_agent "
             . "WHERE user_id=?",
        Bind => [
            \$Param{UserID},
        ],
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Self->{CacheObject}->Set(
        TTL   => $Self->{CacheTTL},
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Data
    );

    return %Data;
}

=item AgentOverlayAdd()

return 1 if added overlay for agent

    my $Success = $AgentOverlayObject->AgentOverlayAdd(
        Subject => $Subject,
        Message => $Message,
        Decay   => $Decay,
        UserID  => $UserID,
        Popup   => $Popup,      # optional, default 0
    );

=cut

sub AgentOverlayAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Subject Message Decay UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if ( !defined($Param{Popup}) ) {
        $Param{Popup} = 0;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    return if !$DBObject->Do(
        SQL => "INSERT INTO overlay_agent "
            . "(subject, message, decay, user_id, popup)"
            . " VALUES "
            . " (?, ?, ?, ?, ?)",
        Bind => [
            \$Param{Subject}, \$Param{Message}, \$Param{Decay}, \$Param{UserID}, \$Param{Popup},
        ],
    );

    # delete cache
    $Self->{CacheObject}->Delete(
        Type => $Self->{CacheType},
        Key  => 'UserID::' . $Param{UserID},
    );

    return 1;
}

=item AgentOverlaySeen()

return 1 if marked as seen

    my $Success = $AgentOverlayObject->AgentOverlaySeen(
        OverlayID => $OverlayID,
        UserID    => $UserID,
    );

=cut

sub AgentOverlaySeen {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(OverlayID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    return if !$DBObject->Do(
        SQL => "UPDATE overlay_agent "
             . "SET popup = 0 "
             . "WHERE id = ? "
             . "AND user_id = ?",
        Bind => [
            \$Param{OverlayID}, \$Param{UserID},
        ],
    );

    # delete cache
    $Self->{CacheObject}->Delete(
        Type => $Self->{CacheType},
        Key  => 'UserID::' . $Param{UserID},
    );

    return 1;
}

=item AgentOverlayGet()

return an overlay entry as hash

    my %Overlay = $AgentOverlayObject->AgentOverlayGet(
        OverlayID => $OverlayID,
    );

=cut

sub AgentOverlayGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{OverlayID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need OverlayID!',
        );
        return;
    }

    # read cache
    my $CacheKey  = 'OverlayID::' . $Param{OverlayID};
    my $Cache    = $Self->{CacheObject}->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    return if !$DBObject->Prepare(
        SQL => "SELECT subject, message, decay "
             . "FROM overlay_agent "
             . "WHERE id=?",
        Bind => [
            \$Param{OverlayID},
        ],
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ 'Subject' } = $Row[0];
        $Data{ 'Message' } = $Row[1];
        $Data{ 'Decay' }   = $Row[2];
    }

    # set cache
    $Self->{CacheObject}->Set(
        TTL   => $Self->{CacheTTL},
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Data
    );

    return %Data;
}

## internal function

sub _AgentOverlayCleanup {
    my ( $Self, %Param ) = @_;

    # get time
    my $Time = $Kernel::OM->Get('Kernel::System::Time')->SystemTime();

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    return if !$DBObject->Prepare(
        SQL => "SELECT id, user_id "
             . "FROM overlay_agent "
             . "WHERE decay<?",
        Bind => [
            \$Time,
        ],
    );

    my %OverlayList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $OverlayList{ $Row[0] } = $Row[1];
    }

    for my $OverlayID ( keys(%OverlayList) ) {

        # delete overlay
        return if !$DBObject->Do(
            SQL  => 'DELETE FROM overlay_agent WHERE id = ?',
            Bind => [ \$OverlayID ],
        );

        # delete cache
        $Self->{CacheObject}->Delete(
            Type => $Self->{CacheType},
            Key  => 'OverlayID::' . $OverlayID,
        );
        $Self->{CacheObject}->Delete(
            Type => $Self->{CacheType},
            Key  => 'UserID::' . $OverlayList{$OverlayID},
        );
    }

    return 1;
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
