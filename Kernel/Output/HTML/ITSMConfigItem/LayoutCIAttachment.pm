# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutCIAttachment;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CIAttachmentStorage::AttachmentStorage',
    'Kernel::System::Log',
    'Kernel::System::Web::Request'
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItemLayoutCIAttachment - layout backend module

=head1 SYNOPSIS

All layout functions of CIAttachment objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::Output::HTML::ITSMConfigItemLayoutCIAttachment');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}            = $Kernel::OM->Get('Kernel::Config');
    $Self->{LanguageObject}          = $Kernel::OM->Get('Kernel::Language');
    $Self->{LayoutObject}            = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{AttachmentStorageObject} = $Kernel::OM->Get('Kernel::System::CIAttachmentStorage::AttachmentStorage');
    $Self->{LogObject}               = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}             = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

=item OutputStringCreate()

create output string

    my $Value = $BackendObject->OutputStringCreate(
        Value => 11,       # (optional)
        Item => $ItemRef,
    );

=cut

sub OutputStringCreate {
    my ( $Self, %Param ) = @_;
    my $String = "";

    #check required stuff...
    foreach (qw(Item)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( $Param{Value} ) {
        my %AttDirData   = ();
        my $SizeNote     = "";
        my $RealFileSize = 0;
        my $MD5Note      = "";
        my $RealMD5Sum   = "";

        # get saved properties (attachment directory info)
        %AttDirData = $Self->{AttachmentStorageObject}->AttachmentStorageGetDirectory(
            ID => $Param{Value},
        );

        if (
            $AttDirData{Preferences}->{FileSizeBytes}
            &&
            $AttDirData{Preferences}->{MD5Sum}
            )
        {

            # get real properties to check if the attachment content has been changed
            my %RealProperties =
                $Self->{AttachmentStorageObject}->AttachmentStorageGetRealProperties(
                %AttDirData,
                );

            $RealMD5Sum   = $RealProperties{RealMD5Sum};
            $RealFileSize = $RealProperties{RealFileSize};

            my $MD5CheckEnabled =
                $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::AttachmentMD5Check') || '';
            my $SizeCheckEnabled =
                $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::AttachmentSizeCheck') || '';

            if ( $SizeCheckEnabled && $RealFileSize != $AttDirData{Preferences}->{FileSizeBytes} ) {
                $SizeNote = "Invalid content - file size on disk "
                    . "has been changed";

                if ( $RealFileSize > ( 1024 * 1024 ) ) {
                    $RealFileSize = sprintf "%.1f MBytes", ( $RealFileSize / ( 1024 * 1024 ) );
                }
                elsif ( $RealFileSize > 1024 ) {
                    $RealFileSize = sprintf "%.1f KBytes", ( ( $RealFileSize / 1024 ) );
                }
                else {
                    $RealFileSize = $RealFileSize . ' Bytes';
                }
            }
            elsif ( $MD5CheckEnabled && $RealMD5Sum ne $AttDirData{Preferences}->{MD5Sum} ) {
                $MD5Note = "Invalid md5sum - The file might have been changed";
            }
        }

        # build the attachment part of the output
        $String = $Self->BuildAttachmentPresentation(
            FileName   => $AttDirData{FileName},
            FileSize   => $AttDirData{Preferences}->{FileSize},
            DataType   => $AttDirData{Preferences}->{DataType},
            SizeNote   => $SizeNote,
            SizeOnDisk => $RealFileSize,
            MD5Note    => $MD5Note,
            AttachID   => $AttDirData{AttDirID},
        );
    }

    return $String;
}

=item FormDataGet()

get form data as hash reference

    my $FormDataRef = $BackendObject->FormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub FormDataGet {
    my ( $Self, %Param ) = @_;
    my %FormData;

    my $AttDirID = $Self->{ParamObject}->GetParam( Param => $Param{Key} . "ID" ) || '';
    my $AttDirDel = $Self->{ParamObject}->GetParam( Param => $Param{Key} . "Delete" );
    my $ConfigItemID = $Param{ConfigItemID};

    #check required stuff...
    foreach (qw(Key Item)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    #get the upload file....
    my %UploadStuff = $Self->{ParamObject}->GetUploadAll(
        Param  => $Param{Key} . "Upload",
        Source => 'string',
    );

    #save the attachment if there is one...
    if ( (%UploadStuff) && $ConfigItemID ) {

        #store the attachment in the default storage backend....
        $AttDirID = $Self->{AttachmentStorageObject}->AttachmentStorageAdd(
            DataRef  => \$UploadStuff{Content},
            FileName => $UploadStuff{Filename},
            StorageBackend =>
                $Self->{ConfigObject}->Get('AttachmentStorage::DefaultStorageBackendModule'),
            UserID      => 1,
            Preferences => {
                DataType => $UploadStuff{ContentType},
                }
        );

    }

    #xml_storage stores only the reference to the attachment directory entry
    #get the AttachmentDirectory-ID (either existing or just uploaded)...
    $FormData{Value} = undef;

    if ($AttDirID) {
        $FormData{Value} = $AttDirID;
    }

    if ( ($AttDirDel) ) {    # && !(%UploadStuff)
        $FormData{Value} = '';
    }

    #set invalid param...
    if ( $Param{Item}->{Input}->{Required} && !$FormData{Value} ) {
        $FormData{Invalid} = 1;
        $Param{Item}->{Form}->{ $Param{Key} }->{Invalid} = 1;
    }

    return \%FormData;
}

=item InputCreate()

create a input string

    my $Value = $BackendObject->InputCreate(
        Key => 'Item::1::Node::3',
        Value => 11,       # (optional)
        Item => $ItemRef,
    );

=cut

sub InputCreate {
    my ( $Self, %Param ) = @_;
    my %AttDirData   = ();
    my $SizeNote     = "";
    my $RealFileSize = 0;
    my $MD5Note      = "";
    my $RealMD5Sum   = "";

    #check required stuff...
    foreach (qw(Key Item)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( $Param{Value} ) {

        # get saved attachment properties und preferences
        %AttDirData = $Self->{AttachmentStorageObject}->AttachmentStorageGetDirectory(
            ID => $Param{Value}
        );

        if (
            $AttDirData{Preferences}->{FileSizeBytes}
            &&
            $AttDirData{Preferences}->{MD5Sum}
            )
        {

            # get real properties to check if the attachment content has been changed
            my %RealProperties =
                $Self->{AttachmentStorageObject}->AttachmentStorageGetRealProperties(
                %AttDirData,
                );

            $RealMD5Sum   = $RealProperties{RealMD5Sum};
            $RealFileSize = $RealProperties{RealFileSize};

            my $MD5CheckEnabled =
                $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::AttachmentMD5Check') || '';
            my $SizeCheckEnabled =
                $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::AttachmentSizeCheck') || '';

            if ( $SizeCheckEnabled && $RealFileSize != $AttDirData{Preferences}->{FileSizeBytes} ) {
                $SizeNote = "Invalid content - file size on disk "
                    . "has been changed";

                if ( $RealFileSize > ( 1024 * 1024 ) ) {
                    $RealFileSize = sprintf "%.1f MBytes", ( $RealFileSize / ( 1024 * 1024 ) );
                }
                elsif ( $RealFileSize > 1024 ) {
                    $RealFileSize = sprintf "%.1f KBytes", ( ( $RealFileSize / 1024 ) );
                }
                else {
                    $RealFileSize = $RealFileSize . ' Bytes';
                }
            }
            elsif ( $MD5CheckEnabled && $RealMD5Sum ne $AttDirData{Preferences}->{MD5Sum} ) {
                $MD5Note = "Invalid md5sum - The file might have been changed";
            }
        }
    }

    # build the attachment part of the output
    my $String = $Self->BuildAttachmentModification(
        FileName   => $AttDirData{FileName},
        FileSize   => $AttDirData{Preferences}->{FileSize},
        DataType   => $AttDirData{Preferences}->{DataType},
        SizeNote   => $SizeNote,
        SizeOnDisk => $RealFileSize,
        MD5Note    => $MD5Note,
        AttachID   => $Param{Value},
        Key        => $Param{Key},
    );

    return $String;
}

=cut item BuildAttachmentModification()
build the attachment part of the output in ConfigItem Edit window
=cut

sub BuildAttachmentModification {
    my ( $Self, %Param ) = @_;
    my $ExistingAttachment = "";
    my $AttDirIDName       = $Param{Key} . "ID";
    my $AttDirDel          = $Param{Key} . "Delete";
    my $AttDirIDUploadName = $Param{Key} . "Upload";

    my $AttachID = $Param{AttachID} || '';

    my $Advice =
        $Self->{LanguageObject}->Translate('Select a file to replace current attachment');

    if ( defined( $Param{FileName} ) && ( $Param{FileName} ) ) {
        my $ahref =
            "<a href=\""
            . $Self->{LayoutObject}->{Baselink}
            . "Action=AgentAttachmentStorage;"
            . "AttachmentDirectoryID=$Param{AttachID}";

        # add session id if needed
        if ( !$Self->{LayoutObject}->{SessionIDCookie} ) {
            $ahref .= ";"
                . $Self->{LayoutObject}->{SessionName}
                . "="
                . $Self->{LayoutObject}->{SessionID};
        }
        $ahref .= "\">";

        $ExistingAttachment = " <li>"
            . $ahref
            . "<b>$Param{FileName}</b></a>&nbsp;&nbsp;"
            . "($Param{FileSize})"
            . " </li>";

        if ( $Param{SizeNote} ) {
            $ExistingAttachment .= " <li><font color=\"red\">"
                . $Self->{LanguageObject}->Translate( $Param{SizeNote} )
                . " ("
                . $Self->{LanguageObject}->Translate( $Param{SizeOnDisk} )
                . ")"
                . "! </font></li>";
        }
        elsif ( $Param{MD5Note} ) {
            $ExistingAttachment .= " <li><font color=\"red\">"
                . $Self->{LanguageObject}->Translate( $Param{MD5Note} )
                . "! </font></li>";
        }
        $ExistingAttachment .= "<li> <label for=\"$AttDirIDName\">$Advice:</label></li>";
    }
    my $Output = "<ul>" . $ExistingAttachment
        . "</ul>"
        . "<input type=\"hidden\" name=\"$AttDirIDName\" value=\"$AttachID\"/> "
        . "<input type=\"file\" id=\"$AttDirIDName\" name=\"$AttDirIDUploadName\" class=\"fixed\"/> ";

    return $Output;
}

=cut item BuildAttachmentModification()
build the attachment part of the output for ConfigItem Details
=cut

sub BuildAttachmentPresentation {
    my ( $Self, %Param ) = @_;
    my $Output = '';

    if ( $Param{AttachID} && $Param{FileName} ) {

        my $ahref = "<a href=\""
            . $Self->{LayoutObject}->{Baselink}
            . "Action=AgentAttachmentStorage;"
            . "AttachmentDirectoryID=$Param{AttachID}";

        # add session id if needed
        if ( !$Self->{LayoutObject}->{SessionIDCookie} ) {
            $ahref .= ";"
                . $Self->{LayoutObject}->{SessionName}
                . "="
                . $Self->{LayoutObject}->{SessionID};
        }
        $ahref .= "\">";

        $Output = $ahref . "$Param{FileName}</a>&nbsp;&nbsp;" .
            "&nbsp;($Param{FileSize})&nbsp;";

        if ( $Param{SizeNote} ) {
            $Output .= '<font color="red">'
                . $Self->{LanguageObject}->Translate( $Param{SizeNote} )
                . " ("
                . $Self->{LanguageObject}->Translate( $Param{SizeOnDisk} )
                . ")"
                . '!</font>';
        }
        elsif ( $Param{MD5Note} ) {
            $Output .= '<font color="red">'
                . $Self->{LanguageObject}->Translate( $Param{MD5Note} )
                . '!</font>';
        }
    }
    return $Output;
}

=item SearchFormDataGet()

get search form data

    my $Value = $BackendObject->SearchFormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchFormDataGet {
    my ( $Self, %Param ) = @_;

    if ( ref $Param{Value} eq 'ARRAY' ) {
        return \@{ $Param{Value} };
    }

    #check required stuff...
    foreach (qw(Key Item)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get form data
    my @Values = $Self->{ParamObject}->GetArray( Param => $Param{Key} );

    # find all attachment_directory IDs for the given FileName
    if ( ( $Param{Key} eq 'Attachment' ) && $Values[0] ) {
        my $FileName = $Values[0];

        my $UsingWildcards = 0;
        if ( ( $FileName =~ s/\*/%/g ) || ( $FileName =~ m/%/ ) ) {
            $UsingWildcards = 1;
        }

        @Values = $Self->{AttachmentStorageObject}->AttachmentStorageSearch(
            FileName       => $FileName,
            UsingWildcards => $UsingWildcards,
        );
        if ( !$Values[0] ) {
            $Values[0] = -1;
        }
    }
    return \@Values;
}

=item SearchInputCreate()

create a search input string

    my $Value = $BackendObject->SearchInputCreate(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchInputCreate {
    my ( $Self, %Param ) = @_;

    #check required stuff...
    foreach (qw(Key Item)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $String = "<input type=\"Text\" name=\"$Param{Key}\" size=\"60\">";

    return $String;
}

1;


=head1 VERSION

$Revision$ $Date$

=cut



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
