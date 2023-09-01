# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Package::ReinstallAll;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Package',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Reinstall all KIX packages that are not correctly deployed.');
    $Self->AddOption(
        Name        => 'force',
        Description => 'Force package reinstallation even if validation fails.',
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Reinstalling all KIX packages that are not correctly deployed...</yellow>\n");

    my @ReinstalledPackages;

    # loop all locally installed packages
    for my $Package ( $Kernel::OM->Get('Kernel::System::Package')->RepositoryList() ) {

        # do a deploy check to see if reinstallation is needed
        my $CorrectlyDeployed = $Kernel::OM->Get('Kernel::System::Package')->DeployCheck(
            Name    => $Package->{Name}->{Content},
            Version => $Package->{Version}->{Content},
        );

        if ( !$CorrectlyDeployed ) {

            push @ReinstalledPackages, $Package->{Name}->{Content};

            my $FileString = $Kernel::OM->Get('Kernel::System::Package')->RepositoryGet(
                Name    => $Package->{Name}->{Content},
                Version => $Package->{Version}->{Content},
            );

            my $Success = $Kernel::OM->Get('Kernel::System::Package')->PackageReinstall(
                String => $FileString,
                Force  => $Self->GetOption('force'),
            );

            if ( !$Success ) {
                $Self->PrintError("Package $Package->{Name}->{Content} could not be reinstalled.\n");
                return $Self->ExitCodeError();
            }
        }
    }

    if (@ReinstalledPackages) {
        $Self->Print( "<green>" . scalar(@ReinstalledPackages) . " package(s) reinstalled.</green>\n" );
    }
    else {
        $Self->Print("<green>No packages needed reinstallation.</green>\n");
    }
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
