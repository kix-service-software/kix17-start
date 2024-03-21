# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2019–2021 Efflux GmbH, https://efflux.de/
# Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::System::MailAccount::IMAPS_OAuth2;

use strict;
use warnings;

use IO::Socket::SSL qw( SSL_VERIFY_NONE SSL_VERIFY_PEER );
use Mail::IMAPClient;
use MIME::Base64;

use Kernel::System::PostMaster;

our @ObjectDependencies = (
    'Kernel::System::Config',
    'Kernel::System::Main',
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

    my $Type = 'IMAPS_OAuth2';

### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    # check needed stuff
    for (qw(OAuth2_ProfileID Login Password Host Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            return (
                Successful => 0,
                Message    => $Type . ': Need ' . $_ . q{!},
            );
        }
    }

    # get access token
    my $AccessToken = $OAuth2Object->GetAccessToken(
        ProfileID => $Param{OAuth2_ProfileID}
    );
    if ( !$AccessToken ) {
        return (
            Successful => 0,
            Message    => $Type
                . ': Could not request access token for '
                . $Param{Login}
                . q{/}
                . $Param{Host}
                . '. The refresh token could be expired or invalid.'
        );
    }

    # connect to host
    my $IMAPObject = Mail::IMAPClient->new(
        Server   => $Param{Host},
        Ssl      => [
            SSL_verify_mode => $Param{SSLVerify} ? SSL_VERIFY_PEER : SSL_VERIFY_NONE
        ],
        Debug    => $Param{Debug},
        Uid      => 1,

        # see bug#8791: needed for some Microsoft Exchange backends
        Ignoresizeerrors => 1,
    );

# KIX-kix, Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
    if ( !$IMAPObject ) {
        return (
            Successful => 0,
            Message    => "$Type: Can't connect to $Param{Host}: $!!"
        );
    }
# EO KIX-kix, Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
                Message    => $Type
                    . ': Could not request access token for '
                    . $Param{Login}
                    . q{/}
                    . $Param{Host}
                    . '. The refresh token could be expired or invalid.'
            );
        }
    }

    if ( !$IMAPObject->IsAuthenticated() ) {
        $IMAPObject->close();
        return (
            Successful => 0,
            Message    => $Type
                . ': Auth for user '
                . $Param{Login}
                . q{/}
                . $Param{Host}
                . ' failed!'
        );
    }

    return (
        Successful => 1,
        IMAPObject => $IMAPObject,
# KIX-kix, Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
        Type       => $Type,
# EO KIX-kix, Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
    );
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
}

sub Fetch {
    my ( $Self, %Param ) = @_;

    # fetch again if still messages on the account
    COUNT:
    for ( 1 .. 200 ) {
        return if !$Self->_Fetch(%Param);
        last COUNT if !$Self->{Reconnect};
    }
    return 1;
}

sub _Fetch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Login Password Host Trusted QueueID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$_ not defined!"
            );
            return;
        }
    }
    for (qw(Login Password Host)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Debug = $Param{Debug} || 0;
    my $Limit = $Param{Limit} || 5000;
    my $CMD   = $Param{CMD}   || 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # MaxEmailSize is in kB in SysConfig
    my $MaxEmailSize = $ConfigObject->Get('PostMasterMaxEmailSize') || 1024 * 6;

    # MaxPopEmailSession
    my $MaxPopEmailSession = $ConfigObject->Get('PostMasterReconnectMessage') || 20;

    # SSLVerify
    my $SSLVerify = $ConfigObject->Get('PostMasterSSLVerify');

    my $Timeout      = 60;
    my $FetchCounter = 0;
    my $AuthType     = 'IMAPS_OAuth2';

    $Self->{Reconnect} = 0;

    my %Connect = $Self->Connect(
        %Param,
        Timeout   => $Timeout,
        Debug     => $Debug,
        SSLVerify => $SSLVerify,
    );

    if ( !$Connect{Successful} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$Connect{Message}",
        );
        return;
    }

    # read folder from MailAccount configuration
    my $IMAPFolder = $Param{IMAPFolder} || 'INBOX';

    my $IMAPObject = $Connect{IMAPObject};
    $IMAPObject->select($IMAPFolder) || die "Could not select: $@\n";

    my $Messages = $IMAPObject->messages()
        || die "Could not retrieve messages : $@\n";
    my $NumberOfMessages = scalar @{$Messages};

    if ($CMD) {
        print "$AuthType: I found $NumberOfMessages messages on $Param{Login}/$Param{Host}. "
    }

    # fetch messages
    if ( !$NumberOfMessages ) {
        if ($CMD) {
            print "$AuthType: No messages on $Param{Login}/$Param{Host}\n";
        }
    }
    else {
        MESSAGE_NO:
        for my $Messageno ( @{$Messages} ) {

            # check if reconnect is needed
            $FetchCounter++;
            if ( ($FetchCounter) > $MaxPopEmailSession ) {
                $Self->{Reconnect} = 1;
                if ($CMD) {
                    print "$AuthType: Reconnect Session after $MaxPopEmailSession messages...\n";
                }
                last MESSAGE_NO;
            }
            if ($CMD) {
                print
                    "$AuthType: Message $FetchCounter/$NumberOfMessages ($Param{Login}/$Param{Host})\n";
            }

            # check message size
            my $MessageSize = int( $IMAPObject->size($Messageno) / 1024 );
            if ( $MessageSize > $MaxEmailSize ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message =>
                        "$AuthType: Can't fetch email $Messageno from $Param{Login}/$Param{Host}. "
                        . "Email too big ($MessageSize KB - max $MaxEmailSize KB)!",
                );
            }
            else {

                # safety protection
                my $FetchDelay = ( $FetchCounter % 20 == 0 ? 1 : 0 );
                if ( $FetchDelay && $CMD ) {
                    print "$AuthType: Safety protection: waiting 1 second before processing next mail...\n";
                    sleep 1;
                }

                # get message (header and body)
                my $Message = $IMAPObject->message_string($Messageno);

                if ( !$Message ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "$AuthType: Can't process mail, email no $Messageno is empty!",
                    );
                }
                else {
                    my $PostMasterObject = Kernel::System::PostMaster->new(
                        %{$Self},
                        Email   => \$Message,
                        Trusted => $Param{Trusted} || 0,
                        Debug   => $Debug,
                    );
                    my @Return = $PostMasterObject->Run( QueueID => $Param{QueueID} || 0 );
                    if ( !$Return[0] ) {
                        # get original message again
                        $Message = $IMAPObject->message_string($Messageno);

                        # process failed message
                        my $File = $Self->_ProcessFailed( Email => $Message );
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message  => "$AuthType: Can't process mail, see log sub system ("
                                . "$File, report it on http://www.kixdesk.com/)!",
                        );
                    }

                    # mark email to delete once it was processed
                    $IMAPObject->delete_message($Messageno);
                    undef $PostMasterObject;
                }

                # check limit
                $Self->{Limit}++;
                if ( $Self->{Limit} >= $Limit ) {
                    $Self->{Reconnect} = 0;
                    last MESSAGE_NO;
                }
            }
            if ($CMD) {
                print "\n";
            }
        }
    }

    # log status
    if ( $Debug > 0 || $FetchCounter ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "$AuthType: Fetched $FetchCounter email(s) from $Param{Login}/$Param{Host}.",
        );
    }
    $IMAPObject->close();
    if ($CMD) {
        print "$AuthType: Connection to $Param{Host} closed.\n\n";
    }

    # return if everything is done
    return 1;
}

sub _ProcessFailed {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Email)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$_ not defined!"
            );
            return;
        }
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/var/spool/';
    my $MD5  = $MainObject->MD5sum(
        String => \$Param{Email},
    );
    my $Location = $Home . 'problem-email-' . $MD5;

    return $MainObject->FileWrite(
        Location   => $Location,
        Content    => \$Param{Email},
        Mode       => 'binmode',
        Type       => 'Local',
        Permission => '640',
    );
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
