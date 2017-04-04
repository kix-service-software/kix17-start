# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::HideAgentTicketMoveServiceQueueAssignment;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Service',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create required objects
    $Self->{ConfigObject}  = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}     = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ServiceObject} = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{TicketObject}  = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    return if ( $Param{Action} && $Param{Action} =~ /^Customer/ );

    # get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( !$Self->_MovePossible(%Param) ) {
        my @Blacklist = ( 'AgentTicketMove' );
        $Param{Acl}->{'900_HideAgentTicketMoveServiceQueueAssignment'} = {
            Properties => {},
            PossibleNot   => {
                Action => \@Blacklist,
            },
        };
    }

    return 1;
}

sub _MovePossible {
    my ( $Self, %Param ) = @_;
    my @Result = qw{};
    my $Result = 1;

    return $Result if ( !$Param{TicketID} );

    my $ServiceQueueAssigment = $Self->{ConfigObject}->Get('Ticket::ServiceQueueAssignment');
    return 1 if ( !$ServiceQueueAssigment || ref($ServiceQueueAssigment) ne 'HASH' );

    # retrieve ticket data...
    my %TicketData = $Self->{TicketObject}->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );
    return $Result if ( !$TicketData{ServiceID} );

    # retrieve excluded ticket type- and states...
    my $TypeStateExlusions = $ServiceQueueAssigment->{TypeStateExclusions};
    if ( $TypeStateExlusions && ref($TypeStateExlusions) eq 'HASH' ) {
        for my $CurrKey ( sort( keys( %{$TypeStateExlusions} ) ) ) {
            if ( $TypeStateExlusions->{$CurrKey} && $CurrKey =~ (/(.+):::(.+):::(.+)/) ) {
                my $TypeRegexp  = $2;
                my $StateRegexp = $3;
                return 1
                    if (
                    ( $TicketData{Type} =~ /$TypeRegexp/ )
                    && ( $TicketData{State} =~ /$StateRegexp/ )
                    );
            }
        }
    }

    # retrieve service data...
    my %ServiceData = $Self->{ServiceObject}->ServiceGet(
        ServiceID => $TicketData{ServiceID},
        UserID    => 1,
    );

    # move or not to move...
    if (
        %ServiceData
        && $ServiceData{AssignedQueueID}
        && $ServiceData{AssignedQueueID}
        )
    {
        $Result = '0';
    }

    return $Result;
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
