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
        LogPrefix => 'db-update-17.19.0.pl',
    },
);

use vars qw(%INC);

# remove obsolete files
_RemoveObsoleteDirectory();
_RemoveObsoleteFiles();

exit 0;

sub _RemoveObsoleteDirectory {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @DirectoryList = (
        'var/httpd/htdocs/js/thirdparty/fullcalendar-3.10.2',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/fullcalendar-3.10.2',
        'var/httpd/htdocs/skins/Customer/default/css/thirdparty/fullcalendar-3.10.2',

        'var/httpd/htdocs/js/thirdparty/jquery-tablesorter-2.31.1',

        'var/httpd/htdocs/js/thirdparty/jstree-3.3.11',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/jstree-3.3.11',
        'var/httpd/htdocs/skins/Customer/default/css/thirdparty/jstree-3.3.11',

        'var/httpd/htdocs/js/thirdparty/jscolor-2.4.5',

        'var/httpd/htdocs/js/thirdparty/jquery-ui-1.12.1',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/jquery-ui-1.12.1',
        'var/httpd/htdocs/skins/Customer/default/css/thirdparty/jquery-ui-1.12.1',

        'var/httpd/htdocs/js/thirdparty/ckeditor-4.16.0',

        'Kernel/cpan-lib/Crypt/Crypt',
    );

    for my $Directory ( @DirectoryList ) {
        rmtree( $HomePath . '/' . $Directory );
    }

    return 1;
}

sub _RemoveObsoleteFiles {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @FileList = (
        'Kernel/cpan-lib/Apache/LICENSE',
        'Kernel/cpan-lib/Apache2/LICENSE',
        'Kernel/cpan-lib/CGI/HTML/Functions.pod',
        'Kernel/cpan-lib/CGI/Apache.pm',
        'Kernel/cpan-lib/CGI/Switch.pm',
        'Kernel/cpan-lib/Font/TTF/Changes_old.txt',
        'Kernel/cpan-lib/Font/TTF/Manual.pod',
        'Kernel/cpan-lib/HTML/TokeParser.pm'
    );

    for my $File ( @FileList ) {
        unlink( $HomePath . '/' . $File );
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
