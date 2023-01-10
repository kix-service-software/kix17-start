# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Database::Check;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::DB',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Check KIX database connectivity.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # print database information
    my $DatabaseDSN  = $DBObject->{DSN};
    my $DatabaseUser = $DBObject->{USER};

    $Self->Print("<yellow>Trying to connect to database '$DatabaseDSN' with user '$DatabaseUser'...</yellow>\n");

    # check database state
    if ($DBObject) {
        $DBObject->Prepare( SQL => "SELECT * FROM valid" );
        my $Check = 0;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Check++;
        }
        if ( !$Check ) {
            $Self->PrintError("Connection was successful, but database content is missing.");
            return $Self->ExitCodeError();
        }

        $Self->Print("<green>Connection successful.</green>\n");

        # check for common MySQL issue where default storage engine is different
        # from initial KIX table; this can happen when MySQL is upgraded from
        # 5.1 > 5.5.
        if ( $DBObject->{'DB::Type'} eq 'mysql' ) {
            $DBObject->Prepare(
                SQL => "SHOW VARIABLES WHERE variable_name = 'storage_engine'",
            );
            my $StorageEngine;
            while ( my @Row = $DBObject->FetchrowArray() ) {
                $StorageEngine = $Row[1];
            }
            $DBObject->Prepare(
                SQL  => "SHOW TABLE STATUS WHERE engine != ?",
                Bind => [ \$StorageEngine ],
            );
            my @Tables;
            while ( my @Row = $DBObject->FetchrowArray() ) {
                push @Tables, $Row[0];
            }
            if (@Tables) {
                my $Error = "Your storage engine is $StorageEngine.\n";
                $Error .= "These tables use a different storage engine:\n\n";
                $Error .= join( "\n", sort @Tables );
                $Error .= "\n\n *** Please correct these problems! *** \n\n";

                $Self->PrintError($Error);
                return $Self->ExitCodeError();
            }
        }

        return $Self->ExitCodeOk();
    }

    $Self->PrintError('Connection failed.');
    return $Self->ExitCodeError();
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
