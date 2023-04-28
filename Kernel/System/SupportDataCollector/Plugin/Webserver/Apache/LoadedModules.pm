# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::Webserver::Apache::LoadedModules;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = ();

sub GetDisplayPath {
    return Translatable('Webserver') . '/' . Translatable('Loaded Apache Modules');
}

sub Run {
    my $Self = shift;

    my %Environment = %ENV;

    # No apache webserver with mod_perl, skip this check
    if (
        !$ENV{GATEWAY_INTERFACE}
        || !$ENV{SERVER_SOFTWARE}
        || $ENV{SERVER_SOFTWARE} !~ m{apache}i
        || !$ENV{MOD_PERL}
        || !eval { require Apache2::Module; }
    ) {
        return $Self->GetResults();
    }

    for ( my $Module = Apache2::Module::top_module(); $Module; $Module = $Module->next() ) {
        $Self->AddResultInformation(
            Identifier => $Module->name(),
            Label      => $Module->name(),
            Value      => $Module->ap_api_major_version() . '.' . $Module->ap_api_minor_version(),
        );
    }

    return $Self->GetResults()
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
