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

package Kernel::System::Console::Command::Maint::Memcacheds::Remove;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Cache',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Removes objects in memcached.');

    $Self->AddArgument(
        Name        => 'type',
        Description => 'cache type',
        Required    => 1,
        ValueRegex  => qr/(.*)/smx,
    );
    $Self->AddArgument(
        Name        => 'key',
        Description => 'cache key',
        Required    => 1,
        ValueRegex  => qr/(.*)/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Type = $Self->GetArgument('type');
    my $Key  = $Self->GetArgument('key');

    $Self->Print(
        "<yellow>removing...</yellow>\n"
    );

    my $Result = $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Key  => $Key,
        Type => $Type,
        Raw  => 1,
    );

    if ($Result) {
        print "\"$Type::$Key\" removed.\n";
    }
    else {
        print "\"$Type::$Key\" not found!\n";
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;

