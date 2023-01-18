# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
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

package Kernel::System::OAuth2;

use strict;
use warnings;

use URI;
use URI::QueryParam;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Valid',
    'Kernel::System::WebUserAgent',
);

=head1 NAME

Kernel::System::OAuth2 - to authenticate

=head1 DESCRIPTION

Global module to authenticate accounts via OAuth 2.0.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $OAuth2Object = $Kernel::OM->Get('Kernel::System::OAuth2');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'OAuth2';

    return $Self;
}

=item ProfileAdd()

add new oauth2 profile

    my $ID = $OAuth2Object->ProfileAdd(
        Name         => 'Profile',
        URLAuth      => 'URL Auth',
        URLToken     => 'URL Token',
        URLRedirect  => 'URL Redirect',
        ClientID     => "ClientID",
        ClientSecret => "ClientSecret",
        Scope        => "Scope",
        ValidID      => 1,
        UserID       => 123,
    );

=cut

sub ProfileAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a profile with this name already exists
    if ( $Self->ProfileLookup( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A OAuth2 profile with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # store data
    return if !$DBObject->Do(
        SQL => 'INSERT INTO oauth2_profile (name, url_auth, url_token, url_redirect,'
            . ' client_id, client_secret, scope, valid_id,'
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{URLAuth}, \$Param{URLToken}, \$Param{URLRedirect},
            \$Param{ClientID}, \$Param{ClientSecret}, \$Param{Scope}, \$Param{ValidID},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get new profile id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM oauth2_profile WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return if !$ID;

    return $ID;
}

=item ProfileGet()

get profile attributes

    my %Profile = $OAuth2Object->ProfileGet(
        Name  => 'Profile',
    );

    my %Profile = $OAuth2Object->ProfileGet(
        ID    => 123,
    );

returns

    my %Profile = (
        ID           => 1,
        Name         => "Profile",
        URLAuth      => 'URL Auth',
        URLToken     => 'URL Token',
        URLRedirect  => 'URL Redirect',
        ClientID     => "ClientID",
        ClientSecret => "ClientSecret",
        Scope        => "Scope",
        ValidID      => 1,
        CreateTime   => '2010-04-07 15:41:15',
        CreateBy     => '321',
        ChangeTime   => '2010-04-07 15:59:45',
        ChangeBy     => '223',
    );

=cut

sub ProfileGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need ID or Name!"
        );
        return;
    }

    # lookup the ID
    if ( !$Param{ID} ) {
        $Param{ID} = $Self->ProfileLookup(
            Name => $Param{Name},
        );
        if ( !$Param{ID} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ID for OAuth2 profile '$Param{Name}' not found!",
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # ask the database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, url_auth, url_token, url_redirect,'
            . ' client_id, client_secret, scope, valid_id,'
            . ' create_time, create_by, change_time, change_by'
            . ' FROM oauth2_profile WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # fetch the result
    my %Profile;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Profile = (
            ID           => $Data[0],
            Name         => $Data[1],
            URLAuth      => $Data[2],
            URLToken     => $Data[3],
            URLRedirect  => $Data[4],
            ClientID     => $Data[5],
            ClientSecret => $Data[6],
            Scope        => $Data[7],
            ValidID      => $Data[8],
            CreateTime   => $Data[9],
            CreateBy     => $Data[10],
            ChangeTime   => $Data[11],
            ChangeBy     => $Data[12],
        );
    }

    # no data found
    if ( !%Profile ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "OAuth2 profile with ID '$Param{ID}' not found!",
        );
        return;
    }

    return %Profile;
}

=item ProfileUpdate()

update profile attributes

    my $Success = $OAuth2Object->ProfileUpdate(
        ID           => 123,
        Name         => 'Profile',
        URLAuth      => 'URL Auth',
        URLToken     => 'URL Token',
        URLRedirect  => 'URL Redirect',
        ClientID     => "ClientID",
        ClientSecret => "ClientSecret",
        Scope        => "Scope",
        ValidID      => 1,
        UserID       => 123,
    );

=cut

sub ProfileUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a profile with this name already exists
    my $ExistingID = $Self->ProfileLookup(
       Name => $Param{Name},
    );
    if (
        $ExistingID
        && $ExistingID != $Param{ID}
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A OAuth2 profile with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get current data
    my %OldProfile = $Self->ProfileGet(
        ID => $Param{ID},
    );

    # check if token need to be cleaned
    if (
        $Param{URLAuth} ne $OldProfile{URLAuth}
        || $Param{URLToken} ne $OldProfile{URLToken}
        || $Param{ClientID} ne $OldProfile{ClientID}
        || $Param{Scope} ne $OldProfile{Scope}
    ) {
        return if  !$Self->TokenDelete(
            ProfileID => $Param{ID},
        );
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    return if !$DBObject->Do(
        SQL => 'UPDATE oauth2_profile SET name = ?, url_auth = ?, url_token = ?, url_redirect = ?,'
            . ' client_id = ?, client_secret = ?, scope = ?, valid_id = ?,'
            . ' change_time = current_timestamp, change_by = ?'
            . ' WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{URLAuth}, \$Param{URLToken}, \$Param{URLRedirect},
            \$Param{ClientID}, \$Param{ClientSecret}, \$Param{Scope}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID},
        ],
    );

    return 1;
}

=item ProfileList()

get profile list as a hash of ID, Name pairs

    my %List = $OAuth2Object->ProfileList();

or

    my %List = $OAuth2Object->ProfileList(
        Valid  => 1,
    );

or

    my %List = $OAuth2Object->ProfileList(
        Valid  => 0, # is default
    );

returns

    my %List = (
        1 => "Profile",
    );

=cut

sub ProfileList {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

    # check Valid param
    my $Valid = 0;
    if ( $Param{Valid} ) {
        $Valid = 1;
    }

    # build SQL
    my $SQL = 'SELECT id, name FROM oauth2_profile';

    # add WHERE statement
    if ( $Valid ) {
        # create the valid list
        my $ValidIDs = join( ', ', $ValidObject->ValidIDsGet() );

        $SQL .= ' WHERE valid_id IN (' . $ValidIDs . ')';
    }

    # ask database
    return if !$DBObject->Prepare(
        SQL => $SQL,
    );

    # fetch the result
    my %ProfileList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ProfileList{ $Row[0] } = $Row[1];
    }

    return %ProfileList;
}

=item ProfileLookup()

returns the id or the name of a profile

    my $ProfileID = $OAuth2Object->ProfileLookup(
        Name => 'Profile',
    );

or

    my $ProfileName = $OAuth2Object->ProfileLookup(
        ID => 2,
    );

=cut

sub ProfileLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            State   => 'error',
            Message => 'Need Name or ID!'
        );
        return;
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # init data
    my $Key;
    my $Value;
    my $SQL;
    my @Bind;

    # prepare data
    if ( $Param{ID} ) {
        $Key   = 'ID';
        $Value = $Param{ID};
        $SQL   = 'SELECT name FROM oauth2_profile WHERE id = ?';
        push( @Bind, \$Param{ID} );
    }
    else {
        $Key   = 'Name';
        $Value = $Param{Name};
        $SQL   = 'SELECT id FROM oauth2_profile WHERE name = ?';
        push( @Bind, \$Param{Name} );
    }

    # lookup
    $DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    my $ReturnData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ReturnData = $Row[0];
    }

    return $ReturnData;
}

=head2 ProfileDelete()

Delete profile.

    my $Success = $OAuth2Object->ProfileDelete(
        ID => $ID,
    );

=cut

sub ProfileDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete token of profile
    return if !$Self->TokenDelete(
        ProfileID => $Param{ID}
    );

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # init data
    my $SQL  = 'DELETE FROM oauth2_profile WHERE id = ?';
    my @Bind = ( \$Param{ID} );

    # execute
    return if !$DBObject->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    return 1;
}

=head2 TokenAdd()

Add tokens.

    my $Success = $OAuth2Object->TokenAdd(
        ProfileID => $ID,
        TokenType => 'refresh',
        Token     => 'Token',
    );

=cut

sub TokenAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ProfileID TokenType Token)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # delete old token
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM oauth2_token WHERE profile_id = ? AND token_type = ?',
        Bind => [ \$Param{ProfileID}, \$Param{TokenType} ],
    );

    # insert new token
    return if !$DBObject->Do(
        SQL => 'INSERT INTO oauth2_token (profile_id, token_type, token, create_time) '
             . 'VALUES (?, ?, ?, current_timestamp)',
        Bind => [ \$Param{ProfileID}, \$Param{TokenType}, \$Param{Token} ],
    );

    return 1;
}

=item TokenList()

get token list as a hash of type, token pairs

    my %List = $OAuth2Object->TokenList(
        ProfileID => 123,
    );

returns

    my %List = (
        'refresh' => "Token",
    );

=cut

sub TokenList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ProfileID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL => 'SELECT token_type, token FROM oauth2_token WHERE profile_id = ?',
        Bind => [ \$Param{ProfileID} ]
    );

    # fetch the result
    my %TokenList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TokenList{ $Row[0] } = $Row[1];
    }

    return %TokenList;
}

=item TokenLookup()

returns the id or the name of a profile

    my $ProfileID = $OAuth2Object->TokenLookup(
        TokenType => 'state',
        Token     => 'Token',
    );

=cut

sub TokenLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TokenType Token)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # lookup
    $DBObject->Prepare(
        SQL   => 'SELECT profile_id FROM oauth2_token WHERE token_type = ? AND token = ?',
        Bind  => [ \$Param{TokenType}, \$Param{Token} ],
        Limit => 1,
    );

    my $ProfileID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ProfileID = $Row[0];
    }

    # check if data exists
    if ( !defined $ProfileID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No profile for given token found!",
        );
        return;
    }

    return $ProfileID;
}

=head2 TokenDelete()

Delete tokens.

    my $Success = $OAuth2Object->TokenDelete(
        ProfileID => $ID,
        TokenType => 'refresh', # Optional
    );

=cut

sub TokenDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ProfileID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # init data
    my $SQL  = 'DELETE FROM oauth2_token WHERE profile_id = ?';
    my @Bind = ( \$Param{ProfileID} );

    # add token type if provided
    if ( $Param{TokenType} ) {
        $SQL .= ' AND token_type = ?';
        push( @Bind, \$Param{TokenType} );
    }

    # execute
    return if !$DBObject->Do(
        SQL   => $SQL,
        Bind  => \@Bind,
    );

    return 1;
}

=head2 PrepareAuthURL()

Build the URL to request an authorization code.

Example:
    my %AuthURL = $OAuth2Object->PrepareAuthURL(
        URLAuth      => 'URL Auth',
        URLRedirect  => 'URL Redirect',
        ClientID     => "ClientID",
        Scope        => "Scope",
        Login        => "Login",         # Optional
    );

returns

    my %AuthURL = (
        State => "State",
        URL   => "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?...",
    );

=cut

sub PrepareAuthURL {
    my ( $Self, %Param ) = @_;

### Code licensed under the GPL-3.0, Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/ ###
    # check needed stuff
    for (qw(URLAuth URLRedirect ClientID Scope)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # Create a random string to prevent cross-site requests.
    my $RandomString = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
        Length => 32,
    );

    # build authorization url
    my $URL = URI->new( $Param{URLAuth} );
    $URL->query_param_append( 'client_id',     $Param{ClientID} );
    $URL->query_param_append( 'scope',         $Param{Scope} );
    $URL->query_param_append( 'redirect_uri',  $Param{URLRedirect} );
    $URL->query_param_append( 'response_type', 'code' );
    $URL->query_param_append( 'response_mode', 'query' );
    $URL->query_param_append( 'state',         $RandomString );
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/ ###

    return (
        State => $RandomString,
        URL   => $URL->as_string(),
    );
}

=head2 RequestAccessToken()

This can either be used to request an initial access and refresh token or to request a refreshed access token.

Example:
    my $AccessToken = $Self->RequestAccessToken(
        ProfileID => 123,
        GrantType => 'refresh_token',
        Code      => $Code,    # Optional: Only needed in combination with GrantType "authorization_code".
    )

Returns:
    my $AccessToken = '...';

=cut

sub RequestAccessToken {
    my ( $Self, %Param ) = @_;

### Code licensed under the GPL-3.0, Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/ ###
    # check needed stuff
    for (qw(ProfileID GrantType)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Profile = $Self->ProfileGet(
        ID => $Param{ProfileID},
    );
    return if !%Profile;

    # init data
    my %Data = (
        client_id     => $Profile{ClientID},
        client_secret => $Profile{ClientSecret},
        redirect_uri  => $Profile{URLRedirect},
        scope         => $Profile{Scope},
        grant_type    => $Param{GrantType},
    );

    # Add optional parameters.
    if (
        $Param{GrantType} eq 'authorization_code'
        && $Param{Code}
    ) {
        $Data{code} = $Param{Code};
    }
    elsif ( $Param{GrantType} eq 'refresh_token' ) {

        my %TokenList = $Self->TokenList(
            ProfileID => $Param{ProfileID},
        );

        if ( !$TokenList{'refresh'} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No refresh token found for profile ($Param{ProfileID})!"
            );
            return;
        }

        $Data{refresh_token} = $TokenList{'refresh'};
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need GrantType authorization_code and the Code, or GrantType refresh_token!',
        );
        return;
    }

    my %Response = $Kernel::OM->Get('Kernel::System::WebUserAgent')->Request(
        URL  => $Profile{URLToken},
        Type => 'POST',
        Data => \%Data,
    );

    # Server did not accept the request.
    if ( $Response{Status} ne '200 OK' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Got: '$Response{Status}'!",
        );
        return;
    }

    my $ResponseData = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
        Data => ${ $Response{Content} }
    );

    if ( exists $ResponseData->{error} || exists $ResponseData->{error_description} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $ResponseData->{error} . ': ' . $ResponseData->{error_description},
        );
        return;
    }

    # Should not happen if no error message given.
    if ( !$ResponseData->{access_token} || !$ResponseData->{refresh_token} || !$ResponseData->{expires_in} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Host did not provide "access_token", "refresh_token" or "expires_in"!',
        );
        return;
    }

    # renew refresh token if necessary
    if ( !$Data{refresh_token} || $Data{refresh_token} ne $ResponseData->{refresh_token} ) {
        return if !$Self->TokenAdd(
            ProfileID => $Param{ProfileID},
            TokenType => 'refresh',
            Token     => $ResponseData->{refresh_token},
        );
    }
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2023 Rother OSS GmbH, https://otobo.de/ ###

    # Cache the access token until it expires.
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type           => $Self->{CacheType},
        TTL            => ( $ResponseData->{expires_in} - 90 ),               # Add a buffer for latency reasons.
        Key            => "AccessToken::$Param{ProfileID}",
        Value          => $ResponseData->{access_token},
        CacheInMemory  => 0,                                            # Cache in Backend only to enforce TTL
        CacheInBackend => 1,
    );

    return $ResponseData->{access_token};
}

=head2 GetAccessToken()

Request a valid access token for the profile

Example:
    my $AccessToken = $OAuth2Object->GetAccessToken(
        ProfileID => 123,
    )

=cut

sub GetAccessToken {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ProfileID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need ProfileID!"
        );
        return;
    }

    # Try the cache
    my $Token = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => "AccessToken::$Param{ProfileID}",
    );
    return $Token if $Token;

    # Get an access and refresh token.
    my $AccessToken = $Self->RequestAccessToken(
        ProfileID => $Param{ProfileID},
        GrantType => 'refresh_token',
    );
    return if !$AccessToken;

    return $AccessToken;
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
