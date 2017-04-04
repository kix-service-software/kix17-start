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

use Digest::MD5;
use Pod::Usage;

if ( !$ARGV[0] ) {
    pod2usage();
}
my $Filename = $ARGV[0];

if ( open my $FH, '<', $Filename ) {    ## no critic
    binmode $FH;
    my $MD5 = Digest::MD5->new();
    $MD5->addfile($FH);
    printf "%-32s %s\n", $MD5->hexdigest(), $Filename;
    close $FH;
}
else {
    die "Cannot open $Filename: $!\n";
}

exit;

__END__

=head1 NAME

md5sum.pl - output the md5sum of a file.

=head1 SYNOPSIS

perl md5sum.pl [filename]

=head1 DESCRIPTION

This program will generate an MD5sum of a file and display it.
Although this trivial task is generally performed by the B<md5sum>
builtin on many systems, not all platforms (Windows!) have this.
In that case using this script is a nice alternative.

=cut

=end



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
