# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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

    # ------------------------
    # prepare search parameter
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

    if ( $Param{SearchStateType} ) {
        $Search{StateType} = $Param{SearchStateType};
    }

    my @States = split( ',', $Param{'SearchStates'} || '' );
    my @Queues = split( ',', $Param{'SearchQueues'} || '' );
    my @Types  = split( ',', $Param{'SearchTypes'}  || '' );

    if ( scalar(@States) > 0 ) {
        $Search{States} = \@States;
    }

    if ( scalar(@Queues) > 0 ) {
        $Search{Queues} = \@Queues;
    }

    if ( scalar(@Types) > 0 ) {
        $Search{Types} = \@Types;
    }


    if ( scalar(@States) == 1 && $States[0] eq '' ) {
        @States = undef;
    }
    if ( scalar(@Queues) == 1 && $Queues[0] eq '' ) {
        @Queues = undef;
    }
    if ( scalar(@Types) == 1 && $Types[0] eq '' ) {
        @Types = undef;
    }

    if ( ref($Param{'SearchDynamicFields'}) eq 'HASH' ) {
        DYNAMICFIELD:
        for my $DynamicField ( keys( %{ $Param{'SearchDynamicFields'} } ) ) {
            $Search{$DynamicField} = $Param{'SearchDynamicFields'}->{$DynamicField};
        }
    }
    # EO prepare search parameter
    # ---------------------------

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
            # check search filter
            my $Match = $Self->{TicketObject}->TicketSearch(
                %Search,
                TicketID   => $ID,
                Permission => 'ro',
                Result     => 'COUNT',
            );
            next ID if ( !$Match );

            # check ticket permission
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

            # get ticket data
            my %Ticket = $Self->{TicketObject}->TicketGet(
                TicketID      => $ID,
                DynamicFields => 1,
                Extended      => 1,
                UserID        => 1,
                Silent        => 1,
            );
            next ID if ( !%Ticket );

            $Result{$ID} = \%Ticket;
            $Result{$ID}->{'Link'} = 1;

            # Check if limit is reached
            return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
        }
    }

    # clean up SearchString
    $Param{SearchString} =~ s/([!*%&|])/\\$1/g;
    $Param{SearchString} =~ s/\s+/ /g;
    $Param{SearchString} =~ s/(^\s+|\s+$)//g;

    if ( $Param{SearchString} ) {

        if ( $Param{'SearchExtended'} ) {
            $Param{SearchString} =~ s/\s/&&/g;
        }
        else {
            $Param{SearchString} =~ s/\s/||/g;
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

        RESULT:
        for my $ID (@IDs) {
            # Skip entries added by LinkKeyList
            next RESULT if ( $Result{$ID} );

            # Skip current TicketID
            next RESULT if ( $Param{TicketID} && "$Param{TicketID}" eq "$ID" );

            # check ticket permission
            if ( $Param{Frontend} =~ /agent/i ) {
                my $Access = $Self->{TicketObject}->TicketPermission(
                    Type     => 'ro',
                    TicketID => $ID,
                    LogNo    => 1,
                    UserID   => $Param{UserID},
                );
                next RESULT if ( !$Access );
            }
            elsif ( $Param{Frontend} =~ /customer/i ) {
                my $Access = $Self->{TicketObject}->TicketCustomerPermission(
                    Type     => 'ro',
                    TicketID => $ID,
                    LogNo    => 1,
                    UserID   => $Param{UserID},
                );
                next RESULT if ( !$Access );
            }
            else {
                next RESULT;
            }

            # get ticket data
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
