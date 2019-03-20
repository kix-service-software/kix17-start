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

my %List;
if ( $Kernel::OM->Get('Kernel::Config')->Get('Package::RepositoryList') ) {
    %List = %{ $Kernel::OM->Get('Kernel::Config')->Get('Package::RepositoryList') };
}
%List = ( %List, $Kernel::OM->Get('Kernel::System::Package')->PackageOnlineRepositories() );

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::Package::RepositoryList');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    %List ? 0 : 1,
    "Admin::Package::RepositoryList exit code without arguments",
);

# cleanup cache is done by RestoreDatabase

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
