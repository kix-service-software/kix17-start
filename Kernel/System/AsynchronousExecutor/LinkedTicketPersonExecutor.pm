# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor;

use strict;
use warnings;


our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Scheduler',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

#------------------------------------------------------------------------------
# BEGIN run method
#
sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    for my $CurrKey (qw(TicketID PersonID PersonHistory LinkType UserID)) {
        if ( !$Param{$CurrKey} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $CurrKey!"
            );
            return;
        }
    }

    # get needed objects
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # add link
    my $Success = $LinkObject->LinkAdd(
        SourceObject => 'Person',
        SourceKey    => $Param{PersonID},
        TargetObject => 'Ticket',
        TargetKey    => $Param{TicketID},
        Type         => $Param{LinkType},
        State        => 'Valid',
        UserID       => $Param{UserID},
    );
    if ($Success) {
        # add history
        $TicketObject->HistoryAdd(
            Name         => 'added involved person ' . $Param{PersonHistory},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Param{TicketID},
            CreateUserID => 1,
        );
    }

    return {
        Success     => 1,
        ReSchedule  => 0,
    };

}

=item AsyncCall()

creates a scheduler daemon task to execute the function 'Run' of this object asynchronously.

    my $Success = $Object->AsyncCall(

    );

Returns:

    $Success = 1;  # of false in case of an error

=cut

sub AsyncCall {
    my ( $Self, %Param ) = @_;

    # create a new object
    my $LocalObject;
    eval {
        $LocalObject = $Kernel::OM->Get('Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor');
    };

    # check if is possible to create the object
    if ( !$LocalObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not create 'Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor' object!",
        );
        return;
    }

    # check if object reference is the same as expected
    if ( ref $LocalObject ne 'Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "'Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor' object is not valid!",
        );
        return;
    }

    # check if the object can execute the function
    if ( !$LocalObject->can('Run') ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "'Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor' can not execute 'Run()'!",
        );
        return;
    }

    # check required params...
    for my $CurrKey (qw(TicketID PersonID PersonHistory LinkType UserID)) {
        if ( !$Param{$CurrKey} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $CurrKey!"
            );
            return;
        }
    }

    my $TaskName       = 'LinkedTicketPerson-' . $Param{TicketID} . '-' . $Param{LinkType} . '-' . $Param{PersonID};
    my %FunctionParams = (
        TicketID      => $Param{TicketID},
        PersonID      => $Param{PersonID},
        PersonHistory => $Param{PersonHistory},
        LinkType      => $Param{LinkType},
        UserID        => $Param{UserID},
    );

    # create a new task
    my $TaskID = $Kernel::OM->Get('Kernel::System::Scheduler')->TaskAdd(
        Type                     => 'AsynchronousExecutor',
        Name                     => $TaskName,
        Attempts                 => 1,
        MaximumParallelInstances => 1,
        Data                     => {
            Object   => 'Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor',
            Function => 'Run',
            Params   => \%FunctionParams,
        },
    );

    if ( !$TaskID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not create new AsynchronousExecutor: '$TaskName' task!",
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
