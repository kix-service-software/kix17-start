# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::KIX::CleanupPackageRepository;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::System::Package',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Remove duplicate entries in package_repository due to force install.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL =>
            'SELECT id FROM package_repository pr1 WHERE id IN (SELECT id FROM package_repository WHERE name = pr1.name AND id < (SELECT MAX(id) FROM package_repository WHERE name = pr1.name))',
    );

    if ($Result) {
        my @IDs;
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            push( @IDs, $Row[0] );
        }

        foreach my $ID (@IDs) {
            $Result = $Kernel::OM->Get('Kernel::System::DB')->Prepare(
                SQL  => 'DELETE FROM package_repository WHERE id = ?',
                Bind => [ \$ID ],
            );
            last if !$Result;
        }
    }

    if ( !$Result ) {
        return $Self->ExitCodeError();
    }

    return $Self->ExitCodeOk();
}

1;
