# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::Log::Print');
my $LogObject     = $Kernel::OM->Get('Kernel::System::Log');

$LogObject->CleanUp();

my ( $Result, $ExitCode );
{
    local *STDOUT;
    open STDOUT, '>:encoding(UTF-8)', \$Result;
    $ExitCode = $CommandObject->Execute();
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$Result );
}

$LogObject->Log(
    Priority => 'error',
    Message  => 'test',
);

$Self->Is(
    $ExitCode,
    0,
    "Exit code for log output",
);

$Self->Is(
    $Result // '',
    '',
    "Log output empty",
);

{
    local *STDOUT;
    open STDOUT, '>:encoding(UTF-8)', \$Result;
    $ExitCode = $CommandObject->Execute();
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$Result );
}

$Self->Is(
    $ExitCode,
    0,
    "Exit code for log output",
);

$Self->True(
    index( $Result, ';test' ) > -1,
    "Test string found in log",
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
