#!/usr/bin/perl
# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        LogPrefix => 'db-update-17.17.0.pl',
    },
);

use vars qw(%INC);

# save configuration
_SaveConfig();

# switched configuration
_SwitchConfig();

# remove obsolete files
_RemoveObsoleteFiles();

exit 0;

sub _SaveConfig {
    my ( $Self, %Param ) = @_;

    # get config values to save from config object
    my %ConfigBackup = ();
    for my $Key ( qw( Ticket::ACL-PossiblePropertiesSubsumption ) ) {
        $ConfigBackup{ $Key } = $Kernel::OM->Get('Kernel::Config')->Get( $Key );
    }

    # update SysConfig
    my $Result;
    for my $Key ( keys( %ConfigBackup ) ) {
        $Result = $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigItemUpdate(
            Key   => $Key,
            Value => $ConfigBackup{ $Key },
            Valid => 1,
        );
    }

    return $Result;
}

sub _SwitchConfig {
    my ( $Self, %Param ) = @_;

    # get config values to save from config object
    my %ConfigBackup = ();
    my $Config   = $Kernel::OM->Get('Kernel::Config')->Get( 'Ticket::Frontend::CustomerTicketTemplates' );
    for my $Key ( qw( UserAttributeRestriction ) ) {
        my $Data = $Config->{$Key};

        if ( ref $Data eq 'HASH' ) {
            for my $Entry ( sort keys %{$Data} ) {
                next ENTRY if $ConfigBackup{$Entry} && $ConfigBackup{$Entry} eq $Data->{$Entry};

                $ConfigBackup{$Entry} = $Data->{$Entry};
            }
        }
    }

    return if !%ConfigBackup;

    # update SysConfig
    my $Result = $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigItemUpdate(
        Key   => 'Ticket::Frontend::CustomerTicketTemplates###UserAttributeBlacklist',
        Value => \%ConfigBackup,
        Valid => 1,
    );

    return $Result;
}

sub _RemoveObsoleteFiles {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @FilesList = (
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.ACL.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.CloudServices.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.DynamicField.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.GenericInterface.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.NotificationEvent.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.OTRSBusiness.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.PerformanceLog.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.ProcessManagement.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.Registration.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.SupportDataCollector.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.SysConfig.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Admin.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.CustomerUser.OpenTicket.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.DaemonInfo.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Dashboard.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.HTMLReference.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Preferences.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.SortedTree.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Statistics.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.TicketMenuModuleCluster.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.TicketProcess.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Toolbar.CICSearch.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Agent.Toolbar.FulltextSearch.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.AgentTicketQueue.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.AgentTicketService.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.AllocationList.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Color.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Default.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Dialog.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Footer.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Form.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.GeoCoordinate.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Header.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.InputFields.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.OverviewControl.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.OverviewLarge.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.OverviewMedium.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.OverviewSmall.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.PageLayout.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Print.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Reset.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Responsive.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Table.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.TicketDetail.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Tooltip.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.Widget.css',
        'var/httpd/htdocs/skins/Agent/default/css/Core.WidgetMenu.css',
        'var/httpd/htdocs/skins/Agent/default/css/FAQ.Agent.Default.css',
        'var/httpd/htdocs/skins/Agent/default/css/FAQ.Agent.Detail.css',
        'var/httpd/htdocs/skins/Agent/default/css/ITSM.Agent.Default.css',
        'var/httpd/htdocs/skins/Agent/default/css/ITSM.Agent.Detail.IE7.css',
        'var/httpd/htdocs/skins/Agent/default/css/ITSM.Agent.Detail.css',
        'var/httpd/htdocs/skins/Agent/default/css/ITSM.Agent.Search.css',
        'var/httpd/htdocs/skins/Agent/default/css/ITSM.ImportExport.css',
        'var/httpd/htdocs/skins/Agent/default/css/ITSM.Print.css',
        'var/httpd/htdocs/skins/Agent/default/css/ITSM.Table.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.Agent.Admin.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.AgentCustomerDashboard.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.AgentITSMConfigItemZoomTab.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.AgentLinkGraph.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.AgentTicketMergeToCustomer.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.Default.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.DependingDynamicFields.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.Footer.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.Form.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.Header.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.ITSM.Agent.Detail.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.JSTree.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.OverviewControl.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.Table.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.TextModules.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIX4OTRS.TicketDetail.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXBase.Default.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXBase.Form.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXBase.JSTree.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXBase.Header.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXBase.Table.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXBase.TicketDetail.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXSidebarTools.KIXSidebarDisableSidebar.css',
        'var/httpd/htdocs/skins/Agent/default/css/KIXSidebarTools.css',
        'var/httpd/htdocs/skins/Agent/default/img/icons/kix.ico',
        'var/httpd/htdocs/skins/Agent/default/img/icons/kix4otrs.ico',
        'var/httpd/htdocs/skins/Agent/default/img/icons/product.ico',
        'var/httpd/htdocs/skins/Agent/default/img/KIX_logo.png',
        'var/httpd/htdocs/skins/Agent/default/img/element_header.png',
        'var/httpd/htdocs/skins/Agent/default/img/element_header_left.png',
        'var/httpd/htdocs/skins/Agent/default/img/element_header_right.png',
        'var/httpd/htdocs/skins/Agent/default/img/header_background_kix.jpg',
        'var/httpd/htdocs/skins/Agent/default/img/loader.gif',
        'var/httpd/htdocs/skins/Agent/default/img/login_background_kix.png',
        'var/httpd/htdocs/skins/Agent/default/img/toggle_arrow.png',
        'var/httpd/htdocs/skins/Agent/default/img/toggle_side_arrow.png',
        'var/httpd/htdocs/skins/Agent/default/img/zoom_sprite_extended.png',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Control.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Customer.TicketProcess.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Default.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Dialog.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Form.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.InputFields.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Login.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Print.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Reset.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Responsive.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Table.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.TicketZoom.css',
        'var/httpd/htdocs/skins/Customer/default/css/Core.Tooltip.css',
        'var/httpd/htdocs/skins/Customer/default/css/FAQ.Customer.Default.css',
        'var/httpd/htdocs/skins/Customer/default/css/FAQ.Customer.Detail.css',
        'var/httpd/htdocs/skins/Customer/default/css/FAQ.FAQZoom.css',
        'var/httpd/htdocs/skins/Customer/default/css/FAQ.Widget.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIX4OTRS.Control.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIX4OTRS.Default.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIX4OTRS.JSTree.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIX4OTRS.PageLayout.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIX4OTRS.Table.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIX4OTRS.TextModules.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIX4OTRS.Widget.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXBase.Default.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXBase.Form.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXBase.Header.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXBase.JSTree.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXBase.Table.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXBase.TicketDetail.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXSidebarTools.KIXSidebarDisableSidebar.css',
        'var/httpd/htdocs/skins/Customer/default/css/KIXSidebarTools.css',
        'var/httpd/htdocs/skins/Customer/default/img/icons/kix.ico',
        'var/httpd/htdocs/skins/Customer/default/img/GradientSmall.png',
        'var/httpd/htdocs/skins/Customer/default/img/KIX_logo.png',
        'var/httpd/htdocs/skins/Customer/default/img/dialog_alert.png',
        'var/httpd/htdocs/skins/Customer/default/img/element_header.png',
        'var/httpd/htdocs/skins/Customer/default/img/element_header_left.png',
        'var/httpd/htdocs/skins/Customer/default/img/element_header_right.png',
        'var/httpd/htdocs/skins/Customer/default/img/header_background.png',
        'var/httpd/htdocs/skins/Customer/default/img/header_background_kix.jpg',
        'var/httpd/htdocs/skins/Customer/default/img/loader.gif',
        'var/httpd/htdocs/skins/Customer/default/img/login_background_kix.png',
        'var/httpd/htdocs/skins/Customer/default/img/menu_separator.png',
        'var/httpd/htdocs/skins/Customer/default/img/textmodule.png',
        'var/httpd/htdocs/skins/Customer/default/img/tm_category.png',
        'var/KIX-printlogo.png',
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
