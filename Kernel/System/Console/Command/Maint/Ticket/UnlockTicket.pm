# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::UnlockTicket;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Unlock a single ticket by force.');
    $Self->AddArgument(
        Name        => 'ticket-id',
        Description => "Ticket to be unlocked by force.",
        Required    => 1,
        ValueRegex  => qr/\d+/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $TicketID = $Self->GetArgument('ticket-id');

    $Self->Print("<yellow>Unlocking ticket $TicketID...</yellow>\n");

    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID => $TicketID,
        Silent   => 1,
    );

    if ( !%Ticket ) {
        $Self->PrintError("Could not find ticket $TicketID.");
        return $Self->ExitCodeError();
    }

    my $Unlock = $Kernel::OM->Get('Kernel::System::Ticket')->TicketLockSet(
        TicketID => $TicketID,
        Lock     => 'unlock',
        UserID   => 1,
    );
    if ( !$Unlock ) {
        $Self->PrintError('Failed.');
        return $Self->ExitCodeError();
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
