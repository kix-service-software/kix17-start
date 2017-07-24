# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::FollowUpCheck::References;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my @References = $Self->{ParserObject}->GetReferences();
    return if !@References;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @Result = ();

    REFERENCE:
    for my $Reference (@References) {

        # get ticket id of message id
        my @TicketIDs = $TicketObject->ArticleGetTicketIDsOfMessageID(
            MessageID => "<$Reference>",
        );
        next REFERENCE if ( !@TicketIDs );

        TICKETID:
        for my $TicketID ( @TicketIDs ) {
            my $TicketNumber = $TicketObject->TicketNumberLookup( TicketID => $TicketID, );
            next TICKETID if ( !$TicketNumber );

            push (@Result, $TicketNumber);
        }
    }

    return @Result;
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
