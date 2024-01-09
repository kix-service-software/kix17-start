# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CIAttachmentStorage::AttachmentStorage;

use strict;
use warnings;

use MIME::Base64;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main'
);

=head1 NAME

Kernel::System::CIAttachmentStorage::AttachmentStorage - std. attachment lib

=head1 SYNOPSIS

All attachment storage functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create std. attachment object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AttachmentStorageObject = $Kernel::OM->Get('Kernel::System::CIAttachmentStorage::AttachmentStorage');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{EncodeObject} = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{MainObject}   = $Kernel::OM->Get('Kernel::System::Main');

    # get configured storage backends...
    my $BackendRef = $Self->{ConfigObject}->Get('AttachmentStorage::StorageBackendModules');
    if ( !( ref($BackendRef) eq 'HASH' ) ) {
        return;
    }

    #retrieve required storage backend modules...
    my $SQL = "SELECT distinct(storage_backend) FROM attachment_directory";
    if ( $Self->{DBObject}->Prepare( SQL => $SQL ) ) {
        while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
            $BackendRef->{ $Data[0] } = 1;
        }
    }

    #load storage backends...
    for my $CurrKey ( keys( %{$BackendRef} ) ) {
        if ( $BackendRef->{$CurrKey} && $Self->{MainObject}->Require($CurrKey) ) {
            $Self->{$CurrKey} = $Kernel::OM->Get($CurrKey);
        }
    }

    return $Self;
}

=item AttachmentStorageGetDirectory()

get an attachment - returns attachment directory entry without attachment content

    my %Data = $AttachmentStorageObject->AttachmentStorageGetDirectory(
        ID => $ID,
    );

=cut

sub AttachmentStorageGetDirectory {
    my ( $Self, %Param ) = @_;
    my %Data = ();

    #check required stuff...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message => "Need ID!"
        );
        return;
    }

    #--------------------------
    # get attachment directory
    #--------------------------
    #db quoting...
    foreach (qw( ID)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    #build sql...
    my $SQL = "SELECT id, storage_backend, file_path, " .
        "file_name " .
        "FROM attachment_directory " .
        "WHERE id=$Param{ID}";

    $Self->{DBObject}->Prepare(
        SQL => $SQL,
    );

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            AttDirID       => $Data[0],
            StorageBackend => $Data[1],
            FilePath       => $Data[2],
            FileName       => $Data[3],
        );
    }

    #-------------------------------------
    # get attachment directory preferences
    #-------------------------------------

    #build sql...
    $SQL = "SELECT preferences_key, preferences_value " .
        "FROM attachment_dir_preferences " .
        "WHERE attachment_directory_id=$Param{ID}";

    $Self->{DBObject}->Prepare(
        SQL => $SQL,
    );

    my %Preferences;

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Preferences{ $Data[0] } = $Data[1];
    }

    #add preferences
    $Data{Preferences} = \%Preferences;

    return %Data;
}

=item AttachmentStorageGet()

get an attachment

    my %Data = $AttachmentStorageObject->AttachmentStorageGet(
        ID => $ID,
    );

=cut

sub AttachmentStorageGet {
    my ( $Self, %Param ) = @_;
    my %Data = ();

    #check required stuff...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message => "Need ID!"
        );
        return \%Data;
    }

    #get directory data...
    %Data = $Self->AttachmentStorageGetDirectory( ID => $Param{ID} );

    if ( !defined( $Data{AttDirID} ) ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message => "No attachment with this ID exists!"
        );
        return \%Data;
    }

    #get the actual attachment...
    my $AttachmentRef = $Self->{ $Data{StorageBackend} }->AttachmentGet(
        %Param,
        AttDirID => $Data{AttDirID},
    );

    #$Data{ContentType} = $AttachmentRef->{DataType};

    # get ContentRef for DB backend
    if ( $AttachmentRef->{DataRef} ) {
        $Data{ContentRef} = $AttachmentRef->{DataRef};
    }

    # get ContentRef for FS backend
    elsif ( exists( $AttachmentRef->{Data} ) ) {
        $Data{ContentRef} = \$AttachmentRef->{Data};
    }

    $AttachmentRef = undef;
    $AttachmentRef = {};

    return \%Data;
}

=item  AttachmentStorageGetRealProperties()

get the attachment's size on disk and the md5sum

    my %Data = $AttachmentStorageObject->AttachmentStorageGetRealProperties(
        AttDirID      => $AttDirID,
       StorageBackend => "Kernel::System::AttachmentStorageDB",
    );

=cut

sub AttachmentStorageGetRealProperties {
    my ( $Self, %Param ) = @_;
    my %RealProperties;

    # check required stuff...
    if ( !$Param{AttDirID} && !$Param{StorageBackend} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need AttDirID and StorageBackend!"
        );
        return %RealProperties;
    }

    # get the actual attachment properties...
    %RealProperties = $Self->{ $Param{StorageBackend} }->AttachmentGetRealProperties(
        AttDirID => $Param{AttDirID},
    );

    return %RealProperties;
}

=item AttachmentStorageAdd()

create a new attachment directory entry and write attachment to the specified backend

    my $ID = $AttachmentStorageObject->AttachmentStorageAdd(
        StorageBackend => 'Kernel::System::AttachmentStorageDB',
        DataRef => $SomeContentReference,
        FileName => 'SomeFileName.zip',
        UserID => 123,
        Preferences  => {
                            DataType           => 'text/xml',
                            SomeCustomParams   => 'with our own value',
                        }
    );

=cut

sub AttachmentStorageAdd {
    my ( $Self, %Param ) = @_;
    my $ID     = 0;
    my $MD5sum = '';

    #check required stuff...
    foreach (qw(DataRef FileName UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "Need $_!"
            );
            return;
        }
    }

    if ( !( $Param{StorageBackend} ) ) {
        $Param{StorageBackend} =
            $Self->{ConfigObject}->Get('AttachmentStorage::DefaultStorageBackendModule');
    }

    #-----------------------------------------------------------------
    # (1) create attachment directory entry...
    #-----------------------------------------------------------------
    #db quoting...
    foreach (qw( StorageBackend FileName)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_} );
    }
    foreach (qw( UserID )) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    #build sql...
    my $SQL = "INSERT INTO attachment_directory (" .
        " storage_backend, " .
        " file_path, file_name,  " .
        " create_time, create_by, change_time, change_by) " .
        " VALUES (" .
        " '$Param{StorageBackend}', " .
        " '', '$Param{FileName}', " .
        " current_timestamp, $Param{UserID}, current_timestamp, $Param{UserID})";

    #run SQL...
    if ( $Self->{DBObject}->Do( SQL => $SQL ) ) {

        #...and get the ID...
        $Self->{DBObject}->Prepare(
            SQL => "SELECT max(id) FROM attachment_directory WHERE " .
                "file_name = '$Param{FileName}' AND " .
                "storage_backend = '$Param{StorageBackend}' AND " .
                "create_by = $Param{UserID}",
        );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $ID = $Row[0];
        }

    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Could NOT insert attachment in attachment directory!",
        );
        return;
    }

    #-----------------------------------------------------------------
    # (2) save attachment directory preferences ...
    #-----------------------------------------------------------------

    # md5sum calculation
    $Self->{EncodeObject}->EncodeOutput( ${ $Param{DataRef} } );
    $Param{Preferences}->{MD5Sum} = md5_hex( ${ $Param{DataRef} } );

    # size calculation
    $Param{Preferences}->{FileSizeBytes} = bytes::length( ${ $Param{DataRef} } );

    my $FileSize = $Param{Preferences}->{FileSizeBytes};
    if ( $FileSize > ( 1024 * 1024 ) ) {
        $FileSize = sprintf "%.1f MBytes", ( $FileSize / ( 1024 * 1024 ) );
    }
    elsif ( $FileSize > 1024 ) {
        $FileSize = sprintf "%.1f KBytes", ( $FileSize / 1024 );
    }
    else {
        $FileSize = $FileSize . ' Bytes';
    }
    $Param{Preferences}->{FileSize} = $FileSize;

    # insert preferences
    for my $Key ( sort keys %{ $Param{Preferences} } ) {
        return if !$Self->{DBObject}->Do(
            SQL => 'INSERT INTO attachment_dir_preferences '
                . '(attachment_directory_id, preferences_key, preferences_value) VALUES ( ?, ?, ?)',
            Bind => [ \$ID, \$Key, \$Param{Preferences}->{$Key} ],
        );

    }

    #-----------------------------------------------------------------
    # (3) create attachment storage entry ( = save file)...
    #-----------------------------------------------------------------

    my $AttID = $Self->{ $Param{StorageBackend} }->AttachmentAdd(
        AttDirID => $ID,
        DataRef  => $Param{DataRef},
    );

    if ( !$AttID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Could NOT store attachment in storage ($Param{StorageBackend})!",
        );
        return;
    }

    #-----------------------------------------------------------------
    # (4) update attachment directory (i.e. file path)...
    #-----------------------------------------------------------------

    $AttID = $Self->{DBObject}->Quote($AttID);
    $SQL   = "UPDATE attachment_directory SET " .
        " file_path = '$AttID' " .
        " WHERE id = $ID";

    if ( $Self->{DBObject}->Do( SQL => $SQL ) ) {
        return $ID;
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Could NOT update attachment directory (ID=$ID, file_path=$AttID)!",
        );
        return;
    }
}

=item AttachmentStorageSearch()

returns attachment directory IDs for the given FileName

    my @Data = $AttachmentStorageObject->AttachmentStorageSearch(
        FileName => 'SomeFileName.zip',
        UsingWildcards => 1, (1 || 0, optional)
    );

=cut

sub AttachmentStorageSearch {
    my ( $Self, %Param ) = @_;
    my @Result = ();
    my $WHERE  = "(id > 0)";

    #check required stuff...
    if ( !$Param{FileName} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need FileName!"
        );
        return;
    }

    #db quoting...
    foreach (qw( FileName )) {
        if ( defined( $Param{$_} ) && ( $Param{$_} ) ) {
            $Param{$_} = $Self->{DBObject}->Quote( $Param{$_} );
        }
    }

    #build WHERE-clause...
    if ( $Param{UsingWildcards} ) {
        $WHERE .= " AND (file_name LIKE '$Param{FileName}')";
    }
    else {
        $WHERE .= " AND (file_name = '$Param{FileName}')";
    }

    #build sql...
    my $SQL = "SELECT id FROM attachment_directory " .
        "WHERE " . $WHERE;

    $Self->{DBObject}->Prepare(
        SQL => $SQL,
    );

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push( @Result, $Data[0] );
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
