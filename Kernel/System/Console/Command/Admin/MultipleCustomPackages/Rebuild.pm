# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::MultipleCustomPackages::Rebuild;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::KIXUtils',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Rebuild library paths');
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    $Self->Print("<yellow>NOTE: start to rebuild library paths\n\n</yellow>\n");

    $Kernel::OM->Get('Kernel::System::KIXUtils')->RebuildConfig(%Param);

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
