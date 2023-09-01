# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketQuickState;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;
use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    my $ParamObject       = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    # get needed objects# get form id
    $Self->{FormID} = $ParamObject->GetParam( Param => 'FormID' );

    # create form id
    if ( !$Self->{FormID} ) {
        $Self->{FormID} = $UploadCacheObject->FormIDCreate();
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject            = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject            = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $QuickStateObject        = $Kernel::OM->Get('Kernel::System::QuickState');
    my $StateObject             = $Kernel::OM->Get('Kernel::System::State');
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
    my $TicketObject            = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject              = $Kernel::OM->Get('Kernel::System::User');
    my $ParamObject             = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $LanguageObject = $LayoutObject->{LanguageObject};
    my $Config         = $ConfigObject->Get('Ticket::Frontend::AdminQuickState');

    # check needed stuff
    for my $Needed (qw(TicketID)) {
        if ( !$Self->{$Needed} ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate( 'Need %s!', $Needed ),
            );
        }
    }

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Config->{Permissions} || 'rw',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        return $LayoutObject->NoPermission(
            Message    => $LanguageObject->Translate("You need rw permissions!"),
            WithHeader => 'yes',
        );
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

    # check if ticket is locked
    if (
        $TicketObject->TicketLockGet(
            TicketID => $Self->{TicketID}
        )
    ) {
        my $AccessOk = $TicketObject->OwnerCheck(
            TicketID => $Self->{TicketID},
            OwnerID  => $Self->{UserID},
        );

        if ( !$AccessOk ) {
            return $LayoutObject->ErrorScreen(
                Message => $LanguageObject->Translate('Sorry, you need to be the ticket owner to perform this action.'),
                Comment => $LanguageObject->Translate('Please change the owner first.'),
            );
        }
    }

    # ticket attributes
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
    );

    # valid state list
    my %StateList = $TicketObject->TicketStateList(
        UserID   => $Self->{UserID},
        TicketID => $Self->{TicketID},
    );

    # get params
    my %GetParam;
    for my $Parameter (
        qw(QuickStateID)
    ) {
        $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
    }

    # if QuickStateID not zero
    if ( !$GetParam{QuickStateID} ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }

    # get all valid quick states
    my %QuickStateList = $QuickStateObject->QuickStateList(
        Valid => 1
    );

    if (
        $GetParam{QuickStateID}
        && !exists $QuickStateList{ $GetParam{QuickStateID} }
    ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }

    # get quick state data
    my %QuickStateData = $QuickStateObject->QuickStateGet(
        ID => $GetParam{QuickStateID}
    );

    if ( ref $QuickStateData{Config} ne 'HASH') {
        $QuickStateData{Config} = {};
    }

    if ( $StateList{$QuickStateData{StateID}} ) {
        # prepare return url
        my $ReturnURL = 'Action=AgentTicketZoom;TicketID=' . $Self->{TicketID};

        # check if article should be created
        if ( $QuickStateData{Config}->{UsedArticle} ) {
            # get all attachments of the quick state
            my @Attachments = $QuickStateObject->QuickStateAttachmentList(
                QuickStateID => $GetParam{QuickStateID},
            );

            # replace placeholder in body
            $QuickStateData{Config}->{Body} = $TemplateGeneratorObject->ReplacePlaceHolder(
                Text     => $QuickStateData{Config}->{Body},
                Data     => {},
                RichText => '1',
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID},
            );

            # replace placeholder in subject
            $QuickStateData{Config}->{Subject} = $TemplateGeneratorObject->ReplacePlaceHolder(
                Text     => $QuickStateData{Config}->{Subject},
                Data     => {},
                RichText => '0',
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID},
            );

            # prepare from
            my $From = "\"$Self->{UserFirstname} $Self->{UserLastname}\" <$Self->{UserEmail}>";

            # create article
            my $ArticleID = $TicketObject->ArticleCreate(
                %{$QuickStateData{Config}},
                TicketID         => $Self->{TicketID},
                From             => $From,
                SenderType       => 'agent',
                HistoryType      => 'AddNote',
                HistoryComment   => 'Added note by quick state',
                Charset          => $LayoutObject->{UserCharset},
                MimeType         => 'text/html',
                UserID           => $Self->{UserID},
                Attachment       => \@Attachments,
            );
            if( $ArticleID ) {
                # add article id to return url
                $ReturnURL .= ';ArticleID=' . $ArticleID;
            }
            else {
                return $LayoutObject->ErrorScreen(
                    Message => $LanguageObject->Translate("It could not be created the corresponding article to the quick state '%s'!", $QuickStateData{StateID}),
                    Comment => $LanguageObject->Translate('Please contact the administrator.'),
                );
            }
        }

        # set state
        my $Success = $TicketObject->TicketStateSet(
            StateID   => $QuickStateData{StateID},
            TicketID  => $Self->{TicketID},
            UserID    => $Self->{UserID},
        );
        if ( !$Success ) {
            return $LayoutObject->ErrorScreen(
                Message => $LanguageObject->Translate("The status couldn't be changed with the quick state '%s'!", $QuickStateData{StateID}),
                Comment => $LanguageObject->Translate('Please contact the administrator.'),
            );
        }

        # get state data for checks
        my %StateData = $StateObject->StateGet(
            ID => $QuickStateData{StateID},
        );

        # check if pending time should be set
        if (
            $StateData{TypeName}
            && $StateData{TypeName} =~ /^pending/i
            && $QuickStateData{Config}->{UsedPending}
        ) {
            my $Diff = 0;
            if ( $QuickStateData{Config}->{PendingFormatID} eq 'Days' ) {
                $Diff = $QuickStateData{Config}->{PendingTime} * 24 * 60;
            }
            elsif ( $QuickStateData{Config}->{PendingFormatID} eq 'Hours' ) {
                $Diff = $QuickStateData{Config}->{PendingTime} * 60;
            }
            else {
                $Diff = $QuickStateData{Config}->{PendingTime};
            }

            # set pending time
            $TicketObject->TicketPendingTimeSet(
                UserID   => $Self->{UserID},
                TicketID => $Self->{TicketID},
                Diff     => $Diff,
            );
        }

        # check if ticket was closed
        if (
            $StateData{TypeName}
            && $StateData{TypeName} =~ /^close/i
        ) {
            # set unlock on close state
            $TicketObject->TicketLockSet(
                TicketID => $Self->{TicketID},
                Lock     => 'unlock',
                UserID   => $Self->{UserID},
            );

            # get agent preferences
            my %Preferences         = $UserObject->GetPreferences( UserID => $Self->{UserID} );
            my $RedirectDestination = $Preferences{RedirectAfterTicketClose} || '0';

            # check redirect destination
            if ( !$RedirectDestination ) {
                $ReturnURL = $Self->{LastScreenOverview} || 'Action=AgentDashboard';
            }
        }

        return $LayoutObject->Redirect(
            OP => $ReturnURL
        );
    }
    return $LayoutObject->ErrorScreen(
        Message => $LanguageObject->Translate(
            "Sorry, the quick state '%s' couldn't use. The current Ticket has the same state as the selected quick state or the quick state is invalid!",
            $QuickStateData{StateID}
        ),
        Comment => $LanguageObject->Translate('Please use a another quick state or contact the administrator.'),
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
