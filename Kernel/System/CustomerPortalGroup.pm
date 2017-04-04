# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CustomerPortalGroup;

use strict;
use warnings;
use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CacheInternal',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::CustomerPortalGroup

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a CustomerPortalGroup object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CustomerPortalGroupObject = $Kernel::OM->Get('Kernel::System::CustomerPortalGroup');

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

=item PortalGroupGet()

Gets the portal group data

    my $Result = $CustomerPortalGroupObject->PortalGroupGet(
        PortalGroupID => 123,
    );

=cut

sub PortalGroupGet {
    my ( $Self, %Param ) = @_;

    # PortalGroupID must be passed
    if ( !$Param{PortalGroupID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need PortalGroupID!',
        );
        return;
    }

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'PortalGroupGet::'.$Param{PortalGroupID};
    my $CacheResult = $Self->{CacheObject}->Get(
        Type => 'CustomerPortalGroup',
        Key  => $CacheKey
    );
    return %{$CacheResult} if (IsHashRefWithData($CacheResult));

    # get service from db
    $Self->{DBObject}->Prepare(
        SQL =>
            'SELECT id, name, icon_content_type, icon_content, valid_id, create_time, create_by, change_time, change_by FROM customer_portal_group WHERE id = ?',
        Bind  => [ \$Param{PortalGroupID} ],
        Limit => 1,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Data{PortalGroupID}        = $Row[0];
        $Data{Name}                 = $Row[1];
        $Data{Icon}->{ContentType}  = $Row[2];
        $Data{Icon}->{Content}      = $Row[3];
        $Data{ValidID}              = $Row[4];
        $Data{CreateTime}           = $Row[5];
        $Data{CreateBy}             = $Row[6];
        $Data{ChangeTime}           = $Row[7];
        $Data{ChangeBy}             = $Row[8];
    }

    # check if exists
    if ( !$Data{PortalGroupID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "PortalGroupGet: No such PortalGroupID ($Param{PortalGroupID})!",
        );
        return;
    }

    # set cache
    $Self->{CacheObject}->Set(
        Type           => 'CustomerPortalGroup',
        Key            => $CacheKey,
        Value          => \%Data,
        TTL            => $CacheTTL,
    );

    return %Data;
}

=item PortalGroupAdd()

Adds a new portal group

    my $Result = $CustomerPortalGroupObject->PortalGroupAdd(
        Name  => 'some name',
        Icon  => { 
            Filename    => 'abc.txt',
            ContentType => 'text/plain',
            Content     => 'Some text',
        },
        ValidID => 0 | 1 | 2,
        UserID => 123
    );

=cut

sub PortalGroupAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name Icon ValidID UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $IconContentType = $Param{Icon}->{ContentType};
    my $IconContent     = encode_base64($Param{Icon}->{Content});

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO customer_portal_group (name, icon_content_type, icon_content, valid_id, create_by, create_time, change_by, change_time) VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp)",
        Bind => [
            \$Param{Name},
            \$IconContentType,
            \$IconContent,
            \$Param{ValidID},
            \$Param{UserID},
            \$Param{UserID},
        ],
    );

    #handle the insert result...
    if ($DBInsert) {

        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => 'CustomerPortalGroup'
        );

        return 0 if !$Self->{DBObject}->Prepare(
            SQL  => 'SELECT max(id) FROM customer_portal_group WHERE name = ?',
            Bind => [ 
                \$Param{Name}
            ],
        );

        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            return $Row[0];
        }
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "PortalGroupAdd::DB insert failed!",
        );
    }

    return 0;
}

=item PortalGroupUpdate()

Updates a portal group

    my $Result = $CustomerPortalGroupObject->PortalGroupUpdate(
        PortalGroupID => 123
        Name          => 'some name',
        Icon  => {                          # optional
            Filename    => 'abc.txt',
            ContentType => 'text/plain',
            Content     => 'Some text',
        },
        ValidID       => 0 | 1 | 2,
        UserID        => 123
    );

=cut

sub PortalGroupUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PortalGroupID Name ValidID UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # do the db update...
    my $DBResult = $Self->{DBObject}->Do(
        SQL  => "UPDATE customer_portal_group SET name = ?, valid_id = ?, change_by = ?, change_time = current_timestamp WHERE id = ?",
        Bind => [
            \$Param{Name},
            \$Param{ValidID},
            \$Param{UserID},
            \$Param{PortalGroupID},
        ],
    );

    #handle the update result...
    if (!$DBResult) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "PortalGroupUpdate::DB update failed!",
        );
        return 0;
    }

    if (IsHashRefWithData($Param{Icon})) {
        my $IconContentType = $Param{Icon}->{ContentType};
        my $IconContent     = encode_base64($Param{Icon}->{Content});

        $DBResult = $Self->{DBObject}->Do(
            SQL  => "UPDATE customer_portal_group SET icon_content_type = ?, icon_content = ? WHERE id = ?",
            Bind => [
                \$IconContentType,
                \$IconContent,
                \$Param{PortalGroupID},
            ],
        );
    }

    #handle the update result...
    if ($DBResult) {
        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => 'CustomerPortalGroup'
        );
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "PortalGroupUpdate::DB update failed!",
        );
        return 0;
    }

    return 1;
}

=item PortalGroupDelete()

Deletes a list of portal groups.

    my $Result = $CustomerPortalGroupObject->PortalGroupDelete(
        PortalGroupIDs => [...],
    );

=cut

sub PortalGroupDelete {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{PortalGroupIDs} ) {
        $Self->{LogObject}->Log( 
            Priority => 'error', 
            Message  => 'PortalGroupDelete: Need PortalGroupIDs!' );
        return;
    }

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => 'CustomerPortalGroup'
    );

    return $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM customer_portal_group WHERE id in ('.join(',', @{$Param{PortalGroupIDs}}).')',
    );
}

=item PortalGroupList()

Returns all (matching) portal group entries

    my %Hash = $CustomerPortalGroupObject->PortalGroupList(
        Search  => '...'             # optional
        ValidID => 0 | 1 | 2         # optional
        Limit   => 123               # optional
    );

=cut

sub PortalGroupList {
    my ( $Self, %Param ) = @_;
    my $WHEREClauseExt = '';
    my %Result;

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'PortalGroupList::'.($Param{Search} || '').'::'.($Param{ValidID} || '');
    my $CacheResult = $Self->{CacheObject}->Get(
        Type => 'CustomerPortalGroup',
        Key  => $CacheKey
    );
    return %{$CacheResult} if (IsHashRefWithData($CacheResult));

    if ( $Param{Search} ) {
        my $Name = $Param{Search};
        $Name =~ s/\*/%/g;
        $WHEREClauseExt .= " AND lower(name) like '".lc($Name)."'";
    }
    if ( defined $Param{ValidID} ) {
        $WHEREClauseExt .= " AND valid_id = $Param{ValidID}";
    }

    my $SQL = "SELECT id, name FROM customer_portal_group WHERE 1=1".$WHEREClauseExt;

    return if !$Self->{DBObject}->Prepare( 
        SQL   => $SQL . $WHEREClauseExt . " ORDER by name",
        Limit => $Param{Limit}, 
    );

    my $Count = 0;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Result{ $Data[0] } = $Data[1];
    }

    # set cache
    $Self->{CacheObject}->Set(
        Type           => 'CustomerPortalGroup',
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
