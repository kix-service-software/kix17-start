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
package Kernel::System::Ticket::Acl::RestrictTicketActionsOnMerged;

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

    return if ( !$Param{Action} || $Param{Action} !~ /^Agent/ );

    # get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Actions = $Self->{ConfigObject}->Get('Ticket::RestrictTicketActionsOnMerged::ActionsMapping');
    return if ( !$Actions || ref($Actions) ne 'HASH' );

    my @RestrictedActions = ();
    for my $Action ( keys %{$Actions} ) {
        next if $Actions->{$Action};
        push @RestrictedActions, $Action;
    }

    $Param{Acl}->{'500_RestrictTicketActionsOnMerged'} = {

        # match properties
        Properties => {
            Ticket => {
                State => [ 'merged', 'removed' ],
            },
        },

        # return possible options (white list)
        PossibleNot => {
            Action => \@RestrictedActions
        },
        StopAfterMatch => 1,
    };

    return 1;
}

1;
