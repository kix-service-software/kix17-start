# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::PostMaster;

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

$Kernel::OM->Get('Kernel::System::Type')->TypeAdd(
#rbo - T2016121190001552 - renamed X-KIX headers
    Name    => "X-KIX-Type-Test",
    ValidID => 1,
    UserID  => 1,
);

# filter test
my @Tests = (
    {
        Name  => 'Valid ticket type (Unclassified)',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
X-KIX-Type: Unclassified
Subject: Test

Some Content in Body',
        NewTicket => 1,
        Check     => {
            Type => 'Unclassified',
            }
    },
    {
        Name  => 'Valid ticket type (Unclassified)',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
X-KIX-Type: X-KIX-Type-Test
Subject: Test

Some Content in Body',
        NewTicket => 1,
        Check     => {
            Type => 'X-KIX-Type-Test',
            }
    },
    {
        Name  => 'Invalid ticket type, ticket still needs to be created',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
X-KIX-Type: Nonexisting
Subject: Test

Some Content in Body',
        NewTicket => 1,
        Check     => {
            Type => 'Unclassified',
            }
    },
);

for my $Test (@Tests) {

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Test->{Email},
            Debug => 2,
        );

        @Return = $PostMasterObject->Run();
    }
    $Self->Is(
        $Return[0] || 0,
        $Test->{NewTicket},
        "#Filter Run() - NewTicket",
    );
    $Self->True(
        $Return[1] || 0,
        "#Filter  Run() - NewTicket/TicketID",
    );
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{Check} } ) {
        $Self->Is(
            $Ticket{$Key},
            $Test->{Check}->{$Key},
            "#Filter Run() - $Key",
        );
    }
}

# cleanup is done by RestoreDatabase.

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
