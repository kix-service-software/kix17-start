# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PreEventHandler;

use strict;
use warnings;

=head1 NAME

Kernel::System::PreEventHandler - pre-event handler lib

=head1 SYNOPSIS

All pre-event handler functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item PreEventHandlerInit()

use vars qw(@ISA);
use Kernel::System::PreEventHandler;
push @ISA, 'Kernel::System::PreEventHandler';

    $Self->PreEventHandlerInit(

        # name of configured event modules
        Config     => 'Example::EventModule',

        # current object, $Self, used in events as "ExampleObject"
        BaseObject => 'ExampleObject',

        # served default objects in any event backend
        Objects    => {
            UserObject => $UserObject,
            XZY        => $XYZ,
        },
    );

e. g.

    $Self->PreEventHandlerInit(
        Config     => 'Ticket::PreEventModule',
        BaseObject => 'TicketObject',
        Objects    => {
            UserObject  => $UserObject,
            GroupObject => $GroupObject,
        },
    );

Example XML config:

    <ConfigItem Name="Example::PreEventModule###99-EscalationIndex" Required="0" Valid="1">
        <Description Lang="en">Example event module updates the example escalation index.</Description>
        <Description Lang="de">Example PreEvent Modul aktualisiert den Example Eskalations-Index.</Description>
        <Group>Example</Group>
        <SubGroup>Core::Example</SubGroup>
        <Setting>
            <Hash>
                <Item Key="Module">Kernel::System::Example::PreEvent::ExampleEscalationIndex</Item>
                <Item Key="Event">(ExampleSLAUpdate|ExampleQueueUpdate|ExampleStateUpdate|ExampleCreate)</Item>
                <Item Key="SomeOption">Some Option accessable via $Param{Config}->{SomeOption} in Run() of event module.</Item>
                <Item Key="Transaction">(0|1)</Item>
            </Hash>
        </Setting>
    </ConfigItem>

=cut

sub PreEventHandlerInit {
    my ( $Self, %Param ) = @_;

    $Self->{PreEventHandlerInit} = \%Param;

    return 1;
}

=item PreEventHandler()

call event handler, returns true if it's executed successfully

    $PreEventHandler->PreEventHandler(
        Event => 'TicketStateUpdate',
        Data  => {
            TicketID => 123,
        },
        UserID => 123,
    );

=cut

sub PreEventHandler {
    my ( $Self, %Param ) = @_;

    my $Result          = undef;
    my $CollectedResult = undef;

    # check needed stuff
    for (qw(Data Event UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    #return if pre-events are skipped
    return 1 if ( $Param{Data} && ref( $Param{Data} ) eq 'HASH' && $Param{Data}->{SkipPreEvent} );

    # get configured modules
    my $Modules = $Kernel::OM->Get('Kernel::Config')->Get( $Self->{PreEventHandlerInit}->{Config} );

    # return if there is no one
    return 1 if !$Modules;

    # load modules and execute
    MODULE:
    for my $Module ( sort keys %{$Modules} ) {

        # execute only if configured (regexp in Event of config is possible)
        if ( !$Modules->{$Module}->{Event} || $Param{Event} =~ /$Modules->{$Module}->{Event}/ ) {

            # load event module
            next MODULE if !$Kernel::OM->Get('Kernel::System::Main')->Require( $Modules->{$Module}->{Module} );

            # get all default objects if given
            my $ObjectRef = $Self->{PreEventHandlerInit}->{Objects};
            my %Objects;
            if ($ObjectRef) {
                %Objects = %{$ObjectRef};
            }

            # execute event backend
            my $Generic = $Modules->{$Module}->{Module}->new(
                %Objects,
                $Self->{PreEventHandlerInit}->{BaseObject} => $Self,
            );

            # compatable to old
            # OTRS 3.x: REMOVE ME
            if ( $Param{Data} ) {
                %Param = ( %Param, %{ $Param{Data} } );
            }

            $Result = $Generic->Run(
                %Param,
                Config => $Modules->{$Module},
            );

            if ( ref($Result) eq 'HASH' && $Result->{Error} ) {
                return $Result;
            }
            elsif ( ref($Result) eq 'HASH' && scalar( keys( %{$Result} ) ) ) {
                for my $ResultKey ( keys %{$Result} ) {
                    $Param{$ResultKey}             = $Result->{$ResultKey};
                    $CollectedResult->{$ResultKey} = $Result->{$ResultKey};
                    $Param{Data}->{$ResultKey}     = $Param{$ResultKey};
                }
            }
        }
    }

    return $CollectedResult;
}

1;


=head1 VERSION

$Revision$ $Date$

=cut



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
