# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Config::Rebuild;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::SysConfig',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Rebuild the system configuration of OTRS.');

    $Self->AddOption(
        Name        => 'cleanup-user-config',
        Description => "Cleanup the user configuration file ZZZAuto.pm, removing duplicate or obsolete values.",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Rebuilding the system configuration...</yellow>\n");

    if ( !$Kernel::OM->Get('Kernel::System::SysConfig')->WriteDefault() ) {
        $Self->PrintError("There was a problem writing ZZZAAuto.pm.");
        return $Self->ExitCodeError();
    }
    if ( $Self->GetOption('cleanup-user-config') ) {
        if ( !$Kernel::OM->Get('Kernel::System::SysConfig')->CreateConfig() ) {
            $Self->PrintError("There was a problem writing ZZZAuto.pm.");
            return $Self->ExitCodeError();
        }
    }
    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
