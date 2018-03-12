# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::CreateFAQEntry;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::FAQ',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::Output::HTML::Layout',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{EncodeObject} = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{FAQObject}    = $Kernel::OM->Get('Kernel::System::FAQ');
    $Self->{LinkObject}   = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{LayoutObject} = $Kernel::OM->Get('Kernel::Output::HTML::Layout');   # necessary for translations

    # create other objects if not available yet...
    if ( !$Self->{FAQObject} ) {

        # nothing to do if FAQ is not installed...
        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require('Kernel::System::FAQ') ) {
            return 0;
        }
        $Self->{FAQObject} = $Kernel::OM->Get('Kernel::System::FAQ');
    }

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if KIXFAQEntry is enabled in current article
    my %Article = $Self->{TicketObject}->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 1,
    );
    my $FAQEnabled = $Article{DynamicField_KIXFAQEntry} || 'No';

    if ( $FAQEnabled && $FAQEnabled eq 'Yes' ) {

        my $FAQEntryKey;
        my $FAQEntry;

        # check needed stuff
        for my $Needed (qw(TicketID ArticleID)) {
            if ( !$Param{Data}->{$Needed} ) {
                $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
                return;
            }
        }

        # get configuration...
        my $FAQWFConfigRef = $Self->{ConfigObject}->Get("FAQWorkflow::Basic");
        if ( !$FAQWFConfigRef || ref($FAQWFConfigRef) ne 'HASH' ) {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => "CreateFAQEntry::DefaultConfig not available - won't do anything.",
            );
            return 1;
        }
        my %FAQWFConfig = %{$FAQWFConfigRef};

        # get this article data...
        my %ThisArticle = $Self->{TicketObject}->ArticleGet(
            ArticleID => $Param{Data}->{ArticleID},
            UserID    => 1,
        );

        my %NewFAQItemData = ();

        # get FAQ-category ID...
        my $CategoryRef = $Self->{FAQObject}->CategorySearch(
            Name   => $FAQWFConfig{'DefaultCategory'},
            UserID => 1,
        );

        if ( !$CategoryRef || ref($CategoryRef) ne 'ARRAY' ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "CreateFAQEntry::DefaultCategory invalid - no FAQ-item created.",
            );
            return 0;
        }

        my @CategorieIDs = @{$CategoryRef};

        for my $CategoryID (@CategorieIDs) {
            my %CurrCat = $Self->{FAQObject}->CategoryGet(
                CategoryID => $CategoryID,
                UserID     => 1,
            );
            if ( %CurrCat && $CurrCat{Name} eq $FAQWFConfig{'DefaultCategory'} ) {
                if ( $NewFAQItemData{CategoryID} ) {
                    $Self->{LogObject}->Log(
                        Priority => 'notice',
                        Message =>
                            "CreateFAQEntry::DefaultCategory ambigous - using last found.",
                    );
                }
                $NewFAQItemData{CategoryID} = $CategoryID;
            }
        }

        if ( !$NewFAQItemData{CategoryID} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "CreateFAQEntry::DefaultCategory ("
                    . $FAQWFConfig{'DefaultCategory'}
                    . ") invalid - no FAQ-item created.",
            );
            return 0;
        }

        # get FAQ-state ID...
        my %FAQStates = $Self->{FAQObject}->StateList( UserID => 1 );
        for my $StateID ( keys(%FAQStates) ) {
            if ( $FAQStates{$StateID} eq $FAQWFConfig{'DefaultState'} ) {
                $NewFAQItemData{StateID} = $StateID;
            }
        }

        # get FAQLanguage-ID...
        my %FAQLang = $Self->{FAQObject}->LanguageList( UserID => 1, );
        my $FwdDefaultLang = $Self->{ConfigObject}->Get('DefaultLanguage') || 'en';
        for my $LangID ( keys(%FAQLang) ) {
            if ( $FAQLang{$LangID} eq $FwdDefaultLang ) {
                $NewFAQItemData{LanguageID} = $LangID;
            }
        }

        # create comment text...
        my $FAQComment =
            $Self->{LayoutObject}->{LanguageObject}->Translate("FAQ Item suggested in source ticket:")
            . "\n\n"
            . $Self->{ConfigObject}->Get('Ticket::Hook') . $ThisArticle{TicketNumber}
            . "\n\n";

        # get first article data...
        my %FirstArticle = $Self->{TicketObject}->ArticleFirstArticle(
            TicketID => $Param{Data}->{TicketID},
            UserID   => 1,
        );

        # convert article body to HTML, if used in FAQ
        my $ContentType = 'text/plain';
        if ( $Self->{ConfigObject}->Get('FAQ::Item::HTML') ) {

            # get HTML-body for ThisArticle...
            my %ArticleIndex0 = $Self->{TicketObject}->ArticleAttachmentIndex(
                ArticleID => $Param{Data}->{ArticleID},
                UserID    => 1,
            );

            $ContentType = 'text/html';

            for my $Index ( keys %ArticleIndex0 ) {
                if (
                    $ArticleIndex0{$Index}->{'Filename'} =~ /^file/
                    && $ArticleIndex0{$Index}->{'ContentType'} =~ /^text\/html/
                    )
                {
                    my %Attachment = $Self->{TicketObject}->ArticleAttachment(
                        ArticleID => $Param{Data}->{ArticleID},
                        FileID    => $Index,
                        UserID    => 1,
                    );
                    $ThisArticle{Body} = $Attachment{Content};
                    last;
                }
            }

            # get HTML-body for FirstArticle...
            my %ArticleIndex1 = $Self->{TicketObject}->ArticleAttachmentIndex(
                ArticleID => $FirstArticle{ArticleID},
                UserID    => 1,
            );
            for my $Index ( keys %ArticleIndex1 ) {
                if (
                    $ArticleIndex1{$Index}->{'Filename'} =~ /^file/
                    && $ArticleIndex1{$Index}->{'ContentType'} =~ /^text\/html/
                    )
                {
                    my %Attachment = $Self->{TicketObject}->ArticleAttachment(
                        ArticleID => $FirstArticle{ArticleID},
                        FileID    => $Index,
                        UserID    => 1,
                    );
                    $FirstArticle{Body} = $Attachment{Content};

                    # convert content to utf-8 if needed
                    if ( $Attachment{ContentType} !~ /utf-8/ ) {
                        my $Charset = 'iso-8859-1';
                        if ( $Attachment{ContentType} =~ /charset=.(.*).$/ ) {
                            $Charset = $1;
                        }
                        $FirstArticle{Body} = $Self->{EncodeObject}->Convert(
                            Text => $Attachment{Content},
                            From => $Charset,
                            To   => 'utf-8',
                        );
                    }

                    last;
                }
            }
            $FAQComment =
                $Self->{LayoutObject}->{LanguageObject}->Translate("FAQ Item suggested in source ticket:")
                . "<br /><br />"
                . "<a href=\""
                . $Self->{ConfigObject}->Get('HttpType') . "://"
                . $Self->{ConfigObject}->Get('FQDN') . "/"
                . $Self->{ConfigObject}->Get('ScriptAlias')
                . "/index.pl?Action=AgentTicketZoom&TicketID=" . $Param{Data}->{TicketID}
                . "&ArticleID=" . $Param{Data}->{ArticleID}
                . "\">"
                . $Self->{ConfigObject}->Get('Ticket::Hook') . $ThisArticle{TicketNumber}
                . "</a><br /><br />";
        }

        # add new faq item...
        $NewFAQItemData{Title}       = $ThisArticle{Title};
        $NewFAQItemData{Field1}      = $FirstArticle{Body};
        $NewFAQItemData{Field2}      = "";
        $NewFAQItemData{Field3}      = $ThisArticle{Body};
        $NewFAQItemData{Field4}      = "";
        $NewFAQItemData{Field5}      = "";
        $NewFAQItemData{Field6}      = $FAQComment;
        $NewFAQItemData{LanguageID}  = $NewFAQItemData{LanguageID} || 1;
        $NewFAQItemData{StateID}     = $NewFAQItemData{StateID} || 1;
        $NewFAQItemData{Approved}    = $FAQWFConfig{DefaultApproved} || 0;
        $NewFAQItemData{ContentType} = $ContentType;

        my $ItemID = $Self->{FAQObject}->FAQAdd(
            %NewFAQItemData,
            UserID => $ThisArticle{CreatedBy},
        );

        if ( !$ItemID ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message =>
                    "CreateFAQEntry: could not create FAQ-Item for Ticket $ThisArticle{TicketNumber}!"
                ,
            );
            return;
        }
        else {

            # copy attachments...
            my %ArticleIndex = $Self->{TicketObject}->ArticleAttachmentIndex(
                ArticleID => $Param{Data}->{ArticleID},
                UserID    => 1,
            );
            for my $Index ( keys %ArticleIndex ) {
                next if ( $ArticleIndex{$Index}->{'Filename'} =~ /^file/ );
                my $Inline     = 0;
                my %Attachment = $Self->{TicketObject}->ArticleAttachment(
                    ArticleID => $Param{Data}->{ArticleID},
                    FileID    => $Index,
                    UserID    => 1,
                );

                if( $Attachment{Disposition} eq 'inline' ) {
                    $Inline = 1;
                }

                my $AttachmentID = $Self->{FAQObject}->AttachmentAdd(
                    %Attachment,
                    ItemID => $ItemID,
                    UserID => $ThisArticle{CreatedBy},
                );

                if ( $AttachmentID
                    && $Inline
                ) {
                    my $ContentID = $Attachment{ContentID};
                    $ContentID =~ s{ > }{}xms;
                    $ContentID =~ s{ < }{}xms;

                    # picture URL in upload cache
                    my $Search =  '(src=")(cid:'.$ContentID.')(")';

                    # picture URL in FAQ attachment
                    my $Replace = $Self->{LayoutObject}->{Baselink}
                        . "Action=AgentFAQZoom;Subaction=DownloadAttachment;"
                        . "ItemID=$ItemID;FileID=$AttachmentID";

                    # rewrite picture URLs
                    FIELD:
                    for my $Number ( 1 .. 6 ) {

                        # check if field contains something
                        next FIELD if !$NewFAQItemData{"Field$Number"};

                        # remove newlines
                        $NewFAQItemData{"Field$Number"} =~ s{ [\n\r]+ }{}gxms;

                        # replace URL
                        $NewFAQItemData{"Field$Number"} =~ s{$Search}{$1$Replace$3}xms;
                    }

                    # update FAQ article without writing a history entry
                    my $Success = $Self->{FAQObject}->FAQUpdate(
                        %NewFAQItemData,
                        ItemID      => $ItemID,
                        HistoryOff  => 1,
                        ApprovalOff => 1,
                        UserID      => $ThisArticle{CreatedBy},
                    );
                }
            }

            # create link between ticket and FAQ-entry...
            if ( $Self->{ConfigObject}->Get('FAQWorkflow::CreateLink') ) {
                my $True = $Self->{LinkObject}->LinkAdd(
                    SourceObject => 'Ticket',
                    SourceKey    => $Param{Data}->{TicketID},
                    TargetObject => 'FAQ',
                    TargetKey    => $ItemID,
                    Type         => 'Normal',
                    State        => 'Valid',
                    UserID       => $ThisArticle{CreatedBy},
                );
            }
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => "CreateFAQEntry::created FAQ-Item ($ItemID).",
            );
        }
    }

    return 1;
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
