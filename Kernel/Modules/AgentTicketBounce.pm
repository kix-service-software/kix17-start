# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with patches licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::Modules::AgentTicketBounce;

use strict;
use warnings;

use Mail::Address;

our $ObjectManagerDisabled = 1;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get article ID
    $Self->{ArticleID} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'ArticleID' ) || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    for my $Needed (qw(ArticleID TicketID QueueID)) {
        if ( !defined $Self->{$Needed} ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate( '%s is needed!', $Needed ),
                Comment => Translatable('Please contact the administrator.'),
            );
        }
    }

    # get ticket data
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Ticket = $TicketObject->TicketGet( TicketID => $Self->{TicketID} );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $Config       = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

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

                $LayoutObject->Block(
                    Name => 'PropertiesLock',
                    Data => { %Param, TicketID => $Self->{TicketID} },
                );
            }
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Self->{TicketID},
                OwnerID  => $Self->{UserID},
            );
            if ( !$AccessOk ) {
                my $Output = $LayoutObject->Header(
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
            else {
                $LayoutObject->Block(
                    Name => 'TicketBack',
                    Data => {
                        %Param,
                        TicketID => $Self->{TicketID},
                    },
                );
            }
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'TicketBack',
            Data => {
                %Param,
                TicketID => $Self->{TicketID},
            },
        );
    }

    # ------------------------------------------------------------ #
    # show screen
    # ------------------------------------------------------------ #
    if ( !$Self->{Subaction} ) {

        # check if plain article exists
        if ( !$TicketObject->ArticlePlain( ArticleID => $Self->{ArticleID} ) ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate(
                    'Plain article not found for article %s!',
                    $Self->{ArticleID}
                ),
            );
        }

        # get article data
        my %Article = $TicketObject->ArticleGet(
            ArticleID     => $Self->{ArticleID},
            DynamicFields => 0,
        );

        # Check if article is from the same TicketID as we checked permissions for.
        if ( $Article{TicketID} ne $Self->{TicketID} ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate(
                    'Article does not belong to ticket %s!',
                    $Self->{TicketID}
                ),
            );
        }

        # prepare to (ReplyTo!) ...
        if ( $Article{ReplyTo} ) {
            $Article{To} = $Article{ReplyTo};
        }
        else {
            $Article{To} = $Article{From};
        }

        # get template generator object
        my $TemplateGenerator = $Kernel::OM->ObjectParamAdd(
            'Kernel::System::TemplateGenerator' => { %{$Self} }
        );
        $TemplateGenerator = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

        # prepare salutation
        $Param{Salutation} = $TemplateGenerator->Salutation(
            TicketID  => $Self->{TicketID},
            ArticleID => $Self->{ArticleID},
            Data      => \%Param,
            UserID    => $Self->{UserID},
        );

        # prepare signature
        $Param{Signature} = $TemplateGenerator->Signature(
            TicketID  => $Self->{TicketID},
            ArticleID => $Self->{ArticleID},
            Data      => \%Param,
            UserID    => $Self->{UserID},
        );

        # prepare bounce text
        $Param{BounceText} = $ConfigObject->Get('Ticket::Frontend::BounceText') || '';

        # make sure body is rich text
        if ( $LayoutObject->{BrowserRichText} ) {

            # prepare bounce tags
            $Param{BounceText} =~ s/<KIX_TICKET>/&lt;KIX_TICKET&gt;/g;
            $Param{BounceText} =~ s/<KIX_BOUNCE_TO>/&lt;KIX_BOUNCE_TO&gt;/g;

            $Param{BounceText} = $LayoutObject->Ascii2RichText(
                String => $Param{BounceText},
            );
        }

        # build InformationFormat
        if ( $LayoutObject->{BrowserRichText} ) {
            $Param{InformationFormat} = <<"END";
$Param{Salutation}<br/>
<br/>
$Param{BounceText}<br/>
<br/>
$Param{Signature}
END
        }
        else {
            $Param{InformationFormat} = <<"END";
$Param{Salutation}

$Param{BounceText}

$Param{Signature}
END
        }

        # prepare sender of bounce email
        my %Address = $Kernel::OM->Get('Kernel::System::Queue')->GetSystemAddress(
            QueueID => $Article{QueueID},
        );
        $Article{From} = "$Address{RealName} <$Address{Email}>";

        # get next states
        my %NextStates = $TicketObject->TicketStateList(
            Action   => $Self->{Action},
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID},
        );

        # build next states string
        if ( !$Config->{StateDefault} ) {
            $NextStates{''} = '-';
        }

        # offer empty selection if default state is not availible
        else {
            my %StateListTmp = reverse(%NextStates);
            if ( !$StateListTmp{ $Config->{StateDefault} } ) {
                $NextStates{''} = '-';
            }
        }

        $Param{NextStatesStrg} = $LayoutObject->BuildSelection(
            Data          => \%NextStates,
            Name          => 'BounceStateID',
            SelectedValue => $Config->{StateDefault},
            Class         => 'Modernize',
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

        # print form ...
        my $Output = $LayoutObject->Header(
            Value     => $Ticket{TicketNumber},
            Type      => 'Small',
            BodyClass => 'Popup',
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AgentTicketBounce',
            Data         => {
                %Param,
                %Article,
                TicketID     => $Self->{TicketID},
                ArticleID    => $Self->{ArticleID},
                TicketNumber => $Ticket{TicketNumber},
            },
        );
        $Output .= $LayoutObject->Footer(
            Type => 'Small',
        );
        return $Output;
    }

    # ------------------------------------------------------------ #
    # bounce
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Store' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get params
### Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
#        for my $Parameter (qw(From BounceTo To Subject Body InformSender BounceStateID)) {
        for my $Parameter (qw(BounceTo To Subject Body InformSender BounceStateID)) {
### EO Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
            $Param{$Parameter}
                = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Parameter ) || '';
        }

        my %Error;

        # check forward email address
        if ( !$Param{BounceTo} ) {
            $Error{'BounceToInvalid'} = 'ServerError';
            $LayoutObject->Block( Name => 'BounceToCustomerGenericServerErrorMsg' );
        }

        # get check item object
        my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

        for my $Email ( Mail::Address->parse( $Param{BounceTo} ) ) {
            my $Address = $Email->address();
            if (
                $ConfigObject->Get('CheckEmailInternalAddress')
                && $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressIsLocalAddress(
                    Address => $Address
                )
            ) {
                $LayoutObject->Block( Name => 'BounceToCustomerGenericServerErrorMsg' );
                $Error{'BounceToInvalid'} = 'ServerError';
            }

            # check email address
            elsif ( !$CheckItemObject->CheckEmail( Address => $Address ) ) {
                my $BounceToErrorMsg =
                    'BounceTo'
                    . $CheckItemObject->CheckErrorType()
                    . 'ServerErrorMsg';
                $LayoutObject->Block( Name => $BounceToErrorMsg );
                $Error{'BounceToInvalid'} = 'ServerError';
            }
        }

        if ( $Param{InformSender} ) {
            if ( !$Param{To} ) {
                $Error{'ToInvalid'} = 'ServerError';
                $LayoutObject->Block( Name => 'ToCustomerGenericServerErrorMsg' );
            }
            else {

                # check email address(es)
                for my $Email ( Mail::Address->parse( $Param{To} ) ) {
                    if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                        my $ToErrorMsg =
                            'To'
                            . $CheckItemObject->CheckErrorType()
                            . 'ServerErrorMsg';
                        $LayoutObject->Block( Name => $ToErrorMsg );
                        $Error{'ToInvalid'} = 'ServerError';
                    }
                }
            }

            if ( !$Param{Subject} ) {
                $Error{'SubjectInvalid'} = 'ServerError';
            }
            if ( !$Param{Body} ) {
                $Error{'BodyInvalid'} = 'ServerError';
            }
        }

        #check for error
        if (%Error) {

            # get next states
            my %NextStates = $TicketObject->TicketStateList(
                Action   => $Self->{Action},
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID},
            );

            # build next states string
            if ( !$Config->{StateDefault} ) {
                $NextStates{''} = '-';
            }
            $Param{NextStatesStrg} = $LayoutObject->BuildSelection(
                Data       => \%NextStates,
                Name       => 'BounceStateID',
                SelectedID => $Param{BounceStateID},
                Class      => 'Modernize',
            );

            # add rich text editor
            if ( $LayoutObject->{BrowserRichText} ) {

                # use height/width defined for this screen
                $Param{RichTextHeight} = $Config->{RichTextHeight} || 0;
                $Param{RichTextWidth}  = $Config->{RichTextWidth}  || 0;

                $LayoutObject->Block(
                    Name => 'RichText',
                );
            }

            # prepare bounce tags if body is rich text
            if ( $LayoutObject->{BrowserRichText} ) {

                # prepare bounce tags
                $Param{Body} =~ s/&lt;KIX_TICKET&gt;/&amp;lt;KIX_TICKET&amp;gt;/gi;
                $Param{Body} =~ s/&lt;KIX_BOUNCE_TO&gt;/&amp;lt;KIX_BOUNCE_TO&amp;gt;/gi;
            }

            $Param{InformationFormat} = $Param{Body};
            $Param{InformSenderChecked} = $Param{InformSender} ? 'checked="checked"' : '';

            my $Output = $LayoutObject->Header(
                Type      => 'Small',
                BodyClass => 'Popup',
            );
            $Output .= $LayoutObject->Output(
                TemplateFile => 'AgentTicketBounce',
                Data         => {
                    %Param,
                    %Error,
                    TicketID  => $Self->{TicketID},
                    ArticleID => $Self->{ArticleID},

                },
            );
            $Output .= $LayoutObject->Footer(
                Type => 'Small',
            );
            return $Output;
        }

### Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
        my $From = $Kernel::OM->Get('Kernel::System::TemplateGenerator')->Sender(
            QueueID => $Ticket{QueueID},
            UserID  => $Self->{UserID},
        );
### EO Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###

        my $Bounce = $TicketObject->ArticleBounce(
            TicketID    => $Self->{TicketID},
            ArticleID   => $Self->{ArticleID},
            UserID      => $Self->{UserID},
            To          => $Param{BounceTo},
### Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
#            From        => $Param{From},
            From        => $From,
### EO Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
            HistoryType => 'Bounce',
        );

        # error page
        if ( !$Bounce ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Can\'t bounce email!'),
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        # send customer info?
        if ( $Param{InformSender} ) {

            # set mime type
            my $MimeType = 'text/plain';
            if ( $LayoutObject->{BrowserRichText} ) {
                $MimeType = 'text/html';

                # verify html document
                $Param{Body} = $LayoutObject->RichTextDocumentComplete(
                    String => $Param{Body},
                );
            }

            # replace placeholders
            $Param{Body} =~ s/(&lt;|<)KIX_TICKET(&gt;|>)/$Ticket{TicketNumber}/g;
            $Param{Body} =~ s/(&lt;|<)KIX_BOUNCE_TO(&gt;|>)/$Param{BounceTo}/g;

            # send
            my $ArticleID = $TicketObject->ArticleSend(
                ArticleType    => 'email-external',
                SenderType     => 'agent',
                TicketID       => $Self->{TicketID},
                HistoryType    => 'Bounce',
                HistoryComment => "Bounced info to '$Param{To}'.",
### Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
#                From           => $Param{From},
                From           => $From,
### Patch licensed under the GPL-3.0, Copyright (C) 2001-2023 OTRS AG, https://otrs.com/ ###
                Email          => $Param{Email},
                To             => $Param{To},
                Subject        => $Param{Subject},
                UserID         => $Self->{UserID},
                Body           => $Param{Body},
                Charset        => $LayoutObject->{UserCharset},
                MimeType       => $MimeType,
            );

            # error page
            if ( !$ArticleID ) {
                return $LayoutObject->ErrorScreen(
                    Message => Translatable('Can\'t send email!'),
                    Comment => Translatable('Please contact the administrator.'),
                );
            }
        }

        # create internal notice for bounce action
        else {
            my $Body = $ConfigObject->Get('Frontend::Agent::AutomaticBounceText')
                || 'Bounced';
            $Body =~ s/(&lt;|<)KIX_TICKET(&gt;|>)/$Ticket{TicketNumber}/g;
            $Body =~ s/(&lt;|<)KIX_BOUNCE_TO(&gt;|>)/$Param{BounceTo}/g;

            # set mime type
            my $MimeType = 'text/plain';
            if ( $ConfigObject->Get('Frontend::RichText') ) {
                $MimeType = 'text/html';

                # verify html document
                $Body = $LayoutObject->RichTextDocumentComplete(
                    String => $Body,
                );
            }

            my $ArticleID = $TicketObject->ArticleCreate(
                TicketID       => $Self->{TicketID},
                ArticleType    => 'note-external',
                SenderType     => 'agent',
                Subject        => $LayoutObject->{LanguageObject}->Translate('Ticket bounced'),
                Body           => $Body,
                Charset        => $LayoutObject->{UserCharset},
                MimeType       => $MimeType,
                UserID         => $Self->{UserID},
                HistoryType    => 'AddNote',
                HistoryComment => '%%Note',
                NoAgentNotify  => 1,
            );

            # error page
            if ( !$ArticleID ) {
                return $LayoutObject->ErrorScreen(
                    Message => "Can't create note for bounce action!",
                    Comment => 'Please contact the admin.',
                );
            }
        }

        # check if there is a chosen bounce state id
        if ( $Param{BounceStateID} ) {

            # set state
            my %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
                ID => $Param{BounceStateID},
            );
            $TicketObject->TicketStateSet(
                TicketID  => $Self->{TicketID},
                ArticleID => $Self->{ArticleID},
                StateID   => $Param{BounceStateID},
                UserID    => $Self->{UserID},
            );

            # should i set an unlock?
            if ( $StateData{TypeName} =~ /^close/i ) {
                $TicketObject->TicketLockSet(
                    TicketID => $Self->{TicketID},
                    Lock     => 'unlock',
                    UserID   => $Self->{UserID},
                );
            }

            # redirect
            if ( $StateData{TypeName} =~ /^close/i ) {
                return $LayoutObject->PopupClose(
                    URL => ( $Self->{LastScreenOverview} || 'Action=AgentDashboard' ),
                );
            }
        }
        return $LayoutObject->PopupClose(
            URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID};ArticleID=$Self->{ArticleID}",
        );
    }
    return $LayoutObject->ErrorScreen(
        Message => Translatable('Wrong Subaction!'),
        Comment => Translatable('Please contact the administrator.'),
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
