# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::CIAttachment;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::CIAttachmentStorage::AttachmentStorage',
    'Kernel::System::Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::CIAttachment - xml backend module

=head1 SYNOPSIS

All xml functions of CIAttachment objects

=over 4

=cut

=item new()

create a object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::CIAttachment');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{AttachmentStorageObject} = $Kernel::OM->Get('Kernel::System::CIAttachmentStorage::AttachmentStorage');
    $Self->{LogObject}               = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Item => $ItemRef,
        Value => 1.1.1.1,
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;
    my $Value = '';

    # check needed stuff
    foreach (qw(Item)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "$Param{Item}->{Input}->{Type} :: Need $_!"
            );
            return;
        }
    }
    if ( ( defined $Param{Value} ) ) {
        my $retVal = $Param{Value};

        return $retVal;
    }

    return '';

}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 0,
            Element          => $Param{Key},
            Block            => 'InputField',
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my $RetVal       = "";
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
        && $AttDirData{Preferences}->{MD5Sum}
    ) {

        my %RealProperties =
            $Self->{AttachmentStorageObject}->AttachmentStorageGetRealProperties(
            %AttDirData,
            );

        $RetVal       = "(size " . $AttDirData{Preferences}->{FileSizeBytes} . ")";
        $RealMD5Sum   = $RealProperties{RealMD5Sum};
        $RealFileSize = $RealProperties{RealFileSize};

        if ( $RealFileSize != $AttDirData{Preferences}->{FileSizeBytes} ) {
            $SizeNote = " Invalid content - file size on disk has been changed";

            if ( $RealFileSize > ( 1024 * 1024 ) ) {
                $RealFileSize = sprintf "%.1f MBytes", ( $RealFileSize / ( 1024 * 1024 ) );
            }
            elsif ( $RealFileSize > 1024 ) {
                $RealFileSize = sprintf "%.1f KBytes", ( ( $RealFileSize / 1024 ) );
            }
            else {
                $RealFileSize = $RealFileSize . ' Bytes';
            }

            $RetVal = "(real size " . $RealFileSize . $SizeNote . ")";
        }
        elsif ( $RealMD5Sum ne $AttDirData{Preferences}->{MD5Sum} ) {
            $MD5Note = " Invalid md5sum - The file might have been changed.";
            $RetVal =~ s/\)/$MD5Note\)/g;
        }

    }
    $RetVal = $AttDirData{FileName};

    #return file information...
    return $RetVal;
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # this attribute is not intended for import yet...
    $Param{Value} = "";

    return $Param{Value};
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # this attribute is not intended for import yet...
    $Param{Value} = "";

    return $Param{Value};
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
