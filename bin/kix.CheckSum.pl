#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
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
    print "kix.CheckSum.pl - KIX check sum\n";
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
    open( $Output, '>', $Archive ) || die "ERROR: Can't write: $Archive";

    ProcessDirectory($Start);

    close $Output;
    print " done.\n";
}
else {
    open( my $In, '<', $Archive ) || die "ERROR: Can't read: $Archive";
    while (<$In>) {
        my @Row = split( /::/, $_ );
        chomp $Row[1];
        $Compare{ $Row[1] } = $Row[0];
    }
    close $In;

    ProcessDirectory($Start);

    for my $File ( sort keys %Compare ) {
        print "Notice: Removed $File\n";
    }
}

sub ProcessDirectory {
    my $Directory = shift;

    my @List = glob("$Directory/*");

    FILE:
    for my $File (@List) {

        # clean up directory name
        $File =~ s{//}{/}smxg;

        # always stay in KIX directory
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
        open( my $In, '<', $OrigFile ) || die "ERROR: $!";

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
            elsif ( -e "$File.save" ) {
                ## report .save files as modified by the KIX Package Manager
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
