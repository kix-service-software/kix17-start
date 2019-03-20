#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

# to get it readable for the web server user and writable for kix
# group (just in case)

umask 007;

use Getopt::Std;
use Kernel::System::ObjectManager;

# get options
my %Opts;
getopt( 'qtd', \%Opts );
if ( $Opts{h} ) {
    print "kix.PostMaster.pl - KIX cmd postmaster\n";
    print
        "usage: kix.PostMaster.pl -q <QUEUE> -t <TRUSTED> (default is trusted, use '-t 0' to disable trusted mode)\n";
    print "\nkix.PostMaster.pl is deprecated, please use console command 'Maint::PostMaster::Read' instead.\n\n";
    exit 1;
}
if ( !$Opts{d} ) {
    $Opts{d} = 0;
}
if ( !defined( $Opts{t} ) ) {
    $Opts{t} = 1;
}
if ( !$Opts{q} ) {
    $Opts{q} = '';
}

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix.PostMaster.pl',
    },
);

# log the use of a deprecated script
$Kernel::OM->Get('Kernel::System::Log')->Log(
    Priority => 'error',
    Message  => "kix.PostMaster.pl is deprecated, please use console command 'Maint::PostMaster::Read' instead.",
);

# convert arguments to console command format
my @Params;

if ( $Opts{q} ) {
    push @Params, '--target-queue';
    push @Params, $Opts{q};
}
if ( !$Opts{t} ) {
    push @Params, '--untrusted';
}
if ( $Opts{d} ) {
    push @Params, '--debug';
}

# execute console command
my $ExitCode = $Kernel::OM->Get('Kernel::System::Console::Command::Maint::PostMaster::Read')->Execute(@Params);

exit $ExitCode;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
