# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Package::RepositoryList;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Package',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List all known KIX package repsitories.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing KIX package repositories...</yellow>\n");

    my $Count = 0;
    my %List;
    if ( $Kernel::OM->Get('Kernel::Config')->Get('Package::RepositoryList') ) {
        %List = %{ $Kernel::OM->Get('Kernel::Config')->Get('Package::RepositoryList') };
    }
    %List = ( %List, $Kernel::OM->Get('Kernel::System::Package')->PackageOnlineRepositories() );

    if ( !%List ) {
        $Self->PrintError("No package repositories configured.");
        return $Self->ExitCodeError();
    }

    for my $URL ( sort { $List{$a} cmp $List{$b} } keys %List ) {
        $Count++;
        print "+----------------------------------------------------------------------------+\n";
        print "| $Count) Name: $List{$URL}\n";
        print "|    URL:  $URL\n";
    }
    print "+----------------------------------------------------------------------------+\n";
    print "\n";

    $Self->Print("<yellow>Listing KIX package repository contents...</yellow>\n");

    for my $URL ( sort { $List{$a} cmp $List{$b} } keys %List ) {
        print
            "+----------------------------------------------------------------------------+\n";
        print "| Package Overview for Repository $List{$URL}:\n";
        my @Packages = $Kernel::OM->Get('Kernel::System::Package')->PackageOnlineList(
            URL  => $URL,
            Lang => $Kernel::OM->Get('Kernel::Config')->Get('DefaultLanguage'),
        );
        my $PackageCount = 0;
        PACKAGE:
        for my $Package (@Packages) {

            # Just show if PackageIsVisible flag is enabled.
            if (
                defined $Package->{PackageIsVisible}
                && !$Package->{PackageIsVisible}->{Content}
            ) {
                next PACKAGE;
            }
            $PackageCount++;
            print
                "+----------------------------------------------------------------------------+\n";
            print "| $PackageCount) Name:        $Package->{Name}\n";
            print "|    Version:     $Package->{Version}\n";
            print "|    Vendor:      $Package->{Vendor}\n";
            print "|    URL:         $Package->{URL}\n";
            print "|    License:     $Package->{License}\n";
            print "|    Description: $Package->{Description}\n";
            print "|    Install:     $URL:$Package->{File}\n";
        }
        print
            "+----------------------------------------------------------------------------+\n";
        print "\n";
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
