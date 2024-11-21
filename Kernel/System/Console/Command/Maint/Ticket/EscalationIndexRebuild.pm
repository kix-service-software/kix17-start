# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::EscalationIndexRebuild;

use strict;
use warnings;

use Time::HiRes();

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Completely rebuild the ticket escalation index.');
    $Self->AddOption(
        Name        => 'micro-sleep',
        Description => "Specify microseconds to sleep after every ticket to reduce system load (e.g. 1000).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Rebuilding ticket escalation index...</yellow>\n");

    # disable ticket events
    $Kernel::OM->Get('Kernel::Config')->{'Ticket::EventModulePost'} = {};

    # get all tickets
    my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Result     => 'ARRAY',
        Limit      => 100_000_000,
        UserID     => 1,
        Permission => 'ro',
    );

    my $Count      = 0;
    my $MicroSleep = $Self->GetOption('micro-sleep');

    TICKETID:
    for my $TicketID (@TicketIDs) {

        $Count++;

        $Kernel::OM->Get('Kernel::System::Ticket')->TicketEscalationIndexBuild(
            TicketID => $TicketID,
            UserID   => 1,
        );

        if ( $Count % 2000 == 0 ) {
            my $Percent = int( $Count / ( $#TicketIDs / 100 ) );
            $Self->Print(
                "<yellow>$Count</yellow> of <yellow>$#TicketIDs</yellow> processed (<yellow>$Percent %</yellow> done).\n"
            );
        }

        Time::HiRes::usleep($MicroSleep) if $MicroSleep;
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
