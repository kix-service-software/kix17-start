# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::MultipleCustomPackages::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::KIXUtils',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List all custom packages.');
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    $Self->Print(
        "<yellow>NOTE: The following packages are currently registered and should "
            . "appear in Config.pm and apache2-perl-startup.pl:</yellow>\n"
    );

    my $RegisteredPackages
        = $Kernel::OM->Get('Kernel::System::KIXUtils')->GetRegisteredCustomPackages(%Param);
    for my $CurrPrioKey ( sort( keys( %{$RegisteredPackages} ) ) ) {
        print "\n\t " . $CurrPrioKey;
    }
    print "\n\n";

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
