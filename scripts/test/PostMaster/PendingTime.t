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
my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

$Helper->FixedTimeSet();

my %NeededXHeaders = (
#rbo - T2016121190001552 - renamed X-KIX headers
    'X-KIX-PendingTime'          => 1,
    'X-KIX-FollowUp-PendingTime' => 1,
);

my $XHeaders          = $ConfigObject->Get('PostmasterX-Header');
my @PostmasterXHeader = @{$XHeaders};
HEADER:
for my $Header ( sort keys %NeededXHeaders ) {
    next HEADER if ( grep $_ eq $Header, @PostmasterXHeader );
    push @PostmasterXHeader, $Header;
}
$ConfigObject->Set(
    Key   => 'PostmasterX-Header',
    Value => \@PostmasterXHeader
);

# filter test
my @Tests = (
    {
        Name  => 'Regular pending time test',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '2021-01-01 00:00:00',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '2022-01-01 00:00:00',
        },
        CheckNewTicket => {
            RealTillTimeNotUsed => $TimeObject->TimeStamp2SystemTime(
                String => '2021-01-01 00:00:00'
            ),
        },
        CheckFollowUp => {
            RealTillTimeNotUsed => $TimeObject->TimeStamp2SystemTime(
                String => '2022-01-01 00:00:00'
            ),
        },
    },
    {
        Name  => 'Regular pending time test, wrong date',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '2022-01- 00:00:00',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '2022-01- 00:00:00',
        },
        CheckNewTicket => {
            RealTillTimeNotUsed => 0,
        },
        CheckFollowUp => {
            RealTillTimeNotUsed => 0,
        },
    },
    {
        Name  => 'Relative pending time test seconds',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60s',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30s',
        },
        CheckNewTicket => {
            UntilTime => 60,
        },
        CheckFollowUp => {
            UntilTime => 30,
        },
    },
    {
        Name  => 'Relative pending time test implicit seconds',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30',
        },
        CheckNewTicket => {
            UntilTime => 60,
        },
        CheckFollowUp => {
            UntilTime => 30,
        },
    },
    {
        Name  => 'Relative pending time test implicit seconds no sign',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '60',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '30',
        },
        CheckNewTicket => {
            UntilTime => 60,
        },
        CheckFollowUp => {
            UntilTime => 30,
        },
    },
    {
        Name  => 'Relative pending time test minutes',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60m',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30m',
        },
        CheckNewTicket => {
            UntilTime => 60 * 60,
        },
        CheckFollowUp => {
            UntilTime => 30 * 60,
        },
    },
    {
        Name  => 'Relative pending time test hours',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60h',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30h',
        },
        CheckNewTicket => {
            UntilTime => 60 * 60 * 60,
        },
        CheckFollowUp => {
            UntilTime => 30 * 60 * 60,
        },
    },
    {
        Name  => 'Relative pending time test days',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60d',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30d',
        },
        CheckNewTicket => {
            UntilTime => 60 * 60 * 60 * 24,
        },
        CheckFollowUp => {
            UntilTime => 30 * 60 * 60 * 24,
        },
    },
    {
        Name  => 'Relative pending time test, invalid unit',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+30y',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30y',
        },
        CheckNewTicket => {
            UntilTime => 0,
        },
        CheckFollowUp => {
            UntilTime => 0,
        },
    },
    {
        Name  => 'Relative pending time test, invalid unit',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+30y',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30y',
        },
        CheckNewTicket => {
            UntilTime => 0,
        },
        CheckFollowUp => {
            UntilTime => 0,
        },
    },
    {
        Name  => 'Relative pending time test, invalid combination',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
#rbo - T2016121190001552 - renamed X-KIX headers
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+30s +30m',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30s +30m',
        },
        CheckNewTicket => {
            UntilTime => 0,
        },
        CheckFollowUp => {
            UntilTime => 0,
        },
    },
);

for my $Test (@Tests) {

    $ConfigObject->Set(
        Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
        Value => {
            %{$Test},
            Module => 'Kernel::System::PostMaster::Filter::Match',
        },
    );

    my $Email = 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: some subject

Some Content in Body
';

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Email,
        );

        @Return = $PostMasterObject->Run();
    }
    $Self->Is(
        $Return[0] || 0,
        1,
        "$Test->{Name} - Create new ticket",
    );

    $Self->True(
        $Return[1] || 0,
        "$Test->{Name} - Create new ticket (TicketID)",
    );

    my $TicketID = $Return[1];

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{CheckNewTicket} } ) {
        $Self->Is(
            $Ticket{$Key},
            $Test->{CheckNewTicket}->{$Key},
            "$Test->{Name} - NewTicket - Check result value $Key",
        );
    }

    my $Subject = 'Subject: ' . $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => 'test',
    );

    my $Email2 = "From: Sender <sender\@example.com>
To: Some Name <recipient\@example.com>
$Subject

Some Content in Body
";

    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Email2,
        );

        @Return = $PostMasterObject->Run();
    }

    $Self->Is(
        $Return[0] || 0,
        2,
        "$Test->{Name} - Create follow up ticket",
    );
    $Self->True(
        $Return[1] || 0,
        "$Test->{Name} - Create follow up ticket (TicketID)",
    );
    $Self->Is(
        $Return[1],
        $TicketID,
        "$Test->{Name} - Create follow up ticket (TicketID of original ticket)",
    );

    %Ticket = $TicketObject->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{CheckFollowUp} } ) {
        $Self->Is(
            $Ticket{$Key},
            $Test->{CheckFollowUp}->{$Key},
            "$Test->{Name} - FollowUp - Check result value $Key",
        );
    }

    $ConfigObject->Set(
        Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
        Value => undef,
    );
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
