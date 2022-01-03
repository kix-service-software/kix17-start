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
        LogPrefix => 'kix-upgrade-to-17.pl',
    },
);

use vars qw(%INC);

my %Opts;
getopt( 'f', \%Opts );

# get installed packages
my %InstalledPackages;
my $Result = $Kernel::OM->Get('Kernel::System::DB')->Prepare(
    SQL => 'SELECT name FROM package_repository',
);
if (!$Result) {
    print STDERR "Unable to execute SQL to get installed packages!\n"; 
}
else {
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $InstalledPackages{$Row[0]} = 1;
    }
}

# define possibly existing DB tables
my %PackageTables = (
    kix_article_flag => 'KIX4OTRS',
    kix_customer_company_prefs => 'KIX4OTRS',
    kix_dep_dynamic_field => 'KIX4OTRS',
    kix_dep_dynamic_field_prefs => 'KIX4OTRS',
    kix_file_watcher => 'KIX4OTRS',
    kix_text_module => 'KIX4OTRS',
    kix_text_module_object_link => 'KIX4OTRS',
    kix_ticket_notes => 'KIX4OTRS',
    kix_ticket_template => 'KIX4OTRS',
    kix_ticket_template_prefs => 'KIX4OTRS',
    kix_text_module_category => 'KIX4OTRS',
    kix_search_profile => 'KIX4OTRS',
    kix_link_graph => 'KIX4OTRS',
    kix_ticket_checklist => 'KIX4OTRS',
    overlay_agent => 'NotificationEventX',
    standard_templatex => 'TemplateX',
    attachment_directory =>  'ITSM-CIAttributeCollection',
    attachment_dir_preferences => 'ITSM-CIAttributeCollection',
    attachment_storage => 'ITSM-CIAttributeCollection',
);

# create database tables and insert initial values
my $XMLFile = $Kernel::OM->Get('Kernel::Config')->Get('Home').'/scripts/database/update/kix-upgrade-to-17.xml';
if ( ! -f "$XMLFile" ) {
    print STDERR "File \"$XMLFile\" doesn't exist!\n"; 
    exit 1;
}
my $XML = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
    Location => $XMLFile,
);
if (!$XML) {
    print STDERR "Unable to read file \"$XMLFile\"!\n"; 
    exit 1;
}

my @XMLArray = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
    String => $XML,
);
if (!@XMLArray) {
    print STDERR "Unable to parse file \"$XMLFile\"!\n"; 
    exit 1;
}

my @SQL = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessor(
    Database => \@XMLArray,
);
if (!@SQL) {
    print STDERR "Unable to create SQL from file \"$XMLFile\"!\n"; 
    exit 1;
}

for my $SQL (@SQL) {
    # ignore create statement if table already exists, because a specific package is already installed
    if ($SQL =~ /CREATE TABLE (.*?)\s+/g) {
        next if ($PackageTables{$1} && $InstalledPackages{$PackageTables{$1}});
    }
    # ignore alter table statement if table doesn't exist, because a specific package isn't installed 
    if ($SQL =~ /ALTER TABLE (.*?)\s+/g) {
        next if ($PackageTables{$1} && !$InstalledPackages{$PackageTables{$1}});
    }
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute SQL from file \"$XMLFile\"!\n"; 
    }
}

# execute post SQL statements (indexes, constraints)
my @SQLPost = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessorPost();
for my $SQL (@SQLPost) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute POST SQL!\n"; 
    }
}

# delete all obsolete packages
my @ObsoletePackages = (
    'KIXBase',
    'NotificationEventX',
    'TicketPrintRichtext',
    'KIXSidebarTools',
    'BPMX',
    'KIX4OTRS',
    'KIXCore',
    'QueuesGroupsRoles',
    'HidePendingTimeInput',
    'ExternalSupplierForwarding',
    'TemplateX',
    'ServiceImportExport',
    'UserImportExport',
    'CustomerCompanyImportExport',
    'CustomerUserImportExport',
    'FAQImportExport',
    'DynamicFieldRemoteDB',
    'DynamicFieldITSMConfigItem',
    'SystemMonitoringX',
    'ITSM',
    'ITSMIncidentProblemManagement',
    'ITSMServiceLevelManagement',
    'ITSMConfigurationManagement',
    'ITSMCore',
    'ITSM-CIAttributeCollection',
    'ImportExport',
    'GeneralCatalog',
    'FAQ',
);

if ($InstalledPackages{KIXBasePro}) {
    @ObsoletePackages = (
        @ObsoletePackages,
        'KIXWidespreadIncident',
        'KIXTemplateWorkflows',
        'KIXServiceCatalog',
        'KIXOptimizedCMDB',
        'ITSM-CIAdminModules',
        'InventorySync',
        'FileExchange',
        'KIXCMDBExplorer',
        'CMDB4Customer',
        'KIXCalendar',
    );

    my $XMLPackageContent = <<'EOT';
<?xml version="1.0" encoding="utf-8" ?>
<otrs_package version="1.1">
    <Name>KIXPro</Name>
    <Version>16.1.0</Version>
</otrs_package>
EOT
    
    # create "fake" KIXPro package entry for update installation
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL  => "UPDATE package_repository SET name = 'KIXPro', version = '16.1.0', content = ? WHERE name = ?",
        Bind => [
            \$XMLPackageContent,
            \'KIXBasePro',
        ],
    );
    if (!$Result) {
        print STDERR "Unable to create package entry \"KIXPro\" in package repository!\n"; 
    }
    
    # create "fake" KIXPro directory for update installation
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    if ( !( -e $Home.'/KIXPro' ) ) {
        if ( !mkpath( $Home.'/KIXPro', 0, 0755 ) ) {
            print STDERR "Can't create directory '$Home/KIXpro'!";
        }
    }
}

foreach my $Package (@ObsoletePackages) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL  => "DELETE FROM package_repository WHERE name = ?",
        Bind => [
            \$Package,
        ],
    );
    if (!$Result) {
        print STDERR "Unable to remove package \"$Package\" from package repository!\n"; 
    }
}

# do all incremental DB updates to current version
my $FrameworkVersion = $Kernel::OM->Get('Kernel::Config')->Get('FrameworkVersion');
$FrameworkVersion =~ s/-\d+//g;
$Result = system(
    $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/scripts/database/update/db-update.pl',
    '-s',
    '17.0.0',
    '-t',
    $FrameworkVersion,
);
if (!$Result) {
    print STDERR "Unable to install necessary incremental database updates! Maybe they are already in place - please check.\n"; 
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
