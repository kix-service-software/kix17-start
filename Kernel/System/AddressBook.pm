# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AddressBook;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CacheInternal',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::AddressBook

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a AddressBook object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AddressBookObject = $Kernel::OM->Get('Kernel::System::AddressBook');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{CacheObject}  = $Kernel::OM->Get('Kernel::System::Cache');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

=item AddAddress()

Adds a new email address

    my $Result = $AddressBookObject->AddAddress(
        Email => 'some email address',
    );

=cut

sub AddAddress {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Email)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    $Param{Email} =~ s/'/\'/gm;
    my $EmailLower = lc($Param{Email});

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO addressbook (email, email_lower) VALUES (?, ?)",
        Bind => [
            \$Param{Email},
            \$EmailLower
        ],
    );

    #handle the insert result...
    if ($DBInsert) {

        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => 'AddressBook'
        );

        return 0 if !$Self->{DBObject}->Prepare(
            SQL  => 'SELECT max(id) FROM addressbook WHERE email = ?',
            Bind => [
                \$Param{Email}
            ],
        );

        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            return $Row[0];
        }
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "AddAddress::DB insert failed!",
        );
    }

    return 0;
}

=item DeleteAddress()

Deletes a list of email addresses.

    my $Result = $AddressBookObject->DeleteAddress(
        IDs      => [...],
    );

=cut

sub DeleteAddress {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{IDs} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'DeleteAddress: Need IDs!' );
        return;
    }

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => 'AddressBook'
    );

    return $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM addressbook WHERE id in ('.join(',', @{$Param{IDs}}).')',
    );
}

=item Empty()

Deletes all entries.

    my $Result = $AddressBookObject->Empty();

=cut

sub Empty {
    my ( $Self, %Param ) = @_;

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => 'AddressBook'
    );

    return $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM addressbook',
    );
}

=item AddressList()

Returns all (matching) email address entries

    my %Hash = $AddressBookObject->AddressList(
        Search => '...'             # optional
        Limit  => 123               # optional
        SearchCaseSensitive => 0|1  # optional
    );

=cut

sub AddressList {
    my ( $Self, %Param ) = @_;
    my $WHEREClauseExt = '';
    my %Result;
    my @Binds;

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'AddressList::'.$Param{Search};
    my $CacheResult = $Self->{CacheObject}->Get(
        Type => 'AddressBook',
        Key  => $CacheKey
    );
    return %{$CacheResult} if (IsHashRefWithData($CacheResult));

    if ( $Param{Search} ) {
        my $Email = $Param{Search};
        $Email =~ s/\*/%/g;
        $Email =~ s/'/\'/gm;

        if ($Param{SearchCaseSensitive}) {
            $WHEREClauseExt .= " AND email like ?";
            push(@Binds, \$Email);
        }
        else {
            $WHEREClauseExt .= " AND email_lower like ?";
            push(@Binds, \lc($Email));
        }
    }

    my $SQL = "SELECT id, email FROM addressbook WHERE 1=1";

    return if !$Self->{DBObject}->Prepare(
        SQL   => $SQL . $WHEREClauseExt . " ORDER by email",
        Bind  => \@Binds,
        Limit => $Param{Limit},
    );

    my $Count = 0;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Result{ $Data[0] } = $Data[1];
    }

    # set cache
    $Self->{CacheObject}->Set(
        Type           => 'AddressBook',
        Key            => $CacheKey,
        Value          => \%Result,
        TTL            => $CacheTTL,
    );

    return %Result;
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
