# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::ProcessProgressAfterClosedChilds;

use strict;
use warnings;

# BPMX-capeIT
use utf8;
# EO BPMX-capeIT

our @ObjectDependencies = (
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if child tickets are not closed
    return 1 if !$Param{TicketID} || !$Param{UserID};

    # link tickets
    my $Links = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkList(
        Object => 'Ticket',
        Key    => $Param{TicketID},
        State  => 'Valid',
        Type   => 'ParentChild',
        UserID => $Param{UserID},
    );

    return 1 if !$Links;
    return 1 if ref $Links ne 'HASH';
    return 1 if !$Links->{Ticket};
    return 1 if ref $Links->{Ticket} ne 'HASH';
    return 1 if !$Links->{Ticket}->{ParentChild};
    return 1 if ref $Links->{Ticket}->{ParentChild} ne 'HASH';
    return 1 if !$Links->{Ticket}->{ParentChild}->{Target};
    return 1 if ref $Links->{Ticket}->{ParentChild}->{Target} ne 'HASH';

    my $OpenSubTickets = 0;
    TICKETID:
    for my $TicketID ( sort keys %{ $Links->{Ticket}->{ParentChild}->{Target} } ) {

        # get ticket
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 0,
        );

        if ( $Ticket{StateType} !~ m{ \A (close|merge|remove) }xms ) {
            $OpenSubTickets = 1;
            last TICKETID;
        }
    }

    # generate acl
    if ($OpenSubTickets) {
# BPMX-capeIT
#        $Param{Acl}->{CloseParentAfterClosedChilds} = {
        $Param{Acl}->{ProcessProgressAfterClosedChilds} = {
# EO BPMX-capeIT
            # match properties
            Properties => {

                # current ticket match properties
                Ticket => {
                    TicketID => [ $Param{TicketID} ],
                },
            },

            # return possible options (black list)
            PossibleNot => {

                # possible ticket options (black list)
# BPMX-capeIT
#                Ticket => {
#                    State => $Param{Config}->{State},
#                },
#                Action => ['AgentTicketClose'],
                ActivityDialog => $Param{Config}->{ActivityDialog},
# EO BPMX-capeIT
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
