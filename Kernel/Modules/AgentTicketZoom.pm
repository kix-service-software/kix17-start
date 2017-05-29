# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketZoom;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use POSIX qw/ceil/;

use Kernel::Language qw(Translatable);
use Kernel::System::EmailParser;
use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # set debug
    $Self->{Debug} = 0;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $Self->{ArticleID}      = $ParamObject->GetParam( Param => 'ArticleID' );
    $Self->{ZoomExpand}     = $ParamObject->GetParam( Param => 'ZoomExpand' );
    $Self->{ZoomExpandSort} = $ParamObject->GetParam( Param => 'ZoomExpandSort' );
    $Self->{ZoomTimeline}   = $ParamObject->GetParam( Param => 'ZoomTimeline' );

    my %UserPreferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    # save last used view type in preferences
    if ( !$Self->{Subaction} ) {

        if ( !defined $Self->{ZoomExpand} && !defined $Self->{ZoomTimeline} ) {
            $Self->{ZoomExpand} = $ConfigObject->Get('Ticket::Frontend::ZoomExpand');
            if ( $UserPreferences{UserLastUsedZoomViewType} ) {
                if ( $UserPreferences{UserLastUsedZoomViewType} eq 'Expand' ) {
                    $Self->{ZoomExpand} = 1;
                }
                elsif ( $UserPreferences{UserLastUsedZoomViewType} eq 'Collapse' ) {
                    $Self->{ZoomExpand} = 0;
                }
                elsif ( $UserPreferences{UserLastUsedZoomViewType} eq 'Timeline' ) {
                    $Self->{ZoomTimeline} = 1;
                }
            }
        }

        elsif ( defined $Self->{ZoomExpand} || defined $Self->{ZoomTimeline} ) {

            my $LastUsedZoomViewType = '';
            if ( defined $Self->{ZoomExpand} && $Self->{ZoomExpand} == 1 ) {
                $LastUsedZoomViewType = 'Expand';
            }
            elsif ( defined $Self->{ZoomExpand} && $Self->{ZoomExpand} == 0 ) {
                $LastUsedZoomViewType = 'Collapse';
            }
            elsif ( defined $Self->{ZoomTimeline} && $Self->{ZoomTimeline} == 1 ) {
                $LastUsedZoomViewType = 'Timeline';
            }
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => 'UserLastUsedZoomViewType',
                Value  => $LastUsedZoomViewType,
            );
        }
    }

    # ddoerffel - T2016121190001552 - BusinessSolution code removed

    if ( !defined $Self->{DoNotShowBrowserLinkMessage} ) {
        if ( $UserPreferences{UserAgentDoNotShowBrowserLinkMessage} ) {
            $Self->{DoNotShowBrowserLinkMessage} = 1;
        }
        else {
            $Self->{DoNotShowBrowserLinkMessage} = 0;
        }
    }

    if ( !defined $Self->{ZoomExpandSort} ) {
        $Self->{ZoomExpandSort} = $ConfigObject->Get('Ticket::Frontend::ZoomExpandSort');
    }

    $Self->{ArticleFilterActive} = $ConfigObject->Get('Ticket::Frontend::TicketArticleFilter');

    # define if rich text should be used
    $Self->{RichText} = $ConfigObject->Get('Ticket::Frontend::ZoomRichTextForce')
        || $LayoutObject->{BrowserRichText}
        || 0;

    # strip html and ascii attachments of content
    $Self->{StripPlainBodyAsAttachment} = 1;

    # check if rich text is enabled, if not only strip ascii attachments
    if ( !$Self->{RichText} ) {
        $Self->{StripPlainBodyAsAttachment} = 2;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # ticket id lookup
    if ( !$Self->{TicketID} && $ParamObject->GetParam( Param => 'TicketNumber' ) ) {
        $Self->{TicketID} = $TicketObject->TicketIDLookup(
            TicketNumber => $ParamObject->GetParam( Param => 'TicketNumber' ),
            UserID       => $Self->{UserID},
        );
    }

    # KIX4OTRS-capeIT
    # removed: create additional objects for process management
    # EO KIX4OTRS-capeIT

    # get zoom settings depending on ticket type
    $Self->{DisplaySettings} = $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom");

    # KIX4OTRS-capeIT
    # removed: mapping of history types
    # removed: time-line config
    # EO KIX4OTRS-capeIT

    # KIX4OTRS-capeIT
    $Self->{DirectLinkAnchor} = $ParamObject->GetParam( Param => 'DirectLinkAnchor' ) || '';

    # EO KIX4OTRS-capeIT

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    return $LayoutObject->NoPermission(
        Message => Translatable(
            'We are sorry, you do not have permissions anymore to access this ticket in its current state.'
        ),
        WithHeader => 'yes',
    ) if !$Access;

    # get ticket attributes
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # KIX4OTRS-capeIT
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Config =
        $ConfigObject->Get('Ticket::Frontend::AgentTicketZoom');

    # customer info
    my %TicketCustomerData = ();
    if (
        $ConfigObject->Get('Ticket::Frontend::CustomerInfoZoom')
        && $Ticket{CustomerUserID}
        )
    {
        %TicketCustomerData = $CustomerUserObject->CustomerUserDataGet(
            User => $Ticket{CustomerUserID},
        );
    }

    # get selected tab
    $Param{SelectedTab} = $ParamObject->GetParam( Param => 'SelectedTab' );
    if ( !$Param{SelectedTab} ) {
        $Param{SelectedTab} = '0';
    }

    # EO KIX4OTRS-capeIT

    # get ACL restrictions
    my %PossibleActions;
    my $Counter = 0;

    # get all registered Actions
    if ( ref $ConfigObject->Get('Frontend::Module') eq 'HASH' ) {

        my %Actions = %{ $ConfigObject->Get('Frontend::Module') };

        # only use those Actions that stats with Agent
        %PossibleActions = map { ++$Counter => $_ }
            grep { substr( $_, 0, length 'Agent' ) eq 'Agent' }
            sort keys %Actions;
    }

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );

    my %AclAction = %PossibleActions;
    if ($ACL) {
        %AclAction = $TicketObject->TicketAclActionData();
    }

    # check if ACL restrictions exist
    my %AclActionLookup = reverse %AclAction;

    # show error screen if ACL prohibits this action
    if ( !$AclActionLookup{ $Self->{Action} } ) {
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }

    # mark shown ticket as seen
    if ( $Self->{Subaction} eq 'TicketMarkAsSeen' ) {
        my $Success = 1;

        # always show archived tickets as seen
        if ( $Ticket{ArchiveFlag} ne 'y' ) {
            $Success = $Self->_TicketItemSeen( TicketID => $Self->{TicketID} );
        }

        return $LayoutObject->Attachment(
            ContentType => 'text/html',
            Content     => $Success,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    if ( $Self->{Subaction} eq 'MarkAsImportant' ) {

        # Owner and Responsible can mark articles as important or remove mark
        if (
            $Self->{UserID} == $Ticket{OwnerID}
            || (
                $ConfigObject->Get('Ticket::Responsible')
                && $Self->{UserID} == $Ticket{ResponsibleID}
            )
            )
        {

            # Always use user id 1 because other users also have to see the important flag
            my %ArticleFlag = $TicketObject->ArticleFlagGet(
                ArticleID => $Self->{ArticleID},
                UserID    => 1,
            );

            my $ArticleIsImportant = $ArticleFlag{Important};
            if ($ArticleIsImportant) {

                # Always use user id 1 because other users also have to see the important flag
                $TicketObject->ArticleFlagDelete(
                    ArticleID => $Self->{ArticleID},
                    Key       => 'Important',
                    UserID    => 1,
                );
            }
            else {

                # Always use user id 1 because other users also have to see the important flag
                $TicketObject->ArticleFlagSet(
                    ArticleID => $Self->{ArticleID},
                    Key       => 'Important',
                    Value     => 1,
                    UserID    => 1,
                );
            }
        }

        return $LayoutObject->Redirect(
            OP => "Action=AgentTicketZoom;TicketID=$Self->{TicketID};ArticleID=$Self->{ArticleID}",
        );
    }

    # get param object
    # KIX4OTRS-capeIT
    # moved content upwards
    # my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    # EO KIX4OTRS-capeIT

    # mark shown article as seen
    if ( $Self->{Subaction} eq 'MarkAsSeen' ) {
        my $Success = 1;

        # always show archived tickets as seen
        if ( $Ticket{ArchiveFlag} ne 'y' ) {
            $Success = $Self->_ArticleItemSeen( ArticleID => $Self->{ArticleID} );
        }

        return $LayoutObject->Attachment(
            ContentType => 'text/html',
            Content     => $Success,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # article update
    elsif ( $Self->{Subaction} eq 'ArticleUpdate' ) {
        my $Count = $ParamObject->GetParam( Param => 'Count' );
        my %Article = $TicketObject->ArticleGet(
            ArticleID     => $Self->{ArticleID},
            DynamicFields => 0,
        );
        $Article{Count} = $Count;

        # get attachment index (without attachments)
        my %AtmIndex = $TicketObject->ArticleAttachmentIndex(
            ArticleID                  => $Self->{ArticleID},
            StripPlainBodyAsAttachment => $Self->{StripPlainBodyAsAttachment},
            Article                    => \%Article,
            UserID                     => $Self->{UserID},
        );
        $Article{Atms} = \%AtmIndex;

        # fetch all std. templates
        my %StandardTemplates
            = $Kernel::OM->Get('Kernel::System::Queue')->QueueStandardTemplateMemberList(
            QueueID       => $Ticket{QueueID},
            TemplateTypes => 1,
            Valid         => 1,
        );

        $Self->_ArticleItem(
            Ticket            => \%Ticket,
            Article           => \%Article,
            AclAction         => \%AclAction,
            StandardResponses => $StandardTemplates{Answer},
            StandardForwards  => $StandardTemplates{Forward},
            Type              => 'OnLoad',
        );
        my $Content = $LayoutObject->Output(
            TemplateFile => 'AgentTicketZoom',
            Data         => { %Ticket, %Article, %AclAction },
        );
        if ( !$Content ) {
            $LayoutObject->FatalError(
                Message =>
                    $LayoutObject->{LanguageObject}->Translate( 'Can\'t get for ArticleID %s!', $Self->{ArticleID} ),
            );
        }
        return $LayoutObject->Attachment(
            ContentType => 'text/html',
            Charset     => $LayoutObject->{UserCharset},
            Content     => $Content,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # get needed objects
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

    # write article filter settings to session
    if ( $Self->{Subaction} eq 'ArticleFilterSet' ) {

        # get params
        my $TicketID     = $ParamObject->GetParam( Param => 'TicketID' );
        my $SaveDefaults = $ParamObject->GetParam( Param => 'SaveDefaults' );
        my @ArticleTypeFilterIDs       = $ParamObject->GetArray( Param => 'ArticleTypeFilter' );
        my @ArticleSenderTypeFilterIDs = $ParamObject->GetArray( Param => 'ArticleSenderTypeFilter' );

        # build session string
        my $SessionString = '';
        if (@ArticleTypeFilterIDs) {
            $SessionString .= 'ArticleTypeFilter<';
            $SessionString .= join ',', @ArticleTypeFilterIDs;
            $SessionString .= '>';
        }
        if (@ArticleSenderTypeFilterIDs) {
            $SessionString .= 'ArticleSenderTypeFilter<';
            $SessionString .= join ',', @ArticleSenderTypeFilterIDs;
            $SessionString .= '>';
        }

        # write the session

        # save default filter settings to user preferences
        if ($SaveDefaults) {
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => 'ArticleFilterDefault',
                Value  => $SessionString,
            );
            $SessionObject->UpdateSessionID(
                SessionID => $Self->{SessionID},
                Key       => 'ArticleFilterDefault',
                Value     => $SessionString,
            );
        }

        # turn off filter explicitly for this ticket
        if ( $SessionString eq '' ) {
            $SessionString = 'off';
        }

        # update the session
        my $Update = $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => "ArticleFilter$TicketID",
            Value     => $SessionString,
        );

        # build JSON output
        my $JSON = '';
        if ($Update) {
            $JSON = $LayoutObject->JSONEncode(
                Data => {
                    Message => Translatable('Article filter settings were saved.'),
                },
            );
        }

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # KIX4OTRS-capeIT
    # update position
    elsif ( $Self->{Subaction} eq 'UpdatePosition' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my @Backends = $ParamObject->GetArray( Param => 'Backend' );

        # get new order
        my $Key  = $Self->{Action} . 'Position';
        my $Data = '';
        for my $Backend (@Backends) {
            $Data .= $Backend . ';';
        }

        # update ssession
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => $Key,
            Value     => $Data,
        );

        # update preferences
        if ( !$ConfigObject->Get('DemoSystem') ) {
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Key,
                Value  => $Data,
            );
        }

        # redirect
        return $LayoutObject->Attachment(
            ContentType => 'text/html',
            Charset     => $LayoutObject->{UserCharset},
            Content     => '',
        );
    }

    # EO KIX4OTRS-capeIT

    # KIX4OTRS-capeIT
    # removed: article filter handling
    # EO KIX4OTRS-capeIT

    # generate output
    my $Output = $LayoutObject->Header(
        Value    => $Ticket{TicketNumber},
        TicketID => $Ticket{TicketID},
    );
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $Self->MaskAgentZoom(
        Ticket    => \%Ticket,
        AclAction => \%AclAction,

        # KIX4OTRS-capeIT
        CustomerData => \%TicketCustomerData,
        SelectedTab  => $Param{SelectedTab},

        # EO KIX4OTRS-capeIT
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub MaskAgentZoom {
    my ( $Self, %Param ) = @_;

    my %Ticket    = %{ $Param{Ticket} };
    my %AclAction = %{ $Param{AclAction} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # KIX4OTRS-capeIT
    my %CustomerData = %{ $Param{CustomerData} };

    # the next is needed, otherwise the tabs will have no TicketID parameter in merged tickets
    $Param{TicketID} = $Ticket{TicketID};

    # EO KIX4OTRS-capeIT

    # else show normal ticket zoom view
    # fetch all move queues
    my %MoveQueues = $TicketObject->MoveList(
        TicketID => $Ticket{TicketID},
        UserID   => $Self->{UserID},
        Action   => $Self->{Action},
        Type     => 'move_into',
    );

    # fetch all std. templates
    my %StandardTemplates = $Kernel::OM->Get('Kernel::System::Queue')->QueueStandardTemplateMemberList(
        QueueID       => $Ticket{QueueID},
        TemplateTypes => 1,
    );

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    # owner info
    my %OwnerInfo = $UserObject->GetUserData(
        UserID => $Ticket{OwnerID},
    );

    # responsible info
    my %ResponsibleInfo = $UserObject->GetUserData(
        UserID => $Ticket{ResponsibleID} || 1,
    );

    # get cofig object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # KIX4OTRS-capeIT
    # get user preferences
    my %Preferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );

    # set display options
    $Param{Hook} = $ConfigObject->Get('Ticket::Hook') || 'Ticket#';

    # EO KIX4OTRS-capeIT

    # generate shown articles
    my $Limit = $ConfigObject->Get('Ticket::Frontend::MaxArticlesPerPage');

    my $Order = $Self->{ZoomExpandSort} eq 'reverse' ? 'DESC' : 'ASC';
    my $Page;

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get article page
    my $ArticlePage = $ParamObject->GetParam( Param => 'ArticlePage' );

    if ( $Self->{ArticleID} ) {
        $Page = $TicketObject->ArticlePage(
            TicketID    => $Self->{TicketID},
            ArticleID   => $Self->{ArticleID},
            RowsPerPage => $Limit,
            Order       => $Order,
            %{ $Self->{ArticleFilter} // {} },
        );
    }
    elsif ($ArticlePage) {
        $Page = $ArticlePage;
    }
    else {
        $Page = 1;
    }

    # KIX4OTRS-capeIT
    $Param{ArticlePage} = $Page;
    # EO KIX4OTRS-capeIT

    # We need to find out whether pagination is actually necessary.
    # The easiest way would be count the articles, but that would slow
    # down the most common case (fewer articles than $Limit in the ticket).
    # So instead we use the following trick:
    # 1) if the $Page > 1, we need pagination
    # 2) if not, request $Limit + 1 articles. If $Limit + 1 are actually
    #    returned, pagination is necessary
    my $Extra = $Page > 1 ? 0 : 1;
    my $NeedPagination;
    my $ArticleCount;

    my @ArticleContentArgs = (
        TicketID                   => $Self->{TicketID},
        StripPlainBodyAsAttachment => $Self->{StripPlainBodyAsAttachment},
        UserID                     => $Self->{UserID},
        Limit                      => $Limit + $Extra,
        Order                      => $Order,
        DynamicFields => 0,    # fetch later only for the article(s) to display
        %{ $Self->{ArticleFilter} // {} },    # limit by ArticleSenderTypeID/ArticleTypeID

    );

    # get content
    my @ArticleBox = $TicketObject->ArticleContentIndex(
        @ArticleContentArgs,
        Page => $Page,
    );

    if ( !@ArticleBox && $Page > 1 ) {

        # if the page argument is past the actual number of pages,
        # assume page 1 instead.
        # This can happen when a new article filter was added.
        $Page       = 1;
        @ArticleBox = $TicketObject->ArticleContentIndex(
            @ArticleContentArgs,
            Page => $Page,
        );
        $ArticleCount = $TicketObject->ArticleCount(
            TicketID => $Self->{TicketID},
            %{ $Self->{ArticleFilter} // {} },
        );
        $NeedPagination = $ArticleCount > $Limit;
    }
    elsif ( @ArticleBox > $Limit ) {
        pop @ArticleBox;
        $NeedPagination = 1;
        $ArticleCount   = $TicketObject->ArticleCount(
            TicketID => $Self->{TicketID},
            %{ $Self->{ArticleFilter} // {} },
        );
    }
    elsif ( $Page == 1 ) {
        $ArticleCount   = @ArticleBox;
        $NeedPagination = 0;
    }
    else {
        $NeedPagination = 1;
        $ArticleCount   = $TicketObject->ArticleCount(
            TicketID => $Ticket{TicketID},
            %{ $Self->{ArticleFilter} // {} },
        );
    }

    $Page ||= 1;

    my $Pages;
    if ($NeedPagination) {
        $Pages = ceil( $ArticleCount / $Limit );
    }

    my $Count;
    if ( $ConfigObject->Get('Ticket::Frontend::ZoomExpandSort') eq 'reverse' ) {
        $Count = scalar @ArticleBox + 1;
    }
    else {
        $Count = 0;
    }

    # get all articles
    my @ArticleContentArgsAll = (
        TicketID                   => $Self->{TicketID},
        StripPlainBodyAsAttachment => $Self->{StripPlainBodyAsAttachment},
        UserID                     => $Self->{UserID},
        Order                      => $Order,
        DynamicFields => 0,    # fetch later only for the article(s) to display
    );
    my @ArticleBoxAll = $TicketObject->ArticleContentIndex(@ArticleContentArgsAll);

    if ( scalar @ArticleBox != scalar @ArticleBoxAll ) {

        if ( $ConfigObject->Get('Ticket::Frontend::ZoomExpandSort') eq 'reverse' ) {
            $Count = scalar @ArticleBoxAll + 1;
        }

        for my $Article (@ArticleBoxAll) {
            if ( $ConfigObject->Get('Ticket::Frontend::ZoomExpandSort') eq 'reverse' ) {
                $Count--;
            }
            else {
                $Count++;
            }
            $Article->{Count} = $Count;
        }
    }

    my $ArticleIDFound = 0;
    ARTICLE:
    for my $Article (@ArticleBox) {

        if ( scalar @ArticleBox != scalar @ArticleBoxAll ) {
            my @ArticleOnPage = grep { $_->{ArticleID} =~ $Article->{ArticleID} } @ArticleBoxAll;
            $Article->{Count} = $ArticleOnPage[0]->{Count};
        }
        else {
            if ( $ConfigObject->Get('Ticket::Frontend::ZoomExpandSort') eq 'reverse' ) {
                $Count--;
            }
            else {
                $Count++;
            }
            $Article->{Count} = $Count;
        }

        next ARTICLE if !$Self->{ArticleID};
        next ARTICLE if !$Article->{ArticleID};
        next ARTICLE if $Self->{ArticleID} ne $Article->{ArticleID};

        $ArticleIDFound = 1;
    }

    my %ArticleFlags = $TicketObject->ArticleFlagsOfTicketGet(
        TicketID => $Ticket{TicketID},
        UserID   => $Self->{UserID},
    );

    # get selected or last customer article
    my $ArticleID;
    if ($ArticleIDFound) {
        $ArticleID = $Self->{ArticleID};
    }
    else {

        # find latest not seen article
        ARTICLE:
        for my $Article (@ArticleBox) {

            # ignore system sender type
            next ARTICLE
                if $ConfigObject->Get('Ticket::NewArticleIgnoreSystemSender')
                && $Article->{SenderType} eq 'system';

            next ARTICLE if $ArticleFlags{ $Article->{ArticleID} }->{Seen};
            $ArticleID = $Article->{ArticleID};
            last ARTICLE;
        }

        # set selected article
        if ( !$ArticleID ) {
            if (@ArticleBox) {

                # set first listed article as fallback
                $ArticleID = $ArticleBox[0]->{ArticleID};
            }

            # set last customer article as selected article replacing last set
            ARTICLETMP:
            for my $ArticleTmp (@ArticleBox) {
                if ( $ArticleTmp->{SenderType} eq 'customer' ) {
                    $ArticleID = $ArticleTmp->{ArticleID};
                    last ARTICLETMP if $Self->{ZoomExpandSort} eq 'reverse';
                }
            }
        }
    }

    # check if expand view is usable (only for less then 400 article)
    # if you have more articles is going to be slow and not usable
    my $ArticleMaxLimit = $ConfigObject->Get('Ticket::Frontend::MaxArticlesZoomExpand')
        // 400;
    if ( $Self->{ZoomExpand} && $#ArticleBox > $ArticleMaxLimit ) {
        $Self->{ZoomExpand} = 0;
    }

    # get shown article(s)
    my @ArticleBoxShown;
    if ( !$Self->{ZoomExpand} ) {
        ARTICLEBOX:
        for my $ArticleTmp (@ArticleBox) {
            if ( $ArticleID eq $ArticleTmp->{ArticleID} ) {
                push @ArticleBoxShown, $ArticleTmp;
                last ARTICLEBOX;
            }
        }
    }
    else {
        @ArticleBoxShown = @ArticleBox;
    }

    # KIX4OTRS-capeIT
    # removed: article tree
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # EO KIX4OTRS-capeIT

    # age design
    $Ticket{Age} = $LayoutObject->CustomerAge(
        Age   => $Ticket{Age},
        Space => ' '
    );

    # number of articles
    $Param{ArticleCount} = scalar @ArticleBox;

    # KIX4OTRS-capeIT
    # if ( $ConfigObject->Get('Ticket::UseArticleColors') ) {
    if ( $ConfigObject->Get('Ticket::UseArticleColors') && $Preferences{UserUseArticleColors} ) {

        # EO KIX4OTRS-capeIT
        $Param{UseArticleColors} = 1;
    }

    # KIX4OTRS-capeIT
    # load KIXSidebar
    my $Config =
        $ConfigObject->Get('Ticket::Frontend::AgentTicketZoom');
    $Param{KIXSidebarContent} = $LayoutObject->AgentKIXSidebar(
        %Param,
        ModuleConfig    => $Config,              # needed for KIXSidebarTicketInfo
        ResponsibleInfo => \%ResponsibleInfo,    # needed for KIXSidebarTicketInfo
        AclAction       => \%AclAction,          # needed for KIXSidebarTicketInfo
    );

    # check if CKEditor is activated
    $Param{RichTextEditorActivated} = $LayoutObject->{BrowserRichText};

    # EO KIX4OTRS-capeIT

    $LayoutObject->Block(
        Name => 'Header',
        Data => { %Param, %Ticket, %AclAction },
    );

    # run ticket menu modules
    if ( ref $ConfigObject->Get('Ticket::Frontend::MenuModule') eq 'HASH' ) {
        my %Menus = %{ $ConfigObject->Get('Ticket::Frontend::MenuModule') };
        my %MenuClusters;
        my %ZoomMenuItems;

        MENU:
        for my $Menu ( sort keys %Menus ) {

            # load module
            if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Menus{$Menu}->{Module} ) ) {
                return $LayoutObject->FatalError();
            }

            my $Object = $Menus{$Menu}->{Module}->new(
                %{$Self},
                TicketID => $Self->{TicketID},
            );

            # run module
            my $Item = $Object->Run(
                %Param,
                Ticket => \%Ticket,
                ACL    => \%AclAction,
                Config => $Menus{$Menu},
            );
            next MENU if !$Item;
            if ( $Menus{$Menu}->{PopupType} ) {
                $Item->{Class} = "AsPopup PopupType_$Menus{$Menu}->{PopupType}";
            }

            if ( !$Menus{$Menu}->{ClusterName} ) {

                $ZoomMenuItems{$Menu} = $Item;
            }
            else {

                # check the configured priority for this item. The lowest ClusterPriority
                # within the same cluster wins.
                my $Priority = $MenuClusters{ $Menus{$Menu}->{ClusterName} }->{Priority};
                if ( !$Priority || $Priority !~ /^\d{3}$/ || $Priority > $Menus{$Menu}->{ClusterPriority} ) {
                    $Priority = $Menus{$Menu}->{ClusterPriority};
                }
                $MenuClusters{ $Menus{$Menu}->{ClusterName} }->{Priority} = $Priority;
                $MenuClusters{ $Menus{$Menu}->{ClusterName} }->{Items}->{$Menu} = $Item;
            }
        }

        for my $Cluster ( sort keys %MenuClusters ) {
            $ZoomMenuItems{ $MenuClusters{$Cluster}->{Priority} . $Cluster } = {
                Name  => $Cluster,
                Type  => 'Cluster',
                Link  => '#',
                Class => 'ClusterLink',
                Items => $MenuClusters{$Cluster}->{Items},
                }
        }

        # display all items
        for my $Item ( sort keys %ZoomMenuItems ) {

            $LayoutObject->Block(
                Name => 'TicketMenu',
                Data => $ZoomMenuItems{$Item},
            );

            if ( $ZoomMenuItems{$Item}->{Type} eq 'Cluster' ) {

                $LayoutObject->Block(
                    Name => 'TicketMenuSubContainer',
                    Data => {
                        Name => $ZoomMenuItems{$Item}->{Name},
                    },
                );

                for my $SubItem ( sort keys %{ $ZoomMenuItems{$Item}->{Items} } ) {
                    $LayoutObject->Block(
                        Name => 'TicketMenuSubContainerItem',
                        Data => $ZoomMenuItems{$Item}->{Items}->{$SubItem},
                    );
                }
            }
        }
    }

    # get MoveQueuesStrg
    if ( $ConfigObject->Get('Ticket::Frontend::MoveType') =~ /^form$/i ) {
        $MoveQueues{0} = '- ' . $LayoutObject->{LanguageObject}->Translate('Move') . ' -';
        $Param{MoveQueuesStrg} = $LayoutObject->AgentQueueListOption(
            Name           => 'DestQueueID',
            Data           => \%MoveQueues,
            Class          => 'Modernize Small',
            CurrentQueueID => $Ticket{QueueID},
        );

        # KIX4OTRS-capeIT
        # replace class W75pc with W75 - causes no line break
        $Param{MoveQueuesStrg} =~ s/W75pc/W75/;

        # EO KIX4OTRS-capeIT
    }
    my %AclActionLookup = reverse %AclAction;
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketMove}
        && ( $AclActionLookup{AgentTicketMove} )
        )
    {
        my $Access = $TicketObject->TicketPermission(
            Type     => 'move',
            TicketID => $Ticket{TicketID},
            UserID   => $Self->{UserID},
            LogNo    => 1,
        );
        $Param{TicketID} = $Ticket{TicketID};
        if ($Access) {
            if ( $ConfigObject->Get('Ticket::Frontend::MoveType') =~ /^form$/i ) {
                $LayoutObject->Block(
                    Name => 'MoveLink',
                    Data => { %Param, %AclAction },
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'MoveForm',
                    Data => { %Param, %AclAction },
                );
            }
        }
    }

    # KIX4OTRS-capeIT
    $Param{ZoomExpand} = $Self->{ZoomExpand};
    $Param{ZoomTimeline} = $Self->{ZoomTimeline};

    # check if ticket is normal or process ticket
    my $IsProcessTicket = $TicketObject->TicketCheckForProcessType(
        'TicketID' => $Ticket{TicketID}
    );

    # mark ticket as seen if no article given and ticket is a process ticket
    if ( $IsProcessTicket ) {
        my $ArticleCount = $TicketObject->ArticleCount(
            TicketID => $Self->{TicketID},
        );
        if (!$ArticleCount) {
            $TicketObject->TicketFlagSet(
                TicketID => $Self->{TicketID},
                Key      => 'Seen',
                Value    => 1,
                UserID   => $Self->{UserID},
            );
        }
    }

    # generate content of ticket zoom tabs
    my $TicketZoomBackendRef = $ConfigObject->Get('AgentTicketZoomBackend');
    if ( $TicketZoomBackendRef && ref($TicketZoomBackendRef) eq 'HASH' ) {
        for my $CurrKey ( sort keys %{$TicketZoomBackendRef} ) {

            # only show process information tab if ticket is process ticket
            next if !$IsProcessTicket && $CurrKey =~ /Process/;

            my $BackendShortRef = $TicketZoomBackendRef->{$CurrKey};

            # check for ACL restriction
            my %AclAllowedActions = reverse %AclAction;

            if ( $BackendShortRef->{Link} ) {
                my $BackendAction = $BackendShortRef->{Link};
                $BackendAction =~ s/Action=([^;]+)(;.+|$)/$1/;

                # do not show tabs by hash key
                next
                    if (
                    defined $AclAction{ $Self->{Action} . '###' . $CurrKey }
                    && !$AclAction{ $Self->{Action} . '###' . $CurrKey }
                    );

                # do not show tabs by action
                next
                    if (
                    $BackendAction
                    && !defined $AclAllowedActions{$BackendAction}
                    );
            }
            elsif ( $BackendShortRef->{PreloadModule} ) {
                next
                    if ( !defined $AclAllowedActions{ $BackendShortRef->{PreloadModule} } );
            }

            # check for ticket permissions
            my $Access = $TicketObject->TicketPermission(
                Type => $BackendShortRef->{Permission} || 'ro',
                TicketID => $Self->{TicketID},
                UserID   => $Self->{UserID},
            );
            next if !$Access;

            # perform count if method registered...
            my $Count = '';
            if (
                $BackendShortRef->{CountMethod}
                &&
                (
                    $BackendShortRef->{CountMethod} =~ /CallMethod::(\w+)Object::(\w+)::(\w+)/
                    ||
                    $BackendShortRef->{CountMethod} =~ /CallMethod::(\w+)Object::(\w+)/
                )
                )
            {
                my $ObjectType = $1;
                my $Method     = $2;
                my $Hashresult = $3;

                my $DisplayResult;
                my $Object;
                if ( $Hashresult && $Hashresult ne '' ) {
                    eval {
                        $Object        = $Kernel::OM->Get( 'Kernel::System::' . $ObjectType );
                        $DisplayResult = {
                            $Object->$Method(
                                %Ticket,
                                %CustomerData,
                                %ResponsibleInfo,
                                UserID => $Self->{UserID}
                                )
                        }->{$Hashresult};
                    };
                }
                else {
                    eval {
                        $Object = $Kernel::OM->Get( 'Kernel::System::' . $ObjectType );
                        $DisplayResult =
                            $Object->$Method(
                            %Ticket,
                            %CustomerData,
                            %ResponsibleInfo,
                            UserID => $Self->{UserID}
                            );
                    };
                }

                if ($DisplayResult) {
                    $Count = $DisplayResult;
                }
                if ($@) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "KIX4OTRS::Kernel::Modules::AgentTicketZoom::TabCount - "
                            . " invalid CallMethod ($Object->$Method) configured "
                            . "(" . $@ . ")!",
                    );
                }
            }

            my $DirectLinkAnchor = $BackendShortRef->{Description};
            $DirectLinkAnchor =~ s/\s/_/g;

            # register as tab if link registered...
            my $Link = $BackendShortRef->{Link};
            if ($Link) {
                $Link =~ s{
                      \$Param\{"([^"]+)"\}
                    }
                    {
                      if ( defined $1 ) {
                        $Param{$1} || '';
                      }
                    }egx;

                my $TemplateString = $Link . ";DirectLinkAnchor=" . $DirectLinkAnchor;
                $TemplateString = $LayoutObject->Output(
                    Template => $TemplateString,
                );

                $LayoutObject->Block(
                    Name => 'DataTabDataLink',
                    Data => {
                        Link        => $TemplateString,
                        Description => $BackendShortRef->{Description},
                        Label       => $BackendShortRef->{Title},
                        LabelCount  => $Count ? " (" . $Count . ")" : '',
                    },
                );
            }

            # preload content if preload module registered...
            if ( $BackendShortRef->{PreloadModule} ) {
                $LayoutObject->Block(
                    Name => 'DataTabDataPreloaded',
                    Data => {
                        Anchor      => $CurrKey,
                        Description => $BackendShortRef->{Description},
                        Label       => $BackendShortRef->{Title},
                        LabelCount  => $Count ? " (" . $Count . ")" : '',
                    },
                );

                # check for existence of module
                my $Module = $BackendShortRef->{PreloadModule};
                return if !$Kernel::OM->Get('Kernel::System::Main')->Require($Module);

                # and run reloadmodule
                my $Object = $Module->new( %{$Self} );
                my $ContentStrg = $Object->Run(%Param) || '';

                $LayoutObject->Block(
                    Name => 'DataTabContentPreloaded',
                    Data => {
                        Anchor      => $CurrKey,
                        ContentStrg => $ContentStrg,
                    },
                );
            }

            # EO KIX4OTRS-capeIT

        }
    }

    # init js
    $LayoutObject->Block(
        Name => 'TicketZoomInit',
        Data => {%Param},
    );

    # KIX4OTRS-capeIT
    # removed: article flag handling
    # removed: linked object table
    # removed: sidebar content - done via sidebar plugin
    # EO KIX4OTRS-capeIT

    # return output
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketZoom',
        Data => { %Param, %Ticket, %AclAction },
    );
}

# KIX4OTRS-capeIT
# removed: article tree functions
# EO KIX4OTRS-capeIT

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
