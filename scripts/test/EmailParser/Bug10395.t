# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::EmailParser;

# This test should verify that an email with an unknown encoding not cause a "die".

my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

# test for bug#1970
my @Array;
open my $IN, '<', "$Home/scripts/test/sample/EmailParser/Bug10395.box";    ## no critic
while (<$IN>) {
    push @Array, $_;
}
close $IN;

# create local object
my $EmailParserObject = Kernel::System::EmailParser->new(
    Email => \@Array,
);

$Self->Is(
    $EmailParserObject->GetParam( WHAT => 'From' ),
    '"dev.mydomain.somewhere - Oddział 3 w Warszawie, testtes A1" <dev@ib.pl>',
    'Check complicated to header',
);

$Self->Is(
    $EmailParserObject->GetParam( WHAT => 'Cc' ),
    '"dev.mydomain.somewhere - Oddział 3 w Warszawie, testtes A1" <dev@ib.pl>, "dev.mydomain.somewhere - Oddział 3 w Warszawie, testtes A1" <dev@ib.pl>, "dev.mydomain.somewhere - Oddział 3 w Warszawie, testtes A1" <dev@ib.pl>',
    'Check complicated to header',
);

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
