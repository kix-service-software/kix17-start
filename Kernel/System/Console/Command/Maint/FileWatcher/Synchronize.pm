# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::FileWatcher::Synchronize;

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . "/Kernel/cpan-lib";

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Document::FS',
    'Kernel::System::Log',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('KIX-FileWatcher');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create common objects
    $Self->{LogObject}        = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{FileSystemObject} = $Kernel::OM->Get('Kernel::System::Document::FS');

    $Self->{LogObject}->Log( Priority => 'notice', Message => "FileWatcher started." );

    $Self->{FileSystemObject}->_MetaImport();
    $Self->{FileSystemObject}->_MetaSync();

    # $Self->{LogObject}->Log( Priority => 'notice', Message => "FileWatcher syncronized ".$FileCount." files using metadata file." );

    $Self->{LogObject}->Log( Priority => 'notice', Message => "FileWatcher finished." );

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
