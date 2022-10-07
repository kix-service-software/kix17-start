#!/usr/bin/perl
# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
use File::Path qw(rmtree);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update-17.20.0.pl',
    },
);

use vars qw(%INC);

# remove obsolete files
_RemoveObsoleteDirectory();

exit 0;

sub _RemoveObsoleteDirectory {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @DirectoryList = (

        'var/httpd/htdocs/js/thirdparty/jquery-3.6',
        'var/httpd/htdocs/js/thirdparty/jquery-migrate-3.3.2',
        'var/httpd/htdocs/js/thirdparty/jquery-ui-1.13.1',
        'var/httpd/htdocs/js/thirdparty/jquery-validate-1.19.3',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/jquery-ui-1.13.1',

        'var/httpd/htdocs/js/thirdparty/jscolor-2.4.7',
        'var/httpd/htdocs/js/thirdparty/momentjs-2.29.1',

        'var/httpd/htdocs/js/thirdparty/ckeditor-4.17.2',
    );

    for my $Directory ( @DirectoryList ) {
        rmtree( $HomePath . q{/} . $Directory );
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