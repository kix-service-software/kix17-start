#!/usr/bin/perl
# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin).'/../../';
use lib dirname($RealBin).'/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update-17.5.0.pl',
    },
);

use vars qw(%INC);

# Add a default quick state if state "closed successful" exists
_AddDefaultQuickState();

exit 0;

sub _AddDefaultQuickState {
    my $StateObject      = $Kernel::OM->Get('Kernel::System::State');
    my $QuickStateObject = $Kernel::OM->Get('Kernel::System::QuickState');
    my $ValidObject      = $Kernel::OM->Get('Kernel::System::Valid');
    my $LogObject        = $Kernel::OM->Get('Kernel::System::Log');

    # get state list
    my %StateList = $StateObject->StateList(
        UserID => 1,
        Valid  => 0
    );

    # get valid list
    my %ValidList = $ValidObject->ValidList();

    my %StateListReverse = reverse(%StateList);
    my %ValidListReverse = reverse(%ValidList);

    if (%StateList) {
        my @StateListKeys = sort keys %StateListReverse;
        if ( grep( { 'closed successful' eq $_ } @StateListKeys ) ) {
            my $Success = $QuickStateObject->QuickStateAdd(
                Name    => 'Ticket Schließen',
                StateID => $StateListReverse{'closed successful'},
                ValidID => $ValidListReverse{'valid'},
                Config  => '',
                UserID  => 1
            );

            if (!$Success) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Unable to add quick state 'Ticket Schließen'!"
                );
            }
        }
    }

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
