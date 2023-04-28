# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::QueueIndexCleanup;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Cleanup unneeded entries from StaticDB queue index.');

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $Module = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::IndexModule');
    if ( $Module =~ m{StaticDB} ) {
        my $Error = "$Module is the active queue index, aborting.\n";
        $Error .= "Use Maint::Ticket::QueueIndexRebuild to regenerate the active index.\n";
        die $Error;
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Cleaning up ticket queue index...</yellow>\n");

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $Records;

    $DBObject->Prepare(
        SQL => 'SELECT count(*) from ticket_index'
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Records += $Row[0];
    }
    $DBObject->Prepare(
        SQL => 'SELECT count(*) from ticket_lock_index'
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Records += $Row[0];
    }

    if ( !$Records ) {
        $Self->Print("<green>Queue index is already clean.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'DELETE FROM ticket_index',
    );

    $DBObject->Do(
        SQL => 'DELETE FROM ticket_lock_index',
    );

    $Self->Print("<green>Done ($Records records deleted).</green>\n");
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
