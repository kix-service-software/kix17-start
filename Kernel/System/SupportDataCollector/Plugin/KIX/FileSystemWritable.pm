# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::FileSystemWritable;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my @TestDirectories = qw(
        /bin/
        /Kernel/
        /Kernel/System/
        /Kernel/Output/
        /Kernel/Output/HTML/
        /Kernel/Modules/
    );

    my @ReadonlyDirectories;

    for my $TestDirectory (@TestDirectories) {
        my $File = $Home . $TestDirectory . "check_permissions.$$";
        if ( open( my $FH, '>', "$File" ) ) {
            print $FH "test";
            close($FH);
            unlink $File;
        }
        else {
            push @ReadonlyDirectories, $TestDirectory;
        }
    }

    if (@ReadonlyDirectories) {
        $Self->AddResultProblem(
            Label   => Translatable('File System Writable'),
            Value   => join( ', ', @ReadonlyDirectories ),
            Message => Translatable('The file system on your KIX partition is not writable.'),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('File System Writable'),
            Value => '',
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
