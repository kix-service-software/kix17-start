# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::MailAccount::Office365;

use strict;
use warnings;

use HTTP::Request;
use LWP::UserAgent;
use Mail::IMAPClient;
use MIME::Base64;
use URI;
use URI::Escape;

use Kernel::System::PostMaster;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::MailAccount',
    'Kernel::System::Main',
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

    # check needed stuff
    for (qw(ID Login Password Host Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $ConfigObject      = $Kernel::OM->Get('Kernel::Config');
    my $JSONObject        = $Kernel::OM->Get('Kernel::System::JSON');
    my $MailAccountObject = $Kernel::OM->Get('Kernel::System::MailAccount');

    # get data of mail account
    my %Data = $MailAccountObject->MailAccountGet(
        ID => $Param{ID},
    );
    if ( !%Data ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid mail account!"
        );
        return;
    }
    for my $Needed ( qw(TenantID ClientID ClientSecret RefreshToken) ) {
        if ( !$Data{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Mail account has no $Needed!"
            );
            return;
        }
    }

    # Create a request
    my $RedirectURI = $ConfigObject->Get('HttpType')
                    . '://'
                    . $ConfigObject->Get('FQDN')
                    . '/'
                    . $ConfigObject->Get('ScriptAlias')
                    . 'index.pl?Action=AdminMailAccount&Subaction=HandleCode';
    my $Content   = 'grant_type=refresh_token'
                  . '&scope=' . URI::Escape::uri_escape_utf8('https://outlook.office365.com/IMAP.AccessAsUser.All offline_access')
                  . '&client_id=' . URI::Escape::uri_escape_utf8($Data{ClientID})
                  . '&client_secret=' . URI::Escape::uri_escape_utf8($Data{ClientSecret})
                  . '&refresh_token=' . URI::Escape::uri_escape_utf8($Data{RefreshToken})
                  . '&redirect_uri=' . URI::Escape::uri_escape_utf8($RedirectURI);
    my $LWPClient = LWP::UserAgent->new();
    my $Request   = HTTP::Request->new(POST => 'https://login.microsoftonline.com/' . $Data{TenantID} . '/oauth2/v2.0/token');
    $Request->content_type('application/x-www-form-urlencoded');
    $Request->content($Content);

    # Pass request to the user agent and get a response back
    my $Response = $LWPClient->request($Request);

    # get content
    my $ResponseContent = $Response->content;
    if ( !$ResponseContent ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid response while fetching token!"
        );
        return;
    }

    # to convert the data into a hash, use the JSON module
    my $ResponseData = $JSONObject->Decode(
        Data => $ResponseContent,
    );

    # check tokens
    if (
        !$ResponseData->{access_token}
        || !$ResponseData->{refresh_token}
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $ResponseData->{error_description} || "Invalid response while fetching token!"
        );
        return;
    }

    # save new refresh token
    $MailAccountObject->SetPreferences(
        MailAccountID => $Param{ID},
        Key           => 'RefreshToken',
        Value         => $ResponseData->{refresh_token},
    );

    # get access token for connection
    my $AccessToken = $ResponseData->{access_token};

    # connect to host
    my $IMAPObject = Mail::IMAPClient->new(
        Server => $Param{Host},
        Debug  => $Param{Debug},
        Ssl    => 1,
        Uid    => 1,

        # see bug#8791: needed for some Microsoft Exchange backends
        Ignoresizeerrors => 1,
    );

    if ( !$IMAPObject ) {
        return (
            Successful => 0,
            Message    => "Office365: Can't connect to $Param{Host}: $@\n"
        );
    }

    # authenticate
    my $OAUTH2_Sign = encode_base64("user=". $Param{Login} ."\x01auth=Bearer ". $AccessToken ."\x01\x01", '');
    my $Success = $IMAPObject->authenticate('XOAUTH2', sub { return $OAUTH2_Sign });
    if ( !$Success ) {
        return (
            Successful => 0,
            Message    => "Office365 Auth error: $IMAPObject->LastError\n"
        );
    }

    return (
        Successful => 1,
        IMAPObject => $IMAPObject,
    );
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

    my $Timeout      = 60;
    my $FetchCounter = 0;
    my $AuthType     = 'IMAPTLS';

    $Self->{Reconnect} = 0;

    my %Connect = $Self->Connect(
        ID       => $Param{ID},
        Host     => $Param{Host},
        Login    => $Param{Login},
        Password => $Param{Password},
        Timeout  => $Timeout,
        Debug    => $Debug
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
                        my $Lines = $IMAPObject->get($Messageno);
                        my $File = $Self->_ProcessFailed( Email => $Message );
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message  => "$AuthType: Can't process mail, see log sub system ("
                                . "$File, report it on http://kixdesk.com/)!",
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

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
