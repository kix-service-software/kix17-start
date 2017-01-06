# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::OpenTickets;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $OpenTickets = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Result     => 'COUNT',
        StateType  => 'Open',
        UserID     => 1,
        Permission => 'ro',
    );

    if ( $OpenTickets > 8000 ) {
        $Self->AddResultWarning(
            Label   => Translatable('Open Tickets'),
            Value   => $OpenTickets,
            Message => Translatable('You should not have more than 8,000 open tickets in your system.'),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Open Tickets'),
            Value => $OpenTickets,
        );
    }

    return $Self->GetResults();
}

1;
