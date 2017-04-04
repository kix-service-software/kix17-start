# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::HideProcessTicketTabs;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create required objects
    $Self->{LogObject}     = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}  = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( defined $Param{Action} && $Param{Action} eq 'AgentTicketZoom' ) {

        # get required params...
        for (qw(TicketID)) {
            if ( !$Param{$_} ) {
                $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
                return;
            }
        }

        # check if ticket is normal or process ticket
        my $IsProcessTicket = $Self->{TicketObject}->TicketCheckForProcessType(
            'TicketID' => $Param{TicketID}
        );

        # create blacklist
        my @Blacklist;
        if ($IsProcessTicket) {

            # count articles
            my $Count = $Self->{TicketObject}->CountArticles(
                TicketID => $Param{TicketID}
            ) || 0;

            # if there are no articles hide article tab
            if ( !$Count ) {
                push @Blacklist,'AgentTicketZoomTabArticle';
            }
        }
        else {

            # show process tab only if ticket is process ticket
            push @Blacklist,'AgentTicketZoomTabProcess';
        }

        # return data
        $Param{Acl}->{'995_HideProcessTicketTabs'} = {
            PossibleNot => {
                Action => \@Blacklist,
            },
        };
    }

    return 1;
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
