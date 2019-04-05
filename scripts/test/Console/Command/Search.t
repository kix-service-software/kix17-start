# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Search');

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Search exit code without arguments",
);

# Check command search
my $Result;

{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $CommandObject->Execute('Lis');
}

$Self->Is(
    $ExitCode,
    0,
    "Exit code searching for commands",
);

$Self->False(
    index( $Result, 'kix.Console.pl Help command' ) > -1,
    "Help for 'Help' command not found",
);

$Self->True(
    index( $Result, 'List all installed KIX packages' ) > -1,
    "Found Admin::Package::List command entry",
);

# Check command search (empty)

{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $CommandObject->Execute('NonExistingSearchTerm');
}

$Self->Is(
    $ExitCode,
    0,
    "Exit code searching for commands",
);

$Self->False(
    index( $Result, 'kix.Console.pl Help command' ) > -1,
    "Help for 'Help' command not found",
);

$Self->True(
    index( $Result, 'No commands found.' ) > -1,
    "No commands found.",
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
