# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::sample::GenericAgent::TestSystemCallModule;

use strict;
use warnings;

use Kernel::System::ObjectManager;

our @ObjectDependencies = (
    'Kernel::System::Console::Command::Maint::PostMaster::SpoolMailsReprocess',
);

=head1 NAME

scripts::test::sample::GenericAgent::TestSystemCallModule - Generic Agent test module

=head1 SYNOPSIS

This test modules calls the console command Maint::PostMaster::SpoolMailsReproces that internally do a
system call to Maint::PostMaster::Read.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $GenericAgentModuleObject = $Kernel::OM-Get('scripts::test::sample::GenericAgent::TestSystemCallModule');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );


    return $Self;
}

=item Run()

Performs a call to Maint::PostMaster::SpoolMailsReproces.

    my $Success = $GenericAgentModuleObject->Run()

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->Get('Kernel::System::Console::Command::Maint::PostMaster::SpoolMailsReprocess')->Execute();

    return 1;
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
