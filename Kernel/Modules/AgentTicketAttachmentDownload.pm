# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketAttachmentDownload;

use strict;
use warnings;

use File::Temp qw( tempfile tempdir );
use IO::Compress::Zip qw(:all);

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
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    # check permiisions
    my $OK = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
        LogNo    => 1,
    );
    if ( !$OK ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }
    my $TicketNumber = $TicketObject->TicketNumberLookup(
        TicketID => $Self->{TicketID},
    );

    # get ArticleID
    $Self->{ArticleID} = $ParamObject->GetParam( Param => 'ArticleID' );

    # create zip object
    my $ZipResult;
    my $ZipFilename = "Ticket_" . $TicketNumber . "_Article_" . $Self->{ArticleID} . ".zip";
    my $ZipObject;

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Self->{ArticleID},
        DynamicFields => 0,
    );

    # get all attachments from article
    my %ArticleAttachments = $TicketObject->ArticleAttachmentIndex(
        ArticleID                  => $Self->{ArticleID},
        UserID                     => 1,
        Article                    => \%Article,
        StripPlainBodyAsAttachment => 1,
    );

    if ( !%ArticleAttachments ) {
        $LogObject->Log(
            Message  => "No attachments given for this article",
            Priority => 'error',
        );
        return $LayoutObject->ErrorScreen();
    }

    #search attachments
    for my $AttachmentNr ( keys %ArticleAttachments ) {
        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID => $Self->{ArticleID},
            FileID    => $AttachmentNr,
            UserID    => $Self->{UserID},
        );

        next if ( $Attachment{Filename} eq 'file-2' );

        if ( !$ZipObject ) {
            $ZipObject = IO::Compress::Zip->new(
                \$ZipResult,
                BinModeIn => 1,
                Name      => $Attachment{Filename},
            );

            if ( !$ZipObject ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Unable to create Zip object.",
                );
                return;
            }

            $ZipObject->print( $Attachment{Content} );
            $ZipObject->flush();
        }
        else {
            $ZipObject->newStream( Name => $Attachment{Filename} );
            $ZipObject->print( $Attachment{Content} );
            $ZipObject->flush();
        }
    }
    if ($ZipObject) {
        $ZipObject->close();
    }

    # output all attachmentfiles
    return $LayoutObject->Attachment(
        Filename    => $ZipFilename,
        ContentType => 'application/unknown',
        Content     => $ZipResult,
        Type        => 'attachment',
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
