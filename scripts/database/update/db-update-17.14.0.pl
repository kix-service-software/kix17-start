#!/usr/bin/perl
# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

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
        LogPrefix => 'db-update-17.14.0.pl',
    },
);

use vars qw(%INC);

# remove obsolete files
_RemoveObsoleteFiles();

exit 0;

sub _RemoveObsoleteFiles {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @FilesList = (
        'var/httpd/htdocs/skins/Agent/dark/css/Base.css',
        'var/httpd/htdocs/skins/Agent/dark/css/Base.Form.css',
        'var/httpd/htdocs/skins/Agent/dark/css/Base.Table.css',
    );

    for my $File ( @FilesList ) {
        my $Success = $MainObject->FileDelete(
            Location        => $HomePath . '/' . $File,
            Type            => 'Local',
            DisableWarnings => 1,
        );
    }

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
