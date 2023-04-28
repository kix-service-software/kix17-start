# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::OS::KernelVersion;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = ();

sub GetDisplayPath {
    return Translatable('Operating System');
}

sub Run {
    my $Self = shift;

    # Check if used OS is a linux system
    if ( $^O !~ /(?:linux|unix|netbsd|freebsd|darwin)/i ) {
        return $Self->GetResults();
    }

    my $KernelVersion = "";
    my $KernelInfo;
    if ( open( $KernelInfo, "-|", "uname -a" ) ) {
        while (<$KernelInfo>) {
            $KernelVersion .= $_;
        }
        close($KernelInfo);
        if ($KernelVersion) {
            $KernelVersion =~ s/^\s+|\s+$//g;
        }
    }

    if ($KernelVersion) {
        $Self->AddResultInformation(
            Label => Translatable('Kernel Version'),
            Value => $KernelVersion,
        );
    }
    else {
        $Self->AddResultProblem(
            Label => Translatable('Kernel Version'),
            Value => $KernelVersion,
            Value => 'Could not determine kernel version.',
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
