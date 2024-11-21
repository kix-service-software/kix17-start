# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::StaticDBOrphanedRecords;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $Module = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::IndexModule');

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( $Module !~ /StaticDB/ ) {

        my ( $OrphanedTicketLockIndex, $OrphanedTicketIndex );

        $DBObject->Prepare( SQL => 'SELECT count(*) from ticket_lock_index' );
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $OrphanedTicketLockIndex = $Row[0];
        }

        if ($OrphanedTicketLockIndex) {
            $Self->AddResultWarning(
                Identifier => 'TicketLockIndex',
                Label      => Translatable('Orphaned Records In ticket_lock_index Table'),
                Value      => $OrphanedTicketLockIndex,
                Message =>
                    Translatable(
                    'Table ticket_lock_index contains orphaned records. Please run bin/kix.Console.pl "Maint::Ticket::QueueIndexCleanup" to clean the StaticDB index.'
                    ),
            );
        }
        else {
            $Self->AddResultOk(
                Identifier => 'TicketLockIndex',
                Label      => Translatable('Orphaned Records In ticket_lock_index Table'),
                Value      => $OrphanedTicketLockIndex || '0',
            );
        }

        $DBObject->Prepare( SQL => 'SELECT count(*) from ticket_index' );
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $OrphanedTicketIndex = $Row[0];
        }

        if ($OrphanedTicketLockIndex) {
            $Self->AddResultWarning(
                Identifier => 'TicketIndex',
                Label      => Translatable('Orphaned Records In ticket_index Table'),
                Value      => $OrphanedTicketIndex,
                Message =>
                    Translatable(
                    'Table ticket_index contains orphaned records. Please run bin/kix.Console.pl "Maint::Ticket::QueueIndexCleanup" to clean the StaticDB index.'
                    ),
            );
        }
        else {
            $Self->AddResultOk(
                Identifier => 'TicketIndex',
                Label      => Translatable('Orphaned Records In ticket_index Table'),
                Value      => $OrphanedTicketIndex || '0',
            );
        }
    }

    return $Self->GetResults();
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
