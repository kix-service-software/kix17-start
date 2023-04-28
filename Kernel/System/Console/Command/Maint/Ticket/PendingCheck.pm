# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::PendingCheck;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::User',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Process pending tickets that are past their pending time and send pending reminders.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Process pending tickets...</yellow>\n");

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $StateObject  = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');

    my @TicketIDs;

    # get pending states
    my @PendingAutoStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingAuto',
        Result => 'ID',
    );
    my @PendingReminderStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingReminder',
        Result => 'ID',
    );

    if (@PendingAutoStateIDs) {

        # do ticket auto jobs
        @TicketIDs = $TicketObject->TicketSearch(
            Result   => 'ARRAY',
            StateIDs => \@PendingAutoStateIDs,
            UserID   => 1,
        );

        my %States = %{ $ConfigObject->Get('Ticket::StateAfterPending') };

        TICKETID:
        for my $TicketID (@TicketIDs) {

            # get ticket data
            my %Ticket = $TicketObject->TicketGet(
                TicketID      => $TicketID,
                UserID        => 1,
                DynamicFields => 0,
            );

            next TICKETID if $Ticket{UntilTime} >= 1;

            my $NextState;
            if (
                $States{ $Ticket{Type} . ':::' . $Ticket{State} }
                || $States{ $Ticket{State} }
            ) {
                $NextState = $States{ $Ticket{Type} . ':::' . $Ticket{State} } || $States{ $Ticket{State} };
            }

            next TICKETID if ( !$NextState );

            $Self->Print(
                " Update ticket state for ticket $Ticket{TicketNumber} ($TicketID) to '$NextState'..."
            );

            # set new state
            my $NewStateID = $TicketObject->TicketStateSet(
                TicketID => $TicketID,
                State    => $NextState,
                UserID   => 1,
            );

            # error handling
            if ( !$NewStateID ) {
                $Self->Print(" failed.\n");
                next TICKETID;
            }

            # get state type for new state
            my %State = $StateObject->StateGet(
                ID => $NewStateID,
            );
            if ( $State{TypeName} eq 'closed' ) {

                # set new ticket lock
                $TicketObject->TicketLockSet(
                    TicketID     => $TicketID,
                    Lock         => 'unlock',
                    UserID       => 1,
                    Notification => 0,
                );
            }
            $Self->Print(" done.\n");
        }
    }
    else {
        $Self->Print(" No pending auto StateIDs found!\n");
    }

    if (@PendingReminderStateIDs) {
        # do ticket reminder notification jobs
        @TicketIDs = $TicketObject->TicketSearch(
            Result   => 'ARRAY',
            StateIDs => \@PendingReminderStateIDs,
            UserID   => 1,
        );

        TICKETID:
        for my $TicketID (@TicketIDs) {

            # get ticket data
            my %Ticket = $TicketObject->TicketGet(
                TicketID      => $TicketID,
                UserID        => 1,
                DynamicFields => 0,
            );

            next TICKETID if $Ticket{UntilTime} >= 1;

            # get used calendar
            my $Calendar = $TicketObject->TicketCalendarGet(
                %Ticket,
            );

            # check if it is during business hours, then send reminder
            my $CountedTime = $TimeObject->WorkingTime(
                StartTime => $TimeObject->SystemTime() - ( 10 * 60 ),
                StopTime  => $TimeObject->SystemTime(),
                Calendar  => $Calendar,
            );

            # error handling
            if ( !$CountedTime ) {
                next TICKETID;
            }

            # trigger notification event
            $TicketObject->EventHandler(
                Event => 'NotificationPendingReminder',
                Data  => {
                    TicketID              => $Ticket{TicketID},
                    CustomerMessageParams => {
                        TicketNumber => $Ticket{TicketNumber},
                    },
                },
                UserID => 1,
            );
        }
    }
    else {
        $Self->Print(" No pending reminder StateIDs found!\n");
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
