# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMConfigItemZoomTabImages;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use File::Copy;
use File::Path qw(mkpath);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    $Self->{Config} = $ConfigObject->Get("ITSMConfigItem::Frontend::$Self->{Action}");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $LinkObject       = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LogObject        = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject       = $Kernel::OM->Get('Kernel::System::Main');
    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $SessionObject    = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $TimeObject       = $Kernel::OM->Get('Kernel::System::Time');

    # get params
    my $ConfigItemID = $ParamObject->GetParam( Param => 'ConfigItemID' ) || 0;
    my $ImageID      = $ParamObject->GetParam( Param => 'ImageID' )      || '';
    my $ImageType    = $ParamObject->GetParam( Param => 'ImageType' )    || '';
    my $TabIndex     = $ParamObject->GetParam( Param => 'TabIndex' )     || '';

    # check needed stuff
    if ( !$ConfigItemID ) {
        return $LayoutObject->ErrorScreen(
            Message => "No ConfigItemID is given!",
            Comment => 'Please contact the admin.',
        );
    }

    # check for access rights
    my $HasAccess = $ConfigItemObject->Permission(
        Scope  => 'Item',
        ItemID => $ConfigItemID,
        UserID => $Self->{UserID},
        Type   => $Self->{Config}->{Permission},
    );

    if ( !$HasAccess ) {

        # error page
        return $LayoutObject->ErrorScreen(
            Message => 'Can\'t show item, no access rights for ConfigItem are given!',
            Comment => 'Please contact the admin.',
        );
    }

    my $FileUploaded = $ParamObject->GetParam( Param => 'FileUploaded' ) || 0;
    if ( $Self->{Subaction} eq 'StoreNew' ) {
        $FileUploaded = 1;
    }

    $LayoutObject->Block(
        Name => 'TabContent',
        Data => {
            ConfigItemID => $ConfigItemID,
            ImageID      => $ImageID,
            Test         => $ImageID,
            FileUploaded => $FileUploaded,
            TabIndex     => $TabIndex,
        },
    );

    # get file and path info
    my $Home       = $ConfigObject->Get('Home');
    my $Path       = $Self->{Config}->{ImageSavePath};
    my $Directory  = $Home . $Path . $ConfigItemID;
    my $ImageTypes = $Self->{Config}->{ImageTypes};

    if ( !( -e ($Home . $Path) ) ) {
        if ( !mkpath( $Home . $Path, 0, oct(755) ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Can't create directory '$Home.$Path'!",
            );
            return;
        }
    }

    if ( !( -e $Directory ) ) {
        if ( !mkpath( $Directory, 0, oct(755) ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Can't create directory '$Directory'!",
            );
            return;
        }
    }

    ################################################################
    # store new image
    ################################################################
    if ( $Self->{Subaction} eq 'StoreNew' ) {

        # get submit attachment
        my %UploadStuff = $ParamObject->GetUploadAll(
            Param  => 'FileUpload',
            Source => 'String'
        );

        my $Filename = '';

        if ( -e $Directory && $UploadStuff{Filename} =~ m/\.($ImageTypes)$/i ) {
            my $FileType = $1;
            my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay )
                = $TimeObject->SystemTime2Date(
                SystemTime => $TimeObject->SystemTime(),
                );
            $Filename = $Year . $Month . $Day . $Hour . $Min . $Sec;

            my $FileLocation = $MainObject->FileWrite(
                Directory => $Directory,
                Filename  => $Filename . "." . $FileType,
                Content   => \$UploadStuff{Content},
            );
        }

        # reload tab
        my $URL = 'Action=AgentITSMConfigItemZoom'
                . ';ConfigItemID=' . $ConfigItemID
                . ';ImageID=' . $Filename
                . ';FileUploaded=' . $FileUploaded
                . ';SelectedTab=' . $TabIndex;
        return $LayoutObject->Redirect( OP => $URL );
    }
    ################################################################
    # show image (AJAX reload)
    ################################################################
    elsif ( $Self->{Subaction} eq 'ViewImage' ) {

        my %TmpHash;

        return if !$ImageID && !$ImageType;
        return if ( $ImageType !~ m/^(?:$ImageTypes)$/i );

        $TmpHash{Filename} = $ImageID . "." . $ImageType;

        my $Content = $MainObject->FileRead(
            Location => $Directory . "/" . $TmpHash{Filename},
            Mode     => 'binmode',
        );
        $TmpHash{Content}     = ${$Content};
        $TmpHash{ContentType} = 'image/' . $ImageType . '; name="' . $TmpHash{Filename} . '"';
        $TmpHash{Type}        = 'inline';

        my $Image = $LayoutObject->Attachment(%TmpHash);
        return $Image;

    }
    ################################################################
    # set new image text
    ################################################################
    elsif ( $Self->{Subaction} eq 'SetImageText' ) {
        my $ImageNote = $ParamObject->GetParam( Param => 'ImageNote' ) || '';

        my $FileLocation = $MainObject->FileWrite(
            Directory => $Directory,
            Filename  => $ImageID . ".txt",
            Content   => \$ImageNote,
            Mode      => 'utf8',
        );

        # reload tab
        my $URL = 'Action=AgentITSMConfigItemZoom'
                . ';ConfigItemID=' . $ConfigItemID
                . ';FileUploaded=' . $FileUploaded
                . ';SelectedTab=' . $TabIndex;
        return $LayoutObject->Redirect( OP => $URL );

    }
    ################################################################
    # delete image
    ################################################################
    elsif ( $Self->{Subaction} eq 'ImageDelete' ) {

        if ( -e ($Directory . "/" . $ImageID . "." . $ImageType) ) {
            my $OK = $MainObject->FileDelete(
                Directory => $Directory,
                Filename  => $ImageID . "." . $ImageType,
            );
        }

        if ( -e ($Directory . "/" . $ImageID . ".txt") ) {
            my $OK = $MainObject->FileDelete(
                Directory => $Directory,
                Filename  => $ImageID . ".txt",
            );
        }

        # redirect url
        my $URL = 'Action=AgentITSMConfigItemZoom'
                . ';ConfigItemID=' . $ConfigItemID
                . ';SelectedTab=' . $TabIndex;
        return $LayoutObject->Redirect( OP => $URL );
    }

    # show images
    if ( -e $Directory ) {

        # get all source files
        opendir( DIR, $Directory );
        my @Files = grep( { !/^(?:.|..)$/g } readdir(DIR) );
        closedir(DIR);

        for my $File (@Files) {

            my $CurrentImageID   = '';
            my $CurrentImageType = '';
            if ( $File =~ m/(.*?)\.($ImageTypes)$/i ) {
                $CurrentImageID   = $1;
                $CurrentImageType = $2;
            } else {
                next;
            }

            # get text
            my $Text;
            if ( -e ($Directory . "/" . $CurrentImageID . ".txt") ) {
                my $Content = $MainObject->FileRead(
                    Location => $Directory . "/" . $CurrentImageID . ".txt",
                    Mode     => 'utf8',
                );

                $Text = ${$Content};
            }

            $LayoutObject->Block(
                Name => 'Image',
                Data => {
                    CurrentImageID   => $CurrentImageID,
                    CurrentImageType => $CurrentImageType,
                    ConfigItemID     => $ConfigItemID,
                    Text             => $Text,
                },
            );
        }

    }

    # store last screen
    if ( $Self->{CallingAction} ) {
        $Self->{RequestedURL} =~ s/DirectLinkAnchor=.+?(;|$)//;
        $Self->{RequestedURL} =~ s/CallingAction=.+?(;|$)//;
        $Self->{RequestedURL} =~ s/(^|;|&)Action=.+?(;|$)//;
        $Self->{RequestedURL}
            = "Action="
            . $Self->{CallingAction} . ";"
            . $Self->{RequestedURL} . "#"
            . $Self->{DirectLinkAnchor};
    }

    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenView',
        Value     => $Self->{RequestedURL},
    );

    my $UserLanguage = $LayoutObject->{UserLanguage};

    # start template output
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentITSMConfigItemZoomTabImages',
        Data         => {
            UserLanguage => $UserLanguage,
        },
    );

    # add footer
    $Output .= $LayoutObject->Footer( Type => 'TicketZoomTab' );

    return $Output;
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
