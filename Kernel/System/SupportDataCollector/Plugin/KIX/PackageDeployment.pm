# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::PackageDeployment;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Package',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # get package object
    my $PackageObject = $Kernel::OM->Get('Kernel::System::Package');

    my @InvalidPackages;
    my @WrongFrameworkVersion;
    for my $Package ( $PackageObject->RepositoryList() ) {

        my $DeployCheck = $PackageObject->DeployCheck(
            Name    => $Package->{Name}->{Content},
            Version => $Package->{Version}->{Content},
        );
        if ( !$DeployCheck ) {
            push @InvalidPackages, "$Package->{Name}->{Content} $Package->{Version}->{Content}";
        }

        # get package
        my $PackageContent = $PackageObject->RepositoryGet(
            Name    => $Package->{Name}->{Content},
            Version => $Package->{Version}->{Content},
            Result  => 'SCALAR',
        );

        my %PackageStructure = $PackageObject->PackageParse(
            String => $PackageContent,
        );

        my $CheckFrameworkOk = $PackageObject->_CheckFramework(
            Framework => $PackageStructure{Framework},
            NoLog     => 1,
        );

        if ( !$CheckFrameworkOk ) {
            push @WrongFrameworkVersion, "$Package->{Name}->{Content} $Package->{Version}->{Content}";
        }
    }

    if (@InvalidPackages) {
        if ( $Kernel::OM->Get('Kernel::Config')->Get('Package::AllowLocalModifications') ) {
            $Self->AddResultInformation(
                Label   => Translatable('Package Installation Status'),
                Value   => join( ', ', @InvalidPackages ),
                Message => Translatable('Some packages have locally modified files.'),
            );
        }
        else {
            $Self->AddResultProblem(
                Label   => Translatable('Package Installation Status'),
                Value   => join( ', ', @InvalidPackages ),
                Message => Translatable('Some packages are not correctly installed.'),
            );
        }
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Package Installation Status'),
            Value => '',
        );
    }

    if (@WrongFrameworkVersion) {
        if ( $Kernel::OM->Get('Kernel::Config')->Get('Package::AllowLocalModifications') ) {
            $Self->AddResultInformation(
                Identifier => 'FrameworkVersion',
                Label      => Translatable('Package Framework Version Status'),
                Value      => join( ', ', @WrongFrameworkVersion ),
                Message    => Translatable('Some packages are not allowed for the current framework version.'),
            );
        }
        else {
            $Self->AddResultProblem(
                Identifier => 'FrameworkVersion',
                Label      => Translatable('Package Framework Version Status'),
                Value      => join( ', ', @WrongFrameworkVersion ),
                Message    => Translatable('Some packages are not allowed for the current framework version.'),
            );
        }
    }
    else {
        $Self->AddResultOk(
            Identifier => 'FrameworkVersion',
            Label      => Translatable('Package Framework Version Status'),
            Value      => '',
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
