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

package Kernel::System::CustomerUser;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::System::CustomerCompany',
    'Kernel::System::DB',
    'Kernel::System::Group',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Time',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::CustomerUser - customer user lib

=head1 SYNOPSIS

All customer user functions. E. g. to add and update customer users.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # load generator customer preferences module
    my $GeneratorModule = $ConfigObject->Get('CustomerPreferences')->{Module}
        || 'Kernel::System::CustomerUser::Preferences::DB';

    # get main object
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    if ( $MainObject->Require($GeneratorModule) ) {
        $Self->{PreferencesObject} = $GeneratorModule->new();
    }

    my $TimeObject  = $Kernel::OM->Get('Kernel::System::Time');
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');

    my $FrontendBaselink = '';
    if ( $ENV{SCRIPT_NAME} ) {
        $ENV{SCRIPT_NAME} =~ m/\/(.*)\/(.*)\.pl$/;
        if ( defined $2 ) {
            $FrontendBaselink = $2;
        }
    }

    # check if we have a UserID in agent frontend
    if (!$Param{UserID} && $FrontendBaselink eq 'index') {
        # no, we haven't => try to get it from an existing session
        my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
        my $SessionName = $ConfigObject->Get('SessionName') || 'SessionID';
        my $SessionID = $ParamObject->GetParam( Param => $SessionName ) || '';

        if (!$SessionID) {
            my $SessionIDCookie = $ParamObject->GetCookie( Key => $SessionName );
            if ( $SessionIDCookie ) {
               $SessionID = $SessionIDCookie;
            }
        }

        if ($SessionID) {
            my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
            my %Data = $SessionObject->GetSessionIDData(
                SessionID => $SessionID,
            );
            if (%Data) {
                $Param{UserID} = $Data{UserID};
            }
        }
    }

    my @UserGroups;
    $Param{UserID} = 1 if !$Param{UserID};
    if ( $Param{UserID} && $FrontendBaselink eq 'index' ) {
        if ( $Param{UserID} !~ /^\d+$/ ) {
            $Param{UserID} = $UserObject->UserLookup(
                UserLogin => $Param{UserID}
            );
        }
        @UserGroups = $GroupObject->GroupMemberList(
            UserID => $Param{UserID},
            Type   => 'ro',
            Result => 'Name',
        );
    }
    elsif ( !$Param{UserID} && $FrontendBaselink eq 'customer' ) {
        $Param{UserID} = $ConfigObject->Get("CustomerPanelUserID");
    }
    elsif ( !$ConfigObject->Get('CustomerGroupSupport') && $FrontendBaselink eq 'customer' ) {
        # if no customer group support is activate and we are in the customer frontend, allow access
        $Param{UserID} = $ConfigObject->Get("CustomerPanelUserID");
    }

    # load customer user backend module
    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$ConfigObject->Get("CustomerUser$Count");

        my $BackendGroups = $ConfigObject->Get("CustomerUser$Count")->{AccessGroups} || "";
        my $Access        = 1;
        if (
            $Param{UserID}
            && (
                $Param{UserID} eq '1'
                || $Param{UserID} eq $ConfigObject->Get("CustomerPanelUserID")
            )
        ) {
            $Access = 1;
        }

        elsif ( $BackendGroups && ref $BackendGroups eq 'ARRAY' ) {
            GROUP:
            for my $Group ( @{$BackendGroups} ) {
                $Access = 0;
                next GROUP if ( ( grep { $_ eq $Group; } @UserGroups ) == 0 );
                $Access = 1;
                last;
            }
        }
        next if !$Access;

        my $GenericModule = $ConfigObject->Get("CustomerUser$Count")->{Module};
        if ( !$MainObject->Require($GenericModule) ) {
            $MainObject->Die("Can't load backend module $GenericModule! $@");
        }
        $Self->{"CustomerUser$Count"} = $GenericModule->new(
            Count             => $Count,
            PreferencesObject => $Self->{PreferencesObject},
            CustomerUserMap   => $ConfigObject->Get("CustomerUser$Count"),
        );
    }

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'CustomerUser::EventModulePost',
    );

    return $Self;
}

=item CustomerSourceList()

return customer source list

    my %List = $CustomerUserObject->CustomerSourceList(
        ReadOnly => 0 # optional, 1 returns only RO backends, 0 returns writable, if not passed returns all backends
    );

=cut

sub CustomerSourceList {
    my ( $Self, %Param ) = @_;

    my %Data;
    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};
        if ( defined $Param{ReadOnly} ) {
            my $CustomerBackendConfig = $Self->{"CustomerUser$Count"}->{CustomerUserMap};
            if ( $Param{ReadOnly} ) {
                next SOURCE if !$CustomerBackendConfig->{ReadOnly};
            }
            else {
                next SOURCE if $CustomerBackendConfig->{ReadOnly};
            }
        }
        $Data{"CustomerUser$Count"} = $Self->{"CustomerUser$Count"}->{CustomerUserMap}->{Name}
            || "No Name $Count";
    }
    return %Data;
}

=item CustomerSearch()

to search users

    # text search
    my %List = $CustomerUserObject->CustomerSearch(
        Search => '*some*', # also 'hans+huber' possible
        Valid  => 1,        # (optional) default 1
        Limit  => 100,      # (optional) overrides limit of the config
    );

    # username search
    my %List = $CustomerUserObject->CustomerSearch(
        UserLogin => '*some*',
        Valid     => 1,         # (optional) default 1
    );

    # email search
    my %List = $CustomerUserObject->CustomerSearch(
        PostMasterSearch => 'email@example.com',
        Valid            => 1,                    # (optional) default 1
    );

    # search by CustomerID
    my %List = $CustomerUserObject->CustomerSearch(
        CustomerID       => 'CustomerID123',
        Valid            => 1,                # (optional) default 1
    );

    # search by search fields
    my %List = $CustomerUserObject->CustomerSearch(
        SearchFields     => {
            UserPhone => '+49123/456789'
        },
        Valid            => 1,                # (optional) default 1
    );

=cut

sub CustomerSearch {
    my ( $Self, %Param ) = @_;

    # remove leading and ending spaces
    if ( $Param{Search} ) {
        $Param{Search} =~ s/^\s+//;
        $Param{Search} =~ s/\s+$//;
    }

    my %Data;
    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};

        # get customer search result of backend and merge it
        my %SubData = $Self->{"CustomerUser$Count"}->CustomerSearch(%Param);
        %Data = ( %SubData, %Data );
    }
    return %Data;
}

=item CustomerUserList()

return a hash with all users (depreciated)

    my %List = $CustomerUserObject->CustomerUserList(
        Valid => 1, # not required
    );

=cut

sub CustomerUserList {
    my ( $Self, %Param ) = @_;

    my %Data;
    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};

        # get customer list result of backend and merge it
        my %SubData = $Self->{"CustomerUser$Count"}->CustomerUserList(%Param);
        %Data = ( %Data, %SubData );
    }
    return %Data;
}

=item CustomerIDList()

return a list of with all known unique CustomerIDs of the registered customers users (no SearchTerm),
or a filtered list where the CustomerIDs must contain a search term.

    my @CustomerIDs = $CustomerUserObject->CustomerIDList(
        SearchTerm  => 'somecustomer',    # optional
        Valid       => 1,                 # optional
    );

=cut

sub CustomerIDList {
    my ( $Self, %Param ) = @_;

    my @Data;
    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};

        # get customer list result of backend and merge it
        push @Data, $Self->{"CustomerUser$Count"}->CustomerIDList(%Param);
    }

    # make entries unique
    my %Tmp;
    @Tmp{@Data} = undef;
    @Data = sort { lc $a cmp lc $b } keys %Tmp;

    return @Data;
}

=item CustomerName()

get customer user name

    my $Name = $CustomerUserObject->CustomerName(
        UserLogin => 'some-login',
    );

=cut

sub CustomerName {
    my ( $Self, %Param ) = @_;

    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};

        # get customer name and return it
        my $Name = $Self->{"CustomerUser$Count"}->CustomerName(%Param);
        if ($Name) {
            return $Name;
        }
    }
    return;
}

=item CustomerIDs()

get customer user customer ids

    my @CustomerIDs = $CustomerUserObject->CustomerIDs(
        User => 'some-login',
    );

=cut

sub CustomerIDs {
    my ( $Self, %Param ) = @_;

    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};

        # get customer id's and return it
        my @CustomerIDs = $Self->{"CustomerUser$Count"}->CustomerIDs(%Param);
        if (@CustomerIDs) {
            return @CustomerIDs;
        }
    }
    return;
}

=item CustomerUserDataGet()

get user data (UserLogin, UserFirstname, UserLastname, UserEmail, ...)

    my %User = $CustomerUserObject->CustomerUserDataGet(
        User => 'franz',
    );

=cut

sub CustomerUserDataGet {
    my ( $Self, %Param ) = @_;

    return if !$Param{User};

    # get needed objects
    my $ConfigObject          = $Kernel::OM->Get('Kernel::Config');
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};

        my %Customer = $Self->{"CustomerUser$Count"}->CustomerUserDataGet(%Param);
        next SOURCE if !%Customer;

        # add preferences defaults
        my $Config = $ConfigObject->Get('CustomerPreferencesGroups');
        if ($Config) {
            KEY:
            for my $Key ( sort keys %{$Config} ) {

                next KEY if !defined $Config->{$Key}->{DataSelected};
                next KEY if defined $Customer{ $Config->{$Key}->{PrefKey} };

                # set default data
                $Customer{ $Config->{$Key}->{PrefKey} } = $Config->{$Key}->{DataSelected};
            }
        }

        # check if customer company support is enabled and get company data
        my %Company;
        if (
            $ConfigObject->Get("CustomerCompany")
            && $ConfigObject->Get("CustomerUser$Count")->{CustomerCompanySupport}
        ) {
            %Company = $CustomerCompanyObject->CustomerCompanyGet(
                CustomerID => $Param{CustomerID} || $Customer{UserCustomerID},
            );

            $Company{CustomerCompanyValidID} = $Company{ValidID};
        }

        # return customer data
        return (
            %Company,
            %Customer,
            Source        => "CustomerUser$Count",
            Config        => $ConfigObject->Get("CustomerUser$Count"),
            CompanyConfig => $ConfigObject->Get( $Company{Source} // 'CustomerCompany' ),
        );
    }

    return;
}

=item CustomerUserAdd()

to add new customer users

    my $UserLogin = $CustomerUserObject->CustomerUserAdd(
        Source         => 'CustomerUser', # CustomerUser source config
        UserFirstname  => 'Huber',
        UserLastname   => 'Manfred',
        UserCustomerID => 'A124',
        UserLogin      => 'mhuber',
        UserPassword   => 'some-pass', # not required
        UserEmail      => 'email@example.com',
        ValidID        => 1,
        UserID         => 123,
    );

=cut

sub CustomerUserAdd {
    my ( $Self, %Param ) = @_;

    # check data source
    if ( !$Param{Source} ) {
        $Param{Source} = 'CustomerUser';
    }

    # check if user exists
    if ( $Param{UserLogin} ) {
        my %User = $Self->CustomerUserDataGet( User => $Param{UserLogin} );
        if (%User) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $Kernel::OM->Get('Kernel::Language')
                    ->Translate( 'Customer user "%s" already exists.', $Param{UserLogin} ),
            );
            return;
        }
    }

    my $Result = $Self->{ $Param{Source} }->CustomerUserAdd(%Param);
    return if !$Result;

    # trigger event
    $Self->EventHandler(
        Event => 'CustomerUserAdd',
        Data  => {
            UserLogin => $Param{UserLogin},
            NewData   => \%Param,
        },
        UserID => $Param{UserID},
    );

    return $Result;

}

=item CustomerUserUpdate()

to update customer users

    $CustomerUserObject->CustomerUserUpdate(
        Source        => 'CustomerUser', # CustomerUser source config
        ID            => 'mh'            # current user login
        UserLogin     => 'mhuber',       # new user login
        UserFirstname => 'Huber',
        UserLastname  => 'Manfred',
        UserPassword  => 'some-pass',    # not required
        UserEmail     => 'email@example.com',
        ValidID       => 1,
        UserID        => 123,
    );

=cut

sub CustomerUserUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserLogin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need UserLogin!"
        );
        return;
    }

    # check for UserLogin-renaming and if new UserLogin already exists...
    if ( $Param{ID} && ( lc $Param{UserLogin} ne lc $Param{ID} ) ) {
        my %User = $Self->CustomerUserDataGet( User => $Param{UserLogin} );
        if (%User) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => $Kernel::OM->Get('Kernel::Language')
                    ->Translate( 'Customer user "%s" already exists.', $Param{UserLogin} ),
            );
            return;
        }
    }

    # check if user exists
    my %User = $Self->CustomerUserDataGet( User => $Param{ID} || $Param{UserLogin} );
    if ( !%User ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such user '$Param{UserLogin}'!",
        );
        return;
    }
    my $Result = $Self->{ $User{Source} }->CustomerUserUpdate(%Param);
    return if !$Result;

    # trigger event
    $Self->EventHandler(
        Event => 'CustomerUserUpdate',
        Data  => {
            UserLogin => $Param{ID} || $Param{UserLogin},
            NewData   => \%Param,
            OldData   => \%User,
        },
        UserID => $Param{UserID},
    );

    return $Result;

}

=item SetPassword()

to set customer users passwords

    $CustomerUserObject->SetPassword(
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
            Message  => 'User UserLogin!'
        );
        return;
    }

    # check if user exists
    my %User = $Self->CustomerUserDataGet( User => $Param{UserLogin} );
    if ( !%User ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such user '$Param{UserLogin}'!",
        );
        return;
    }

    my $Result = $Self->{ $User{Source} }->SetPassword(%Param);

    # trigger event handler
    if ($Result) {
        $Self->EventHandler(
            Event => 'CustomerUserSetPassword',
            Data  => {
                %Param,
                OldData => \%User,
                Result  => $Result,
            },
            UserID => $Param{UserID},
        );
    }
    return $Result;
}

=item GenerateRandomPassword()

generate a random password

    my $Password = $CustomerUserObject->GenerateRandomPassword();

    or

    my $Password = $CustomerUserObject->GenerateRandomPassword(
        Size => 16,
    );

=cut

sub GenerateRandomPassword {
    my ( $Self, %Param ) = @_;

    return $Self->{CustomerUser}->GenerateRandomPassword(%Param);
}

=item SetPreferences()

set customer user preferences

    $CustomerUserObject->SetPreferences(
        Key    => 'UserComment',
        Value  => 'some comment',
        UserID => 'some-login',
    );

=cut

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # Don't allow overwriting of native user data.
    my %Blacklisted = (
        UserID         => 1,
        UserLogin      => 1,
        UserPassword   => 1,
        UserFirstname  => 1,
        UserLastname   => 1,
        UserFullname   => 1,
        UserStreet     => 1,
        UserCity       => 1,
        UserZip        => 1,
        UserCountry    => 1,
        UserComment    => 1,
        UserCustomerID => 1,
        UserTitle      => 1,
        UserEmail      => 1,
        ChangeTime     => 1,
        ChangeBy       => 1,
        CreateTime     => 1,
        CreateBy       => 1,
        UserPhone      => 1,
        UserMobile     => 1,
        UserFax        => 1,
        UserMailString => 1,
        ValidID        => 1,
    );

    return 0 if $Blacklisted{ $Param{Key} };
### Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
    return 0 if substr( $Param{Key}, 0, 11 ) eq 'UserIsGroup';
### EO Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###

    # check if user exists
    my %User = $Self->CustomerUserDataGet( User => $Param{UserID} );
    if ( !%User ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such user '$Param{UserID}'!",
        );
        return;
    }

    my $Result;

    # call new api (2.4.8 and higher)
    if ( $Self->{ $User{Source} }->can('SetPreferences') ) {
        $Result = $Self->{ $User{Source} }->SetPreferences(%Param);
    }

    # call old api
    else {
        $Result = $Self->{PreferencesObject}->SetPreferences(%Param);
    }

    # trigger event handler
    if ($Result) {
        $Self->EventHandler(
            Event => 'CustomerUserSetPreferences',
            Data  => {
                %Param,
                UserData => \%User,
                Result   => $Result,
            },
            UserID => 1,
        );
    }
    return $Result;
}

=item GetPreferences()

get customer user preferences

    my %Preferences = $CustomerUserObject->GetPreferences(
        UserID => 'some-login',
    );

=cut

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # check if user exists
    my %User = $Self->CustomerUserDataGet( User => $Param{UserID} );
    if ( !%User ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such user '$Param{UserID}'!",
        );
        return;
    }

    # call new api (2.4.8 and higher)
    if ( $Self->{ $User{Source} }->can('GetPreferences') ) {
        return $Self->{ $User{Source} }->GetPreferences(%Param);
    }

    # call old api
    return $Self->{PreferencesObject}->GetPreferences(%Param);
}

=item SearchPreferences()

search in user preferences

    my %UserList = $CustomerUserObject->SearchPreferences(
        Key   => 'UserSomeKey',
        Value => 'SomeValue',   # optional, limit to a certain value/pattern
    );

=cut

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    my %Data;
    SOURCE:
    for my $Count ( '', 1 .. 10 ) {

        next SOURCE if !$Self->{"CustomerUser$Count"};

        # get customer search result of backend and merge it
        # call new api (2.4.8 and higher)
        my %SubData;
        if ( $Self->{"CustomerUser$Count"}->can('SearchPreferences') ) {
            %SubData = $Self->{"CustomerUser$Count"}->SearchPreferences(%Param);
        }

        # call old api
        else {
            %SubData = $Self->{PreferencesObject}->SearchPreferences(%Param);
        }
        %Data = ( %SubData, %Data );
    }

    return %Data;
}

=item DeletePreferences()

delete customer user preferences

    $CustomerUserObject->DeletePreferences(
        Key    => 'UserComment',
        UserID => 'some-login',
    );

=cut

sub DeletePreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # check if user exists
    my %User = $Self->CustomerUserDataGet( User => $Param{UserID} );
    if ( !%User ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such user '$Param{UserID}'!",
        );
        return;
    }

    my $Result;

    # call new api (2.4.8 and higher)
    if ( $Self->{ $User{Source} }->can('DeletePreferences') ) {
        $Result = $Self->{ $User{Source} }->DeletePreferences(%Param);
    }

    # call old api
    else {
        $Result = $Self->{PreferencesObject}->DeletePreferences(%Param);
    }

    # trigger event handler
    if ($Result) {
        $Self->EventHandler(
            Event => 'CustomerUserDeletePreferences',
            Data  => {
                %Param,
                UserData => \%User,
                Result   => $Result,
            },
            UserID => 1,
        );
    }
    return $Result;
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
            Message  => "Need Token and UserID!"
        );
        return;
    }

    # get preferences token
    my %Preferences = $Self->GetPreferences(
        UserID => $Param{UserID},
    );

    # check requested vs. stored token
    return if !$Preferences{UserToken};
    return if $Preferences{UserToken} ne $Param{Token};

    # reset password token
    $Self->SetPreferences(
        Key    => 'UserToken',
        Value  => '',
        UserID => $Param{UserID},
    );

    return 1;
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
