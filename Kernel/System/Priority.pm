# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Priority;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::SysConfig',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Priority - priority lib

=head1 SYNOPSIS

All ticket priority functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');


=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Priority';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item PriorityAdd()

add a new ticket priority

    my $ID = $PriorityObject->PriorityAdd(
        Name    => 'New Prio',
        ValidID => 1,
        UserID  => 1,
    );

=cut

sub PriorityAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a type with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A type with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    # store data
    return if !$DBObject->Do(
        SQL => 'INSERT INTO ticket_priority (name, valid_id, '
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get new priority id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket_priority WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return if !$ID;

    # cleanup cache
    $CacheObject->CleanUp(
        Type => $Self->{CacheType},
    );

    return $ID;
}

=item PriorityGet()

get priority attributes

    my %Priority = $PriorityObject->PriorityGet(
        ID => 123,
    );

    my %Priority = $PriorityObject->PriorityGet(
        Name => 'default',
    );

Returns:

    my %Priority = (
        ID                  => '123',
        Name                => 'Service Request',
        ValidID             => '1',
        CreateTime          => '2010-04-07 15:41:15',
        CreateBy            => '321',
        ChangeTime          => '2010-04-07 15:59:45',
        ChangeBy            => '223',
    );

=cut

sub PriorityGet {
    my ( $Self, %Param ) = @_;

    # COMPAT
    if (
        $Param{PriorityID}
        && !$Param{ID}
    ) {
        $Param{ID} = $Param{PriorityID};
    }

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!',
        );
        return;
    }

    # lookup the ID
    if ( !$Param{ID} ) {
        $Param{ID} = $Self->PriorityLookup(
            Priority => $Param{Name},
        );
        if ( !$Param{ID} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ID for Priority '$Param{Name}' not found!",
            );
            return;
        }
    }

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    # check cache
    my $CacheKey = 'PriorityGet::ID::' . $Param{ID};
    my $Cache    = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # ask the database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, valid_id, '
            . 'create_time, create_by, change_time, change_by '
            . 'FROM ticket_priority WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # fetch the result
    my %Priority;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Priority = (
            ID         => $Data[0],
            Name       => $Data[1],
            ValidID    => $Data[2],
            CreateTime => $Data[3],
            CreateBy   => $Data[4],
            ChangeTime => $Data[5],
            ChangeBy   => $Data[6],
        );
    }

    # no data found
    if ( !%Priority ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Priority with ID '$Param{ID}' not found!",
        );
        return;
    }

    # set cache
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Priority,
    );

    return %Priority;
}

=item PriorityUpdate()

update priority attributes

    my $Success = $PriorityObject->PriorityUpdate(
        ID             => 123,
        Name           => 'New Prio',
        ValidID        => 1,
        CheckSysConfig => 0,   # (optional) default 1
        UserID         => 1,
    );

=cut

sub PriorityUpdate {
    my ( $Self, %Param ) = @_;

    # COMPAT
    if (
        $Param{PriorityID}
        && !$Param{ID}
    ) {
        $Param{ID} = $Param{PriorityID};
    }

    # check needed stuff
    for (qw(ID Name ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a priority with this name already exists
    if (
        $Self->NameExistsCheck(
            Name => $Param{Name},
            ID   => $Param{ID}
        )
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A priority with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $CacheObject     = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject        = $Kernel::OM->Get('Kernel::System::DB');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    # check CheckSysConfig param
    if ( !defined $Param{CheckSysConfig} ) {
        $Param{CheckSysConfig} = 1;
    }

    # sql
    return if !$DBObject->Do(
        SQL => 'UPDATE ticket_priority SET name = ?, valid_id = ?,'
            . ' change_time = current_timestamp, change_by = ?'
            . ' WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID},
        ],
    );

    # cleanup cache
    $CacheObject->CleanUp(
        Type => $Self->{CacheType},
    );

    # check all sysconfig options and correct them automatically if neccessary
    if ( $Param{CheckSysConfig} ) {
        $SysConfigObject->ConfigItemCheckAll();
    }

    return 1;
}

=item PriorityList()

return a priority list as hash

    my %List = $PriorityObject->PriorityList();

or

    my %List = $PriorityObject->PriorityList(
        Valid => 1, # is default
    );

or

    my %List = $PriorityObject->PriorityList(
        Valid => 0,
    );

returns

    my %List = (
        1 => "1 very low",
        2 => "2 low",
        3 => "3 normal",
        4 => "4 high",
        5 => "5 very high",
    );

=cut

sub PriorityList {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

    # check Valid param
    my $Valid = 1;
    if ( !$Param{Valid} && defined $Param{Valid} ) {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = 'PriorityList::Valid::' . $Valid;
    my $Cache    = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # build SQL
    my $SQL = 'SELECT id, name FROM ticket_priority ';

    # add WHERE statement
    if ( $Valid ) {
        # create the valid list
        my $ValidIDs = join( ', ', $ValidObject->ValidIDsGet() );

        $SQL .= ' WHERE valid_id IN (' . $ValidIDs . ')';
    }

    # ask database
    return if !$DBObject->Prepare(
        SQL => $SQL
    );

    # fetch the result
    my %PriorityList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $PriorityList{ $Row[0] } = $Row[1];
    }

    # set cache
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%PriorityList,
    );

    return %PriorityList;
}

=item PriorityLookup()

returns the id or the name of a priority

    my $PriorityID = $PriorityObject->PriorityLookup(
        Priority => '3 normal',
    );

or

    my $Priority = $PriorityObject->PriorityLookup(
        PriorityID => 1,
    );

=cut

sub PriorityLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Priority} && !$Param{PriorityID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Priority or PriorityID!'
        );
        return;
    }

    # get (already cached) priority list
    my %PriorityList = $Self->PriorityList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{PriorityID} ) {
        $Key        = 'PriorityID';
        $Value      = $Param{PriorityID};
        $ReturnData = $PriorityList{ $Param{PriorityID} };
    }
    else {
        $Key   = 'Priority';
        $Value = $Param{Priority};
        my %PriorityListReverse = reverse %PriorityList;
        $ReturnData = $PriorityListReverse{ $Param{Priority} };
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No $Key for $Value found!",
        );
        return;
    }

    return $ReturnData;
}

=item NameExistsCheck()

    return 1 if another priority with this name already exits

        $Exist = $PriorityObject->NameExistsCheck(
            Name => 'Some::Template',
            ID => 1, # optional
        );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_priority WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # fetch the result
    my $Flag;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( !$Param{ID} || $Param{ID} ne $Row[0] ) {
            $Flag = 1;
        }
    }
    if ($Flag) {
        return 1;
    }
    return 0;
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
