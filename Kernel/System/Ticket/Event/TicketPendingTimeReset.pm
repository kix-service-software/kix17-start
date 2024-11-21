# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketPendingTimeReset;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::State',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # get needed objects
    my $StateObject  = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get pending states
    my @PendingAutoStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingAuto',
        Result => 'ID',
    );
    my @PendingReminderStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingReminder',
        Result => 'ID',
    );
    my @PendingsStateIDs = (@PendingAutoStateIDs, @PendingReminderStateIDs);

    # get user lock data
    my $TicketFilter = 0;
    if ( @PendingsStateIDs ) {
        $TicketFilter = $TicketObject->TicketSearch(
            Result     => 'COUNT',
            TicketID   => $Param{Data}->{TicketID},
            StateIDs   => \@PendingsStateIDs,
            UserID     => 1,
            Permission => 'ro',
        );
    }

    # only set the pending time to 0 if the new state is NOT a pending state
    return 1 if $TicketFilter;

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 0,
        Silent        => 1,
        UserID        => 1,
    );
    return if ( !%Ticket );

    # only set the pending time to 0 if it's actually set
    return 1 if !$Ticket{UntilTime};

    # reset pending date/time
    return if !$TicketObject->TicketPendingTimeSet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Param{UserID},
        String   => '0000-00-00 00:00:00',
    );

    return 1;
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
