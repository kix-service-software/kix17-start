# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::PostMaster::Read');

my ( $ExitCode, $Result );

{
    local *STDIN;
    open STDIN, '<:utf8', \'';    ## no critic
    $ExitCode = $CommandObject->Execute();
}

$Self->Is(
    $ExitCode,
    1,
    "Maint::PostMaster::Read exit code without email input",
);

{
    my $Email = "From: me\@home.com\nTo: you\@home.com\nSubject: Test\nUnit tests rock.\n";
    local *STDIN;
    open STDIN, '<:utf8', \$Email;    ## no critic
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $CommandObject->Execute('--debug');
}

$Self->Is(
    $ExitCode,
    0,
    "Maint::PostMaster::Read exit code with email input",
);

my ($TicketID) = $Result =~ m{TicketID:\s+(\d+)};

$Self->True(
    $TicketID,
    'Ticket created from email',
);

# cleanup is done by RestoreDatabase

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
