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

use MIME::Base64;

# get type
my $Type = shift;

if ( !$Type ) {
    print STDERR "ERROR: Need ARG 1 - (encode|decode)\n";
    exit 1;
}
elsif ( $Type !~ /^encode|decode$/ ) {
    print STDERR "ERROR: ARG 1 - (encode|decode)\n";
    exit 1;
}

# get source text
my @InArray = <STDIN>;
my $In      = '';
for (@InArray) {
    $In .= $_;
}

if ( $Type eq 'decode' ) {
    $In = decode_base64($In);
}
else {
    $In = encode_base64($In);
}
print $In. "\n";

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
