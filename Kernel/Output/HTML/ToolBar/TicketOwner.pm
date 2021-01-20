# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ToolBar::TicketOwner;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::Output::HTML::Layout',
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

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get user lock data
    my $Count = $TicketObject->TicketSearch(
        Result     => 'COUNT',
        StateType  => 'Open',
        OwnerIDs   => [ $Self->{UserID} ],
        UserID     => 1,
        Permission => 'ro',
    );
    my $CountNew = $TicketObject->TicketSearch(
        Result     => 'COUNT',
        StateType  => 'Open',
        OwnerIDs   => [ $Self->{UserID} ],
        TicketFlag => {
            Seen => 1,
        },
        TicketFlagUserID => $Self->{UserID},
        UserID           => 1,
        Permission       => 'ro',
    );
    $CountNew = $Count - $CountNew;
    my $CountReached = $TicketObject->TicketSearch(
        Result                        => 'COUNT',
        StateType                     => ['pending reminder'],
        TicketPendingTimeOlderMinutes => 1,
        OwnerIDs                      => [ $Self->{UserID} ],
        UserID                        => 1,
        Permission                    => 'ro',
    );

    my $Class        = $Param{Config}->{CssClass};
    my $ClassNew     = $Param{Config}->{CssClassNew};
    my $ClassReached = $Param{Config}->{CssClassReached};

    my $Icon        = $Param{Config}->{Icon};
    my $IconNew     = $Param{Config}->{IconNew};
    my $IconReached = $Param{Config}->{IconReached};

    my $URL = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{Baselink};
    my %Return;
    my $Priority = $Param{Config}->{Priority};
    if ($CountNew) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Count       => $CountNew,
            Description => Translatable('Owner Tickets New'),
            Class       => $ClassNew,
            Icon        => $IconNew,
            Link        => $URL . 'Action=AgentTicketOwnerView;Filter=New',
            AccessKey   => $Param{Config}->{AccessKeyNew} || '',
        };
    }
    if ($CountReached) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Count       => $CountReached,
            Description => Translatable('Owner Tickets Reminder Reached'),
            Class       => $ClassReached,
            Icon        => $IconReached,
            Link        => $URL . 'Action=AgentTicketOwnerView;Filter=ReminderReached',
            AccessKey   => $Param{Config}->{AccessKeyReached} || '',
        };
    }
    if ($Count) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Count       => $Count,
            Description => Translatable('Owner Tickets Total'),
            Class       => $Class,
            Icon        => $Icon,
            Link        => $URL . 'Action=AgentTicketOwnerView',
            AccessKey   => $Param{Config}->{AccessKey} || '',
        };
    }
    return %Return;
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
