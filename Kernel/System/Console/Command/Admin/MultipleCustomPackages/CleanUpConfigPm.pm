# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::MultipleCustomPackages::CleanUpConfigPm;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::KIXUtils',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Restore old Config.pm');
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    $Self->Print("<yellow>NOTE: start to restore old 'Config.pm'</yellow>\n");

    $Kernel::OM->Get('Kernel::System::KIXUtils')->CleanUpConfigPm(%Param);

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;

