#!/usr/bin/perl
# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin).'/../../';
use lib dirname($RealBin).'/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update-17.3.0_post.pl',
    },
);

use vars qw(%INC);

# migrate DFs "CustomerUser" and "CustomerCompany"
_MigrateDynamicFields();

exit 0;


sub _MigrateDynamicFields {

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    my $Success = $DBObject->Do(
        SQL =>'UPDATE dynamic_field_value SET object_id = NULL WHERE object_id_text IS NOT NULL',
    );
    if (!$Success) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unable to erase object_id for DynamicFields with textual object_id!"
        );
    }

    return 1;
}


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
