# --
# Kernel/Modules/AgentAttachmentStorage.pm - to get the attachments
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentAttachmentStorage;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CIAttachmentStorage::AttachmentStorage',
    'Kernel::System::Log',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LayoutObject}            = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{AttachmentStorageObject} = $Kernel::OM->Get('Kernel::System::CIAttachmentStorage::AttachmentStorage');
    $Self->{LogObject}               = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}             = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my $Output  = '';
    my $Allowed = 1;

    # get params...
    my $AttachmentDirectoryID =
        $Self->{ParamObject}->GetParam( Param => 'AttachmentDirectoryID' );

    # check params...
    if ( !$AttachmentDirectoryID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'AgentAttachmentStorage: Need AttachmentDirectoryID!',
        );
        return $Self->{LayoutObject}->ErrorScreen();
    }

    # get the attachment...
    my %AttachmentData = %{
        $Self->{AttachmentStorageObject}->AttachmentStorageGet(
            ID => $AttachmentDirectoryID,
        )
    };

    if (%AttachmentData) {
        $AttachmentData{Content}     = ${ $AttachmentData{ContentRef} };
        $AttachmentData{Filename}    = $AttachmentData{FileName};
        $AttachmentData{ContentType} = $AttachmentData{Preferences}->{DataType};
        return $Self->{LayoutObject}->Attachment(%AttachmentData);

    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "No such attachment in directory index ($AttachmentDirectoryID)! ",
        );
        return $Self->{LayoutObject}->ErrorScreen();
    }
}

1;
