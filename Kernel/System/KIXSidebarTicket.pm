# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXSidebarTicket;

use strict;
use warnings;

use utf8;

our @ObjectDependencies = (
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Ticket'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LinkObject}   = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub KIXSidebarTicketSearch {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Frontend} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need Frontend!",
        );
        return;
    }

    if ( !$Param{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need UserID!",
        );
        return;
    }

    my @States = split( ',', $Param{'SearchStates'} || '' );
    my @Queues = split( ',', $Param{'SearchQueues'} || '' );
    my @Types  = split( ',', $Param{'SearchTypes'}  || '' );

    if ( scalar(@States) == 1 && $States[0] eq '' ) {
        @States = undef;
    }
    if ( scalar(@Queues) == 1 && $Queues[0] eq '' ) {
        @Queues = undef;
    }
    if ( scalar(@Types) == 1 && $Types[0] eq '' ) {
        @Types = undef;
    }

    my %Result;

    if ( $Param{TicketID} && $Param{LinkMode} ) {
        my %LinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => 'Ticket',
            State   => $Param{LinkMode},
            UserID  => 1,
        );

        ID:
        for my $ID ( keys %LinkKeyList ) {
            if ( $Param{Frontend} =~ /agent/i ) {
                my $Access = $Self->{TicketObject}->TicketPermission(
                    Type     => 'ro',
                    TicketID => $ID,
                    LogNo    => 1,
                    UserID   => $Param{UserID},
                );
                next ID if ( !$Access );
            }
            elsif ( $Param{Frontend} =~ /customer/i ) {
                my $Access = $Self->{TicketObject}->TicketCustomerPermission(
                    Type     => 'ro',
                    TicketID => $ID,
                    LogNo    => 1,
                    UserID   => $Param{UserID},
                );
                next ID if ( !$Access );
            }
            else {
                next ID;
            }
            my %Ticket = $Self->{TicketObject}->TicketGet(
                TicketID      => $ID,
                DynamicFields => 1,
                Extended      => 1,
                UserID        => 1,
                Silent        => 1,
            );
            next ID if ( !%Ticket );

            if ( @States ) {
                my $MatchState = 0;
                for my $State (@States) {
                    if ( $Ticket{State} eq $State ) {
                        $MatchState = 1;
                    }
                }
                next ID if ( !$MatchState );
            }
            if ( @Queues ) {
                my $MatchQueue = 0;
                for my $Queue (@Queues) {
                    if ( $Ticket{Queue} eq $Queue ) {
                        $MatchQueue = 1;
                    }
                }
                next ID if ( !$MatchQueue );
            }
            if ( @Types ) {
                my $MatchType = 0;
                for my $Type (@Types) {
                    if ( $Ticket{Type} eq $Type ) {
                        $MatchType = 1;
                    }
                }
                next ID if ( !$MatchType );
            }

            $Result{$ID} = \%Ticket;
            $Result{$ID}->{'Link'} = 1;

            # Check if limit is reached
            return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
        }
    }

    if ( $Param{SearchString} ) {

        $Param{SearchString} =~ s/\s\s/ /g;
        if ( $Param{'SearchExtended'} ) {
            $Param{SearchString} =~ s/\s/&&/g;
        }
        else {
            $Param{SearchString} =~ s/\s/||/g;
        }

        my %Search = ();

        if ( $Param{Frontend} =~ /agent/i ) {
            $Search{UserID} = $Param{UserID};
        }
        elsif ( $Param{Frontend} =~ /customer/i ) {
            $Search{CustomerUserID} = $Param{UserID};
        }
        else {
            return;
        }

        if ( $Param{'SearchCustomer'} == 1 ) {
            $Search{CustomerID} = $Param{CustomerID};
        }
        elsif ( $Param{'SearchCustomer'} == 2 ) {
            $Search{CustomerUserLogin} = $Param{CustomerUser};
        }

        if ( scalar(@States) > 0 ) {
            $Search{States} = \@States;
        }

        if ( scalar(@Queues) > 0 ) {
            $Search{Queues} = \@Queues;
        }

        if ( scalar(@Types) > 0 ) {
            $Search{Types} = \@Types;
        }

        my @IDs = $Self->{TicketObject}->TicketSearch(
            From    => $Param{SearchString},
            To      => $Param{SearchString},
            Cc      => $Param{SearchString},
            Subject => $Param{SearchString},
            Body    => $Param{SearchString},

            %Search,

            ContentSearch       => 'OR',
            ContentSearchPrefix => '*',
            ContentSearchSuffix => '*',
            ConditionInline     => 1,

            Permission => 'ro',
            Limit      => $Param{'Limit'},
            Result     => 'ARRAY',
        );

        for my $ID (@IDs) {

            # Skip entries added by LinkKeyList
            next if ( $Result{$ID} );

            # Skip current TicketID
            next if ( $Param{TicketID} && "$Param{TicketID}" eq "$ID" );

            my %Ticket = $Self->{TicketObject}->TicketGet(
                TicketID      => $ID,
                DynamicFields => 1,
                Extended      => 1,
                UserID        => 1,
                Silent        => 1,
            );
            if (%Ticket) {
                $Result{$ID} = \%Ticket;
                $Result{$ID}->{'Link'} = 0;

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }
    }

    return \%Result;
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
