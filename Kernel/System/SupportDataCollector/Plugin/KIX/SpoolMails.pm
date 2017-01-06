# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::SpoolMails;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Main',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $Home     = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my $SpoolDir = "$Home/var/spool";

    my @SpoolMails = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $SpoolDir,
        Filter    => '*',
    );

    if ( scalar @SpoolMails ) {
        $Self->AddResultProblem(
            Label   => Translatable('Spooled Emails'),
            Value   => scalar @SpoolMails,
            Message => Translatable('There are emails in var/spool that KIX could not process.'),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Spooled Emails'),
            Value => scalar @SpoolMails,
        );
    }

    return $Self->GetResults();
}

1;
