# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketExtensionsKIX4OTRS;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::TemplateGenerator;
use Kernel::System::VariableCheck qw(:all);

=item CommonNextStates()

Returns a hash of common next states for multiple tickets (based on TicketStateWorkflow).

    my %StateHash = $TicketObject->TSWFCommonNextStates(
        TicketIDs => [ 1, 2, 3, 4], # required
        Action => 'SomeActionName', # optional
        UserID => 1,                # optional
    );

=cut

sub TSWFCommonNextStates {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} || ref( $Param{TicketIDs} ) ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need TicketIDs as array ref!' );
        return;
    }
    $Self->{TicketObject} = $Param{TicketObject} || $Kernel::OM->Get('Kernel::System::Ticket');

    my %Result = ();
    if ( $Param{StateType} ) {
        %Result = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
            StateType => $Param{StateType},
            Result    => 'HASH',
            Action    => $Param{Action} || '',
            UserID    => $Param{UserID} || 1,
        );
    }
    else {
        %Result = $Kernel::OM->Get('Kernel::System::State')->StateList(
            UserID => $Param{UserID} || 1,
        );
    }

    my %NextStates = ();
    for my $CurrTID ( @{ $Param{TicketIDs} } ) {

        my %States = $Kernel::OM->Get('Kernel::System::Ticket')->TicketStateList(
            TicketID => $CurrTID,
            UserID => $Param{UserID} || 1,
        );

        my @CurrNextStatesArr;
        for my $ThisState ( keys %States ) {
            push( @CurrNextStatesArr, $States{$ThisState} );
        }

        # init next states set...
        if ( !%NextStates ) {
            %NextStates = map { $_ => 1 } @CurrNextStatesArr;
        }

        # check if current next states are common with previous next states...
        else {
            for my $CurrStateCheck ( keys(%NextStates) ) {

                #remove trailing or leading spaces...
                $CurrStateCheck =~ s/^\s+//g;
                $CurrStateCheck =~ s/\s+$//g;

                next if ( grep { $_ eq $CurrStateCheck } @CurrNextStatesArr );
                delete( $NextStates{$CurrStateCheck} )
            }
        }

        # end if no next states available at all..
        last if ( !%NextStates );
    }
    for my $CurrStateID ( keys(%Result) ) {
        next if ( $NextStates{ $Result{$CurrStateID} } );
        delete( $Result{$CurrStateID} );
    }

    return %Result;
}

=item TicketQueueLinkGet()

Returns a link to the queue of a given ticket.

    my $Result = $TicketObject->TicketQueueLinkGet(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub TicketQueueLinkGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => 'Need TicketID!' );
        return;
    }

    my $SessionID = '';
    if ( !$Kernel::OM->Get('Kernel::Config')->Get('SessionUseCookie') && $Param{SessionID} ) {
        $SessionID = ';' . $Param{SessionName} . '=' . $Param{SessionID};
    }

    my $Output =
        '<a href="?Action=AgentTicketQueue;QueueID='
        . $Param{'QueueID'}
        . $SessionID . '">'
        . $Param{'Queue'} . '</a>';

    return $Output;
}

=item CountArticles()

Returns the number of articles of a given ticket.

    my $Result = $TicketObject->CountArticles(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountArticles {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    my @ArticleIndexList = $Self->ArticleIndex(
        TicketID => $Param{TicketID},
    );

    $Result = ( scalar(@ArticleIndexList) || 0 );

    return $Result;
}

=item CountAttachments()

Returns the number of attachments in all articles of a given ticket.

    my $Result = $TicketObject->CountAttachments(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountAttachments {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    my @ArticleList = $Self->ArticleContentIndex(
        TicketID                   => $Param{TicketID},
        StripPlainBodyAsAttachment => 1,
        UserID                     => $Param{UserID} || 1,
    );

    for my $Article (@ArticleList) {
        my %AtmIndex = %{ $Article->{Atms} };
        my @AtmKeys  = keys(%AtmIndex);
        $Result = $Result + ( scalar(@AtmKeys) || 0 );
    }

    return $Result;
}

=item CountLinkedObjects()

Returns the number of objects linked with a given ticket.

    my $Result = $TicketObject->CountLinkedObjects(
        TicketID => 123,
        UserID   => 123,
    );

=cut

sub CountLinkedObjects {
    my ( $Self, %Param ) = @_;
    my $Result = 0;
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject') || undef;

    if ( !$LinkObject ) {
        $LinkObject = Kernel::System::LinkObject->new( %{$Self} );
    }

    return '' if !$LinkObject;

    my %PossibleObjectsList = $LinkObject->PossibleObjectsList(
        Object => 'Ticket',
        UserID => 1,
    );

    # get user preferences
    my %UserPreferences
        = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Param{UserID} );

    for my $CurrObject ( keys(%PossibleObjectsList) ) {
        my %LinkList = $LinkObject->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => $CurrObject,
            State   => 'Valid',
            UserID  => 1,
        );

        # do not count merged tickets if user preference set
        my $LinkCount = 0;
        if ( $CurrObject eq 'Ticket' ) {
            foreach my $ObjectID ( keys %LinkList ) {
                my %Ticket = $Self->TicketGet( TicketID => $ObjectID );
                next
                    if (
                    (
                        !defined $UserPreferences{UserShowMergedTicketsInLinkedObjects}
                        || !$UserPreferences{UserShowMergedTicketsInLinkedObjects}
                    )
                    && $Ticket{StateType} eq 'merged'
                    );
                $LinkCount++;
            }
        }
        else {
            $LinkCount = scalar( keys(%LinkList) );
        }
        $Result = $Result + ( $LinkCount || 0 );
    }

    return $Result;
}

=item GetTotalNonEscalationRelevantBusinessTime()

Calculate non relevant time for escalation.

    my $Result = $TicketObject->GetTotalNonEscalationRelevantBusinessTime(
        TicketID => 123,  # required
        Type     => "",   # optional ( Response | Solution )
    );

=cut

sub GetTotalNonEscalationRelevantBusinessTime {
    my ( $Self, %Param ) = @_;

    $Self->{StateObject} = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TimeObject}  = $Kernel::OM->Get('Kernel::System::Time');

    return if !$Param{TicketID};

    # get optional parameter
    $Param{Type} ||= '';
    if ( $Param{StartTimestamp} ) {
        $Param{StartTime} = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Param{StartTimestamp},
        );
    }
    if ( $Param{StopTimestamp} ) {
        $Param{StopTime} = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Param{StopTimestamp},
        );
    }

    # get some config values if required...
    if ( !$Param{RelevantStates} ) {
        my $RelevantStateNamesArrRef =
            $Kernel::OM->Get('Kernel::Config')->Get('Ticket::EscalationDisabled::RelevantStates');
        if ( ref($RelevantStateNamesArrRef) eq 'ARRAY' ) {
            my $RelevantStateNamesArrStrg = join( ',', @{$RelevantStateNamesArrRef} );
            my %StateListHash = $Self->{StateObject}->StateList( UserID => 1 );
            for my $CurrStateID ( keys(%StateListHash) ) {
                if ( grep { $_ eq $StateListHash{$CurrStateID} } @{$RelevantStateNamesArrRef} ) {
                    $Param{RelevantStates}->{$CurrStateID} = $StateListHash{$CurrStateID};
                }
            }
        }
    }
    my %RelevantStates = ();
    if ( ref( $Param{RelevantStates} ) eq 'HASH' ) {
        %RelevantStates = %{ $Param{RelevantStates} };
    }

    # get esclation data...
    my %Ticket = $Self->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );
    my %Escalation = $Self->TicketEscalationPreferences(
        Ticket => \%Ticket,
        UserID => 1,
    );

    # get all history lines...
    my @HistoryLines = $Self->HistoryGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );

    my $PendStartTime = 0;
    my $PendTotalTime = 0;
    my $Solution      = 0;

    my %ClosedStateList = $Self->{StateObject}->StateGetStatesByType(
        StateType => ['closed'],
        Result    => 'HASH',
    );
    for my $HistoryHash (@HistoryLines) {
        my $CreateTime = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $HistoryHash->{CreateTime},
        );

        # skip not relevant history information
        next if ( $Param{StartTime} && $Param{StartTime} > $CreateTime );
        next if ( $Param{StopTime}  && $Param{StopTime} < $CreateTime );

        # proceed history information
        if (
            $HistoryHash->{HistoryType} eq 'StateUpdate'
            || $HistoryHash->{HistoryType} eq 'NewTicket'
        ) {
            if ( $RelevantStates{ $HistoryHash->{StateID} } && $PendStartTime == 0 ) {

                # datetime to unixtime
                $PendStartTime = $CreateTime;
                next;
            }
            elsif ( $PendStartTime != 0 && !$RelevantStates{ $HistoryHash->{StateID} } ) {
                my $UnixEndTime = $CreateTime;
                my $WorkingTime = $Self->{TimeObject}->WorkingTime(
                    StartTime => $PendStartTime,
                    StopTime  => $UnixEndTime,
                    Calendar  => $Escalation{Calendar},
                );
                $PendTotalTime += $WorkingTime;
                $PendStartTime = 0;
            }
        }
        if (
            (
                $HistoryHash->{HistoryType}    eq 'SendAnswer'
                || $HistoryHash->{HistoryType} eq 'PhoneCallAgent'
                || $HistoryHash->{HistoryType} eq 'EmailAgent'
            )
            && $Param{Type} eq 'Response'
        ) {
            if ( $PendStartTime != 0 ) {
                my $UnixEndTime = $CreateTime;
                my $WorkingTime = $Self->{TimeObject}->WorkingTime(
                    StartTime => $PendStartTime,
                    StopTime  => $UnixEndTime,
                    Calendar  => $Escalation{Calendar},
                );
                $PendTotalTime += $WorkingTime;
                $PendStartTime = 0;
            }
            return $PendTotalTime;
        }
        if ( $HistoryHash->{HistoryType} eq 'StateUpdate' && $Param{Type} eq 'Solution' ) {
            for my $State ( keys %ClosedStateList ) {
                if ( $HistoryHash->{StateID} == $State ) {
                    if ( $PendStartTime != 0 ) {
                        my $UnixEndTime = $CreateTime;
                        my $WorkingTime = $Self->{TimeObject}->WorkingTime(
                            StartTime => $PendStartTime,
                            StopTime  => $UnixEndTime,
                            Calendar  => $Escalation{Calendar},
                        );
                        $PendTotalTime += $WorkingTime;
                        $PendStartTime = 0;
                    }
                    return $PendTotalTime;
                }
            }
        }
    }
    return $PendTotalTime;
}

=item GetPreviousTicketState()

Returns the previous ticket state to the current one.

    my $Result = $TicketObject->GetPreviousTicketState(
        TicketID   => 123,                  # required
        ResultType => "StateName" || "ID",  # optional
    );

=cut

sub GetPreviousTicketState {
    my ( $Self, %Param ) = @_;
    my $Result = 0;

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "Need $_!" );
            return 0;
        }
    }

    my $SelectValue = 'ts1.name';
    if ( $Param{ResultType} && $Param{ResultType} eq 'ID' ) {
        $SelectValue = 'ts1.id';
    }

    # following deprecated but kept for backward-compatibility...
    elsif ( $Param{ResultType} && $Param{ResultType} eq 'StateID' ) {
        $SelectValue = 'ts1.id';
    }

    my %Ticket = $Self->TicketGet(
        TicketID => $Param{TicketID},
    );
    return 0 if !%Ticket || !$Ticket{State};

    return 0 if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => "SELECT " . $SelectValue . " FROM ticket_history th1, ticket_state ts1 " .
            " WHERE " .
            "   th1.id = ( " .
            "     SELECT max(th2.id) FROM ticket_history th2, ticket_state ts2 WHERE " .
            "     th2.ticket_id = ? AND th2.create_time = th2.change_time " .
            "     AND th2.state_id = ts2.id AND ts2.name != ? " .
            "   ) " .
            "   AND ts1.id = th1.state_id ",
        Bind => [ \$Ticket{TicketID}, \$Ticket{State} ],
    );

    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Result = $Row[0];
    }

    return $Result;
}

=item ArticleMove()

Moves an article to another ticket

    my $Result = $TicketObject->ArticleMove(
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

Result:
    1
    MoveFailed
    AccountFailed

Events:
    ArticleMove

=cut

sub ArticleMove {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleMove: Need $Needed!" );
            return;
        }
    }

    # update article data
    return 'MoveFailed' if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE article SET ticket_id = ?, "
            . "change_time = current_timestamp, change_by = ? WHERE id = ?",
        Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # update time accounting data
    return 'AccountFailed' if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE time_accounting SET ticket_id = ?, '
            . "change_time = current_timestamp, change_by = ? WHERE article_id = ?",
        Bind => [ \$Param{TicketID}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # update article history
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'UPDATE ticket_history SET ticket_id = ? WHERE article_id = ?',
        Bind => [ \$Param{TicketID}, \$Param{ArticleID} ],
    );

    # clear ticket cache
    delete $Self->{ 'Cache::GetTicket' . $Param{TicketID} };

    # event
    $Self->EventHandler(
        Event => 'ArticleMove',
        Data  => {
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item ArticleCopy()

Copies an article to another ticket including all attachments

    my $Result = $TicketObject->ArticleCopy(
        TicketID  => 123,
        ArticleID => 123,
        UserID    => 123,
    );

Result:
    NewArticleID
    'NoOriginal'
    'CopyFailed'
    'UpdateFailed'

Events:
    ArticleCopy

=cut

sub ArticleCopy {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID TicketID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleCopy: Need $Needed!" );
            return;
        }
    }

    # get original article content
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID},
    );
    return 'NoOriginal' if !%Article;

    # copy original article
    my $CopyArticleID = $Self->ArticleCreate(
        %Article,
        TicketID       => $Param{TicketID},
        UserID         => $Param{UserID},
        HistoryType    => 'Misc',
        HistoryComment => "Copied article $Param{ArticleID} from "
            . "ticket $Article{TicketID} to ticket $Param{TicketID}",
    );
    return 'CopyFailed' if !$CopyArticleID;

    # set article times from original article
    return 'UpdateFailed' if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL =>
            'UPDATE article SET create_time = ?, change_time = ?, incoming_time = ? WHERE id = ?',
        Bind => [
            \$Article{Created},      \$Article{Changed},
            \$Article{IncomingTime}, \$CopyArticleID
        ],
    );

    # copy attachments from original article
    my %ArticleIndex = $Self->ArticleAttachmentIndex(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );
    for my $Index ( keys %ArticleIndex ) {
        my %Attachment = $Self->ArticleAttachment(
            ArticleID => $Param{ArticleID},
            FileID    => $Index,
            UserID    => $Param{UserID},
        );
        $Self->ArticleWriteAttachment(
            %Attachment,
            ArticleID => $CopyArticleID,
            UserID    => $Param{UserID},
        );
    }

    # clear ticket cache
    delete $Self->{ 'Cache::GetTicket' . $Param{TicketID} };

    # copy plain article if exists
    if ( $Article{ArticleType} =~ /email/i ) {
        my $Data = $Self->ArticlePlain(
            ArticleID => $Param{ArticleID}
        );
        if ($Data) {
            $Self->ArticleWritePlain(
                ArticleID => $CopyArticleID,
                Email     => $Data,
                UserID    => $Param{UserID},
            );
        }
    }

    # event
    $Self->EventHandler(
        Event => 'ArticleCopy',
        Data  => {
            TicketID     => $Param{TicketID},
            ArticleID    => $CopyArticleID,
            OldArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return $CopyArticleID;
}

=item ArticleFullDelete()

Delete an article, its history, its plain message, and all attachments

    my $Success = $TicketObject->ArticleFullDelete(
        ArticleID => 123,
        UserID    => 123,
    );

ATTENTION:
    sub ArticleDelete is used in this sub, but this sub does not delete
    article history

Events:
    ArticleFullDelete

=cut

sub ArticleFullDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFullDelete: Need $Needed!" );
            return;
        }
    }

    # get article content
    my %Article = $Self->ArticleGet(
        ArticleID => $Param{ArticleID},
    );
    return if !%Article;

    # clear ticket cache
    delete $Self->{ 'Cache::GetTicket' . $Article{TicketID} };

    # delete article history
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM ticket_history WHERE article_id = ?',
        Bind => [ \$Param{ArticleID} ],
    );

    # delete article, attachments and plain emails
    return if !$Self->ArticleDelete(
        ArticleID => $Param{ArticleID},
        UserID    => $Param{UserID},
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleFullDelete',
        Data  => {
            TicketID  => $Article{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item ArticleCreateDateUpdate()

Manipulates the article create date

    my $Result = $TicketObject->ArticleCreateDateUpdate(
        ArticleID => 123,
        UserID    => 123,
    );

Events:
    ArticleUpdate

=cut

sub ArticleCreateDateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID ArticleID UserID Created IncomingTime)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleCreateDateUpdate: Need $Needed!" );
            return;
        }
    }

    # db update
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => "UPDATE article SET incoming_time = ?, create_time = ?,"
            . "change_time = current_timestamp, change_by = ? WHERE id = ?",
        Bind => [ \$Param{IncomingTime}, \$Param{Created}, \$Param{UserID}, \$Param{ArticleID} ],
    );

    # event
    $Self->EventHandler(
        Event => 'ArticleUpdate',
        Data  => {
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        },
        UserID => $Param{UserID},
    );
    return 1;
}

=item ArticleFlagDataSet()

set ....

    my $Success = $TicketObject->ArticleFlagDataSet(
            ArticleID   => 1,
            Key         => 'ToDo', // ArticleFlagKey
            Keywords    => Keywords,
            Subject     => Subject,
            Note        => Note,
        );
=cut

sub ArticleFlagDataSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID Key UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFlagDataSet: Need $Needed!" );
            return;
        }
    }

    # db quote
    for my $Quote (qw(Notes Subject Keywords Key)) {
        $Param{$Quote} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$Quote} );
    }
    for my $Quote (qw(ArticleID)) {
        $Param{$Quote} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$Quote}, 'Integer' );
    }

    # check if update is needed
    my %ArticleFlagData = $Self->ArticleFlagDataGet(
        ArticleID      => $Param{ArticleID},
        ArticleFlagKey => $Param{Key},
        UserID         => $Param{UserID},
    );

    # return 1 if ( %ArticleFlagData && $ArticleFlagData{ $Param{TicketID} } eq $Param{Notes} );

    # update action
    if (
        defined( $ArticleFlagData{ $Param{ArticleID} } )
        && defined( $ArticleFlagData{ $Param{Key} } )
    ) {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'UPDATE kix_article_flag SET note = ?, subject = ?, keywords = ? '
                . 'WHERE article_id = ? AND article_key = ? AND create_by = ? ',
            Bind => [
                \$Param{Note},      \$Param{Subject}, \$Param{Keywords},
                \$Param{ArticleID}, \$Param{Key},     \$Param{UserID}
            ],
        );
    }

    # insert action
    else {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'INSERT INTO kix_article_flag (article_id, article_key, keywords, subject, note, create_by) '
                . ' VALUES (?, ?, ?, ?, ?, ?)',
            Bind => [
                \$Param{ArticleID}, \$Param{Key},  \$Param{Keywords},
                \$Param{Subject},   \$Param{Note}, \$Param{UserID}
            ],
        );
    }

    return 1;
}

=item ArticleFlagDataDelete()

delete ....

    my $Success = $TicketObject->ArticleFlagDataDelete(
            ArticleID   => 1,
            Key         => 'ToDo',
            UserID      => $UserID,  # use either UserID or AllUsers
        );

    my $Success = $TicketObject->ArticleFlagDataDelete(
            ArticleID   => 1,
            Key         => 'ToDo',
            AllUsers    => 1,        # delete flag data from all users for this article
        );
=cut

sub ArticleFlagDataDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID Key)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFlagDataDelete: Need $Needed!" );
            return;
        }
    }
    if ( !defined $Param{UserID} && !defined $Param{AllUsers} ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log(
            Priority => 'error',
            Message  => "ArticleFlagDataDelete: Need either UserID or AllUsers!"
            );
        return;
    }

    # check if UserID or AllUsers set
    if ( $Param{UserID} ) {

        # insert action
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'DELETE FROM kix_article_flag'
                . ' WHERE article_id = ? AND article_key = ? AND create_by = ? ',
            Bind => [ \$Param{ArticleID}, \$Param{Key}, \$Param{UserID} ],
        );
    }
    else {

        # insert action
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'DELETE FROM kix_article_flag'
                . ' WHERE article_id = ? AND article_key = ? ',
            Bind => [ \$Param{ArticleID}, \$Param{Key} ],
        );
    }

    return 1;
}

=item ArticleFlagDataGet()

get ....

    my $Success = $TicketObject->ArticleFlagDataGet(
            ArticleID      => 1,
            ArticleFlagKey => 'ToDo',
            UserID         => 1
        );
=cut

sub ArticleFlagDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ArticleID ArticleFlagKey UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "ArticleFlagGet: Need $Needed!" );
            return;
        }
    }

    # fetch the result
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT article_id, article_key, subject, keywords, note, create_by'
            . ' FROM kix_article_flag'
            . ' WHERE article_id = ? AND article_key = ? AND create_by = ?',
        Bind => [ \$Param{ArticleID}, \$Param{ArticleFlagKey}, \$Param{UserID} ],
        Limit => 1,
    );

    my %ArticleFlagData;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ArticleFlagData{ArticleID} = $Row[0];
        $ArticleFlagData{Key}       = $Row[1];
        $ArticleFlagData{Subject}   = $Row[2];
        $ArticleFlagData{Keywords}  = $Row[3];
        $ArticleFlagData{Note}      = $Row[4];
        $ArticleFlagData{CreateBy}  = $Row[5];
    }

    return %ArticleFlagData;
}

=item SendLinkedPersonNotification()

send linked person notification via email

    my $Success = $TicketObject->SendLinkedPersonNotification(
        TicketID    => 123,
        ArticleID   => 123,
        CustomerMessageParams => {
            SomeParams => 'For the message!',
        },
        Type       => 'LinkedPersonPhoneNotification' || 'LinkedPersonNoteNotification',
        Recipients => $UserID,
        UserID     => 123,
    );

Events:
    ArticleLinkedPersonNotification

=cut

sub SendLinkedPersonNotification {
    my ( $Self, %Param ) = @_;
    my @Cc;

    # check needed stuff
    for (qw(CustomerMessageParams TicketID Type Recipients UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "SendLinkedPersonNotification: Need $_!" );
            return;
        }
    }

    # return if no notification is active
    return 1 if $Self->{SendNoNotification};

    # proceed selected linked persons
    return if ref $Param{Recipients} ne 'ARRAY';
    for my $RecipientStr ( @{ $Param{Recipients} } ) {
        my ( $RecipientType, $RecipientID ) = split( ':::', $RecipientStr );

        my %User;
        if ( $RecipientType eq 'Agent' ) {
            %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
                UserID => $RecipientID,
            );
        }
        else {
            %User = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                User => $RecipientID,
            );
        }
        next if !$User{UserEmail} || $User{UserEmail} !~ /@/;

        my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
        my %Notification = $TemplateGeneratorObject->NotificationLinkedPerson(
            Type                  => $Param{Type},
            TicketID              => $Param{TicketID},
            ArticleID             => $Param{ArticleID} || '',
            CustomerMessageParams => $Param{CustomerMessageParams},
            RecipientID           => $RecipientID,
            RecipientType         => $RecipientType,
            RecipientData         => \%User,
            UserID                => $Param{UserID},
        );
        next if !%Notification || !$Notification{Subject} || !$Notification{Body};

        # send notify
        $Kernel::OM->Get('Kernel::System::Email')->Send(
            From => $Kernel::OM->Get('Kernel::Config')->Get('NotificationSenderName') . ' <'
                . $Kernel::OM->Get('Kernel::Config')->Get('NotificationSenderEmail') . '>',
            To       => $User{UserEmail},
            Subject  => $Notification{Subject},
            MimeType => $Notification{ContentType} || 'text/plain',
            Charset  => $Notification{Charset},
            Body     => $Notification{Body},
            Loop     => 1,
        );

        # save person name for Cc update
        push( @Cc, $User{UserEmail} );

        # write history
        $Param{HistoryName} = 'Involved Person Phone';
        if ( $Param{Type} eq 'InvolvedNoteNotification' ) {
            $Param{HistoryName} = 'Involved Person Note';
        }
        $Self->HistoryAdd(
            TicketID     => $Param{TicketID},
            HistoryType  => 'SendLinkedPersonNotification',
            Name         => "$Param{HistoryName}: $User{UserEmail}",
            CreateUserID => $Param{UserID},
        );

        # log event
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Sent '$Param{Type}' notification to $RecipientType '$RecipientID'.",
        );

        # event
        $Self->EventHandler(
            Event => 'ArticleLinkedPersonNotification',
            Data  => {
                RecipientID => $RecipientID,
                TicketID    => $Param{TicketID},
                ArticleID   => $Param{ArticleID},
            },
            UserID => $Param{UserID},
        );
    }

    # update article Cc
    if (@Cc) {
        $Self->ArticleUpdate(
            ArticleID => $Param{ArticleID},
            TicketID  => $Param{TicketID},
            Key       => 'Cc',
            Value     => join( ',', @Cc ),
            UserID    => $Param{UserID},
        );
    }

    return 1;
}

=item TicketNotesUpdate()

Creates or updates ticket remarks

    my $Success = $TicketObject->TicketNotesUpdate(
        TicketID => 123,
        Notes    => 'some remark content', # leave it empty to delete remarks
        UserID   => 123,
    );

Events:
    TicketNotesUpdate

=cut

sub TicketNotesUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Notes TicketID UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketNotesUpdate: Need $Needed!" );
            return;
        }
    }

    # db quote
    for my $Quote (qw(Notes)) {
        $Param{$Quote} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$Quote} );
    }
    for my $Quote (qw(TicketID UserID)) {
        $Param{$Quote} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$Quote}, 'Integer' );
    }

    # check if update is needed
    my %Notes = $Self->TicketNotesGet(
        TicketID => $Param{TicketID},
    );
    return 1 if ( %Notes && $Notes{ $Param{TicketID} } eq $Param{Notes} );

    # update action
    if ( defined( $Notes{ $Param{TicketID} } ) ) {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'UPDATE kix_ticket_notes SET note = ?, change_time = current_timestamp, change_by = ? '
                . 'WHERE ticket_id = ?',
            Bind => [ \$Param{Notes}, \$Param{UserID}, \$Param{TicketID} ],
        );
    }

    # insert action
    else {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL =>
                'INSERT INTO kix_ticket_notes (ticket_id, note, create_time, create_by, change_time, change_by) '
                . ' VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
            Bind => [ \$Param{TicketID}, \$Param{Notes}, \$Param{UserID}, \$Param{UserID} ],
        );
    }

    # update ticket notes cache
    my $CacheKey = 'Cache::GetTicketNotes::' . $Param{TicketID};
    $Self->{$CacheKey} = {
        $Param{TicketID} => $Param{Notes},
    };

    # event
    $Self->EventHandler(
        Event => 'TicketNotesUpdate',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item TicketNotesGet()

Get ticket remark and its ID

    my %TicketRemark = $TicketObject->TicketNotesGet(
        TicketID => 123,
    );

Returns:

    %TicketRemark = (
        123 => 'remark content',
    );

=cut

sub TicketNotesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketNotesGet: Need $Needed!" );
            return;
        }
    }

    my $CacheKey = 'Cache::GetTicketNotes::' . $Param{TicketID};

    # check if result is cached
    if ( $Self->{$CacheKey} ) {
        return %{ $Self->{$CacheKey} };
    }

    return () if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => 'SELECT note FROM kix_ticket_notes WHERE ticket_id = ? ',
        Bind  => [ \$Param{TicketID} ],
        Limit => 1,
    );

    my %Notes;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Notes{ $Param{TicketID} } = $Row[0];
    }

    # cache ticket notes result
    $Self->{$CacheKey} = \%Notes;

    return %Notes;
}

=item TicketNotesDelete()

Deletes ticket remarks

    my $Success = $TicketObject->TicketNotesDelete(
        TicketID => 123,
        UserID   => 123,
    );

Events:
    TicketNotesDelete

=cut

sub TicketNotesDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketNotesUpdate: Need $Needed!" );
            return;
        }
    }

    # db quote
    for my $Quote (qw(TicketID)) {
        $Param{$Quote} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{$Quote}, 'Integer' );
    }

    # delete action
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM kix_ticket_notes WHERE ticket_id = ? ',
        Bind => [ \$Param{TicketID} ],
    );

    # event
    $Self->EventHandler(
        Event => 'TicketNotesDelete',
        Data  => {
            TicketID => $Param{TicketID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item TicketChecklistUpdate()

Creates new tasks

    my $HashRef = $TicketObject->TicketChecklistUpdate(
        TicketID => 123,
        TaskString => String,
        State => 'open',
    );

=cut

sub TicketChecklistUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TaskString TicketID State)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketChecklistUpdate: Need $Needed!" );
            return;
        }
    }

    # get single tasks
    my @Tasks        = split /\n/, $Param{TaskString};
    my %TaskHash     = ();
    my %TaskPosition = ();

    # get old task hash
    my $Checklist = $Self->TicketChecklistGet(
        TicketID => $Param{TicketID},
        Result   => 'Task',
    );

    # db quote
    $Param{TicketID} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{TicketID}, 'Integer' );
    $Param{State} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{State} );

    my $Position = 1;
    my %NewTaskDataHash;
    for my $Task (@Tasks) {

        # if task already exists
        if ( defined $Checklist->{Data}->{$Task} ) {

            # update position if changed
            if ( $Position != $Checklist->{Data}->{$Task}->{Position} ) {

                $Checklist->{Data}->{$Task}->{Position} = $Position;
                $Self->TicketChecklistTaskUpdate(
                    TaskID   => $Checklist->{Data}->{$Task}->{ID},
                    Task     => $Task,
                    Position => $Position
                );
            }

            # add data to new task hash
            my %TempTaskHash = %{ $Checklist->{Data}->{$Task} };
            $NewTaskDataHash{$Position} = \%TempTaskHash;
            $TaskHash{$Task}            = 1;
            delete $Checklist->{Data}->{$Task};
        }

        # check if similar task exists
        else {
            my $Distance = 10;
            my $ChangedTaskID;
            my $ChangedTask;
            for my $NewTaskKey ( keys %{ $Checklist->{Data} } ) {

                # get distance
                my $NewDistance = $Self->_CalcStringDistance( $NewTaskKey, $Task );

                # take lowest distance
                next if $NewDistance >= $Distance;

                $Distance      = $NewDistance;
                $ChangedTaskID = $Checklist->{Data}->{$NewTaskKey}->{ID};
                $ChangedTask   = $NewTaskKey;

                last if $Distance == 1;
            }

            # similar task found - update data
            if ( $Distance < 10 ) {

                $Self->TicketChecklistTaskUpdate(
                    TaskID   => $ChangedTaskID,
                    Task     => $Task,
                    Position => $Position
                );
                $Checklist->{Data}->{$ChangedTask}->{Task} = $Task;
                my %TempTaskHash = %{ $Checklist->{Data}->{$ChangedTask} };
                $NewTaskDataHash{$Position} = \%TempTaskHash;
                delete $Checklist->{Data}->{$ChangedTask};
            }

            # no similar task found - create new task
            else {
                if ( !defined $TaskHash{$Task} ) {
                    my $TaskID = $Self->TicketChecklistTaskCreate(
                        Task     => $Task,
                        State    => $Param{State},
                        TicketID => $Param{TicketID},
                        Position => $Position,
                    );
                    my %TempHash;
                    $TempHash{ID}               = $TaskID;
                    $TempHash{Position}         = $Position;
                    $TempHash{Task}             = $Task;
                    $TempHash{State}            = $Param{State};
                    $NewTaskDataHash{$Position} = \%TempHash;

                    $TaskHash{$Task} = 1;
                }
            }
        }
        $Position++;
    }

    # delete obsolete tasks
    for my $ObsoleteTask ( keys %{ $Checklist->{Data} } ) {
        $Self->TicketChecklistTaskDelete(
            TaskID => $Checklist->{Data}->{$ObsoleteTask}->{ID},
        );
    }

    return \%NewTaskDataHash;
}

=item TicketChecklistTaskStateUpdate()

Sets new state to a tasks

    my $Success = $TicketObject->TicketChecklistTaskStateUpdate(
        TaskID => 123,
        State => 'open',
    );

=cut

sub TicketChecklistTaskStateUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TaskID State)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log(
                Priority => 'error',
                Message  => "TicketChecklistTaskStateUpdate: Need $Needed!"
                );
            return;
        }
    }

    # db quote
    $Param{TaskID} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{TaskID}, 'Integer' );
    $Param{State} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{State} );

    # update
    return 0 if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE kix_ticket_checklist SET state = ? WHERE id = ?',
        Bind => [ \$Param{State}, \$Param{TaskID} ],
    );

    return 1;
}

=item TicketChecklistTaskUpdate()

Updates a tasks

    my $Success = $TicketObject->TicketChecklistTaskUpdate(
        TaskID => 123,
        Task => 'text'
    );

=cut

sub TicketChecklistTaskUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TaskID Task Position)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketChecklistTaskUpdate: Need $Needed!" );
            return;
        }
    }

    # db quote
    $Param{TaskID}   = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{TaskID},   'Integer' );
    $Param{Position} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{Position}, 'Integer' );

    # update
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'UPDATE kix_ticket_checklist SET task = ?, position = ? WHERE id = ?',
        Bind => [ \$Param{Task}, \$Param{Position}, \$Param{TaskID} ],
    );

    return 1;
}

=item TicketChecklistTaskCreate()

Inserts a tasks

    my $TaskID = $TicketObject->TicketChecklistTaskCreate(
        Task        => 123,
        State       => 'open',
        TicketID    => 123,
    );

=cut

sub TicketChecklistTaskCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID State Task)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketChecklistTaskCreate: Need $Needed!" );
            return;
        }
    }

    # insert action
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL =>
            'INSERT INTO kix_ticket_checklist (ticket_id, task, state, position) '
            . ' VALUES (?, ?, ?, ?)',
        Bind => [ \$Param{TicketID}, \$Param{Task}, \$Param{State}, \$Param{Position} ],
    );

    # get inserted id
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => 'SELECT id FROM kix_ticket_checklist WHERE task = ?',
        Bind  => [ \$Param{Task} ],
        Limit => 1,
    );

    my $ID;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

=item TicketChecklistTaskDelete()

Deletes a tasks

    my $Success = $TicketObject->TicketChecklistTaskDelete(
        TaskID => 123,
    );

=cut

sub TicketChecklistTaskDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined( $Param{TaskID} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')
            ->Log( Priority => 'error', Message => "TicketChecklistTaskDelete: Need TaskID!" );
        return;
    }

    # db quote
    $Param{TaskID} = $Kernel::OM->Get('Kernel::System::DB')->Quote( $Param{TaskID}, 'Integer' );

    # update
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM kix_ticket_checklist WHERE id = ?',
        Bind => [ \$Param{TaskID} ],
    );

    return 1;
}

=item TicketChecklistGet()

Returns a hash of task string and task data

    my $HashRef = $TicketObject->TicketChecklistGet(
        TicketID => 123,
    );

=cut

sub TicketChecklistGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Result)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')
                ->Log( Priority => 'error', Message => "TicketChecklistGet: Need $Needed!" );
            return;
        }
    }

    # if order by given
    if (
        !defined $Param{Sort}
        || ( $Param{Sort} ne 'id' && $Param{Sort} ne 'position' )
    ) {
        $Param{Sort} = 'position';
    }

    # fetch the result
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, task, state, position'
            . ' FROM kix_ticket_checklist'
            . ' WHERE ticket_id = ? ORDER BY '.$Param{Sort},
        Bind => [ \$Param{TicketID} ],
    );

    # get checklist items
    my %ChecklistData;
    my $ChecklistString = '';

    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        my %TempHash;
        $TempHash{ID}       = $Row[0];
        $TempHash{Task}     = $Row[1];
        $TempHash{State}    = $Row[2];
        $TempHash{Position} = $Row[3] || 0;

        # create data hash
        if ( $Param{Result} eq 'Task' ) {
            $ChecklistData{ $Row[1] } = \%TempHash;
        }
        elsif ( $Param{Result} eq 'Position' ) {
            $ChecklistData{ $Row[3] } = \%TempHash;
        }
        else {
            $ChecklistData{ $Row[0] } = \%TempHash;
        }

        # create string
        $ChecklistString .= $Row[1] . "\n";
    }

    # create hash of single task data and checklist string
    my %Checklist;
    $Checklist{Data}   = \%ChecklistData;
    $Checklist{String} = $ChecklistString;

    # return hash
    return \%Checklist;
}

=item TicketOwnerName()

returns the ticket owner name for ticket info sidebar

    my $OwnerStrg = $TicketObject->TicketOwnerName(
        OwnerID => 123,
        %{ $Self }
    );

=cut

sub TicketOwnerName {
    my ( $Self, %Param ) = @_;

    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{OwnerID},
    );
    return if !%User;
    return $Self->_GetUserInfoString(
        %{$Self},
        %Param,
        UserType => 'Owner',
        User     => \%User,
    );
}

=item TicketResponsibleName()

returns the ticket Responsible name for ticket info sidebar

    my $ResponsibleStrg = $TicketObject->TicketResponsibleName(
        ResponsibleID => 123,
        %{ $Self }
    );

=cut

sub TicketResponsibleName {
    my ( $Self, %Param ) = @_;

    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{ResponsibleID},
    );
    return if !%User;

    return $Self->_GetUserInfoString(
        %{$Self},
        %Param,
        UserType => 'Responsible',
        User     => \%User,
    );

}

sub _GetUserInfoString {
    my ( $Self, %Param ) = @_;

    return '' if !$Param{UserType};
    my %User = %{ $Param{User} };

    my %CustomerUserData
        = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $User{UserLogin},
        );

    # if no customer data found use agent data
    if ( !%CustomerUserData ) {
        my @EmptyArray = ();
        %CustomerUserData = %User;
        $CustomerUserData{Config}->{Map} = \@EmptyArray;

        my $AgentConfig
            = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::KIXSidebarTicketInfo');
        for my $Attribute ( sort keys %{ $AgentConfig->{DisplayAttributes} } ) {
            next if !$AgentConfig->{DisplayAttributes}->{$Attribute};

            my $AttributeDisplay = $Attribute =~ m/^User(.*)$/;
            my @TempArray = ();
            push @TempArray, $Attribute;
            push @TempArray, $AttributeDisplay || $Attribute;
            push @TempArray, '';
            push @TempArray, 1;
            push @TempArray, 0;
            push @{ $CustomerUserData{Config}->{Map} }, \@TempArray;
        }
    }

    $Self->{LayoutObject} = $Param{LayoutObject};
    my $DetailsTable = $Self->{LayoutObject}->AgentCustomerDetailsViewTable(
        Data   => \%CustomerUserData,
        Ticket => $Param{Ticket},
        Max =>
            $Kernel::OM->Get('Kernel::Config')
            ->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
    );

    my $Title
        = $Self->{LayoutObject}->{LanguageObject}
        ->Translate( $Param{UserType} . ' Information' );
    my $Output
        = $User{UserFirstname} . ' '
        . $User{UserLastname}
        . '<span class="' . $Param{UserType} . 'DetailsMagnifier">'
        . ' <i class="fa fa-search"></i>'
        . '</span>'
        . '<div class="WidgetPopup" id="' . $Param{UserType} . 'Details">'
        . '<div class="Header"><h2>' . $Title . '</h2></div>'
        . '<div class="Content"><div class="Spacing">'
        . $DetailsTable
        . '</div>'
        . '</div>'
        . '</div>';

    return $Output;
}


=item Kernel::System::Ticket::TicketAclFormData()

return the current ACL form data hash after TicketAcl()

    my %AclForm = Kernel::System::Ticket::TicketAclFormData();

=cut

sub Kernel::System::Ticket::TicketAclFormData {
    my ( $Self, %Param ) = @_;

    if ( IsHashRefWithData( $Self->{TicketAclFormData} ) ) {
        return %{ $Self->{TicketAclFormData} };
    }
    else {
        return ();
    }
}

=item TicketAccountedTimeDelete()

deletes the accounted time of a ticket.

    my $Success = $TicketObject->TicketAccountedTimeDelete(
        TicketID    => 1234,
        ArticleID   => 1234
    );

=cut

sub TicketAccountedTimeDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # db query
    if ( $Param{ArticleID} ) {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL => 'DELETE FROM time_accounting WHERE ticket_id = ? AND article_id = ?',
            Bind => [ \$Param{TicketID}, \$Param{ArticleID} ],
        );
    }
    else {
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => 'DELETE FROM time_accounting WHERE ticket_id = ?',
            Bind => [ \$Param{TicketID} ],
        );
    }

    return 1;
}

sub GetLinkedTickets {
    my ( $Self, %Param ) = @_;

    my $SQL = 'SELECT DISTINCT target_key FROM link_relation WHERE source_key = ?';

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{Customer} ],
    );
    my @TicketIDs;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push @TicketIDs, $Row[0];
    }
    return @TicketIDs;
}

# Levenshtein algorithm taken from
# http://en.wikibooks.org/wiki/Algorithm_implementation/Strings/Levenshtein_distance#Perl
sub _CalcStringDistance {
    my ( $Self, $StringA, $StringB ) = @_;
    my ( $len1, $len2 ) = ( length $StringA, length $StringB );
    return $len2 if ( $len1 == 0 );
    return $len1 if ( $len2 == 0 );
    my %d;
    for ( my $i = 0; $i <= $len1; ++$i ) {
        for ( my $j = 0; $j <= $len2; ++$j ) {
            $d{$i}{$j} = 0;
            $d{0}{$j} = $j;
        }
        $d{$i}{0} = $i;
    }

    # Populate arrays of characters to compare
    my @ar1 = split( //, $StringA );
    my @ar2 = split( //, $StringB );
    for ( my $i = 1; $i <= $len1; ++$i ) {
        for ( my $j = 1; $j <= $len2; ++$j ) {
            my $cost = ( $ar1[ $i - 1 ] eq $ar2[ $j - 1 ] ) ? 0 : 1;
            my $min1 = $d{ $i - 1 }{$j} + 1;
            my $min2 = $d{$i}{ $j - 1 } + 1;
            my $min3 = $d{ $i - 1 }{ $j - 1 } + $cost;
            if ( $min1 <= $min2 && $min1 <= $min3 ) {
                $d{$i}{$j} = $min1;
            }
            elsif ( $min2 <= $min1 && $min2 <= $min3 ) {
                $d{$i}{$j} = $min2;
            }
            else {
                $d{$i}{$j} = $min3;
            }
        }
    }
    return $d{$len1}{$len2};
}

=item TicketEscalationDisabledCheck()

check if escalation is disabled for this ticket

    my $Disabled = $TicketObject->TicketEscalationDisabledCheck(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

=cut

sub TicketEscalationDisabledCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %Ticket = $Self->TicketGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    # no escalation for certain ticket types
    my $RelevantTypeNamesArrRef = $Kernel::OM->Get('Kernel::Config')->Get(
        'Ticket::EscalationDisabled::RelevantTypes'
    );
    if (
        $Ticket{Type}
        && $RelevantTypeNamesArrRef
        && ref($RelevantTypeNamesArrRef) eq 'ARRAY'
    ) {
        if (grep { $_ eq $Ticket{Type} } @{$RelevantTypeNamesArrRef}) {
            return 1;
        }
    }

    # no escalation for certain queues
    my $RelevantQueueNamesArrRef = $Kernel::OM->Get('Kernel::Config')->Get(
        'Ticket::EscalationDisabled::RelevantQueues'
    );
    if (
        $Ticket{Queue}
        && $RelevantQueueNamesArrRef
        && ref($RelevantQueueNamesArrRef) eq 'ARRAY'
    ) {
        if (grep { $_ eq $Ticket{Queue} } @{$RelevantQueueNamesArrRef}) {
            return 1;
        }
    }

    # check for Non-SLA-relevant pending time...
    my $RelevantStateNamesArrRef = $Kernel::OM->Get('Kernel::Config')->Get(
        'Ticket::EscalationDisabled::RelevantStates'
    );
    my %RelevantStateHash         = ();
    my $RelevantStateNamesArrStrg = '';
    if (
        $RelevantStateNamesArrRef
        && ref($RelevantStateNamesArrRef) eq 'ARRAY'
    ) {
        my %StateListHash = $Kernel::OM->Get('Kernel::System::State')->StateList( UserID => 1, );
        for my $CurrStateID ( keys(%StateListHash) ) {
            if ( grep { $_ eq $StateListHash{$CurrStateID} } @{$RelevantStateNamesArrRef} ) {
                $RelevantStateHash{$CurrStateID} = $StateListHash{$CurrStateID};
            }
        }
    }
    if ( grep { $_ eq $Ticket{State} } @{$RelevantStateNamesArrRef} ) {
        return 1;
    }

    return 0;
}

=item TicketEscalationCheck()

check if escalations are relevant for this ticket

    my $Check = $TicketObject->TicketEscalationCheck(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
    );

=cut

sub TicketEscalationCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %Ticket = $Self->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1,
        UserID        => $Param{UserID},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # init result
    my %Result = (
        FirstResponse => 0,
        Update        => 0,
        Solution      => 0,
        
    );
    # do no escalations on (merge|close|remove) tickets
    if ( $Ticket{StateType} =~ /^(?:merge|close|remove)/i ) {
        return \%Result;
    }

    # get escalation properties
    my %Escalation;
    if (%Ticket) {
        %Escalation = $Self->TicketEscalationPreferences(
            Ticket => \%Ticket,
            UserID => $Param{UserID},
        );
    }

    # check first response escalation (if not responded till now)
    if ( $Escalation{FirstResponseTime} ) {
        # check if first response is already done
        my %FirstResponseDone = $Self->_TicketGetFirstResponse(
            TicketID => $Ticket{TicketID},
            Ticket   => \%Ticket,
        );

        # find solution time / first close time
        my %SolutionDone = $Self->_TicketGetClosed(
            TicketID => $Ticket{TicketID},
            Ticket   => \%Ticket,
        );

        # first response can escalate
        if (
            !%FirstResponseDone
            && !%SolutionDone
        ) {
            $Result{'FirstResponse'} = 1;
        }
    }

    # check update escalation (if not in pending state)
    if (
        $Escalation{UpdateTime}
        && $Ticket{StateType} !~ /^(pending)/i
    ) {

        # check if update escalation should be set
        my @SenderHistory;
        return if !$DBObject->Prepare(
            SQL  => 'SELECT article_sender_type_id, article_type_id, create_time FROM '
                  . 'article WHERE ticket_id = ? ORDER BY create_time ASC',
            Bind => [ \$Param{TicketID} ],
        );
        while ( my @Row = $DBObject->FetchrowArray() ) {
            push @SenderHistory, {
                SenderTypeID  => $Row[0],
                ArticleTypeID => $Row[1],
                Created       => $Row[2],
            };
        }

        # fill up lookups
        for my $Row (@SenderHistory) {

            # get sender type
            $Row->{SenderType} = $Self->ArticleSenderTypeLookup(
                SenderTypeID => $Row->{SenderTypeID},
            );

            # get article type
            $Row->{ArticleType} = $Self->ArticleTypeLookup(
                ArticleTypeID => $Row->{ArticleTypeID},
            );
        }

        # get latest customer contact time
        my $LastSenderTime;
        my $LastSenderType = '';
        ROW:
        for my $Row ( reverse @SenderHistory ) {

            # fill up latest sender time (as initial value)
            if ( !$LastSenderTime ) {
                $LastSenderTime = $Row->{Created};
            }

            # do not use internal article types for calculation
            next ROW if $Row->{ArticleType} =~ /-int/i;

            # only use 'agent' and 'customer' sender types for calculation
            next ROW if $Row->{SenderType} !~ /^(?:agent|customer)$/;

            # last ROW if latest was customer and the next was not customer
            # otherwise use also next, older customer article as latest
            # customer followup for starting escalation
            if ( $Row->{SenderType} eq 'agent' && $LastSenderType eq 'customer' ) {
                last ROW;
            }

            # start escalation on latest customer article
            if ( $Row->{SenderType} eq 'customer' ) {
                $LastSenderType = 'customer';
                $LastSenderTime = $Row->{Created};
            }

            # start escalation on latest agent article
            if ( $Row->{SenderType} eq 'agent' ) {
                $LastSenderTime = $Row->{Created};
                last ROW;
            }
        }
        if ($LastSenderTime) {
            $Result{'Update'} = 1;
        }
    }

    # check solution escalation
    if ( $Escalation{SolutionTime} ) {

        # find solution time / first close time
        my %SolutionDone = $Self->_TicketGetClosed(
            TicketID => $Ticket{TicketID},
            Ticket   => \%Ticket,
        );

        # update solution time to 0
        if ( !%SolutionDone ) {
            $Result{'Solution'} = 1;
        }
    }

    return \%Result;
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
