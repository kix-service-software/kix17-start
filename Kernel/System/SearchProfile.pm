# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SearchProfile;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::SearchProfile - module to manage search profiles

=head1 SYNOPSIS

module with all functions to manage search profiles

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{DBObject} = $Kernel::OM->Get('Kernel::System::DB');

    $Self->{CacheType} = 'SearchProfile';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    $Self->{LanguageObject} = $Kernel::OM->Get('Kernel::Language');

    return $Self;
}

=item SearchProfileAdd()

to add a search profile item

    $SearchProfileObject->SearchProfileAdd(
        Base      => 'TicketSearch',
        Name      => 'last-search',
        Key       => 'Body',
        Value     => $String,    # SCALAR|ARRAYREF
        UserLogin => 123,
    );

=cut

sub SearchProfileAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base Name Key UserLogin)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check value
    return 1 if !defined $Param{Value};

    # create login string
    my $Login = $Param{Base} . '::' . $Param{UserLogin};

    my @Data;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Data = @{ $Param{Value} };
        $Param{Type} = 'ARRAY';
    }
    else {
        @Data = ( $Param{Value} );
        $Param{Type} = 'SCALAR';
    }

    for my $Value (@Data) {

        return if !$Self->{DBObject}->Do(
            SQL  => <<'END',
INSERT INTO search_profile
    (login, profile_name,  profile_type, profile_key, profile_value)
VALUES (?, ?, ?, ?, ?)
END
            Bind => [
                \$Login, \$Param{Name}, \$Param{Type}, \$Param{Key}, \$Value,
            ],
        );
    }

    # reset cache
    my $CacheKey = $Login . '::' . $Param{Name};
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => $Login,
    );
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return 1;
}

=item SearchProfileGet()

returns hash with search profile.

    my %SearchProfileData = $SearchProfileObject->SearchProfileGet(
        Base      => 'TicketSearch',
        Name      => 'last-search',
        UserLogin => 'me',
    );

=cut

sub SearchProfileGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base Name UserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create login string
    my $Login = $Param{Base} . '::' . $Param{UserLogin};

    # check the cache
    my $CacheKey = $Login . '::' . $Param{Name};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get search profile
    return if !$Self->{DBObject}->Prepare(
        SQL  => <<"END",
SELECT profile_type, profile_key, profile_value
FROM search_profile
WHERE profile_name = ?
    AND $Self->{Lower}(login) = $Self->{Lower}(?)
END
        Bind => [ \$Param{Name}, \$Login ],
    );

    my %Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        if ( $Data[0] eq 'ARRAY' ) {
            push @{ $Result{ $Data[1] } }, $Data[2];
        }
        else {
            $Result{ $Data[1] } = $Data[2];
        }
    }
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result
    );

    return %Result;
}

=item SearchProfileDelete()

deletes a search profile.

    $SearchProfileObject->SearchProfileDelete(
        Base      => 'TicketSearch',
        Name      => 'last-search',
        UserLogin => 'me',
    );

=cut

sub SearchProfileDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base Name UserLogin)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create login string
    my $Login = $Param{Base} . '::' . $Param{UserLogin};

    # delete search profile
    return if !$Self->{DBObject}->Do(
        SQL  => <<"END",
DELETE FROM search_profile
WHERE profile_name = ?
    AND $Self->{Lower}(login) = $Self->{Lower}(?)
END
        Bind => [ \$Param{Name}, \$Login ],
    );

    # delete cache
    my $CacheKey = $Login . '::' . $Param{Name};
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => $Login,
    );
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return 1;
}

=item SearchProfileList()

returns a hash of all profiles for the given user.

    my %SearchProfiles = $SearchProfileObject->SearchProfileList(
        Base             => 'TicketSearch',
        UserLogin        => 'me',
        Category         => 'CategoryName', # get list depending on category
        WithSubscription => 1 # get also profiles from other agents
    );

=cut

sub SearchProfileList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base UserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create login string
    my $Login = $Param{Base} . '::' . $Param{UserLogin};

    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $Login,
    );
    return %{$Cache} if $Cache;

    my %Result;

    # use category
    if ( defined $Param{Category} && $Param{Category} ) {

        return
            if !$Self->{DBObject}->Prepare(
            SQL  => "SELECT name,login,state FROM kix_search_profile WHERE category = ?",
            Bind => [ \$Param{Category} ],
            );

        my @SelectedData;
        my %DataHash;

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {

            if ( $Data[0] =~ m/^(.*?)::(.*?)::(.*?)$/ ) {

                # do not subscribe to own search profiles
                next
                    if (
                    $Param{SubscriptedOnly}
                    && $Data[2] eq 'owner'
                    && $Param{UserLogin} eq $Data[1]
                    );
                next
                    if (
                    $Data[2] eq 'subscriber'
                    && $Param{UserLogin} ne $Data[1]
                    );

                $DataHash{ $Data[0] } = $3;

                next if $Param{UserLogin} ne $Data[1];
                push @SelectedData, $Data[0];
            }
        }

        $Result{Data}         = \%DataHash;
        $Result{SelectedData} = \@SelectedData;

    }
    elsif ( defined $Param{WithSubscription} && $Param{WithSubscription} ) {

        # get search profiles
        return
            if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT profile_name FROM search_profile WHERE $Self->{Lower}(login) = $Self->{Lower}(?)",
            Bind => [ \$Login ],
            );

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            $Result{ $Data[0] . '::' . $Param{UserLogin} } = $Data[0];
        }

        # get subscripted search profiles from other agents
        return
            if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT name FROM kix_search_profile WHERE login = ? AND state = 'subscriber' AND name LIKE '%"
                . $Param{Base} . "%'",
            Bind => [ \$Param{UserLogin} ],
            );

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            my $Key;
            if ( $Data[0] =~ m/^TicketSearch::(.*?)::(.*?)$/ ) {
                $Key = $2 . '::' . $1;
            }
            my $Subscription = $Self->{LanguageObject}->Translate('Subscribe');
            if ( !defined $Result{$Key} ) {
                $Result{$Key} = "[" . substr( $Subscription, 0, 1 ) . "] " . $2;
            }
        }

    }
    # get search profile list
    else {
        # get old search profiles
        return if !$Self->{DBObject}->Prepare(
            SQL  => <<"END",
SELECT profile_name
FROM search_profile
WHERE $Self->{Lower}(login) = $Self->{Lower}(?)
END
            Bind => [ \$Login ],
        );

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            $Result{ $Data[0] } = $Data[0];
        }

        # get search profiles with category
        return
            if !$Self->{DBObject}->Prepare(
            SQL =>
                "SELECT name FROM kix_search_profile WHERE login = ? AND state = 'subscriber' AND name LIKE '%"
                . $Param{Base} . "%'",
            Bind => [ \$Param{UserLogin} ],
            );

        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            my $Key;
            if ( $Data[0] =~ m/^TicketSearch::(.*?)::(.*?)$/ ) {
                $Key = $2 . '::' . $1;
            }
            my $Subscription = $Self->{LanguageObject}->Translate('Subscribe');
            if ( !defined $Result{$Key} ) {
                $Result{$Key} = "[" . substr( $Subscription, 0, 1 ) . "] " . $2;
            }
        }
    }

    return %Result;
}

=item SearchProfileUpdateUserLogin()

changes the UserLogin of SearchProfiles

    my $Result = $SearchProfileObject->SearchProfileUpdateUserLogin(
        Base         => 'TicketSearch',
        UserLogin    => 'me',
        NewUserLogin => 'newme',
    );

=cut

sub SearchProfileUpdateUserLogin {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base UserLogin NewUserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get existing profiles
    my %SearchProfiles = $Self->SearchProfileList(
        Base      => $Param{Base},
        UserLogin => $Param{UserLogin},
    );

    # iterate over profiles; create them for new login name and delete old ones
    for my $SearchProfile ( sort keys %SearchProfiles ) {
        my %Search = $Self->SearchProfileGet(
            Base      => $Param{Base},
            Name      => $SearchProfile,
            UserLogin => $Param{UserLogin},
        );

        # add profile for new login (needs to be done per attribute)
        for my $Attribute ( sort keys %Search ) {
            $Self->SearchProfileAdd(
                Base      => $Param{Base},
                Name      => $SearchProfile,
                Key       => $Attribute,
                Value     => $Search{$Attribute},
                UserLogin => $Param{NewUserLogin},
            );
        }

        # delete the old profile
        $Self->SearchProfileDelete(
            Base      => $Param{Base},
            Name      => $SearchProfile,
            UserLogin => $Param{UserLogin},
        );
    }

    return 1;
}

=item SearchProfileCopy()

to copy a search profile item

    $SearchProfileObject->SearchProfileCopy(
        Base      => 'TicketSearch',
        Name      => 'last-search',
        NewName   => 'last-search-123',
        OldLogin  => 123,
        UserLogin => 123,
    );

=cut

sub SearchProfileCopy {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Base Name UserLogin)) {
        if ( !defined $Param{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get source data
    my %SearchProfileData = $Self->SearchProfileGet(
        Base      => $Param{Base},
        Name      => $Param{Name},
        UserLogin => $Param{OldLogin},
    );

    if ( !defined $Param{NewName} || $Param{NewName} eq '' ) {

        # delete search profile with same name if exists
        $Self->SearchProfileDelete(
            Base      => $Param{Base},
            Name      => $Param{Name},
            UserLogin => $Param{UserLogin},
        );
    }
    else {
        $Param{Name} = $Param{NewName};
    }

    # write target
    for my $Item ( keys %SearchProfileData ) {

        $Self->SearchProfileAdd(
            Base      => $Param{Base},
            Name      => $Param{Name},
            Key       => $Item,
            Value     => $SearchProfileData{$Item},
            UserLogin => $Param{UserLogin},
        );
    }

    return 1;
}

=item SearchProfileCategoryAdd()

to add a search profile item

    $SearchProfileObject->SearchProfileCategoryAdd(
        Name      => 'TicketSearch::UserLogin::SearchTemplate',
        Category  => 'CategoryName',
        State     => 'owner', # or subscriber
        UserLogin => 'UserLogin',
    );

=cut

sub SearchProfileCategoryAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name Category UserLogin State)) {
        if ( !defined $Param{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return
        if !$Self->{DBObject}->Do(
        SQL => 'INSERT INTO kix_search_profile'
            . ' (name,  category, state , login)'
            . ' VALUES (?, ?, ?, ?) ',
        Bind => [
            \$Param{Name},  \$Param{Category},
            \$Param{State}, \$Param{UserLogin},
        ],
        );

    return 1;
}

=item SearchProfileCategoryGet()

returns a hash with information about the shared search profile

    my %SearchProfileData = $SearchProfileObject->SearchProfileCategoryGet(
        Name      => 'last-search',
        UserLogin => 'me',
    );

=cut

sub SearchProfileCategoryGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name UserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get searech profile
    return
        if !$Self->{DBObject}->Prepare(
        SQL =>
            "SELECT * FROM kix_search_profile WHERE name = ? AND $Self->{Lower}(login) = $Self->{Lower}(?)",
        Bind => [ \$Param{Name}, \$Param{UserLogin} ],
        );

    my %Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {

        $Result{Category}  = $Data[0];
        $Result{Name}      = $Data[1];
        $Result{State}     = $Data[2];
        $Result{UserLogin} = $Data[3];
    }

    return %Result;
}

=item SearchProfileCategoryDelete()

deletes an profile

    $SearchProfileObject->SearchProfileCategoryDelete(
        Category  => 'TicketSearch',     # optional (category or name must be given)
        Name      => 'last-search',      # optional (category or name must be given)
        UserLogin => 'me',               # optional
        State      => 'owner'            # optional
    );

=cut

sub SearchProfileCategoryDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Category} && !$Param{Name} ) {
        $Self->{LogObject}
            ->Log( Priority => 'error', Message => "Need Category or Name!" );
        return;
    }

    # create SQL string
    my $SQL = "DELETE FROM kix_search_profile WHERE ";

    # create where-clause
    my @SQLExtended = ();
    my $Criterion;

    # UserLogin
    if ( $Param{UserLogin} ) {
        $Criterion =
            $Self->{Lower}
            . "(login) = "
            . $Self->{Lower} . "('"
            . $Param{UserLogin} . "')";
        push @SQLExtended, $Criterion;
    }

    # name, e.g. TicketSearch::UserLogin::SearchProfile
    if ( $Param{Name} ) {
        $Criterion = " name = '" . $Param{Name} . "'";
        push @SQLExtended, $Criterion;
    }

    # category
    if ( $Param{Category} ) {
        $Criterion = " category = '" . $Param{Category} . "'";
        push @SQLExtended, $Criterion;
    }

    # state, e.g. owner / copy
    if ( $Param{State} ) {
        $Criterion = " state = '" . $Param{State} . "'";
        push @SQLExtended, $Criterion;
    }

    my $SQLExt = join( " AND ", @SQLExtended );

    return $Self->{DBObject}->Prepare( SQL => $SQL . $SQLExt );

}

=item SearchProfileCategoryList()

returns a hash of all profiles

    my %SearchProfiles = $SearchProfileObject->SearchProfileCategoryList();

=cut

sub SearchProfileCategoryList {
    my ( $Self, %Param ) = @_;

    # get search profile categorylist
    return
        if !$Self->{DBObject}->Prepare(
        SQL  => "SELECT DISTINCT category FROM kix_search_profile",
        Bind => [],
        );

    # fetch the result
    my %Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Result{ $Data[0] } = $Data[0];
    }

    return %Result;
}

=item SearchProfileAutoSubscribe()

auto-subscribe of a search profile

    my %SearchProfiles = $SearchProfileObject->SearchProfileAutoSubscribe(
        Name        => 'SearchProfileName',
        UserLogin   => 'me'
        UserObject  => $Self->{UserObject}
    );

=cut

sub SearchProfileAutoSubscribe {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name UserLogin UserObject)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get search profile data
    my %SearchProfileData = $Self->SearchProfileCategoryGet(
        Name      => $Param{Name},
        UserLogin => $Param{UserLogin},
    );

    # get user preference 'auto-subscribe' from all users and check if user selected chosen category
    return
        if !$Self->{DBObject}->Prepare(
        SQL =>
            "SELECT user_id,preferences_value FROM user_preferences WHERE preferences_key = 'SearchProfileAutoSubscribe'",
        Bind => [],
        );

    my %Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        my @TmpArray = split( /;/, $Data[1] );
        next if !grep { $_ eq $SearchProfileData{Category} } @TmpArray;
        $Result{ $Data[0] } = 1;
    }

    # auto-subscribe
    $Self->{UserObject} = $Param{UserObject};
    for my $User ( keys %Result ) {
        my %UserData = $Self->{UserObject}->GetUserData( UserID => $User );
        $Self->SearchProfileCategoryAdd(
            Name      => $Param{Name},
            Category  => $SearchProfileData{Category},
            State     => 'subscriber',
            UserLogin => $UserData{UserLogin},
        );
    }

    return 1;
}

=item SearchProfilesByCategory()

returns a hash of all subscribable profiles by category

    my %SearchProfiles = $SearchProfileObject->SearchProfilesByCategory(
        Base            => 'TicketSearch',
        Category        => 'SearchProfileCategoryName',
    );

=cut

sub SearchProfilesByCategory {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Category Base UserLogin)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get all search profiles for this category
    my %SearchProfiles = $Self->SearchProfileList(
        Base            => 'TicketSearch',
        UserLogin       => $Param{UserLogin},
        Category        => $Param{Category},
        SubscriptedOnly => 1,
    );

    return %SearchProfiles;

}

=item SearchProfilesBasesGet()

returns an array of all possible search profile bases

    my %SearchProfiles = $SearchProfileObject->SearchProfilesBasesGet();

=cut

sub SearchProfilesBasesGet {
    my ( $Self, %Param ) = @_;

    # get search profile categorylist
    return
        if !$Self->{DBObject}->Prepare(
        SQL  => "SELECT DISTINCT login FROM search_profile",
        Bind => [],
        );

    # fetch the result
    my @Result;
    GETDATA:
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        if ( $Data[0] =~ /(.*?)::(.*)/ ) {
            next GETDATA if grep { $_ eq $1 } @Result;
            push @Result, $1;
        }
    }
    return @Result;
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
