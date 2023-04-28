# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::CloseParentAfterClosedChilds;

use strict;
use warnings;

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

    # check if ticket id is given
    return 1 if !$Param{TicketID};

    # check config for ticket types to exclude
    if ( ref( $Param{Config}->{ExcludeTypes} ) eq 'HASH' ) {
        # get ticket data
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
            Silent        => 1,
        );

        # check for excluded ticket type
        if (
            %Ticket
            && $Ticket{Type}
            && $Param{Config}->{ExcludeTypes}->{ $Ticket{Type} }
        ) {
            return 1;
        }
    }

    # get linked tickets for ticket
    my $Links = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkList(
        Object  => 'Ticket',
        Key     => $Param{TicketID},
        Object2 => 'Ticket',
        State   => 'Valid',
        Type    => 'ParentChild',
        UserID  => 1,
    );

    # check if any linked ticket exist
    return 1 if(
        !$Links
        || ref( $Links ) ne 'HASH'
        || !$Links->{Ticket}
        || ref( $Links->{Ticket} ) ne 'HASH'
        || !$Links->{Ticket}->{ParentChild}
        || ref( $Links->{Ticket}->{ParentChild} ) ne 'HASH'
        || !$Links->{Ticket}->{ParentChild}->{Target}
        || ref( $Links->{Ticket}->{ParentChild}->{Target} ) ne 'HASH'
    );

    my $OpenSubTickets = 0;
    TICKETID:
    for my $TicketID ( sort keys %{ $Links->{Ticket}->{ParentChild}->{Target} } ) {

        # get ticket
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 0,
        );

        if ( $Ticket{StateType} !~ m{ \A (?:close|merge|remove) }xms ) {
            $OpenSubTickets = 1;
            last TICKETID;
        }
    }

    # generate acl
    if ($OpenSubTickets) {

        $Param{Acl}->{CloseParentAfterClosedChilds} = {

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
                Ticket => {
                    State => $Param{Config}->{State},
                },
                Action => ['AgentTicketClose'],
            },
        };
    }

    return 1;
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
