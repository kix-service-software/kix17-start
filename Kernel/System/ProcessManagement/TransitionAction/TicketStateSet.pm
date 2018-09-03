# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ProcessManagement::TransitionAction::TicketStateSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::ProcessManagement::TransitionAction::Base);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::ProcessManagement::TransitionAction::TicketStateSet - A module to set the ticket state

=head1 SYNOPSIS

All TicketStateSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketStateSetObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::TransitionAction::TicketStateSet');

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

    my $TicketStateSetResult = $TicketStateSetActionObject->Run(
        UserID                   => 123,
        Ticket                   => \%Ticket,   # required
        ProcessEntityID          => 'P123',
        ActivityEntityID         => 'A123',
        TransitionEntityID       => 'T123',
        TransitionActionEntityID => 'TA123',
        Config                   => {
            State   => 'open',
            # or
            StateID => 3,

            PendingTimeDiff => 123,             # optional, used for pending states, difference in seconds from
                                                #   current time to desired pending time (e.g. a value of 3600 means
                                                #   that the pending time will be 1 hr after the Transition Action is
                                                #   executed)
            UserID  => 123,                     # optional, to override the UserID from the logged user
        }
    );
    Ticket contains the result of TicketGet including DynamicFields
    Config is the Config Hash stored in a Process::TransitionAction's  Config key
    Returns:

    $TicketStateSetResult = 1; # 0

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

    if ( !$Param{Config}->{StateID} && !$Param{Config}->{State} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage . "No State or StateID configured!",
        );
        return;
    }

    $Success = 0;
    my %StateData;

    # If Ticket's StateID is already the same as the Value we
    # should set it to, we got nothing to do and return success
    if (
        defined $Param{Config}->{StateID}
        && $Param{Config}->{StateID} eq $Param{Ticket}->{StateID}
        )
    {
        return 1;
    }

    # If Ticket's StateID is not the same as the Value we
    # should set it to, set the StateID
    elsif (
        defined $Param{Config}->{StateID}
        && $Param{Config}->{StateID} ne $Param{Ticket}->{StateID}
        )
    {
        %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            ID => $Param{Config}->{StateID},
        );
        $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TicketStateSet(
            TicketID => $Param{Ticket}->{TicketID},
            StateID  => $Param{Config}->{StateID},
            UserID   => $Param{UserID},
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $CommonMessage
                    . 'Ticket StateID '
                    . $Param{Config}->{StateID}
                    . ' could not be updated for Ticket: '
                    . $Param{Ticket}->{TicketID} . '!',
            );
        }
    }

    # If Ticket's State is already the same as the Value we
    # should set it to, we got nothing to do and return success
    elsif (
        defined $Param{Config}->{State}
        && $Param{Config}->{State} eq $Param{Ticket}->{State}
        )
    {
        return 1;
    }

    # If Ticket's State is not the same as the Value we
    # should set it to, set the State
    elsif (
        defined $Param{Config}->{State}
        && $Param{Config}->{State} ne $Param{Ticket}->{State}
        )
    {
        %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            Name => $Param{Config}->{State},
        );
        $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TicketStateSet(
            TicketID => $Param{Ticket}->{TicketID},
            State    => $Param{Config}->{State},
            UserID   => $Param{UserID},
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $CommonMessage
                    . 'Ticket State '
                    . $Param{Config}->{State}
                    . ' could not be updated for Ticket: '
                    . $Param{Ticket}->{TicketID} . '!',
            );
        }
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage
                . "Couldn't update Ticket State - can't find valid State parameter!",
        );
        return;
    }

    # set pending time
    if (
        $Success
        && IsHashRefWithData( \%StateData )
        && $StateData{TypeName} =~ m{\A pending}msxi
        )
    {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        # get current time
        my $PendingTime = $TimeObject->SystemTime();

        if (
            IsNumber( $Param{Config}->{PendingTimeDiff} )
            )
        {

            # add PendingTimeDiff
            $PendingTime += $Param{Config}->{PendingTimeDiff};

            # convert pending time to time stamp
            my $PendingTimeString = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $PendingTime,
            );

            # set pending time
            $Kernel::OM->Get('Kernel::System::Ticket')->TicketPendingTimeSet(
                UserID   => $Param{UserID},
                TicketID => $Param{Ticket}->{TicketID},
                String   => $PendingTimeString,
            );

        }
        elsif ( $Param{Config}->{PendingDateTime} && ref $Param{Config}->{Placeholder} eq 'HASH' ) {
            if (
                defined $Param{Config}->{Placeholder}->{PendingDateTime}
                && $Param{Config}->{Placeholder}->{PendingDateTime}
                =~ /\<(KIX|OTRS)_TICKET_DynamicField_(.*?)\>/i
                )
            {
                my $DynamicField
                    = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
                    Name => $2,
                    );

                my $PendingTime;

                if ( $DynamicField->{FieldType} eq 'DateTime' ) {
                    $PendingTime = $Param{Config}->{PendingDateTime};
                }
                elsif ( $DynamicField->{FieldType} eq 'Date' ) {
                    $PendingTime = $Param{Config}->{PendingDateTime} . ' 00:00:00';
                }
                else {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => $CommonMessage
                            . "Couldn't set pending time - no valid date or datetime dynamic field!",
                    );
                    return;
                }

                # handle BOB and EOB
                if ( $Param{Config}->{TimeTarget} =~ /^(BOB|EOB)$/g ) {
                    my $Calendar;
                    if ( $Param{Ticket}->{SLAID} ) {

                        # get calendar from SLA
                        my %SLA = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
                            SLAID  => $Param{Ticket}->{SLAID},
                            UserID => 1,
                        );
                        $Calendar = $SLA{Calendar};
                    }
                    else {
                        # otherwise get calendar from Queue
                        my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
                            ID     => $Param{Ticket}->{QueueID},
                            UserID => 1,
                        );
                        $Calendar = $Queue{Calendar};
                    }
                    my $PendingTimeUnix = $TimeObject->DestinationTime(
                        StartTime => $TimeObject->TimeStamp2SystemTime(
                            String => $PendingTime,
                        ),
                        Time     => 2,
                        Calendar => $Calendar
                    );
                    $PendingTime = $TimeObject->SystemTime2TimeStamp(
                        SystemTime => $PendingTimeUnix - 2,
                    );

                    # speacial handling for EOB
                    if ( $Param{Config}->{TimeTarget} eq 'EOB' ) {
                        my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay )
                            = $TimeObject->SystemTime2Date(
                            SystemTime => $TimeObject->TimeStamp2SystemTime(
                                String => $PendingTime,
                                )
                            );
                        my %WeekDays = (
                            0 => 'Sun',
                            1 => 'Mon',
                            2 => 'Tue',
                            3 => 'Wed',
                            4 => 'Thu',
                            5 => 'Fri',
                            6 => 'Sat',
                        );

                        # get last element = end hour of working time
                        if ($Calendar) {
                            $Calendar = '::Calendar' . $Calendar;
                        }
                        my $WorkingHours = $Kernel::OM->Get('Kernel::Config')
                            ->Get( 'TimeWorkingHours' . $Calendar );
                        my $EOB = pop @{ $WorkingHours->{ $WeekDays{$WeekDay} } };
                        $PendingTime =~ s/^(.*?)\s(.*?)$/"$1 $EOB:59:59"/g;
                    }
                }

                # set pending time
                $Kernel::OM->Get('Kernel::System::Ticket')->TicketPendingTimeSet(
                    UserID   => $Param{UserID},
                    TicketID => $Param{Ticket}->{TicketID},
                    String   => $PendingTime,
                );
            }
        }

    }

    return $Success;
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
