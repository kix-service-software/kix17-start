#!/usr/bin/perl
# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
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

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update.pl',
    },
);

use vars qw(%INC);

my %Opts;
getopt( 'v', \%Opts );

# check if xml file exists, if it doesn't, exit gracefully
my $XMLFile = $Kernel::OM->Get('Kernel::Config')->Get('Home').'/scripts/database/update/db-update-'.$Opts{v}.'.xml';
if ( ! -f "$XMLFile" ) {
    exit 0;
}
my $XML = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
    Location => $XMLFile,
);
if (!$XML) {
    print STDERR "Unable to read file \"$XMLFile\"!"; 
    exit -1;
}

my @XMLArray = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
    String => $XML,
);
if (!@XMLArray) {
    print STDERR "Unable to parse file \"$XMLFile\"!"; 
    exit -1;
}

my @SQL = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessor(
    Database => \@XMLArray,
);
if (!@SQL) {
    print STDERR "Unable to create SQL from file \"$XMLFile\"!"; 
    exit -1;
}

for my $SQL (@SQL) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute SQL from file \"$XMLFile\"!"; 
    }
}

# execute post SQL statements (indexes, constraints)
my @SQLPost = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessorPost();
for my $SQL (@SQLPost) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute POST SQL!"; 
    }
}

exit 1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
