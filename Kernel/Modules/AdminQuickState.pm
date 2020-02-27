# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminQuickState;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Encode',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::QuickState',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::Valid',
    'Kernel::System::Web::Request',
    'Kernel::System::Web::UploadCache',
    'Kernel::System::YAML'
);

use MIME::Base64;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $QuickStateObject  = $Kernel::OM->Get('Kernel::System::QuickState');
    my $YAMLObject        = $Kernel::OM->Get('Kernel::System::YAML');
    my $TimeObject        = $Kernel::OM->Get('Kernel::System::Time');
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $EncodeObject      = $Kernel::OM->Get('Kernel::System::Encode');

    my $LanguageObject    = $LayoutObject->{LanguageObject};

    $Param{FormID} = $ParamObject->GetParam( Param => 'FormID' );
    if ( !$Param{FormID} ) {
        $Param{FormID} = $UploadCacheObject->FormIDCreate();
    }
    $Self->{FormID} = $Param{FormID};

    # ------------------------------------------------------------ #
    # delete
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Delete' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';

        # get ID
        my $ID = $ParamObject->GetParam( Param => 'ID' )
            || $ParamObject->GetParam( Param => 'QuickStateID' )
            || '';

        if ( !$ID ) {
            return $LayoutObject->ErrorScreen(
                Message => "No ID is given!",
            );
        }

        my $Success = $QuickStateObject->QuickStateDelete(
            ID => $ID,
        );

        if ( !$Success ) {
            $Note .= $LayoutObject->Notify( Priority => 'Error' );
        } else {
            $Note .= $LayoutObject->Notify(
                Info => $LanguageObject->Translate("Quick State deleted!")
            );
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note;
        $Output .= $Self->_Overview();
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # load inline attachments
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'LoadInline' ) {

        my %GetParam;
        # manage parameters
        for ( qw(FileID QuickStateID) ) {
            $GetParam{$_} = $ParamObject->GetParam( Param => $_) || '';
            if ( !$GetParam{$_} ) {
                return $LayoutObject->FatalError( Message => "Need $_!" );
            }
        }

        # get attachments
        my %File = $QuickStateObject->QuickStateAttachmentGet(
            %GetParam
        );

        if (%File) {
            return $LayoutObject->Attachment(
                Filename    => $File{Filename},
                ContentType => $File{ContentType},
                Content     => $File{Content},
            );
        }
        else {
            $LogObject->Log(
                Message  => "No such attachment ($GetParam{FileID})! May be an attack!!!",
                Priority => 'error',
            );
            return $LayoutObject->ErrorScreen();
        }
    }

    # ------------------------------------------------------------ #
    # import
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Import' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my %Upload = $ParamObject->GetUploadAll(
            Param  => 'FileUpload',
            Source => 'string',
        );

        my $ImportData = $YAMLObject->Load(
            Data => $Upload{Content}
        );

        my %QuickState = $QuickStateObject->QuickStateGet(
            %{$ImportData}
        );

        my $Success;
        my $Note      = '';
        my $Overwrite = $ParamObject->GetParam( Param => 'OverwriteExistingEntities' ) || '';

        if (
            %QuickState
            && $Overwrite
        ) {
            my %Data = (
                %QuickState,
                %{$ImportData}
            );

            if ( $Data{Config} ) {
                $Data{Config} = $YAMLObject->Dump(
                    Data => $Data{Config}
                );
            }

            $Success = $QuickStateObject->QuickStateUpdate(
                %Data,
                UserID => $Self->{UserID}
            );
            if ( $Success ) {
                $Note .= $LayoutObject->Notify(
                    Info => $LanguageObject->Translate("Quick State imported!")
                );

                if (
                    $ImportData->{Config}
                    && $ImportData->{Config}->{Body}
                    && $ImportData->{Attachments}
                ) {
                    $QuickStateObject->QuickStateDelete(
                        QuickStateID => $Data{ID}
                    );

                    for my $Attachment ( @{$ImportData->{Attachments}} ) {
                        $Attachment->{Content} = decode_base64($Attachment->{Content});

                        $QuickStateObject->QuickStateWriteAttachment(
                            %{$Attachment},
                            QuickStateID => $Data{ID},
                            UserID       => $Self->{UserID}
                        );
                    }
                }
            }
        }
        elsif (
            %QuickState
            && !$Overwrite
        ) {
            $Note .= $LayoutObject->Notify(
                Info => $LanguageObject->Translate("Quick State already exists! \(Overwrite not used\)")
            );
            $Success = 1;
        }

        elsif ( !%QuickState ) {

            my $DataConfig = '';
            if ( $ImportData->{Config} ) {
                $DataConfig = $YAMLObject->Dump(
                    Data => $ImportData->{Config}
                );
            }

            my $ID = $QuickStateObject->QuickStateAdd(
                %{$ImportData},
                Config => $DataConfig,
                UserID => $Self->{UserID}
            );

            if ( $ID ) {
                $Success = 1;
                $Note .= $LayoutObject->Notify(
                    Info => $LanguageObject->Translate("Quick State imported!")
                );

                if (
                    $ImportData->{Config}
                    && $ImportData->{Config}->{Body}
                    && $ImportData->{Attachments}
                ) {
                    for my $Attachment ( @{$ImportData->{Attachments}} ) {
                        $Attachment->{Content} = decode_base64($Attachment->{Content});

                        $QuickStateObject->QuickStateWriteAttachment(
                            %{$Attachment},
                            QuickStateID => $ID,
                            UserID       => $Self->{UserID}
                        );
                    }
                }
            }
        }

        if ( !$Success ) {
            my $Message = 'Quick state not be imported due to an unknown error,'
                        . ' please check KIX logs for more information';
            return $LayoutObject->ErrorScreen(
                Message => $Message,
            );
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note;
        $Output .= $Self->_Overview();
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # export
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Export' ) {

        # get ID
        my $ID = $ParamObject->GetParam( Param => 'ID' )
            || $ParamObject->GetParam( Param => 'QuickStateID' )
            || '';
        if ( !$ID ) {
            return $LayoutObject->ErrorScreen(
                Message => "No ID is given",
            );
        }

        # get conversation guide
        my %Data = $QuickStateObject->QuickStateGet(
            ID => $ID
        );

        if ( !%Data ) {
            return $LayoutObject->ErrorScreen(
                Message => "No quick state found for ID " . $ID,
            );
        }

        my @Attachments = $QuickStateObject->QuickStateAttachmentList(
            QuickStateID => $ID
        );

        if ( scalar(@Attachments) ) {
            for my $Attachment ( @Attachments ) {
                $EncodeObject->EncodeOutput( \$Attachment->{Content} );
                $Attachment->{Content} = encode_base64( $Attachment->{Content} );
                push(@{$Data{Attachments}}, $Attachment );
            }
        }

        my $ExportData = $YAMLObject->Dump(
            Data => \%Data
        );

        my $Filename = 'Export_QuickState_'
            . $Data{Name}
            . '_'#
            . $TimeObject->SystemTime();

        # cleanup name for saving
        $Filename =~ s{[^a-zA-Z0-9-_]}{_}xmsg;
        $Filename .= '.yml';

        # send the result to the browser
        return $LayoutObject->Attachment(
            ContentType => 'text/html; charset=' . $LayoutObject->{Charset},
            Content     => $ExportData,
            Type        => 'attachment',
            Filename    => $Filename,
            NoCache     => 1,
        );
    }

    # -----------------------------------------------------------
    # add
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'Add' ) {
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_Mask(
            %Param,
            Subaction => 'Add'
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # add action
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'AddAction' ) {
        my $Note = '';
        my %GetParam;
        my %Errors;
        my @AttachmentData;

        for my $Needed ( qw(Name ValidID StateID) ) {
            $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid'} = 'ServerError';
            }
        }

        $GetParam{UsedArticle} = $ParamObject->GetParam( Param => 'UsedArticle' ) || 0;
        $GetParam{UsedPending} = $ParamObject->GetParam( Param => 'UsedPending' ) || 0;

        if ( $GetParam{UsedArticle} ) {
            for my $Needed ( qw(Subject Body ArticleTypeID) ) {
                $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
                if ( !$GetParam{$Needed} ) {
                    $Errors{ $Needed . 'Invalid'} = 'ServerError';
                }
            }

            # get pre loaded attachment
            @AttachmentData = $UploadCacheObject->FormIDGetAllFilesData(
                FormID => $Self->{FormID},
            );

            my $MimeType = 'text/plain';
            if ( $LayoutObject->{BrowserRichText} ) {
                $MimeType = 'text/html';

                # remove unused inline images
                my @NewAttachmentData;
                ATTACHMENT:
                for my $Attachment (@AttachmentData) {
                    my $ContentID = $Attachment->{ContentID};
                    if (
                        $ContentID
                        && ( $Attachment->{ContentType} =~ /image/i )
                        && ( $Attachment->{Disposition} eq 'inline' )
                    ) {
                        my $ContentIDHTMLQuote = $LayoutObject->Ascii2Html(
                            Text => $ContentID,
                        );

                        my $ContentIDLinkEncode = $LayoutObject->LinkEncode($ContentID);
                        $GetParam{Body} =~ s/(ContentID=)$ContentIDLinkEncode/$1$ContentID/g;

                        # ignore attachment if not linked in body
                        next ATTACHMENT
                            if $GetParam{Body} !~ m/(?:\Q$ContentIDHTMLQuote\E|\Q$ContentID\E)/i;
                    }

                    # remember inline images and normal attachments
                    push @NewAttachmentData, \%{$Attachment};
                }
                @AttachmentData = @NewAttachmentData;

                # verify html document
                $GetParam{Body} = $LayoutObject->RichTextDocumentComplete(
                    String => $GetParam{Body},
                );
            }

            $GetParam{PlainBody} = $GetParam{Body};

            if ( $LayoutObject->{BrowserRichText} ) {
                $GetParam{PlainBody} = $LayoutObject->RichText2Ascii( String => $GetParam{Body} );
            }
        }

        if ( $GetParam{UsedPending} ) {
            for my $Needed ( qw(PendingTime PendingFormatID) ) {
                $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            }
        }

        # check if a quick state exists with this name
        my $NameExists = $QuickStateObject->NameExistsCheck(
            Name => $GetParam{Name}
        );

        if ($NameExists) {
            $Errors{NameExists}    = 1;
            $Errors{'NameInvalid'} = 'ServerError';
        }

        if ( !%Errors ) {
            my $QuickStateConfig = '';
            my %ConfigData;
            if ( $GetParam{UsedArticle} ) {
                for my $Key ( qw(UsedArticle Subject Body ArticleTypeID) ) {
                    $ConfigData{$Key} = $GetParam{$Key};
                }
            }

            if ( $GetParam{UsedPending} ) {
                $ConfigData{UsedPending} = 1;

                if ( $GetParam{PendingTime} eq '' ) {
                    $ConfigData{PendingTime} = 1;
                }
                else {
                    $ConfigData{PendingTime} = $GetParam{PendingTime};
                }

                if ( $GetParam{PendingFormatID} eq '' ) {
                    $ConfigData{PendingFormatID} = 'Days';
                }
                else {
                    $ConfigData{PendingFormatID} = $GetParam{PendingFormatID};
                }
            }

            if ( %ConfigData ) {
                $QuickStateConfig = $YAMLObject->Dump(
                    Data => \%ConfigData
                );
            }

            my $QuickStateID = $QuickStateObject->QuickStateAdd(
                %GetParam,
                Config  => $QuickStateConfig || '',
                UserID  => $Self->{UserID}
            );

            if ( $QuickStateID ) {
                # write attachments
                if ( $GetParam{UsedArticle}
                    && scalar(@AttachmentData)
                ) {
                    for my $Attachment (@AttachmentData) {
                        $QuickStateObject->QuickStateWriteAttachment(
                            %{$Attachment},
                            QuickStateID => $QuickStateID,
                            UserID       => $Self->{UserID},
                        );
                    }

                    # remove pre submited attachments
                    $UploadCacheObject->FormIDRemove( FormID => $Self->{FormID} );
                }

                # get quick state data and show screen again
                if ( !$Note ) {
                    my $Output = $LayoutObject->Header();
                    $Output .= $LayoutObject->NavigationBar();
                    $Output .= $Note;
                    $Output .= $LayoutObject->Notify(
                        Info => $LanguageObject->Translate("Quick State added!") );
                    $Output .= $Self->_Overview();
                    $Output .= $LayoutObject->Footer();

                    return $Output;
                }
            } else {
                $Note .= $LayoutObject->Notify( Priority => 'Error' );
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note;
        $Output .= $Self->_Mask(
            %Param,
            %GetParam,
            %Errors,
            Subaction => 'Add'
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # change
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'Change' ) {
        my $ID = $ParamObject->GetParam( Param => 'ID' );

        my %Data = $QuickStateObject->QuickStateGet(
            ID => $ID
        );

        if ( $Data{Config} ) {
            for my $Key ( sort keys %{$Data{Config}} ) {
                $Data{$Key} = $Data{Config}->{$Key};
            }

            my %AttachmentIndex = $QuickStateObject->QuickStateAttachmentIndex(
                QuickStateID => $ID
            );

            if ( %AttachmentIndex ) {
                my $Link = $LayoutObject->{Baselink}
                    . 'Action='
                    . $Self->{Action}
                    . ';Subaction=LoadInline;'
                    . 'QuickStateID='
                    . $ID
                    . ';FileID=';

                for my $Index ( sort keys %AttachmentIndex ) {
                    next if $AttachmentIndex{$Index}->{Disposition} ne 'inline';
                    my $ContentID = $AttachmentIndex{$Index}->{ContentID};
                    my $NewLink   = $Link . $AttachmentIndex{$Index}->{FileID};
                    $Data{Body} =~ s{(cid:$ContentID)}{$NewLink}gxms;
                }
            }

        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_Mask(
            %Param,
            %Data,
            Subaction => 'Change'
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # change action
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {
        my $Note = '';
        my %GetParam;
        my %Errors;
        my @AttachmentData;

        for my $Needed ( qw(ID Name ValidID StateID) ) {
            $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid'} = 'ServerError';
            }
        }

        $GetParam{UsedArticle} = $ParamObject->GetParam( Param => 'UsedArticle' ) || 0;
        $GetParam{UsedPending} = $ParamObject->GetParam( Param => 'UsedPending' ) || 0;

        if ( $GetParam{UsedArticle} ) {
            for my $Needed ( qw(Subject Body ArticleTypeID) ) {
                $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
                if ( !$GetParam{$Needed} ) {
                    $Errors{ $Needed . 'Invalid'} = 'ServerError';
                }
            }

            # get pre loaded attachment
            @AttachmentData = $UploadCacheObject->FormIDGetAllFilesData(
                FormID => $Self->{FormID},
            );

            my $MimeType = 'text/plain';
            if ( $LayoutObject->{BrowserRichText} ) {
                $MimeType = 'text/html';
                # remove unused inline images
                my @NewAttachmentData;
                ATTACHMENT:
                for my $Attachment (@AttachmentData) {
                    my $ContentID = $Attachment->{ContentID};
                    if (
                        $ContentID
                        && ( $Attachment->{ContentType} =~ /image/i )
                        && ( $Attachment->{Disposition} eq 'inline' )
                    ) {
                        my $ContentIDHTMLQuote = $LayoutObject->Ascii2Html(
                            Text => $ContentID,
                        );

                        my $ContentIDLinkEncode = $LayoutObject->LinkEncode($ContentID);
                        $GetParam{Body} =~ s/(ContentID=)$ContentIDLinkEncode/$1$ContentID/g;

                        # ignore attachment if not linked in body
                        next ATTACHMENT if $GetParam{Body} !~ m/(?:\Q$ContentIDHTMLQuote\E|\Q$ContentID\E)/i;
                    }

                    # remember inline images and normal attachments
                    push( @NewAttachmentData, \%{$Attachment});
                }
                @AttachmentData = @NewAttachmentData;

                # verify html document
                $GetParam{Body} = $LayoutObject->RichTextDocumentComplete(
                    String => $GetParam{Body},
                );
            }
        }

        if ( $GetParam{UsedPending} ) {
            for my $Needed ( qw(PendingTime PendingFormatID) ) {
                $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            }
        }

        # check if a quick state exists with this name
        my $NameExists = $QuickStateObject->NameExistsCheck(
            Name => $GetParam{Name},
            ID   => $GetParam{ID}
        );

        if ($NameExists) {
            $Errors{NameExists}    = 1;
            $Errors{'NameInvalid'} = 'ServerError';
        }

        if ( !%Errors ) {
            my $QuickStateConfig = '';
            my %ConfigData;

            if ( $GetParam{UsedArticle} ) {
                for my $Key ( qw(UsedArticle Subject Body ArticleTypeID) ) {
                    $ConfigData{$Key} = $GetParam{$Key};
                }

                #cleanup attachment links
                my %AttachmentIndex = $QuickStateObject->QuickStateAttachmentIndex(
                    QuickStateID => $GetParam{ID}
                );

                if ( %AttachmentIndex ) {
                    my $Link = $LayoutObject->{Baselink}
                    . 'Action='
                    . $Self->{Action}
                    . ';Subaction=LoadInline;'
                    . 'QuickStateID='
                    . $GetParam{ID}
                    . ';FileID=';

                    for my $Index ( sort keys %AttachmentIndex ) {
                        next if $AttachmentIndex{$Index}->{Disposition} ne 'inline';
                        my $ContentID = $AttachmentIndex{$Index}->{ContentID};
                        my $NewLink   = $Link . $AttachmentIndex{$Index}->{FileID};
                        if ( $ConfigData{Body} =~ /\Q$NewLink\E/ ) {
                            $ConfigData{Body} =~ s{\Q$NewLink\E}{cid:$ContentID}gxms;
                        } else {
                            $QuickStateObject->QuickStateAttachmentDelete(
                                QuickStateID => $GetParam{ID},
                                FileID       => $AttachmentIndex{$Index}->{FileID}
                            );
                        }
                    }
                }
            }

            if ( $GetParam{UsedPending} ) {
                $ConfigData{UsedPending} = 1;

                if ( $GetParam{PendingTime} eq '' ) {
                    $ConfigData{PendingTime} = 1;
                }
                else {
                    $ConfigData{PendingTime} = $GetParam{PendingTime};
                }

                if ( $GetParam{PendingFormatID} eq '' ) {
                    $ConfigData{PendingFormatID} = 'Days';
                }
                else {
                    $ConfigData{PendingFormatID} = $GetParam{PendingFormatID};
                }
            }

            if ( %ConfigData ) {
                $QuickStateConfig = $YAMLObject->Dump(
                    Data => \%ConfigData
                );
            }

            my $Success = $QuickStateObject->QuickStateUpdate(
                %GetParam,
                Config  => $QuickStateConfig || '',
                UserID  => $Self->{UserID}
            );

            if ( $Success ) {
                # write attachments
                if ( $GetParam{UsedArticle}
                    && scalar(@AttachmentData)
                ) {
                    for my $Attachment (@AttachmentData) {
                        $QuickStateObject->QuickStateWriteAttachment(
                            %{$Attachment},
                            QuickStateID => $GetParam{ID},
                            UserID       => $Self->{UserID},
                        );
                    }

                    # remove pre submited attachments
                    $UploadCacheObject->FormIDRemove( FormID => $Self->{FormID} );
                }

                # get quick state data and show screen again
                if ( !$Note ) {
                    my $Output = $LayoutObject->Header();
                    $Output .= $LayoutObject->NavigationBar();
                    $Output .= $Note;
                    $Output .= $LayoutObject->Notify(
                        Info => $LanguageObject->Translate("Quick State updated!")
                    );
                    $Output .= $Self->_Overview();
                    $Output .= $LayoutObject->Footer();

                    return $Output;
                }
            } else {
                $Note .= $LayoutObject->Notify( Priority => 'Error' );
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note;
        $Output .= $Self->_Mask(
            %Param,
            %GetParam,
            %Errors,
            Subaction => 'Change'
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # overview
    # -----------------------------------------------------------

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $Self->_Overview(
        %Param
    );
    $Output .= $LayoutObject->Footer();
    return $Output;

}

sub _Mask {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $QuickStateObject = $Kernel::OM->Get('Kernel::System::QuickState');
    my $ValidObject      = $Kernel::OM->Get('Kernel::System::Valid');
    my $StateObject      = $Kernel::OM->Get('Kernel::System::State');
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject     = $Kernel::OM->Get('Kernel::System::Ticket');
    my $JSONObject       = $Kernel::OM->Get('Kernel::System::JSON');

    my $HideConfig = $ConfigObject->Get('HidePendingTimeInput') || undef;
    my $Config     = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");
    my %ValidList  = $ValidObject->ValidList();
    my $HideStates = '';

    my %StateTypeList = $StateObject->StateTypeList(
        UserID => 1,
    );

    my %StateList = $StateObject->StateList(
        Valid  => 1,
        UserID => 1,
    );

    my %ArticleTypeList = $TicketObject->ArticleTypeList(
        Result => 'HASH',
    );

    my %ArticleTypeListReverse = reverse(%ArticleTypeList);
    my $DefaultArticleType     = $Config->{DefaultArticleType} || 'note-internal';
    my $DefaultArticleTypeID   = '';

    if ( $ArticleTypeListReverse{$DefaultArticleType} ) {
        $DefaultArticleTypeID = $ArticleTypeListReverse{$DefaultArticleType};
    }

    if ( !defined $Param{StateIDInvalid} ) {
        $Param{StateIDInvalid} = '';
    }

    if ( !defined $Param{ValidIDInvalid} ) {
        $Param{ValidIDInvalid} = '';
    }

    $Param{StateIDOption} = $LayoutObject->BuildSelection(
        Name         => 'StateID',
        Data         => \%StateList,
        Translation  => 1,
        PossibleNone => 1,
        SelectedID   => $Param{StateID} || '',
        Class        => 'W33pc Modernize Validate_Required ' . $Param{StateIDInvalid}
    );

    $Param{ValidIDOption} = $LayoutObject->BuildSelection(
        Name         => 'ValidID',
        Data         => \%ValidList,
        Translation  => 1,
        SelectedID   => $Param{ValidID} || '',
        Class        => 'W33pc Modernize Validate_Required ' . $Param{ValidIDInvalid}
    );

    $Param{ArticleTypeIDOption} = $LayoutObject->BuildSelection(
        Name         => 'ArticleTypeID',
        Data         => \%ArticleTypeList,
        Translation  => 1,
        SelectedID   => $Param{ArticleTypeID} || $DefaultArticleTypeID || '',
        Class        => 'W33pc Modernize'
    );

    $Param{PendingFormatIDOption} = $LayoutObject->BuildSelection(
        Name         => 'PendingFormatID',
        Data         => ['Days', 'Hours', 'Minutes'],
        Translation  => 1,
        SelectedID   => $Param{PendingFormatID} || 'Days',
        Class        => 'W33pc Modernize'
    );

    if ( ref $HideConfig eq 'HASH'
         && scalar(@{ $HideConfig->{StateTypes} })
    ) {
        my %Result;
        for my $StateID ( sort keys %StateList ) {

            # get state data
            my %State = $StateObject->StateGet(
                ID => $StateID
            );

            $Result{$StateID} = 0;
            # check if PendingUntil input field should be shown for this state type
            for my $ConfiguredStateType ( @{ $HideConfig->{StateTypes} } ) {
                if ( $StateTypeList{$State{TypeID}} eq $ConfiguredStateType ) {
                    $Result{$StateID} = 1;
                    last;
                }
            }
        }
        if ( %Result ) {
            $HideStates = $JSONObject->Encode(
                Data     => \%Result,
            );
        }
    }

    if ( !$Param{UsedPending} ) {
        $Param{PendingTime} = 1;
    }

    $Param{UsedArticleClass}   = 'Hidden';
    $Param{UsedArticleChecked} = '';
    if ( $Param{UsedArticle} ) {
        $Param{UsedArticleChecked} = 'checked="checked"';
        $Param{UsedArticleClass}   = '';
        $Param{BodyRequired}       = 'Validate_Required';
        $Param{SubjectRequired}    = 'Validate_Required';
    }

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview');

    $LayoutObject->Block(
        Name => 'OverviewEdit',
        Data => {
            %Param,
            Subaction  => $Param{Subaction} || $Self->{Subaction},
            HideStates => $HideStates
        }
    );

    # add rich text editor
    if ( $LayoutObject->{BrowserRichText} ) {

        # use height/width defined for this screen
        $Param{RichTextHeight} = $Config->{RichTextHeight} || 0;
        $Param{RichTextWidth}  = $Config->{RichTextWidth}  || 0;

        $LayoutObject->Block(
            Name => 'RichText',
            Data => \%Param,
        );
    }

    # show appropriate messages for ServerError
    if (
        defined $Param{NameExists}
        && $Param{NameExists}
    ) {
        $LayoutObject->Block( Name => 'ExistNameServerError' );
    }
    else {
        $LayoutObject->Block( Name => 'NameServerError' );
    }

    return $LayoutObject->Output(
        TemplateFile => 'AdminQuickState',
        Data         => \%Param,
    );
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $QuickStateObject = $Kernel::OM->Get('Kernel::System::QuickState');

    $Param{Search} = $ParamObject->GetParam( Param => 'Search' ) || '*';

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block(
        Name => 'ActionSearch',
        Data => {
            Search => $Param{Search}
        }
    );
    $LayoutObject->Block( Name => 'ActionAdd' );
    $LayoutObject->Block( Name => 'ActionImport' );

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    my %List = $QuickStateObject->QuickStateSearch(
        Search => $Param{Search}. '*',
        Valid  => 0,
    );

    # print the list of quick states
    $Self->_PagingListShow(
        QuickState => \%List,
        Total      => scalar keys %List,
        Search     => $Param{Search},
    );

    return $LayoutObject->Output(
        TemplateFile => 'AdminQuickState',
        Data         => \%Param,
    );
}

sub _PagingListShow {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ConfigObject     = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject      = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $QuickStateObject = $Kernel::OM->Get('Kernel::System::QuickState');
    my $ValidObject      = $Kernel::OM->Get('Kernel::System::Valid');

    # check start option, if higher than fields available, set
    # it to the last field page
    my $StartHit = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

    # get personal page shown count
    my $PageShownPreferencesKey = 'AdminQuickStateOverviewPageShown';
    my $PageShown               = $Self->{$PageShownPreferencesKey} || 35;
    my $Group                   = 'QuickStateOverviewPageShown';

    # get data selection
    my %Data;
    my $Config = $ConfigObject->Get('PreferencesGroups');
    if (
        $Config
        && $Config->{$Group}
        && $Config->{$Group}->{Data}
    ) {
        %Data = %{ $Config->{$Group}->{Data} };
    }

    my $Session = '';
    if ($Self->{SessionID}
        && !$ConfigObject->Get('SessionUseCookie')
    ) {
        $Session = $ConfigObject->Get('SessionName') . '=' . $Self->{SessionID} . ';';
    }

    # calculate max. shown per page
    if ( $StartHit > $Param{Total} ) {
        my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
        $StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
    }
    # build nav bar
    my $Limit = $Param{Limit} || 20_000;
    my %PageNav = $LayoutObject->PageNavBar(
        Limit     => $Limit,
        StartHit  => $StartHit,
        PageShown => $PageShown,
        AllHits   => $Param{Total} || 0,
        Action    => 'Action=' . $LayoutObject->{Action},
        Link      => "Search=$Param{Search};",
        IDPrefix  => $LayoutObject->{Action},
    );

    # build shown dynamic fields per page
    $Param{RequestedURL}    = "Action=$Self->{Action}";
    $Param{Group}           = $Group;
    $Param{PreferencesKey}  = $PageShownPreferencesKey;
    $Param{PageShownString} = $LayoutObject->BuildSelection(
        Name        => $PageShownPreferencesKey,
        SelectedID  => $PageShown,
        Translation => 0,
        Data        => \%Data,
    );

    if (%PageNav) {
        $LayoutObject->Block(
            Name => 'OverviewNavBarPageNavBar',
            Data => \%PageNav,
        );

        $LayoutObject->Block(
            Name => 'ContextSettings',
            Data => { %PageNav, %Param, },
        );
    }

    my $MaxFieldOrder = 0;

    # check if at least 1 conversation guide is registered in the system
    if ( $Param{Total} ) {

        # get conversation guide details
        my $Counter = 0;
        my %List = %{$Param{QuickState}};

         # get valid list
        my %ValidList = $ValidObject->ValidList();
        for my $ListKey ( sort { $List{$a} cmp $List{$b} } keys %List ) {
            $Counter++;
            if ( $Counter >= $StartHit && $Counter < ( $PageShown + $StartHit ) ) {
                my %StateData = $QuickStateObject->QuickStateGet(
                    ID       => $ListKey,
                    MetaOnly => 1
                );

                if ( $ValidList{ $StateData{ValidID} } ne 'valid' ) {
                    $StateData{Invalid} = 'Invalid';
                }

                $LayoutObject->Block(
                    Name => 'OverviewResultRow',
                    Data => {
                        %StateData,
                        Valid   => $ValidList{ $StateData{ValidID} },
                        Session => $Session
                    },
                );
            }
        }
    }

    return;
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
