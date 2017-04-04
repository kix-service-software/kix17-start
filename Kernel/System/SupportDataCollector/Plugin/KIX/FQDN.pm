# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
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



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
