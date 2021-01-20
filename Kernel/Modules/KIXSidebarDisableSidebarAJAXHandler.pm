# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarDisableSidebarAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Log',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::Service',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Type',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}   = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{LogObject}      = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{PriorityObject} = $Kernel::OM->Get('Kernel::System::Priority');
    $Self->{QueueObject}    = $Kernel::OM->Get('Kernel::System::Queue');
    $Self->{ServiceObject}  = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{StateObject}    = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TicketObject}   = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{TypeObject}     = $Kernel::OM->Get('Kernel::System::Type');
    $Self->{ParamObject}    = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Param{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' ) || '';
    if ( $Param{Identifier} ) {
        my $KIXSidebarToolsConfig = $Self->{ConfigObject}->Get('KIXSidebarTools');
        for my $Data ( keys %{ $KIXSidebarToolsConfig->{Data} } ) {
            my ( $DataIdentifier, $DataAttribute ) = split( ':::', $Data, 2 );
            next if $Param{Identifier} ne $DataIdentifier;
            $Self->{SidebarConfig}->{$DataAttribute} =
                $KIXSidebarToolsConfig->{Data}->{$Data} || '';
        }
    }

    if ( !$Self->{SidebarConfig} ) {
        my $ConfigPrefix = '';
        if ( $Self->{LayoutObject}->{UserType} eq 'Customer' ) {
            $ConfigPrefix = 'Customer';
        }
        my $CompleteConfig
            = $Self->{ConfigObject}->Get( $ConfigPrefix . 'Frontend::KIXSidebarBackend' );
        if ( $CompleteConfig && ref($CompleteConfig) eq 'HASH' ) {
            $Self->{SidebarConfig} = $CompleteConfig->{ $Param{Identifier} }
                || $CompleteConfig->{'KIXSidebarSearchCIs'};
        }
    }
    $Self->{SidebarConfig}->{Identifier} = $Param{Identifier};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    for my $GetParam (qw{ CallingAction TicketID TypeID QueueID ServiceID PriorityID NextStateID Dest }) {
        $Param{$GetParam} = $Self->{ParamObject}->GetParam( Param => $GetParam ) || '';
    }
    my @SplitDest = split(/\|\|/, ($Param{Dest} || ''));
    if (scalar @SplitDest == 2) {
        $Param{Dest} = $SplitDest[0];
    }
    $Param{QueueID} ||= $Param{Dest};

    # check needed stuff
    for my $Needed (qw(CallingAction)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "DisableSidebars: Need $Needed!" );
            return;
        }
    }

    # set default params...
    if ( !defined $Param{ReturnType} ) {
        $Param{ReturnType} = 'Array';
    }
    my %TicketData = ();
    if ( $Param{TicketID} ) {
        %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID => $Param{TicketID},
            UserID   => 1,
        );
    }
    for my $CurrKey (qw{ TypeID QueueID ServiceID PriorityID }) {
        if ( !$Param{$CurrKey} && $TicketData{$CurrKey} ) {
            $Param{$CurrKey} = $TicketData{$CurrKey};
        }
    }
    if ( !$Param{NextStateID} && $TicketData{StateID} ) {
        $Param{NextStateID} = $TicketData{StateID};
    }

    # get type, service, state list
    my %TypeList     = $Self->{TypeObject}->TypeList( UserID => 1, );
    my %ServiceList  = $Self->{ServiceObject}->ServiceList( UserID => 1, );
    my %StateList    = $Self->{StateObject}->StateList( UserID => 1, );
    my %QueueList    = $Self->{QueueObject}->QueueList();
    my %PriorityList = $Self->{PriorityObject}->PriorityList();

    # get config
    my $DisabledSidebarsRef
        = $Self->{ConfigObject}->Get('Frontend::KIXSidebarBackend::DisabledSidebars');
    my %DisabledSidebars;
    if ( $DisabledSidebarsRef && ref($DisabledSidebarsRef) eq 'HASH' ) {
        %DisabledSidebars = %{ $DisabledSidebarsRef };
    }

    # cycle through disabled fields
    my @SidebarAJAX = qw{};
    RULE:
    for my $RestrictedSidebar ( keys %DisabledSidebars ) {
        next RULE if !$RestrictedSidebar;

        # check valid action
        my @ActionRestrictions = split /###/, $RestrictedSidebar;
        my $MatchRuleString;
        if ( $ActionRestrictions[0] && $ActionRestrictions[1] ) {
            next RULE
                if (
                $ActionRestrictions[0] ne $Param{CallingAction}
                && $Param{CallingAction} !~ /$ActionRestrictions[0]/
                );
            $MatchRuleString = $ActionRestrictions[1];
        }
        else {
            $MatchRuleString = $ActionRestrictions[0];
        }

        # check data match
        my @MatchRules = split( '\|\|\|', $MatchRuleString );

        MATCHRULE:
        for my $MatchRule (@MatchRules) {

            my @Restriction = split( ':::', $MatchRule );
            next MATCHRULE if ( !$Restriction[0] || !$Restriction[1] );

            my $ValueMatched = 0;
            my @RestrictionValues = split( ';', $Restriction[1] );
            RESTRICTEDVALUE:
            for my $RestrictionValue (@RestrictionValues) {

                my $RegExpPatternCondition = "";
                if ( $RestrictionValue =~ /^\[regexp\](.*)$/ ) {
                    $RegExpPatternCondition = $1;
                }

                my $ConditionElement = "";

                # type
                if ( $Restriction[0] eq 'Type' && $Param{TypeID} ) {
                    $ConditionElement = $TypeList{ $Param{TypeID} } || '';
                }

                # queue
                elsif ( $Restriction[0] eq 'Queue' && $Param{QueueID} ) {
                    $ConditionElement = $QueueList{ $Param{QueueID} } || '';
                }

                # service
                elsif ( $Restriction[0] eq 'Service' && $Param{ServiceID} ) {
                    $ConditionElement = $ServiceList{ $Param{ServiceID} } || '';
                }

                # next state
                elsif (
                    ( $Restriction[0] eq 'NextState' || $Restriction[0] eq 'State' )
                    && defined $Param{NextStateID}
                ) {
                    $ConditionElement = $StateList{ $Param{NextStateID} } || '';
                }

                # priority
                elsif ( $Restriction[0] eq 'Priority' && defined $Param{PriorityID} ) {
                    $ConditionElement = $PriorityList{ $Param{PriorityID} } || '';
                }

                # if condition is satisfied - remember the dynamic fields to remove...
                if (
                    ( !$RegExpPatternCondition && $RestrictionValue eq $ConditionElement )
                    || (
                        !$RegExpPatternCondition
                        && $RestrictionValue eq 'EMPTY'
                        && !$ConditionElement
                    )
                    || ( $RegExpPatternCondition && $ConditionElement =~ /$RegExpPatternCondition/ )
                ) {
                    $ValueMatched = 1;
                    last RESTRICTEDVALUE;
                }
            }

            # check match of restriction
            if ( $ValueMatched == 0 ) {
                next RULE;
            }
        }

        # create array of restrictions
        my @RestrictedSidebarNames = split( ',', $DisabledSidebars{$RestrictedSidebar} || '' );
        if ( scalar @RestrictedSidebarNames ) {
            SIDEBAR:
            for my $Sidebar (@RestrictedSidebarNames) {
                next SIDEBAR if grep({/^$Sidebar$/} @SidebarAJAX);
                push @SidebarAJAX, $Sidebar;
            }
        }
    }

    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset='
            . $Self->{LayoutObject}->{Charset},
        Content => join(",", @SidebarAJAX),
        Type    => 'inline',
        NoCache => 1,
    );
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
