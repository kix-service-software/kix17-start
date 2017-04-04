# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketStateWorkflowTypeUpdate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}        = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}           = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}        = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(Event Config)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event TicketStateWorkflowTypeUpdate: Need $_!"
            );
            return;
        }
    }

    if ( $Param{Event} eq 'TicketTypeUpdate' ) {

        if ( !$Param{Data}->{TicketID} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need TicketID!"
            );
            return;
        }

        # get defaultticketstate...
        my $DefaultState = $Self->{ConfigObject}->Get(
            'TicketStateWorkflow::DefaultTicketState'
        );
        my $DefaultStateExtended
            = $Self->{ConfigObject}->Get('TicketStateWorkflowExtension::DefaultTicketState');
        if ( defined $DefaultStateExtended && ref $DefaultStateExtended eq 'HASH' ) {
            for my $Extension ( sort keys %{$DefaultStateExtended} ) {
                for my $Type ( keys %{ $DefaultStateExtended->{$Extension} } ) {
                    $DefaultState->{$Type} = $DefaultStateExtended->{$Extension}->{$Type};
                }
            }
        }

        my $ForceDefaultState = $Self->{ConfigObject}->Get(
            'TicketStateWorkflow::ForceDefaultTicketState'
        );
        my $ForceDefaultStateExtended
            = $Self->{ConfigObject}->Get('TicketStateWorkflowExtension::ForceDefaultTicketState');
        if ( defined $ForceDefaultStateExtended && ref $ForceDefaultStateExtended eq 'HASH' ) {
            for my $Extension ( sort keys %{$ForceDefaultStateExtended} ) {
                for my $Type ( keys %{ $ForceDefaultStateExtended->{$Extension} } ) {
                    $ForceDefaultState->{$Type} = $ForceDefaultStateExtended->{$Extension}->{$Type};
                }
            }
        }

        # get ticketstateworkflow...
        my $TicketStateWorkflow = $Self->{ConfigObject}->Get(
            'TicketStateWorkflow'
        );
        my $TicketStateWorkflowExtended
            = $Self->{ConfigObject}->Get('TicketStateWorkflowExtension');
        if ( defined $TicketStateWorkflowExtended && ref $TicketStateWorkflowExtended eq 'HASH' ) {
            for my $Extension ( sort keys %{$TicketStateWorkflowExtended} ) {
                for my $TypeState ( keys %{ $TicketStateWorkflowExtended->{$Extension} } ) {
                    $TicketStateWorkflow->{$TypeState}
                        = $TicketStateWorkflowExtended->{$Extension}->{$TypeState};
                }
            }
        }

        #get ticket data...
        my %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID => $Param{Data}->{TicketID},
            UserID   => 1,
        );

        if ( !scalar( keys(%TicketData) ) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event TicketStateWorkflowTypeUpdate: "
                    . "no ticket data for ID <"
                    . $Param{Data}->{TicketID}
                    . ">!",
            );
            return 1;
        }

        #return if current state is already default state
        return 1
            if (
            ref($DefaultState) ne 'HASH'
            || !$DefaultState->{ $TicketData{Type} }
            || $TicketData{State} eq $DefaultState->{ $TicketData{Type} }
            );

        #update state if force state update is enabeled...
        if (
            ref($ForceDefaultState) eq 'HASH'
            && $ForceDefaultState->{ $TicketData{Type} }
            && !$TicketStateWorkflow->{ $TicketData{Type}.':::'.$TicketData{State} }
            )
        {
            $Self->{TicketObject}->StateSet(
                State    => $ForceDefaultState->{ $TicketData{Type} },
                TicketID => $TicketData{TicketID},
                UserID   => $Self->{UserID} || 1,
            );
        }

        #check if current state is valid for new ticket type in workflow ...
        else {
            my $CurrentStateIsNotValid = 1;
            foreach my $Key ( sort( keys %{$TicketStateWorkflow} ) ) {
                my ( $CurrentType, $CurrentState ) = split( ':::', $Key );

                if ( $Key !~ /.+:::$/ && !$CurrentState && $CurrentType ) {
                    $CurrentState = $CurrentType;
                    $CurrentType  = '';
                }

                # set current state valid if it can be found in workflow def.
                # either on the left (key) side or on the right (value) side...
                if ( !$CurrentType || $CurrentType eq $TicketData{Type} ) {
                    if (
                        $CurrentState eq $TicketData{State}
                        || $TicketStateWorkflow->{$Key} =~ /(^|.*,\s*)$TicketData{State}(,.*|$)/
                        )
                    {

                        $CurrentStateIsNotValid = 0;
                        last;

                    }
                }
            }    #EO foreach my $Key ( sort( keys %{$TicketStateWorkflow} ) )

            if ($CurrentStateIsNotValid) {

                $Self->{TicketObject}->StateSet(
                    State    => $DefaultState->{ $TicketData{Type} },
                    TicketID => $TicketData{TicketID},
                    UserID   => $Self->{UserID} || 1,
                );
            }
        }
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
