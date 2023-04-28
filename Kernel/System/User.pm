# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with patches licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::System::User;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

use Crypt::PasswdMD5 qw(unix_md5_crypt apache_md5_crypt);
use Digest::SHA;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::CheckItem',
    'Kernel::System::DB',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::SearchProfile',
    'Kernel::System::Time',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::User - user lib

=head1 SYNOPSIS

All user functions. E. g. to add and updated user and other functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get user table
    $Self->{UserTable}       = $ConfigObject->Get('DatabaseUserTable')       || 'user';
    $Self->{UserTableUserID} = $ConfigObject->Get('DatabaseUserTableUserID') || 'id';
    $Self->{UserTableUserPW} = $ConfigObject->Get('DatabaseUserTableUserPW') || 'pw';
    $Self->{UserTableUser}   = $ConfigObject->Get('DatabaseUserTableUser')   || 'login';

    $Self->{CacheType} = 'User';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('Kernel::System::DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'User::EventModulePost',
    );

    return $Self;
}

=item GetUserData()

get user data (UserLogin, UserFirstname, UserLastname, UserEmail, ...)

    my %User = $UserObject->GetUserData(
        UserID => 123,
    );

    or

    my %User = $UserObject->GetUserData(
        User          => 'franz',
        Valid         => 1,       # not required -> 0|1 (default 0)
                                  # returns only data if user is valid
        NoOutOfOffice => 1,       # not required -> 0|1 (default 0)
                                  # returns data without out of office infos
    );

=cut

sub GetUserData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} && !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need User or UserID!',
        );
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get configuration for the full name order
    my $FirstnameLastNameOrder = $ConfigObject->Get('FirstnameLastnameOrder') || 0;

    # check if result is cached
    if ( $Param{Valid} ) {
        $Param{Valid} = 1;
    }
    else {
        $Param{Valid} = 0;
    }
    if ( $Param{NoOutOfOffice} ) {
        $Param{NoOutOfOffice} = 1;
    }
    else {
        $Param{NoOutOfOffice} = 0;
    }

    my $CacheKey;
    if ( $Param{User} ) {
        $CacheKey = join '::', 'GetUserData', 'User',
            $Param{User},
            $Param{Valid},
            $FirstnameLastNameOrder,
            $Param{NoOutOfOffice};
    }
    else {
        $CacheKey = join '::', 'GetUserData', 'UserID',
            $Param{UserID},
            $Param{Valid},
            $FirstnameLastNameOrder,
            $Param{NoOutOfOffice};
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get initial data
    my @Bind;
    my $SQL = "SELECT $Self->{UserTableUserID}, $Self->{UserTableUser}, "
        . " title, first_name, last_name, $Self->{UserTableUserPW}, valid_id, "
        . " create_time, change_time FROM $Self->{UserTable} WHERE ";

    if ( $Param{User} ) {
        my $User = lc $Param{User};
        $SQL .= " $Self->{Lower}($Self->{UserTableUser}) = ?";
        push @Bind, \$User;
    }
    else {
        $SQL .= " $Self->{UserTableUserID} = ?";
        push @Bind, \$Param{UserID};
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{UserID}        = $Row[0];
        $Data{UserLogin}     = $Row[1];
        $Data{UserTitle}     = $Row[2];
        $Data{UserFirstname} = $Row[3];
        $Data{UserLastname}  = $Row[4];
        $Data{UserPw}        = $Row[5];
        $Data{ValidID}       = $Row[6];
        $Data{CreateTime}    = $Row[7];
        $Data{ChangeTime}    = $Row[8];
    }

    # check data
    if ( !$Data{UserID} ) {
        if ( $Param{User} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Panic! No UserData for user: '$Param{User}'!!!",
            );
            return;
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Panic! No UserData for user id: '$Param{UserID}'!!!",
            );
            return;
        }
    }

    # Store CacheTTL locally so that we can reduce it for users that are out of office.
    my $CacheTTL = $Self->{CacheTTL};

    # check valid, return if there is locked for valid users
    if ( $Param{Valid} ) {

        my $Hit = 0;

        for ( $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet() ) {
            if ( $_ eq $Data{ValidID} ) {
                $Hit = 1;
            }
        }

        if ( !$Hit ) {

            # set cache
            $Kernel::OM->Get('Kernel::System::Cache')->Set(
                Type  => $Self->{CacheType},
                TTL   => $CacheTTL,
                Key   => $CacheKey,
                Value => {},
            );
            return;
        }
    }

    # generate the full name and save it in the hash
    my $UserFullname = $Self->_UserFullname(
        %Data,
        NameOrder => $FirstnameLastNameOrder,
    );

    # save the generated fullname in the hash.
    $Data{UserFullname} = $UserFullname;

    # get preferences
    my %Preferences = $Self->GetPreferences( UserID => $Data{UserID} );

    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # add last login timestamp
    if ( $Preferences{UserLastLogin} ) {
        $Preferences{UserLastLoginTimestamp} = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $Preferences{UserLastLogin},
        );
    }

    # check compat stuff
    if ( !$Preferences{UserEmail} ) {
        $Preferences{UserEmail} = $Data{UserLogin};
    }

    # out of office check
    if ( !$Param{NoOutOfOffice} ) {
        if ( $Preferences{OutOfOffice} ) {
            my $Time = $TimeObject->SystemTime();
            my $Start
                = "$Preferences{OutOfOfficeStartYear}-$Preferences{OutOfOfficeStartMonth}-$Preferences{OutOfOfficeStartDay} 00:00:00";
            my $TimeStart = $TimeObject->TimeStamp2SystemTime(
                String => $Start,
            );
            my $End
                = "$Preferences{OutOfOfficeEndYear}-$Preferences{OutOfOfficeEndMonth}-$Preferences{OutOfOfficeEndDay} 23:59:59";
            my $TimeEnd = $TimeObject->TimeStamp2SystemTime(
                String => $End,
            );
            if ( $TimeStart < $Time && $TimeEnd > $Time ) {
                my $OutOfOfficeMessageTemplate =
                    $ConfigObject->Get('OutOfOfficeMessageTemplate') || '*** out of office until %s (%s d left) ***';
                my $TillDate = sprintf(
                    '%04d-%02d-%02d',
                    $Preferences{OutOfOfficeEndYear},
                    $Preferences{OutOfOfficeEndMonth},
                    $Preferences{OutOfOfficeEndDay}
                );
                my $Till = int( ( $TimeEnd - $Time ) / 60 / 60 / 24 );
                $Preferences{OutOfOfficeMessage} = sprintf( $OutOfOfficeMessageTemplate, $TillDate, $Till );
                $Data{UserLastname} .= ' ' . $Preferences{OutOfOfficeMessage};
            }

            # Reduce CacheTTL to one hour for users that are out of office to make sure the cache expires timely
            #   even if there is no update action.
            $CacheTTL = 60 * 60 * 1;
        }
    }

    # merge hash
    %Data = ( %Data, %Preferences );

    # add preferences defaults
    my $Config = $ConfigObject->Get('PreferencesGroups');
    if ( $Config && ref $Config eq 'HASH' ) {

        KEY:
        for my $Key ( sort keys %{$Config} ) {

            next KEY if !defined $Config->{$Key}->{DataSelected};

            # check if data is defined
            next KEY if defined $Data{ $Config->{$Key}->{PrefKey} };

            # set default data
            $Data{ $Config->{$Key}->{PrefKey} } = $Config->{$Key}->{DataSelected};
        }
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $CacheTTL,
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=item UserAdd()

to add new users

    my $UserID = $UserObject->UserAdd(
        UserFirstname => 'Huber',
        UserLastname  => 'Manfred',
        UserLogin     => 'mhuber',
        UserPw        => 'some-pass', # not required
        UserEmail     => 'email@example.com',
        UserMobile    => '1234567890', # not required
        ValidID       => 1,
        ChangeUserID  => 123,
    );

=cut

sub UserAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserFirstname UserLastname UserLogin UserEmail ValidID ChangeUserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # check if a user with this login (username) already exits
    if ( $Self->UserLoginExistsCheck( UserLogin => $Param{UserLogin} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A user with username '$Param{UserLogin}' already exists!"
        );
        return;
    }

    # check email address
    if (
        $Param{UserEmail}
        && !$Kernel::OM->Get('Kernel::System::CheckItem')->CheckEmail( Address => $Param{UserEmail} )
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Email address ($Param{UserEmail}) not valid ("
                . $Kernel::OM->Get('Kernel::System::CheckItem')->CheckError() . ")!",
        );
        return;
    }

    # check password
    if ( !$Param{UserPw} ) {
        $Param{UserPw} = $Self->GenerateRandomPassword();
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # Don't store the user's password in plaintext initially. It will be stored in a
    #   hashed version later with SetPassword().
    my $RandomPassword = $Self->GenerateRandomPassword();

    # sql
    return if !$DBObject->Do(
        SQL => "INSERT INTO $Self->{UserTable} "
            . "(title, first_name, last_name, "
            . " $Self->{UserTableUser}, $Self->{UserTableUserPW}, "
            . " valid_id, create_time, create_by, change_time, change_by)"
            . " VALUES "
            . " (?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)",
        Bind => [
            \$Param{UserTitle}, \$Param{UserFirstname}, \$Param{UserLastname},
            \$Param{UserLogin}, \$RandomPassword, \$Param{ValidID},
            \$Param{ChangeUserID}, \$Param{ChangeUserID},
        ],
    );

    # get new user id
    my $UserLogin = lc $Param{UserLogin};
    return if !$DBObject->Prepare(
        SQL => "SELECT $Self->{UserTableUserID} FROM $Self->{UserTable} "
            . " WHERE $Self->{Lower}($Self->{UserTableUser}) = ?",
        Bind  => [ \$UserLogin ],
        Limit => 1,
    );

    # fetch the result
    my $UserID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $UserID = $Row[0];
    }

    # check if user exists
    if ( !$UserID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Unable to create User: '$Param{UserLogin}' ($Param{ChangeUserID})!",
        );
        return;
    }

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message =>
            "User: '$Param{UserLogin}' ID: '$UserID' created successfully ($Param{ChangeUserID})!",
    );

    # set password
    $Self->SetPassword(
        UserLogin => $Param{UserLogin},
        PW        => $Param{UserPw}
    );

    # set email address
    $Self->SetPreferences(
        UserID => $UserID,
        Key    => 'UserEmail',
        Value  => $Param{UserEmail}
    );

    # set mobile phone
    $Self->SetPreferences(
        UserID => $UserID,
        Key    => 'UserMobile',
        Value  => $Param{UserMobile} || '',
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # trigger event
    $Self->EventHandler(
        Event => 'UserAdd',
        Data  => {
            UserLogin => $Param{UserLogin},
            NewData   => \%Param,
        },
        UserID => $UserID,
    );

    return $UserID;
}

=item UserUpdate()

to update users

    $UserObject->UserUpdate(
        UserID        => 4321,
        UserFirstname => 'Huber',
        UserLastname  => 'Manfred',
        UserLogin     => 'mhuber',
        UserPw        => 'some-pass', # not required
        UserEmail     => 'email@example.com',
        UserMobile    => '1234567890', # not required
        ValidID       => 1,
        ChangeUserID  => 123,
    );

=cut

sub UserUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    my %FixUserStuffHash = ();
    for (qw(UserID UserFirstname UserLastname UserLogin ValidID ChangeUserID)) {
        $FixUserStuffHash{$_} = 1;
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # store old user login for later use
    my $OldUserLogin = $Self->UserLookup(
        UserID => $Param{UserID},
    );

    # check if a user with this login (username) already exists
    if (
        $Self->UserLoginExistsCheck(
            UserLogin => $Param{UserLogin},
            UserID    => $Param{UserID}
        )
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A user with username '$Param{UserLogin}' already exists!"
        );
        return;
    }

    # check email address
    if (
        $Param{UserEmail}
        && !$Kernel::OM->Get('Kernel::System::CheckItem')->CheckEmail( Address => $Param{UserEmail} )
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Email address ($Param{UserEmail}) not valid ("
                . $Kernel::OM->Get('Kernel::System::CheckItem')->CheckError() . ")!",
        );
        return;
    }

    # update db
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE $Self->{UserTable} SET title = ?, first_name = ?, last_name = ?, "
            . " $Self->{UserTableUser} = ?, valid_id = ?, "
            . " change_time = current_timestamp, change_by = ? "
            . " WHERE $Self->{UserTableUserID} = ?",
        Bind => [
            \$Param{UserTitle}, \$Param{UserFirstname}, \$Param{UserLastname},
            \$Param{UserLogin}, \$Param{ValidID}, \$Param{ChangeUserID}, \$Param{UserID},
        ],
    );

    # check pw
    if ( $Param{UserPw} ) {
        $Self->SetPassword(
            UserLogin => $Param{UserLogin},
            PW        => $Param{UserPw}
        );
        $FixUserStuffHash{UserPw} = 1;
    }

    for my $ParamKey ( keys %Param ) {
        if (
            $ParamKey =~ /^User/
            && !$FixUserStuffHash{$ParamKey}
        ) {
            $Self->SetPreferences(
                UserID => $Param{UserID},
                Key    => $ParamKey,
                Value  => $Param{$ParamKey}
            );
        }
    }

    # update search profiles if the UserLogin changed
    if ( lc $OldUserLogin ne lc $Param{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileUpdateUserLogin(
            Base         => 'TicketSearch',
            UserLogin    => $OldUserLogin,
            NewUserLogin => $Param{UserLogin},
        );
    }

    $Self->_UserCacheClear( UserID => $Param{UserID} );

    # TODO Not needed to delete the cache if ValidID or Name was not changed

    my $CacheObject            = $Kernel::OM->Get('Kernel::System::Cache');
    my $SystemPermissionConfig = $Kernel::OM->Get('Kernel::Config')->Get('System::Permission') || [];

    for my $Type ( @{$SystemPermissionConfig}, 'rw' ) {

        $CacheObject->Delete(
            Type => 'GroupPermissionUserGet',
            Key  => 'PermissionUserGet::' . $Param{UserID} . '::' . $Type,
        );
    }

    $CacheObject->CleanUp(
        Type => 'GroupPermissionGroupGet',
    );

    # trigger event
    $Self->EventHandler(
        Event => 'UserUpdate',
        Data  => {
            UserID       => $Param{UserID},
            OldUserLogin => $OldUserLogin,
            NewData      => \%Param,
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item UserSearch()

to search users

    my %List = $UserObject->UserSearch(
        Search => '*some*', # also 'hans+huber' possible
        Valid  => 1, # not required
    );

    my %List = $UserObject->UserSearch(
        UserLogin => '*some*',
        Limit     => 50,
        Valid     => 1, # not required
    );

    my %List = $UserObject->UserSearch(
        PostMasterSearch => 'email@example.com',
        Valid            => 1, # not required
    );

Returns hash of UserID, Login pairs:

    my %List = (
        1 => 'root@locahost',
        4 => 'admin',
        9 => 'joe',
    );

For PostMasterSearch, it returns hash of UserID, Email pairs:

    my %List = (
        4 => 'john@example.com',
        9 => 'joe@example.com',
    );

=cut

sub UserSearch {
    my ( $Self, %Param ) = @_;

    my %Users;
    my $Valid = $Param{Valid} // 1;

    # check needed stuff
    if ( !$Param{Search} && !$Param{UserLogin} && !$Param{PostMasterSearch} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Search, UserLogin or PostMasterSearch!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # get like escape string needed for some databases (e.g. oracle)
    my $LikeEscapeString = $DBObject->GetDatabaseFunction('LikeEscapeString');

    # build SQL string
    my $SQL = "SELECT $Self->{UserTableUserID}, login FROM $Self->{UserTable} WHERE ";
    my @Bind;

    if ( $Param{Search} ) {

        my %QueryCondition = $DBObject->QueryCondition(
            Key      => [qw(login first_name last_name)],
            Value    => $Param{Search},
            BindMode => 1,
        );
        $SQL .= $QueryCondition{SQL} . ' ';
        push @Bind, @{ $QueryCondition{Values} };
    }
    elsif ( $Param{PostMasterSearch} ) {

        my %UserID = $Self->SearchPreferences(
            Key   => 'UserEmail',
            Value => $Param{PostMasterSearch},
        );

        for ( sort keys %UserID ) {
            my %User = $Self->GetUserData(
                UserID => $_,
                Valid  => $Param{Valid},
            );
            if (%User) {
                return %UserID;
            }
        }

        return;
    }
    elsif ( $Param{UserLogin} ) {

        my $UserLogin = lc $Param{UserLogin};
        $SQL .= " $Self->{Lower}($Self->{UserTableUser}) LIKE ? $LikeEscapeString";
        $UserLogin =~ s/\*/%/g;
        $UserLogin = $DBObject->Quote( $UserLogin, 'Like' );
        push @Bind, \$UserLogin;
    }

    # add valid option
    if ($Valid) {
        $SQL .= "AND valid_id = ?";
        push( @Bind, \$Valid );
    }

    # get data
    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => $Self->{UserSearchListLimit} || $Param{Limit},
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Users{ $Row[0] } = $Row[1];
    }

    return %Users;
}

=item SetPassword()

to set users passwords

    $UserObject->SetPassword(
        UserLogin => 'some-login',
        PW        => 'some-new-password'
    );

=cut

sub SetPassword {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin!'
        );
        return;
    }

    # get old user data
    my %User = $Self->GetUserData( User => $Param{UserLogin} );
    if ( !$User{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'No such User!',
        );
        return;
    }

    my $Pw        = $Param{PW} || '';
    my $CryptedPw = '';

    # get crypt type
    my $CryptType = $Kernel::OM->Get('Kernel::Config')->Get('AuthModule::DB::CryptType') || 'sha2';

    # crypt plain (no crypt at all)
    if ( $CryptType eq 'plain' ) {
        $CryptedPw = $Pw;
    }

    # crypt with UNIX crypt
    elsif ( $CryptType eq 'crypt' ) {

        # encode output, needed by crypt() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Param{UserLogin} );

        $CryptedPw = crypt( $Pw, $Param{UserLogin} );
    }

    # crypt with md5
    elsif ( $CryptType eq 'md5' || !$CryptType ) {

        # encode output, needed by unix_md5_crypt() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Param{UserLogin} );

        $CryptedPw = unix_md5_crypt( $Pw, $Param{UserLogin} );
    }

    # crypt with md5 (compatible with Apache's .htpasswd files)
    elsif ( $CryptType eq 'apr1' ) {

        # encode output, needed by unix_md5_crypt() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Param{UserLogin} );

        $CryptedPw = apache_md5_crypt( $Pw, $Param{UserLogin} );
    }

    # crypt with sha1
    elsif ( $CryptType eq 'sha1' ) {

        my $SHAObject = Digest::SHA->new('sha1');

        # encode output, needed by sha1_hex() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );

        $SHAObject->add($Pw);
        $CryptedPw = $SHAObject->hexdigest();
    }

    # bcrypt
    elsif ( $CryptType eq 'bcrypt' ) {

        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require('Crypt::Eksblowfish::Bcrypt') ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "User: '$User{UserLogin}' tried to store password with bcrypt but 'Crypt::Eksblowfish::Bcrypt' is not installed!",
            );
            return;
        }

        my $Cost = 9;
        my $Salt = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString( Length => 16 );

        # remove UTF8 flag, required by Crypt::Eksblowfish::Bcrypt
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );

        # calculate password hash
        my $Octets = Crypt::Eksblowfish::Bcrypt::bcrypt_hash(
            {
                key_nul => 1,
                cost    => 9,
                salt    => $Salt,
            },
            $Pw
        );

        # We will store cost and salt in the password string so that it can be decoded
        #   in future even if we use a higher cost by default.
        $CryptedPw = "BCRYPT:$Cost:$Salt:" . Crypt::Eksblowfish::Bcrypt::en_base64($Octets);
    }

    # crypt with sha256 as fallback
    else {

        my $SHAObject = Digest::SHA->new('sha256');

        # encode output, needed by sha256_hex() only non utf8 signs
        $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Pw );

        $SHAObject->add($Pw);
        $CryptedPw = $SHAObject->hexdigest();
    }

    # update db
    my $UserLogin = lc $Param{UserLogin};
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE $Self->{UserTable} SET $Self->{UserTableUserPW} = ? "
            . " WHERE $Self->{Lower}($Self->{UserTableUser}) = ?",
        Bind => [ \$CryptedPw, \$UserLogin ],
    );

    # log notice
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => "User: '$Param{UserLogin}' changed password successfully!",
    );

    # trigger event handler
    $Self->EventHandler(
        Event => 'UserSetPassword',
        Data  => {
            %Param,
            OldData => \%User,
        },
        UserID => $Self->{UserID} || $Param{UserID} || 1,
    );

    return 1;
}

=item UserLookup()

user login or id lookup

    my $UserLogin = $UserObject->UserLookup(
        UserID => 1,
        Silent => 1, # optional, don't generate log entry if user was not found
    );

    my $UserID = $UserObject->UserLookup(
        UserLogin => 'some_user_login',
        Silent    => 1, # optional, don't generate log entry if user was not found
    );

=cut

sub UserLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserLogin} && !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserLogin or UserID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    if ( $Param{UserLogin} ) {

        # check cache
        my $CacheKey = 'UserLookup::ID::' . $Param{UserLogin};
        my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        my $UserLogin = lc $Param{UserLogin};

        return if !$DBObject->Prepare(
            SQL => "SELECT $Self->{UserTableUserID} FROM $Self->{UserTable} "
                . " WHERE $Self->{Lower}($Self->{UserTableUser}) = ?",
            Bind  => [ \$UserLogin ],
            Limit => 1,
        );

        # fetch the result
        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        if ( !$ID ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "No UserID found for '$Param{UserLogin}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $ID,
        );

        return $ID;
    }

    else {

        # check cache
        my $CacheKey = 'UserLookup::Login::' . $Param{UserID};
        my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # build sql query
        return if !$DBObject->Prepare(
            SQL => "SELECT $Self->{UserTableUser} FROM $Self->{UserTable} "
                . " WHERE $Self->{UserTableUserID} = ?",
            Bind  => [ \$Param{UserID} ],
            Limit => 1,
        );

        # fetch the result
        my $Login;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Login = $Row[0];
        }

        if ( !$Login ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "No UserLogin found for '$Param{UserID}'!",
                );
            }
            return;
        }

        # set cache
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $Login,
        );

        return $Login;
    }
}

=item UserName()

get user name

    my $Name = $UserObject->UserName(
        User => 'some-login',
    );

    or

    my $Name = $UserObject->UserName(
        UserID => 123,
    );

=cut

sub UserName {
    my ( $Self, %Param ) = @_;

    my %User = $Self->GetUserData(%Param);

    return if !%User;
    return $User{UserFullname};
}

=item UserList()

return a hash with all users

    my %List = $UserObject->UserList(
        Type          => 'Short', # Short|Long, default Short
        Valid         => 1,       # default 1
        NoOutOfOffice => 1,       # (optional) default 0
    );

=cut

sub UserList {
    my ( $Self, %Param ) = @_;

    my $Type = $Param{Type} || 'Short';

    # set valid option
    my $Valid = $Param{Valid} // 1;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get configuration for the full name order
    my $FirstnameLastNameOrder = $ConfigObject->Get('FirstnameLastnameOrder') || 0;
    my $NoOutOfOffice = $Param{NoOutOfOffice} || 0;

    # check cache
    my $CacheKey = join '::', 'UserList', $Type, $Valid, $FirstnameLastNameOrder, $NoOutOfOffice;
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SelectStr;
    if ( $Type eq 'Short' ) {
        $SelectStr = "$ConfigObject->{DatabaseUserTableUserID}, "
            . " $ConfigObject->{DatabaseUserTableUser}";
    }
    else {
        $SelectStr = "$ConfigObject->{DatabaseUserTableUserID}, "
            . " last_name, first_name, "
            . " $ConfigObject->{DatabaseUserTableUser}";
    }

    my $SQL = "SELECT $SelectStr FROM $ConfigObject->{DatabaseUserTable}";

    # sql query
    if ($Valid) {
        $SQL
            .= " WHERE valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare( SQL => $SQL );

    # fetch the result
    my %UsersRaw;
    my %Users;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $UsersRaw{ $Row[0] } = \@Row;
    }

    if ( $Type eq 'Short' ) {
        for my $CurrentUserID ( sort keys %UsersRaw ) {
            $Users{$CurrentUserID} = $UsersRaw{$CurrentUserID}->[1];
        }
    }
    else {
        for my $CurrentUserID ( sort keys %UsersRaw ) {
            my @Data         = @{ $UsersRaw{$CurrentUserID} };
            my $UserFullname = $Self->_UserFullname(
                UserFirstname => $Data[2],
                UserLastname  => $Data[1],
                UserLogin     => $Data[3],
                NameOrder     => $FirstnameLastNameOrder,
            );

            $Users{$CurrentUserID} = $UserFullname;
        }
    }

    # check vacation option
    if ( !$NoOutOfOffice ) {

        USERID:
        for my $UserID ( sort keys %Users ) {
            next USERID if !$UserID;

            my %User = $Self->GetUserData(
                UserID => $UserID,
            );
            if ( $User{OutOfOfficeMessage} ) {
                $Users{$UserID} .= ' ' . $User{OutOfOfficeMessage};
            }
        }
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Users,
    );

    return %Users;
}

=item GenerateRandomPassword()

generate a random password

    my $Password = $UserObject->GenerateRandomPassword();

    or

    my $Password = $UserObject->GenerateRandomPassword(
        Size => 16,
    );

=cut

sub GenerateRandomPassword {
    my ( $Self, %Param ) = @_;

    # generated passwords are eight characters long by default
    my $Size = $Param{Size} || 8;

    # The list of characters that can appear in a randomly generated password.
    my @PwChars = ( 0 .. 9, 'A' .. 'Z', 'a' .. 'z', '-', '_', '!', '@', '#', '$', '%', '^', '&', '*' );

    # generate random password string
    my $Password = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
        Dictionary => \@PwChars,
        Length     => $Size,
    );

    return $Password;
}

=item SetPreferences()

set user preferences

    $UserObject->SetPreferences(
        Key    => 'UserComment',
        Value  => 'some comment',
        UserID => 123,
    );

=cut

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check needed stuff
    for (qw(Key UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # Don't allow overwriting of native user data.
    my %Blacklisted = (
        UserID        => 1,
        UserLogin     => 1,
        UserPw        => 1,
        UserFirstname => 1,
        UserLastname  => 1,
        UserFullname  => 1,
        UserTitle     => 1,
        ChangeTime    => 1,
        CreateTime    => 1,
        ValidID       => 1,
    );

    return 0 if $Blacklisted{ $Param{Key} };
### Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
    return 0 if substr( $Param{Key}, 0, 11 ) eq 'UserIsGroup';
### EO Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###

    # get current setting
    my %Preferences = $Self->GetPreferences(
        UserID => $Param{UserID},
    );

    # no updated needed
    return 1
        if defined $Preferences{ $Param{Key} }
        && defined $Param{Value}
        && $Preferences{ $Param{Key} } eq $Param{Value};

    $Self->_UserCacheClear( UserID => $Param{UserID} );

    # get user preferences config
    my $GeneratorModule = $ConfigObject->Get('User::PreferencesModule') || 'Kernel::System::User::Preferences::DB';

    # get generator preferences module
    my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

    # set preferences
    my $Result = $PreferencesObject->SetPreferences(%Param);

    if ( $Result ) {
        $Self->EventHandler(
            Event => 'UserSetPreferences',
            Data  => {
                %Param,
                OldData => {
                    $Param{Key} => $Preferences{$Param{Key}}
                },
                Result  => $Result,
            },
            UserID => 1,
        );
    }

    return $Result;
}

sub _UserCacheClear {
    my ( $Self, %Param ) = @_;

    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!"
        );
        return;
    }

    # get configuration for the full name order
    my $FirstnameLastNameOrder = $Kernel::OM->Get('Kernel::Config')->Get('FirstnameLastnameOrder') || 0;

    # create cachekey
    my $Login = $Self->UserLookup( UserID => $Param{UserID} );
    my @CacheKeys = (
        'GetUserData::User::' . $Login . '::0::' . $FirstnameLastNameOrder . '::0',
        'GetUserData::User::' . $Login . '::0::' . $FirstnameLastNameOrder . '::1',
        'GetUserData::User::' . $Login . '::1::' . $FirstnameLastNameOrder . '::0',
        'GetUserData::User::' . $Login . '::1::' . $FirstnameLastNameOrder . '::1',
        'GetUserData::UserID::' . $Param{UserID} . '::0::' . $FirstnameLastNameOrder . '::0',
        'GetUserData::UserID::' . $Param{UserID} . '::0::' . $FirstnameLastNameOrder . '::1',
        'GetUserData::UserID::' . $Param{UserID} . '::1::' . $FirstnameLastNameOrder . '::0',
        'GetUserData::UserID::' . $Param{UserID} . '::1::' . $FirstnameLastNameOrder . '::1',
        'UserList::Short::0::' . $FirstnameLastNameOrder . '::0',
        'UserList::Short::0::' . $FirstnameLastNameOrder . '::1',
        'UserList::Short::1::' . $FirstnameLastNameOrder . '::0',
        'UserList::Short::1::' . $FirstnameLastNameOrder . '::1',
        'UserList::Long::0::' . $FirstnameLastNameOrder . '::0',
        'UserList::Long::0::' . $FirstnameLastNameOrder . '::1',
        'UserList::Long::1::' . $FirstnameLastNameOrder . '::0',
        'UserList::Long::1::' . $FirstnameLastNameOrder . '::1',
        'UserLookup::ID::' . $Login,
        'UserLookup::Login::' . $Param{UserID},
    );

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # delete cache
    for my $CacheKey (@CacheKeys) {

        $CacheObject->Delete(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
    }

    return 1;
}

=item GetPreferences()

get user preferences

    my %Preferences = $UserObject->GetPreferences(
        UserID => 123,
    );

=cut

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # get user preferences config
    my $GeneratorModule = $Kernel::OM->Get('Kernel::Config')->Get('User::PreferencesModule')
        || 'Kernel::System::User::Preferences::DB';

    # get generator preferences module
    my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

    return $PreferencesObject->GetPreferences(%Param);
}

=item SearchPreferences()

search in user preferences

    my %UserList = $UserObject->SearchPreferences(
        Key   => 'UserEmail',
        Value => 'email@example.com',   # optional, limit to a certain value/pattern
    );

=cut

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    # get user preferences config
    my $GeneratorModule = $Kernel::OM->Get('Kernel::Config')->Get('User::PreferencesModule')
        || 'Kernel::System::User::Preferences::DB';

    # get generator preferences module
    my $PreferencesObject = $Kernel::OM->Get($GeneratorModule);

    return $PreferencesObject->SearchPreferences(%Param);
}

=item TokenGenerate()

generate a random token

    my $Token = $UserObject->TokenGenerate(
        UserID => 123,
    );

=cut

sub TokenGenerate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserID!"
        );
        return;
    }
    my $Token = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
        Length => 16,
    );

    # save token in preferences
    $Self->SetPreferences(
        Key    => 'UserToken',
        Value  => $Token,
        UserID => $Param{UserID},
    );

    return $Token;
}

=item TokenCheck()

check password token

    my $Valid = $UserObject->TokenCheck(
        Token  => $Token,
        UserID => 123,
    );

=cut

sub TokenCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Token} || !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Token and UserID!'
        );
        return;
    }

    # get preferences token
    my %Preferences = $Self->GetPreferences(
        UserID => $Param{UserID},
    );

    # check requested vs. stored token
    if ( $Preferences{UserToken} && $Preferences{UserToken} eq $Param{Token} ) {

        # reset password token
        $Self->SetPreferences(
            Key    => 'UserToken',
            Value  => '',
            UserID => $Param{UserID},
        );

        # return true if token is valid
        return 1;
    }

    # return false if token is invalid
    return;
}

=begin Internal:

=item _UserFullname()

Builds the user fullname based on firstname, lastname and login. The order
can be configured.

    my $Fullname = $Object->_UserFullname(
        UserFirstname => 'Test',
        UserLastname  => 'Person',
        UserLogin     => 'tp',
        NameOrder     => 0,         # optional 0, 1, 2, 3, 4, 5
    );

=cut

sub _UserFullname {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(UserFirstname UserLastname UserLogin)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    my $FirstnameLastNameOrder = $Param{NameOrder} || 0;

    my $UserFullname;
    if ( $FirstnameLastNameOrder eq '0' ) {
        $UserFullname = $Param{UserFirstname} . ' '
            . $Param{UserLastname};
    }
    elsif ( $FirstnameLastNameOrder eq '1' ) {
        $UserFullname = $Param{UserLastname} . ', '
            . $Param{UserFirstname};
    }
    elsif ( $FirstnameLastNameOrder eq '2' ) {
        $UserFullname = $Param{UserFirstname} . ' '
            . $Param{UserLastname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ( $FirstnameLastNameOrder eq '3' ) {
        $UserFullname = $Param{UserLastname} . ', '
            . $Param{UserFirstname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ( $FirstnameLastNameOrder eq '4' ) {
        $UserFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{UserFirstname}
            . ' ' . $Param{UserLastname};
    }
    elsif ( $FirstnameLastNameOrder eq '5' ) {
        $UserFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{UserLastname}
            . ', ' . $Param{UserFirstname};
    }
    elsif ( $FirstnameLastNameOrder eq '6' ) {
        $UserFullname = $Param{UserLastname} . ' '
            . $Param{UserFirstname};
    }
    elsif ( $FirstnameLastNameOrder eq '7' ) {
        $UserFullname = $Param{UserLastname} . ' '
            . $Param{UserFirstname} . ' ('
            . $Param{UserLogin} . ')';
    }
    elsif ( $FirstnameLastNameOrder eq '8' ) {
        $UserFullname = '(' . $Param{UserLogin}
            . ') ' . $Param{UserLastname}
            . ' ' . $Param{UserFirstname};
    }
    return $UserFullname;
}

=end Internal:

=cut

=item UserLoginExistsCheck()

return 1 if another user with this login (username) already exists

    $Exist = $UserObject->UserLoginExistsCheck(
        UserLogin => 'Some::UserLogin',
        UserID => 1, # optional
    );

=cut

sub UserLoginExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL =>
            "SELECT $Self->{UserTableUserID} FROM $Self->{UserTable} WHERE $Self->{UserTableUser} = ?",
        Bind => [ \$Param{UserLogin} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{UserID} || $Param{UserID} ne $Row[0] ) {
            $Flag = 1;
        }
    }
    if ($Flag) {
        return 1;
    }
    return 0;
}

sub DESTROY {
    my $Self = shift;

    # execute all transaction events
    $Self->EventHandlerTransaction();

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. This program is
licensed under the AGPL-3.0 with patches licensed under the GPL-3.0.
For details, see the enclosed files LICENSE (AGPL) and
LICENSE-GPL3 (GPL3) for license information. If you did not receive
this files, see <https://www.gnu.org/licenses/agpl.txt> (APGL) and
<https://www.gnu.org/licenses/gpl-3.0.txt> (GPL3).

=cut
