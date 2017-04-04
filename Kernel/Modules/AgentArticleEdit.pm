# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --


package Kernel::Modules::AgentArticleEdit;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);
use HTML::Entities;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $HTMLUtilsObject    = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $UploadCacheObject  = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get module config
    $Self->{Config} = $ConfigObject->Get('Ticket::Frontend::AgentArticleEdit');

    # get or generate form id
    $Self->{FormID} = $ParamObject->GetParam( Param => 'FormID' );
    if ( !$Self->{FormID} ) {
        $Self->{FormID} = $UploadCacheObject->FormIDCreate();
    }

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => 'Article',
        FieldFilter => $Self->{Config}->{DynamicField} || {},
    );

    my %GetParam;

    # check needed stuff
    for (qw(TicketID ArticleID)) {
        $GetParam{$_} = $ParamObject->GetParam( Param => $_ ) || '';
        if ( !$GetParam{$_} ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate('Need %s in AgentArticleEdit!', $_ ),
                Comment => Translatable('Please contact your admin.'),
            );
        }
    }

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Self->{Config}->{Permission},
        TicketID => $GetParam{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        return $LayoutObject->NoPermission(
            Message    => "You need $Self->{Config}->{Permission} permissions!",
            WithHeader => 'yes',
        );
    }

    # get ACL restrictions
    $TicketObject->TicketAcl(
        Data          => '-',
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();

    # check if ACL resctictions if exist
    if ( IsHashRefWithData( \%AclAction ) ) {

        # show error screen if ACL prohibits this action
        if ( defined $AclAction{ $Self->{Action} } && $AclAction{ $Self->{Action} } eq '0' ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }

    # ACL compatibility translation
    my %ACLCompatGetParam;

    # get ticket and article data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $GetParam{TicketID},
        DynamicFields => 1,
    );
    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $GetParam{ArticleID},
        DynamicFields => 1,
    );

    $Article{Count} = $ParamObject->GetParam( Param => 'Count' );

    # get accounted time for this article
    $Article{TimeUnits} = $TicketObject->ArticleAccountedTimeGet(
        ArticleID => $Article{ArticleID},
    );
    if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
        $Param{NeedAccountedTime} = 'Validate_Required';
    }

    # prevent permission checks for wrong ticket number
    if ( $GetParam{TicketID} != $Article{TicketID} ) {
        return $LayoutObject->NoPermission(
            Message =>
                "Sorry, you're given ticket number does not match your article's ticket number!",
            Comment => 'Please contact your admin.',
        );
    }

    # check if only responsible can edit articles
    if ( $Self->{Config}->{OnlyResponsible} && $Self->{UserID} != $Article{ResponsibleID} ) {
        my $Output = $LayoutObject->Header(
            Value => $Ticket{Number},
            Type  => 'Small',
        );
        $Output .=
            $LayoutObject->Warning(
            Message =>
                'Sorry, you need to be the responsible of the ticket to do this action!',
            );

        $Output .= $LayoutObject->Footer( Type => 'Small', );
        return $Output;
    }

    # get lock state
    if ( $Self->{Config}->{RequiredLock} ) {
        if ( !$TicketObject->TicketLockGet( TicketID => $Article{TicketID} ) ) {
            $TicketObject->TicketLockSet(
                TicketID => $Article{TicketID},
                Lock     => 'lock',
                UserID   => $Self->{UserID}
            );
            my $Success = $TicketObject->TicketOwnerSet(
                TicketID  => $Article{TicketID},
                UserID    => $Self->{UserID},
                NewUserID => $Self->{UserID},
            );

            # show lock state
            if ($Success) {
                $LayoutObject->Block(
                    Name => 'PropertiesLock',
                    Data => { %Param, TicketID => $Article{TicketID} },
                );
            }
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Article{TicketID},
                OwnerID  => $Self->{UserID},
            );
            if ( !$AccessOk ) {
                my $Output = $LayoutObject->Header(
                    Type  => 'Small',
                    Value => $Ticket{Number},
                );
                $Output .= $LayoutObject->Warning(
                    Message => 'Sorry, you need to be the owner to do this action!',
                    Comment => 'Please change the owner first.',
                );
                $Output .= $LayoutObject->Footer( Type => 'Small' );
                return $Output;
            }
            $LayoutObject->Block(
                Name => 'TicketBack',
                Data => {
                    TicketID  => $Article{TicketID},
                    ArticleID => $Article{ArticleID},
                    FormID    => $Self->{FormID},
                },
            );
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'TicketBack',
            Data => {
                TicketID  => $Article{TicketID},
                ArticleID => $Article{ArticleID},
                FormID    => $Self->{FormID},
            },
        );
    }

    # show different blocks
    $LayoutObject->Block(
        Name => 'ArticleEdit',
        Data => {
            %Param,
            %Ticket,
            %Article,
            FormID    => $Self->{FormID},
        },
    );

    $LayoutObject->Block(
        Name => 'ArticleCopyMove',
        Data => {
            %Param,
            %Ticket,
            %Article,
            WidgetClass => 'ArticleCopy',
            WidgetTitle => 'Copy Article',
            FormID    => $Self->{FormID},
        },
    );

    # get accounting time
    if ( $Article{TimeUnits} ) {
        $LayoutObject->Block(
            Name => 'TimeUnitsJs',
            Data => {
                %Param,
                TimeUnitsOriginal => $GetParam{TimeUnitsOriginal} || 'Difference',
            },
        );
        $LayoutObject->Block(
            Name => 'TimeUnitsCopy',
            Data => {
                %Param,
                %Ticket,
                %Article,
            }
        );
    }

    # get first article
    my %FirstArticle = $TicketObject->ArticleFirstArticle(
        TicketID => $GetParam{TicketID},
    );

    # check copy or move first article
    if ( $GetParam{ArticleID} != $FirstArticle{ArticleID} ) {
        $LayoutObject->Block(
            Name => 'ArticleCopyMove',
            Data => {
                %Param,
                %Ticket,
                %Article,
                WidgetClass => 'ArticleMove',
                WidgetTitle => 'Move Article',
                FormID    => $Self->{FormID},
            },
        );
        $LayoutObject->Block(
            Name => 'ArticleDelete',
            Data => {
                %Param,
                %Ticket,
                %Article,
                FormID    => $Self->{FormID},
            },
        );
    }

    # get dynamic field values from http request
    my %DynamicFieldValues;

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # extract the dynamic field value from the web request
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} }
            = $BackendObject->EditFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ParamObject        => $ParamObject,
            LayoutObject       => $LayoutObject,
            );

    }

    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    DYNAMICFIELD:
    for my $DynamicField ( keys %DynamicFieldValues ) {

        next DYNAMICFIELD if !$DynamicField;
        next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

        $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField }
            = $DynamicFieldValues{$DynamicField};
    }
    $GetParam{DynamicField} = \%DynamicFieldACLParameters;

    # ------------------------------------------------------------ #
    # save changes
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'ArticleEdit' ) {

        my %Error;

        # get params
        for my $Key (
            qw(Body Subject Year Month Day Hour Minute AttachmentChanged ArticleTypeID TimeUnits
            )
            )
        {
            $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
        }

        $GetParam{Created}
            = $GetParam{Year} . '-'
            . $GetParam{Month} . '-'
            . $GetParam{Day} . ' '
            . $GetParam{Hour} . ':'
            . $GetParam{Minute} . ':'
            . '00';

        $GetParam{IncomingTime}
            = $TimeObject->TimeStamp2SystemTime( String => $GetParam{Created} );

        #-----------------------------------------------------------------------
        # If is an action about attachments
        #-----------------------------------------------------------------------
        my $IsUpload = 0;

        # attachment delete
        for my $Count ( 1 .. 32 ) {
            my $Delete = $ParamObject->GetParam( Param => "AttachmentDelete$Count" );
            next if !$Delete;

            $UploadCacheObject->FormIDRemoveFile(
                FormID => $Self->{FormID},
                FileID => $Count,
            );
            $IsUpload = 1;
            $Error{AttachmentChanged} = 1;
        }

        # attachment upload
        if ( $ParamObject->GetParam( Param => 'AttachmentUpload' ) ) {
            my %UploadStuff = $ParamObject->GetUploadAll(
                Param  => 'FileUpload',
                Source => 'string',
            );
            $UploadCacheObject->FormIDAddFile(
                FormID => $Self->{FormID},
                %UploadStuff,
            );
            $IsUpload = 1;
            $Error{AttachmentChanged} = 1;
        }

        #-----------------------------------------------------------------------
        # if the action is not about attachments -> check article values
        #-----------------------------------------------------------------------

        if ( !$IsUpload ) {

            # check subject
            if ( !$GetParam{Subject} ) {
                $Error{SubjectInvalid} = 'ServerError';
            }

            # check body
            if ( !$GetParam{Body} ) {
                $Error{BodyInvalid} = 'ServerError';
            }

            # check time units
            if (
                defined $GetParam{TimeUnits}
                && $GetParam{TimeUnits} eq ''
                && $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
                )
            {
                $Error{TimeUnitsInvalid} = 'ServerError';
            }

            # check create date
            if ( !$GetParam{Created} ) {

                # TODO
            }
        }

        # get all attachments meta data
        my @Attachments
            = $UploadCacheObject->FormIDGetAllFilesMeta( FormID => $Self->{FormID}, );

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $PossibleValuesFilter;

            # check if field has PossibleValues property in its configuration
            if ( IsHashRefWithData( $DynamicFieldConfig->{Config}->{PossibleValues} ) ) {

                # set possible values filter from ACLs
                my $ACL = $TicketObject->TicketAcl(
                    %GetParam,
                    Action        => $Self->{Action},
                    TicketID      => $Self->{TicketID},
                    ReturnType    => 'Ticket',
                    ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data          => $DynamicFieldConfig->{Config}->{PossibleValues},
                    UserID        => $Self->{UserID},
                );
                if ($ACL) {
                    my %Filter = $TicketObject->TicketAclData();
                    $PossibleValuesFilter = \%Filter;
                }
            }

            my $ValidationResult;

            # do not validate on attachment upload
            if ( !$IsUpload ) {

                $ValidationResult = $BackendObject->EditFieldValueValidate(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $PossibleValuesFilter,
                    ParamObject          => $ParamObject,
                    Mandatory =>
                        $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                );

                if ( !IsHashRefWithData($ValidationResult) ) {
                    return $LayoutObject->ErrorScreen(
                        Message =>
                            "Could not perform validation on field $DynamicFieldConfig->{Label}!",
                        Comment => 'Please contact the admin.',
                    );
                }

                # propagate validation error to the Error variable to be detected by the frontend
                if ( $ValidationResult->{ServerError} ) {
                    $Error{ $DynamicFieldConfig->{Name} } = ' ServerError';
                }
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                $BackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValuesFilter,
                Mandatory =>
                    $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                ServerError  => $ValidationResult->{ServerError}  || '',
                ErrorMessage => $ValidationResult->{ErrorMessage} || '',
                LayoutObject => $LayoutObject,
                ParamObject  => $ParamObject,
                AJAXUpdate   => 1,
                UpdatableFields => $Self->_GetFieldsToUpdate(),
                );
        }

        if (%Error) {
            my $Output = $LayoutObject->Header( Type => 'Small', );
            $Output .= $Self->_Mask(
                Attachments => \@Attachments,
                %Ticket,
                %Article,
                DynamicFieldHTML => \%DynamicFieldHTML,
                %GetParam,
                %Error,
                FormID => $Self->{FormID},
            );
            $Output .= $LayoutObject->Footer( Type => 'Small', );
            return $Output;
        }

        #-----------------------------------------------------------------------
        # if the action is not about attachments and no error occured -> update article values
        #-----------------------------------------------------------------------

        #-----------------------------------------------------------------------
        # check if create date has been changed (if diference is more than 1 minute)
        if ( abs( $Article{IncomingTime} - $GetParam{IncomingTime} ) >= 60 ) {
            my $UpdateSuccessful = $TicketObject->ArticleCreateDateUpdate(
                TicketID     => $Article{TicketID},
                ArticleID    => $Article{ArticleID},
                IncomingTime => $GetParam{IncomingTime},
                Created      => $GetParam{Created},
                UserID       => $Self->{UserID},
            );
            if ( !$UpdateSuccessful ) {
                return $LayoutObject->ErrorScreen(
                    Message => Translatable('Can\'t update article create time!'),
                    Comment => Translatable('Please contact the admin.'),
                );
            }
            else {
                $TicketObject->HistoryAdd(
                    Name => "Article updated, ID: "
                        . $Article{ArticleID}
                        . " - Updated incoming time from '"
                        . $Article{Created}
                        . "' to '"
                        . $GetParam{Created} . "'",
                    HistoryType  => $Self->{Config}->{HistoryType},
                    TicketID     => $Article{TicketID},
                    CreateUserID => $Self->{UserID},
                );
            }
        }

        #-----------------------------------------------------------------------
        # check if subject has been changed
        if ( $GetParam{Subject} ne $Article{Subject} ) {
            my $UpdateSuccessful = $TicketObject->ArticleUpdate(
                ArticleID => $Article{ArticleID},
                Key       => 'Subject',
                Value     => $GetParam{Subject},
                UserID    => $Self->{UserID},
                TicketID  => $Article{TicketID},
            );
            if ( !$UpdateSuccessful ) {
                return $LayoutObject->ErrorScreen(
                    Message => Translatable('Can\'t update article subject!'),
                    Comment => Translatable('Please contact the admin.'),
                );
            }
            else {
                $TicketObject->HistoryAdd(
                    Name => "Article updated, ID: "
                        . $Article{ArticleID}
                        . " - Updated article subject from '"
                        . $Article{Subject}
                        . "' to '"
                        . $GetParam{Subject} . "'",
                    HistoryType  => $Self->{Config}->{HistoryType},
                    TicketID     => $Article{TicketID},
                    CreateUserID => $Self->{UserID},
                );
            }
        }

        #-----------------------------------------------------------------------
        # Update attachments (incl. article note if saved as HTML attachment)
        # It is not optimal, because there is no way to delete ONE particular
        # attachment, it's only possibel to delete them ALL (see Article.pm)

        if ( $GetParam{AttachmentChanged} || $GetParam{Body} ne $Article{Body} ) {

            # delete all (old) attachments
            my $UpdateSuccessful = $TicketObject->ArticleDeleteAttachment(
                ArticleID => $Article{ArticleID},
                UserID    => $Self->{UserID},
            );
            if ( !$UpdateSuccessful ) {
                return $LayoutObject->ErrorScreen(
                    Message => Translatable('Can\'t delete article attachment!'),
                    Comment => Translatable('Please contact the admin.'),
                );
            }

            # if RichText is used - save (new) body as HTML attachment
            if ( $LayoutObject->{BrowserRichText} ) {

                # verify html document
                my $HTMLBody =
                    $LayoutObject
                    ->RichTextDocumentComplete( String => $GetParam{Body}, );

                # and save (new) body as html attachment
                $UpdateSuccessful =
                    $TicketObject->ArticleWriteAttachment(
                    Content => $HTMLBody,
                    ContentType =>
                        "text/html; charset=\"$LayoutObject->{UserCharset}\"",
                    Filename =>
                        'file-2',    # as used in Article.pm (sub ArticleCreate)
                    ArticleID => $Article{ArticleID},
                    UserID    => $Self->{UserID},
                    Force     => 1,
                    );
                if ( !$UpdateSuccessful ) {
                    return $LayoutObject->ErrorScreen(
                        Message => Translatable('Can\'t add article body as attachment!'),
                        Comment => Translatable('Please contact the admin.'),
                    );
                }
            }

            # save all (new) attachments

            # get pre loaded attachments
            @Attachments =
                $UploadCacheObject
                ->FormIDGetAllFilesData( FormID => $Self->{FormID}, );

            # get submit attachment
            my %UploadStuff = $ParamObject->GetUploadAll(
                Param  => 'FileUpload',
                Source => 'String',
            );
            if (%UploadStuff) {
                push @Attachments, \%UploadStuff;
            }

            # write attachments
            for my $Attachment (@Attachments) {

                # skip, deleted not used inline images
                if ( $LayoutObject->{BrowserRichText} ) {
                    my $ContentID = $Attachment->{ContentID};
                    if ($ContentID) {
                        my $ContentIDHTMLQuote =
                            $LayoutObject->Ascii2Html( Text => $ContentID, );

                        # workaround for link encode of rich text editor, see bug#5053
                        my $ContentIDLinkEncode =
                            $LayoutObject->LinkEncode($ContentID);
                        $GetParam{Body} =~
                            s/(ContentID=)$ContentIDLinkEncode/$1$ContentID/g;

                        # ignore attachment if not linked in body
                        next
                            if $GetParam{Body} !~
                                /(\Q$ContentIDHTMLQuote\E|\Q$ContentID\E)/i;
                    }
                }

                # write existing file to backend
                $UpdateSuccessful =
                    $TicketObject->ArticleWriteAttachment(
                    %{$Attachment},
                    ArticleID => $Article{ArticleID},
                    UserID    => $Self->{UserID},
                    );
                if ( !$UpdateSuccessful ) {

                    # error page
                    return $LayoutObject->ErrorScreen(
                        Message => Translatable('Can\'t update article body!'),
                        Comment => Translatable('Please contact the admin.'),
                    );
                }
            }
        }

        # set dynamic fields
        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # set the value
            my $Success = $BackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Article{ArticleID},
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $Self->{UserID},
            );
        }

        #-----------------------------------------------------------------------
        # check if body has been changed
        if ( $GetParam{Body} ne $Article{Body} ) {

            # if RichText is used - get ascii body
            if ( $LayoutObject->{BrowserRichText} ) {
                $GetParam{Body} =
                    $HTMLUtilsObject->ToAscii( String => $GetParam{Body}, );
            }

            # update article body
            my $UpdateSuccessful = $TicketObject->ArticleUpdate(
                ArticleID => $Article{ArticleID},
                Key       => 'Body',
                Value     => $GetParam{Body},
                UserID    => $Self->{UserID},
                TicketID  => $Article{TicketID},
            );

            if ( !$UpdateSuccessful ) {
                return $LayoutObject->ErrorScreen(
                    Message => Translatable('Can\'t update article body!'),
                    Comment => Translatable('Please contact the admin.'),
                );
            }
            else {
                $TicketObject->HistoryAdd(
                    Name => 'Article updated, ID: '
                        . $Article{ArticleID}
                        . ' - Updated article body',
                    HistoryType  => $Self->{Config}->{HistoryType},
                    TicketID     => $Article{TicketID},
                    CreateUserID => $Self->{UserID},
                );
            }
        }

        #-----------------------------------------------------------------------
        # check if attachments have been changed
        if ( $GetParam{AttachmentChanged} ) {

            $TicketObject->HistoryAdd(
                Name => 'Article updated, ID: '
                    . $Article{ArticleID}
                    . ' - Updated attachment(s)',
                HistoryType  => $Self->{Config}->{HistoryType},
                TicketID     => $Article{TicketID},
                CreateUserID => $Self->{UserID},
            );
        }

        # remove pre submited attachments from cache
        $UploadCacheObject->FormIDRemove( FormID => $Self->{FormID} );

        #-----------------------------------------------------------------------
        # check if article type has been changed
        if (
            defined $GetParam{ArticleTypeID}
            && $GetParam{ArticleTypeID} != $Article{ArticleTypeID}
            )
        {
            my %ArticleTypeList = $TicketObject->ArticleTypeList( Result => 'HASH' );

            # update article type
            my $UpdateSuccessful = $TicketObject->ArticleUpdate(
                ArticleID => $Article{ArticleID},
                Key       => 'ArticleTypeID',
                Value     => $GetParam{ArticleTypeID},
                UserID    => $Self->{UserID},
                TicketID  => $Article{TicketID},
            );

            $TicketObject->HistoryAdd(
                Name => 'Article updated, ID: '
                    . $Article{ArticleID}
                    . ' - Updated article type from "'
                    . $ArticleTypeList{ $Article{ArticleTypeID} }
                    . '" to "'
                    . $ArticleTypeList{ $GetParam{ArticleTypeID} } . '"',
                HistoryType  => $Self->{Config}->{HistoryType},
                TicketID     => $Article{TicketID},
                CreateUserID => $Self->{UserID},
            );
        }

        #-----------------------------------------------------------------------
        # check if time accounting has been changed
        if ( defined $GetParam{TimeUnits} && $GetParam{TimeUnits} != $Article{TimeUnits} ) {

            if ( $GetParam{TimeUnits} ) {

                # delete old time account values
                my $DeleteSuccessful = $TicketObject->TicketAccountedTimeDelete(
                    TicketID  => $Article{TicketID},
                    ArticleID => $Article{ArticleID},
                );

                # set new time account value
                my $UpdateSuccessful = $TicketObject->TicketAccountTime(
                    TicketID  => $Article{TicketID},
                    ArticleID => $Article{ArticleID},
                    TimeUnit  => $GetParam{TimeUnits},
                    UserID    => $Self->{UserID},
                );
                if ( !$UpdateSuccessful || !$DeleteSuccessful ) {

                    # error page
                    return $LayoutObject->ErrorScreen(
                        Message => Translatable('Can\'t update accounted time for this article!'),
                        Comment => Translatable('Please contact the admin.'),
                    );
                }
                else {
                    $TicketObject->HistoryAdd(
                        Name => "Article updated, ID: "
                            . $Article{ArticleID}
                            . " - Updated accounted time from '"
                            . $Article{TimeUnits}
                            . "' to '"
                            . $GetParam{TimeUnits} . "'",
                        HistoryType  => $Self->{Config}->{HistoryType},
                        TicketID     => $Article{TicketID},
                        CreateUserID => $Self->{UserID},
                    );
                }
            }
        }

        # redirect
        return $LayoutObject->PopupClose(
            URL =>
                "Action=AgentTicketZoom&TicketID=$Article{TicketID};ArticleID=$Article{ArticleID}"
        );
    }

    # ------------------------------------------------------------ #
    # copy or move article
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ArticleCopy' || $Self->{Subaction} eq 'ArticleMove' ) {

        for (qw(NewTicketNumber TimeUnits TimeUnitsOriginal)) {
            $GetParam{$_} = $ParamObject->GetParam( Param => $_ ) || '';
        }

        my $NewTicketID = $GetParam{TicketID};

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # check needed stuff
        if ( !$GetParam{NewTicketNumber} ) {
            my $Output = $LayoutObject->Header( Type => 'Small', );
            $Output .= $LayoutObject->Notify(
                Info => 'Perhaps, you forgot to enter a ticket number!',
            );
            $Output .= $Self->_Mask(
                %Ticket,
                %Article,
                %GetParam,
                FormID => $Self->{FormID},
            );
            $Output .= $LayoutObject->Footer( Type => 'Small', );
            return $Output;
        }

        # get new ticket id
        $NewTicketID = $TicketObject->TicketCheckNumber(
            Tn => $GetParam{NewTicketNumber},
        );
        if ( !$NewTicketID ) {
            my $Output = $LayoutObject->Header( Type => 'Small', );
            $Output .= $LayoutObject->Notify(
                Info =>
                    $LayoutObject->{LanguageObject}
                    ->Get('Sorry, no ticket found for ticket number: ')
                    . $GetParam{NewTicketNumber}
                    . '!',
            );
            $Output .= $Self->_Mask(
                %Ticket,
                %Article,
                %GetParam,
                FormID => $Self->{FormID},
            );
            $Output .= $LayoutObject->Footer( Type => 'Small' );
            return $Output;
        }

        # check owner of new ticket
        my $NewAccessOk = $TicketObject->OwnerCheck(
            TicketID => $NewTicketID,
            OwnerID  => $Self->{UserID},
        );

        if ( !$NewAccessOk ) {
            my $Output = $LayoutObject->Header( Type => 'Small', );
            $Output .= $LayoutObject->Notify(
                Info => 'Sorry, you need to be owner of the new ticket to do this action!',
            );
            $Output .= $Self->_Mask(
                %Ticket,
                %Article,
                %GetParam,
                FormID => $Self->{FormID},
            );
            $Output .= $LayoutObject->Footer( Type => 'Small' );
            return $Output;
        }

        # copy article
        if ( $Self->{Subaction} eq 'ArticleCopy' ) {
            my $CopyResult = $TicketObject->ArticleCopy(
                TicketID  => $NewTicketID,
                ArticleID => $GetParam{ArticleID},
                UserID    => $Self->{UserID},
            );
            if ( $CopyResult eq 'CopyFailed' ) {
                return $LayoutObject->ErrorScreen(
                    Message =>
                        "Can't copy article $GetParam{ArticleID} to ticket $GetParam{NewTicketNumber}!",
                    Comment => Translatable('Please contact your admin.'),
                );
            }
            elsif ( $CopyResult eq 'UpdateFailed' ) {
                return $LayoutObject->ErrorScreen(
                    Message => $LayoutObject->{LanguageObject}->Translate('Can\'t update times for article %s!', $GetParam{ArticleID} ),
                    Comment => Translatable('Please contact your admin.'),
                );
            }

            # add accounted time to new article
            if ( $GetParam{TimeUnits} ) {
                $TicketObject->TicketAccountTime(
                    TicketID  => $NewTicketID,
                    ArticleID => $CopyResult,
                    TimeUnit  => $GetParam{TimeUnits},
                    UserID    => $Self->{UserID},
                );
            }

            # delete accounted time from old article
            if ( $GetParam{TimeUnitsOriginal} ne 'Keep' ) {
                $TicketObject->ArticleAccountedTimeDelete(
                    ArticleID => $GetParam{ArticleID},
                );
            }

            # save residual if chosen to old article
            if ( $GetParam{TimeUnitsOriginal} eq 'Difference' && $GetParam{TimeUnits} ) {
                $TicketObject->TicketAccountTime(
                    TicketID  => $GetParam{TicketID},
                    ArticleID => $GetParam{ArticleID},
                    TimeUnit  => ( $Param{AccountedTime} - $GetParam{TimeUnits} ),
                    UserID    => $Self->{UserID},
                );
            }

            # add history to original ticket
            $TicketObject->HistoryAdd(
                Name => "Copied article $GetParam{ArticleID} from "
                    . "ticket $Article{TicketNumber} to ticket $GetParam{NewTicketNumber} "
                    . "as article $CopyResult",
                HistoryType  => 'Misc',
                TicketID     => $GetParam{TicketID},
                ArticleID    => $GetParam{ArticleID},
                CreateUserID => $Self->{UserID},
            );
        }

        # move article
        elsif ( $Self->{Subaction} eq 'ArticleMove' ) {
            my $MoveResult = $TicketObject->ArticleMove(
                TicketID  => $NewTicketID,
                ArticleID => $GetParam{ArticleID},
                UserID    => $Self->{UserID},
            );
            if ( $MoveResult eq 'MoveFailed' ) {
                return $LayoutObject->ErrorScreen(
                    Message =>
                        "Can't move article $GetParam{ArticleID} to ticket $GetParam{NewTicketNumber}!",
                    Comment => Translatable('Please contact your admin.'),
                );
            }
            if ( $MoveResult eq 'AccountFailed' ) {
                return $LayoutObject->ErrorScreen(
                    Message => $LayoutObject->{LanguageObject}->Translate('Can\'t update ticket id in time accounting data for article %s!', $GetParam{ArticleID} ),
                    Comment => Translatable('Please contact your admin.'),
                );
            }

            # add history to new ticket
            $TicketObject->HistoryAdd(
                Name => "Moved article $GetParam{ArticleID} from ticket"
                    . " $Article{TicketNumber} to ticket $GetParam{NewTicketNumber} ",
                HistoryType  => 'Misc',
                TicketID     => $NewTicketID,
                ArticleID    => $GetParam{ArticleID},
                CreateUserID => $Self->{UserID},
            );

            # add history to old ticket
            $TicketObject->HistoryAdd(
                Name => "Moved article $GetParam{ArticleID} from ticket"
                    . " $Article{TicketNumber} to ticket $GetParam{NewTicketNumber} ",
                HistoryType  => 'Misc',
                TicketID     => $GetParam{TicketID},
                ArticleID    => $GetParam{ArticleID},
                CreateUserID => $Self->{UserID},
            );
        }

        # redirect
        return $LayoutObject->PopupClose(
            URL => "Action=AgentTicketZoom&TicketID=$NewTicketID"
        );

    }

    # ------------------------------------------------------------ #
    # delete article
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ArticleDelete' ) {

        my $DeleteResult = $TicketObject->ArticleFullDelete(
            ArticleID => $GetParam{ArticleID},
            UserID    => $Self->{UserID},
        );
        if ( !$DeleteResult ) {
            return $LayoutObject->ErrorScreen(
                Message =>
                    "Can't delete article $GetParam{ArticleID} from ticket $Article{TicketNumber}!",
                Comment => Translatable('Please contact your admin.'),
            );
        }

        # add history to original ticket
        $TicketObject->HistoryAdd(
            Name => "Deleted article $GetParam{ArticleID} from ticket $Article{TicketNumber}",
            HistoryType  => 'Misc',
            TicketID     => $GetParam{TicketID},
            CreateUserID => $Self->{UserID},
        );

        # redirect
        return $LayoutObject->PopupClose(
            URL => "Action=AgentTicketZoom&TicketID=$GetParam{TicketID}"
        );

    }

    # ------------------------------------------------------------ #
    # Autocomplete
    # ------------------------------------------------------------ #

    elsif ( $Self->{Subaction} eq 'SearchTicketID' ) {

        # get params
        for (qw(Term MaxResults)) {
            if ($Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $_ ) ne 'undefined' ) {
                $Param{$_} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $_ ) || '';
            }
            else {
                $Param{$_} = '';
            }
        }

        # get search attributes
        my @SearchAttributes =
            split( ',', $Self->{Config}->{AutoCompleteTicketID}->{SearchAttribute} );

        # do search
        my %ResultHash;
        for my $SearchAttribute (@SearchAttributes) {

            my %Filters;
            $Filters{$SearchAttribute} = $Param{Term};

            my %SearchList = $TicketObject->TicketSearch(
                Result => 'HASH',
                Limit  => $Param{MaxResults},
                %Filters,
                UserID     => $Self->{UserID},
                Permission => 'ro',
            );

            # remove doubles
            for my $SearchResult ( keys %SearchList ) {
                next if defined $ResultHash{$SearchResult} && $ResultHash{$SearchResult};
                $ResultHash{$SearchResult} = $SearchList{$SearchResult};
            }

        }

        # build data
        my @Data;
        my $MaxResultCount = $Param{MaxResults};
        SEARCHID:
        for my $TicketID (
            sort { $ResultHash{$a} cmp $ResultHash{$b} }
            keys %ResultHash
            )
        {
            my %Ticket = $TicketObject->TicketGet(
                TicketID => $TicketID,
            );

            next if $Ticket{StateType} eq 'merged';

            push @Data, {
                SearchObjectKey   => $Ticket{TicketNumber},
                SearchObjectValue => $Ticket{Title},
            };
            $MaxResultCount--;
            last if $MaxResultCount == 0;
        }

        # build JSON output
        my $JSON = $LayoutObject->JSONEncode(
            Data => \@Data,
        );

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # ------------------------------------------------------------ #
    # AJAX Update
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {

        # update Dynamic Fields Possible Values via AJAX
        my @DynamicFieldAJAX;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Article';

            my $PossibleValues = $BackendObject->PossibleValuesGet(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            # set possible values filter from ACLs
            my $ACL = $TicketObject->TicketAcl(
                %GetParam,
                %ACLCompatGetParam,
                Action        => $Self->{Action},
                QueueID       => 0,
                ReturnType    => 'Ticket',
                ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data          => $PossibleValues,
                UserID        => $Self->{UserID},
            );
            if ($ACL) {
                my %Filter = $TicketObject->TicketAclData();
                $PossibleValues = \%Filter;
            }

            # add dynamic field to the list of fields to update
            push(
                @DynamicFieldAJAX,
                {
                    Name        => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data        => $PossibleValues,
                    SelectedID  => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                    Translation => $DynamicFieldConfig->{Config}->{TranslatableValues} || 0,
                    Max         => 100,
                }
            );
        }

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                @DynamicFieldAJAX,
            ],
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # ------------------------------------------------------------ #
    # show screen
    # ------------------------------------------------------------ #
    else {

        # body preparation
        $Article{Body} = $LayoutObject->ArticleQuote(
            TicketID           => $Article{TicketID},
            ArticleID          => $GetParam{ArticleID},
            FormID             => $Self->{FormID},
            UploadCacheObject  => $UploadCacheObject,
            AttachmentsInclude => 1,
        );
        if ( $LayoutObject->{BrowserRichText} ) {
            $Article{ContentType} = 'text/html';
        }
        else {
            $Article{ContentType} = 'text/plain';
        }

        # unescape URIs for inline images etc
        $Article{Body} =~ s/<img([^>]*)\ssrc="(.*?)"/"<img$1" . ' src="' . URI::Escape::uri_unescape( $2 ) . '"'/egi;

        # encode entities for preformatted code within rich text editor
        $Article{Body} = encode_entities( $Article{Body} );

        # get all attachments meta data
        my @Attachments =
            $UploadCacheObject
            ->FormIDGetAllFilesMeta( FormID => $Self->{FormID}, );

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $PossibleValuesFilter;

            # check if field has PossibleValues property in its configuration
            if ( IsHashRefWithData( $DynamicFieldConfig->{Config}->{PossibleValues} ) ) {

                # set possible values filter from ACLs
                my $ACL = $TicketObject->TicketAcl(
                    %GetParam,
                    Action        => $Self->{Action},
                    TicketID      => $Self->{TicketID},
                    ReturnType    => 'Ticket',
                    ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data          => $DynamicFieldConfig->{Config}->{PossibleValues},
                    UserID        => $Self->{UserID},
                );
                if ($ACL) {
                    my %Filter = $TicketObject->TicketAclData();
                    $PossibleValuesFilter = \%Filter;
                }
            }

            # to store dynamic field value from database (or undefined)
            my $Value;

            # only get values for Ticket fields (all screens based on AgentTickeActionCommon
            # generates a new article, then article fields will be always empty at the beginign)
            if ( $DynamicFieldConfig->{ObjectType} eq 'Article' ) {

                # get value stored on the database from Ticket
                $Value = $Article{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                $BackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValuesFilter,
                Value                => $Value,
                Mandatory =>
                    $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject    => $LayoutObject,
                ParamObject     => $ParamObject,
                AJAXUpdate      => 1,
                UpdatableFields => $Self->_GetFieldsToUpdate(),
                );
        }

        # print form ...
        my $Output = $LayoutObject->Header( Type => 'Small', );
        $Output .= $Self->_Mask(
            TicketID         => $Article{TicketID},
            DynamicFieldHTML => \%DynamicFieldHTML,
            %Article,
            FormID      => $Self->{FormID},
            Attachments => \@Attachments,
        );
        $Output .= $LayoutObject->Footer( Type => 'Small', );
        return $Output;
    }
}

sub _Mask {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # edit of content and date/time only possible for note and phone articles
    if ( $Param{ArticleType} =~ /^(note-|phone)/ ) {

        # create date
        my $DiffTime = $TimeObject->SystemTime() - $Param{IncomingTime};
        $Param{DateString} = $LayoutObject->BuildDateSelection(
            Format             => 'DateInputFormatLong',
            DiffTime           => -$DiffTime,
            NoCheckbox         => 1,
        );

        # article date
        $LayoutObject->Block(
            Name => 'CreateDate',
            Data => \%Param,
        );

        # article note
        $LayoutObject->Block(
            Name => 'Note',
            Data => \%Param,
        );

        # show spell check
        if ( $LayoutObject->{BrowserSpellChecker} ) {
            $LayoutObject->Block(
                Name => 'TicketOptions',
                Data => {},
            );
            $LayoutObject->Block(
                Name => 'SpellCheck',
                Data => {},
            );
        }

        # add rich text editor
        if ( $LayoutObject->{BrowserRichText} ) {
            $LayoutObject->Block(
                Name => 'RichText',
                Data => \%Param,
            );
        }

        # show attachments
        for my $Attachment ( @{ $Param{Attachments} } ) {
            next if $Attachment->{ContentID} && $LayoutObject->{BrowserRichText};
            $LayoutObject->Block(
                Name => 'Attachment',
                Data => $Attachment,
            );
        }
    }

    # Dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {

        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # skip fields that HTML could not be retrieved
        next DYNAMICFIELD if !IsHashRefWithData(
            $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} }
        );

        # get print string for this dynamic field
        my $ValueStrg = $BackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Param{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            ValueMaxChars      => 25,
            LayoutObject       => $LayoutObject,
        );

        # get the html strings from $Param
        my $DynamicFieldHTML = $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} };

        $LayoutObject->Block(
            Name => 'DynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'DynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );
    }

    # get possible notes
    if ( $Self->{Config}->{EditableArticleTypes} ) {
        my $ShowTypeEdit = 0;
        my %EditableArticleTypes
            = map { $_ => 1 } split( /,/, $Self->{Config}->{EditableArticleTypes} );
        foreach my $ArticleType ( sort keys %EditableArticleTypes ) {
            if ( $Param{ArticleType} =~ /$ArticleType/ ) {
                $ShowTypeEdit = 1;
                last;
            }
        }
        if ($ShowTypeEdit) {
            my @SplitArray = split( /-/, $Param{ArticleType} );
            pop @SplitArray if ( scalar(@SplitArray) > 1 );
            my $ArticleBaseType = join( '-', @SplitArray );
            my %ArticleTypeList = $TicketObject->ArticleTypeList( Result => 'HASH' );
            my %ArticleTypes;

            # filter the list
            for my $Key ( sort keys %ArticleTypeList ) {
                my @SplitArray = split( /-/, $ArticleTypeList{$Key} );
                pop @SplitArray if ( scalar(@SplitArray) > 1 );
                my $TmpType = join( '-', @SplitArray );
                if ( $TmpType eq $ArticleBaseType ) {
                    $ArticleTypes{$Key} = $ArticleTypeList{$Key};
                }
            }

            $Param{ArticleTypeStrg} = $LayoutObject->BuildSelection(
                Data       => \%ArticleTypes,
                SelectedID => $Param{ArticleTypeID},
                Name       => 'ArticleTypeID',
                Class        => 'Modernize',
            );
            $LayoutObject->Block(
                Name => 'ArticleType',
                Data => \%Param,
            );
        }
    }

    # show time accounting box
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabelMandatory',
                Data => \%Param,
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabel',
                Data => \%Param,
            );
        }
        $LayoutObject->Block(
            Name => 'TimeUnits',
            Data => \%Param,
        );
    }

    # get output back
    return $LayoutObject->Output(
        TemplateFile => 'AgentArticleEdit',
        Data         => \%Param,
    );
}

sub _GetFieldsToUpdate {
    my ( $Self, %Param ) = @_;

    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my @UpdatableFields;

    # set the fields that can be updateable via AJAXUpdate
    if ( !$Param{OnlyDynamicFields} ) {
        @UpdatableFields
            = qw(
            TypeID ServiceID SLAID NewOwnerID OldOwnerID NewResponsibleID NewStateID
            NewPriorityID
        );
    }

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsACLReducible = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsACLReducible',
        );
        next DYNAMICFIELD if !$IsACLReducible;

        push @UpdatableFields, 'DynamicField_' . $DynamicFieldConfig->{Name};
    }

    return \@UpdatableFields;
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
