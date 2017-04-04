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

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Dev::Package::RepositoryIndex');

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Dev::Package::RepositoryIndex exit code without arguments",
);

my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

my $Result;
{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $CommandObject->Execute("$Home/Kernel/Config/Files");
}

$Self->Is(
    $ExitCode,
    0,
    "Dev::Package::RepositoryIndex exit code",
);

$Self->Is(
    $Result,
    '<?xml version="1.0" encoding="utf-8" ?>
<otrs_package_list version="1.0">
</otrs_package_list>
',
    "Dev::Package::RepositoryIndex result for empty directory",
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
