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
        Name   => 'Simple test',
        Params => {
            Name => 'test',
            Data => {
                1 => 'Testqueue',
            },
        },
        Result => '<select name="test" id="test" class="" data-tree="true"   >
<option value="1">Testqueue</option>
</select>
',
    },
    {
        Name   => 'Special characters',
        Params => {
            Name => 'test',
            Data => {
                '1||"><script>alert(\'hey there\');</script>' => '"><script>alert(\'hey there\');</script>',
            },
        },
        Result => q{<select name="test" id="test" class="" data-tree="true"   >
<option value="1||&quot;&gt;&lt;script&gt;alert('hey there');&lt;/script&gt;">&quot;&gt;&lt;script&gt;alert('hey there');&lt;/script&gt;</option>
</select>
},
    },

);

for my $Test (@Tests) {
    my $Result = $LayoutObject->AgentQueueListOption( %{ $Test->{Params} } );
    $Self->Is(
        $Result,
        $Test->{Result},
        $Test->{Name}
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
