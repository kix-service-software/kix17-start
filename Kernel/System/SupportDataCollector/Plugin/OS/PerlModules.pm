# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::OS::PerlModules;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
);

sub GetDisplayPath {
    return Translatable('Operating System');
}

sub Run {
    my $Self = shift;

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my $Output;

    open( my $FH, "-|", "perl $Home/bin/kix.CheckModules.pl nocolors --all" ) or die "Can't open pipe: ?!";

    while (<$FH>) {
        $Output .= $_;
    }
    close($FH);

    if (
        $Output =~ m{Not \s installed! \s \(required}ismx
        || $Output =~ m{failed!}ismx
    ) {
        $Self->AddResultProblem(
            Label   => Translatable('Perl Modules'),
            Value   => $Output,
            Message => Translatable('Not all required Perl modules are correctly installed.'),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Perl Modules'),
            Value => $Output,
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
