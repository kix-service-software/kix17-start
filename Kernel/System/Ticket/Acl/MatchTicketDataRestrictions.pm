# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::System::Ticket::Acl::MatchTicketDataRestrictions;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create required objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $ExcludedTicketData = $Self->{ConfigObject}->Get('Match::ExcludedTicketData');

    # get restricted ticket actions
    my $IdentifiersRef = $Self->{ConfigObject}->Get('Match::ExcludedTicketData::Identifier') || '';
    return if ( !$IdentifiersRef || ref($IdentifiersRef) ne 'ARRAY' );

    # get ticket action match properties
    my $MatchActionsRef
        = $Self->{ConfigObject}->Get('Match::ExcludedTicketData::ActionsMatch') || '';
    return if ( !$MatchActionsRef || ref($MatchActionsRef) ne 'HASH' );

    # get ticket data match properties
    my $MatchTicketDataRef
        = $Self->{ConfigObject}->Get('Match::ExcludedTicketData::DataMatch') || '';
    return if ( !$MatchTicketDataRef || ref($MatchTicketDataRef) ne 'HASH' );

    # get ticket data restrictions
    my $RestrictedTicketDataRef
        = $Self->{ConfigObject}->Get('Match::ExcludedTicketData::DataRestricted') || '';
    return if ( !$RestrictedTicketDataRef || ref($RestrictedTicketDataRef) ne 'HASH' );

    # add additional information to restriction hash
    if ( $ExcludedTicketData && ref $ExcludedTicketData eq 'HASH' ) {
        for my $Item ( sort keys %{$ExcludedTicketData} ) {
            next if grep(/$Item/,@{$IdentifiersRef});
            push @{$IdentifiersRef},$Item;
            $MatchActionsRef->{$Item} = $ExcludedTicketData->{$Item}->{ActionsMatch};
            $MatchTicketDataRef->{$Item} = $ExcludedTicketData->{$Item}->{DataMatch};
            $RestrictedTicketDataRef->{$Item} = $ExcludedTicketData->{$Item}->{DataRestricted};
        }
    }

    # build ACL for each identifier
    for my $Identifier ( @{$IdentifiersRef} ) {
        next if !$MatchActionsRef->{$Identifier};
        next if !defined( $MatchTicketDataRef->{$Identifier} );
        next if !$RestrictedTicketDataRef->{$Identifier};

        # build action restriction
        my @PropertiesAction = split( ';', $MatchActionsRef->{$Identifier} );

        # build ticket data restriction as hash with array references (e.g. Type => ['default'], Queue => ['Raw'])
        my %PropertiesTicket;
        my @MatchRestrictions = split( '\|\|\|', $MatchTicketDataRef->{$Identifier} );
        for my $Criteria (@MatchRestrictions) {
            my @MatchTicket = split( ':::', $Criteria );
            if ( $MatchTicket[0] && $MatchTicket[1] ) {
                my @MatchValues = split( ';', $MatchTicket[1] );
                $PropertiesTicket{ $MatchTicket[0] } = \@MatchValues;
            }
            if ( $MatchTicket[0] && $MatchTicket[1] ) {
                my @MatchValues = split( ';', $MatchTicket[1] );
                $PropertiesTicket{ $MatchTicket[0] } = \@MatchValues;
            }
        }

        # build blacklist as hash with array references (e.g. Type => ['default'], Queue => ['Raw'])
        my %Blacklist;
        my @RestrictionsTicket = split( '\|\|\|', $RestrictedTicketDataRef->{$Identifier} );
        for my $RestrictionTicket (@RestrictionsTicket) {
            my @Restriction = split( ':::', $RestrictionTicket );
            next if ( !$Restriction[0] || !$Restriction[1] );
            my @RestrictionValues = split( ';', $Restriction[1] );
            $Blacklist{ $Restriction[0] } = \@RestrictionValues;
        }

        if (%Blacklist) {
            $Param{Acl}->{ '802_MatchTicketDataRestrictions' . $Identifier } = {
                Properties => {
                    Frontend => {
                        Action => \@PropertiesAction,
                    },
                    Ticket => \%PropertiesTicket,
                },
                PossibleNot => {
                    Ticket => \%Blacklist,
                },
            };
        }
    }

    return 1;
}

1;
