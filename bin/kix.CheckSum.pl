#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use vars qw($RealBin);

use Getopt::Std;
use Digest::MD5 qw(md5_hex);

my $Start = $RealBin;
$Start =~ s{/bin}{/}smx;
my $Archive = '';
my $Action  = 'compare';
my %Compare;

# get options
my %Opts;
getopt( 'abd', \%Opts );
if ( exists $Opts{h} || !keys %Opts ) {
    print "kix.CheckSum.pl - OTRS check sum\n";
    print
        "usage: kix.CheckSum.pl -a create|compare [-b /path/to/ARCHIVE] [-d /path/to/framework]\n";
    exit 1;
}

if ( $Opts{a} && $Opts{a} eq 'create' ) {
    $Action = $Opts{a};
}
if ( $Opts{d} ) {
    $Start = $Opts{d};
}
if ( $Opts{b} ) {
    $Archive = $Opts{b};
}
else {
    $Archive = $Start . 'ARCHIVE';
}

my $Output;

if ( $Action eq 'create' ) {
    print "Writing $Archive ...";
    open( $Output, '>', $Archive ) || die "ERROR: Can't write: $Archive";    ## no critic
}
else {
    open( my $In, '<', $Archive ) || die "ERROR: Can't read: $Archive";      ## no critic
    while (<$In>) {
        my @Row = split( /::/, $_ );
        chomp $Row[1];
        $Compare{ $Row[1] } = $Row[0];
    }
    close $In;
}

my @Dirs;
ProcessDirectory($Start);
for my $File ( sort keys %Compare ) {

    #print "Notice: Removed $Compare{$File}\n";
    print "Notice: Removed $File\n";
}
if ( $Action eq 'create' ) {
    print " done.\n";
    close $Output;
}

sub ProcessDirectory {
    my $In = shift;

    my @List = glob("$In/*");

    FILE:
    for my $File (@List) {

        # clean up directory name
        $File =~ s{//}{/}smxg;

        # always stay in OTRS directory
        next FILE if $File !~ m{^\Q$Start\E};

        # ignore source code directories, ARCHIVE file
        next FILE if $File =~ m{/.git|/ARCHIVE}smx;

        # if it's a directory
        if ( -d $File ) {
            ProcessDirectory($File);
            next FILE;
        }

        # ignore all non-regular files as links, pipes, sockets etc.
        next FILE if ( !-f $File );

        # if it's a file
        my $OrigFile = $File;
        $File =~ s{$Start}{}smx;
        $File =~ s{^/(.*)$}{$1}smx;

        # ignore directories
        next FILE if $File =~ m{^doc/}smx;
        next FILE if $File =~ m{^var/tmp}smx;
        next FILE if $File =~ m{^var/article}smx;
        next FILE if $File =~ m{js-cache}smx;
        next FILE if $File =~ m{css-cache}smx;

        # next if not readable
        # print "File: $File\n";
        open( my $In, '<', $OrigFile ) || die "ERROR: $!";    ## no critic

        my $DigestGenerator = Digest::MD5->new();
        $DigestGenerator->addfile($In);
        my $Digest = $DigestGenerator->hexdigest();
        close $In;

        if ( $Action eq 'create' ) {
            print $Output $Digest . '::' . $File . "\n";
        }
        else {
            if ( !$Compare{$File} ) {
                print "Notice: New $File\n";
            }
            elsif ( $Compare{$File} ne $Digest && !-e "$File.save" ) {    ## ignore files with .save
                print "Notice: Dif $File\n";
            }
            elsif ( -e "$File.save" )
            {    ## report .save files as modified by the OTRS Package Manager
                print "Notice: OPM Changed $File\n"
            }
            if ( defined $Compare{$File} ) {
                delete $Compare{$File};
            }
        }
    }

    return 1;
}



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
