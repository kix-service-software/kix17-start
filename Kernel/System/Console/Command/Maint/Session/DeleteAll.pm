# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Session::DeleteAll;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::AuthSession',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete all sessions.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting all sessions...</yellow>\n");

    for my $SessionID ( $Kernel::OM->Get('Kernel::System::AuthSession')->GetAllSessionIDs() ) {
        my $Success = $Kernel::OM->Get('Kernel::System::AuthSession')->RemoveSessionID(
            SessionID => $SessionID,
        );

        if ( !$Success ) {
            $Self->PrintError("Session $SessionID could not be deleted.");
            return $Self->ExitCodeError();
        }

        $Self->Print("  $SessionID\n");
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
