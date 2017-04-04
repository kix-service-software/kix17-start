# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Memcached::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Cache',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Infos about objects in memcached.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get all cached object types
    my $Result = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Key  => 'CachedObjects',
        Type => 'Memcached',
        Raw  => 1,
    );
    if ( $Result && ref($Result) eq 'HASH' ) {
        foreach my $Type ( sort keys %{$Result} ) {
            print $Type. "\n";
        }
    }
    else {
        $Self->Print("You can't use the \"all\" option, because there is no information about the cached objects stored in the memcache. This is the case if you've deaktivated the option \"Cache::Module::Memcached###CacheMetaInfo\" in the SysConfig.");
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
