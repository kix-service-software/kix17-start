# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ProcessManagement::TransitionAction::UpdateMultipleTickets;
use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);
use base qw(Kernel::System::ProcessManagement::TransitionAction::Base);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::System::Log',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{TicketObject}              = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{AllowedTicketSearchParams} = {

        #TicketID => '',
        #TicketNumber => '',
        Title  => 'Title',
        Queue  => 'Queues',
        Queues => 'Queues',

        #QueueIDs => '',
        Type  => 'Types',
        Types => 'Types',

        #TypeIDs => '',

        State  => 'States',
        States => 'States',

        #StateIDs => '',

        StateType => 'StateType',

        #StateTypeIDs => '',
        #Priority => 'Priority',
        #PriorityIDs => '',

        Service  => 'Services',
        Services => 'Services',

        #ServiceIDs => '',

        SLA          => 'SLAs',
        Lock         => 'Locks',
        Owner        => 'OwnerIDs',
        Owners       => 'OwnerIDs',
        Responsible  => 'ResponsibleIDs',
        Responsibles => 'ResponsibleIDs',

        #Customer => 'Customer',
        #CustomerUser => 'CustomerUserLoginRaw',
    };

    return $Self;
}

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
    $Self->_ReplaceTicketAttributes(%Param);

    my %TicketMethods;

    # go through config-hash and get methods and attributes for ticket-change
    CONFIGKEY:
    for my $Key ( keys %{ $Param{Config} } ) {

        # check validity
        if ( $Key !~ m/(.+)::(.+)/ ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $CommonMessage
                    . "No valid string for search or update given (format: X::Y) for $Key.",
            );
            return 0;
        }
        my $Method    = $1;
        my $Attribute = $2;

        # normalize search attribute...
        my $SearchAttribute = $Self->{AllowedTicketSearchParams}->{$Attribute} || $Attribute;

        # remove leading and trailing whitespaces from value...
        $Param{Config}->{$Key} =~ s{^\s+|\s+$}{}g;

        #----------------------------------------------------------------------
        # prepare search params...
        if ( $Method =~ m/Search/ ) {

            # check if values for asttribute are given
            if ( !$Param{Config}->{$Key} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => $CommonMessage . "No value for $Attribute given."
                );
                next CONFIGKEY;
            }

            # check if attribute is a valid search param...
            if (
                $Attribute
                && $Self->{AllowedTicketSearchParams}->{$Attribute}
                && $Attribute !~ m/^DynamicField_/
                )
            {
                $TicketMethods{Search}->{$SearchAttribute} = [ $Param{Config}->{$Key} ];
            }
            elsif ( $Attribute =~ m/DynamicField_/ ) {

                $TicketMethods{Search}->{$SearchAttribute}
                    = { Equals => [ $Param{Config}->{$Key} ] };
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => $CommonMessage
                        . "$Attribute is no valid search parameter! "
                );
                next CONFIGKEY;
            }
        }

        #----------------------------------------------------------------------
        # prepare update params - only ONE attribute is possible
        elsif ( $Method =~ m/Update/ ) {
            $TicketMethods{Update}->{$Attribute} = $Param{Config}->{$Key};
        }
    }

    # check if search parameters are given
    if ( !$TicketMethods{Search} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage . "No search parameters given!"
        );
        return 0;
    }

    # perform ticketsearch
    my @TicketIDs = $Self->{TicketObject}->TicketSearch(
        %{ $TicketMethods{Search} },
        Result => 'ARRAY',
        UserID => $Param{UserID},
    );

    # check number of tickets found
    if ( !@TicketIDs ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => $CommonMessage . "Got no ticket IDs!"
        );
        return 0;
    }
    elsif ( scalar(@TicketIDs) > ($Kernel::OM->Get('Kernel::Config')->Get('UpdateMultipleTickets::TicketSearchFoundThreshold') || 25) )
    {
        #too many tickets found, something wrong? no update...
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => $CommonMessage
                . "too many tickets found. No update - check transaction "
                . "config or increase 'UpdateMultipleTickets::TicketSearchFoundThreshold'."
        );
        return;
    }

    # update all found tickets...
    $Success = 0;
    TICKET:
    for my $ID (@TicketIDs) {

        # string of given attributes
        my $SuccessAttrList = '';

        # go through given attributes
        for my $AttrKey ( keys %{ $TicketMethods{Update} } ) {

            # update tickets, for all filtered tickets the same attributes are used
            if ( $AttrKey =~ m/DynamicField/ ) {
                my $DFKey = $AttrKey;
                $DFKey =~ s/DynamicField_//g;

                # get required DynamicField config
                my $DynamicFieldConfig = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
                    Name => $DFKey,
                );

                # check if we have a valid DynamicField
                if ( !IsHashRefWithData($DynamicFieldConfig) ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => $CommonMessage
                            . "Can't get DynamicField config for DynamicField: '$DFKey'!",
                    );
                    return;
                }

                # try to set the configured value
                $Success = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $ID,
                    Value              => $TicketMethods{Update}->{$AttrKey},
                    UserID             => $Param{UserID},
                );

            }
            elsif ( $AttrKey =~ m/Title/ ) {
                $Success = $Self->{TicketObject}->TicketTitleUpdate(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    Title    => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/Queue/ ) {
                $Success = $Self->{TicketObject}->TicketQueueSet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    Queue    => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/Owner/ ) {
                $Success = $Self->{TicketObject}->TicketOwnerSet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    NewUser  => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/Responsible/ ) {
                $Success = $Self->{TicketObject}->TicketResponsibleSet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    NewUser  => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/State/ ) {
                $Success = $Self->{TicketObject}->TicketStateSet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    State  => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/Service/ ) {
                $Success = $Self->{TicketObject}->TicketServiceSet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    Service  => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/SLA/ ) {
                $Success = $Self->{TicketObject}->TicketSLASet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    SLA  => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/Priority/ ) {
                $Success = $Self->{TicketObject}->TicketPrioritySet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    Priority  => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/Type/ ) {
                $Success = $Self->{TicketObject}->TicketTypeSet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    Type  => $TicketMethods{Update}->{$AttrKey},
                );
            }
            elsif ( $AttrKey =~ m/Lock/ ) {
                $Success = $Self->{TicketObject}->TicketLockSet(
                    TicketID => $ID,
                    UserID   => $Param{UserID},
                    Lock  => $TicketMethods{Update}->{$AttrKey},
                );
            }

            # check if everything went wrong
            if ( !$Success ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => $CommonMessage
                        . "Can't set value '"
                        . $TicketMethods{Update}->{$AttrKey}
                        . "' for $AttrKey of "
                        . "TicketID '" . $ID . "'!",
                );
                next TICKET;
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
