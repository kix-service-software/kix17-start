#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

# remove obsolete perl files
_RemoveObsoleteFiles();

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
                    next KEY if( ref( $Data{Data}->{$Key} ) ne 'ARRAY' );

                    $Data{Data}->{'AgentOverlay' . $Key} = $Data{Data}->{$Key};
                    delete $Data{Data}->{$Key};
                }

                push( @{ $Data{Data}->{'AgentOverlayRecipientSubject'} }, $Data{Data}->{RecipientSubject}->[$Count] );
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

sub _RemoveObsoleteFiles {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @FilesList = (
        'Kernel/Output/HTML/Layout/KIX4OTRS.pm',
        'Kernel/Output/HTML/Layout/KIX4OTRSITSMConfigManagement.pm',
        'Kernel/Output/HTML/Layout/KIXBase.pm',
        'Kernel/Output/HTML/Templates/Standard/ChatDisplay.tt',
        'Kernel/Output/HTML/Templates/Standard/ChatStartForm.tt',
        'Kernel/Output/Template/Plugin/OTRS.pm',
        'var/httpd/htdocs/skins/Agent/default/img/kix4otrs_logo.png',
        'var/httpd/htdocs/skins/Agent/default/img/loginlogo_default.png',
        'var/httpd/htdocs/skins/Agent/default/img/logo-business.png',
        'var/httpd/htdocs/skins/Agent/default/img/logo_bg.png',
        'var/httpd/htdocs/skins/Agent/default/img/otrs-verify-small.png',
        'var/httpd/htdocs/skins/Agent/default/img/otrs-verify.png',
        'var/httpd/htdocs/skins/Agent/default/img/logo.psd',
        'var/httpd/htdocs/skins/Agent/default/img/logo_bg.psd',
        'var/httpd/htdocs/skins/Customer/default/img/logo.png',
        'var/stats/ITSMStats-400-ITSMChangeManagement.xml',
        'var/stats/ITSMStats-401-ITSMChangeManagement.xml',
        'var/stats/ITSMStats-402-ITSMChangeManagement.xml',
        'var/stats/ITSMStats-403-ITSMChangeManagement.xml',
        'var/stats/ITSMStats-404-ITSMChangeManagement.xml',
        'var/stats/ITSMStats-405-ITSMChangeManagement.xml',
        'var/stats/ITSMStats-406-ITSMChangeManagement.xml',
        'var/stats/ListOfOpenTicketsSortedByTimeLeftUntilEscalationDeadlineExpires.hu.xml',
        'var/stats/ListOfOpenTicketsSortedByTimeLeftUntilResponseDeadlineExpires.hu.xml',
        'var/stats/ListOfOpenTicketsSortedByTimeLeftUntilSolutionDeadlineExpires.hu.xml',
        'var/stats/ListOfTheMostTimeConsumingTickets.hu.xml',
        'var/stats/ListOfTicketsClosedLastMonth.hu.xml',
        'var/stats/ListOfTicketsClosedSortedByResponseTime.hu.xml',
        'var/stats/ListOfTicketsClosedSortedBySolutionTime.hu.xml',
        'var/stats/ListOfTicketsCreatedLastMonth.hu.xml',
        'var/stats/Stats.NewTickets.hu.xml',
        'var/stats/Stats.StatusActionOverview.hu.xml',
        'var/stats/Stats.TicketOverview.hu.xml'
    );

    for my $File ( @FilesList ) {
        my $Success = $MainObject->FileDelete(
            Location        => $HomePath . '/' . $File,
            Type            => 'Local',
            DisableWarnings => 1,
        );
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
