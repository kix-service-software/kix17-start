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
use utf8;

use vars (qw($Self));

my @Tests = (
    {
        Name      => 'Command completion',
        COMP_LINE => 'bin/kix.Console.pl Hel',
        Arguments => [ 'bin/kix.Console.pl', 'Hel', 'bin/kix.Console.pl' ],
        Result    => "Help",
    },
    {
        Name      => 'Argument list',
        COMP_LINE => 'bin/kix.Console.pl Admin::Article::StorageSwitch ',
        Arguments => [ 'bin/kix.Console.pl', '', 'Admin::Article::SwitchStorage' ],
        Result    => "--target
--tickets-closed-before-date
--tickets-closed-before-days
--tolerant
--micro-sleep
--force-pid",
    },
    {
        Name      => 'Argument list limitted',
        COMP_LINE => 'bin/kix.Console.pl Admin::Article::StorageSwitch --to',
        Arguments => [ 'bin/kix.Console.pl', '--to', 'Admin::Article::SwitchStorage' ],
        Result    => "--tolerant",
    },
);

for my $Test (@Tests) {

    my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Internal::BashCompletion');

    my ( $Result, $ExitCode );

    {
        local $ENV{COMP_LINE} = $Test->{COMP_LINE};
        local *STDOUT;
        open STDOUT, '>:utf8', \$Result;    ## no critic
        $ExitCode = $CommandObject->Execute( @{ $Test->{Arguments} } );
    }

    $Self->Is(
        $ExitCode,
        0,
        "$Test->{Name} exit code",
    );

    $Self->Is(
        $Result,
        $Test->{Result},
        "$Test->{Name} result",
    );

}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
