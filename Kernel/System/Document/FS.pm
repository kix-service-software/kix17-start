# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Document::FS;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::DB',
    'Kernel::System::Group',
    'Kernel::System::Main',
    'Kernel::System::User',
);

use File::Find;
use File::Basename;
use Digest::MD5;

=head1 NAME

Kernel::System::Document

=head1 SYNOPSIS

Document backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a Document object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $DocumentObject = $Kernel::OM->Get('Kernel::System::DocumentField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{GroupObject}  = $Kernel::OM->Get('Kernel::System::Group');
    $Self->{MainObject}   = $Kernel::OM->Get('Kernel::System::Main');
    $Self->{UserObject}   = $Kernel::OM->Get('Kernel::System::User');

    # get config
    $Self->{Config}   = $Self->{ConfigObject}->Get('Document');
    $Self->{ConfigFS} = $Self->{ConfigObject}->Get('Document::FS');

    return $Self;
}

sub DocumentGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(DocumentID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentGet: Need $_!"
            );
            return {};
        }
    }
    my $FileID = $Param{DocumentID};
    my %Data   = $Self->_MetaGet(
        FileID => $FileID,
    );

    # if we found something and the entry is outdated, try to find the latest entry
    while ( exists( $Data{Outdated} ) && $Data{Outdated} ) {
        %Data = $Self->_MetaGet(
            ParentID => $Data{FileID},
        );
    }
    if ( -f "$Data{Path}/$Data{Name}" ) {

        # get file content
        $Data{Content} = ${
            $Self->{MainObject}->FileRead(
                Directory => $Data{Path},
                Filename  => $Data{Name},
                Result    => 'Scalar',
                )
            };
    }
    return %Data;
}

sub DocumentMetaGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(DocumentID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentMetaGet: Need $_!"
            );
            return {};
        }
    }
    my $FileID = $Param{DocumentID};
    my %Data   = $Self->_MetaGet(
        FileID => $FileID,
    );
    my %OldData = %Data;

    # if we found something and the entry is outdated, try to find the latest entry
    while ( exists( $Data{Outdated} ) && $Data{Outdated} ) {
        %Data = $Self->_MetaGet(
            ParentID => $Data{FileID},
        );
        if (%Data) {
            %OldData = %Data;
        }
    }
    if ( !%Data ) {

        # if we didn't find something, just use the last one we've found
        # so that we can display a name
        %Data = %OldData
    }

    # create DisplayPath to prevent user from knowing about the full local path
    my $DisplayPath = $Data{Path};
    if ($DisplayPath) {
        my %DirHash = $Self->_DirectoryListGet(
            HashResult             => 1,
            IgnoreSourcePermission => 1,
        );
        for my $Source ( keys %DirHash ) {
            for my $Path ( @{ $DirHash{$Source} } ) {
                $Path =~ s/^(.*?)\/$/$1/g;
                if ( $DisplayPath =~ /^$Path/ ) {
                    $DisplayPath =~ s/^$Path/&lt;$Self->{Config}->{Sources}->{$Source}&gt;/;
                    last;
                }
            }
        }
    }
    my %Result = (
        Name        => $Data{Name},
        Path        => $Data{Path},
        DisplayPath => $DisplayPath,
    );
    return %Result;
}

sub DocumentCheckPermission {
    my ( $Self, %Param ) = @_;
    my $Result = 'NoAccess';

    # check needed stuff
    for (qw(DocumentID UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentCheckPermission: Need $_!"
            );
            return 0;
        }
    }

    # DocumentPath
    my %Data = $Self->DocumentMetaGet(
        DocumentID => $Param{DocumentID},
    );
    if ( -f "$Data{Path}/$Data{Name}" ) {

        # UserPaths
        my @UserDirectoryList = $Self->_DirectoryListGet(
            UserID => $Param{UserID}
        );
        for my $Dir (@UserDirectoryList) {
            if ( $Data{Path} =~ /^$Dir.*$/ ) {
                $Result = 'Access';
                last;
            }
        }
    }
    else {
        $Result = 'NoLink';
    }
    return $Result;
}

sub _DocumentPathGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(DocumentID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "_DocumentPathGet: Need $_!"
            );
            return {};
        }
    }

    # db quote
    for (qw(DocumentID)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }
    my %Data = ();
    my $SQL  = "SELECT path FROM kix_file_watcher WHERE id=$Param{DocumentID}";
    $Self->{DBObject}->Prepare( SQL => $SQL );
    my @Row = $Self->{DBObject}->FetchrowArray();
    return $Row[0];
}

sub DocumentNameSearch {
    my ( $Self, %Param ) = @_;

    for my $Argument (qw(UserID FileName)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "DocumentNameSearch: Need $Argument!",
            );
            return;
        }
    }

    # get filename
    my @FileList;
    my $SearchPattern = $Param{FileName};
    return @FileList unless $SearchPattern;
    my @PathList = $Self->_DirectoryListGet(
        Source => $Param{Source},
        UserID => $Param{UserID},
    );
    if ( $Self->{ConfigFS}->{SearchType} =~ /LIVE/ ) {

        # live search in filesystem including sync to database
        $SearchPattern =~ s/\*/.*?/g;
        @FileList = $Self->_DirectorySearch(
            SearchPattern => $SearchPattern,
            PathList      => \@PathList,
            IgnoreCase    => exists( $Param{IgnoreCase} ) ? $Param{IgnoreCase} : 1,
            SearchLimit   => ( exists( $Param{Limit} ) && $Param{Limit} ne 'NONE' )
            ? $Param{Limit}
            : undef,
        );
    }
    else {

        # search in database
        my $PathList;
        for my $Dir (@PathList) {
            $PathList .= "OR path like '$Dir/%'";
        }
        if ($PathList) {
            $PathList = substr( $PathList, 3 );
        }
        $SearchPattern =~ s/\*/\%/g;

        # search in database
        my $SQL = "SELECT id, name, path, fingerprint, last_mod, parent_id, last_found "
            . "FROM kix_file_watcher WHERE "
            . (
            ( $Param{IgnoreCase} )
            ?
                " name_lower like '" . lc($SearchPattern) . "'"
            : " name like '$SearchPattern'"
            )
            .
            " AND ($PathList)" .
            " AND outdated = 0" .
            " ORDER BY last_found DESC";
        $Self->{DBObject}->Prepare( SQL => $SQL );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            push( @FileList, $Row[0] );
        }
    }
    return @FileList;
}

sub _DirectorySearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(SearchPattern PathList)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "_DirectorySearch: Need $Argument!",
            );
            return;
        }
    }
    my $Counter = 0;
    my @FoundFiles;
    my $DirectorySearchSubRef = sub {

        # filter filename
        my $NameMatch =
            ( $Param{IgnoreCase} )
            ? ( $_ =~ /^$Param{SearchPattern}$/i )
            : ( $_ =~ /^$Param{SearchPattern}$/ );
        if (
            (
                ( -f $_ && -r $_ )
                || ( $Param{FileName} && -f $Param{FileName} && -r $Param{FileName} )
            )
            && $NameMatch
            && ( !$Param{SearchLimit} || $Counter <= $Param{SearchLimit} )
            )
        {
            $Counter++;
            my $FilePath = $Param{FilePath} || $File::Find::dir;     # path of File
            my $FileName = $_;                                       # filename
            my $File     = $Param{FileName} || $File::Find::name;    # full path and filename
            my $FileID   = 0;
            my %FileData = $Self->_MetaGet(
                Name => $FileName,
                Path => $FilePath,
            );
            my $FileMod     = ( stat($File) )[9];
            my $FileSize    = ( stat($File) )[7];
            my $FileFinger  = $Self->_CalcMD5( File => $File );
            my $WatcherID   = $FileData{FileID};
            my $FileAddTime = time();
            if (%FileData) {

                # file already exists in database, check if the stored one is identical
                if ( $FileData{FingerPrint} eq $FileFinger && $FileData{LastMod} == $FileMod )
                {

                    # ok it is identical, let's just update its lastseen time
                    $Self->_MetaUpdate(
                        FileID   => $FileData{FileID},
                        LastSeen => time(),
                    );
                }
                else {

                    # hmmm...fingerprint and/or modtime are different but the file is still there,
                    # so just update the meta data
                    $WatcherID = $Self->_MetaUpdate(
                        FileID      => $FileData{FileID},
                        Name        => $FileName,
                        Path        => $FilePath,
                        FingerPrint => $FileFinger,
                        Size        => $FileSize,
                        LastMod     => $FileMod,
                        LastSeen    => time(),
                    );
                }
            }
            else {

                # file is not in database, just add it
                $WatcherID = $Self->_MetaAdd(
                    Name        => $FileName,
                    Path        => $FilePath,
                    FingerPrint => $FileFinger,
                    Size        => $FileSize,
                    LastMod     => $FileMod,
                    FirstSeen   => $FileAddTime,
                    LastSeen    => $FileAddTime,
                );
            }
            push( @FoundFiles, $WatcherID );
        }
    };
    if ( $Self->{ConfigFS}->{SearchType} eq 'LIVE' ) {
        File::Find::find( $DirectorySearchSubRef, @{ $Param{PathList} } );
    }
    elsif ( $Self->{ConfigFS}->{SearchType} eq 'LIVESYS' ) {
        my @SysFoundFiles;
        my $Command;
        my $SearchPattern = $Param{SearchPattern};
        $SearchPattern =~ s/\.\*\?/*/g;
        foreach my $Path ( @{ $Param{PathList} } ) {
            if ( $Param{IgnoreCase} ) {
                $Command = "find $Path -type f -name $SearchPattern";
            }
            else {
                $Command = "find $Path -type f -iname $SearchPattern";
            }
            my @SysFindResult = `$Command`;
            foreach my $File (@SysFindResult) {
                chomp($File);
                push( @SysFoundFiles, $File );
                $Counter++;
                if ( $Param{SearchLimit} && $Counter > $Param{SearchLimit} ) {
                    last;
                }
            }
            if ( $Param{SearchLimit} && $Counter > $Param{SearchLimit} ) {
                last;
            }
        }

        # reset counter and call worker function
        $Counter = 0;
        foreach my $File (@SysFoundFiles) {
            $Param{FileName} = $File;
            $Param{FilePath} = dirname($File);
            $_               = basename($File);
            $DirectorySearchSubRef->();
        }
    }
    return @FoundFiles;
}

sub _MetaImport {
    my ( $Self, %Param ) = @_;
    my $FileCount = 0;
    if ( $Self->{ConfigFS}->{SyncType} eq 'DirectorySearch' ) {

        # get all directories defined for backend FS
        my @PathList = $Self->_DirectoryListGet(
            UserID => 1,
        );

        # sync all files
        my @FileList = $Self->_DirectorySearch(
            PathList      => \@PathList,
            SearchPattern => ".*?",
            IgnoreCase    => 1,
            UserID        => 1,
        );
        $FileCount = scalar(@FileList);
    }
    elsif ( $Self->{ConfigFS}->{SyncType} eq 'MetaFile' ) {
        my @MetaFiles = split( /\s*\,\s*/, $Self->{ConfigFS}->{MetaFiles} );

        # read metadata files
        for my $MetaFile ( @{MetaFiles} ) {
            open( my $Handle, "<", $MetaFile );
            while ( my $Line = <$Handle> ) {
                chop($Line);
                $Line =~ s/^{//g;
                $Line =~ s/}$//g;
                my ( $FileFinger, $FullPath, $FileSize, $FileMod ) = split( /}::{/, $Line );
                $FileCount++;
                my $FileName = basename($FullPath);
                my $FilePath = dirname($FullPath);

                # look for the file in our database
                my %FileData = $Self->_MetaGet(
                    Name => $FileName,
                    Path => $FilePath,
                );
                my $WatcherID = $FileData{FileID};
                if (%FileData) {

                    # file already exists in database, check if the stored one is identical
                    if (
                        $FileData{FingerPrint} ne $FileFinger
                        || $FileData{LastMod} != $FileMod
                        )
                    {

                      # hmmm...fingerprint and/or modtime are different but the file is still there,
                      # so just update the meta data
                        $WatcherID = $Self->_MetaUpdate(
                            FileID      => $FileData{FileID},
                            Name        => $FileName,
                            Path        => $FilePath,
                            FingerPrint => $FileFinger,
                            Size        => $FileSize,
                            LastMod     => $FileMod,
                            LastSeen    => time(),
                        );
                    }
                }
                else {

                    # file is not in database, just add it
                    $WatcherID = $Self->_MetaAdd(
                        Name        => $FileName,
                        Path        => $FilePath,
                        FingerPrint => $FileFinger,
                        Size        => $FileSize,
                        LastMod     => $FileMod,
                        FirstSeen   => time(),
                        LastSeen    => time(),
                    );
                }
            }
            close($Handle);
        }
    }
    return $FileCount;
}

sub _MetaSync {
    my ( $Self, %Param ) = @_;
    my $WeightThreshold = 100;

    # look through database and check if file still exists in FS
    # if not, try to find it in meta data (this case can happen
    # if meta import did not contain the file)
    my @MetaList = $Self->_MetaList();
    for my $FileID (@MetaList) {
        my %FileData = $Self->_MetaGet( FileID => $FileID );

        # does the file still exist ?
        if ( !-f $FileData{Path} . '/' . $FileData{Name} ) {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message =>
                    "file not found: $FileData{Path}/$FileData{Name}, looking for possible candidates."
            );
            my %PossibleFiles = $Self->_MetaLookupPossible(
                %FileData,
            );
            if ( keys %PossibleFiles ) {

                # use the possible candidate with the highest weight
                my $LastWeight = 0;
                my $Count      = 0;
                my @SortedPossibleFileIDs =
                    sort { $PossibleFiles{$b}->{Weight} <=> $PossibleFiles{$a}->{Weight} }
                    keys %PossibleFiles;
                for my $PossibleFileID (@SortedPossibleFileIDs) {
                    my %PossibleFileData = %{ $PossibleFiles{$PossibleFileID} };

                    # only look at candidates with a usable weight
                    if ( $PossibleFileData{Weight} >= $WeightThreshold ) {
                        $Self->{LogObject}->Log(
                            Priority => 'notice',
                            Message =>
                                "possible above threshold: $PossibleFileData{Path}/$PossibleFileData{Name} ($PossibleFileData{Weight})"
                        );
                        last if ( $PossibleFileData{Weight} < $LastWeight );
                        $Count++;
                        $LastWeight = $PossibleFileData{Weight};
                    }
                }

# if there is no candidate with sufficiant weight or we have multiple candidates with the same weight
# we can't update
                if ( $Count == 1 ) {
                    my $NewFileID = $SortedPossibleFileIDs[0];
                    $Self->{LogObject}->Log(
                        Priority => 'notice',
                        Message =>
                            "using: $PossibleFiles{$SortedPossibleFileIDs[0]}->{Path}/$PossibleFiles{$SortedPossibleFileIDs[0]}->{Name} ($PossibleFiles{$SortedPossibleFileIDs[0]}->{Weight})"
                    );

                    # update old file as outdated
                    $Self->_MetaUpdate(
                        FileID   => $FileID,
                        Outdated => 1,
                    );

                    # update new file with parentID
                    $Self->_MetaUpdate(
                        FileID   => $NewFileID,
                        ParentID => $FileID,
                    );
                }
            }
            else {
                $Self->{LogObject}
                    ->Log( Priority => 'notice', Message => "No possible candidates found!" );
            }
        }
    }
    return 1;
}

sub _MetaList {
    my ( $Self, %Param ) = @_;
    my @Data;
    my $SQL = "SELECT id FROM kix_file_watcher WHERE outdated = 0";
    $Self->{DBObject}->Prepare( SQL => $SQL );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push( @Data, $Row[0] );
    }
    return @Data;
}

sub _MetaGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ParentID} && !$Param{FileID} && !$Param{Path} && !$Param{Name} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "_MetaGet: Need FileID or ParentID or Path and Name!"
        );
        return {};
    }
    my %Data = ();
    my $BindArray;
    my $SQL =
        "SELECT id, name, path, fingerprint, filesize, last_mod, parent_id, last_found, outdated FROM kix_file_watcher WHERE ";
    if ( $Param{FileID} ) {
        $SQL .= " id = $Param{FileID}";
    }
    elsif ( $Param{ParentID} ) {
        $SQL .= " parent_id = $Param{ParentID}";
    }
    else {
        $SQL .= " path = ? AND name = ?";
        $BindArray = [
            \$Param{Path},
            \$Param{Name},
        ];
    }
    $SQL .= " ORDER BY last_found DESC";
    $Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Limit => 1,
        Bind  => $BindArray,
    );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            FileID      => $Row[0],
            Name        => $Row[1],
            Path        => $Row[2],
            FingerPrint => $Row[3],
            Size        => $Row[4],
            LastMod     => $Row[5],
            ParentID    => $Row[6],
            LastSeen    => $Row[7],
            Outdated    => $Row[8],
        );
    }
    return %Data;
}

sub _MetaUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(FileID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "_MetaUpdate: Need $_!"
            );
            return {};
        }
    }
    $Self->{LogObject}
        ->Log( Priority => 'notice', Message => "updating fileID: $Param{FileID}" );

    my %Data = ();
    my $SQL  = 'UPDATE kix_file_watcher SET ';
    if ( $Param{FingerPrint} ) {
        $SQL .= " fingerprint = '$Param{FingerPrint}',";
    }
    if ( $Param{LastMod} ) {
        $SQL .= " last_mod = '$Param{LastMod}',";
    }
    if ( $Param{LastSeen} ) {
        $SQL .= " last_found = '$Param{LastSeen}',";
    }
    if ( $Param{Size} ) {
        $SQL .= " filesize = '$Param{Size}',";
    }
    if ( $Param{ParentID} ) {
        $SQL .= " parent_id = '$Param{ParentID}',";
    }
    if ( $Param{Outdated} ) {
        $SQL .= " outdated = '$Param{Outdated}',";
    }
    $SQL =~ s/,$//g;
    $SQL .= " WHERE id = $Param{FileID}";
    $Self->{DBObject}->Do( SQL => $SQL );
    return;
}

sub _MetaAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(FingerPrint Path Name Size FirstSeen LastSeen)) {
        if ( !$Param{$_} && !exists( $Param{$_} ) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "_MetaAdd: Need $_!"
            );
            return {};
        }
    }
    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => "adding new: $Param{Path}/$Param{Name}"
    );

    my $SQL =
        'INSERT INTO kix_file_watcher (parent_id, path, path_lower, name, name_lower, fingerprint,'
        . ' filesize, first_found, last_found, mod_type, last_mod, outdated)'
        . ' VALUES (0, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 0)';
    return if !$Self->{DBObject}->Prepare(
        SQL  => $SQL,
        Bind => [
            \$Param{Path},        \lc( $Param{Path} ),
            \$Param{Name},        \lc( $Param{Name} ),
            \$Param{FingerPrint}, \$Param{Size},
            \$Param{FirstSeen},   \$Param{LastSeen},
            \$Param{LastMod},
        ],
    );
    $SQL = 'SELECT id FROM kix_file_watcher WHERE '
        . " fingerprint='$Param{FingerPrint}' AND "
        . ' path=? AND '
        . ' name=? AND '
        . " last_mod=$Param{LastMod}"
        . ' ORDER BY last_found DESC';
    $Self->{DBObject}->Prepare(
        SQL   => $SQL,
        Limit => 1,
        Bind  => [
            \$Param{Path},
            \$Param{Name},
        ],
    );
    my @Row = $Self->{DBObject}->FetchrowArray();
    return $Row[0];
}

sub _MetaLookupPossible {
    my ( $Self, %Param ) = @_;
    my %Data;
    my %WeightDef = (
        FingerPrint => 100,
        Name        => 50,
        Path        => 50,
        Size        => 30,
        LastMod     => 20,
    );

    # check needed stuff
    for (qw(FileID FingerPrint Name Size LastMod)) {
        if ( !$Param{$_} && !exists( $Param{$_} ) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "_MetaLookupPossible: Need $_!"
            );
            return {};
        }
    }
    my $FileName = lc( $Param{Name} );
    my @ParameterList;
    if ($FileName) {
        push( @ParameterList, "name_lower = '$FileName'" );
    }
    if ( $Param{FingerPrint} ) {
        push( @ParameterList, "fingerprint = '$Param{FingerPrint}'" );
    }
    if ( $Param{Size} ) {
        push( @ParameterList, "filesize = '$Param{Size}'" );
    }
    if ( $Param{LastMod} ) {
        push( @ParameterList, "last_mod = '$Param{LastMod}'" );
    }
    my $SQL = 'SELECT id FROM kix_file_watcher WHERE'
        . " id <> $Param{FileID} AND"
        . ' (' . join( ' OR ', @ParameterList ) . ')'
        . ' AND outdated = 0';
    $Self->{DBObject}->Prepare( SQL => $SQL );
    my @FileIDs;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        push( @FileIDs, $Row[0] );
    }
    if ( !@FileIDs && $Param{DeepSearch} ) {
        $SQL = 'SELECT id FROM kix_file_watcher WHERE'
            . " id <> $Param{FileID} AND"
            . ' outdated = 0';
        $Self->{DBObject}->Prepare( SQL => $SQL );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            push( @FileIDs, $Row[0] );
        }
    }
    for my $FileID (@FileIDs) {

        my %FileData = $Self->_MetaGet( FileID => $FileID );
        $FileData{Weight} = 0;

        # calc weight
        for my $Key ( keys %WeightDef ) {

            # check which parameters do match and weight them
            if ( $FileData{$Key} eq $Param{$Key} ) {
                $FileData{Weight} += $WeightDef{$Key};
            }
            elsif ( $Key eq 'Size' && $Param{Size} ) {

                # calc percentual diff of file sizes
                my $SizeDiff = $FileData{Size} / $Param{Size};
                my $Weight
                    += $WeightDef{$Key} * ( $SizeDiff < 1 ) ? $SizeDiff : ( 1 / $SizeDiff );

                $FileData{Weight} += $Weight;
            }
            elsif ( $Key eq 'Name' ) {
                my $Distance = $Self->_CalcStringDistance( $FileName, lc( $FileData{Name} ) );

                if ( $Distance < length($FileName) ) {
                    my $Weight =
                        $WeightDef{$Key} * ( length($FileName) - $Distance ) /
                        length($FileName);

                    $FileData{Weight} += $Weight;
                }
            }
            elsif ( $Key eq 'Path' ) {
                my $Distance =
                    $Self->_CalcStringDistance( lc( $Param{Path} ), lc( $FileData{Path} ) );

                if ( $Distance < length( $Param{Path} ) ) {
                    my $Weight = $WeightDef{$Key} * ( length( $Param{Path} ) - $Distance ) /
                        length( $Param{Path} );

                    $FileData{Weight} += $Weight;
                }
            }
        }

        $Data{$FileID} = \%FileData;
    }
    return %Data;
}

sub _DirectoryListGet {
    my ( $Self, %Param ) = @_;
    my $Config = $Self->{ConfigObject}->Get('Document');
    my %PathHash;
    my @PathList;
    my @Sources;
    if ( $Param{Source} ) {
        push( @Sources, $Param{Source} );
    }
    else {
        @Sources = keys %{ $Config->{Sources} };
    }
    for my $Source (@Sources) {
        if ( $Config->{Backend}->{$Source} eq "FS" ) {
            my %Parameters = $Self->_GetSourceParameters( Source => $Source );
            if (
                $Param{IgnoreSourcePermission}
                || $Self->DocumentCheckSourceAccess(
                    Source => $Source,
                    UserID => $Param{UserID}
                )
                )
            {
                for my $Dir ( @{ $Parameters{RootDir} } ) {
                    push( @PathList, $Dir );
                }
                if ( $Param{HashResult} ) {
                    my @TmpPathList = @PathList;
                    @PathList = ();
                    $PathHash{$Source} = \@TmpPathList;
                }
            }
        }
    }
    if ( !$Param{HashResult} ) {

        # delete subpaths
        for my $Dir (@PathList) {
            @PathList = map { s/^$Dir.*$/$Dir/i; $_; } @PathList;
        }

        # delete double entries
        my %Paths;
        $Paths{$_} = 0 for @PathList;
        @PathList = keys %Paths;
        return @PathList;
    }
    else {
        return %PathHash;
    }
}

sub _CalcMD5 {
    my ( $Self, %Param ) = @_;
    my $Result = '';
    open( my $FH, '<', $Param{File} );
    my $ctx = Digest::MD5->new;
    $ctx->addfile(*$FH);
    $Result = $ctx->hexdigest;
    close($FH);
    return $Result;
}

sub _GetSourceParameters {
    my ( $Self, %Param ) = @_;
    my %Parameters;
    my %ParameterTypes = (
        RootDir => 'ARRAY',
    );

    # check needed stuff
    for (qw(Source)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return {};
        }
    }
    my %Tmp;
    my @OptionList = split( /\s*\,\s*/, $Self->{Config}->{Parameters}->{ $Param{Source} } );
    for my $Option (@OptionList) {
        my ( $Key, $Value ) = split( /=/, $Option );
        if ( !exists( $Tmp{$Key} ) ) {
            my @TmpArray;
            $Tmp{$Key} = \@TmpArray;
        }
        push( @{ $Tmp{$Key} }, $Value );
    }

    # create parameters hash
    for my $Key ( keys %Tmp ) {
        if (
            scalar( @{ $Tmp{$Key} } ) > 1
            || ( exists( $ParameterTypes{$Key} ) && $ParameterTypes{$Key} eq 'ARRAY' )
            )
        {
            $Parameters{$Key} = $Tmp{$Key};
        }
        else {
            $Parameters{$Key} = $Tmp{$Key}->[0];
        }
    }
    return %Parameters;
}

sub _GetSourceAccess {
    my ( $Self, %Param ) = @_;
    my %Parameters;
    my %ParameterTypes = (
        Role  => 'ARRAY',
        Group => 'ARRAY',
        User  => 'ARRAY',
    );

    # check needed stuff
    for (qw(Source)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return {};
        }
    }
    my %Tmp;
    my @OptionList = split( /\s*\,\s*/, $Self->{Config}->{Access}->{ $Param{Source} } );
    for my $Option (@OptionList) {
        my ( $Key, $Value ) = split( /=/, $Option );
        if ( !exists( $Tmp{$Key} ) ) {
            my @TmpArray;
            $Tmp{$Key} = \@TmpArray;
        }
        push( @{ $Tmp{$Key} }, $Value );
    }

    # create parameters hash
    for my $Key ( keys %Tmp ) {
        if (
            scalar( @{ $Tmp{$Key} } ) > 1
            || ( exists( $ParameterTypes{$Key} ) && $ParameterTypes{$Key} eq 'ARRAY' )
            )
        {
            $Parameters{$Key} = $Tmp{$Key};
        }
        else {
            $Parameters{$Key} = $Tmp{$Key}->[0];
        }
    }
    return %Parameters;
}

sub DocumentCheckSourceAccess {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check needed stuff
    for (qw(Source UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return {};
        }
    }

    # root has all permissions
    if ( $Param{UserID} == 1 ) {
        return 1;
    }
    my %AccessOptions = $Self->_GetSourceAccess( Source => $Param{Source} );
    for my $Key ( keys %AccessOptions ) {

        # if we already found some permission
        last if ($Result);

        # check roles, groups and users
        if ( $Key eq 'Role' ) {
            for my $Role ( @{ $AccessOptions{$Key} } ) {
                my @UserIDs = $Self->{GroupObject}->GroupUserRoleMemberList(
                    RoleID => $Self->{GroupObject}->RoleLookup( Role => $Role ),
                    Result => 'ID',
                );
                if ( grep {/$Param{UserID}/} @UserIDs ) {
                    $Result = 1;
                    last;
                }
            }
        }
        elsif ( $Key eq 'Group' ) {
            for my $Group ( @{ $AccessOptions{$Key} } ) {
                my @UserIDs = $Self->{GroupObject}->GroupGroupMemberList(
                    GroupID => $Self->{GroupObject}->GroupLookup( Group => $Group ),
                    Type    => 'ro',
                    Result  => 'ID',
                );
                if ( grep {/$Param{UserID}/} @UserIDs ) {
                    $Result = 1;
                    last;
                }
            }
        }
        elsif ( $Key eq 'User' ) {
            for my $User ( @{ $AccessOptions{$Key} } ) {
                my $UserID = $Self->{UserObject}->UserLookup( UserLogin => $User );
                if ( $UserID == $Param{UserID} ) {
                    $Result = 1;
                    last;
                }
            }
        }
    }
    return $Result;
}

# Levenshtein algorithm taken from
# http://en.wikibooks.org/wiki/Algorithm_implementation/Strings/Levenshtein_distance#Perl
sub _CalcStringDistance {
    my ( $Self, $StringA, $StringB ) = @_;
    my ( $len1, $len2 ) = ( length $StringA, length $StringB );
    return $len2 if ( $len1 == 0 );
    return $len1 if ( $len2 == 0 );
    my %d;
    for ( my $i = 0; $i <= $len1; ++$i ) {
        for ( my $j = 0; $j <= $len2; ++$j ) {
            $d{$i}{$j} = 0;
            $d{0}{$j} = $j;
        }
        $d{$i}{0} = $i;
    }

    # Populate arrays of characters to compare
    my @ar1 = split( //, $StringA );
    my @ar2 = split( //, $StringB );
    for ( my $i = 1; $i <= $len1; ++$i ) {
        for ( my $j = 1; $j <= $len2; ++$j ) {
            my $cost = ( $ar1[ $i - 1 ] eq $ar2[ $j - 1 ] ) ? 0 : 1;
            my $min1 = $d{ $i - 1 }{$j} + 1;
            my $min2 = $d{$i}{ $j - 1 } + 1;
            my $min3 = $d{ $i - 1 }{ $j - 1 } + $cost;
            if ( $min1 <= $min2 && $min1 <= $min3 ) {
                $d{$i}{$j} = $min1;
            }
            elsif ( $min2 <= $min1 && $min2 <= $min3 ) {
                $d{$i}{$j} = $min2;
            }
            else {
                $d{$i}{$j} = $min3;
            }
        }
    }
    return $d{$len1}{$len2};
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
