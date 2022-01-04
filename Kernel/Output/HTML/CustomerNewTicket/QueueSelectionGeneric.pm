# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerNewTicket::QueueSelectionGeneric;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for my $Needed (qw( UserID SystemAddress)) {
        $Self->{$Needed} = $Param{$Needed} || die "Got no $Needed!";
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');

    my %NewTos;
    my $UserData       = $Param{Env}->{UserData} || '';
    my $CustomerUserID = '';

    if (
        $UserData
        && ref $UserData eq 'HASH'
    ) {
        $CustomerUserID = $UserData->{UserID} || $UserData->{ID} || '';
    }

    if (
        $Param{Env}->{UserType} eq 'User'
        && !$CustomerUserID
    ) {
        return %NewTos;
    }
    elsif (
        $Param{Env}->{UserType} ne 'User'
        && !$CustomerUserID
    ) {
        $CustomerUserID = $Param{Env}->{UserID} || $Self->{UserID};
    }

    # check if own selection is configured
    if ( $ConfigObject->{CustomerPanelOwnSelection} ) {
        for my $Queue ( sort keys %{ $ConfigObject->{CustomerPanelOwnSelection} } ) {
            my $Value = $ConfigObject->{CustomerPanelOwnSelection}->{$Queue};
            if ( $Queue =~ /^\d+$/ ) {
                $NewTos{$Queue} = $Value;
            }
            else {
                if ( $QueueObject->QueueLookup( Queue => $Queue ) ) {
                    $NewTos{ $QueueObject->QueueLookup( Queue => $Queue ) } = $Value;
                }
                else {
                    $NewTos{$Queue} = $Value;
                }
            }
        }

        # check create permissions
        my %Queues = $TicketObject->TicketMoveList(
            %{ $Param{ACLParams} },
            CustomerUserID => $CustomerUserID,
            Type           => 'create',
            Action         => $Param{Env}->{Action},
        );
        for my $QueueID ( sort keys %NewTos ) {
            if ( !$Queues{$QueueID} ) {
                delete $NewTos{$QueueID};
            }
        }
    }
    else {

        # SelectionType Queue or SystemAddress?
        my %Tos;
        if ( $ConfigObject->Get('CustomerPanelSelectionType') eq 'Queue' ) {
            %Tos = $TicketObject->TicketMoveList(
                %{ $Param{ACLParams} },
                CustomerUserID => $CustomerUserID,
                Type           => 'create',
                Action         => $Param{Env}->{Action},
            );
        }
        else {
            my %Queues = $TicketObject->TicketMoveList(
                %{ $Param{ACLParams} },
                CustomerUserID => $CustomerUserID,
                Type           => 'create',
                Action         => $Param{Env}->{Action},
            );
            my %SystemTos = $Kernel::OM->Get('Kernel::System::DB')->GetTableData(
                Table => 'system_address',
                What  => 'queue_id, id',
                Valid => 1,
                Clamp => 1,
            );
            for my $QueueID ( sort keys %Queues ) {
                if ( $SystemTos{$QueueID} ) {
                    $Tos{$QueueID} = $Queues{$QueueID};
                }
            }
        }
        %NewTos = %Tos;

        # build selection string
        for my $QueueID ( sort keys %NewTos ) {
            my %QueueData = $QueueObject->QueueGet( ID => $QueueID );
            my $String = $ConfigObject->Get('CustomerPanelSelectionString')
                || '<Realname> <<Email>> - Queue: <Queue>';
            $String =~ s/<Queue>/$QueueData{Name}/g;
            $String =~ s/<QueueComment>/$QueueData{Comment}/g;
            if ( $ConfigObject->Get('CustomerPanelSelectionType') ne 'Queue' ) {
                my %SystemAddressData = $Self->{SystemAddress}->SystemAddressGet( ID => $QueueData{SystemAddressID} );
                $String =~ s/<Realname>/$SystemAddressData{Realname}/g;
                $String =~ s/<Email>/$SystemAddressData{Name}/g;
            }
            $NewTos{$QueueID} = $String;
        }
    }
    return %NewTos;
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
