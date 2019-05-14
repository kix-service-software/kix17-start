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
use utf8;

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
        LogPrefix => 'db-update-17.6.0.pl',
    },
);

use vars qw(%INC);

# migrate configuration of AgentOverlay with a prefix
_MigrateDBNotificationEvents();

exit 0;

sub _MigrateDBNotificationEvents {

    # get needed object
    my $NotificationEventObject = $Kernel::OM->Get('Kernel::System::NotificationEvent');

    my %List = $NotificationEventObject->NotificationList(
        Details => 1,
        All     => 1,
    );

    return 1 if !%List;

    ITEM:
    for my $ID ( sort keys %List ) {
        my %Data = %{$List{$ID}};
        next ITEM if !grep( { $_ eq 'AgentOverlay' } @{$Data{Data}->{Transports}} );

        my $Count = 0;
        TRANSPORT:
        for my $Transport ( @{$Data{Data}->{Transports}}) {
            if ( $Transport eq 'AgentOverlay' ) {
                KEY:
                for my $Key (qw(RecipientDecay RecipientBusinessTime RecipientPopup)) {
                    next KEY if !$Data{Data}->{$Key};
                    next KEY if !defined $Data{Data}->{$Key}>[0];
                    $Data{Data}->{'AgentOverlay' . $Key} = $Data{Data}->{$Key}->[0];
                    delete $Data{Data}->{$Key};
                }
                $Data{Data}->{'AgentOverlayRecipientSubject'} = $Data{Data}->{RecipientSubject}->[$Count];
                splice( @{$Data{Data}->{RecipientSubject}}, $Count, 1);
                $NotificationEventObject->NotificationUpdate(
                    %Data,
                    UserID => 1
                );

                last TRANSPORT;
            }
            $Count++;
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
