# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get layout object
my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

my @Tests = (
    {
        Name   => 'Plain',
        String => 'some plain text',
        Result => 'some plain text',
    },
    {
        Name   => 'Umlauts',
        String => '&Auml;nderung',
        Result => 'Änderung',
    },
);
for my $Test (@Tests) {
    my $Plain = $LayoutObject->RichText2Ascii(
        String => $Test->{String},
    );
    $Self->Is(
        $Plain || '',
        $Test->{Result},
        $Test->{Name},
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
