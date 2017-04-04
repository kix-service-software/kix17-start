# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketUnlockOnStateUpdate;

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
    my $NonOverrideTicketState;
    my $DefaultState;

    # check needed stuff
    if ( !$Param{Event} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need Event!" );
        return;
    }

    if ( $Param{Event} eq 'TicketStateUpdate' ) {

        #check required param...
        return 1 if !$Param{Data}->{TicketID};

        # get configuration...
        my $ConfigRef = $Self->{ConfigObject}->Get('TicketUnlockOnStateUpdate');
        my $ConfigRefExtended = $Self->{ConfigObject}->Get('TicketUnlockOnStateUpdateExtension');
        if ( defined $ConfigRefExtended && ref $ConfigRefExtended eq 'HASH' ) {
            for my $Extension ( sort keys %{$ConfigRefExtended} ) {
                for my $TypeState ( keys %{ $ConfigRefExtended->{$Extension} } ) {
                    $ConfigRef->{$TypeState} = $ConfigRefExtended->{$Extension}->{$TypeState};
                }
            }
        }

        # get ticket is locked
        return 1 if ( !$Self->{TicketObject}->LockIsTicketLocked( TicketID => $Param{Data}->{TicketID} ) );

        #get ticket data...
        my %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID => $Param{Data}->{TicketID},
            UserID   => 1,
        );

        if ( !scalar( keys(%TicketData) ) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event:TicketStateAutoUpdate - "
                    . "no ticket data for ID <"
                    . $Param{Data}->{TicketID}
                    . ">!",
            );
            return 1;
        }

        #return if no automaticstates
        return 1 if ( ref($ConfigRef) ne 'HASH' );

        my @AutomaticStates;
        if ( defined $ConfigRef->{ValidStates}->{ $TicketData{Type} } ) {
            @AutomaticStates = split( /,/, $ConfigRef->{ValidStates}->{ $TicketData{Type} } );
        }

        foreach my $State (@AutomaticStates) {

            # Blanks remove
            $State =~ s/^\s+|\s+$//g;

            next if ( $TicketData{State} ne $State );

            if ( $TicketData{State} eq $State ) {

                # unlock Ticket
                $Self->{TicketObject}->LockSet(
                    Lock               => 'unlock',
                    TicketID           => $Param{Data}->{TicketID},
                    SendNoNotification => 0,
                    UserID             => 1,
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
