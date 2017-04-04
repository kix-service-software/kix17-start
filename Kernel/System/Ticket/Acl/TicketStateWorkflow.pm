# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::TicketStateWorkflow;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Type',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create required objects
    $Self->{ConfigObject}  = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}     = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}  = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{TypeObject}  = $Kernel::OM->Get('Kernel::System::Type');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my @CurrentTicketState = ();
    my @CurrentTicketType  = ();
    my @PossibleStates     = ();

    return if ( $Param{ReturnType} ne 'Ticket' || $Param{ReturnSubType} ne 'State' );

    # get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( $Param{TypeID} ) {
        my %Type = $Self->{TypeObject}->TypeGet(
            ID => $Param{TypeID},
        );
        $Param{Type} = $Type{Name};
    }

    if ( $Param{Type} || $Param{TicketID} ) {
        my %Ticket = ();
        if ( $Param{TicketID} ) {
            %Ticket = $Self->{TicketObject}->TicketGet(
                TicketID => $Param{TicketID},
            );
        }

        # fallback for QueueID...
        if ( !$Param{TicketID} ) {
            $Ticket{QueueID} = $Param{QueueID} || 1;
        }
        $Ticket{State} ||= '';
        $Ticket{Type} = $Param{Type} if $Param{Type};
        $Ticket{Type} ||= '';

        # get config for StateWorkflow...
        my $Config = $Self->{ConfigObject}->Get('TicketStateWorkflow');
        my $ConfigExtended = $Self->{ConfigObject}->Get('TicketStateWorkflowExtension');
        if ( defined $ConfigExtended && ref $ConfigExtended eq 'HASH' ) {
            for my $Extension ( sort keys %{$ConfigExtended} ) {
                for my $TypeState ( keys %{ $ConfigExtended->{$Extension} } ) {
                    $Config->{$TypeState} = $ConfigExtended->{$Extension}->{$TypeState};
                }
            }
        }

        push( @CurrentTicketState, $Ticket{State} );
        push( @CurrentTicketType,  $Ticket{Type} );

        if (
            $Config
            && ref($Config) eq 'HASH'
            && (
                $Config->{ $Ticket{Type} . ':::' . $Ticket{State} }
                || $Config->{ $Ticket{State} }
            )
            )
        {
            my $ConfigTicketValue = $Config->{ $Ticket{Type} . ':::' . $Ticket{State} }
                || $Config->{ $Ticket{State} };

            if ( $ConfigTicketValue =~ /_ANY_/ ) {
                return 1;
            }
            elsif ( $ConfigTicketValue =~ /_NONE_/ ) {
                @PossibleStates = [ $Ticket{State} ];
            }
            else {
                my @PossibleStatesArray = split( ',', $ConfigTicketValue );
                foreach my $StateTypeValue (@PossibleStatesArray) {

                    #remove trailing or leading spaces...
                    $StateTypeValue =~ s/^\s+//g;
                    $StateTypeValue =~ s/\s+$//g;

                    #replace placeholder statenames...
                    if ( $Param{TicketID} && $StateTypeValue =~ /_PREVIOUS_/ ) {
                        $StateTypeValue = $Self->{TicketObject}->GetPreviousTicketState(
                            TicketID => $Param{TicketID},
                        );
                    }

                    push( @PossibleStates, $StateTypeValue );
                }
            }
        }
        else {
            return 1;
        }

        #-----------------------------------------------------------------------
        # setting up the ACL...
        $Param{Acl}->{'950_TicketStateWorkflow'} = {
            Properties => {

                # always match
            },
            Possible => {
                Ticket => {
                    State => \@PossibleStates,
                },
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
