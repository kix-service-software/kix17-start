# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Output::HTML::Layout::Ticket - all Ticket-related HTML functions

=head1 SYNOPSIS

All Ticket-related HTML functions

=head1 PUBLIC INTERFACE

=over 4

=item AgentCustomerViewTable()

=cut

sub AgentCustomerViewTable {
    my ( $Self, %Param ) = @_;

    # check customer params
    if ( ref $Param{Data} ne 'HASH' ) {
        $Self->FatalError( Message => 'Need Hash ref in Data param' );
    }
    elsif ( ref $Param{Data} eq 'HASH' && !%{ $Param{Data} } ) {
        return $Self->{LanguageObject}->Translate('none');
    }

    # add ticket params if given
    if ( $Param{Ticket} ) {
        %{ $Param{Data} } = ( %{ $Param{Data} }, %{ $Param{Ticket} } );
    }

    my @MapNew;
    my $Map = $Param{Data}->{Config}->{Map};
    if ($Map) {
        @MapNew = ( @{$Map} );
    }

    # check if customer company support is enabled
    if ( $Param{Data}->{Config}->{CustomerCompanySupport} ) {
        my $Map2 = $Param{Data}->{CompanyConfig}->{Map};
        if ($Map2) {
            push( @MapNew, @{$Map2} );
        }
    }

    my $ShownType = 1;
    if ( $Param{Type} && $Param{Type} eq Translatable('Lite') ) {
        $ShownType = 2;

        # check if min one lite view item is configured, if not, use
        # the normal view also
        my $Used = 0;
        for my $Field (@MapNew) {
            if ( $Field->[3] == 2 ) {
                $Used = 1;
            }
        }
        if ( !$Used ) {
            $ShownType = 1;
        }
    }

    # build html table
    $Self->Block(
        Name => 'Customer',
        Data => $Param{Data},
    );

    # get needed objects
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');

    # get isolated layout object for link safety checks
    my $HTMLLinkLayoutObject = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout');

    # check Frontend::CustomerUser::Image
    my $CustomerImage = $ConfigObject->Get('Frontend::CustomerUser::Image');
    if ($CustomerImage) {
        my %Modules = %{$CustomerImage};

        MODULE:
        for my $Module ( sort keys %Modules ) {
            if ( !$MainObject->Require( $Modules{$Module}->{Module} ) ) {
                $Self->FatalDie();
            }

            my $Object = $Modules{$Module}->{Module}->new(
                %{$Self},
                LayoutObject => $Self,
            );

            # run module
            next MODULE if !$Object;

            $Object->Run(
                Config => $Modules{$Module},
                Data   => $Param{Data},
            );
        }
    }

    # use CustomerInfoString
    my $CustomerInfoString = $Param{Data}->{Config}->{CustomerInfoString}
        || $ConfigObject->Get('DefaultCustomerInfoString') || '';

    if ($CustomerInfoString) {
        $CustomerInfoString = $Self->Output(
            Template => $CustomerInfoString,
            Data     => {},
        );
        my $CustomerData = $Param{Data};
        while ( $CustomerInfoString =~ /\$CustomerData\-\>\{(.+?)}/ ) {
            my $Tag = $1;
            if ( $CustomerData->{$Tag} ) {
                $CustomerInfoString =~ s/\$CustomerData\-\>\{$Tag\}/$CustomerData->{$Tag}/;
            }
            else {
                $CustomerInfoString =~ s/\$CustomerData\-\>\{$Tag\}//;
            }
        }
        $Self->Block(
            Name => 'CustomerInfoString',
            Data => {
                CustomerInfoString => $CustomerInfoString,
                %{ $Param{Data} },
                }
        );
    }
    else {
        # build table
        for my $Field (@MapNew) {
            if ( $Field->[3] && $Field->[3] >= $ShownType && $Param{Data}->{ $Field->[0] } ) {
                my %Record = (
                    %{ $Param{Data} },
                    Key       => $Field->[1],
                    Value     => $Param{Data}->{ $Field->[0] },
                    LinkStart => '',
                    LinkStop  => '',
                );
                if ( $Field->[6] ) {
                    $Record{LinkStart} = "<a href=\"$Field->[6]\"";
                    if ( $Field->[8] ) {
                        $Record{LinkStart} .= " target=\"$Field->[8]\"";
                    }
                    if ( $Field->[9] ) {
                        $Record{LinkStart} .= " class=\"$Field->[9]\"";
                    }
                    $Record{LinkStart} .= ">";
                    $Record{LinkStop} = "</a>";
                }
                if ( $Field->[0] ) {
                    $Record{ValueShort} = $Self->Ascii2Html(
                        Text => $Record{Value},
                        Max  => $Param{Max}
                    );
                }
                $Record{Entry} = $HTMLLinkLayoutObject->Output(
                    Template => '[% Data.LinkStart | Interpolate %][% Data.ValueShort %][% Data.LinkStop %]',
                    Data     => \%Record,
                );
                my %Safe = $HTMLUtilsObject->Safety(
                    String       => $Record{Entry},
                    NoApplet     => 1,
                    NoObject     => 1,
                    NoEmbed      => 1,
                    NoSVG        => 1,
                    NoImg        => 1,
                    NoIntSrcLoad => 0,
                    NoExtSrcLoad => 1,
                    NoJavaScript => 1,
                );
                if ( $Safe{Replace} ) {
                    $Record{Entry} = $Safe{String};
                }
                $Self->Block(
                    Name => 'CustomerRow',
                    Data => \%Record,
                );

                if (
                    $Param{Data}->{Config}->{CustomerCompanySupport}
                    && $Field->[0] eq 'CustomerCompanyName'
                ) {
                    my $CompanyValidID = $Param{Data}->{CustomerCompanyValidID};

                    if ($CompanyValidID) {
                        my @ValidIDs = $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet();
                        my $CompanyIsValid = grep { $CompanyValidID == $_ } @ValidIDs;

                        if ( !$CompanyIsValid ) {
                            $Self->Block(
                                Name => 'CustomerRowCustomerCompanyInvalid',
                            );
                        }
                    }
                }
            }
        }
    }

    # check Frontend::CustomerUser::Item
    my $CustomerItem      = $ConfigObject->Get('Frontend::CustomerUser::Item');
    my $CustomerItemCount = 0;
    if ($CustomerItem) {
        $Self->Block(
            Name => 'CustomerItem',
        );
        my %Modules = %{$CustomerItem};

        MODULE:
        for my $Module ( sort keys %Modules ) {
            if ( !$MainObject->Require( $Modules{$Module}->{Module} ) ) {
                $Self->FatalDie();
            }

            my $Object = $Modules{$Module}->{Module}->new(
                %{$Self},
                LayoutObject => $Self,
            );

            # run module
            next MODULE if !$Object;

            my $Run = $Object->Run(
                Config        => $Modules{$Module},
                Data          => $Param{Data},
                CallingAction => $Param{CallingAction}
            );

            next MODULE if !$Run;

            $CustomerItemCount++;
        }
    }

    # create & return output
    return $Self->Output(
        TemplateFile   => 'AgentCustomerTableView',
        Data           => \%Param,
        KeepScriptTags => $Param{Data}->{AJAX} || 0,
    );
}

sub AgentQueueListOption {
    my ( $Self, %Param ) = @_;

    my $Size               = $Param{Size}                      ? "size='$Param{Size}'"   : '';
    my $MaxLevel           = defined( $Param{MaxLevel} )       ? $Param{MaxLevel}        : 10;
    my $SelectedID         = defined( $Param{SelectedID} )     ? $Param{SelectedID}      : '';
    my $Selected           = defined( $Param{Selected} )       ? $Param{Selected}        : '';
    my $CurrentQueueID     = defined( $Param{CurrentQueueID} ) ? $Param{CurrentQueueID}  : '';
    my $Class              = defined( $Param{Class} )          ? $Param{Class}           : '';
    my $Multiple           = $Param{Multiple}                  ? 'multiple = "multiple"' : '';
    my $TreeView           = $Param{TreeView}                  ? $Param{TreeView}        : 0;
    my $OptionTitle        = defined( $Param{OptionTitle} )    ? $Param{OptionTitle}     : 0;
    my $OnChangeSubmit     = defined( $Param{OnChangeSubmit} ) ? $Param{OnChangeSubmit}  : '';
    my $SelectedIDRefArray = $Param{SelectedIDRefArray} || '';
    if ($OnChangeSubmit) {
        $OnChangeSubmit = " onchange=\"submit();\"";
    }
    else {
        $OnChangeSubmit = '';
    }

    # set OnChange if AJAX is used
    if ( $Param{Ajax} ) {

        # get log object
        my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

        if ( !$Param{Ajax}->{Depend} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Need Depend Param Ajax option!',
            );
            $Self->FatalError();
        }
        if ( !$Param{Ajax}->{Update} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'Need Update Param Ajax option()!',
            );
            $Self->FatalError();
        }
        $Param{OnChange} = "Core.AJAX.FormUpdate(\$('#"
            . $Param{Name} . "'), '"
            . $Param{Ajax}->{Subaction} . "',"
            . " '$Param{Name}',"
            . " ['"
            . join( "', '", @{ $Param{Ajax}->{Update} } ) . "']);";
    }

    if ( $Param{OnChange} ) {
        $OnChangeSubmit = " onchange=\"$Param{OnChange}\"";
    }

    my %UserPreferences;
    my $AutoCompleteConfig = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::GenericAutoCompleteSearch');
    my $SearchType         = $AutoCompleteConfig->{SearchTypeMapping}->{ $Self->{Action} . ":::" . $Param{Name} } || '';

    if ($SearchType) {

        # get UserPreferences
        %UserPreferences = $Kernel::OM->Get('Kernel::System::User')
            ->GetPreferences( UserID => $Self->{UserID} );
    }

    # just show a simple list
    if (
        $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::ListType') eq 'list'
        || (
            $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' }
            && $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' } eq 'AutoComplete'
        )
    ) {
        # transform data from Hash in Array because of ordering in frontend by Queue name
        # it was a problem wit name like '(some_queue)'
        my %QueueDataHash = %{ $Param{Data} || {} };

        # get StandardResponsesStrg
        my %ReverseQueueDataHash = reverse %QueueDataHash;
        my @QueueDataArray       = map {
            {
                Key   => $ReverseQueueDataHash{$_},
                Value => $_
            }
        } sort values %QueueDataHash;

        # find index of first element in array @QueueDataArray for displaying in frontend
        # at the top should be element with ' $QueueDataArray[$_]->{Key} = 0' like "- Move -"
        # when such element is found, it is moved at the top
        my ($FirstElementIndex) = grep( {$QueueDataArray[$_]->{Key} == 0} 0 .. $#QueueDataArray || 0 );
        splice( @QueueDataArray, 0, 0, splice( @QueueDataArray, $FirstElementIndex, 1 ) );
        $Param{Data} = \@QueueDataArray;

        $Param{MoveQueuesStrg} = $Self->BuildSelection(
            %Param,
            HTMLQuote     => 0,
            SelectedID    => $Param{SelectedID} || $Param{SelectedIDRefArray} || '',
            SelectedValue => $Param{Selected},
            Translation   => 0,
        );
        return $Param{MoveQueuesStrg};
    }

    # build tree list
    $Param{MoveQueuesStrg} = '<select name="'
        . $Param{Name}
        . '" id="'
        . $Param{Name}
        . '" class="'
        . $Class
        . '" data-tree="true"'
        . " $Size $Multiple $OnChangeSubmit>\n";
    my %UsedData;
    my %Data;

    if ( $Param{Data} && ref $Param{Data} eq 'HASH' ) {
        %Data = %{ $Param{Data} };
    }
    else {
        return 'Need Data Ref in AgentQueueListOption()!';
    }

    # add suffix for correct sorting
    my $KeyNoQueue;
    my $ValueNoQueue;
    my $MoveStr           = $Self->{LanguageObject}->Translate('Move');
    my $ValueOfQueueNoKey = "- " . $MoveStr . " -";
    DATA:
    for ( sort { $Data{$a} cmp $Data{$b} } keys %Data ) {

        # find value for default item in select box
        # it can be "-" or "Move"
        if (
            $Data{$_} eq "-"
            || $Data{$_} eq $ValueOfQueueNoKey
        ) {
            $KeyNoQueue   = $_;
            $ValueNoQueue = $Data{$_};
            next DATA;
        }
        $Data{$_} .= '::';
    }

    # get HTML utils object
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

    # set default item of select box
    if ($ValueNoQueue) {
        $Param{MoveQueuesStrg} .= '<option value="'
            . $HTMLUtilsObject->ToHTML( String => $KeyNoQueue )
            . '">'
            . $ValueNoQueue
            . "</option>\n";
    }

    # build selection string
    KEY:
    for ( sort { $Data{$a} cmp $Data{$b} } keys %Data ) {

        # default item of select box has set already
        next KEY if ( $Data{$_} eq "-" || $Data{$_} eq $ValueOfQueueNoKey );

        my @Queue = split( /::/, $Param{Data}->{$_} );
        $UsedData{ $Param{Data}->{$_} } = 1;
        my $UpQueue = $Param{Data}->{$_};
        $UpQueue =~ s/^(.*)::.+?$/$1/g;
        if ( !$Queue[$MaxLevel] && $Queue[-1] ne '' ) {
            $Queue[-1] = $Self->Ascii2Html(
                Text => $Queue[-1],
                Max  => 50 - $#Queue
            );
            my $Space = '';
            for ( my $i = 0; $i < $#Queue; $i++ ) {
                $Space .= '&nbsp;&nbsp;';
            }

            # check if SelectedIDRefArray exists
            if ($SelectedIDRefArray) {
                for my $ID ( @{$SelectedIDRefArray} ) {
                    if ( $ID eq $_ ) {
                        $Param{SelectedIDRefArrayOK}->{$_} = 1;
                    }
                }
            }

            if ( !$UsedData{$UpQueue} ) {

                # integrate the not selectable parent and root queues of this queue
                # useful for ACLs and complex permission settings
                for my $Index ( 0 .. ( scalar @Queue - 2 ) ) {

                    # get the Full Queue Name (with all its parents separated by '::') this will
                    # make a unique name and will be used to set the %DisabledQueueAlreadyUsed
                    # using unique names will prevent erroneous hide of Sub-Queues with the
                    # same name, refer to bug#8148
                    my $FullQueueName;
                    for my $Counter ( 0 .. $Index ) {
                        $FullQueueName .= $Queue[$Counter];
                        if ( int $Counter < int $Index ) {
                            $FullQueueName .= '::';
                        }
                    }

                    if ( !$UsedData{$FullQueueName} ) {
                        my $DSpace               = '&nbsp;&nbsp;' x $Index;
                        my $OptionTitleHTMLValue = '';
                        if ($OptionTitle) {
                            my $HTMLValue = $HTMLUtilsObject->ToHTML(
                                String => $Queue[$Index],
                            );
                            $OptionTitleHTMLValue = ' title="' . $HTMLValue . '"';
                        }
                        $Param{MoveQueuesStrg}
                            .= '<option value="-" disabled="disabled"'
                            . $OptionTitleHTMLValue
                            . '>'
                            . $DSpace
                            . $Queue[$Index]
                            . "</option>\n";
                        $UsedData{$FullQueueName} = 1;
                    }
                }
            }

            # create selectable elements
            my $String               = $Space . $Queue[-1];
            my $OptionTitleHTMLValue = '';
            if ($OptionTitle) {
                my $HTMLValue = $HTMLUtilsObject->ToHTML(
                    String => $Queue[-1],
                );
                $OptionTitleHTMLValue = ' title="' . $HTMLValue . '"';
            }
            my $HTMLValue = $HTMLUtilsObject->ToHTML(
                String => $_,
            );
            if (
                $SelectedID eq $_
                || $Selected eq $Param{Data}->{$_}
                || $Param{SelectedIDRefArrayOK}->{$_}
            ) {
                $Param{MoveQueuesStrg}
                    .= '<option selected="selected" value="'
                    . $HTMLValue . '"'
                    . $OptionTitleHTMLValue . '>'
                    . $String
                    . "</option>\n";
            }
            elsif ( $CurrentQueueID eq $_ ) {
                $Param{MoveQueuesStrg}
                    .= '<option value="-" disabled="disabled"'
                    . $OptionTitleHTMLValue . '>'
                    . $String
                    . "</option>\n";
            }
            else {
                $Param{MoveQueuesStrg}
                    .= '<option value="'
                    . $HTMLValue . '"'
                    . $OptionTitleHTMLValue . '>'
                    . $String
                    . "</option>\n";
            }
        }
    }
    $Param{MoveQueuesStrg} .= "</select>\n";

    if ( $Param{TreeView} ) {
        my $TreeSelectionMessage = $Self->{LanguageObject}->Translate("Show Tree Selection");
        $Param{MoveQueuesStrg}
            .= ' <a href="#" title="'
            . $TreeSelectionMessage
            . '" class="ShowTreeSelection"><span>'
            . $TreeSelectionMessage . '</span><i class="fa fa-sitemap"></i></a>';
    }

    return $Param{MoveQueuesStrg};
}

=item ArticleQuote()

get body and attach e. g. inline documents and/or attach all attachments to
upload cache

for forward or split, get body and attach all attachments

    my $HTMLBody = $LayoutObject->ArticleQuote(
        TicketID           => 123,
        ArticleID          => 123,
        FormID             => $Self->{FormID},
        UploadCacheObject   => $Self->{UploadCacheObject},
        AttachmentsInclude => 1,
    );

or just for including inline documents to upload cache

    my $HTMLBody = $LayoutObject->ArticleQuote(
        TicketID           => 123,
        ArticleID          => 123,
        FormID             => $Self->{FormID},
        UploadCacheObject  => $Self->{UploadCacheObject},
        AttachmentsInclude => 0,
    );

Both will also work without rich text (if $ConfigObject->Get('Frontend::RichText')
is false), return param will be text/plain instead.

=cut

sub ArticleQuote {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID ArticleID FormID UploadCacheObject)) {
        if ( !$Param{$_} ) {
            $Self->FatalError( Message => "Need $_!" );
        }
    }

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # body preparation for plain text processing
    if ( $ConfigObject->Get('Frontend::RichText') ) {

        my $Body = '';

        # check for html body
        my @ArticleBox = $TicketObject->ArticleContentIndex(
            TicketID                   => $Param{TicketID},
            StripPlainBodyAsAttachment => 3,
            UserID                     => $Self->{UserID},
            DynamicFields              => 0,
        );

        my %NotInlineAttachments;
        ARTICLE:
        for my $ArticleTmp (@ArticleBox) {

            # search for article to answer (reply article)
            next ARTICLE if $ArticleTmp->{ArticleID} ne $Param{ArticleID};

            # check if no html body exists
            last ARTICLE if !$ArticleTmp->{AttachmentIDOfHTMLBody};

            my %AttachmentHTML = $TicketObject->ArticleAttachment(
                ArticleID => $ArticleTmp->{ArticleID},
                FileID    => $ArticleTmp->{AttachmentIDOfHTMLBody},
                UserID    => $Self->{UserID},
            );
            my $Charset = $AttachmentHTML{ContentType} || '';
            $Charset =~ s/.+?charset=("|'|)(\w+)/$2/gi;
            $Charset =~ s/"|'//g;
            $Charset =~ s/(.+?);.*/$1/g;

            # convert html body to correct charset
            $Body = $Kernel::OM->Get('Kernel::System::Encode')->Convert(
                Text  => $AttachmentHTML{Content},
                From  => $Charset,
                To    => $Self->{UserCharset},
                Check => 1,
            );

            # get HTML utils object
            my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

            # add url quoting
            $Body = $HTMLUtilsObject->LinkQuote(
                String => $Body,
            );

            # strip head, body and meta elements
            $Body = $HTMLUtilsObject->DocumentStrip(
                String => $Body,
            );

            # display inline images if exists
            my $SessionID = '';
            if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
                $SessionID = ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
            }
            my $AttachmentLink = $Self->{Baselink}
                . 'Action=PictureUpload'
                . ';FormID='
                . $Param{FormID}
                . $SessionID
                . ';ContentID=';

            # search inline documents in body and add it to upload cache
            my %Attachments = %{ $ArticleTmp->{Atms} };
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
                        ArticleID => $Param{ArticleID},
                        FileID    => $AttachmentID,
                        UserID    => $Self->{UserID},
                    );

                    # content id cleanup
                    $AttachmentPicture{ContentID} =~ s/^<//;
                    $AttachmentPicture{ContentID} =~ s/>$//;

                    # find cid, add attachment URL and remember, file is already uploaded
                    $ContentID = $AttachmentLink . $Self->LinkEncode( $AttachmentPicture{ContentID} );

                    # add to upload cache if not uploaded and remember
                    if (!$AttachmentAlreadyUsed{$AttachmentID}) {

                        # remember
                        $AttachmentAlreadyUsed{$AttachmentID} = 1;

                        # write attachment to upload cache
                        $Param{UploadCacheObject}->FormIDAddFile(
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

            # find inline images using Content-Location instead of Content-ID
            ATTACHMENT:
            for my $AttachmentID ( sort keys %Attachments ) {

                next ATTACHMENT if !$Attachments{$AttachmentID}->{ContentID};

                # get whole attachment
                my %AttachmentPicture = $TicketObject->ArticleAttachment(
                    ArticleID => $Param{ArticleID},
                    FileID    => $AttachmentID,
                    UserID    => $Self->{UserID},
                );

                # content id cleanup
                $AttachmentPicture{ContentID} =~ s/^<//;
                $AttachmentPicture{ContentID} =~ s/>$//;

                $Body =~ s{
                    ("|')(\Q$AttachmentPicture{ContentID}\E)("|'|>|\/>|\s)
                }
                {
                    my $Start= $1;
                    my $ContentID = $2;
                    my $End = $3;

                    # find cid, add attachment URL and remember, file is already uploaded
                    $ContentID = $AttachmentLink . $Self->LinkEncode( $AttachmentPicture{ContentID} );

                    # add to upload cache if not uploaded and remember
                    if (!$AttachmentAlreadyUsed{$AttachmentID}) {

                        # remember
                        $AttachmentAlreadyUsed{$AttachmentID} = 1;

                        # write attachment to upload cache
                        $Param{UploadCacheObject}->FormIDAddFile(
                            FormID      => $Param{FormID},
                            Disposition => 'inline',
                            %{ $Attachments{$AttachmentID} },
                            %AttachmentPicture,
                        );
                    }

                    # return link
                    $Start . $ContentID . $End;
                }egxi;
            }

            # find not inline images
            ATTACHMENT:
            for my $AttachmentID ( sort keys %Attachments ) {
                next ATTACHMENT if $AttachmentAlreadyUsed{$AttachmentID};
                $NotInlineAttachments{$AttachmentID} = 1;
            }

            # do no more article
            last ARTICLE;
        }

        # attach also other attachments on article forward
        if ( $Body && $Param{AttachmentsInclude} ) {
            for my $AttachmentID ( sort keys %NotInlineAttachments ) {
                my %Attachment = $TicketObject->ArticleAttachment(
                    ArticleID => $Param{ArticleID},
                    FileID    => $AttachmentID,
                    UserID    => $Self->{UserID},
                );

                # add attachment
                $Param{UploadCacheObject}->FormIDAddFile(
                    FormID => $Param{FormID},
                    %Attachment,
                    Disposition => 'attachment',
                );
            }
        }
        return $Body if $Body;
    }

    # as fallback use text body for quote
    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{ArticleID},
        DynamicFields => 0,
    );

    # check if original content isn't text/plain or text/html, don't use it
    if ( !$Article{ContentType} ) {
        $Article{ContentType} = 'text/plain';
    }

    if ( $Article{ContentType} !~ /text\/(?:plain|html)/i ) {
        $Article{Body}        = '-> no quotable message <-';
        $Article{ContentType} = 'text/plain';
    }
    else {
        $Article{Body} = $Self->WrapPlainText(
            MaxCharacters => $ConfigObject->Get('Ticket::Frontend::TextAreaEmail') || 82,
            PlainText => $Article{Body},
        );
    }

    # attach attachments
    if ( $Param{AttachmentsInclude} ) {
        my %ArticleIndex = $TicketObject->ArticleAttachmentIndex(
            ArticleID                  => $Param{ArticleID},
            UserID                     => $Self->{UserID},
            StripPlainBodyAsAttachment => 3,
            Article                    => \%Article,
        );
        for my $Index ( sort keys %ArticleIndex ) {
            my %Attachment = $TicketObject->ArticleAttachment(
                ArticleID => $Param{ArticleID},
                FileID    => $Index,
                UserID    => $Self->{UserID},
            );

            # add attachment
            $Param{UploadCacheObject}->FormIDAddFile(
                FormID => $Param{FormID},
                %Attachment,
                Disposition => 'attachment',
            );
        }
    }

    # return body as html
    if ( $ConfigObject->Get('Frontend::RichText') ) {

        $Article{Body} = $Self->Ascii2Html(
            Text           => $Article{Body},
            HTMLResultMode => 1,
            LinkFeature    => 1,
        );
    }

    # return body as plain text
    return $Article{Body};
}

sub TicketListShow {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    # take object ref to local, remove it from %Param (prevent memory leak)
    my $Env = $Param{Env};
    delete $Param{Env};

    # lookup latest used view mode
    if ( !$Param{View} && $Self->{ 'UserTicketOverview' . $Env->{Action} } ) {
        $Param{View} = $Self->{ 'UserTicketOverview' . $Env->{Action} };
    }

    # set default view mode to 'small'
    my $View = $Param{View} || 'Small';

    # set default view mode for AgentTicketQueue or AgentTicketService
    if (
        !$Param{View}
        && (
            $Env->{Action} eq 'AgentTicketQueue'
            || $Env->{Action} eq 'AgentTicketService'
        )
    ) {
        $View = 'Preview';
    }

    # store latest view mode
    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'UserTicketOverview' . $Env->{Action},
        Value     => $View,
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # update preferences if needed
    my $Key = 'UserTicketOverview' . $Env->{Action};

    my $LastView = $Self->{$Key} || '';

    # if ( !$ConfigObject->Get('DemoSystem') && $Self->{$Key} ne $View ) {
    if ( !$ConfigObject->Get('DemoSystem') && $LastView ne $View ) {

        $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Key,
            Value  => $View,
        );
    }

    # check backends
    my $Backends = $ConfigObject->Get('Ticket::Frontend::Overview');
    if ( !$Backends ) {
        return $Self->FatalError(
            Message => 'Need config option Ticket::Frontend::Overview',
        );
    }
    if ( ref $Backends ne 'HASH' ) {
        return $Self->FatalError(
            Message => 'Config option Ticket::Frontend::Overview need to be HASH ref!',
        );
    }

    # check if selected view is available
    if ( !$Backends->{$View} ) {

        # try to find fallback, take first configured view mode
        KEY:
        for my $Key ( sort keys %{$Backends} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No Config option found for view mode $View, took $Key instead!",
            );
            $View = $Key;
            last KEY;
        }
    }

    # load overview backend module
    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Backends->{$View}->{Module} ) ) {
        return $Self->FatalError(
            Message => 'Can not load overview backend ' . $Backends->{$View}->{Module},
        );
    }
    my $Object = $Backends->{$View}->{Module}->new( %{$Env} );
    return if !$Object;

    # retireve filter values
    if ( $Param{FilterContentOnly} ) {
        return $Object->FilterContent(
            %Param,
        );
    }

    # run action row backend module
    $Param{ActionRow} = $Object->ActionRow(
        %Param,
        Config => $Backends->{$View},
    );

    # run overview backend module
    $Param{SortOrderBar} = $Object->SortOrderBar(
        %Param,
        Config => $Backends->{$View},
    );

    # check start option, if higher then tickets available, set
    # it to the last ticket page (Thanks to Stefan Schmidt!)
    my $StartHit = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'StartHit' ) || 1;

    # get personal page shown count
    my $PageShownPreferencesKey = 'UserTicketOverview' . $View . 'PageShown';
    my $PageShown               = $Self->{$PageShownPreferencesKey} || 10;
    my $Group                   = 'TicketOverview' . $View . 'PageShown';

    # get data selection
    my %Data;
    my $Config = $ConfigObject->Get('PreferencesGroups');
    if ( $Config && $Config->{$Group} && $Config->{$Group}->{Data} ) {
        %Data = %{ $Config->{$Group}->{Data} };
    }

    # calculate max. shown per page
    if ( $StartHit > $Param{Total} ) {
        my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
        $StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
    }


    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UploadCacheObject   = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    my $SelectedItemStrg  = $ParamObject->GetParam( Param => 'SelectedItems' ) || '';
    my @SelectedItems     = split(',', $SelectedItemStrg);
    my %SelectedItemsHash = map( { $_ => 1 } @SelectedItems );
    my @UnselectedItems   = ();

    for my $TicketID ( @{$Param{OriginalTicketIDs}} ) {
        if ( !$SelectedItemsHash{ $TicketID } ) {
            push(@UnselectedItems, $TicketID);
        }
    }
    my $UnselectedItemStrg = join(',', @UnselectedItems) || '';

    if ( !$Self->{FormID} ) {
        $Self->{FormID} = $UploadCacheObject->FormIDCreate();
    }

    # build nav bar
    my $Limit   = $Param{Limit} || 20_000;
    my %PageNav = $Self->PageNavBar(
        Limit               => $Limit,
        StartHit            => $StartHit,
        PageShown           => $PageShown,
        AllHits             => $Param{Total} || 0,
        Action              => 'Action=' . $Self->{Action},
        Link                => $Param{LinkPage},
        IDPrefix            => $Self->{Action},
        SelectedItems       => $SelectedItemStrg,
        UnselectedItems     => $UnselectedItemStrg,
        FormID              => $Self->{FormID}
    );

    # build shown ticket per page
    # this results in a re-open of the search dialog if someone uses the context settings after a ticket search
    $Param{RequestedURL}
        = $Kernel::OM->Get('Kernel::System::Web::Request')->{Query}->url( -query_string => 1 )
        || "Action=$Self->{Action}";

    $Param{Group}           = $Group;
    $Param{PreferencesKey}  = $PageShownPreferencesKey;
    $Param{PageShownString} = $Self->BuildSelection(
        Name        => $PageShownPreferencesKey,
        SelectedID  => $PageShown,
        Translation => 0,
        Data        => \%Data,
        Sort        => 'NumericValue',
    );

    # nav bar at the beginning of a overview
    $Param{View} = $View;
    $Self->Block(
        Name => 'OverviewNavBar',
        Data => \%Param,
    );

    # back link
    if ( $Param{LinkBack} ) {
        $Self->Block(
            Name => 'OverviewNavBarPageBack',
            Data => \%Param,
        );
    }

    # filter selection
    if ( $Param{Filters} ) {
        my @NavBarFilters;
        for my $Prio ( sort keys %{ $Param{Filters} } ) {
            push @NavBarFilters, $Param{Filters}->{$Prio};
        }
        $Self->Block(
            Name => 'OverviewNavBarFilter',
            Data => {
                %Param,
            },
        );
        my $Count = 0;
        for my $Filter (@NavBarFilters) {
            $Count++;
            if ( $Count == scalar @NavBarFilters ) {
                $Filter->{CSS} = 'Last';
            }
            $Self->Block(
                Name => 'OverviewNavBarFilterItem',
                Data => {
                    %Param,
                    %{$Filter},
                },
            );
            if ( $Filter->{Filter} eq $Param{Filter} ) {
                $Self->Block(
                    Name => 'OverviewNavBarFilterItemSelected',
                    Data => {
                        %Param,
                        %{$Filter},
                    },
                );
            }
            else {
                $Self->Block(
                    Name => 'OverviewNavBarFilterItemSelectedNot',
                    Data => {
                        %Param,
                        %{$Filter},
                    },
                );
            }
        }
    }

    # view mode
    for my $Backend (
        sort { $Backends->{$a}->{ModulePriority} <=> $Backends->{$b}->{ModulePriority} }
        keys %{$Backends}
    ) {

        $Self->Block(
            Name => 'OverviewNavBarViewMode',
            Data => {
                %Param,
                %{ $Backends->{$Backend} },
                Filter => $Param{Filter},
                View   => $Backend,
            },
        );
        if ( $View eq $Backend ) {
            $Self->Block(
                Name => 'OverviewNavBarViewModeSelected',
                Data => {
                    %Param,
                    %{ $Backends->{$Backend} },
                    Filter => $Param{Filter},
                    View   => $Backend,
                },
            );
        }
        else {
            $Self->Block(
                Name => 'OverviewNavBarViewModeNotSelected',
                Data => {
                    %Param,
                    %{ $Backends->{$Backend} },
                    Filter => $Param{Filter},
                    View   => $Backend,
                },
            );
        }
    }

    if (%PageNav) {
        $Self->Block(
            Name => 'OverviewNavBarPageNavBar',
            Data => \%PageNav,
        );

        # don't show context settings in AJAX case (e. g. in customer ticket history),
        #   because the submit with page reload will not work there
        if ( !$Param{AJAX} ) {
            $Self->Block(
                Name => 'ContextSettings',
                Data => {
                    %PageNav,
                    %Param,
                },
            );

            # show column filter preferences
            if ( $View eq 'Small' ) {

                # set preferences keys
                my $PrefKeyColumns = 'UserFilterColumnsEnabled' . '-' . $Env->{Action};

                # create extra needed objects
                my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

                # configure columns
                my @ColumnsEnabled = @{ $Object->{ColumnsEnabled} };
                my @ColumnsAvailable;

                for my $ColumnName ( sort { $a cmp $b } @{ $Object->{ColumnsAvailable} } ) {
                    if ( !grep { $_ eq $ColumnName } @ColumnsEnabled ) {
                        push @ColumnsAvailable, $ColumnName;
                    }
                }

                my %Columns;

                # for my $ColumnName ( sort @ColumnsAvailable ) {
                for my $ColumnName (@ColumnsAvailable) {

                    $Columns{Columns}->{$ColumnName}
                        = ( grep { $ColumnName eq $_ } @ColumnsEnabled ) ? 1 : 0;
                }

                $Self->Block(
                    Name => 'FilterColumnSettings',
                    Data => {
                        Columns          => $JSONObject->Encode( Data => \%Columns ),
                        ColumnsEnabled   => $JSONObject->Encode( Data => \@ColumnsEnabled ),
                        ColumnsAvailable => $JSONObject->Encode( Data => \@ColumnsAvailable ),
                        NamePref         => $PrefKeyColumns,
                        Desc             => 'Shown Columns',
                        Name             => $Env->{Action},
                        View             => $View,
                        GroupName        => 'TicketOverviewFilterSettings',
                        %Param,
                    },
                );
            }
            }    # end show column filters preferences

            # check if there was stored filters, and print a link to delete them
            if ( IsHashRefWithData( $Object->{StoredFilters} ) ) {
            $Self->Block(
                    Name => 'DocumentActionRowRemoveColumnFilters',
                    Data => {
                        CSS => "ContextSettings RemoveFilters",
                        %Param,
                    },
                );
        }
    }

    if ( $Param{NavBar} ) {
        if ( $Param{NavBar}->{MainName} ) {
            $Self->Block(
                Name => 'OverviewNavBarMain',
                Data => $Param{NavBar},
            );
        }
    }

    my $OutputNavBar = $Self->Output(
        TemplateFile => 'AgentTicketOverviewNavBar',
        Data         => { %Param, },
    );
    my $OutputRaw = '';
    if ( !$Param{Output} ) {
        $Self->Print( Output => \$OutputNavBar );
    }
    else {
        $OutputRaw .= $OutputNavBar;
    }

    # run overview backend module
    my $Output = $Object->Run(
        %Param,
        Config          => $Backends->{$View},
        Limit           => $Limit,
        StartHit        => $StartHit,
        PageShown       => $PageShown,
        AllHits         => $Param{Total} || 0,
        Output          => $Param{Output} || '',
        SelectedItems   => \@SelectedItems,
        UnselectedItems => \@UnselectedItems,
    );
    if ( !$Param{Output} ) {
        $Self->Print( Output => \$Output );
    }
    else {
        $OutputRaw .= $Output;
    }

    return $OutputRaw;
}

sub TicketMetaItemsCount {
    my ( $Self, %Param ) = @_;
    return ( 'Priority', 'New Article' );
}

sub TicketMetaItems {
    my ( $Self, %Param ) = @_;

    my %ActiveColums = (
        'Priority'    => 1,
        'New Article' => 1,
        'Locked'      => 0,
        'Watcher'     => 0,
    );

    if ( $Param{ViewableColumns} && ref( $Param{ViewableColumns} ) eq 'ARRAY' ) {
        my @ViewableColumns = @{ $Param{ViewableColumns} };
        $ActiveColums{'Priority'}    = 0;
        $ActiveColums{'New Article'} = 0;
        $ActiveColums{'Locked'}      = 0;
        $ActiveColums{'Watcher'}     = 0;
        for my $Columns (@ViewableColumns) {
            $ActiveColums{$Columns} = 1;
        }
    }

    if ( ref $Param{Ticket} ne 'HASH' ) {
        $Self->FatalError( Message => 'Need Hash ref in Ticket param!' );
    }

    # return attributes
    my @Result;

    # show priority
    if ( $ActiveColums{'Priority'} ) {
        push( @Result, {
            Title      => $Param{Ticket}->{Priority},
            Class      => 'Flag',
            ClassSpan  => 'PriorityID-' . $Param{Ticket}->{PriorityID},
            ClassTable => 'Flags',
        });
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket = $TicketObject->TicketGet( TicketID => $Param{Ticket}->{TicketID} );

    # Show if new message is in there, but show archived tickets as read.
    my %TicketFlag;
    if ( $Ticket{ArchiveFlag} ne 'y' ) {
        %TicketFlag = $TicketObject->TicketFlagGet(
            TicketID => $Param{Ticket}->{TicketID},
            UserID   => $Self->{UserID},
        );
    }

    if (
        $ActiveColums{'New Article'}
        && (
            $Ticket{ArchiveFlag} eq 'y'
            || $TicketFlag{Seen}
        )
    ) {
        push( @Result, undef );
    }
    elsif ( $Ticket{ArchiveFlag} ne 'y' && $ActiveColums{'New Article'} ) {

        # just show ticket flags if agent belongs to the ticket
        my $ShowMeta;
        if (
            $Self->{UserID} == $Param{Ticket}->{OwnerID}
            || $Self->{UserID} == $Param{Ticket}->{ResponsibleID}
        ) {
            $ShowMeta = 1;
        }
        if ( !$ShowMeta && $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Watcher') ) {
            my %Watch = $TicketObject->TicketWatchGet(
                TicketID => $Param{Ticket}->{TicketID},
            );
            if ( $Watch{ $Self->{UserID} } ) {
                $ShowMeta = 1;
            }
        }

        # show ticket flags
        my $Image = 'meta-new-inactive.png';
        if ($ShowMeta) {
            $Image = 'meta-new.png';
            push @Result, {
                Image      => $Image,
                Title      => Translatable('Unread article(s) available'),
                Class      => 'UnreadArticles',
                ClassSpan  => 'UnreadArticles Remarkable',
                ClassTable => 'UnreadArticles',
            };
        }
        else {
            push @Result, {
                Image      => $Image,
                Title      => Translatable('Unread article(s) available'),
                Class      => 'UnreadArticles',
                ClassSpan  => 'UnreadArticles Ordinary',
                ClassTable => 'UnreadArticles',
            };
        }
    }

    return @Result;
}

sub GetTicketHighlight {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    for my $Needed ( qw(Ticket View) ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => 'GetTicketHighlight: Needed $Needed!'
            );
            return '';
        }
    }

    my $Selector = '';
    my %Ticket   = %{$Param{Ticket}};
    my $View     = $Param{View};

    my $Config = $ConfigObject->Get('KIX4OTRSTicketOverview' . $View . 'HighlightMapping');

    return '' if !$Config;

    RULE:
    for my $Key ( sort keys %{$Config} ) {
        next RULE if $Key !~ /###/;

        my ($Prio, $Restrictions) = split( /###/, $Key);

        next RULE if !$Restrictions;

        # check data match
        my @MatchRules = split( '\|\|\|', $Restrictions );
        my $MatchCount = 0;

        MATCHRULE:
        for my $MatchRule (@MatchRules) {

            my @Restriction = split( ':::', $MatchRule );

            next MATCHRULE if ( !$Restriction[0] || !$Restriction[1] );

            my @RestrictionValues = split( ';', $Restriction[1] );
            my $ConditionElement  = "";

            # type
            if (
                $Restriction[0] eq 'Type'
                && $Ticket{Type}
            ) {
                $ConditionElement = $Ticket{Type} || '';
            }

            # queue
            elsif (
                $Restriction[0] eq 'Queue'
                && $Ticket{Queue}
            ) {
                $ConditionElement = $Ticket{Queue} || '';
            }

            # service
            elsif (
                $Restriction[0] eq 'Service'
                && $Ticket{Service}
            ) {
                $ConditionElement = $Ticket{Service} || '';
            }

            # SLA
            elsif (
                $Restriction[0] eq 'SLA'
                && $Ticket{Service}
            ) {
                $ConditionElement = $Ticket{Service} || '';
            }

            # state
            elsif (
                $Restriction[0] eq 'State'
                && $Ticket{State}
            ) {
                $ConditionElement = $Ticket{State} || '';
            }

            # priority
            elsif (
                $Restriction[0] eq 'Priority'
                && $Ticket{Priority}
            ) {
                $ConditionElement = $Ticket{Priority} || '';
            }

            # user skin
            elsif (
                $Restriction[0] eq 'UserSkin'
                && $Self->{UserSkin}
            ) {
                $ConditionElement = $Self->{UserSkin} || '';
            }

            my $Match = 0;

            RESTRICTEDVALUE:
            for my $RestrictionValue (@RestrictionValues) {

                my $RegExpPatternCondition = "";
                if ( $RestrictionValue =~ /^\[regexp\](.*)$/ ) {
                    $RegExpPatternCondition = $1;
                }

                # if condition is satisfied
                if (
                    (
                        !$RegExpPatternCondition
                        && $RestrictionValue eq $ConditionElement
                    )
                    || (
                        !$RegExpPatternCondition
                        && $RestrictionValue eq 'EMPTY'
                        && !$ConditionElement
                    )
                    || (
                        $RegExpPatternCondition
                        && $ConditionElement =~ /$RegExpPatternCondition/
                    )
                ) {
                    $Match = 1;
                    $MatchCount++;

                    last RESTRICTEDVALUE;
                }
            }

            # check match of restriction
            if ( !$Match ) {
                next RULE;
            }
        }

        if ( $MatchCount == scalar(@MatchRules) ) {
            $Selector = $Prio;
            $Selector =~ s/\s+//gm;
            $Selector =~ s/[:\.,\\\/]//;
            $Selector =~ s/[+]/Plus/;
            $Selector =~ s/[-]/Minus/;
            $Selector = 'Highlight' . $View . $Selector;
        }
    }

    if ( !$Selector ) {
        RULE:
        for my $Key ( sort keys %{$Config} ) {

            next RULE if $Key =~ /###/;

            if ( $Ticket{State} eq $Key ) {
                $Selector = $Key;
                $Selector =~ s/\s+//gm;
                $Selector =~ s/[:\.,\\\/]//;
                $Selector =~ s/[+]/Plus/;
                $Selector =~ s/[-]/Minus/;
                $Selector = 'Highlight' . $View . $Selector;
                last RULE;
            }
        }
    }

    return $Selector;
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
