# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketQueueMoveWorkflowState;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}        = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}           = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}        = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    for (qw(Event Config UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( !$Param{Data}->{TicketID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get ticket data...
    my %TicketData = $Self->{TicketObject}->TicketGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => 1,
    );

    if ( !scalar( keys(%TicketData) ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event TicketQueueMoveWorkflowState: "
                . "no ticket data for ID <"
                . $Param{Data}->{TicketID}
                . ">!",
        );
        return 1;
    }

    # get config
    my $SetMode = $Self->{ConfigObject}->Get('Ticket::TicketQueueMoveWorkflowState');
    my $SetModeExtended
        = $Self->{ConfigObject}->Get('Ticket::TicketQueueMoveWorkflowStateExtension');
    if ( defined $SetModeExtended && ref $SetModeExtended eq 'HASH' ) {
        for my $Extension ( sort keys %{$SetModeExtended} ) {
            for my $QueueType ( keys %{ $SetModeExtended->{$Extension} } ) {
                $SetMode->{$QueueType} = $SetModeExtended->{$Extension}->{$QueueType};
            }
        }
    }

    # get new state from config hash
    my $NewState;
    if ( $SetMode && ref $SetMode eq 'HASH' ) {
        for my $QueueTicketType ( keys %{$SetMode} ) {
            next if $QueueTicketType !~ m/^$TicketData{Queue}:::$TicketData{Type}$/i;
            $NewState = $SetMode->{$QueueTicketType};
        }
    }

    # if workflow found
    if ( defined $NewState && $NewState ) {

        # get ticket state list
        my %NextStates = $Self->{TicketObject}->TicketStateList(
            TicketID => $TicketData{TicketID},
            UserID   => 1,
        );

        # check if given state is valid
        my $CurrentStateIsValid = 0;
        for my $StateValid (%NextStates) {
            next if $NewState !~ m/^$StateValid$/i;
            $CurrentStateIsValid = 1;
        }

        # set new ticket state
        if ($CurrentStateIsValid) {
            $Self->{TicketObject}->TicketStateSet(
                TicketID           => $Param{Data}->{TicketID},
                State              => $NewState,
                SendNoNotification => 1,
                UserID             => 1,
            );
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event TicketQueueMoveWorkflowState: new state not valid!",
            );
        }
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
