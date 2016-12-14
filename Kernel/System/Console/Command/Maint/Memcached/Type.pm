# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Memcacheds::Type;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Cache',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Infos about objects in memcached.');

    $Self->AddArgument(
        Name        => 'type',
        Description => 'cache type',
        Required    => 1,
        ValueRegex  => qr/(.*)/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Type = $Self->GetArgument('type');

    # get all cached keys for type
    my $Result = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Key  => 'CacheIndex::' . $Type,
        Type => 'Memcached',
        Raw  => 1,
    );
    if ( $Result && ref($Result) eq 'HASH' ) {
        foreach my $Key ( sort keys %{$Result} ) {
            print $Key. "\n";
        }
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;

