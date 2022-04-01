# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SystemMessage;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::DB',
    'Kernel::System::Valid',
    'Kernel::System::Main',
    'Kernel::System::YAML'
);

=head1 NAME

Kernel::System::SystemMessage - signature lib

=head1 SYNOPSIS

All signature functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::SystemMessage');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item MessageAdd()

add news

    my $ID = $SystemMessageObject->MessageAdd(
        Title          => 'Some Message',
        ValidID        => 123,
        ShortText      => 'Some short text',
        Body           => 'Some news text',
        ValidFrom      => 'Timestamp',
        ValidTo        => 'Timestamp',
        Templates      => [...],
        PopupTemplates => [...],
        UserID         => 123,
    );

=cut

sub MessageAdd {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    for ( qw(UserID Templates ValidID Title ShortText Body) ) {
        if ( !defined( $Param{$_} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Config;
    for ( qw(Templates PopupTemplates ShortText Body ValidTo ValidFrom) ) {
        $Config{$_} = $Param{$_} || '';
    }

    my $ConfigStrg = $YAMLObject->Dump(
        Data => \%Config
    );

    # sql
    return if !$DBObject->Do(
        SQL  => <<'END',
INSERT INTO kix_system_message (title, valid_id, config, create_time, create_by, change_time, change_by)
VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?)
END
        Bind => [
            \$Param{Title},   \$Param{ValidID},
            \$ConfigStrg,     \$Param{UserID},
            \$Param{UserID},
        ],
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM kix_system_message WHERE title = ? AND change_by = ?',
        Bind => [ \$Param{Title}, \$Param{UserID}, ],
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

=item MessageUpdate()

update news

    my $Success = $SystemMessageObject->MessageUpdate(
        MessageID      => '123',
        Title          => 'Message',
        ValidID        => 123,
        ShortText      => 'Some short text',
        Body           => 'Some news text',
        ValidFrom      => 'Timestamp',
        ValidTo        => 'Timestamp',
        Templates      => [...],
        PopupTemplates => [...],
        UserID         => 123,
    );

=cut
sub MessageUpdate {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject  = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

    for ( qw(MessageID UserID Templates ValidID Title ShortText Body) ) {
        if ( !defined( $Param{$_} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }


    my %Config;
    for ( qw(Templates PopupTemplates ShortText Body ValidTo ValidFrom) ) {
        $Config{$_} = $Param{$_} || '';
    }

    my $ConfigStrg = $YAMLObject->Dump(
        Data => \%Config
    );

    # sql
    return if !$DBObject->Do(
        SQL  => <<'END',
UPDATE kix_system_message
SET
    title = ?,
    valid_id = ?,
    config   = ?,
    change_time = current_timestamp,
    change_by = ?
WHERE id = ?
END
        Bind => [
            \$Param{Title}, \$Param{ValidID},
            \$ConfigStrg,   \$Param{UserID},
            \$Param{MessageID}
        ],
    );

    return 1;
}

=item MessageDelete()

delete a news

    $SystemMessageObject->MessageDelete(
        ID => 123,
    );

=cut

sub MessageDelete {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if ( !$Param{ID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # sql
    return if !$DBObject->Do(
        SQL  => 'DELETE FROM kix_system_message WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    return 1;
}

=item MessageList()

get all valid news

    my %Messages = $SystemMessageObject->MessageList();

Returns:
    %Messages = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );

get all news

    my %Messages = $SystemMessageObject->MessageList(
        Valid => 0,
    );

Returns:
    %Messages = (
        1 => 'Some Name',
        2 => 'Some Name2',
    );

=cut

sub MessageList {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');

    my $Valid = 1;
    if ( defined $Param{Valid}
         && !$Param{Valid}
    ) {
        $Valid = 0;
    }

    my $SQL = 'SELECT id, title FROM kix_system_message';

    if ($Valid) {
        $SQL .= ' WHERE valid_id IN ('
              . join( ', ', $ValidObject->ValidIDsGet())
              . ')';
    }

    my @Bind;
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    return %Data;
}

=item MessageSearch()

search for message

    my @Message = $SystemMessageObject->MessageSearch(
        Search  => '*some*',           # optional
        Valid   => 1,                  # optional default(0)
        SortBy  => 'Created',          # optional default(Created)
        OrderBy => 'Down',             # optional default(Down)
        Result  => 'ARRAY'             # optional default(HASH)
    );

Returns:
    @MessageID = (3,1,2);

search with used action and active state or valid date

    my %Message = $SystemMessageObject->MessageSearch(
        Action          => 'AgentTicketPhone', # optional
        IgnoreUserReads => 1,                  # optional default(0)
        Valid           => 1,                  # optional defaul(0)
        UserID          => 1,                  # optional
        UserType        => 'user'              # required if UserID used
    );

Returns:
    %Message = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );

search on valid date check

    my %Message = $SystemMessageObject->MessageSearch(
        DateCheck => 1,                 # optional
        Valid     => 1,                 # optional default(0)
    );

Returns:
    %Message = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );
=cut

sub MessageSearch {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');
    my $StateObject        = $Kernel::OM->Get('Kernel::System::State');
    my $DBObject           = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $JSONObject         = $Kernel::OM->Get('Kernel::System::JSON');

    my @Bind;
    my $Valid          = 1;
    my $SortBy         = $Param{SortBy}  || 'Created';
    my $OrderBy        = $Param{OrderBy} || 'Down';
    my $Result         = $Param{Result}  || 'HASH';
    my %SortAttributes = (
        Title       => 'title',
        Created     => 'create_time',
        Changed     => 'change_time',
        MessageID   => 'id',
        CreateBy    => 'create_by',
        ChangeBy    => 'change_by'
    );
    my %OrderAttributes = (
        Down => 'DESC',
        Up   => 'ASC',
    );

    if ( defined $Param{Valid}
         && !$Param{Valid}
    ) {
        $Valid = 0;
    }

    my $SQLWhere = '';
    my $SQL      = 'SELECT id FROM kix_system_message WHERE';

    if ($Valid) {
        $SQLWhere .= ' valid_id IN ('
                   . join( ', ', $ValidObject->ValidIDsGet())
                   . ')';
    }

    if ( $Param{Search} ) {
        my %QueryCondition = $DBObject->QueryCondition(
            Key      => ['title'],
            Value    => $Param{Search},
            BindMode => 1,
        );

        $SQLWhere .= ' AND' if $SQLWhere;
        $SQLWhere .= ' ' . $QueryCondition{SQL};
        push( @Bind, @{ $QueryCondition{Values} });
    }

    my %UserReads;
    if (
        !$Param{IgnoreUserReads}
        && $Param{UserID}
    ) {

        # check needed stuff
        if ( !$Param{UserType} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Need UserType by using UserID!'
            );
            return;
        }

        my %Preferences;
        if ( $Param{UserType} eq  'User' ) {
            %Preferences = $UserObject->GetPreferences(
                UserID => $Param{UserID},
            );
        }

        elsif ( $Param{UserType} eq 'Customer' ) {
            %Preferences = $CustomerUserObject->GetPreferences(
                UserID => $Param{UserID},
            );
        }

        if ( $Preferences{UserMessageRead} ) {
            my $JSONData = $JSONObject->Decode(
                Data => $Preferences{UserMessageRead}
            );
            %UserReads = %{$JSONData};
        }
    }

    if ( !$SortAttributes{$SortBy} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Invalid sort attribute '$SortBy' used!"
        );
        return;
    }

    if ( !$OrderAttributes{$OrderBy} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Invalid order attribute '$OrderBy' used!"
        );
        return;
    }

    $SQLWhere .= ' ORDER BY '
        . $SortAttributes{$SortBy}
        . ' '
        . $OrderAttributes{$OrderBy};

    return if !$DBObject->Prepare(
        SQL  => $SQL . $SQLWhere,
        Bind => \@Bind,
    );

    my $SystemTime = $TimeObject->SystemTime();
    my @TmpResult;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push(@TmpResult, $Row[0]);
    }

    my @ResultArray;
    my %ResultHash;
    my %NewUserReads;
    for my $MessageID ( @TmpResult ) {
        my %Data = $Self->MessageGet(
            MessageID => $MessageID
        );

        if (
            %UserReads
            && $UserReads{$MessageID}
        ) {
            my $ChangedTime = $TimeObject->TimeStamp2SystemTime(
                String => $Data{Changed}
            );

            if (
                $Data{ValidTo}
                && $Data{ValidTo} > $SystemTime
            ) {
                $NewUserReads{$MessageID} = $UserReads{$MessageID};
            }

            elsif ( $ChangedTime < $UserReads{$MessageID} ) {
                $NewUserReads{$MessageID} = $UserReads{$MessageID};
            }
        }

        if ( $Param{Action} ) {
            if (
                !grep( { $Param{Action} eq $_} @{$Data{Templates}} )
                || (
                    $Data{ValidFrom}
                    && $Data{ValidFrom} > $SystemTime
                )
                || (
                    $Data{ValidTo}
                    &&  $Data{ValidTo} < $SystemTime
                )
                || $NewUserReads{$MessageID}
            ) {
                next;
            }

            push(@ResultArray, $MessageID);
            $ResultHash{$MessageID} = $Data{Title};
        }

        elsif ( $Param{DateCheck} ) {
            if (
                (
                    $Data{ValidFrom}
                    && $Data{ValidFrom} > $SystemTime
                )
                || (
                    $Data{ValidTo}
                    &&  $Data{ValidTo} < $SystemTime
                )
            ) {
                next;
            }

            push(@ResultArray, $MessageID);
            $ResultHash{$MessageID} = $Data{Title};
        }

        else {
            push(@ResultArray, $MessageID);
            $ResultHash{$MessageID} = $Data{Title};
        }
    }

    if ( 
        !$Param{IgnoreUserReads}
        && $Param{UserID}
    ) {
        my $UserReadsStrg = '';
        if ( %NewUserReads ) {
            $UserReadsStrg = $JSONObject->Encode(
                Data => \%NewUserReads
            );
        }

        if ( $Param{UserType} eq  'User' ) {
            $UserObject->SetPreferences(
                Key    => 'UserMessageRead',
                Value  => $UserReadsStrg,
                UserID => $Param{UserID},
            );
        }

        elsif ( $Param{UserType} eq 'Customer' ) {
            $CustomerUserObject->SetPreferences(
                Key    => 'UserMessageRead',
                Value  => $UserReadsStrg,
                UserID => $Param{UserID},
            );
        }
    }

    if ( $Result eq 'ARRAY' ) {
        return @ResultArray;
    }

    return %ResultHash;
}

=item MessageGet()

get news all attributes

    my %Message = $SystemMessageObject->MessageGet(
        MessageID => 123,
    );

Returns:

    %Message = (
        MessageID      => '123',
        Title          => 'Simple message',
        ValidID        => '1',
        ShortText      => 'Some short text',
        Body           => 'Some news text',
        ValidFrom      => 'Timestamp',
        ValidTo        => 'Timestamp',
        Templates      => [...],
        PopupTemplates => [...],
        Created        => '2010-04-07 15:41:15',
        Changed        => '2010-04-07 15:59:45',
    );

=cut
sub MessageGet {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject  = $Kernel::OM->Get('Kernel::System::YAML');
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    if ( !$Param{MessageID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Needed MessageID!"
        );
        return;
    }

    return if !$DBObject->Prepare(
        SQL  => <<'END',
SELECT id, title, valid_id, config, create_time, create_by, change_time, change_by
FROM kix_system_message
WHERE id = ?
END
        Bind => [\$Param{MessageID}]
    );

    # fetch the result
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %Result = (
            MessageID => $Row[0],
            Title     => $Row[1],
            ValidID   => $Row[2],
            Created   => $Row[4],
            CreatedBy => $Row[5],
            Changed   => $Row[6],
            ChangedBy => $Row[7]
        );

        if ( $Row[3] ) {
            my $Data = $YAMLObject->Load(
                Data => $Row[3]
            );

            for my $Key ( keys( %{$Data} ) ) {
                $Result{ $Key } = $Data->{ $Key };
            }
        }
    }

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
