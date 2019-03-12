# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::QuickState;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::YAML',
    'Kernel::System::DB',
    'Kernel::System::Valid',
    'Kernel::System::State',
    'Kernel::System::Main',
    'Kernel::System::Encode'
);

=head1 NAME

Kernel::System::QuickState - signature lib

=head1 SYNOPSIS

All signature functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::QuickState');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item QuickStateAdd()

add quick state

    my $ID = $QuickStateObject->QuickStateAdd(
        Name     => 'Quick State',
        StateID  => 123,
        ValidID  => 123,
        COnfig   => 'YAML-Conent'
        UserID   => 123,
    );

=cut

sub QuickStateAdd {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for ( qw(UserID Config StateID ValidID Name) ) {
        if ( !defined( $Param{$_} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a quick state with this name already exists
    if ( $Self->NameExistsCheck( Name => $Param{Name} ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "A quick state with name '$Param{Name}' already exists!"
        );
        return;
    }

    # sql
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO kix_quick_state (
                name, state_id, valid_id, config, create_time, create_by, change_time, change_by
            )
            VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name},    \$Param{StateID},
            \$Param{ValidID}, \$Param{Config},
            \$Param{UserID},  \$Param{UserID},
        ],
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM kix_quick_state WHERE name = ? AND change_by = ?',
        Bind => [ \$Param{Name}, \$Param{UserID}, ],
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

=item QuickStateUpdate()

update quick state

    my $Success = $QuickStateObject->QuickStateUpdate(
        ID       => '123',
        Name     => 'Quick State',
        StateID  => 123,
        ValidID  => 123,
        Config   => 'YAML-Conent'
        UserID   => 123,
    );

=cut
sub QuickStateUpdate {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    for ( qw(ID UserID Config StateID ValidID Name) ) {
        if ( !defined( $Param{$_} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if a quick state with this name already exists
    if (
        $Self->NameExistsCheck(
            Name => $Param{Name},
            ID   => $Param{ID}
        )
    ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "A quick state with name '$Param{Name}' already exists!"
        );
        return;
    }

    # sql
    return if !$DBObject->Do(
        SQL => '
            UPDATE kix_quick_state
            SET
                name = ?,
                state_id = ?,
                valid_id = ?,
                config   = ?,
                change_time = current_timestamp,
                change_by = ?
            WHERE id = ?',
        Bind => [
            \$Param{Name},    \$Param{StateID},
            \$Param{ValidID}, \$Param{Config},
            \$Param{UserID},  \$Param{ID},
        ],
    );

    return 1;
}

=item QuickStateDelete()

delete a quick state

    $QuickStateObject->QuickStateDelete(
        ID => 123,
    );

=cut

sub QuickStateDelete {
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

    # delete attachment<->std template relation
    return if !$DBObject->Do(
        SQL  => 'DELETE
            FROM kix_quick_state_attachment
            WHERE quick_state_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # sql
    return if !$DBObject->Do(
        SQL  => 'DELETE
            FROM kix_quick_state
            WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    return 1;
}

=item QuickStateList()

get all valid quick states

    my %QuickStates = $QuickStateObject->QuickStateList();

Returns:
    %QuickStates = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );

get all quick states

    my %QuickStates = $QuickStateObject->QuickStateList(
        Valid => 0,
    );

Returns:
    %QuickStates = (
        1 => 'Some Name',
        2 => 'Some Name2',
    );

=cut

sub QuickStateList {
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

    my $SQL = '
        SELECT id, name
        FROM kix_quick_state';

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

=item QuickStateSearch()

search for quick states

    my %QuickStates = $QuickStateObject->QuickStateSearch(
        Search  => '*some*',    # optional
        Valid   => 1,           # optional defaul(0)

        # optional
        # Use QuickStateSearch as a state filter on a single state,
        # or a predefined state list
        # You can use states like new, open, pending reminder, ...
        State    => 'open',
        State    => ['open', 'new' ],
        StateID  => 1234,
        StateID  => [1234, 1235],
    );

Returns:
    %QuickStates = (
        1 => 'Some Name',
        2 => 'Some Name2',
        3 => 'Some Name3',
    );

=cut

sub QuickStateSearch {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');

    my %StateList = $StateObject->StateList(
        UserID  => 1,
        Valid   => 1
    );
    my %StateListReverse = reverse(%StateList);

    my @Bind;
    my @StateIDs;
    my $Valid = 1;
    if ( defined $Param{Valid}
         && !$Param{Valid}
    ) {
        $Valid = 0;
    }

    if (
        !$Param{State}
        && $Param{StateID}
    ) {
        if ( ref $Param{StateID} eq 'ARRAY') {
            push(@StateIDs,@{$Param{StateID}});
        } else {
            push(@StateIDs,$Param{StateID});
        }
        for my $StateID ( @StateIDs ) {
            if ( !$StateList{StateID} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "StateID '$StateID' is invalid!"
                );
                return;
            }
        }
    }

    elsif (
        !$Param{StateID}
        && $Param{State}
    ) {
        if ( ref $Param{State} eq 'ARRAY') {
            push(@StateIDs,@{$Param{State}});
        } else {
            push(@StateIDs,$Param{State});
        }

        for my $State ( @{$Param{State}} ) {
            if ( !$StateListReverse{$State} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "State '$State' is invalid!"
                );
                return;
            }
            push(@StateIDs, $StateListReverse{$State});
        }
    }

    my $SQLWhere = '';
    my $SQL      = '
        SELECT id, name
        FROM kix_quick_state
        WHERE';

    if ($Valid) {
        $SQLWhere .= ' valid_id IN ('
            . join( ', ', $ValidObject->ValidIDsGet())
            . ')';
    }

    if ( scalar(@StateIDs) ) {
        $SQLWhere .= ' AND' if $SQLWhere;
        $SQLWhere .= ' state_id IN ('
            . join( ', ', @StateIDs )
            . ')';
    }

    if ( $Param{Search} ) {
        my %QueryCondition = $DBObject->QueryCondition(
            Key      => ['name'],
            Value    => $Param{Search},
            BindMode => 1,
        );

        $SQLWhere .= ' AND' if $SQLWhere;
        $SQLWhere .= ' ' . $QueryCondition{SQL};
        push( @Bind, @{ $QueryCondition{Values} });
    }

    return if !$DBObject->Prepare(
        SQL  => $SQL . $SQLWhere,
        Bind => \@Bind,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    return %Data;
}

=item QuickStateGet()

get quick state all attributes

    my %QuickState = $QuickStateObject->QuickStateGet(
        ID => 123,
    );

Returns:

    %QuickState = (
        ID      => '123',
        Name    => 'Simple quick state',
        StateID => '123',
        ValidID => '1',
        Config  => {
            UsedArticle     => '1',
            Subject         => 'Example',
            Body            => 'HTML Body',
            ArticleTypeID   => '1'
            UsedPending     => '1',
            PendingTime     => '1',
            PendingFormatID => 'Days',
            ArticleTypeID   => '1'
        },
        Created => '2010-04-07 15:41:15',
        Changed => '2010-04-07 15:59:45',
    );

get quick state without config

    my %QuickState = $QuickStateObject->QuickStateGet(
        ID       => 123,
        MetaOnly => 1
    );

Returns:

    %QuickState = (
        ID      => '123',
        Name    => 'Simple quick state',
        StateID => '123',
        ValidID => '1',
        Created => '2010-04-07 15:41:15',
        Changed => '2010-04-07 15:59:45',
    );

=cut
sub QuickStateGet {
    my ($Self, %Param) = @_;

    # get needed objects
    my $DBObject    = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');
    my $YAMLObject  = $Kernel::OM->Get('Kernel::System::YAML');

    if (
        !$Param{ID}
        && !$Param{Name}
    ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Needed ID or Name!"
        );
        return;
    }

    my @Bind;
    my $SQLWhere  = '';
    my $SQLSelect = 'SELECT id, name, state_id, valid_id, create_time, change_time';
    my $SQLFrom   = '
            FROM kix_quick_state
            WHERE ';

    if ( !$Param{MetaOnly} ) {
        $SQLSelect .= ', config';
    }

    for my $Key ( qw(ID Name) ) {
        next if !$Param{$Key};
        $SQLWhere .= lc($Key) . ' = ?';
        push(@Bind, \$Param{$Key});
        last;
    }

    return if !$DBObject->Prepare(
        SQL  => $SQLSelect . $SQLFrom . $SQLWhere,
        Bind => \@Bind
    );

    # fetch the result
    my %Result;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %Result = (
            ID      => $Row[0],
            Name    => $Row[1],
            StateID => $Row[2],
            ValidID => $Row[3],
            Created => $Row[4],
            Changed => $Row[5]
        );

        if ( !$Param{MetaOnly} ) {
            if ( $Row[6] ) {
                my $Data = $YAMLObject->Load(
                    Data => $Row[6]
                );
                $Result{Config} = $Data || '';
            } else {
                $Result{Config} = '';
            }
        }
    }

    return %Result;
}

=item QuickStateWriteAttachment()

add attachemnt to  quick state

    my $Success = $QuickStateObject->QuickStateWriteAttachment(
        QuickStateID => 123,
        Filename     => 'Quick_State.png',
        Filesize     => '123',
        ContentType  => 'image/png',
        Content      => 'Conent'
        UserID       => 123,
    );

=cut
sub QuickStateWriteAttachment {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    # check needed stuff
    for (qw(Content Filename ContentType QuickStateID UserID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Param{Filename} = $MainObject->FilenameCleanUp(
        Filename  => $Param{Filename},
        Type      => 'Local',
        NoReplace => 1,
    );

    my $NewFileName = $Param{Filename};
    my %UsedFile;
    my %Index = $Self->QuickStateAttachmentIndex(
        QuickStateID => $Param{QuickStateID},
    );

    for ( sort keys %Index ) {
        $UsedFile{ $Index{$_}->{Filename} } = 1;
    }

    for ( my $i = 1; $i <= 50; $i++ ) {
        if ( exists $UsedFile{$NewFileName} ) {
            if ( $Param{Filename} =~ /^(.*)\.(.+?)$/ ) {
                $NewFileName = "$1-$i.$2";
            }
            else {
                $NewFileName = "$Param{Filename}-$i";
            }
        }
    }

    # get file name
    $Param{Filename} = $NewFileName;

    # get attachment size
    $Param{Filesize} = bytes::length( $Param{Content} );

    # encode attachment if it's a postgresql backend!!!
    if ( !$DBObject->GetDatabaseFunction('DirectBlob') ) {

        $EncodeObject->EncodeOutput( \$Param{Content} );

        $Param{Content} = encode_base64( $Param{Content} );
    }

    my $Disposition;
    my $Filename;
    if ( $Param{Disposition} ) {
        ( $Disposition, $Filename ) = split( ';', $Param{Disposition});
    }
    $Disposition //= '';

    # write attachment to db
    return if !$DBObject->Do(
        SQL => '
            INSERT INTO kix_quick_state_attachment
            (
                quick_state_id, filename, content_type, content_size,
                content, content_id, disposition, create_time, create_by,
                change_time, change_by
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{QuickStateID}, \$Param{Filename},
            \$Param{ContentType}, \$Param{Filesize},
            \$Param{Content}, \$Param{ContentID},
            \$Disposition, \$Param{UserID}, \$Param{UserID},
        ],
    );

    return 1;
}

=item QuickStateAttachmentIndex()

get a index list of attachments of quick state

    my %Index = $QuickStateObject->QuickStateAttachmentIndex(
        QuickStateID => 123,
    );

Returns:

    %Index = (
        1 => {
            FileID      => '123',
            Filename    => 'Quick_State.png',
            Filesize    => '123 KByte',
            FilesizeRaw => '123',
            ContentID   => 'inline123456.228845.5641667'
            ContentType => 'image/png',
            Disposition => 'inline',
        },
    );

=cut
sub QuickStateAttachmentIndex {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if ( !$Param{QuickStateID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need QuickStateID!'
        );
        return;
    }

    my %Index;
    my $Counter = 0;
    # try database
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id, filename, content_type, content_size, content_id, disposition
            FROM kix_quick_state_attachment
            WHERE quick_state_id = ?
            ORDER BY filename, id',
        Bind => [ \$Param{QuickStateID} ],
    );

    while ( my @Row = $DBObject->FetchrowArray() ) {

        # human readable file size
        my $FileSizeRaw = $Row[3];
        if ( $Row[3] ) {
            if ( $Row[3] > ( 1024 * 1024 ) ) {
                $Row[3] = sprintf "%.1f MBytes", ( $Row[3] / ( 1024 * 1024 ) );
            }
            elsif ( $Row[3] > 1024 ) {
                $Row[3] = sprintf "%.1f KBytes", ( ( $Row[3] / 1024 ) );
            }
            else {
                $Row[3] = $Row[3] . ' Bytes';
            }
        }

        my $Disposition = $Row[6];
        if ( !$Disposition ) {

            # if no content disposition is set images with content id should be inline
            if ( $Row[4] && $Row[2] =~ m{image}i ) {
                $Disposition = 'inline';
            }

            # converted body should be inline
            elsif ( $Row[1] =~ m{file-[12]} ) {
                $Disposition = 'inline';
            }

            # all others including attachments with content id that are not images
            #   should NOT be inline
            else {
                $Disposition = 'attachment';
            }
        }

        # add the info the the hash
        $Counter++;
        $Index{$Counter} = {
            FileID             => $Row[0],
            Filename           => $Row[1],
            Filesize           => $Row[3]       || '',
            FilesizeRaw        => $FileSizeRaw  || 0,
            ContentID          => $Row[4]       || '',
            ContentType        => $Row[2],
            Disposition        => $Disposition,
        };
    }

    return %Index;
}

=item QuickStateAttachmentList()

get all attachments of quick state

    my @Attachments = $QuickStateObject->QuickStateAttachmentList(
        QuickStateID => 123,
    );

Returns:

    @Attachments = [
        {
            FileID      => '123',
            Filename    => 'Quick_State.png',
            Filesize    => '123',
            Content     => 'content',
            ContentID   => 'inline123456.228845.5641667'
            ContentType => 'image/png',
            Disposition => 'inline',
        },
    );

=cut
sub QuickStateAttachmentList {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    # check needed stuff
    if ( !$Param{QuickStateID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need QuickStateID!'
        );
        return;
    }

    # try database
    return if !$DBObject->Prepare(
        SQL => '
            SELECT filename, content_type, content_size, content_id, disposition, content
            FROM kix_quick_state_attachment
            WHERE quick_state_id = ?
            ORDER BY filename, id',
        Bind => [ \$Param{QuickStateID} ],
    );

    my @Attachemnts;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $EncodeObject->EncodeOutput( \$Row[5] );
         my %Result =  (
            Filename     => $Row[0],
            Filesize     => $Row[2] || '',
            ContentID    => $Row[3] || '',
            ContentType  => $Row[1],
            Disposition  => $Row[4],
            Content      => $Row[5]
        );
        push(@Attachemnts, \%Result);
    }

    return @Attachemnts;
}

=item QuickStateAttachmentGet()

get attachment
    my %File = $QuickStateObject->QuickStateAttachmentGet(
        QuickStateID => 123,
        FileID       => 123
    );

Returns:

    %File = (
        FileID      => '123',
        Filename    => 'Quick_State.png',
        Filesize    => '123',
        Content     => 'content',
        ContentID   => 'inline123456.228845.5641667'
        ContentType => 'image/png',
        Disposition => 'inline',
    );

=cut
sub QuickStateAttachmentGet{
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for ( qw(FileID QuickStateID) ) {
        if ( !defined $Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return if !$DBObject->Prepare(
        SQL => '
            SELECT id, filename, content_type, content_size, content_id, disposition, content
            FROM kix_quick_state_attachment
            WHERE quick_state_id = ? AND id = ?',
        Bind => [ \$Param{QuickStateID}, \$Param{FileID} ],
    );

    my %File;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %File = (
            FileID      => $Row[0],
            Filename    => $Row[1],
            Filesize    => $Row[3],
            ContentType => $Row[2],
            ContentID   => $Row[4],
            Disposition => $Row[5],
            Content     => $Row[6],
        );
    }

    return %File;
}

=item QuickStateAttachmentDelete()

delete a single attachment of quick state

    my $Success = $QuickStateObject->QuickStateAttachmentDelete(
        QuickStateID => 123,
        FileID       => 123
    );

delete all attachments of quick state

    my $Success = $QuickStateObject->QuickStateAttachmentDelete(
        QuickStateID => 123,
    );

=cut
sub QuickStateAttachmentDelete{
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject  = $Kernel::OM->Get('Kernel::System::DB');
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    if ( !defined $Param{QuickStateID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Need $_!",
        );
        return;
    }

    my @Bind;
    my $SQL = 'DELETE
        FROM kix_quick_state_attachment
        WHERE quick_state_id = ?';
    push(@Bind, \$Param{QuickStateID});

    if ( $Param{FileID} ) {
        $SQL .=  ' AND id = ?';
        push(@Bind, \$Param{FileID});
    }

    return if !$DBObject->Prepare(
        SQL => $SQL,
        Bind => \@Bind,
    );

    return 1;
}

=item NameExistsCheck()

    return 1 if another quick state with this name already exists

        $Exist = $QuickStateObject->NameExistsCheck(
            Name => 'Quick State',
            ID   => 1,              # optional
        );

=cut

sub NameExistsCheck {
    my ( $Self, %Param ) = @_;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM kix_quick_state WHERE name = ?',
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

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
