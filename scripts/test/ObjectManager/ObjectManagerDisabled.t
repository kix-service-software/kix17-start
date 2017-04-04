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
use vars (qw($Self));

$Self->True(
    $Kernel::OM->Get('scripts::test::ObjectManager::Dummy'),
    "Can load custom object",
);

my $NonexistingObject = eval { $Kernel::OM->Get('scripts::test::ObjectManager::Disabled') };
$Self->True(
    $@,
    "Fetching an object that cannot be loaded via OM causes an exception",
);
$Self->False(
    $NonexistingObject,
    "Cannot construct an object that cannot be loaded via OM",
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
