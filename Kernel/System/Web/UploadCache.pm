# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Web::UploadCache;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
);

=head1 NAME

Kernel::System::Web::UploadCache - an upload file system cache

=head1 SYNOPSIS

All upload cache functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $WebUploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    my $GenericModule = $Kernel::OM->Get('Kernel::Config')->Get('WebUploadCacheModule')
        || 'Kernel::System::Web::UploadCache::DB';

    # load generator auth module
    $Self->{Backend} = $Kernel::OM->Get($GenericModule);

    return $Self if $Self->{Backend};
    return;
}

=item FormIDCreate()

create a new Form ID

    my $FormID = $UploadCacheObject->FormIDCreate();

=cut

sub FormIDCreate {
    my ( $Self, %Param ) = @_;

    return $Self->{Backend}->FormIDCreate(%Param);
}

=item FormIDRemove()

remove all data for a provided Form ID

    $UploadCacheObject->FormIDRemove( FormID => 123456 );

=cut

sub FormIDRemove {
    my ( $Self, %Param ) = @_;

    return $Self->{Backend}->FormIDRemove(%Param);
}

=item FormIDAddFile()

add a file to a Form ID

    $UploadCacheObject->FormIDAddFile(
        FormID      => 12345,
        Filename    => 'somefile.html',
        Content     => $FileInString,
        ContentType => 'text/html',
        Disposition => 'inline', # optional
    );

ContentID is optional (automatically generated if not given on disposition = inline)

    $UploadCacheObject->FormIDAddFile(
        FormID      => 12345,
        Filename    => 'somefile.html',
        Content     => $FileInString,
        ContentID   => 'some_id@example.com',
        ContentType => 'text/html',
        Disposition => 'inline', # optional
    );

=cut

sub FormIDAddFile {
    my ( $Self, %Param ) = @_;

    if ( !defined($Param{Uploaded})
         && $Param{Filename}
    ) {
        return $Self->{Backend}->FormIDAddFile(%Param);
    }
    elsif (
        defined($Param{Uploaded})
        && scalar(@{$Param{Uploaded}})
    ) {
        for my $Attachment ( @{$Param{Uploaded}} ) {
            $Self->{Backend}->FormIDAddFile(
                FormID => $Param{FormID},
                %{$Attachment}
            );
        }
    }

    return 1;
}

=item FormIDRemoveFile()

removes a file from a form id

    $UploadCacheObject->FormIDRemoveFile(
        FormID => 12345,
        FileID => 1,
    );

=cut

sub FormIDRemoveFile {
    my ( $Self, %Param ) = @_;

    return $Self->{Backend}->FormIDRemoveFile(%Param);
}

=item FormIDGetAllFilesData()

returns an array with a hash ref of all files for a Form ID

    my @Data = $UploadCacheObject->FormIDGetAllFilesData(
        FormID => 12345,
    );

    Return data of on hash is Content, ContentType, ContentID, Filename, Filesize, FileID;

=cut

sub FormIDGetAllFilesData {
    my ( $Self, %Param ) = @_;

    return @{ $Self->{Backend}->FormIDGetAllFilesData(%Param) };
}

=item FormIDGetAllFilesMeta()

returns an array with a hash ref of all files for a Form ID

Note: returns no content, only meta data.

    my @Data = $UploadCacheObject->FormIDGetAllFilesMeta(
        FormID => 12345,
    );

    Return data of hash is ContentType, ContentID, Filename, Filesize, FileID;

=cut

sub FormIDGetAllFilesMeta {
    my ( $Self, %Param ) = @_;

    return @{ $Self->{Backend}->FormIDGetAllFilesMeta(%Param) };
}

=item FormIDCleanUp()

Removed no longer needed temporary files.

Each file older than 1 day will be removed.

    $UploadCacheObject->FormIDCleanUp();

=cut

sub FormIDCleanUp {
    my ( $Self, %Param ) = @_;

    return $Self->{Backend}->FormIDCleanUp(%Param);
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
