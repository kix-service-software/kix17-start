# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2019–2021 Efflux GmbH, https://efflux.de/
# Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::System::MailAccount::IMAPTLS_OAuth2;

use strict;
use warnings;

use Mail::IMAPClient;
use MIME::Base64;

use parent qw(Kernel::System::MailAccount::IMAPTLS);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::OAuth2',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Connect {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $OAuth2Object = $Kernel::OM->Get('Kernel::System::OAuth2');

    my $Type = 'IMAPTLS_OAuth2';

### Code licensed under the GPL-3.0, Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/ ###
    # check needed stuff
    for (qw(OAuth2_ProfileID Login Password Host Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            return (
                Successful => 0,
                Message    => $Type . ': Need ' . $_ . '!',
            );
        }
    }

    # get access token
    my $AccessToken = $OAuth2Object->GetAccessToken(
        ProfileID => $Param{OAuth2_ProfileID},
    );
    if ( !$AccessToken ) {
        return (
            Successful => 0,
            Message    => $Type . ': Could not request access token for ' . $Param{Login} . '/' . $Param{Host} . '. The refresh token could be expired or invalid.'
        );
    }

    # connect to host
    my $IMAPObject = Mail::IMAPClient->new(
        Server   => $Param{Host},
        Starttls => [ SSL_verify_mode => 0 ],
        Debug    => $Param{Debug},
        Uid      => 1,

        # see bug#8791: needed for some Microsoft Exchange backends
        Ignoresizeerrors => 1,
    );

# KIX-kix, Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
    if ( !$IMAPObject ) {
        return (
            Successful => 0,
            Message    => $Type . ': Could not connect to ' . $Param{Host} . ': ' . $! . '!'
        );
    }
# EO KIX-kix, Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com

    # try it 2 times to authenticate with the IMAP server
    TRY:
    for my $Try ( 1 .. 2 ) {
        # auth via SASL XOAUTH2
        my $SASLXOAUTH2 = encode_base64( 'user=' . $Param{Login} . "\x01auth=Bearer " . $AccessToken . "\x01\x01" );
        $IMAPObject->authenticate( 'XOAUTH2', sub { return $SASLXOAUTH2 } );

        last TRY if ( $IMAPObject->IsAuthenticated() );

        # sleep 0,3 seconds;
        sleep( 0.3 );

        # get a new access token
        $AccessToken = $OAuth2Object->RequestAccessToken(
            ProfileID => $Param{OAuth2_ProfileID},
            GrantType => 'refresh_token'
        );
        if ( !$AccessToken ) {
            $IMAPObject->close();
            return (
                Successful => 0,
                Message    => $Type . ': Could not request access token for ' . $Param{Login} . '/' . $Param{Host} . '. The refresh token could be expired or invalid.'
            );
        }
    }

    if ( !$IMAPObject->IsAuthenticated() ) {
        $IMAPObject->close();
        return (
            Successful => 0,
            Message    => $Type . ': Auth for user ' . $Param{Login} . '/' . $Param{Host} . ' failed!'
        );
    }

    return (
        Successful => 1,
        IMAPObject => $IMAPObject,
# KIX-kix, Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
        Type       => $Type,
# EO KIX-kix, Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
    );
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/ ###
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. This program is
licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
For details, see the enclosed files LICENSE (AGPL) and
LICENSE-GPL3 (GPL3) for license information. If you did not receive
this files, see <https://www.gnu.org/licenses/agpl.txt> (APGL) and
<https://www.gnu.org/licenses/gpl-3.0.txt> (GPL3).

=cut
