# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::PackageList;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CSV',
    'Kernel::System::Package',
);

sub GetDisplayPath {
    return Translatable('KIX') . '/' . Translatable('Package List');
}

sub Run {
    my $Self = shift;

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    # get needed objects
    my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');
    my $CSVObject     = $Kernel::OM->Get('Kernel::System::CSV');

    my @PackageList = $PackageObject->RepositoryList( Result => 'Short' );

    for my $Package (@PackageList) {

        my @PackageData = (
            [
                $Package->{Name},
                $Package->{Version},
                $Package->{MD5sum},
                $Package->{Vendor},
            ],
        );

        # use '-' (minus) as separator otherwise the line will not wrap and will not be totally
        #   visible
        my $Message = $CSVObject->Array2CSV(
            Data      => \@PackageData,
            Separator => '-',
            Quote     => "'",
        );

        # remove the new line character, otherwise it does not play good with output translations
        chomp $Message;

        $Self->AddResultInformation(
            Identifier => $Package->{Name},
            Label      => $Package->{Name},
            Value      => $Package->{Version},
            Message    => $Message,
        );
    }

    # if no packages where found we should not add any result, otherwise the table will be
    #   have that row instead of output just the label and a message of not packages found

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
