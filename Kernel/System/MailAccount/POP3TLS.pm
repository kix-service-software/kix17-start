# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::MailAccount::POP3TLS;

use strict;
use warnings;

use IO::Socket::SSL qw( SSL_VERIFY_NONE SSL_VERIFY_PEER );
use Net::POP3;

use base qw(Kernel::System::MailAccount::POP3);

our @ObjectDependencies = (
    'Kernel::System::Log',
);

# Use Net::SSLGlue::POP3 on systems with older Net::POP3 modules that do not provide starttls
BEGIN {
    if ( !defined &Net::POP3::starttls ) {
        require Net::SSLGlue::POP3;
    }
}

sub Connect {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Login Password Host Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Type = 'POP3TLS';

    # connect to host
    my $PopObject = Net::POP3->new(
        $Param{Host},
        Timeout => $Param{Timeout},
        Debug   => $Param{Debug},
    );

    if ( !$PopObject ) {
        return (
            Successful => 0,
            Message    => "$Type: Can't connect to $Param{Host}"
        );
    }

    $PopObject->starttls(
        SSL             => 1,
        SSL_verify_mode => $Param{SSLVerify} ? SSL_VERIFY_PEER : SSL_VERIFY_NONE,
    );

    # authentication
    my $NOM = $PopObject->login( $Param{Login}, $Param{Password} );
    if ( !defined $NOM ) {
        $PopObject->quit();
        return (
            Successful => 0,
            Message    => "$Type: Auth for user $Param{Login}/$Param{Host} failed!"
        );
    }

    return (
        Successful => 1,
        PopObject  => $PopObject,
        NOM        => $NOM,
        Type       => $Type,
    );
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
