# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ProcessManagement::TransitionAction::TicketPrioritySet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::ProcessManagement::TransitionAction::Base);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::ProcessManagement::TransitionAction::TicketPrioritySet - A Module to set the priority of a Ticket

=head1 SYNOPSIS

All TicketPrioritySet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketPrioritySetObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::TransitionAction::TicketPrioritySet');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

    Run Data

    my $TicketPrioritySetResult = $TicketPrioritySetActionObject->Run(
        UserID                   => 123,
        Ticket                   => \%Ticket,   # required
        ProcessEntityID          => 'P123',
        ActivityEntityID         => 'A123',
        TransitionEntityID       => 'T123',
        TransitionActionEntityID => 'TA123',
        Config                   => {
            Type => 'Default',
            # or
            TypeID => 1,
            UserID => 123,                      # optional, to override the UserID from the logged user

        }
    );
    Ticket contains the result of TicketGet including DynamicFields
    Config is the Config Hash stored in a Process::TransitionAction's  Config key
    Returns:

    $TicketPrioritySetResult = 1; # 0

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # define a common message to output in case of any error
    my $CommonMessage = "Process: $Param{ProcessEntityID} Activity: $Param{ActivityEntityID}"
        . " Transition: $Param{TransitionEntityID}"
        . " TransitionAction: $Param{TransitionActionEntityID} - ";

    # check for missing or wrong params
    my $Success = $Self->_CheckParams(
        %Param,
        CommonMessage => $CommonMessage,
    );
    return if !$Success;

    # override UserID if specified as a parameter in the TA config
    $Param{UserID} = $Self->_OverrideUserID(%Param);

    # use ticket attributes if needed
    $Self->_ReplaceTicketAttributes(\%Param);

    if ( !$Param{Config}->{PriorityID} && !$Param{Config}->{Priority} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage . "No Priority or PriorityID configured!",
        );
        return;
    }

    $Success = 0;

    if (
        defined $Param{Config}->{Priority}
        && $Param{Config}->{Priority} ne $Param{Ticket}->{Priority}
    ) {
        $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TicketPrioritySet(
            Priority     => $Param{Config}->{Priority},
            TicketID => $Param{Ticket}->{TicketID},
            UserID   => $Param{UserID},
        );
    }
    elsif (
        defined $Param{Config}->{PriorityID}
        && $Param{Config}->{PriorityID} ne $Param{Ticket}->{PriorityID}
    ) {
        $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TicketPrioritySet(
            PriorityID   => $Param{Config}->{PriorityID},
            TicketID => $Param{Ticket}->{TicketID},
            UserID   => $Param{UserID},
        );
    }
    else {

        # data is the same as in ticket nothing to do
        $Success = 1;
    }

    if ( !$Success ) {
        my $CustomMessage;
        if ( defined $Param{Config}->{Priority} ) {
            $CustomMessage = "Priority: $Param{Config}->{Priority},";
        }
        else {
            $CustomMessage = "PriorityID: $Param{Config}->{PriorityID},";
        }
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage
                . 'Ticket Priority could not be updated to '
                . $CustomMessage
                . ' for Ticket: '
                . $Param{Ticket}->{TicketID} . '!',
        );
        return;
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
