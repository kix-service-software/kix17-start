#!/usr/bin/perl
# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin).'/../../';
use lib dirname($RealBin).'/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);
use File::Basename qw(fileparse);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update.pl',
    },
);

use vars qw(%INC);

my %Opts;
getopt( 'st', \%Opts );

if (!%Opts) {
    print "USAGE: db-update.pl -s <Startversion> -t <Targetversion>\n";
    exit 0;
}

my $StartVersion;
if ($Opts{s} =~ /^(\d+).(\d+).(\d+)$/g) {
    $StartVersion = 0 + "$1$2$3";
}

if (!$StartVersion) {
    print STDERR "Wrong version format ($Opts{s})!\n"; 
    exit 1;
}

my $TargetVersion;
if ($Opts{t} =~ /^(\d+).(\d+).(\d+)$/g) {
    $TargetVersion = 0 + "$1$2$3";
}

if (!$TargetVersion) {
    print STDERR "Wrong version format ($Opts{t})!\n"; 
    exit 1;
}

# get all relevant versions between Start (f) and to (t)
my @FileList = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
    Directory => $Kernel::OM->Get('Kernel::Config')->Get('Home').'/scripts/database/update',
    Filter    => 'db-update-*',
);

my %VersionList;
foreach my $File (sort @FileList) {
    my ($Filename, $Dirs, $Suffix) = fileparse($File, qr/\.[^.]*/);
    if ($Filename =~ /^db-update-(\d+).(\d+).(\d+).*?$/g) {
        my $NummericVersion = 0 + "$1$2$3";
        $VersionList{$NummericVersion} = "$1.$2.$3";
    }
}

foreach my $NummericVersion (sort keys %VersionList) {
    next if $NummericVersion <= $StartVersion;
    last if $NummericVersion > $TargetVersion;

    if (!DoVersionUpdate($VersionList{$NummericVersion})) {
        exit 1;
    }
}

exit 0;


sub DoVersionUpdate {
    my ($Version) = @_;

    print "updating to $Version\n";

    # check and exec pre update script (before any SQL)
    if (!_ExecScript($Version, 'pre')) {
        return;
    }

    # check and execute pre SQL script (to prepare some thing in the DB)
    if (!_ExecSQL($Version, 'pre')) {
        return;
    }

    # check and exec main update script (after preparation)
    if (!_ExecScript($Version)) {
        return;
    }

    # check and execute post SQL script (to do some things after main migration)
    if (!_ExecSQL($Version, 'post')) {
        return;
    }

    # check and exec post update script (after all SQL)
    if (!_ExecScript($Version, 'post')) {
        return;
    }

    return 1;
}

sub _ExecScript {
    my ($Version, $Type) = @_;

    my $OrgType = $Type || '';

    if ( $Type ) {
        $Type = '_'.$Type;
    }
    else {
        $Type = '';
    }
 
    my $ScriptFile = $Kernel::OM->Get('Kernel::Config')->Get('Home').'/scripts/database/update/db-update-'.$Version.$Type.'.pl';

    if ( ! -f "$ScriptFile" ) {
        return 1;
    }

    print "    executing $OrgType update script\n";

    my $ExitCode = system($ScriptFile);    
    if ($ExitCode) {
        print STDERR "ERROR: Unable to execute $OrgType update script!";
        return;
    }

    return 1;
}

sub _ExecSQL {
    my ($Version, $Type) = @_;

    # check if xml file exists, if it doesn't, exit gracefully
    my $XMLFile = $Kernel::OM->Get('Kernel::Config')->Get('Home').'/scripts/database/update/db-update-'.$Version.'_'.$Type.'.xml';
    
    if ( ! -f "$XMLFile" ) {
        return 1;
    }

    print "    executing $Type SQL\n";

    my $XML = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => $XMLFile,
    );
    if (!$XML) {
        print STDERR "ERROR: Unable to read file \"$XMLFile\"!\n"; 
        return;
    }

    my @XMLArray = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
        String => $XML,
    );
    if (!@XMLArray) {
        print STDERR "ERROR: Unable to parse file \"$XMLFile\"!\n"; 
        return;
    }

    my @SQL = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessor(
        Database => \@XMLArray,
    );
    if (!@SQL) {
        print STDERR "ERROR: Unable to create SQL Start file \"$XMLFile\"!\n"; 
        return;
    }

    for my $SQL (@SQL) {
        my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
            SQL => $SQL 
        );
        if (!$Result) {
            print STDERR "ERROR: Unable to execute SQL Start file \"$XMLFile\"!\n"; 
        }
    }

    # execute post SQL statements (indexes, constraints)
    my @SQLPost = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessorPost();
    for my $SQL (@SQLPost) {
        my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
            SQL => $SQL 
        );
        if (!$Result) {
            print STDERR "ERROR: Unable to execute POST SQL!\n"; 
        }
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
