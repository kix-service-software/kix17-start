# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::SwitchButton;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $GroupObject        = $Kernel::OM->Get('Kernel::System::Group');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $SessionObject      = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    # check needed stuff
    for my $Needed (qw(Type)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            return $LayoutObject->ErrorScreen( Message => "Need $Needed!", );
        }
    }

    # get baselink for switch
    my $BaseLink = $LayoutObject->{Baselink};

    # switch from agents to customers frontend
    if ( $Param{Type} eq 'Customer' ) {

        # get agents user data
        my %AgentData = $UserObject->GetUserData(
            UserID => $Self->{UserID},
        );

        # get customers data
        my %CustomerData =
            $CustomerUserObject->CustomerUserDataGet( User => $AgentData{UserLogin} );

        # redirect to agents frontend if no customer exists with this login
        if (
            !%CustomerData
            || !$CustomerData{UserLogin}
            || ( defined $CustomerData{ValidID} && !$CustomerData{ValidID} )
            )
        {
            return $LayoutObject->Redirect(
                OP => '&Reason=NotACustomer'
            );
        }

        # last login preferences update
        $UserObject->SetPreferences(
            UserID => $AgentData{UserID},
            Key    => 'UserLastLogin',
            Value  => $TimeObject->SystemTime(),
        );

        # create new session id
        my $NewSessionID = $SessionObject->CreateSessionID(
            %CustomerData,
            UserLastRequest => $TimeObject->SystemTime(),
            UserType        => 'Customer',
        );

        # get customer interface session name
        my $SessionName = $ConfigObject->Get('CustomerPanelSessionName') || 'CSID';

        # create a new LayoutObject with SessionIDCookie
        my $Expires = '+' . $ConfigObject->Get('SessionMaxTime') . 's';
        if ( !$ConfigObject->Get('SessionUseCookieAfterBrowserClose') ) {
            $Expires = '';
        }

        my $SecureAttribute;
        if ( $ConfigObject->Get('HttpType') eq 'https' ) {

            # Restrict Cookie to HTTPS if it is used.
            $SecureAttribute = 1;
        }

        my $LayoutObject = Kernel::Output::HTML::Layout->new(
            %{$Self},
            SetCookies => {
                SessionIDCookie => $ParamObject->SetCookie(
                    Key      => $SessionName,
                    Value    => $NewSessionID,
                    Expires  => $Expires,
                    Path     => $ConfigObject->Get('ScriptAlias'),
                    Secure   => scalar $SecureAttribute,
                    HTTPOnly => 1,
                ),
            },
            SessionID   => $NewSessionID,
            SessionName => $ConfigObject->Get('SessionName'),
        );

        # log event
        $LogObject->Log(
            Priority => 'notice',
            Message =>
                "Switched from Agent to Customer ($Self->{UserLogin} -=> $CustomerData{UserLogin})",
        );

        # build URL to customer interface
        my $URL = $ConfigObject->Get('HttpType')
            . '://'
            . $ConfigObject->Get('FQDN')
            . '/'
            . $ConfigObject->Get('ScriptAlias')
            . 'customer.pl';

        # if no sessions are used we attach the session as URL parameter
        if ( !$ConfigObject->Get('SessionUseCookie') ) {
            $URL .= "?$SessionName=$NewSessionID";
        }

        # redirect to customer interface with new session id
        return $LayoutObject->Redirect( ExtURL => $URL );

    }

    # switch from customers to agents frontend
    else {

        # change baselink
        $BaseLink =~ s/customer.pl/index.pl/g;

        # get customers user data
        my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
            User => $Self->{UserID},
        );

        # get agents data
        my %AgentData =
            $UserObject->GetUserData( User => $CustomerData{UserLogin}, Valid => 1 );

        # redirect to customers frontend if no agent exists with this login
        if ( !%AgentData || !$AgentData{UserLogin} ) {
            return $LayoutObject->Redirect(
                OP => 'Action=' . $Self->{Action} . ';Reason=NotAnAgent'
            );
        }

        # last login preferences update
        $UserObject->SetPreferences(
            UserID => $AgentData{UserID},
            Key    => 'UserLastLogin',
            Value  => $TimeObject->SystemTime(),
        );

        # get groups with rw permission
        my %GroupData = $GroupObject->GroupMemberList(
            Result => 'HASH',
            Type   => 'rw',
            UserID => $AgentData{UserID},
        );
        foreach ( keys %GroupData ) {
            $AgentData{"UserIsGroup[$GroupData{$_}]"} = 'Yes';
        }

        # get groups with ro permission
        %GroupData = $GroupObject->GroupMemberList(
            Result => 'HASH',
            Type   => 'ro',
            UserID => $AgentData{UserID},
        );
        foreach ( keys %GroupData ) {
            $AgentData{"UserIsGroupRo[$GroupData{$_}]"} = 'Yes';
        }

        # create new session id
        my $NewSessionID = $SessionObject->CreateSessionID(
            _UserLogin => $CustomerData{UserLogin},
            _UserPw    => $CustomerData{UserPassword},
            %AgentData,
            UserLastRequest => $TimeObject->SystemTime(),
            UserType        => 'User',
        );

        # get customer interface session name
        my $SessionName = $ConfigObject->Get('SessionName') || 'Session';

        my $Expires = '+' . $ConfigObject->Get('SessionMaxTime') . 's';
        if ( !$ConfigObject->Get('SessionUseCookieAfterBrowserClose') ) {
            $Expires = '';
        }

        my $SecureAttribute;
        if ( $ConfigObject->Get('HttpType') eq 'https' ) {

            # Restrict Cookie to HTTPS if it is used.
            $SecureAttribute = 1;
        }

        my $LayoutObject = Kernel::Output::HTML::Layout->new(
            %{$Self},
            SetCookies => {
                SessionIDCookie => $ParamObject->SetCookie(
                    Key      => $SessionName,
                    Value    => $NewSessionID,
                    Expires  => $Expires,
                    Path     => $ConfigObject->Get('ScriptAlias'),
                    Secure   => scalar $SecureAttribute,
                    HTTPOnly => 1,
                ),
            },
            SessionID => $NewSessionID,
            SessionName => $Param{SessionName} || $SessionName,
            %{$Self},
        );

        # log event
        $LogObject->Log(
            Priority => 'notice',
            Message =>
                "Switched from Customer to Agent ($Self->{UserID} -=> $AgentData{UserLogin})",
        );

        # build URL to customer interface
        my $URL = $ConfigObject->Get('HttpType')
            . '://'
            . $ConfigObject->Get('FQDN')
            . '/'
            . $ConfigObject->Get('ScriptAlias')
            . 'index.pl';

        # if no sessions are used we attach the session as URL parameter
        if ( !$ConfigObject->Get('SessionUseCookie') ) {
            $URL .= "?$SessionName=$NewSessionID";
        }

        # redirect to customer interface with new session id
        return $LayoutObject->Redirect( ExtURL => $URL );

    }
}

1;
