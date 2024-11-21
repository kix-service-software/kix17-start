# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketMerge;

use strict;
use warnings;

use Mail::Address;

use Kernel::Language qw(Translatable);
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

    my $Output;
    my %Error;
    my %GetParam;

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get config param
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Config->{Permission},
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }

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

    # get ticket data
    my %Ticket = $TicketObject->TicketGet( TicketID => $Self->{TicketID} );

    # get lock state && write (lock) permissions
    if ( $Config->{RequiredLock} ) {
        if ( !$TicketObject->TicketLockGet( TicketID => $Self->{TicketID} ) ) {
            $TicketObject->TicketLockSet(
                TicketID => $Self->{TicketID},
                Lock     => 'lock',
                UserID   => $Self->{UserID}
            );
            if (
                $TicketObject->TicketOwnerSet(
                    TicketID  => $Self->{TicketID},
                    UserID    => $Self->{UserID},
                    NewUserID => $Self->{UserID},
                )
            ) {

                # show lock state
                $LayoutObject->Block(
                    Name => 'PropertiesLock',
                    Data => {
                        %Param,
                        TicketID => $Self->{TicketID},
                    },
                );
            }
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Self->{TicketID},
                OwnerID  => $Self->{UserID},
            );
            if ( !$AccessOk ) {
                $Output = $LayoutObject->Header(
                    Value     => $Ticket{Number},
                    Type      => 'Small',
                    BodyClass => 'Popup',
                );
                $Output .= $LayoutObject->Warning(
                    Message => Translatable('Sorry, you need to be the ticket owner to perform this action.'),
                    Comment => Translatable('Please change the owner first.'),
                );
                $Output .= $LayoutObject->Footer(
                    Type => 'Small',
                );
                return $Output;
            }

            # show back link
            $LayoutObject->Block(
                Name => 'TicketBack',
                Data => { %Param, TicketID => $Self->{TicketID} },
            );
        }
    }
    else {

        # show back link
        $LayoutObject->Block(
            Name => 'TicketBack',
            Data => { %Param, TicketID => $Self->{TicketID} },
        );
    }

    # merge action
    if ( $Self->{Subaction} eq 'Merge' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get all parameters
        for my $Parameter (qw( From To Subject Body InformSender MainTicketNumber )) {
            $GetParam{$Parameter}
                = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Parameter ) || '';
        }

        # rewrap body if no rich text is used
        if ( $GetParam{Body} && !$LayoutObject->{BrowserRichText} ) {
            $GetParam{Body} = $LayoutObject->WrapPlainText(
                MaxCharacters => $ConfigObject->Get('Ticket::Frontend::TextAreaNote'),
                PlainText     => $GetParam{Body},
            );
        }

        # get check item object
        my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

        # removing blank spaces from the ticket number
        $CheckItemObject->StringClean(
            StringRef => \$GetParam{'MainTicketNumber'},
            TrimLeft  => 1,
            TrimRight => 1,
        );

        # check some stuff
        my $MainTicketID = $TicketObject->TicketIDLookup(
            TicketNumber => $GetParam{'MainTicketNumber'},
        );

        # check if source and target TicketID are the same (bug#8667)
        if ( $MainTicketID && $MainTicketID == $Self->{TicketID} ) {
            $LayoutObject->FatalError(
                Message => Translatable('Can\'t merge ticket with itself!'),
            );
        }

        # check for errors
        if ( !$MainTicketID ) {
            $Error{'MainTicketNumberInvalid'} = 'ServerError';
        }

        if ( $GetParam{InformSender} ) {
            for my $Parameter (qw( To Subject Body )) {
                if ( !$GetParam{$Parameter} ) {
                    $Error{ $Parameter . 'Invalid' } = 'ServerError';
                }
            }

            # check forward email address(es)
            if ( $GetParam{To} ) {
                for my $Email ( Mail::Address->parse( $GetParam{To} ) ) {
                    my $Address = $Email->address();
                    if (
                        $ConfigObject->Get('CheckEmailInternalAddress')
                        && $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressIsLocalAddress(
                            Address => $Address
                        )
                    ) {
                        $LayoutObject->Block( Name => 'ToCustomerGenericServerErrorMsg' );
                        $Error{'ToInvalid'} = 'ServerError';
                    }

                    # check email address
                    elsif ( !$CheckItemObject->CheckEmail( Address => $Address ) ) {
                        my $ToErrorMsg =
                            'To'
                            . $CheckItemObject->CheckErrorType()
                            . 'ServerErrorMsg';
                        $LayoutObject->Block( Name => $ToErrorMsg );
                        $Error{'ToInvalid'} = 'ServerError';
                    }
                }
            }
            else {
                $LayoutObject->Block( Name => 'ToCustomerGenericServerErrorMsg' );
            }
        }

        if (%Error) {
            $Output = $LayoutObject->Header(
                Type      => 'Small',
                BodyClass => 'Popup',
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

            $Param{InformSenderChecked} = $GetParam{InformSender} ? 'checked="checked"' : '';

            $Output .= $LayoutObject->Output(
                TemplateFile => 'AgentTicketMerge',
                Data         => {
                    %Param,
                    %GetParam,
                    %Ticket,
                    %Error
                },
            );
            $Output .= $LayoutObject->Footer(
                Type => 'Small',
            );
            return $Output;
        }

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # check permissions
        my $HasAccess = $TicketObject->TicketPermission(
            Type     => $Config->{Permission},
            TicketID => $MainTicketID,
            UserID   => $Self->{UserID},
        );

        # error screen, don't show ticket
        if ( !$HasAccess ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }

        # check errors
        if (
            $Self->{TicketID} == $MainTicketID
            || !$TicketObject->TicketMerge(
                    MainTicketID  => $MainTicketID,
                    MergeTicketID => $Self->{TicketID},
                    UserID        => $Self->{UserID},
                )
        ) {
            $Output = $LayoutObject->Header(
                Type      => 'Small',
                BodyClass => 'Popup',
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

            $Output .= $LayoutObject->Output(
                TemplateFile => 'AgentTicketMerge',
                Data         => {
                    %Param,
                    %Ticket
                },
            );
            $Output .= $LayoutObject->Footer(
                Type => 'Small',
            );
            return $Output;
        }
        else {

            # send customer info?
            if ( $GetParam{InformSender} ) {
                my $MimeType = 'text/plain';
                if ( $LayoutObject->{BrowserRichText} ) {
                    $MimeType = 'text/html';

                    # verify html document
                    $GetParam{Body} = $LayoutObject->RichTextDocumentComplete(
                        String => $GetParam{Body},
                    );
                }
                $GetParam{Body} =~ s/(&lt;|<)KIX_TICKET(&gt;|>)/$Ticket{TicketNumber}/g;
                $GetParam{Body}
                    =~ s/(&lt;|<)KIX_MERGE_TO_TICKET(&gt;|>)/$GetParam{'MainTicketNumber'}/g;
                my $ArticleID = $TicketObject->ArticleSend(
                    ArticleType    => 'email-external',
                    SenderType     => 'agent',
                    TicketID       => $Self->{TicketID},
                    HistoryType    => 'SendAnswer',
                    HistoryComment => "Merge info to '$GetParam{To}'.",
                    From           => $GetParam{From},
                    Email          => $GetParam{Email},
                    To             => $GetParam{To},
                    Subject        => $GetParam{Subject},
                    UserID         => $Self->{UserID},
                    Body           => $GetParam{Body},
                    Charset        => $LayoutObject->{UserCharset},
                    MimeType       => $MimeType,
                );
                if ( !$ArticleID ) {

                    # error page
                    return $LayoutObject->ErrorScreen();
                }
            }

            # redirect to merged ticket
            return $LayoutObject->PopupClose(
                URL => "Action=AgentTicketZoom;TicketID=$MainTicketID",
            );
        }
    }

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
            split( ',', $Config->{AutoCompleteTicketID}->{SearchAttribute} );

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
        ) {
            my %TicketData = $TicketObject->TicketGet(
                TicketID => $TicketID,
            );

            next if $TicketData{StateType} eq 'merged';

            push @Data, {
                SearchObjectKey   => $TicketData{TicketNumber},
                SearchObjectValue => $TicketData{Title},
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

    else {

        # get last article
        my %Article = $TicketObject->ArticleLastCustomerArticle(
            TicketID      => $Self->{TicketID},
            DynamicFields => 1,
        );

        # merge box
        $Output = $LayoutObject->Header(
            Value     => $Ticket{TicketNumber},
            Type      => 'Small',
            BodyClass => 'Popup',
        );

        # prepare salutation
        my $TemplateGenerator = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
        my $Salutation        = $TemplateGenerator->Salutation(
            TicketID  => $Self->{TicketID},
            ArticleID => $Article{ArticleID},
            Data      => {%Article},
            UserID    => $Self->{UserID},
        );

        # prepare signature
        my $Signature = $TemplateGenerator->Signature(
            TicketID  => $Self->{TicketID},
            ArticleID => $Article{ArticleID},
            Data      => {%Article},
            UserID    => $Self->{UserID},
        );

        # prepare subject ...
        $Article{Subject} = $TicketObject->TicketSubjectBuild(
            TicketNumber => $Article{TicketNumber},
            Subject      => $Article{Subject} || '',
        );

        # prepare from ...
        $Article{To} = $Article{From};

        # overwrite "To" with customer email, because "To" could be system adress, external...
        if ( $Article{CustomerUserID} ) {
            my %CustomerData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                User => $Article{CustomerUserID},
            );
            if ( %CustomerData && $CustomerData{UserEmail} ) {
                $Article{To} =
                    ( $CustomerData{UserFirstname} ) ? $CustomerData{UserFirstname} . ' ' : '';
                $Article{To} .=
                    ( $CustomerData{UserLastname} ) ? $CustomerData{UserLastname} . ' ' : '';
                $Article{To} .= '<' . $CustomerData{UserEmail} . '>';
            }
            elsif ( $Kernel::OM->Get('Kernel::System::CheckItem')->CheckEmail( Address => $Article{CustomerUserID} ) ) {
                $Article{To} = $Article{CustomerUserID};
            }
        }

        my %Address = $Kernel::OM->Get('Kernel::System::Queue')
            ->GetSystemAddress( QueueID => $Ticket{QueueID} );
        $Article{From} = "$Address{RealName} <$Address{Email}>";

        my $MergeText = $LayoutObject->{LanguageObject}->Translate(
            $ConfigObject->Get('Ticket::Frontend::MergeText')
        );

        # add salutation and signature to body
        if ( $LayoutObject->{BrowserRichText} ) {
            my $Body = $LayoutObject->Ascii2RichText(
                String => $MergeText,
            );
            $Article{Body} = $Salutation
                . '<br/><br/>'
                . $Body
                . '<br/><br/>'
                . $Signature;
        }
        else {
            $Article{Body} = $Salutation
                . "\n\n"
                . $MergeText
                . "\n\n"
                . $Signature;
        }

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

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AgentTicketMerge',
            Data         => { %Param, %Ticket, %Article, }
        );
        $Output .= $LayoutObject->Footer(
            Type => 'Small',
        );
        return $Output;
    }
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
