# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::State;

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

Kernel::System::State - state lib

=head1 SYNOPSIS

All ticket state functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'State';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # check needed config options
    for (qw(Ticket::ViewableStateType Ticket::UnlockStateType)) {
        $Kernel::OM->Get('Kernel::Config')->Get($_) || die "Need $_ in Kernel/Config.pm!\n";
    }

    return $Self;
}

=item StateAdd()

add new ticket state

    my $ID = $StateObject->StateAdd(
        Name    => 'New State',
        Comment => 'some comment',
        ValidID => 1,
        TypeID  => 1,
        UserID  => 123,
    );

=cut

sub StateAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name ValidID TypeID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a state with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A state with name '$Param{Name}' already exists!"
        );
        return;
    }

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    # store data
    return if !$DBObject->Do(
        SQL => 'INSERT INTO ticket_state (name, valid_id, type_id, comments,'
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{TypeID}, \$Param{Comment},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    # get new state id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM ticket_state WHERE name = ?',
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

=item StateGet()

get state attributes

    my %State = $StateObject->StateGet(
        Name  => 'New State',
    );

    my %State = $StateObject->StateGet(
        ID    => 123,
    );

returns

    my %State = (
        Name       => "new",
        ID         => 1,
        TypeName   => "new",
        TypeID     => 1,
        ValidID    => 1,
        Comment    => "New ticket created by customer.",
        CreateTime => '2010-04-07 15:41:15',
        CreateBy   => '321',
        ChangeTime => '2010-04-07 15:59:45',
        ChangeBy   => '223',
    );

=cut

sub StateGet {
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
        $Param{ID} = $Self->StateLookup(
            State => $Param{Name},
        );
        if ( !$Param{ID} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ID for State '$Param{Name}' not found!",
            );
            return;
        }
    }

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    # check cache
    my $CacheKey = 'StateGet::ID::' . $Param{ID};
    my $Cache    = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # ask the database
    return if !$DBObject->Prepare(
        SQL => 'SELECT ts.id, ts.name, ts.valid_id, ts.comments, ts.type_id, tst.name,'
            . ' ts.create_time, ts.create_by, ts.change_time, ts.change_by'
            . ' FROM ticket_state ts, ticket_state_type tst WHERE ts.type_id = tst.id AND ts.id = ?',
        Bind => [ \$Param{ID} ],
    );

    # fetch the result
    my %State;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %State = (
            ID         => $Data[0],
            Name       => $Data[1],
            ValidID    => $Data[2],
            Comment    => $Data[3],
            TypeID     => $Data[4],
            TypeName   => $Data[5],
            CreateTime => $Data[6],
            CreateBy   => $Data[7],
            ChangeTime => $Data[8],
            ChangeBy   => $Data[9],
        );
    }

    # no data found
    if ( !%State ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "State with ID '$Param{ID}' not found!",
        );
        return;
    }

    # set cache
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%State,
    );

    return %State;
}

=item StateUpdate()

update state attributes

    my $Success = $StateObject->StateUpdate(
        ID             => 123,
        Name           => 'New State',
        Comment        => 'some comment',
        ValidID        => 1,
        TypeID         => 1,
        CheckSysConfig => 0,   # (optional) default 1
        UserID         => 123,
    );

=cut

sub StateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name ValidID TypeID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a state with this name already exists
    if (
        $Self->NameExistsCheck(
            Name => $Param{Name},
            ID   => $Param{ID}
        )
    ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A state with name '$Param{Name}' already exists!"
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
        SQL => 'UPDATE ticket_state SET name = ?, comments = ?, type_id = ?,'
            . ' valid_id = ?, change_time = current_timestamp, change_by = ?'
            . ' WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Comment}, \$Param{TypeID}, \$Param{ValidID},
            \$Param{UserID}, \$Param{ID},
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

=item StateGetStatesByType()

get list of states for a type or a list of state types.

Get all states with state type open and new:
(available: new, open, closed, pending reminder, pending auto, removed, merged)

    my @List = $StateObject->StateGetStatesByType(
        StateType => ['open', 'new'],
        Result    => 'ID', # HASH|ID|Name
    );

Get all state types used by config option named like
Ticket::ViewableStateType for "Viewable" state types.

    my %List = $StateObject->StateGetStatesByType(
        Type   => 'Viewable',
        Result => 'HASH', # HASH|ID|Name
    );

=cut

sub StateGetStatesByType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Result} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Result!'
        );
        return;
    }

    if ( !$Param{Type} && !$Param{StateType} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Type or StateType!'
        );
        return;
    }

    # cache key
    my $CacheKey = 'StateGetStatesByType::';
    if ( $Param{Type} ) {
        $CacheKey .= 'Type::' . $Param{Type};
    }
    if ( $Param{StateType} ) {

        my @StateType;
        if ( ref $Param{StateType} eq 'ARRAY' ) {
            @StateType = @{ $Param{StateType} };
        }
        else {
            push @StateType, $Param{StateType};
        }
        $CacheKey .= 'StateType::' . join ':', sort @StateType;
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    if ($Cache) {
        if ( $Param{Result} eq 'Name' ) {
            return @{ $Cache->{Name} };
        }
        elsif ( $Param{Result} eq 'HASH' ) {
            return %{ $Cache->{HASH} };
        }
        return @{ $Cache->{ID} };
    }

    # sql
    my @StateType;
    my @Name;
    my @ID;
    my %Data;
    if ( $Param{Type} ) {

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        if ( $ConfigObject->Get( 'Ticket::' . $Param{Type} . 'StateType' ) ) {
            @StateType = @{ $ConfigObject->Get( 'Ticket::' . $Param{Type} . 'StateType' ) };
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Type 'Ticket::$Param{Type}StateType' not found in Kernel/Config.pm!",
            );
            die;
        }
    }
    else {
        if ( ref $Param{StateType} eq 'ARRAY' ) {
            @StateType = @{ $Param{StateType} };
        }
        else {
            push @StateType, $Param{StateType};
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    @StateType = map { $DBObject->Quote($_) } @StateType;

    my $SQL = ''
        . 'SELECT ts.id, ts.name, tst.name'
        . ' FROM ticket_state ts, ticket_state_type tst'
        . ' WHERE tst.id = ts.type_id'
        . " AND tst.name IN ('${\(join '\', \'', sort @StateType)}' )"
        . " AND ts.valid_id IN ( ${\(join ', ', $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet())} )";

    return if !$DBObject->Prepare( SQL => $SQL );

    # fetch the result
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push @Name, $Data[1];
        push @ID,   $Data[0];
        $Data{ $Data[0] } = $Data[1];
    }

    # set runtime cache
    my $All = {
        Name => \@Name,
        ID   => \@ID,
        HASH => \%Data,
    };

    # set permanent cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $All,
    );

    if ( $Param{Result} eq 'Name' ) {
        return @Name;
    }
    elsif ( $Param{Result} eq 'HASH' ) {
        return %Data;
    }

    return @ID;
}

=item StateList()

get state list as a hash of ID, Name pairs

    my %List = $StateObject->StateList();

or

    my %List = $StateObject->StateList(
        Valid  => 1, # is default
    );

or

    my %List = $StateObject->StateList(
        Valid  => 0,
    );

returns

    my %List = (
        1 => "new",
        2 => "closed successful",
        3 => "closed unsuccessful",
        4 => "open",
        5 => "removed",
        6 => "pending reminder",
        7 => "pending auto close+",
        8 => "pending auto close-",
        9 => "merged",
    );

=cut

sub StateList {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

    # check Valid param
    my $Valid = 1;
    if ( !$Param{Valid} && defined( $Param{Valid} ) ) {
        $Valid = 0;
    }

    # check cache
    my $CacheKey = 'StateList::Valid::' . $Valid;
    my $Cache    = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # build SQL
    my $SQL = 'SELECT id, name FROM ticket_state';

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
    my %StateList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $StateList{ $Row[0] } = $Row[1];
    }

    # set cache
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%StateList,
    );

    return %StateList;
}

=item StateLookup()

returns the id or the name of a state

    my $StateID = $StateObject->StateLookup(
        State => 'closed successful',
    );

or

    my $State = $StateObject->StateLookup(
        StateID => 2,
    );

=cut

sub StateLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{State} && !$Param{StateID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            State   => 'error',
            Message => 'Need State or StateID!'
        );
        return;
    }

    # get (already cached) state list
    my %StateList = $Self->StateList(
        Valid  => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{StateID} ) {
        $Key        = 'StateID';
        $Value      = $Param{StateID};
        $ReturnData = $StateList{ $Param{StateID} };
    }
    else {
        $Key   = 'State';
        $Value = $Param{State};
        my %StateListReverse = reverse %StateList;
        $ReturnData = $StateListReverse{ $Param{State} };
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

=item StateTypeList()

get state type list as a hash of ID, Name pairs

    my %ListType = $StateObject->StateTypeList(
        UserID => 123,
    );

returns

    my %ListType = (
        1 => "new",
        2 => "open",
        3 => "closed",
        4 => "pending reminder",
        5 => "pending auto",
        6 => "removed",
        7 => "merged",
    );

=cut

sub StateTypeList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'UserID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'StateTypeList';
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # sql
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, name FROM ticket_state_type',
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=item StateTypeLookup()

returns the id or the name of a state type

    my $StateTypeID = $StateTypeObject->StateTypeLookup(
        StateType => 'pending auto',
    );

or

    my $StateType = $StateTypeObject->StateTypeLookup(
        StateTypeID => 1,
    );

=cut

sub StateTypeLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{StateType} && !$Param{StateTypeID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            StateType => 'error',
            Message   => 'Need StateType or StateTypeID!',
        );
        return;
    }

    # get (already cached) state type list
    my %StateTypeList = $Self->StateTypeList(
        UserID => 1,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{StateTypeID} ) {
        $Key        = 'StateTypeID';
        $Value      = $Param{StateTypeID};
        $ReturnData = $StateTypeList{ $Param{StateTypeID} };
    }
    else {
        $Key   = 'StateType';
        $Value = $Param{StateType};
        my %StateTypeListReverse = reverse %StateTypeList;
        $ReturnData = $StateTypeListReverse{ $Param{StateType} };
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

    return 1 if another state with this name already exits

        $Exist = $StateObject->NameExistsCheck(
            Name => 'Some::Template',
            ID => 1, # optional
        );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM ticket_state WHERE name = ?',
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
