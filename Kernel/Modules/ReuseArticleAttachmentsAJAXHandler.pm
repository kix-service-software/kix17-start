# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::ReuseArticleAttachmentsAJAXHandler;

use strict;
use warnings;

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
    my $LogObject         = $Kernel::OM->Get('Kernel::System::Log');
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $TicketObject      = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject      = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Result;

    for my $Needed (qw(Subaction TicketID)) {
        $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "ReuseArticleAttachmentsAJAXHandler: Need $Needed !",
            );
        }
    }

    # generate output...
    if ( $Param{Subaction} eq 'LoadAttachments' ) {
        for my $Needed (qw(SearchString FormID)) {
            $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        }

        # generate output...
        $Param{ArticleAttachmentStrg} = $LayoutObject->KIXSideBarReuseArticleAttachmentsTable(
            SearchString => $Param{SearchString},
            TicketID     => $Param{TicketID}        || '',
            UserID       => $Self->{UserID}         || '',
            AJAX         => $Param{Data}->{AJAX}    || 0,
            FormID       => $Param{FormID}
        );

        return $LayoutObject->Attachment(
            ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
            Content     => $Param{ArticleAttachmentStrg} || "<br/>",
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Param{Subaction} eq 'AttachmentAdd' ) {
        for my $Needed (qw(FormID AttachmentID)) {
            $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            if ( !$Param{$Needed} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "ReuseArticleAttachmentsAJAXHandler: Need $Needed !",
                );
            }
        }

        my ( $ArticleID, $FileID ) = split( '::', $Param{AttachmentID} );
        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID => $ArticleID,
            FileID    => $FileID,
            UserID    => $Self->{UserID},
        );

        $UploadCacheObject->FormIDAddFile(
            FormID => $Param{FormID},
            %Attachment,
        );
    }
    elsif ( $Param{Subaction} eq 'AttachmentRemove' ) {
        for my $Needed (qw(FormID AttachmentID)) {
            $Param{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            if ( !$Param{$Needed} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "ReuseArticleAttachmentsAJAXHandler: Need $Needed !",
                );
            }
        }

        my ( $ArticleID, $FileID ) = split( '::', $Param{AttachmentID} );
        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID => $ArticleID,
            FileID    => $FileID,
            UserID    => $Self->{UserID},
        );

        # get all attachments meta data
        my @Attachments = $UploadCacheObject->FormIDGetAllFilesMeta(
            FormID => $Param{FormID},
        );

        foreach my $AttachmentRef (@Attachments) {
            if ( $AttachmentRef->{Filename} eq $Attachment{Filename} ) {
                $FileID = $AttachmentRef->{FileID};
                last;
            }
        }

        if ($FileID) {
            $UploadCacheObject->FormIDRemoveFile(
                FormID => $Param{FormID},
                FileID => $FileID,
            );
        }
    }

    return $LayoutObject->Attachment(
        ContentType => 'text/plain; charset=' . $LayoutObject->{Charset},
        Content     => '',
        Type        => 'inline',
        NoCache     => 1,
    );
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
