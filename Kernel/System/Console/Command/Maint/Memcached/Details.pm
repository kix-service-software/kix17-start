# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Memcached::Details;

use strict;
use warnings;

use Data::Dumper;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Cache',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Detailed infos about objects in memcached.');

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

    # get content for cache key
    my $Result = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Key  => $Key,
        Type => $Type,
        Raw  => 1,
    );
    if ($Result) {
        print STDERR Dumper($Result);
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
