# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Notification::AgentTicketEscalation;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Cache',
    'Kernel::System::Ticket',
    'Kernel::System::Queue',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # only show the escalations on ticket overviews
    my $Pattern = '^AgentTicket(?:Queue|Service|(?:Status|Locked|Watch|Responsible)View)';
    return '' if $LayoutObject->{Action} !~ /$Pattern/;

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # check result cache
    my $CacheTime = $Param{Config}->{CacheTime} || 40;
    if ($CacheTime) {
        my $Output = $CacheObject->Get(
            Type => 'TicketEscalation',
            Key  => 'EscalationResult::' . $Self->{UserID} . '::' . $LayoutObject->{UserLanguage},
        );
        return $Output if defined $Output;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

    # restrict ticket search to relevant queues only?
    my %SearchAdd;
    if ( $Param{Config}->{AgentsCustomQueuesOnly} ) {
        my @AgentsCustomQueues = $QueueObject->GetAllCustomQueues(
            UserID => $Self->{UserID}
        );
        $SearchAdd{QueueIDs} = \@AgentsCustomQueues;
    }

    # get all overtime tickets
    my $ShownMax            = $Param{Config}->{ShownMax}            || 25;
    my $EscalationInMinutes = $Param{Config}->{EscalationInMinutes} || 120;

    my @TicketIDs;
    if ( ref $SearchAdd{QueueIDs} eq 'ARRAY' && @{ $SearchAdd{QueueIDs} } ) {
        @TicketIDs = $TicketObject->TicketSearch(
            Result                           => 'ARRAY',
            Limit                            => $ShownMax,
            TicketEscalationTimeOlderMinutes => -$EscalationInMinutes,
            Permission                       => 'rw',
            UserID                           => $Self->{UserID},
            %SearchAdd,
        );
    }

    # get escalations
    my $ResponseTime = '';
    my $UpdateTime   = '';
    my $SolutionTime = '';
    my $Comment      = '';
    my $Count        = 0;
    TICKET:
    for my $TicketID (@TicketIDs) {
        # get ticket escalation preferences
        my $TicketEscalationDisabled = $TicketObject->TicketEscalationDisabledCheck(
            TicketID => $TicketID,
            UserID   => $Self->{UserID},
        );
        # no notification if escalation is disabled
        if ($TicketEscalationDisabled) {
            next TICKET;
        }

        # get ticket data
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 0,
        );

        # check response time
        if ( defined $Ticket{FirstResponseTime} ) {
            $Ticket{FirstResponseTimeHuman} = $LayoutObject->CustomerAgeInHours(
                Age   => $Ticket{FirstResponseTime},
                Space => ' ',
            );

            if ( $Ticket{FirstResponseTimeEscalation} ) {
                $LayoutObject->Block(
                    Name => 'TicketEscalationFirstResponseTimeOver',
                    Data => \%Ticket,
                );
                my $Data = $LayoutObject->Output(
                    TemplateFile => 'AgentTicketEscalation',
                    Data         => \%Param,
                );
                $ResponseTime .= $LayoutObject->Notify(
                    Priority => 'Error',
                    Data     => $Data,
                );
                $Count++;
            }
            elsif ( $Ticket{FirstResponseTimeNotification} ) {
                $LayoutObject->Block(
                    Name => 'TicketEscalationFirstResponseTimeWillBeOver',
                    Data => \%Ticket,
                );
                my $Data = $LayoutObject->Output(
                    TemplateFile => 'AgentTicketEscalation',
                    Data         => \%Param,
                );
                $ResponseTime .= $LayoutObject->Notify(
                    Priority => 'Notice',
                    Data     => $Data,
                );
                $Count++;
            }
        }

        # check update time
        if ( defined $Ticket{UpdateTime} ) {
            $Ticket{UpdateTimeHuman} = $LayoutObject->CustomerAgeInHours(
                Age   => $Ticket{UpdateTime},
                Space => ' ',
            );

            if ( $Ticket{UpdateTimeEscalation} ) {
                $LayoutObject->Block(
                    Name => 'TicketEscalationUpdateTimeOver',
                    Data => \%Ticket,
                );
                my $Data = $LayoutObject->Output(
                    TemplateFile => 'AgentTicketEscalation',
                    Data         => \%Param,
                );
                $UpdateTime .= $LayoutObject->Notify(
                    Priority => 'Error',
                    Data     => $Data,
                );
                $Count++;
            }
            elsif ( $Ticket{UpdateTimeNotification} ) {
                $LayoutObject->Block(
                    Name => 'TicketEscalationUpdateTimeWillBeOver',
                    Data => \%Ticket,
                );
                my $Data = $LayoutObject->Output(
                    TemplateFile => 'AgentTicketEscalation',
                    Data         => \%Param,
                );
                $UpdateTime .= $LayoutObject->Notify(
                    Priority => 'Notice',
                    Data     => $Data,
                );
                $Count++;
            }
        }

        # check solution
        if ( defined $Ticket{SolutionTime} ) {
            $Ticket{SolutionTimeHuman} = $LayoutObject->CustomerAgeInHours(
                Age   => $Ticket{SolutionTime},
                Space => ' ',
            );

            if ( $Ticket{SolutionTimeEscalation} ) {
                $LayoutObject->Block(
                    Name => 'TicketEscalationSolutionTimeOver',
                    Data => \%Ticket,
                );
                my $Data = $LayoutObject->Output(
                    TemplateFile => 'AgentTicketEscalation',
                    Data         => \%Param,
                );
                $SolutionTime .= $LayoutObject->Notify(
                    Priority => 'Error',
                    Data     => $Data,
                );
                $Count++;
            }
            elsif ( $Ticket{SolutionTimeNotification} ) {
                $LayoutObject->Block(
                    Name => 'TicketEscalationSolutionTimeWillBeOver',
                    Data => \%Ticket,
                );
                my $Data = $LayoutObject->Output(
                    TemplateFile => 'AgentTicketEscalation',
                    Data         => \%Param,
                );
                $SolutionTime .= $LayoutObject->Notify(
                    Priority => 'Notice',
                    Data     => $Data,
                );
                $Count++;
            }
        }
    }
    if ( $Count == $ShownMax ) {
        $Comment .= $LayoutObject->Notify(
            Priority => 'Error',
            Info     => Translatable('There are more escalated tickets!'),
        );
    }
    my $Output = $ResponseTime . $UpdateTime . $SolutionTime . $Comment;

    # cache result
    if ($CacheTime) {
        $CacheObject->Set(
            Type  => 'TicketEscalation',
            Key   => 'EscalationResult::' . $Self->{UserID} . '::' . $LayoutObject->{UserLanguage},
            Value => $Output,
            TTL   => $CacheTime,
        );
    }

    return $Output;
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
