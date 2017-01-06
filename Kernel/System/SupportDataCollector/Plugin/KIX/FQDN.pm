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

package Kernel::System::SupportDataCollector::Plugin::KIX::FQDN;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $FQDN = $Kernel::OM->Get('Kernel::Config')->Get('FQDN');

    # Do we have set our FQDN?
    if ( $FQDN eq 'yourhost.example.com' ) {
        $Self->AddResultProblem(
            Label   => Translatable('FQDN (domain name)'),
            Value   => $FQDN,
            Message => Translatable('Please configure your FQDN setting.'),
        );
    }

    # FQDN syntax check.
    elsif ( $FQDN !~ /^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$/ ) {
        $Self->AddResultProblem(
            Label   => Translatable('Domain Name'),
            Value   => $FQDN,
            Message => Translatable('Your FQDN setting is invalid.'),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Domain Name'),
            Value => $FQDN,
        );
    }

    return $Self->GetResults();
}

1;
