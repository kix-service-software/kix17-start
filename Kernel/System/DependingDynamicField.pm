# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DependingDynamicField;

use strict;

use warnings;
use Kernel::Language;

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Cache',
);

=head1 NAME

Kernel::System::DependingDynamicField

=head1 SYNOPSIS

DependingDynamicField backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a DependingDynamicField object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DependingDynamicFieldObject = $Kernel::OM->Get('Kernel::System::DependingDynamicField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{DBObject} = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{LogObject} = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{CacheObject} = $Kernel::OM->Get('Kernel::System::Cache');

    $Self->{CacheType} = 'DependingDynamicField';

    return $Self;
}

=item DependingDynamicFieldAdd()

Adds a new Depending Dynamic Field (new node of the depending dynamic field tree)

    my $FieldID = $DependingDynamicFieldObject->DependingDynamicFieldAdd(
        DynamicFieldID  => $DynamicFieldID,
        Value           => $FieldValue,
        ParentID        => $ParentDependingDynamicFieldID,
        TreeID          => $TreeID
    );

=cut

sub DependingDynamicFieldAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(DynamicFieldID Value ParentID TreeID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # build sql...
    my $SQL = "INSERT INTO kix_dep_dynamic_field_prefs "
        . "(dynamicfield_id, value, parent_id, dependingfield_id)"
        . "VALUES "
        . "(?, ?, ?, ?)";

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{DynamicFieldID}, \$Param{Value}, \$Param{ParentID}, \$Param{TreeID},
        ],
    );

    #handle the insert result...
    if ($DBInsert) {
        return 0 if !$Self->{DBObject}->Prepare(
            SQL => 'SELECT max(id) FROM kix_dep_dynamic_field_prefs '
                . " WHERE dynamicfield_id = ? ",
            Bind => [ \$Param{DynamicFieldID} ],
        );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            return $Row[0];
        }
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DependingDynamicField::DB insert failed!",
        );
    }
    return 0;
}

=item DependingDynamicFieldGet()

gets depending dynamic field data hash

    my %DepedingDynamicFieldHash = $DependingDynamicFieldObject->DependingDynamicFieldGet(
        ID  => $DependingDynamicFieldID,
    );

=cut

sub DependingDynamicFieldGet {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ID!" );
        return;
    }

    # db quote
    for (qw(ID)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    # sql
    my $SQL
        = 'SELECT dd.dynamicfield_id, dd.value, dd.parent_id, dd.dependingfield_id, df.name,df.label,df.field_type '
        . 'FROM kix_dep_dynamic_field_prefs dd, dynamic_field df '
        . 'WHERE dd.id = ' . $Param{ID} . ' AND dd.dynamicfield_id = df.id';

    my %Data = ();
    return \%Data if !$Self->{DBObject}->Prepare( SQL => $SQL );
    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            ID             => $Param{ID},
            DynamicFieldID => $Data[0],
            Value          => $Data[1],
            ParentID       => $Data[2],
            TreeID         => $Data[3],
            Name           => $Data[4],
            Label          => $Data[5],
            FieldType      => $Data[6]
        );
    }

    return \%Data;
}

=item DependingDynamicFieldTreeNameGet()

gets depending dynamic field tree data hash

    my $DepedingDynamicFieldHash = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameGet(
        ID  => $DependingDynamicFieldTreeID,
    );

=cut

sub DependingDynamicFieldTreeNameGet {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ID!" );
        return;
    }

    my %Data = ();

    return \%Data if $Param{ID} !~ /\d/;

    # db quote
    $Param{ID} = $Self->{DBObject}->Quote( $Param{ID}, 'Integer' );
    return \%Data if !$Param{ID};

    # sql
    my $SQL
        = "SELECT dd.name, dd.valid_id, "
        . "dd.create_time, dd.create_by, dd.change_time, dd.change_by, "
        . "df.name, df.label, df.field_type "
        . "FROM kix_dep_dynamic_field dd, dynamic_field df "
        . 'WHERE dd.id = ' . $Param{ID} . ' AND dd.id = df.id';

    return if !$Self->{DBObject}->Prepare( SQL => $SQL );
    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            ID                => $Param{ID},
            Name              => $Data[0],
            ValidID           => $Data[1],
            CreateTime        => $Data[2],
            CreateBy          => $Data[3],
            ChangeTime        => $Data[4],
            ChangeBy          => $Data[5],
            DynamicFieldName  => $Data[6],
            DynamicFieldLabel => $Data[7],
            DynamicFieldType  => $Data[8]
        );
        return \%Data;
    }
    return;
}

=item DependingDynamicFieldDelete()

deletes a depending dynamic field

    my $Success = $DependingDynamicFieldObject->DependingDynamicFieldDelete(
        ID  => $DependingDynamicFieldID,
    );

=cut

sub DependingDynamicFieldDelete {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}
            ->Log( Priority => 'error', Message => 'DependingDynamicFieldDelete: Need ID!' );
        return;
    }

    my $DeleteResult = 1;

    # delete child nodes first
    my $ChildNodes = $Self->DependingDynamicFieldListGet( ParentID => $Param{ID} );
    for my $Child ( @{$ChildNodes} ) {
        $DeleteResult = $DeleteResult && $Self->DependingDynamicFieldDelete( ID => $Child->{ID} );
    }

    $DeleteResult = $DeleteResult && $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM kix_dep_dynamic_field_prefs WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    return $DeleteResult;
}

=item DependingDynamicFieldTreeNameDelete()

deletes a depending dynamic tree

    my $Success = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameDelete(
        ID  => $DependingDynamicFieldID,
    );

=cut

sub DependingDynamicFieldTreeNameDelete {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}
            ->Log( Priority => 'error', Message => 'DependingDynamicFieldDelete: Need ID!' );
        return;
    }

    my $DeleteResult = 1;

    # delete child nodes first
    my $ChildNodes = $Self->DependingDynamicFieldListGet( TreeID => $Param{ID} );
    for my $Child ( @{$ChildNodes} ) {
        $DeleteResult = $DeleteResult && $Self->DependingDynamicFieldDelete( ID => $Child->{ID} );
    }

    $DeleteResult = $DeleteResult && $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM kix_dep_dynamic_field WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    return $DeleteResult;
}

=item DependingDynamicFieldListGet()

gets a list of hashes width depending dynamic field data

    my @FieldList = $DependingDynamicFieldObject->DependingDynamicFieldListGet(
        DynamicFieldID  => $DependingDynamicFieldID, (optional)
        Value           => $DependingDynamicFieldValue, (optional)
        ParentID        => $ParentID, (optional)
        TreeID          => $DependingDynamicFieldTree  (optional)
        ValidID         => 1 # optional
    );

=cut

sub DependingDynamicFieldListGet {
    my ( $Self, %Param ) = @_;
    my @ResultArr = ();

    my $SQL
        = "SELECT dd.id, dd.dynamicfield_id, dd.value, dd.parent_id, dd.dependingfield_id, df.name,df.label,df.field_type "
        . "FROM kix_dep_dynamic_field_prefs dd, dynamic_field df, kix_dep_dynamic_field ddf "
        . "WHERE dd.dynamicfield_id = df.id AND ddf.id = dd.dependingfield_id";

    if ( $Param{DynamicFieldID} ) {
        $SQL .= " AND dd.dynamicfield_id = " . $Param{DynamicFieldID};
    }
    if ( $Param{Value} ) {
        $SQL .= " AND dd.value LIKE '" . $Param{Value} . "'";
    }
    if ( defined $Param{ParentID} && $Param{ParentID} ne '' ) {
        $SQL .= " AND dd.parent_id = " . $Param{ParentID};
    }
    if ( $Param{TreeID} ) {
        $SQL .= " AND dd.dependingfield_id = " . $Param{TreeID};
    }
    if ( $Param{ValidID} ) {
        $SQL .= " AND ddf.valid_id = " . $Param{ValidID};
    }

    return \@ResultArr if !$Self->{DBObject}->Prepare( SQL => $SQL );

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        my %ResultHash;
        $ResultHash{ID}             = $Data[0];
        $ResultHash{DynamicFieldID} = $Data[1];
        $ResultHash{Value}          = $Data[2];
        $ResultHash{ParentID}       = $Data[3];
        $ResultHash{TreeID}         = $Data[4];
        $ResultHash{Name}           = $Data[5];
        $ResultHash{Label}          = $Data[6];
        $ResultHash{FieldType}      = $Data[7];
        push( @ResultArr, \%ResultHash );
    }
    return \@ResultArr;
}

=item DependingDynamicFieldList()

returns a list of ids

    my @FieldIDList = $DependingDynamicFieldObject->DependingDynamicFieldList(
        DynamicFieldID  => $DependingDynamicFieldID, (optional)
        ParentID        => $ParentID, (optional)
        ValidID         => 1 # optional
    );

=cut

sub DependingDynamicFieldList {
    my ( $Self, %Param ) = @_;
    my @ResultArr;
    my $SQL = "SELECT DISTINCT dp.id "
        . "FROM kix_dep_dynamic_field_prefs dp INNER JOIN kix_dep_dynamic_field df ON dp.dependingfield_id = df.id";

    if ( defined $Param{ValidID} ) {
        $SQL .= " WHERE df.valid_id = " . $Param{ValidID};
    }

    if ( defined $Param{ParentID} && $Param{ParentID} ne '' ) {
        $SQL .= " AND dp.parent_id = " . $Param{ParentID};
        if ( $Param{DynamicFieldID} ) {
            $SQL .= " AND dp.dynamicfield_id = " . $Param{DynamicFieldID};
        }
    }
    elsif ( $Param{DynamicFieldID} ) {
        $SQL .= " AND dp.dynamicfield_id = " . $Param{DynamicFieldID};
    }

    return if !$Self->{DBObject}->Prepare( SQL => $SQL );
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push( @ResultArr, $Data[0] );
    }

    return \@ResultArr;
}

=item DependingDynamicFieldTreeNameList()

gets a list of all depending dynamic field tree ids

    my @TreeIDList = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameList(
        ValidID => 1 # optional
    );

=cut

sub DependingDynamicFieldTreeNameList {
    my ( $Self, %Param ) = @_;

    my @ResultArr;
    my $SQL = "SELECT id "
        . "FROM kix_dep_dynamic_field";

    if ( $Param{ValidID} ) {
        $SQL .= ' WHERE valid_id = ' . $Param{ValidID};
    }

    return if !$Self->{DBObject}->Prepare( SQL => $SQL );

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push( @ResultArr, $Data[0] );
    }

    return \@ResultArr;
}

=item DependingDynamicFieldTreeNameListGet ()

gets a list of hashes with data of all depending dynamic field trees

    my @TreeIDList = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameListGet (
        ValidID => 1 # optional
    );

=cut

sub DependingDynamicFieldTreeNameListGet {
    my ( $Self, %Param ) = @_;
    my @ResultArr;

    my $SQL
        = "SELECT dd.id, dd.name, dd.valid_id, "
        . "dd.create_time, dd.create_by, dd.change_time, dd.change_by, "
        . "df.name, df.label, df.field_type "
        . "FROM kix_dep_dynamic_field dd, dynamic_field df "
        . "WHERE dd.id = df.id";

    if ( $Param{ValidID} ) {
        $SQL .= ' AND dd.valid_id = ' . $Param{ValidID};
    }

    return if !$Self->{DBObject}->Prepare( SQL => $SQL );

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        my %ResultHash;
        $ResultHash{ID}                = $Data[0];
        $ResultHash{Name}              = $Data[1];
        $ResultHash{ValidID}           = $Data[2];
        $ResultHash{CreateTime}        = $Data[3];
        $ResultHash{CreateBy}          = $Data[4];
        $ResultHash{ChangeTime}        = $Data[5];
        $ResultHash{ChangeBy}          = $Data[6];
        $ResultHash{DynamicFieldName}  = $Data[7];
        $ResultHash{DynamicFieldLabel} = $Data[8];
        $ResultHash{DynamicFieldType}  = $Data[9];
        push( @ResultArr, \%ResultHash );
    }
    return \@ResultArr;
}

=item DependingDynamicFieldTreeNameAdd()

Adds a new Depending Dynamic Field Tree

    my $TreeID = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameAdd(
        ID     => $DynamicFieldID,
        UserID => $UserID,
        Name   => $TreeName,
        ValidID => 1 # optional
    );

=cut

sub DependingDynamicFieldTreeNameAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Name UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get valid id
    if ( !defined $Param{ValidID} ) {
        $Param{ValidID} = 1;
    }

    # build sql...
    my $SQL = "INSERT INTO kix_dep_dynamic_field "
        . "(id, name, valid_id, "
        . "create_time, create_by, change_time, change_by) "
        . "VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?)";

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{ID}, \$Param{Name}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # handle the insert result...
    if ($DBInsert) {
        return 0 if !$Self->{DBObject}->Prepare(
            SQL => 'SELECT max(id) FROM kix_dep_dynamic_field '
                . " WHERE id = ? ",
            Bind => [ \$Param{ID} ],
        );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            return $Row[0];
        }
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DependingDynamicField::DB insert failed!",
        );
    }
    return 0;

}

=item DependingDynamicFieldTreeNameUpdate()

Adds a new Depending Dynamic Field Tree

    my $TreeID = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameUpdate(
        ID       => $DynamicFieldID,
        UserID   => $UserID,
        Name     => $TreeName,        # optional
        ValidID  => 1                 # optional
    );

=cut

sub DependingDynamicFieldTreeNameUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my @SQLExtended = ();

    # set valid id
    if ( defined $Param{ValidID} ) {
        push @SQLExtended, "valid_id = " . $Param{ValidID};
    }

    if ( defined $Param{Name} ) {
        push @SQLExtended, "name = " . $Param{Name};
    }

    # build sql...
    my $SQL = "UPDATE kix_dep_dynamic_field SET " . join( ', ', @SQLExtended ) . " WHERE id = ? ";

    # do the db insert...
    my $DBUpdate = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [ \$Param{ID} ]
    );

    # handle the insert result...
    return $DBUpdate;

}

=item DependingDynamicFieldTreeList ()

gets a list of hashes with data of all depending dynamic field trees and sub nodes
needs possible values hash to get all child nodes

    my %TreeStringHash = $DependingDynamicFieldObject->DependingDynamicFieldTreeList (
        PossibleValues  => $PossibleValues
    );

=cut

sub DependingDynamicFieldTreeList {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( ref $Param{PossibleValues} ne 'HASH' ) {
        $Self->{LogObject}
            ->Log(
            Priority => 'error',
            Message  => 'DependingDynamicFieldTreeList: Need PossibleValues!'
            );
        return;
    }

    my $PossibleValues = $Param{PossibleValues};
    my %TreeStringHash;

    # get tree names
    my $TreeNameList = $Self->DependingDynamicFieldTreeNameListGet();
    for my $TreeItem ( @{$TreeNameList} ) {
        $TreeStringHash{ 'DynamicField_' . $TreeItem->{DynamicFieldName} } = $TreeItem->{Name};
    }

    # get depending dynamic fields
    my $FieldList = $Self->DependingDynamicFieldList();

# create tree string hash
# get value string from each depending field node (id), e.g. TreeRoot::DynamicField1|Value1::DynamicField2::Value1
    my @MissingNodes = ();
    for my $ID ( @{$FieldList} ) {

        # get data for this node
        my $DynamicFieldData = $Self->DependingDynamicFieldGet( ID => $ID );

        # search for damaged nodes - maybe because of deleted dynamic field
        if ( !keys %{$DynamicFieldData} ) {
            push @MissingNodes, $ID;
        }
        next if !keys %{$DynamicFieldData};
        next if grep { $_ == $DynamicFieldData->{ParentID} } @MissingNodes;

        # get tree string
        my $TreeString = $Self->_GetParentTreeString(
            ID             => $ID,
            PossibleValues => $PossibleValues,
            TreeNameList   => $TreeNameList
        );

        $TreeStringHash{$ID} = $TreeString;
    }

    return \%TreeStringHash;

}

=item DependencyList ()

gets a list of all child nodes (depeding dynamic field ids)

    my @ChildList = $DependingDynamicFieldObject->DependencyList (
        DynamicFieldID  => $PossibleValues,
        ParentID        => $Parent,
        ValidID         => 1 # optional
    );

=cut

sub DependencyList {
    my ( $Self, %Param ) = @_;

    my @ResultArray = ();

    # check required params...
    if ( !$Param{DynamicFieldID} && !$Param{ParentID} ) {
        $Self->{LogObject}
            ->Log(
            Priority => 'error',
            Message  => 'DependencyList: Need DynamicFieldID or ParentID!'
            );
        return;
    }

    # check cache
    if ( $Param{DynamicFieldID} && $Self->{CacheObject} ) {
        my $Array = $Self->{CacheObject}->Get(
            Type => $Self->{CacheType},
            Key  => "DependencyList::$Param{DynamicFieldID}",
        );
        return $Array if defined $Array;
    }

    # get child nodes
    my $ChildNodes = $Self->DependingDynamicFieldListGet(
        DynamicFieldID => $Param{DynamicFieldID} || 0,
        ParentID       => $Param{ParentID}       || 0,
    );

    # return if no child nodes defined
    return \@ResultArray if !defined $ChildNodes || !scalar @{$ChildNodes};

    # check tree validity
    my $ValidID = 1;
    if ( $Param{DynamicFieldID} && $Param{ValidID} ) {
        if ( defined $ChildNodes->[0]->{TreeID} ) {
            my $TreeData
                = $Self->DependingDynamicFieldTreeNameGet( ID => $ChildNodes->[0]->{TreeID} );
            $ValidID = $TreeData->{ValidID};
        }
    }

    # return if not valid
    return \@ResultArray if $ValidID != 1;

    # check child nodes of children
    if ( scalar @{$ChildNodes} ) {
        for my $Child ( @{$ChildNodes} ) {
            @ResultArray = ( @{ $Self->DependencyList( ParentID => $Child->{ID} ) }, @ResultArray );
            if ( !grep {/^$Child->{DynamicFieldID}$/} @ResultArray ) {
                push @ResultArray, $Child->{DynamicFieldID};
            }
        }
    }

    # cache request
    if ( $Param{DynamicFieldID} && $Self->{CacheObject} ) {
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => "DependencyList::$Param{DynamicFieldID}",
            Value => \@ResultArray,
            TTL   => 5 * 60,
        );
    }

    # return result
    return \@ResultArray;

}

=item _GetParentTreeString ()

builds a string like "DependingDynamicFieldTree::DynamicField1|Value::DynamicField2|Value" describing a path from tree root to child node

    $DependingDynamicFieldObject->_GetParentTreeString (
        PossibleValues  => $PossibleValues,
        TreeNameList    => $TreeNameList
    );

=cut

sub _GetParentTreeString {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ID!" );
        return;
    }

    # check required params...
    if ( ref $Param{PossibleValues} ne 'HASH' ) {
        $Self->{LogObject}
            ->Log(
            Priority => 'error',
            Message  => 'DependingDynamicFieldTreeList: Need PossibleValues!'
            );
        return;
    }

    if ( ref $Param{TreeNameList} ne 'ARRAY' ) {
        $Self->{LogObject}
            ->Log(
            Priority => 'error',
            Message  => 'DependingDynamicFieldTreeList: Need TreeNames!'
            );
        return;
    }

    my $ParentData = $Self->DependingDynamicFieldGet( ID => $Param{ID} );

    # create string
    my $ParentTreeString = '';

    # first node - parent is tree root
    if ( $ParentData->{ParentID} == 0 ) {
        my $TreeName = '';
        for my $TreeItem ( @{ $Param{TreeNameList} } ) {
            my $TreeItemID     = $TreeItem->{ID};
            my $DynamicFieldID = $ParentData->{DynamicFieldID};

            next if $TreeItemID ne $DynamicFieldID;
            $TreeName = $TreeItem->{Name};
        }
        $ParentTreeString = $TreeName . '::' . $ParentData->{Label} . '|'
            . $Param{PossibleValues}->{ $ParentData->{DynamicFieldID} }->{ $ParentData->{Value} };
    }
    elsif ( defined $ParentData->{ParentID} && $ParentData->{ParentID} != 0 ) {
        $ParentTreeString = $Self->_GetParentTreeString(
            ID             => $ParentData->{ParentID},
            PossibleValues => $Param{PossibleValues},
            TreeNameList   => $Param{TreeNameList}
            )
            . '::'
            . $ParentData->{Label} . '|'
            . $Param{PossibleValues}->{ $ParentData->{DynamicFieldID} }->{ $ParentData->{Value} };
    }

    return $ParentTreeString;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
