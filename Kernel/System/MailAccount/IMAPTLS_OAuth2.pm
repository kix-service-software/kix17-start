# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# Copyright (C) 2019–2021 Efflux GmbH, https://efflux.de/
# Copyright (C) 2019-2021 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
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

    my $Type = 'IMAP_OAuth2';

    # check needed stuff
    for (qw(OAuth2_ProfileID Login Password Host Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            return (
                Successful => 0,
                Message    => "Type: Need $_!",
            );
        }
    }

    my $AccessToken = $Kernel::OM->Get('Kernel::System::OAuth2')->GetAccessToken(
        ProfileID => $Param{OAuth2_ProfileID}
    );

    if ( !$AccessToken ) {
        return (
            Successful => 0,
            Message    => "$Type: Could not request access token for $Param{Login}/$Param{Host}'. The refresh token could be expired or invalid."
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

    # Auth via SASL XOAUTH2.
    my $SASLXOAUTH2 = encode_base64( 'user=' . $Param{Login} . "\x01auth=Bearer " . $AccessToken . "\x01\x01" );
    $IMAPObject->authenticate( 'XOAUTH2', sub { return $SASLXOAUTH2 } );

    if ( !$IMAPObject || !$IMAPObject->IsAuthenticated() ) {
        return (
            Successful => 0,
            Message    => "$Type: Can't connect to $Param{Host}: $@\n"
        );
    }

    return (
        Successful => 1,
        IMAPObject => $IMAPObject,
        Type       => $Type,
    );
}

1;
