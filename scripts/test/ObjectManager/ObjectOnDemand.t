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

#
# This test makes sure that object dependencies are only created when
# the object actively asks for them, not earlier.
#

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

$Self->True( $Kernel::OM, 'Could build object manager' );

$Self->True(
    exists $Kernel::OM->{Objects}->{'Kernel::System::Encode'},
    'Kernel::System::Encode is always preloaded',
);

$Self->False(
    exists $Kernel::OM->{Objects}->{'Kernel::System::Time'},
    'Kernel::System::Time was not loaded yet',
);

$Self->False(
    exists $Kernel::OM->{Objects}->{'Kernel::System::Log'},
    'Kernel::System::Log was not loaded yet',
);

$Kernel::OM->Get('Kernel::System::Time');

$Self->True(
    exists $Kernel::OM->{Objects}->{'Kernel::System::Time'},
    'Kernel::System::Time was loaded',
);

$Self->False(
    exists $Kernel::OM->{Objects}->{'Kernel::System::Log'},
    'Kernel::System::Log is a dependency of Kernel::System::Time, but was not yet loaded',
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
