# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

## no critic (Modules::RequireExplicitPackage)
use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::SystemMonitoring::NagiosCheck');

my $ConfigFile = $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/scripts/test/sample/NagiosCheckTesting.pm';

my $ExitCode = $CommandObject->Execute( '--config-file', $ConfigFile, '--as-checker', '--verbose', );

$Self->Is(
    $ExitCode,
    0,
    "Maint::SystemMonitoring::NagiosCheck exit code",
);

1;
