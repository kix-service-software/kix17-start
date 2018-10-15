# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::LoaderCache::Rebuild;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout'
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Rebuilds the loader cache.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Rebuilding loader cache...</yellow>\n");

    $Kernel::OM->Get('Kernel::Config')->{'Loader::PreCreatedCaches'} = 0;

    $Kernel::OM->Get('Kernel::Output::HTML::Layout')->LoaderCreateAgentCSSCalls();
    $Kernel::OM->Get('Kernel::Output::HTML::Layout')->LoaderCreateAgentJSCalls();
    $Kernel::OM->Get('Kernel::Output::HTML::Layout')->LoaderCreateCustomerCSSCalls();
    $Kernel::OM->Get('Kernel::Output::HTML::Layout')->LoaderCreateCustomerJSCalls();

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
