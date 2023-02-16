# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Email::SMTPS;

use strict;
use warnings;

use Net::SMTP;

use base qw(Kernel::System::Email::SMTP);

our @ObjectDependencies = (
    'Kernel::System::Log',
);

## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)

# Use Net::SSLGlue::SMTP on systems with older Net::SMTP modules that do not provide starttls
BEGIN {
    if ( !defined &Net::SMTP::starttls ) {
        require Net::SSLGlue::SMTP;
    }
}

sub _Connect {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(MailHost FQDN)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # Remove a possible port from the FQDN value
    my $FQDN = $Param{FQDN};
    $FQDN =~ s{:\d+}{}smx;

    # set up connection connection
    my $SMTP = Net::SMTP->new(
        $Param{MailHost},
        Hello           => $FQDN,
        Port            => $Param{SMTPPort} || 465,
        Timeout         => 30,
        Debug           => $Param{SMTPDebug},
        SSL             => 1,
        SSL_verify_mode => 0,
    );

    return $SMTP;
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
