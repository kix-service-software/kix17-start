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

# get DB object
my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

my @TestsMofifiers = (
    {
        Name        => 'Autoconnect off - No connect after object creation',
        Command     => '',
        Success     => 0,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Connected',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Diconnected',
        Command     => 'Disconnect',
        Success     => 0,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Connected again',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Diconnected again',
        Command     => 'Disconnect',
        Success     => 0,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect on - Ping should connect automatically',
        Command     => '',
        Success     => 1,
        AutoConnect => 1,
    },
    {
        Name        => 'Autoconnect on - Ping should connect again after disconnected',
        Command     => 'Disconnect',
        Success     => 1,
        AutoConnect => 1,
    },
    {
        Name        => 'Autoconnect on - Already connected',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 1,
    },
    {
        Name        => 'Autoconnect on - Already connected',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 1,
    },
);

for my $TestCase (@TestsMofifiers) {

    my $Command = $TestCase->{Command} || '';
    if ($Command) {
        $DBObject->$Command();
    }

    my $Success = $DBObject->Ping(
        AutoConnect => $TestCase->{AutoConnect},
    );

    if ( $TestCase->{Success} ) {
        $Self->True(
            $Success,
            "$TestCase->{Name} - Ping() with true",
        );
    }
    else {
        $Self->False(
            $Success,
            "$TestCase->{Name} - Ping() with false",
        );
    }
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
