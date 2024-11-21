# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::NavBar::AgentTicketService;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
);

use Kernel::System::ObjectManager;

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

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check if frontend module is registered (otherwise return)
    my $Config = $ConfigObject->Get('Frontend::Module')->{AgentTicketService};
    return if !$Config;

    # check if ticket service feature is enabled, in such case there is nothing to do
    return if $ConfigObject->Get('Ticket::Service');

    # frontend module is enabled but not ticket service, then remove the menu entry
    my $NavBarName = $Config->{NavBarName};
    my $Priority = sprintf( "%07d", $Config->{NavBar}->[0]->{Prio} );

    my %Return = %{ $Param{NavBar}->{Sub} };

    # remove AgentTicketService from the TicketMenu
    delete $Return{$NavBarName}->{$Priority};

    return ( Sub => \%Return );
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
