# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ToolBar::TicketWatcher;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Output::HTML::Layout',
    'Kernel::System::Log',
    'Kernel::System::State',
    'Kernel::System::Ticket',
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

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StateObject  = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check watcher feature
    return if !$ConfigObject->Get('Ticket::Watcher');

    # check access
    my @Groups;
    if ( $ConfigObject->Get('Ticket::WatcherGroup') ) {
        @Groups = @{ $ConfigObject->Get('Ticket::WatcherGroup') };
    }
    if (@Groups) {
        my $Access = 0;
        GROUP:
        for my $Group (@Groups) {
            next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
            if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                $Access = 1;
                last GROUP;
            }
        }

        # return on no access
        return if !$Access;
    }

    # get pending states
    my @PendingReminderStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingReminder',
        Result => 'ID',
    );

    # find watched tickets
    my $Count = $TicketObject->TicketSearch(
        Result       => 'COUNT',
        WatchUserIDs => [ $Self->{UserID} ],
        UserID       => 1,
        Permission   => 'ro',
    );
    my $CountNew = $TicketObject->TicketSearch(
        Result       => 'COUNT',
        WatchUserIDs => [ $Self->{UserID} ],
        TicketFlag   => {
            Seen => 1,
        },
        TicketFlagUserID => $Self->{UserID},
        UserID           => 1,
        Permission       => 'ro',
    );
    $CountNew = $Count - $CountNew;

    my $CountReached = 0;
    if ( @PendingReminderStateIDs ) {
        $CountReached = $TicketObject->TicketSearch(
            Result                        => 'COUNT',
            WatchUserIDs                  => [ $Self->{UserID} ],
            StateIDs                      => \@PendingReminderStateIDs,
            TicketPendingTimeOlderMinutes => 1,
            UserID                        => 1,
            Permission                    => 'ro',
        );
    }

    my $Class        = $Param{Config}->{CssClass};
    my $ClassNew     = $Param{Config}->{CssClassNew};
    my $ClassReached = $Param{Config}->{CssClassReached};

    my $Icon        = $Param{Config}->{Icon};
    my $IconNew     = $Param{Config}->{IconNew};
    my $IconReached = $Param{Config}->{IconReached};

    my $URL = $LayoutObject->{Baselink};
    my %Return;
    my $Priority = $Param{Config}->{Priority};
    if ($CountNew) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Description => Translatable('Watched Tickets New'),
            Count       => $CountNew,
            Class       => $ClassNew,
            Icon        => $IconNew,
            Link        => $URL . 'Action=AgentTicketWatchView;Filter=New',
            AccessKey   => $Param{Config}->{AccessKeyNew} || '',
        };
    }
    if ($CountReached) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Description => Translatable('Watched Tickets Reminder Reached'),
            Count       => $CountReached,
            Class       => $ClassReached,
            Icon        => $IconReached,
            Link        => $URL . 'Action=AgentTicketWatchView;Filter=ReminderReached',
            AccessKey   => $Param{Config}->{AccessKeyReached} || '',
        };
    }
    if ($Count) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Description => Translatable('Watched Tickets Total'),
            Count       => $Count,
            Class       => $Class,
            Icon        => $Icon,
            Link        => $URL . 'Action=AgentTicketWatchView',
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
