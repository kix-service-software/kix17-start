# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ToolBar::ArticleFlag;

use strict;
use warnings;

our @ObjectDependencies = (
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
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $StateObject  = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get pending states
    my @PendingReminderStateIDs = $StateObject->StateGetStatesByType(
        Type   => 'PendingReminder',
        Result => 'ID',
    );

    # get user lock data
    my $Count = $TicketObject->TicketSearch(
        Result      => 'COUNT',
        UserID      => $Self->{UserID},
        ArticleFlag => $Param{Config}->{ArticleFlagKey},
        Permission  => 'ro',
    );
    my $CountReached = 0;
    if ( @PendingReminderStateIDs ) {
        $CountReached = $TicketObject->TicketSearch(
            Result                        => 'COUNT',
            UserID                        => $Self->{UserID},
            ArticleFlag                   => $Param{Config}->{ArticleFlagKey},
            StateIDs                      => \@PendingReminderStateIDs,
            TicketPendingTimeOlderMinutes => 1,
            Permission                    => 'ro',
        );
    }
    my $CountNew = $TicketObject->TicketSearch(
        Result        => 'COUNT',
        UserID        => $Self->{UserID},
        ArticleFlag   => $Param{Config}->{ArticleFlagKey},
        NotTicketFlag => {
            Seen => 1,
        },
        Permission => 'ro',
    );

    my $Priority = $Param{Config}->{Priority};
    my $URL      = $LayoutObject->{Baselink}
        . 'Action=AgentTicketArticleFlagView;ArticleFlag='
        . $Param{Config}->{ArticleFlagKey} . ';';
    my $Description = $LayoutObject->{LanguageObject}->Translate( $Param{Config}->{Description} );

    my %Return;
    if ($CountNew) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Count       => $CountNew,
            Description => $Description . ' '
                . $LayoutObject->{LanguageObject}->Translate('Tickets New'),
            Icon      => $Param{Config}->{IconNew},
            Class     => $Param{Config}->{CssClassNew},
            Link      => $URL . 'Filter=New',
            AccessKey => $Param{Config}->{AccessKey},
        };
    }
    if ($CountReached) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Count       => $CountReached,
            Description => $Description . ' '
                . $LayoutObject->{LanguageObject}->Translate('Tickets Reminder Reached'),
            Class     => $Param{Config}->{CssClassReached},
            Icon      => $Param{Config}->{IconReached},
            Link      => $URL . 'Filter=ReminderReached',
            AccessKey => $Param{Config}->{AccessKey},
        };
    }
    if ($Count) {
        $Return{ $Priority++ } = {
            Block       => 'ToolBarItem',
            Count       => $Count,
            Description => $Description . ' '
                . $LayoutObject->{LanguageObject}->Translate('Tickets Total'),
            Class     => $Param{Config}->{CssClass},
            Icon      => $Param{Config}->{Icon},
            Link      => $URL,
            AccessKey => $Param{Config}->{AccessKey},
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
