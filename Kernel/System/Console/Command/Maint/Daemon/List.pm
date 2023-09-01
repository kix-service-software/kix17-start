# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Daemon::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List available daemons.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing system daemons...</yellow>\n");

    # get daemon modules from SysConfig
    my $DaemonModuleConfig = $Kernel::OM->Get('Kernel::Config')->Get('DaemonModules') || {};

    MODULE:
    for my $Module ( sort keys %{$DaemonModuleConfig} ) {

        # skip not well configured modules
        next MODULE if !$Module;
        next MODULE if !$DaemonModuleConfig->{$Module};
        next MODULE if ref $DaemonModuleConfig->{$Module} ne 'HASH';
        next MODULE if !$DaemonModuleConfig->{$Module}->{Module};

        my $DaemonObject;

        # create daemon object
        eval {
            $DaemonObject = $Kernel::OM->Get( $DaemonModuleConfig->{$Module}->{Module} );
        };

        # skip module if object could not be created or does not provide the needed methods()
        next MODULE if !$DaemonObject;
        next MODULE if !$DaemonObject->can("PreRun");
        next MODULE if !$DaemonObject->can("Run");
        next MODULE if !$DaemonObject->can("PostRun");

        $Self->Print("  $Module\n");
    }

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
