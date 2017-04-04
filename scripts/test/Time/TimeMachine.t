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

# get time object
my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

my $StartSystemTime = $TimeObject->SystemTime();

{
    my $HelperObject = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

    sleep 1;

    my $FixedTime = $HelperObject->FixedTimeSet();

    sleep 1;

    $Self->Is(
        $TimeObject->SystemTime(),
        $FixedTime,
        "Stay with fixed time",
    );

    sleep 1;

    $Self->Is(
        $TimeObject->SystemTime(),
        $FixedTime,
        "Stay with fixed time",
    );

    $HelperObject->FixedTimeAddSeconds(-10);

    $Self->Is(
        $TimeObject->SystemTime(),
        $FixedTime - 10,
        "Stay with increased fixed time",
    );

    # Let object be destroyed at the end of this scope
    $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::UnitTest::Helper'] );
}

sleep 1;

$Self->True(
    $TimeObject->SystemTime() >= $StartSystemTime,
    "Back to original time",
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
