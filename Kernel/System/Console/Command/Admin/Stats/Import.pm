# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Stats::Import;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Stats',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Install Package Stats');
    $Self->AddOption(
        Name        => 'file-prefix',
        Description => "Name of the file prefix which should be used.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/(.*)/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    # check prefix
    $Self->{FilePrefix} = $Self->GetOption('file-prefix');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Install stats with file prefix $Self->{FilePrefix}...</yellow>\n");

    $Kernel::OM->Get('Kernel::System::Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
