# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::CustomerUser::SetPassword;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CustomerUser',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    # rkaiser - T#2017020290001194 - changed customer user to contact
    $Self->Description('Updates the password for a contact.');
    $Self->AddArgument(
        Name        => 'user',
        Description => "Specify the user login of the agent/customer to be updated.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddArgument(
        Name        => 'password',
        Description => "Set a new password for the user (a password will be generated otherwise).",
        Required    => 0,
        ValueRegex  => qr/.*/smx,
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Login = $Self->GetArgument('user');

    $Self->Print("<yellow>Setting password for user $Login...</yellow>\n");

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my %CustomerUserList   = $CustomerUserObject->CustomerSearch(
        UserLogin => $Login,
    );

    if ( !scalar %CustomerUserList ) {
        # rkaiser - T#2017020290001194 - changed customer user to contact
        $Self->PrintError("No contact found with login '$Login'!\n");
        return $Self->ExitCodeError();
    }

    # if no password has been provided, generate one
    my $Password = $Self->GetArgument('password');
    if ( !$Password ) {
        $Password = $CustomerUserObject->GenerateRandomPassword( Size => 12 );
        $Self->Print("<yellow>Generated password '$Password'.</yellow>\n");
    }

    my $Result = $CustomerUserObject->SetPassword(
        UserLogin => $Login,
        PW        => $Password,
    );

    if ( !$Result ) {
        $Self->PrintError("Failed to set password!\n");
        return $Self->ExitCodeError();
    }

    # rkaiser - T#2017020290001194 - changed customer user to contact
    $Self->Print("<green>Successfully set password for contact '$Login'.</green>\n");
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
