# --
# Kernel/Modules/AgentArticleCopyMove.pm - to copy or move articles
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentArticleCopyMove;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

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
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Output = $LayoutObject->Header( Type => 'Small' );

    # check permissions
    my $Access = 0;
    my $Groups = $ConfigObject->Get('Frontend::Module')->{AgentArticleCopyMove}->{Group}
        || '';
    if ( $Groups && ref($Groups) eq 'ARRAY' ) {
        for my $Group ( @{$Groups} ) {
            next if !$LayoutObject->{"UserIsGroup[$Group]"};
            if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                $Access = 1;
                last;
            }
        }
    }
    else {
        $Access = 1;
    }

    if ( !$Access ) {
        $Output .= $LayoutObject->Warning(
            Message => 'Sorry, you are not a member of allowed groups!',
            Comment => 'Please contact your admin.',
        );
        $Output .= $LayoutObject->Footer( Type => 'Small' );
        return $Output;
    }

    # get params
    my %GetParam;
    for (qw(ArticleID TicketID ArticleAction NewTicketNumber TimeUnits TimeUnitsOriginal)) {
        $GetParam{$_} = $ParamObject->GetParam( Param => $_ ) || '';
    }

    # check needed stuff
    for (qw(ArticleID TicketID)) {
        if ( !$GetParam{$_} ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate('AgentArticleCopyMove: Need %s!', $_ ),
                Comment => Translatable('Please contact your admin.'),
            );
        }
    }

    # check permissions
    $Access = $TicketObject->OwnerCheck(
        TicketID => $GetParam{TicketID},
        OwnerID  => $Self->{UserID},
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        $Output .= $LayoutObject->Warning(
            Message => Translatable('Sorry, you need to be owner of the selected ticket to do this action!'),
            Comment => Translatable('Please change the owner first.'),
        );
        $Output .= $LayoutObject->Footer( Type => 'Small' );
        return $Output;
    }

    # get first article
    my %FirstArticle = $TicketObject->ArticleFirstArticle(
        TicketID => $GetParam{TicketID},
    );

    # check copy or move first article
    if ( $GetParam{ArticleID} != $FirstArticle{ArticleID} ) {
        $GetParam{FurtherActionOptions} = 1;
    }

    # get article content
    my %Article = $TicketObject->ArticleGet(
        ArticleID => $GetParam{ArticleID},
    );

    # get accounting time
    $Param{AccountedTime} = $TicketObject->ArticleAccountedTimeGet(
        ArticleID => $GetParam{ArticleID},
    );
    if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
        $Param{NeedAccountedTime} = 'Validate_Required';
    }

    if ( $Param{AccountedTime} ) {
        $LayoutObject->Block(
            Name => 'TimeUnitsJs',
            Data => {
                %Param,
                TimeUnitsOriginal => $GetParam{TimeUnitsOriginal} || 'Difference',
            },
        );
        $LayoutObject->Block(
            Name => 'TimeUnits',
            Data => \%Param,
        );
    }

    if ( $Self->{Subaction} eq 'Update' ) {
        my $NewTicketID = $GetParam{TicketID};

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # delete article
        if ( $GetParam{ArticleAction} eq 'Delete' ) {
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
        }

        # preparations for move and copy
        else {

            # check needed stuff
            if ( !$GetParam{NewTicketNumber} ) {
                $Output .= $LayoutObject->Notify(
                    Info => 'Perhaps, you forgot to enter a ticket number!',
                );
                $Output .= $Self->Form(
                    %Article,
                    %GetParam,
                    NewTicketNumberInvalid => 'ServerError',
                );
                return $Output;
            }

            # get new ticket id
            $NewTicketID = $TicketObject->TicketCheckNumber(
                Tn => $GetParam{NewTicketNumber},
            );
            if ( !$NewTicketID ) {
                $Output .= $LayoutObject->Notify(
                    Info =>
                        $LayoutObject->{LanguageObject}
                        ->Get('Sorry, no ticket found for ticket number: ')
                        . $GetParam{NewTicketNumber}
                        . '!',
                );
                $Output .= $Self->Form(
                    %Article,
                    %GetParam,
                    NewTicketNumberInvalid => 'ServerError',
                );
                return $Output;
            }

            # check owner of new ticket
            my $NewAccessOk = $TicketObject->OwnerCheck(
                TicketID => $NewTicketID,
                OwnerID  => $Self->{UserID},
            );
            if ( !$NewAccessOk ) {
                $Output .= $LayoutObject->Notify(
                    Info => 'Sorry, you need to be owner of the new ticket to do this action!',
                );
                $Output .= $Self->Form(
                    %Article,
                    %GetParam,
                );
                $Output .= $LayoutObject->Footer( Type => 'Small' );
                return $Output;
            }
        }

        # copy article
        if ( $GetParam{ArticleAction} eq 'Copy' ) {
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
            if ( $GetParam{TimeUnitsOriginal} eq 'Difference' ) {
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
        elsif ( $GetParam{ArticleAction} eq 'Move' ) {
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

    # show form
    $GetParam{CopyTypeChecked} = 'checked="checked"';
    $Output .= $Self->Form(
        %Article,
        %GetParam,
    );
    return $Output;
}

sub Form {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'ArticleActionOptions',
        Data => \%Param,
    );

    if ( $Param{FurtherActionOptions} ) {
        $LayoutObject->Block(
            Name => 'FurtherActionOptions',
            Data => \%Param,
        );
    }

    # start output
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentArticleCopyMove',
        Data         => {
            %Param,
            ArticleAction => $Param{ArticleAction} || 'Copy',
        },
    );
    $Output .= $LayoutObject->Footer( Type => 'Small' );
    return $Output;
}

1;
