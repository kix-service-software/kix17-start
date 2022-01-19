# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::ErrorLog;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Log',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my @ErrorLines;

    for my $Line ( split( /\n/, $Kernel::OM->Get('Kernel::System::Log')->GetLog() ) ) {
        my @Row = split( /;;/, $Line );
        if ( $Row[3] && $Row[1] =~ /error/i ) {
            push @ErrorLines, $Row[3];
        }
    }

    if (@ErrorLines) {
        $Self->AddResultInformation(
            Label   => Translatable('Error Log'),
            Value   => join( "\n", @ErrorLines ),
            Message => Translatable('There are error reports in your system log.'),
        );
    }
    else {
        $Self->AddResultInformation(
            Label => Translatable('Error Log'),
            Value => '',
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
