# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::ConfigSettings;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
);

sub GetDisplayPath {
    return Translatable('KIX') . '/' . Translatable('Config Settings');
}

sub Run {
    my $Self = shift;

    my @Settings = qw(
        Home
        FQDN
        HttpType
        DefaultLanguage
        SystemID
        Version
        ProductName
        Organization
        Ticket::IndexModule
        Ticket::SearchIndexModule
        Ticket::StorageModule
        SendmailModule
        Frontend::RichText
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    for my $Setting (@Settings) {

        my $ConfigValue = $ConfigObject->Get($Setting);

        if ( defined $ConfigValue ) {
            $Self->AddResultInformation(
                Identifier => $Setting,
                Label      => $Setting,
                Value      => $ConfigValue,
            );
        }
        else {
            $Self->AddResultProblem(
                Identifier => $Setting,
                Label      => $Setting,
                Value      => $ConfigValue,
                Message    => Translatable('Could not determine value.'),
            );
        }
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
