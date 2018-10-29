# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketPrintRichtext;

# EO TicketPrintRichtext-capeIT

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Output;
    my $QueueID = $TicketObject->TicketQueueID( TicketID => $Self->{TicketID} );
    my $ArticleID = $ParamObject->GetParam( Param => 'ArticleID' );

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} || !$QueueID ) {
        return $LayoutObject->ErrorScreen( Message => 'Need TicketID!' );
    }

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    return $LayoutObject->NoPermission( WithHeader => 'yes' ) if !$Access;

    # get ACL restrictions
    my %PossibleActions = ( 1 => $Self->{Action} );

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();

    # check if ACL restrictions exist
    if ( $ACL || IsHashRefWithData( \%AclAction ) ) {

        my %AclActionLookup = reverse %AclAction;

        # show error screen if ACL prohibits this action
        if ( !$AclActionLookup{ $Self->{Action} } ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }

    # get linked objects
    my $LinkObject       = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LinkListWithData = $LinkObject->LinkListWithData(
        Object           => 'Ticket',
        Key              => $Self->{TicketID},
        State            => 'Valid',
        UserID           => $Self->{UserID},
        ObjectParameters => {
            Ticket => {
                IgnoreLinkedTicketStateTypes => 1,
            },
        },
    );

    # get link type list
    my %LinkTypeList = $LinkObject->TypeList(
        UserID => $Self->{UserID},
    );

    # get the link data
    my %LinkData;
    if ( $LinkListWithData && ref $LinkListWithData eq 'HASH' && %{$LinkListWithData} ) {
        %LinkData = $LayoutObject->LinkObjectTableCreate(
            LinkListWithData => $LinkListWithData,
            ViewMode         => 'SimpleRaw',
        );
    }

    # get content
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );
    my @ArticleBox = $TicketObject->ArticleContentIndex(
        TicketID                   => $Self->{TicketID},
        StripPlainBodyAsAttachment => 1,
        UserID                     => $Self->{UserID},
        DynamicFields              => 0,
    );

    # check if only one article need printed
    if ($ArticleID) {

        ARTICLE:
        for my $Article (@ArticleBox) {
            if ( $Article->{ArticleID} == $ArticleID ) {
                @ArticleBox = ($Article);
                last ARTICLE;
            }
        }
    }

    # TicketPrintRichtext-capeIT
    #    # resort article order
    #    if ( $Self->{ZoomExpandSort} eq 'reverse' ) {
    #        @ArticleBox = reverse(@ArticleBox);
    #    }
    # EO TicketPrintRichtext-capeIT

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # show total accounted time if feature is active:
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        $Ticket{TicketTimeUnits} = $TicketObject->TicketAccountedTimeGet(
            TicketID => $Ticket{TicketID},
        );
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    # user info
    my %UserInfo = $UserObject->GetUserData(
        User => $Ticket{Owner},
    );

    # responsible info
    my %ResponsibleInfo;
    if ( $ConfigObject->Get('Ticket::Responsible') && $Ticket{Responsible} ) {
        %ResponsibleInfo = $UserObject->GetUserData(
            User => $Ticket{Responsible},
        );
    }

    # customer info
    my %CustomerData;
    if ( $Ticket{CustomerUserID} ) {
        %CustomerData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $Ticket{CustomerUserID},
        );
    }

    # do some html quoting
    $Ticket{Age} = $LayoutObject->CustomerAge(
        Age   => $Ticket{Age},
        Space => ' ',
    );

    if ( $Ticket{UntilTime} ) {

        # KIX4OTRS-capeIT
        my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );
        my $DisplayPendingTime = $UserPreferences{UserDisplayPendingTime} || '';

        if ( $DisplayPendingTime && $DisplayPendingTime eq 'RemainingTime' ) {

            # $Ticket{PendingUntil} = $LayoutObject->CustomerAge(
            $Ticket{PendingUntil} .= $LayoutObject->CustomerAge(

                # EO KIX4OTRS-capeIT
                Age   => $Ticket{UntilTime},
                Space => ' ',
            );

            # KIX4OTRS-capeIT
        }
        else {
            $Ticket{PendingUntil} = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
                SystemTime => $Ticket{RealTillTimeNotUsed},
            );
            $Ticket{PendingUntil} = $LayoutObject->{LanguageObject}
                ->FormatTimeString( $Ticket{PendingUntil}, 'DateFormat' );
        }

        # EO KIX4OTRS-capeIT
    }

    # TicketPrintRichtext-capeIT
## REMOVED CODE FOR PDF-GENERATION ##
    #    # get PDF object
    #    my $PDFObject = $Kernel::OM->Get('Kernel::System::PDF');

    # EO TicketPrintRichtext-capeIT

    if (%LinkData) {

        # output link data
        $LayoutObject->Block(
            Name => 'Link',
        );

        for my $LinkTypeLinkDirection ( sort { lc $a cmp lc $b } keys %LinkData ) {

            # investigate link type name
            my @LinkData = split q{::}, $LinkTypeLinkDirection;

            # output link type data
            $LayoutObject->Block(
                Name => 'LinkType',
                Data => {
                    LinkTypeName => $LinkTypeList{ $LinkData[0] }->{ $LinkData[1] . 'Name' },
                },
            );

            # extract object list
            my $ObjectList = $LinkData{$LinkTypeLinkDirection};

            for my $Object ( sort { lc $a cmp lc $b } keys %{$ObjectList} ) {

                for my $Item ( @{ $ObjectList->{$Object} } ) {

                    # output link type data
                    $LayoutObject->Block(
                        Name => 'LinkTypeRow',
                        Data => {
                            LinkStrg => $Item->{Title},
                        },
                    );
                }
            }
        }
    }

    # output customer infos
    if (%CustomerData) {
        $Param{CustomerTable} = $LayoutObject->AgentCustomerViewTable(
            Data => \%CustomerData,
            Max  => 100,
        );
    }

    $Output = $LayoutObject->Output(
        TemplateFile => 'PrintHeader',
        Data         => \%Param,
    );

    # show ticket
    $Output .= $Self->_HTMLMask(
        TicketID        => $Self->{TicketID},
        QueueID         => $QueueID,
        ArticleBox      => \@ArticleBox,
        ResponsibleData => \%ResponsibleInfo,
        %Param,
        %UserInfo,
        %Ticket,
    );

    $Output .= $LayoutObject->Output(
        TemplateFile => 'PrintFooter',
        Data         => \%Param,
    );

    # return output
    return $Output;

    # TicketPrintRichtext-capeIT
    #    }
    # EO TicketPrintRichtext-capeIT
}

# TicketPrintRichtext-capeIT
## REMOVED sub _PDFOutputTicketInfos ##
## REMOVED sub _PDFOutputLinkedObjects ##
## REMOVED sub _PDFOutputTicketDynamicFields ##
## REMOVED sub _PDFOutputCustomerInfos ##
## REMOVED sub _PDFOutputArticles ##
# EO TicketPrintRichtext-capeIT

# TicketPrintRichtext-capeIT
sub _HTMLMask {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( !$Param{FormID} ) {
        $Param{FormID} = $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDCreate();
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # output responsible, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Responsible') ) {
        my $Responsible = '-';
        if ( $Param{Responsible} ) {
            $Responsible = $Param{Responsible} . ' ('
                . $Param{ResponsibleData}->{UserFirstname} . ' '
                . $Param{ResponsibleData}->{UserLastname} . ')';
        }
        $LayoutObject->Block(
            Name => 'Responsible',
            Data => {
                ResponsibleString => $Responsible,
            },
        );
    }

    # output type, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Type') ) {
        $LayoutObject->Block(
            Name => 'TicketType',
            Data => { %Param, },
        );
    }

    # output service and sla, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Service') ) {
        $LayoutObject->Block(
            Name => 'TicketService',
            Data => {
                Service => $Param{Service} || '-',
                SLA     => $Param{SLA}     || '-',
            },
        );
    }

    # output accounted time
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        $LayoutObject->Block(
            Name => 'AccountedTime',
            Data => {%Param},
        );
    }

    # output pending date
    if ( $Param{PendingUntil} ) {
        $LayoutObject->Block(
            Name => 'PendingUntil',
            Data => {%Param},
        );
    }

    # output first response time
    if ( defined( $Param{FirstResponseTime} ) ) {
        $LayoutObject->Block(
            Name => 'FirstResponseTime',
            Data => {%Param},
        );
    }

    # output update time
    if ( defined( $Param{UpdateTime} ) ) {
        $LayoutObject->Block(
            Name => 'UpdateTime',
            Data => {%Param},
        );
    }

    # output solution time
    if ( defined( $Param{SolutionTime} ) ) {
        $LayoutObject->Block(
            Name => 'SolutionTime',
            Data => {%Param},
        );
    }

    my $DynamicFieldFilter
        = $ConfigObject->Get("Ticket::Frontend::AgentTicketPrint")->{DynamicField};

    # get the dynamic fields for ticket object
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $DynamicFieldFilter || {},
    );

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields for ticket object
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $Value = $DynamicFieldBackendObject->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{TicketID},
        );

        next DYNAMICFIELD if !$Value;
        next DYNAMICFIELD if $Value eq "";

        # get print string for this dynamic field
        my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
            HTMLOutput         => 1,
            ValueMaxChars      => 20,
            LayoutObject       => $LayoutObject,
        );

        my $Label = $DynamicFieldConfig->{Label};

        $LayoutObject->Block(
            Name => 'TicketDynamicField',
            Data => {
                Label => $Label,
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'TicketDynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Label => $Label,
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );
    }

    # build article stuff
    my $SelectedArticleID = $Param{ArticleID} || '';
    my @ArticleBox        = @{ $Param{ArticleBox} };
    my $ArticleCounter    = 1;

    # get last customer article
    for my $ArticleTmp (@ArticleBox) {
        my %Article = %{$ArticleTmp};

        # Set Article count and increment
        $Article{ArticleCounter} = $ArticleCounter++;

        # get attachment string
        my %AtmIndex = ();
        if ( $Article{Atms} ) {
            %AtmIndex = %{ $Article{Atms} };
        }
        $Param{'Article::ATM'} = '';
        for my $FileID ( sort keys %AtmIndex ) {
            my %File = %{ $AtmIndex{$FileID} };
            $File{Filename} = $LayoutObject->Ascii2Html( Text => $File{Filename} );
            my $DownloadText = $LayoutObject->{LanguageObject}->Translate("Download");
            $Param{'Article::ATM'}
                .= '<a href="' . $LayoutObject->{Baselink} . 'Action=AgentTicketAttachment;'
                . "ArticleID=$Article{ArticleID};FileID=$FileID\" target=\"attachment\" "
                . "title=\"$DownloadText: $File{Filename}\">"
                . "$File{Filename}</a> $File{Filesize}<br/>";
        }

        if ( $Article{ArticleType} eq 'chat-external' || $Article{ArticleType} eq 'chat-internal' )
        {
            $Article{ChatMessages} = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
                Data => $Article{Body},
            );
            $Article{IsChat} = 1;
        }
        else {

            # check if just a only html email
            my $MimeTypeText = $LayoutObject->CheckMimeType(
                %Param,
                %Article,
                Action => 'AgentTicketZoom',
            );
            if ($MimeTypeText) {
                $Param{TextNote} = $MimeTypeText;
                $Article{Body}   = '';
            }
            else {

                # html quoting
                $Article{Body} = $LayoutObject->Ascii2Html(
                    NewLine => $ConfigObject->Get('DefaultViewNewLine'),
                    Text    => $Article{Body},
                    VMax    => $ConfigObject->Get('DefaultViewLines') || 5000,
                );

                if ( $Article{AttachmentIDOfHTMLBody} ) {
                    my %AttachmentHTML = $TicketObject->ArticleAttachment(
                        ArticleID => $Article{ArticleID},
                        FileID    => $Article{AttachmentIDOfHTMLBody},
                        UserID    => $Self->{UserID},
                    );

                    my $Charset = $AttachmentHTML{ContentType} || '';
                    $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
                    $Charset =~ s/"|'//g;
                    $Charset =~ s/(.+?);.*/$1/g;

                    my $Body = $AttachmentHTML{Content};

                    # convert html body to correct charset
                    $Body = $Kernel::OM->Get('Kernel::System::Encode')->Convert(
                        Text => $Body,
                        From => $Charset,
                        To   => $Self->{UserCharset} || 'utf-8',
                    );

                    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

                    # add url quoting
                    $Body = $HTMLUtilsObject->LinkQuote(
                        String => $Body,
                    );

                    # strip head, body and meta elements
                    $Body = $HTMLUtilsObject->DocumentStrip(
                        String => $Body,
                    );

                    my %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
                        ArticleID => $Article{ArticleID},
                        UserID    => $Self->{UserID},
                    );

                    # search inline documents in body and add it to upload cache
                    my $SessionID = '';
                    if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
                        $SessionID = ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
                    }

                    my $AttachmentLink = $LayoutObject->{Baselink}
                        . 'Action=AgentTicketAttachment;Subaction=HTMLView;ArticleID='
                        . $Article{ArticleID}
                        . ';FileID=';

                    my %Attachments = %AttachmentIndex;
                    my %AttachmentAlreadyUsed;
                    $Body =~ s{
                        (=|"|')cid:(.*?)("|'|>|\/>|\s)
                    }
                    {
                        my $Start= $1;
                        my $ContentID = $2;
                        my $End = $3;
                        # improve html quality
                        if ( $Start ne '"' && $Start ne '\'' ) {
                            $Start .= '"';
                        }
                        if ( $End ne '"' && $End ne '\'' ) {
                            $End = '"' . $End;
                        }

                        # find attachment to include
                        ATMCOUNT:
                        for my $AttachmentID ( sort keys %Attachments ) {

                            if ( lc $Attachments{$AttachmentID}->{ContentID} ne lc "<$ContentID>" ) {
                                next ATMCOUNT;
                            }

                            # get whole attachment
                            my %AttachmentPicture = $TicketObject->ArticleAttachment(
                                ArticleID => $Article{ArticleID},
                                FileID    => $AttachmentID,
                                UserID    => $Self->{UserID},
                            );

                            ## content id cleanup
                            $AttachmentPicture{ContentID} =~ s/^<//;
                            $AttachmentPicture{ContentID} =~ s/>$//;

                            # find cid, add attachment URL and remember, file is already uploaded
                            $ContentID = $AttachmentLink . $AttachmentID; #$LayoutObject->LinkEncode( $AttachmentPicture{ContentID} );

                            # add to upload cache if not uploaded and remember
                            if (!$AttachmentAlreadyUsed{$AttachmentID}) {

                                # remember
                                $AttachmentAlreadyUsed{$AttachmentID} = 1;

                                # write attachment to upload cache
                                $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDAddFile(
                                    FormID      => $Param{FormID},
                                    Disposition => 'inline',
                                    %{ $Attachments{$AttachmentID} },
                                    %AttachmentPicture,
                                );
                            }
                        }

                        # return link
                        $Start . $ContentID . $End;
                    }egxi;

                    # scale image
                    $Body =~ s/(<img[^>]+style="[^"]*)width:[0-9]+px([^"]*"[^>]*>)/$1$2/g;
                    $Body =~ s/(<img[^>]+style="[^"]*)height:[0-9]+px([^"]*"[^>]*>)/$1$2/g;
                    $Body =~ s/(<img[^>]+)style="[\s;]*"([^>]*>)/$1$2/g;
                    if ( $Body =~ m/<img[^>]+style="/ ) {
                        $Body
                            =~ s/(<img[^>]+style=")([^>]+>)/$1width:auto;max-width:612px;height:auto;$2/g;
                    }
                    else {
                        $Body
                            =~ s/(<img)([^>]+>)/$1 style="width:auto;max-width:612px;height:auto;" $2/g;
                    }

                    # strip head, body and meta elements
                    $Article{Body}
                        = '<div class="ArticleMailContent" style="font-family:Geneva,Helvetica,Arial,sans-serif; font-size: 12px;">'
                        . $Body
                        . '</div>';
                }
                else {
                    $Article{Body} = '<pre>' . $Article{Body} . '</pre>';
                }
            }
        }

        $LayoutObject->Block(
            Name => 'Article',
            Data => { %Param, %Article },
        );

        # do some strips && quoting

        $LayoutObject->Block(
            Name => 'ArticleCount',
            Data => { %Param, %Article },
        );

        for my $Parameter (qw(From To Cc Subject)) {
            if ( $Article{$Parameter} ) {
                $LayoutObject->Block(
                    Name => 'Row',
                    Data => {
                        Key   => $Parameter,
                        Value => $Article{$Parameter},
                    },
                );
            }
        }

        # show accounted article time
        if ( $ConfigObject->Get('Ticket::ZoomTimeDisplay') ) {
            my $ArticleTime = $TicketObject->ArticleAccountedTimeGet(
                ArticleID => $Article{ArticleID},
            );
            $LayoutObject->Block(
                Name => "Row",
                Data => {
                    Key   => 'Time',
                    Value => $ArticleTime,
                },
            );
        }

        # get the dynamic fields for ticket object
        my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
            Valid       => 1,
            ObjectType  => ['Article'],
            FieldFilter => $DynamicFieldFilter || {},
        );

        # cycle trough the activated Dynamic Fields for ticket object
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$DynamicField} ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $Value = $DynamicFieldBackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Article{ArticleID},
            );

            next DYNAMICFIELD if !$Value;
            next DYNAMICFIELD if $Value eq "";

            # get print string for this dynamic field
            my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Value,
                HTMLOutput         => 1,
                ValueMaxChars      => 20,
                LayoutObject       => $LayoutObject,
            );

            my $Label = $DynamicFieldConfig->{Label};

            $LayoutObject->Block(
                Name => 'ArticleDynamicField',
                Data => {
                    Label => $Label,
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );

        }
    }

    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketPrintRichtext',
        Data         => \%Param,
    );

}

# EO TicketPrintRichtext-capeIT

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
