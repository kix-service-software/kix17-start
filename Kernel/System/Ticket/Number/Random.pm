# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Number::Random;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

sub TicketCreateNumber {
    my $Self = shift;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get needed config options
    my $SystemID = $ConfigObject->Get('SystemID');

    # random counter
    my $Count = int rand 9999999999;

    $Count = sprintf "%.*u", 10, $Count;

    # create new ticket number
    my $Tn = $SystemID . $Count;

    # Check ticket number. If exists generate new one!
    if ( $Self->TicketCheckNumber( Tn => $Tn ) ) {

        $Self->{LoopProtectionCounter}++;

        if ( $Self->{LoopProtectionCounter} >= 16000 ) {

            # loop protection
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "CounterLoopProtection is now $Self->{LoopProtectionCounter}!"
                    . " Stopped TicketCreateNumber()!",
            );
            return;
        }

        # create new ticket number again
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Tn ($Tn) exists! Creating a new one.",
        );

        $Tn = $Self->TicketCreateNumber();
    }

    return $Tn;
}

sub GetTNByString {
    my ( $Self, $String ) = @_;

    if ( !$String ) {
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get needed config options
    my $CheckSystemID = $ConfigObject->Get('Ticket::NumberGenerator::CheckSystemID');
    my $SystemID      = '';

    if ($CheckSystemID) {
        $SystemID = $ConfigObject->Get('SystemID');
    }

    my $TicketHook        = $ConfigObject->Get('Ticket::Hook');
    my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider');

    # check current setting
    if ( $String =~ /\Q$TicketHook$TicketHookDivider\E($SystemID\d{2,20})/i ) {
        return $1;
    }

    # check default setting
    if ( $String =~ /\Q$TicketHook\E:\s{0,2}($SystemID\d{2,20})/i ) {
        return $1;
    }

    return;
}

sub GetTNArrayByString {
    my ( $Self, $String ) = @_;

    if ( !$String ) {
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get needed config options
    my $CheckSystemID = $ConfigObject->Get('Ticket::NumberGenerator::CheckSystemID');
    my $SystemID      = '';

    if ($CheckSystemID) {
        $SystemID = $ConfigObject->Get('SystemID');
    }

    my $TicketHook        = $ConfigObject->Get('Ticket::Hook');
    my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider');

    # check current setting
    if ( $String =~ /\Q$TicketHook$TicketHookDivider\E($SystemID\d{2,20})/i ) {
        my @Result = ( $String =~ /\Q$TicketHook$TicketHookDivider\E($SystemID\d{2,20})/ig );
        return @Result;
    }

    # check default setting
    if ( $String =~ /\Q$TicketHook\E:\s{0,2}($SystemID\d{2,20})/i ) {
        my @Result = ( $String =~ /\Q$TicketHook\E:\s{0,2}($SystemID\d{2,20})/ig );
        return @Result;
    }

    return;
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
