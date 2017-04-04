# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketStateWorkflowAutomaticStateAction;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::SLA',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
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
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{QueueObject}  = $Kernel::OM->Get('Kernel::System::Queue');
    $Self->{SLAObject}    = $Kernel::OM->Get('Kernel::System::SLA');
    $Self->{StateObject}  = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{TimeObject}   = $Kernel::OM->Get('Kernel::System::Time');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $ArticleFreeKey;
    my $ArticleFreeText;

    # check needed stuff
    for (qw(Event Config)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # ensure it's a ticket state event or ticket creation...
    if ( $Param{Event} ne 'TicketStateUpdate' && $Param{Event} ne 'TicketCreate' ) {
        return;
    }

    if ( !$Param{Data}->{TicketID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need TicketID!"
        );
        return;
    }

    # get configuration...
    my $WFConfigRef = $Self->{ConfigObject}->Get('TicketStateWorkflowAutomaticStateAction');
    my $WFConfigRefExtended
        = $Self->{ConfigObject}->Get('TicketStateWorkflowAutomaticStateActionExtension');

    if ( defined $WFConfigRefExtended && ref $WFConfigRefExtended eq 'HASH' ) {
        for my $Extension ( sort keys %{$WFConfigRefExtended} ) {
            for my $ConfigOption (qw(NextStateSet QueueMove NextStatePendingOffset)) {
                for my $Item ( keys %{ $WFConfigRefExtended->{$Extension}->{$ConfigOption} } ) {
                    $WFConfigRef->{$ConfigOption}->{$Item}
                        = $WFConfigRefExtended->{$Extension}->{$ConfigOption}->{$Item};
                }
            }
        }
    }

    if ( !$WFConfigRef || ( ref($WFConfigRef) ne 'HASH' ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event::TicketStateWorkflowAutomaticStateAction "
                . "- no configuration found."
        );
        return;
    }

    # get ticket data...
    my %Ticket = $Self->{TicketObject}->TicketGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => 1,
    );

    if ( !%Ticket ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event::TicketStateWorkflowAutomaticStateAction "
                . "- no ticket data found "
                . "for ID $Param{Data}->{TicketID}."
        );
        return;
    }

    if ( !$Ticket{State} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Event::TicketStateWorkflowAutomaticStateAction "
                . "- no ticket state found "
                . "for ID $Param{Data}->{TicketID}."
        );
        return;
    }

    $Ticket{Calendar} = "";

    if ( $Ticket{SLAID} ) {
        my %SLA = $Self->{SLAObject}->SLAGet(
            SLAID  => $Ticket{SLAID},
            UserID => 1,
        );
        if ( $SLA{Calendar} ) {
            $Ticket{Calendar} = $SLA{Calendar};
        }
    }

    if ( !$Ticket{Calendar} && $Ticket{QueueID} ) {
        my %Queue = $Self->{QueueObject}->QueueGet(
            ID => $Ticket{QueueID},
        );
        if ( $Queue{Calendar} ) {
            $Ticket{Calendar} = $Queue{Calendar};
        }
    }

    # do automatic QueueMove
    if (
        $WFConfigRef->{QueueMove}
        && ( ref( $WFConfigRef->{QueueMove} ) eq 'HASH' )
        && (
            $WFConfigRef->{QueueMove}->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $WFConfigRef->{QueueMove}->{ $Ticket{State} }
        )
        )
    {
        my $NextQueueName = $WFConfigRef->{QueueMove}->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $WFConfigRef->{QueueMove}->{ $Ticket{State} };
        my @SingleQueueNames = split( /::/, $NextQueueName );
        my $Index = 0;

        #check and replace placeholders...
        for my $QueueNamePart (@SingleQueueNames) {
#rbo - T2016121190001552 - added KIX placeholders
            $QueueNamePart =~ s/<(KIX|OTRS)_Ticket_(.+)>/$Ticket{$2}/e;
            $SingleQueueNames[$Index] = $QueueNamePart;
            $Index++;
        }

        $NextQueueName = join( '::', @SingleQueueNames );

        my $NextQueueID = $Self->{QueueObject}->QueueLookup( Queue => $NextQueueName );
        if ($NextQueueID) {
            $Self->{TicketObject}->TicketQueueSet(
                QueueID  => $NextQueueID,
                TicketID => $Param{Data}->{TicketID},
                UserID   => 1,
            );
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event::TicketStateWorkflowAutomaticStateAction "
                    . "- configured queue "
                    . "<$NextQueueName> does not exist or is invalid (ticketID <$Param{Data}->{TicketID}>)."
            );

            # set configured fallback queue
            if (
                $WFConfigRef->{FallbackOnErrorQueue}
                && $WFConfigRef->{FallbackOnErrorQueue} ne ''
                )
            {
                my $NextQueueID = $Self->{QueueObject}
                    ->QueueLookup( Queue => $WFConfigRef->{FallbackOnErrorQueue} );
                if ($NextQueueID) {
                    $Self->{TicketObject}->MoveTicket(
                        QueueID  => $NextQueueID,
                        TicketID => $Param{Data}->{TicketID},
                        UserID   => 1,
                    );
                }
            }

            # set configured fallback state
            if (
                $WFConfigRef->{FallbackOnErrorState}
                && $WFConfigRef->{FallbackOnErrorState} ne ''
                )
            {
                my %NextState = $Self->{StateObject}
                    ->StateGet( Name => $WFConfigRef->{FallbackOnErrorState} );
                if ( $NextState{ID} ) {
                    $Self->{TicketObject}->StateSet(
                        StateID  => $NextState{ID},
                        TicketID => $Param{Data}->{TicketID},
                        UserID   => 1,
                    );
                }
            }

            # add system notice to inform agents about this failure
            if ( $WFConfigRef->{FallbackOnErrorNote} ) {
                $Self->{TicketObject}->ArticleCreate(
                    TicketID    => $Param{Data}->{TicketID},
                    ArticleType => 'note-internal',
                    SenderType  => 'system',
                    From        => 'KIX4OTRS Systeminformation',
                    Subject     => 'Automatic move failed due to a misconfiguration.',
                    Body        => 'Hello,

due to a misconfiguration in your system, the automatic queue move could not succed.
You\'ve decided to move this ticket to "'
                        . $NextQueueName
                        . '". But this queue does not exists.

Have you forgotten to set required fields? Otherwhise please contact your admin.


Furthermore this ticket has been moved to "'
                        . ( $WFConfigRef->{FallbackOnErrorQueue} || $Ticket{Queue} )
                        . '" with ticket state "'
                        . ( $WFConfigRef->{FallbackOnErrorState} || $Ticket{State} )
                        . '".'
                    ,
                    UserID      => 1,
                    HistoryType => 'SystemRequest',
                    HistoryComment =>
                        'Added failure notice for AutomaticStateAction due to misconfiguration.',
                    NoAgentNotify => 0,
                );
            }

            return 1;
        }
    }

    # do automatic NextStateSet...
    if (
        $WFConfigRef->{NextStateSet}
        && ( ref( $WFConfigRef->{NextStateSet} ) eq 'HASH' )
        && (
            $WFConfigRef->{NextStateSet}->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $WFConfigRef->{NextStateSet}->{ $Ticket{State} }

        )
        )
    {
        my $NextStateName = $WFConfigRef->{NextStateSet}->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $WFConfigRef->{NextStateSet}->{ $Ticket{State} };
        my %NextState = $Self->{StateObject}->StateGet( Name => $NextStateName );

        my $TimeOffSet =
            $WFConfigRef->{NextStatePendingOffset}->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $WFConfigRef->{NextStatePendingOffset}->{ $Ticket{State} } || 0;

        if ( $NextState{ID} ) {

            # check if it's a pending state...
            my $PendingTimeStamp = 0;
            my %PendingStateHash = $Self->{StateObject}->StateGetStatesByType(
                StateType => [ 'pending reminder', 'pending auto' ],
                Result => 'HASH',
            );
            if ( $PendingStateHash{ $NextState{ID} } ) {
                my $DestinationTime = $Self->{TimeObject}->DestinationTime(
                    StartTime => $Self->{TimeObject}->SystemTime(),
                    Time      => 60 * $TimeOffSet,
                    Calendar  => $Ticket{Calendar} || '',
                );
                $PendingTimeStamp = $Self->{TimeObject}->SystemTime2TimeStamp(
                    SystemTime => $DestinationTime,
                );
            }

            # set new state...
            my $StateSet = $Self->{TicketObject}->StateSet(
                StateID  => $NextState{ID},
                TicketID => $Param{Data}->{TicketID},
                UserID   => 1,
            );

            # set pending time if necessary...
            if ( $StateSet && $PendingTimeStamp ) {
                $Self->{TicketObject}->TicketPendingTimeSet(
                    String   => $PendingTimeStamp,
                    TicketID => $Param{Data}->{TicketID},
                    UserID   => 1,
                );
            }
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event::TicketStateWorkflowAutomaticStateAction "
                    . "- configured NextState "
                    . "<$NextStateName> does not exist or is invalid (ticketID <$Param{Data}->{TicketID}>)."
            );
        }
    }

    #check for <NOT DEFINED ACTION>...

    return 1;
}

# --
1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
