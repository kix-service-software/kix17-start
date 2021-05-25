#!/usr/bin/perl
# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        LogPrefix => 'db-update-17.16.0.pl',
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
        'var/httpd/htdocs/js/thirdparty/canvg-1.4',
        'var/httpd/htdocs/js/thirdparty/d3-3.5.6',
        'var/httpd/htdocs/js/thirdparty/nvd3-1.7.1',
        'var/httpd/htdocs/js/thirdparty/StringView-8',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/nvd3-1.7.1',

        'var/httpd/htdocs/js/thirdparty/jquery-2.1.4',
        'var/httpd/htdocs/js/thirdparty/jquery-migrate-1.2.1',
        'var/httpd/htdocs/js/thirdparty/jquery-tablesorter-2.0.5',
        'var/httpd/htdocs/js/thirdparty/jquery-ui-1.11.4',
        'var/httpd/htdocs/js/thirdparty/jquery-validate-1.14.0',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/ui-theme',
        'var/httpd/htdocs/skins/Customer/default/css/thirdparty/ui-theme',

        'var/httpd/htdocs/js/thirdparty/jquery-jstree-3.1.1',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/jstree-theme',
        'var/httpd/htdocs/skins/Customer/default/css/thirdparty/jstree-theme',

        'var/httpd/htdocs/js/thirdparty/jscolor_1.4.1',

        'var/httpd/htdocs/js/thirdparty/jsplumb-1.6.4',
        'var/httpd/htdocs/js/thirdparty/farahey-0.5',
    );

    for my $Directory ( @DirectoryList ) {
        rmtree( $HomePath . '/' . $Directory );
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
