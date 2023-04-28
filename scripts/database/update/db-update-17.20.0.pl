#!/usr/bin/perl
# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

# remove obsolete directories
_RemoveObsoleteDirectory();

# remove obsolete files
_RemoveObsoleteFiles();

exit 0;

sub _RemoveObsoleteDirectory {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @DirectoryList = (
        'Kernel/cpan-lib/Lingua',
        'Kernel/cpan-lib/Pod',

        'Kernel/System/Console/Command/Dev/Code',

        'var/httpd/htdocs/js/thirdparty/jquery-3.6',
        'var/httpd/htdocs/js/thirdparty/jquery-migrate-3.3.2',
        'var/httpd/htdocs/js/thirdparty/jquery-ui-1.13.1',
        'var/httpd/htdocs/js/thirdparty/jquery-validate-1.19.3',
        'var/httpd/htdocs/skins/Agent/default/css/thirdparty/jquery-ui-1.13.1',
        'var/httpd/htdocs/skins/Customer/default/css/thirdparty/jquery-ui-1.13.1',

        'var/httpd/htdocs/js/thirdparty/jscolor-2.4.7',
        'var/httpd/htdocs/js/thirdparty/momentjs-2.29.1',

        'var/httpd/htdocs/js/thirdparty/ckeditor-4.17.2',
    );

    for my $Directory ( @DirectoryList ) {
        rmtree( $HomePath . q{/} . $Directory );
    }

    return 1;
}

sub _RemoveObsoleteFiles {

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    # get home path
    my $HomePath = $ConfigObject->Get('Home');

    # prepare file list
    my @FilesList = (
        'Kernel/System/Console/Command/Dev/Tools/Config2Docbook.pm',
        'Kernel/System/Console/Command/Dev/Tools/RPMSpecGenerate.pm',
        'Kernel/System/Console/Command/Dev/Tools/TranslationsUpdate.pm',
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
