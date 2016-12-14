#!/usr/bin/perl -w
# --
# bin/kix.CheckModules.pl - to check needed cpan framework modules
# based upon bin/otrs.CheckModules.pl
# original Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# KIX4OTRS-Extensions Copyright (C) 2001-2015 c.a.p.e. IT GmbH, http://www.cape-it.de/
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';

# config
my @NeededModules = (
    {
        Module   => 'Data::Compare',
        Required => 0,
        Comment  => 'Required to track SysConfig changes.',
    },
);

# try to load modules
my $Depends = 0;
foreach my $Module (@NeededModules) {
    _Check( $Module, $Depends );
}
exit;

sub _Check {
    my ( $Module, $Depends ) = @_;

    for ( 0 .. $Depends ) {
        print "   ";
    }
    print "o $Module->{Module}";
    my $Length = length( $Module->{Module} ) + ( $Depends * 3 );
    for ( $Length .. 30 ) {
        print ".";
    }
    if ( eval "require $Module->{Module}" ) {

        # some strange CPAN module do not export VERSION
        my $Version = eval "\$$Module->{Module}::Version::VERSION";

        # ask for CPAN module VERSION
        if ( !$Version ) {
            $Version = eval "\$$Module->{Module}::VERSION";
        }

        # cleanup version number
        my $CleanedVersion = _VersionClean(
            Version => $Version,
        );

        if ( $Module->{NotSupported} ) {

            my $NotSupported = 0;
            ITEM:
            for my $Item ( @{ $Module->{NotSupported} } ) {

                # cleanup item version number
                my $ItemVersion = _VersionClean(
                    Version => $Item->{Version},
                );

                if ( $CleanedVersion == $ItemVersion ) {
                    $NotSupported = $Item->{Comment};
                    last ITEM;
                }
            }

            if ($NotSupported) {
                print "failed!!! Version $Version not supported! $NotSupported\n";
                return;
            }
        }

        if ( $Module->{Version} ) {

            # cleanup item version number
            my $ModuleVersion = _VersionClean(
                Version => $Module->{Version},
            );

            if ( $CleanedVersion >= $ModuleVersion ) {
                print "ok (v$Version)\n";
            }
            else {
                print
                    "failed!!! Version $Version installed but $Module->{Version} or higher is required!\n";
            }
        }
        else {
            print "ok (v$Version)\n";
        }
    }
    else {
        my $Comment = $Module->{Comment} || '';
        my $Required = $Module->{Required};
        if ($Required) {
            $Required = 'Required - use "perl -MCPAN -e shell;"';
        }
        else {
            $Required = 'Optional';
        }
        print "Not installed! ($Required - $Comment)\n";
    }

    if ( $Module->{Depends} ) {
        for my $ModuleSub ( @{ $Module->{Depends} } ) {
            _Check( $ModuleSub, $Depends + 1 );
        }
    }

    return 1;
}

sub _VersionClean {
    my (%Param) = @_;

    return 0 if !$Param{Version};

    # replace all special characters with an dot
    $Param{Version} =~ s{ [_-] }{.}xmsg;

    my @VersionParts = split q{\.}, $Param{Version};

    my $CleanedVersion = '';
    for my $Count ( 0 .. 4 ) {
        $VersionParts[$Count] ||= 0;
        $CleanedVersion .= sprintf "%04d", $VersionParts[$Count];
    }

    return int $CleanedVersion;
}

