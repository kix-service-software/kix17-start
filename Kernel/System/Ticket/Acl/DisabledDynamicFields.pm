# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::DisabledDynamicFields;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create required objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldConfig         = $Self->{ConfigObject}->Get('Ticket::Frontend::DynamicField');
    my $DisabledDynamicFieldConfig = $DynamicFieldConfig->{DisabledDynamicFields};

    return if ( $Param{ReturnType} ne 'Ticket' );
    return if !$Param{Action};
    return if ($Param{Action} !~ /^(AgentTicketPhone|AgentTicketEmail|CustomerTicketMessage|AgentTicketProcess)$/ && !$Param{TicketID});

    my %Ticket = ();
    if ( defined $Param{TicketID} && $Param{TicketID} ) {
        %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Param{TicketID},
        );
    }

    # get all dynamic fields
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Param{Action}");
    my $DynamicFieldList = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # cycle through disabled fields
    my %DisabledDynamicFieldHash;
    DYNAMICFIELD:
    for my $RestrictedDynamicField ( keys %{$DisabledDynamicFieldConfig} ) {
        next if !$RestrictedDynamicField;

        my @Elements = split /:::/, $RestrictedDynamicField;
        next if scalar @Elements != 3;

        my $RegExpPatternCondition = "";
        if ( $Elements[2] =~ /\[regexp\](.*)/ ) {
            $RegExpPatternCondition = $1;
        }
        my @RestrictedDynamicFieldNames;

        # if action matches
        if ( $Elements[0] eq $Param{Action} || $Param{Action} =~ /$Elements[0]/ ) {

            $Param{NextStateID} = $Param{NextStateID} || $Param{NewStateID} || $Param{StateID};
            $Param{ServiceID}   = $Param{ServiceID}   || $Ticket{ServiceID};

            my $ConditionElement = "";

            # type
            if ( $Elements[1] eq 'Type' && $Param{TypeID} ) {
                my %TypeList = $Kernel::OM->Get('Kernel::System::Type')->TypeList( UserID => 1, );
                $ConditionElement = $TypeList{ $Param{TypeID} } || '';
            }
            elsif ( $Elements[1] eq 'Type' && $Ticket{Type} ) {
                $ConditionElement = $Ticket{Type};
            }

            # queue
            elsif ( $Elements[1] eq 'Queue' && $Param{QueueID} ) {
                my %QueueList = $Kernel::OM->Get('Kernel::System::Queue')->QueueList();
                $ConditionElement = $QueueList{ $Param{QueueID} } || '';
            }
            elsif ( $Elements[1] eq 'Queue' && $Ticket{Queue} ) {
                $ConditionElement = $Ticket{Queue};
            }

            # service
            elsif ( $Elements[1] eq 'Service' && $Param{ServiceID} ) {
                my %ServiceList
                    = $Kernel::OM->Get('Kernel::System::Service')->ServiceList( UserID => 1, );
                $ConditionElement = $ServiceList{ $Param{ServiceID} } || '';
            }
            elsif ( $Elements[1] eq 'Service' && $Ticket{Service} ) {
                $ConditionElement = $Ticket{Service};
            }

            # next state
            elsif (
                ( $Elements[1] eq 'NextState' || $Elements[1] eq 'State' )
                && ( $Param{NextStateID} )
                )
            {
                my %StateList
                    = $Kernel::OM->Get('Kernel::System::State')->StateList( UserID => 1, );
                $ConditionElement = $StateList{ $Param{NextStateID} } || '';
            }
            elsif (
                ( $Elements[1] eq 'NextState' || $Elements[1] eq 'State' )
                && ( $Ticket{State} )
                )
            {
                $ConditionElement = $Ticket{State};
            }

            # priority
            elsif ( $Elements[1] eq 'Priority' && defined $Param{PriorityID} ) {
                my %PriorityList = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList();
                $ConditionElement = $PriorityList{ $Param{PriorityID} } || '';
            }
            elsif ( $Elements[1] eq 'Priority' && defined $Ticket{Priority} ) {
                $ConditionElement = $Ticket{Priority};
            }

            # if condition is satisfied - remember the dynamic fields to remove...
            if (
                ( !$RegExpPatternCondition && $Elements[2] eq $ConditionElement )
                || ( !$RegExpPatternCondition && $Elements[2] eq 'EMPTY' && !$ConditionElement )
                || ( $RegExpPatternCondition && $ConditionElement && $ConditionElement =~ /$RegExpPatternCondition/ )
                )
            {

                my $Regexp = $DisabledDynamicFieldConfig->{$RestrictedDynamicField};
                for my $DynamicField ( @{$DynamicFieldList} ) {
                    next if $DynamicField->{Name} !~ /$Regexp/;
                    $DisabledDynamicFieldHash{ $DynamicField->{Name} } = 0;
                }
            }
        }
    }

    # return data
    $Param{Acl}->{'991_DisabledDynamicFields'} = {
        Possible => {
            Form => \%DisabledDynamicFieldHash
        },
    };
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
