# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AsynchronousExecutor::ExternalSupplierForwarding;

use base qw(Kernel::System::AsynchronousExecutor);

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Queue',
    'Kernel::Language',
    'Kernel::System::FwdLinkedObjectData',
    'Kernel::System::CustomerUser',
    'Kernel::System::Crypt::PGP',
    'Kernel::System::Crypt::SMIME',
);

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}        = $Kernel::OM->Get('Kernel::Config');
    $Self->{TicketObject}        = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{QueueObject}         = $Kernel::OM->Get('Kernel::System::Queue');
    $Self->{CustomerUserObject}  = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{FwdLinkedObjectData} = $Kernel::OM->Get('Kernel::System::FwdLinkedObjectData');
    $Self->{LogObject}           = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{LayoutObject}        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{LanguageObject}      = $Kernel::OM->Get('Kernel::Language');
    $Self->{CryptObject}         = $Kernel::OM->Get('Kernel::System::Crypt::PGP');

    return $Self;
}

#------------------------------------------------------------------------------
# BEGIN run method
#
sub Run {
    my ( $Self, %Param ) = @_;

    my %MyJobDefinition = ();
    $MyJobDefinition{StateName} = '';
    $MyJobDefinition{Params}    = \%Param;

    my %CustomerData = ();
    my %FirstArticle = ();
    my %TicketData   = ();

    #-----------------------------------------------------------------------
    # check param data for existence...
    if ( !$MyJobDefinition{Params}->{TicketID} ) {
        $MyJobDefinition{StateName} = 'Error-ExtSuppFwd-101';
    }
    elsif ( !$MyJobDefinition{Params}->{DestMailAddress} ) {
        $MyJobDefinition{StateName} = 'Error-ExtSuppFwd-102';
    }
    elsif ( !$MyJobDefinition{Params}->{FromMailAddress} ) {
        $MyJobDefinition{StateName} = 'Error-ExtSuppFwd-103';
    }
    elsif ( !defined( $MyJobDefinition{Params}->{FirstArticleFlag} ) ) {
        $MyJobDefinition{StateName} = 'Error-ExtSuppFwd-104';
    }
    elsif ( !$MyJobDefinition{Params}->{ArticleID} ) {
        $MyJobDefinition{StateName} = 'Error-ExtSuppFwd-105';
    }

    if ( $MyJobDefinition{StateName} =~ /^Error.*/ ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message =>
                "AsynchronousExecutor::ExternalSupplierForwarding: $MyJobDefinition{StateName} !",
        );
        return {
            Success    => 0,
            ReSchedule => 0,
        };
    }

    #-----------------------------------------------------------------------
    # get some config data...
    my %FwdEmailPGPKeys =
        %{
        $Self->{ConfigObject}->Get('ExternalSupplierForwarding::ForwardEmailPGPKeys')
        };
    my $BccReceipient =
        $Self->{ConfigObject}->Get('ExternalSupplierForwarding::BCC') || '';
    my $JobDoneType =
        $Self->{ConfigObject}->Get('ExternalSupplierForwarding::DoneType') || 'Done-Delete';

    # Remove blacklisted fields
    my $CustomerUserAttrBlacklist =
        $Self->{ConfigObject}->Get('ExternalSupplierForwarding::CustomerUserAttrBlacklist') || '';

    my $Crypt = 0;

    #-----------------------------------------------------------------------
    #get ticket and article data...
    my %Ticket;
    if ( $MyJobDefinition{Params}->{TicketID} ) {
        %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $MyJobDefinition{Params}->{TicketID},
            UserID   => 1,
        );
    }

    my %ThisArticle;
    if ( $MyJobDefinition{Params}->{ArticleID} ) {
        %ThisArticle =
            $Self->{TicketObject}
            ->ArticleGet( ArticleID => $MyJobDefinition{Params}->{ArticleID}, );
    }

    if ( !keys(%Ticket) ) {
        $MyJobDefinition{StateName} = 'Error-ExtSuppFwd-110';
    }
    elsif ( !keys(%ThisArticle) ) {
        $MyJobDefinition{StateName} = 'Error-ExtSuppFwd-115';
    }

    if ( $MyJobDefinition{StateName} =~ /^Error.*/ ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message =>
                "AsynchronousExecutor::ExternalSupplierForwarding: $MyJobDefinition{StateName} !",
        );
        return {
            Success    => 0,
            ReSchedule => 0,
        };
    }

    #-------------------------------------------------------------------
    # build the fwd-mail...
    my $FwdBody        = "";
    my $DestMailAdress = $MyJobDefinition{Params}->{DestMailAddress};
    my %FromAddress =
        $Self->{QueueObject}
        ->GetSystemAddress( QueueID => $Ticket{QueueID}, );

    $FwdBody .=
        $Self->{LanguageObject}->Translate(
        'This issue/information update has automatically been forwarded to you as external supplier for'
        )
        . " "
        . $Self->{ConfigObject}->{Organization}
        . ".\n\n  "
        . $Self->{LanguageObject}->Translate('Ticket Title') . ": "
        . $Ticket{Title} . "\n  "
        . $Self->{LanguageObject}->Translate('Ticket Number') . ": ["
        . $Self->{LanguageObject}->Translate('Ticket::Hook')
        . $Ticket{TicketNumber} . "]\n\n"
        . $Self->{LanguageObject}->Translate(
        'NOTE: Please do NOT remove the processing number from your response - Thank you.'
        )
        . "\n\n"
        . "\n------------------------- "
        . $Self->{LanguageObject}->Translate('PROBLEM DESCRIPTION')
        . " -------------------------\n";

    #-------------------------------------------------------------------
    # add the attachments (except HTML-article body)...
    my @Attachments = ();
    my %ArticleIndex =
        $Self->{TicketObject}
        ->ArticleAttachmentIndex( %ThisArticle, UserID => 1, );
    for my $Index ( keys %ArticleIndex ) {
        next if ( $ArticleIndex{$Index}->{'Filename'} =~ /^file/ );
        my %Attachment = $Self->{TicketObject}->ArticleAttachment(
            %ThisArticle,
            FileID => $Index,
            UserID => 1,
        );
        push @Attachments, \%Attachment;
    }

    #-------------------------------------------------------------------
    # build bbody...
    $FwdBody .= $ThisArticle{Body} . "\n";
    $FwdBody .= "\n------------------------------ ";
    $FwdBody .= $Self->{LanguageObject}->Translate('CUSTOMER DATA');
    $FwdBody .= " ------------------------------\n";

    #-------------------------------------------------------------------
    #get customer data...
    if ( $Ticket{CustomerUserID} ) {
        my %CustomerUserData =
            $Self->{CustomerUserObject}
            ->CustomerUserDataGet( User => $Ticket{CustomerUserID}, );

        if (%CustomerUserData) {
            my @Map = @{ $CustomerUserData{Config}->{Map} };

            # check if customer company support is enabled
            if ( $CustomerUserData{Config}->{CustomerCompanySupport} ) {
                my $Map2 = $CustomerUserData{CompanyConfig}->{Map};
                if ($Map2) {
                    push( @Map, @{$Map2} );
                }
            }

            # get maximum length of label fields
            my $MaxLength = 0;
            foreach my $Field (@Map) {

                # Remove blacklisted fields
                if (
                    $CustomerUserAttrBlacklist
                    && ref($CustomerUserAttrBlacklist) eq 'ARRAY'
                    )
                {
                    next
                        if (
                        grep { $_ eq ${$Field}[0]; }
                        @{$CustomerUserAttrBlacklist}
                        );
                }

                # EO Remove blacklisted fields
                if ( ${$Field}[3] && $CustomerUserData{ ${$Field}[0] } ) {
                    if ( length( ${$Field}[1] ) > $MaxLength ) {
                        $MaxLength = length( ${$Field}[1] );
                    }
                }
            }
            foreach my $Field (@Map) {

                # Remove blacklisted fields
                if (
                    $CustomerUserAttrBlacklist
                    && ref($CustomerUserAttrBlacklist) eq 'ARRAY'
                    )
                {
                    next
                        if (
                        grep { $_ eq ${$Field}[0]; }
                        @{$CustomerUserAttrBlacklist}
                        );
                }

                # EO Remove blacklisted fields
                if ( ${$Field}[3] && $CustomerUserData{ ${$Field}[0] } ) {
                    $FwdBody .= sprintf(
                        "%" . $MaxLength . "s: %s\n",
                        $Self->{LanguageObject}->Translate( ${$Field}[1] ),
                        $CustomerUserData{ ${$Field}[0] }
                    );
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # cleaning up...
    $FwdBody =~ s/-----BEGIN PGP SIGNED MESSAGE-----\n.*\n//g;
    $FwdBody =~
        s/-----BEGIN PGP SIGNATURE-----(.|\n)+----END PGP SIGNATURE-----//g;

    #-------------------------------------------------------------------
    # retrieve related object data...
    my $RelatedObjectData = "";

    $RelatedObjectData =
        $Self->{FwdLinkedObjectData}
        ->BuildFwdContent(
        TicketID => $MyJobDefinition{Params}->{TicketID},
        );

    if ($RelatedObjectData) {
        $FwdBody .= "\n------------------------  ";
        $FwdBody .= $Self->{LanguageObject}->Translate('RELATED OBJECT DATA');
        $FwdBody .= " ------------------------\n";
        $FwdBody .= $RelatedObjectData;
        $FwdBody .=
            "\n----------------------------------------------------------------------\n";
    }

    #-------------------------------------------------------------------
    # look for a PGP-key for the receipient...
    my $AddToHistory = "The message was sent unencrypted:";
    my $Charset      = $Self->{ConfigObject}->Get('DefaultCharset');
    my @KeyRef;

    if ( !$Self->{CryptObject} ) {
        $Self->{LogObject}->Log(
            Priority => 'notice',
            Message  => "TaskHandler::ExternalSupplierForwarding - "
                . "Could not create CryptObject - sending unencrypted!",
        );
    }
    else {
        @KeyRef =
            $Self->{CryptObject}->PublicKeySearch(
            Search => $MyJobDefinition{Params}->{DestMailAddress},
            );
    }

    #(1) HIGHER PRIO: use key in special PGP key configuration...
    if ( $FwdEmailPGPKeys{ $MyJobDefinition{Params}->{DestMailAddress} } ) {
        $Crypt = {
            Type    => 'PGP',
            SubType => 'Inline',
            Key     => $FwdEmailPGPKeys{
                $MyJobDefinition{Params}
                    ->{DestMailAddress}
            },
        };
        $AddToHistory = "The message was sent encrypted:";
    }

    #(2) LOWER PRIO: use key, found for mailaddress...
    elsif (@KeyRef) {
        $Crypt = {
            Type    => 'PGP',
            SubType => 'Inline',
            Key     => $KeyRef[0]->{Key},
        };
        $AddToHistory = "The message was sent encrypted:";

    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'notice',
            Message  => "TaskHandler::ExternalSupplierForwarding - "
                . "No crypt definition found for address <"
                . "$MyJobDefinition{Params}->{DestMailAddress}> found "
                . "- sending unencrypted.",
        );
    }

    #-------------------------------------------------------------------
    # send the fwd-email...
    my $Subject =
        "FWD-Ticket ["
        . $Self->{ConfigObject}->Get('Ticket::Hook')
        . $Ticket{TicketNumber}
        . "] from "
        . $Self->{ConfigObject}->{Organization};

    my $SentArticleID = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleSend(
        TicketID       => $Ticket{TicketID},
        ArticleType    => $Self->{ConfigObject}->Get('ExternalSupplierForwarding::ArticleType') || 'email-internal',
        SenderType     => 'system',
        From           => $MyJobDefinition{Params}->{FromMailAddress},
        To             => $MyJobDefinition{Params}->{DestMailAddress},
        Bcc            => $BccReceipient || '',
        Subject        => $Subject,
        Body           => $FwdBody,
        Charset        => $Charset,
        MimeType       => 'text/plain',
        Loop           => 0,                                          # 1|0 used for bulk emails
        Attachment     => \@Attachments,
        Crypt          => $Crypt,
        HistoryType    => 'AddNote',
        HistoryComment => $AddToHistory
            . ' ticket information forwarded to external supplier.',
        NoAgentNotify => 1,
        UserID        => 1,
    );

    return {
        Success    => 1,
        ReSchedule => 0,
    };
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
