# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::CustomerUser::Add;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    # rkaiser - T#2017020290001194 - changed customer user to contact
    $Self->Description('Add a contact.');
    $Self->AddOption(
        Name        => 'user-name',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "User name for the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'first-name',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "First name of the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'last-name',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "Last name of the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'email-address',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "Email address of the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'customer-id',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "Customer ID for the new contact.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'password',
        # rkaiser - T#2017020290001194 - changed customer user to contact
        Description => "Password for the new contact. If left empty, a password will be generated automatically.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Adding a new customer user...</yellow>\n");

    # add customer user
    if (
        !$Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserAdd(
            Source         => 'CustomerUser',
            UserLogin      => $Self->GetOption('user-name'),
            UserFirstname  => $Self->GetOption('first-name'),
            UserLastname   => $Self->GetOption('last-name'),
            UserCustomerID => $Self->GetOption('customer-id'),
            UserPassword   => $Self->GetOption('password'),
            UserEmail      => $Self->GetOption('email-address'),
            UserID         => 1,
            ChangeUserID   => 1,
            ValidID        => 1,
        )
        )
    {
        $Self->PrintError("Can't add customer user.");
        return $Self->ExitCodeError();
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
