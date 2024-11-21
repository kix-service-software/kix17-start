# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::Webserver::Version;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = ();

sub GetDisplayPath {
    return Translatable('Webserver');
}

sub Run {
    my $Self = shift;

    my %Environment = %ENV;

    # Skip the plugin, if the support data collection isn't running in a web request.
    return $Self->GetResults() if !$ENV{GATEWAY_INTERFACE};

    my $Version = $ENV{SERVER_SOFTWARE};

    if ($Version) {
        $Self->AddResultInformation(
            Label => Translatable('Webserver Version'),
            Value => $ENV{SERVER_SOFTWARE},
        );
    }
    else {
        $Self->AddResultProblem(
            Label   => Translatable('Webserver Version'),
            Value   => '',
            Message => Translatable('Could not determine webserver version.')
        );
    }

    return $Self->GetResults();
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
