# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Cache::Delete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Cache',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Deletes cache files created by OTRS.');
    $Self->AddOption(
        Name        => 'expired',
        Description => 'Delete only caches which are expired by TTL.',
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'type',
        Description => 'Define the type of cache which should be deleted (e.g. Ticket or StdAttachment).',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %Options;
    $Options{Expired} = $Self->GetOption('expired');
    $Options{Type}    = $Self->GetOption('type');

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    $Self->Print("<yellow>Deleting cache...</yellow>\n");
    if ( !$CacheObject->CleanUp(%Options) ) {
        return $Self->ExitCodeError();
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
