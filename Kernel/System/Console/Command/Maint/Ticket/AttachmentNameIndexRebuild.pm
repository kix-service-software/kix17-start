# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::AttachmentNameIndexRebuild;

use strict;
use warnings;

use Time::HiRes();

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Completely rebuild the attachment name search index.');
    $Self->AddOption(
        Name        => 'micro-sleep',
        Description => "Specify microseconds to sleep after every ticket to reduce system load (e.g. 1000).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'ticket-newer',
        Description => "Ticket has to be created after given date YYYY-MM-DD",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr{^\d{4}-\d{2}-\d{2}$}smx,
    );
    $Self->AddOption(
        Name        => 'ticket-older',
        Description => "Ticket has to be created before or at given date YYYY-MM-DD",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr{^\d{4}-\d{2}-\d{2}$}smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Rebuilding attachment name search index...</yellow>\n");

    # disable ticket events
    $Kernel::OM->Get('Kernel::Config')->{'Ticket::EventModulePost'} = {};

    my $TicketNewer = $Self->GetOption('ticket-newer');
    if ($TicketNewer) {
        $TicketNewer .= ' 00:00:00';
    }
    else {
        $TicketNewer = undef;
    }

    my $TicketOlder = $Self->GetOption('ticket-older');
    if ($TicketOlder) {
        $TicketOlder .= ' 23:59:59';
    }
    else {
        $TicketOlder = undef;
    }

    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get all tickets
    my @TicketIDs = $TicketObject->TicketSearch(
        TicketCreateTimeNewerDate => $TicketNewer,
        TicketCreateTimeOlderDate => $TicketOlder,
        ArchiveFlags              => [ 'y', 'n' ],
        OrderBy                   => 'Down',
        SortBy                    => 'Age',
        Result                    => 'ARRAY',
        Limit                     => 100_000_000,
        Permission                => 'ro',
        UserID                    => 1,
    );
    my $TicketCount = scalar(@TicketIDs);

    my $Count      = 0;
    my $MicroSleep = $Self->GetOption('micro-sleep');

    $Self->Print(
        "<yellow>0</yellow> of <yellow>$TicketCount</yellow> processed (<yellow>0 %</yellow> done).\n"
    );
    TICKETID:
    for my $TicketID (@TicketIDs) {

        $Count++;

        # get articles
        my @ArticleIndex = $TicketObject->ArticleIndex(
            TicketID => $TicketID,
            UserID   => 1,
        );

        for my $ArticleID (@ArticleIndex) {
            # update search index table
            $DBObject->Do(
                SQL  => 'DELETE FROM article_attachment_search WHERE article_id = ?',
                Bind => [ \$ArticleID ],
            );

            # get all attachments from article
            my %ArticleAttachments = $TicketObject->ArticleAttachmentIndexRaw(
                ArticleID => $ArticleID,
            );

            # process attachments
            ATTACHMENT:
            for my $Index ( keys( %ArticleAttachments ) ) {
                next ATTACHMENT if ( !$ArticleAttachments{ $Index }->{Filename} );

                # get filename
                # convert to lowercase to avoid LOWER()/LCASE() in the DB query
                my $Filename = lc $ArticleAttachments{ $Index }->{Filename};
                next ATTACHMENT if (
                    $Filename eq 'file-1'
                    || $Filename eq 'file-2'
                );

                # write attachment to search index
                my $Success  = $DBObject->Do(
                    SQL  => 'INSERT INTO article_attachment_search (article_id, filename)'
                          . ' VALUES (?, ?)',
                    Bind => [ \$ArticleID, \$Filename ],
                );
                if ( !$Success ) {
                    $Self->PrintError('Could not add attachment ' . $Filename . ' to search index for article id ' . $ArticleID . '.');
                }
            }
        }

        if (
            $Count % 1000 == 0
            && $Count != $TicketCount
        ) {
            my $Percent = int( $Count / ( $TicketCount / 100 ) );
            $Self->Print(
                "<yellow>$Count</yellow> of <yellow>$TicketCount</yellow> processed (<yellow>$Percent %</yellow> done).\n"
            );
        }

        Time::HiRes::usleep($MicroSleep) if $MicroSleep;
    }
    $Self->Print(
        "<yellow>$TicketCount</yellow> of <yellow>$TicketCount</yellow> processed (<yellow>100 %</yellow> done).\n"
    );

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
