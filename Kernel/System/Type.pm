# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Type;

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

Kernel::System::Type - type lib

=head1 SYNOPSIS

All type functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Type';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item TypeAdd()

add a new ticket type

    my $ID = $TypeObject->TypeAdd(
        Name    => 'New Type',
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub TypeAdd {
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
        SQL => 'INSERT INTO ticket_type (name, valid_id, '
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new type id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket_type WHERE name = ?',
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

=item TypeGet()

get type attributes

    my %Type = $TypeObject->TypeGet(
        ID => 123,
    );

    my %Type = $TypeObject->TypeGet(
        Name => 'default',
    );

Returns:

    my %Type = (
        ID                  => '123',
        Name                => 'Service Request',
        ValidID             => '1',
        CreateTime          => '2010-04-07 15:41:15',
        CreateBy            => '321',
        ChangeTime          => '2010-04-07 15:59:45',
        ChangeBy            => '223',
    );

=cut

sub TypeGet {
    my ( $Self, %Param ) = @_;

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
        $Param{ID} = $Self->TypeLookup(
            Type => $Param{Name},
        );
        if ( !$Param{ID} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ID for Type '$Param{Name}' not found!",
            );
            return;
        }
    }

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    # check cache
    my $CacheKey = 'TypeGet::ID::' . $Param{ID};
    my $Cache    = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # ask the database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name, valid_id, '
            . 'create_time, create_by, change_time, change_by '
            . 'FROM ticket_type WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # fetch the result
    my %Type;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Type = (
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
    if ( !%Type ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Type with ID '$Param{ID}' not found!",
        );
        return;
    }

    # set cache
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Type,
    );

    return %Type;
}

=item TypeUpdate()

update type attributes

    my $Success = $TypeObject->TypeUpdate(
        ID      => 123,
        Name    => 'New Type',
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub TypeUpdate {
    my ( $Self, %Param ) = @_;

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

    # check if a type with this name already exists
    if (
        $Self->NameExistsCheck(
            Name => $Param{Name},
            ID   => $Param{ID}
        )
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A type with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $CacheObject     = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject        = $Kernel::OM->Get('Kernel::System::DB');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    # get type data
    my %Type = $Self->TypeGet(
        ID => $Param{ID},
    );

    # check if the type is set as a default ticket type
    if (
        $ConfigObject->Get('Ticket::Type::Default') eq $Type{Name}
        && $Param{ValidID} != 1
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "The ticket type is set as a default ticket type, so it cannot be set to invalid!"
        );
        return;
    }

    # sql
    return if !$DBObject->Do(
        SQL => 'UPDATE ticket_type SET name = ?, valid_id = ?,'
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

    # check if the name of the default ticket type is updated
    if (
        $Type{Name} ne $Param{Name}
        && $ConfigObject->Get('Ticket::Type::Default') eq $Type{Name}
    ) {

        # update default ticket type SySConfig item
        $SysConfigObject->ConfigItemUpdate(
            Valid => 1,
            Key   => 'Ticket::Type::Default',
            Value => $Param{Name}
        );

    }

    return 1;
}

=item TypeList()

get type list

    my %List = $TypeObject->TypeList();

or

    my %List = $TypeObject->TypeList(
        Valid => 1, # is default
    );

or

    my %List = $TypeObject->TypeList(
        Valid => 0,
    );

returns

    my %List = (
        1 => "Unclassified",
        2 => "Incident",
        3 => "Incident::Major",
        4 => "Service Request",
        5 => "Problem",
    );

=cut

sub TypeList {
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
    my $CacheKey = 'TypeList::Valid::' . $Valid;
    my $Cache    = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # build SQL
    my $SQL = 'SELECT id, name FROM ticket_type';

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
    my %TypeList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TypeList{ $Row[0] } = $Row[1];
    }

    # set cache
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%TypeList,
    );

    return %TypeList;
}

=item TypeLookup()

get id or name for a ticket type

    my $TypeID = $TypeObject->TypeLookup(
        Type => 'Incident'
    );

or

    my $Type = $TypeObject->TypeLookup(
        TypeID => 2
    );

=cut

sub TypeLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Type} && !$Param{TypeID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Type or TypeID!',
        );
        return;
    }

    # get (already cached) type list
    my %TypeList = $Self->TypeList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{TypeID} ) {
        $Key        = 'TypeID';
        $Value      = $Param{TypeID};
        $ReturnData = $TypeList{ $Param{TypeID} };
    }
    else {
        $Key   = 'Type';
        $Value = $Param{Type};
        my %TypeListReverse = reverse %TypeList;
        $ReturnData = $TypeListReverse{ $Param{Type} };
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

    return 1 if another type with this name already exits

        $Exist = $TypeObject->NameExistsCheck(
            Name => 'Some::Template',
            ID => 1, # optional
        );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_type WHERE name = ?',
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
