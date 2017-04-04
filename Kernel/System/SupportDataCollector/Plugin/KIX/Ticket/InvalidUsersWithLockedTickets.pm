# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::InvalidUsersWithLockedTickets;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my @InvalidUsers;
    $DBObject->Prepare(
        SQL => '
        SELECT DISTINCT(users.login) FROM ticket, users
        WHERE
            ticket.user_id = users.id
            AND ticket.ticket_lock_id = 2
            AND users.valid_id != 1
        '
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @InvalidUsers, $Row[0];
    }

    if (@InvalidUsers) {
        $Self->AddResultWarning(
            Label   => Translatable('Invalid Users with Locked Tickets'),
            Value   => join( "\n", @InvalidUsers ),
            Message => Translatable('There are invalid users with locked tickets.'),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Invalid Users with Locked Tickets'),
            Value => '0',
        );
    }

    return $Self->GetResults();
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
