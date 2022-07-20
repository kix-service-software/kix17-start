# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketZoomTabArticle;

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
    $Self->{ZoomExpand}     = $ParamObject->GetParam( Param => 'ZoomExpand' )      || 0;
    $Self->{ZoomExpandSort} = $ParamObject->GetParam( Param => 'ZoomExpandSort' );

    my %UserPreferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    # save last used view type in preferences
    if ( !$Self->{Subaction} ) {

        if ( !$Self->{ZoomExpand} ) {

            $Self->{ZoomExpand} = $ConfigObject->Get('Ticket::Frontend::ZoomExpand');
            if ( $UserPreferences{UserLastUsedZoomViewType} ) {
                if ( $UserPreferences{UserLastUsedZoomViewType} eq 'Expand' ) {
                    $Self->{ZoomExpand} = 1;
                }
                elsif ( $UserPreferences{UserLastUsedZoomViewType} eq 'Collapse' ) {
                    $Self->{ZoomExpand} = 0;
                }
            }
        }

        elsif ( defined $Self->{ZoomExpand} ) {

            my $LastUsedZoomViewType = '';
            if ( defined $Self->{ZoomExpand} && $Self->{ZoomExpand} == 1 ) {
                $LastUsedZoomViewType = 'Expand';
            }
            elsif ( defined $Self->{ZoomExpand} && $Self->{ZoomExpand} == 0 ) {
                $LastUsedZoomViewType = 'Collapse';
            }
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => 'UserLastUsedZoomViewType',
                Value  => $LastUsedZoomViewType,
            );
        }
    }

    if ( !defined $Self->{DoNotShowBrowserLinkMessage} ) {
        if ( $UserPreferences{UserAgentDoNotShowBrowserLinkMessage} ) {
            $Self->{DoNotShowBrowserLinkMessage} = 1;
        }
        else {
            $Self->{DoNotShowBrowserLinkMessage} = 0;
        }
    }

    if ( $UserPreferences{UserArticleTableColumnResizing} ) {
        $Self->{ColumnResizing} = $UserPreferences{UserArticleTableColumnResizing};
    }
    else {
        $Self->{ColumnResizing} = '';
    }

    if ( !defined $Self->{ZoomExpandSort} ) {
        $Self->{ZoomExpandSort} = $ConfigObject->Get('Ticket::Frontend::ZoomExpandSort');
    }

    $Self->{ArticleFilterActive} = $ConfigObject->Get('Ticket::Frontend::TicketArticleFilter');

    # get usage of article colors
    $Self->{UseArticleColors} = 0;
    if (
        $ConfigObject->Get('Ticket::UseArticleColors')
        && $UserPreferences{UserUseArticleColors}
    ) {
        $Self->{UseArticleColors} = 1;
    }

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

    $Self->{Config}           = $ConfigObject->Get('Ticket::Frontend::AgentTicketZoomTabArticle');
    $Self->{CallingAction}    = $ParamObject->GetParam( Param => 'CallingAction' ) || '';
    $Self->{DirectLinkAnchor} = $ParamObject->GetParam( Param => 'DirectLinkAnchor' ) || '';

    # get dynamic field config for frontend module
    $Self->{DynamicFieldFilter} = {
        %{
            $ConfigObject->Get("Ticket::Frontend::AgentTicketZoomTabArticle")
                ->{DynamicField} || {}
        },
    };

    my %ShowFields = ();
    for my $Field ( keys %{ $Self->{DynamicFieldFilter} } ) {
        if ( $Self->{DynamicFieldFilter}->{$Field} == 2 ) {
            $ShowFields{$Field} = 1;
            $Self->{DynamicFieldFilter}->{$Field} = 0;
        }
        elsif ( $Self->{DynamicFieldFilter}->{$Field} > 2 ) {
            $ShowFields{$Field} = 1;
        }
    }
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{DynamicFieldShow} = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Article'],
        FieldFilter => \%ShowFields,
    );
    $Self->{DynamicFieldActiveFilter} = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Article'],
        FieldFilter => $ConfigObject->Get("Ticket::Frontend::AgentTicketZoomTabArticle")
            ->{DynamicFieldActiveFilter} || {},
    );

    # get zoom settings depending on ticket type
    $Self->{DisplaySettings} = $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom");

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

    # get ACL restrictions
    my %PossibleActions;
    my $Counter = 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $ImagePath = $ConfigObject->Get('Frontend::ImagePath');

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
        ) {

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
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

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

    # set article flag
    elsif ( $Self->{Subaction} eq 'ArticleFlagSet' ) {

        # get article flag key
        my $ArticleFlagKey = $ParamObject->GetParam( Param => 'ArticleFlagKey' );

        # get article flag data
        my $ArticleFlagKeywords = $ParamObject->GetParam( Param => 'ArticleFlagKeywords' );
        my $ArticleFlagSubject  = $ParamObject->GetParam( Param => 'ArticleFlagSubject' );
        my $ArticleFlagNote     = $ParamObject->GetParam( Param => 'ArticleFlagNote' );

        # set article flag
        $TicketObject->ArticleFlagSet(
            ArticleID => $Self->{ArticleID},
            Key       => $ArticleFlagKey,
            Value     => 1,
            UserID    => $Self->{UserID},
        );

        # set additional data for article flag
        $TicketObject->ArticleFlagDataSet(
            ArticleID => $Self->{ArticleID},
            Key       => $ArticleFlagKey,
            Keywords  => $ArticleFlagKeywords,
            Subject   => $ArticleFlagSubject,
            Note      => $ArticleFlagNote,
            UserID    => $Self->{UserID},
        );
    }

    # set article flag
    elsif ( $Self->{Subaction} eq 'ArticleFlagUpdate' ) {

        # get article flag key
        my $ArticleFlagKey = $ParamObject->GetParam( Param => 'ArticleFlagKey' );

        # get article flag data
        my $ArticleFlagKeywords = $ParamObject->GetParam( Param => 'ArticleFlagKeywords' );
        my $ArticleFlagSubject  = $ParamObject->GetParam( Param => 'ArticleFlagSubject' );
        my $ArticleFlagNote     = $ParamObject->GetParam( Param => 'ArticleFlagNote' );

        # get a list of all available article flags from sysconfig
        my %ArticleFlagList = ();
        if ( defined $Self->{Config}->{ArticleFlags}
            && ref $Self->{Config}->{ArticleFlags} eq 'HASH'
        ) {
            %ArticleFlagList = %{ $Self->{Config}->{ArticleFlags} };
        }

        # delete existing article flag
        if ( defined $ArticleFlagList{$ArticleFlagKey} && $ArticleFlagList{$ArticleFlagKey} ) {

            # delete article flag
            my $Success = $TicketObject->ArticleFlagDelete(
                ArticleID => $Self->{ArticleID},
                Key       => $ArticleFlagKey,
                UserID    => $Self->{UserID},
            );

            if ($Success) {

                # delete additional data for article flag
                $Success = $TicketObject->ArticleFlagDataDelete(
                    ArticleID => $Self->{ArticleID},
                    Key       => $ArticleFlagKey,
                    UserID    => $Self->{UserID},
                );
            }

            # set article flag
            $TicketObject->ArticleFlagSet(
                ArticleID => $Self->{ArticleID},
                Key       => $ArticleFlagKey,
                Value     => 1,
                UserID    => $Self->{UserID},
            );

            # set additional data for article flag
            $TicketObject->ArticleFlagDataSet(
                ArticleID => $Self->{ArticleID},
                Key       => $ArticleFlagKey,
                Keywords  => $ArticleFlagKeywords,
                Subject   => $ArticleFlagSubject,
                Note      => $ArticleFlagNote,
                UserID    => $Self->{UserID},
            );
        }
    }

    # set article flag
    elsif ( $Self->{Subaction} eq 'ArticleFlagDelete' ) {

        # get article flag key
        my $ArticleFlagKey = $ParamObject->GetParam( Param => 'ArticleFlagKey' );

        # get a list of all available article flags from sysconfig
        my %ArticleFlagList = %{ $Self->{Config}->{ArticleFlags} };

        # create article flag icon string
        my $FlagIconString = ' ';

        if ( defined $ArticleFlagList{$ArticleFlagKey} && $ArticleFlagList{$ArticleFlagKey} ) {

            # delete article flag
            my $Success = $TicketObject->ArticleFlagDelete(
                ArticleID => $Self->{ArticleID},
                Key       => $ArticleFlagKey,
                UserID    => $Self->{UserID},
            );

            if ($Success) {

                # delete additional data for article flag
                $Success = $TicketObject->ArticleFlagDataDelete(
                    ArticleID => $Self->{ArticleID},
                    Key       => $ArticleFlagKey,
                    UserID    => $Self->{UserID},
                );
            }

            # if flag was not deleted, keep old flag icon
            if ( !$Success ) {
                $FlagIconString =
                    '<img src="' . $ConfigObject->Get('Frontend::ImagePath') . '">';
            }
        }

        # update flag icon content
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $FlagIconString,
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
        my %StandardTemplates = $Kernel::OM->Get('Kernel::System::Queue')->QueueStandardTemplateMemberList(
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
            TemplateFile => 'AgentTicketZoomTabArticle',
            Data         => { %Ticket, %Article, %AclAction },
        );
        if ( !$Content ) {
            $LayoutObject->FatalError(
                Message =>
                    $LayoutObject->{LanguageObject}
                    ->Translate( 'Can\'t get for ArticleID %s!', $Self->{ArticleID} ),
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
        my $TicketID                   = $ParamObject->GetParam( Param => 'TicketID' );
        my $SaveDefaults               = $ParamObject->GetParam( Param => 'SaveDefaults' );
        my @ArticleTypeFilterIDs       = $ParamObject->GetArray( Param => 'ArticleTypeFilter' );
        my @ArticleSenderTypeFilterIDs = $ParamObject->GetArray( Param => 'ArticleSenderTypeFilter' );

        # extended article filter
        my $ArticleSubjectFilter  = $ParamObject->GetParam( Param => 'ArticleSubjectFilter' );
        my $ArticleBodyFilter     = $ParamObject->GetParam( Param => 'ArticleBodyFilter' );
        my @ArticleFlagFilter     = $ParamObject->GetArray( Param => 'ArticleFlagFilter' );
        my $ArticleFlagTextFilter = $ParamObject->GetParam( Param => 'ArticleFlagTextFilter' );

        my %ArticleDynamicFieldFilter;

        # cycle trough the activated Dynamic Fields for this screen
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldActiveFilter} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # extract the dynamic field value from the web request
            $ArticleDynamicFieldFilter{ $DynamicFieldConfig->{Name} }
                = $DynamicFieldBackendObject->EditFieldValueGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ParamObject        => $ParamObject,
                    LayoutObject       => $LayoutObject,
                ) || '';
        }

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

        # extended article filter
        if ($ArticleSubjectFilter) {
            $SessionString .= 'ArticleSubjectFilter<';
            $SessionString .= join ',', $ArticleSubjectFilter;
            $SessionString .= '>';
        }
        if ($ArticleBodyFilter) {
            $SessionString .= 'ArticleBodyFilter<';
            $SessionString .= join ',', $ArticleBodyFilter;
            $SessionString .= '>';
        }
        if (@ArticleFlagFilter) {
            $SessionString .= 'ArticleFlagFilter<';
            $SessionString .= join ',', @ArticleFlagFilter;
            $SessionString .= '>';
        }
        if ($ArticleFlagTextFilter) {
            $SessionString .= 'ArticleFlagTextFilter<';
            $SessionString .= join ',', $ArticleFlagTextFilter;
            $SessionString .= '>';
        }
        for my $ArticleDynamicField ( keys %ArticleDynamicFieldFilter ) {
            $SessionString .= 'ArticleDynamicField_';
            $SessionString .= $ArticleDynamicField;
            $SessionString .= '_Filter<';
            $SessionString .= join ',', $ArticleDynamicFieldFilter{$ArticleDynamicField};
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
            Key       => 'ArticleFilter' . $Self->{TicketID},
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

    # article filter is activated in sysconfig
    if ( $Self->{ArticleFilterActive} ) {

        # get article filter settings from session string
        my $ArticleFilterSessionString = $Self->{ 'ArticleFilter' . $Self->{TicketID} };

        # set article filter for this ticket from user preferences
        if ( !$ArticleFilterSessionString ) {
            $ArticleFilterSessionString = $Self->{ArticleFilterDefault};
        }

        # do not use defaults for this ticket if filter was explicitly turned off
        elsif ( $ArticleFilterSessionString eq 'off' ) {
            $ArticleFilterSessionString = '';
        }

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldActiveFilter} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $ArticleFilterDynamicFieldName = 'ArticleDynamicField_'
                . $DynamicFieldConfig->{Name}
                . '_Filter';
            if (
                $ArticleFilterSessionString
                && $ArticleFilterSessionString
                =~ m{ $ArticleFilterDynamicFieldName < ( [^<>]+ ) > }xms
            ) {
                $Self->{ArticleFilter}->{$ArticleFilterDynamicFieldName} = $1;
            }
        }

        # extract ArticleTypeIDs
        if (
            $ArticleFilterSessionString
            && $ArticleFilterSessionString =~ m{ ArticleTypeFilter < ( [^<>]+ ) > }xms
        ) {
            my @IDs = split /,/, $1;
            $Self->{ArticleFilter}->{ArticleTypeID} = \@IDs;
        }

        # extract ArticleSenderTypeIDs
        if (
            $ArticleFilterSessionString
            && $ArticleFilterSessionString =~ m{ ArticleSenderTypeFilter < ( [^<>]+ ) > }xms
        ) {
            my @IDs = split /,/, $1;
            $Self->{ArticleFilter}->{ArticleSenderTypeID} = \@IDs;
        }

        # extract ArticleSubjet
        if (
            $ArticleFilterSessionString
            && $ArticleFilterSessionString =~ m{ ArticleSubjectFilter < ( [^<>]+ ) > }xms
            ) {
            $Self->{ArticleFilter}->{Subject} = $1;
        }

        # extract ArticleBody
        if (
            $ArticleFilterSessionString
            && $ArticleFilterSessionString =~ m{ ArticleBodyFilter < ( [^<>]+ ) > }xms
            ) {
            $Self->{ArticleFilter}->{Body} = $1;
        }

        # extract ArticleFlags and ArticleFlag text
        if (
            $ArticleFilterSessionString
            && $ArticleFilterSessionString =~ m{ ArticleFlagFilter < ( [^<>]+ ) > }xms
            ) {
            my @IDs = split /,/, $1;
            $Self->{ArticleFilter}->{ArticleFlag} = { map { $_ => 1 } @IDs };
        }

        # extract ArticleBody
        if (
            $ArticleFilterSessionString
            && $ArticleFilterSessionString =~ m{ ArticleFlagTextFilter < ( [^<>]+ ) > }xms
            ) {
            $Self->{ArticleFilter}->{ArticleFlagText} = $1;
        }
    }

    # return if HTML email
    if ( $Self->{Subaction} eq 'ShowHTMLeMail' ) {

        # check needed ArticleID
        if ( !$Self->{ArticleID} ) {
            return $LayoutObject->ErrorScreen( Message => Translatable('Need ArticleID!') );
        }

        # get article data
        my %Article = $TicketObject->ArticleGet(
            ArticleID     => $Self->{ArticleID},
            DynamicFields => 0,
        );

        # check if article data exists
        if ( !%Article ) {
            return $LayoutObject->ErrorScreen( Message => Translatable('Invalid ArticleID!') );
        }

        # if it is a html email, return here
        return $LayoutObject->Attachment(
            Filename => $ConfigObject->Get('Ticket::Hook')
                . "-$Article{TicketNumber}-$Article{TicketID}-$Article{ArticleID}",
            Type        => 'inline',
            ContentType => "$Article{MimeType}; charset=$Article{Charset}",
            Content     => $Article{Body},
        );
    }

    # generate output
    my $Output = $Self->MaskAgentZoom(
        Ticket    => \%Ticket,
        AclAction => \%AclAction
    );

    $Output .= $LayoutObject->Footer( Type => 'TicketZoomTab' );

    return $Output;
}

sub MaskAgentZoom {
    my ( $Self, %Param ) = @_;

    my %Ticket    = %{ $Param{Ticket} };
    my %AclAction = %{ $Param{AclAction} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

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

    # generate shown articles
    my $Limit = $ConfigObject->Get('Ticket::Frontend::MaxArticlesPerPage');

    my $Order = $Self->{ZoomExpandSort} eq 'reverse' ? 'DESC' : 'ASC';
    my $Page;

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get tab index
    my $TabIndex = $ParamObject->GetParam( Param => 'TabIndex' );

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
        DynamicFields              => 1,
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

    # add counter
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
                my %Preferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );

                # show first article
                if (
                    $Preferences{ShownArticle}
                    &&
                    (
                        (
                            $Preferences{ShownArticle} eq 'first'
                            && $Self->{ZoomExpandSort} ne 'reverse'
                        )
                        ||
                        (
                            $Preferences{ShownArticle} eq 'last'
                            && $Self->{ZoomExpandSort} eq 'reverse'
                        )
                    )
                ) {

                    # set first listed article as fallback
                    $ArticleID = $ArticleBox[0]->{ArticleID};
                }
                elsif (
                    $Preferences{ShownArticle}
                    &&
                    (
                        (
                            $Preferences{ShownArticle} eq 'last'
                            && $Self->{ZoomExpandSort} ne 'reverse'
                        )
                        ||
                        (
                            $Preferences{ShownArticle} eq 'first'
                            && $Self->{ZoomExpandSort} eq 'reverse'
                        )
                    )
                ) {

                    # set last article as default if reverse sort
                    $ArticleID = $ArticleBox[-1]->{ArticleID};
                }

                else {

                    # set last customer article as selected article replacing last set
                    ARTICLETMP:
                    for my $ArticleTmp (@ArticleBox) {
                        if ( $ArticleTmp->{SenderType} eq 'customer' ) {
                            $ArticleID = $ArticleTmp->{ArticleID};
                            last ARTICLETMP if $Self->{ZoomExpandSort} eq 'reverse';
                        }
                    }

                    # use fallback if no customer article found - show last article
                    if ( !defined $ArticleID ) {
                        if ( $Self->{ZoomExpandSort} ne 'reverse' ) {
                            $ArticleID = $ArticleBox[-1]->{ArticleID};
                        }
                        else {
                            $ArticleID = $ArticleBox[0]->{ArticleID};
                        }
                    }
                }
            }
        }
    }

    # remember shown article ids if article filter is activated in sysconfig
    if ( $Self->{ArticleFilterActive} && $Self->{ArticleFilter} ) {

        # reset shown article ids
        $Self->{ArticleFilter}->{ShownArticleIDs} = undef;

        my $NewArticleID = '';
        my $ShowCount    = 0;

        ARTICLE:
        for my $Article (@ArticleBox) {

            # cycle trough the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldActiveFilter} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                my $DynamicFieldName              = 'DynamicField_' . $DynamicFieldConfig->{Name};
                my $ArticleFilterDynamicFieldName = 'Article' . $DynamicFieldName . '_Filter';
                my $DynamicFieldFilter = $Self->{ArticleFilter}->{$ArticleFilterDynamicFieldName};

                if (
                    defined $Self->{ArticleFilter}->{$ArticleFilterDynamicFieldName}
                    && (
                        !defined $Article->{$DynamicFieldName}
                        || $Article->{$DynamicFieldName} !~ m/$DynamicFieldFilter/i
                    )
                ) {
                    next ARTICLE;
                }
            }

            # article type id does not match
            if (
                $Self->{ArticleFilter}->{ArticleTypeID}
                && !grep { $_ eq $Article->{ArticleTypeID} }
                @{ $Self->{ArticleFilter}->{ArticleTypeID} }
            ) {
                next ARTICLE;
            }

            # article sender type id does not match
            if (
                $Self->{ArticleFilter}->{ArticleSenderTypeID}
                && !grep { $_ eq $Article->{SenderTypeID} }
                @{ $Self->{ArticleFilter}->{ArticleSenderTypeID} }
            ) {
                next ARTICLE;
            }

            # article subject does not match
            my $ArticleFilterSubject = $Self->{ArticleFilter}->{Subject};
            if ($ArticleFilterSubject) {

                # remove leading and ending *
                $ArticleFilterSubject =~ s/^\*(.*)\*$/$1/;
                if ( $Article->{Subject} !~ m/$ArticleFilterSubject/i ) {
                    next ARTICLE;
                }
            }

            # article body does not match
            my $ArticleFilterBody = $Self->{ArticleFilter}->{Body};
            if ($ArticleFilterBody) {

                # remove leading and ending *
                $ArticleFilterBody =~ s/^\*(.*)\*$/$1/;
                if ( $Article->{Body} !~ m/$ArticleFilterBody/i ) {
                    next ARTICLE;
                }
            }

            # article flag does not match
            my $ArticleFilterFlag     = $Self->{ArticleFilter}->{ArticleFlag};
            my $ArticleFilterFlagText = $Self->{ArticleFilter}->{ArticleFlagText};
            if ($ArticleFilterFlagText) {

                # remove leading and ending *
                $ArticleFilterFlagText =~ s/^\*(.*)\*$/$1/;
            }

            if ( defined $ArticleFilterFlag && ref $ArticleFilterFlag eq 'HASH' ) {
                my $FoundFlag     = 0;
                my $FoundFlagText = 0;

                for my $Flag ( keys %{$ArticleFilterFlag} ) {

                    if ( $ArticleFlags{ $Article->{ArticleID} }->{$Flag} ) {
                        $FoundFlag = 1;
                    }

                    if ($ArticleFilterFlagText) {
                        my %ArticleFlagData = $TicketObject->ArticleFlagDataGet(
                            ArticleID      => $Article->{ArticleID},
                            ArticleFlagKey => $Flag,
                            UserID         => $Self->{UserID},
                        );

                        if (
                            (
                                defined $ArticleFlagData{Subject}
                                && $ArticleFlagData{Subject} =~ m/$ArticleFilterFlagText/
                            )
                            || (
                                defined $ArticleFlagData{Keywords}
                                && $ArticleFlagData{Keywords} =~ m/$ArticleFilterFlagText/
                            )
                            || (
                                defined $ArticleFlagData{Note}
                                && $ArticleFlagData{Note} =~ m/$ArticleFilterFlagText/
                            )
                        ) {
                            $FoundFlagText = 1;
                        }
                    }
                    else {
                        $FoundFlagText = 1;
                    }
                }
                next ARTICLE if !$FoundFlag || !$FoundFlagText;
            }

            # count shown articles
            $ShowCount++;

            # remember article id
            $Self->{ArticleFilter}->{ShownArticleIDs}->{ $Article->{ArticleID} } = 1;

            # set article id to first shown article
            if ( $ShowCount == 1 ) {
                $NewArticleID = $Article->{ArticleID};
            }

            # set article id to last shown customer article
            if ( $Article->{SenderType} eq 'customer' ) {
                $NewArticleID = $Article->{ArticleID};
            }
        }

        # change article id if it was filtered out
        if ( $NewArticleID && !$Self->{ArticleFilter}->{ShownArticleIDs}->{$NewArticleID} ) {
            $ArticleID = $NewArticleID;
        }

        # add current article id
        $Self->{ArticleFilter}->{ShownArticleIDs}->{$NewArticleID} = 1;
    }

    # check if expand view is usable (only for less then 400 article)
    # if you have more articles is going to be slow and not usable
    my $ArticleMaxLimit = $ConfigObject->Get('Ticket::Frontend::MaxArticlesZoomExpand') // 400;
    if ( $Self->{ZoomExpand} && $#ArticleBox > $ArticleMaxLimit ) {
        $Self->{ZoomExpand} = 0;
    }

    # get shown article(s)
    my @ArticleBoxShown;
    if ( !$Self->{ZoomExpand} ) {
        ARTICLEBOX:
        for my $ArticleTmp (@ArticleBox) {

            # if ( $ArticleID eq $ArticleTmp->{ArticleID} ) {
            if ( defined $ArticleID && $ArticleID eq $ArticleTmp->{ArticleID} ) {
                push @ArticleBoxShown, $ArticleTmp;
                last ARTICLEBOX;
            }
        }
    }
    else {
        if ( $Self->{ArticleFilterActive} && $Self->{ArticleFilter} ) {
            for my $ArticleItem (@ArticleBox) {
                next if !$Self->{ArticleFilter}->{ShownArticleIDs}->{ $ArticleItem->{ArticleID} };
                push @ArticleBoxShown, $ArticleItem;
            }
        }
        else {
            @ArticleBoxShown = @ArticleBox;
        }
    }

    # set display options
    $Param{WidgetTitle} = 'Ticket Information';
    $Param{Hook} = $ConfigObject->Get('Ticket::Hook') || 'Ticket#';

    # check if ticket is normal or process ticket
    my $IsProcessTicket = $TicketObject->TicketCheckForProcessType(
        'TicketID' => $Self->{TicketID}
    );

    # overwrite display options for process ticket
    if ($IsProcessTicket) {
        $Param{WidgetTitle} = $Self->{DisplaySettings}->{ProcessDisplay}->{WidgetTitle};
    }

    # only show article tree if articles are present,
    # or if a filter is set (so that the user has the option to
    # disable the filter)
    if ( @ArticleBox || $Self->{ArticleFilter} ) {

        my $Pagination;

        if ($NeedPagination) {
            $Pagination = {
                Pages       => $Pages,
                CurrentPage => $Page,
                TicketID    => $Ticket{TicketID},
            };
        }

        # show article tree
        $Param{ArticleTree} = $Self->_ArticleTree(
            Ticket            => \%Ticket,
            ArticleFlags      => \%ArticleFlags,
            ArticleID         => $ArticleID,
            ArticleMaxLimit   => $ArticleMaxLimit,
            ArticleBox        => \@ArticleBox,
            Pagination        => $Pagination,
            Page              => $Page,
            ArticleCount      => scalar @ArticleBoxAll,
            AclAction         => \%AclAction,
            StandardResponses => $StandardTemplates{Answer},
            StandardForwards  => $StandardTemplates{Forward},
            TabIndex          => $TabIndex,
        );
    }

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # show articles items
    $Param{ArticleItems} = '';
    ARTICLE:
    for my $ArticleTmp (@ArticleBoxShown) {
        my %Article = %$ArticleTmp;

        $Self->_ArticleItem(
            Ticket            => \%Ticket,
            Article           => \%Article,
            AclAction         => \%AclAction,
            StandardResponses => $StandardTemplates{Answer},
            StandardForwards  => $StandardTemplates{Forward},
            ActualArticleID   => $ArticleID,
            Type              => 'Static',
        );
    }
    $Param{ArticleItems} .= $LayoutObject->Output(
        TemplateFile => 'AgentTicketZoomTabArticle',
        Data         => { %Ticket, %AclAction },
    );

    # always show archived tickets as seen
    if ( $Self->{ZoomExpand} && $Ticket{ArchiveFlag} ne 'y' ) {
        $LayoutObject->Block(
            Name => 'TicketItemMarkAsSeen',
            Data => { TicketID => $Ticket{TicketID} },
        );
    }

    # age design
    $Ticket{Age} = $LayoutObject->CustomerAge(
        Age   => $Ticket{Age},
        Space => ' '
    );

    # number of articles
    $Param{ArticleCount} = $Count;

    $LayoutObject->Block(
        Name => 'Header',
        Data => { %Param, %Ticket, %AclAction },
    );

    # article filter is activated in sysconfig
    if ( $Self->{ArticleFilterActive} ) {

        # get article types
        my %ArticleTypes = $TicketObject->ArticleTypeList(
            Result => 'HASH',
        );

        my %ArticleFlagList = ();
        if (
            defined $Self->{Config}->{ArticleFlags}
            && ref $Self->{Config}->{ArticleFlags} eq 'HASH'
        ) {
            %ArticleFlagList = %{ $Self->{Config}->{ArticleFlags} };
        }

        # build article type list for filter dialog
        $Param{ArticleTypeFilterString} = $LayoutObject->BuildSelection(
            Data        => \%ArticleTypes,
            SelectedID  => $Self->{ArticleFilter}->{ArticleTypeID},
            Translation => 1,
            Multiple    => 1,
            Sort        => 'AlphanumericValue',
            Name        => 'ArticleTypeFilter',
            Class       => 'Modernize',
        );

        # get sender types
        my %ArticleSenderTypes = $TicketObject->ArticleSenderTypeList(
            Result => 'HASH',
        );

        # build article sender type list for filter dialog
        $Param{ArticleSenderTypeFilterString} = $LayoutObject->BuildSelection(
            Data        => \%ArticleSenderTypes,
            SelectedID  => $Self->{ArticleFilter}->{ArticleSenderTypeID},
            Translation => 1,
            Multiple    => 1,
            Sort        => 'AlphanumericValue',
            Name        => 'ArticleSenderTypeFilter',
            Class       => 'Modernize',
        );

        $Param{ArticleSubjectFilterString} = $Self->{ArticleFilter}->{Subject};
        $Param{ArticleBodyFilterString}    = $Self->{ArticleFilter}->{Body};

        # build article flag selection
        $Param{ArticleFlagFilterString} = $LayoutObject->BuildSelection(
            Data        => \%ArticleFlagList,
            SelectedID  => [ keys %{ $Self->{ArticleFilter}->{ArticleFlag} } ],
            Translation => 1,
            Multiple    => 1,
            Sort        => 'AlphanumericValue',
            Name        => 'ArticleFlagFilter',
        );
        $Param{ArticleFlagTextFilterString} = $Self->{ArticleFilter}->{ArticleFlagText};

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldActiveFilter} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            $LayoutObject->Block(
                Name => 'ArticleFilterDialogDynamicFieldReset',
                Data => {
                    Name => $DynamicFieldConfig->{Name},
                },
            );

            my $ArticleFilterDynamicFieldName = 'ArticleDynamicField_'
                . $DynamicFieldConfig->{Name}
                . '_Filter';

            if ( defined $Self->{ArticleFilter}->{$ArticleFilterDynamicFieldName} ) {
                $LayoutObject->Block(
                    Name => 'ArticleFilterDialogDynamicFieldActive',
                    Data => {
                        Name => $DynamicFieldConfig->{Name},
                    },
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'ArticleFilterDialogDynamicFieldInactive',
                    Data => {
                        Name => $DynamicFieldConfig->{Name},
                    },
                );
            }

            my $DynamicFieldBackendObject
                = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
            my $DynamicFieldHTML = $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value => defined $Self->{ArticleFilter}->{$ArticleFilterDynamicFieldName}
                ? "$Self->{ArticleFilter}->{$ArticleFilterDynamicFieldName}"
                : '',
                LayoutObject => $LayoutObject,
                ParamObject  => $ParamObject,
            );

            $LayoutObject->Block(
                Name => 'ArticleFilterDialogDynamicField',
                Data => {
                    Name  => $DynamicFieldConfig->{Name},
                    Label => $DynamicFieldConfig->{Label},
                    Field => $DynamicFieldHTML->{Field},
                },
            );
        }

        # Ticket ID
        $Param{TicketID} = $Self->{TicketID};

        $LayoutObject->Block(
            Name => 'ArticleFilterDialog',
            Data => {%Param},
        );
    }

    # create layout block
    $LayoutObject->Block(
        Name => 'ArticleFlagDialog',
        Data => {
            TicketID => $Self->{TicketID},
        },
    );

    # check if ticket need to be marked as seen
    my $ArticleAllSeen = 1;
    ARTICLE:
    for my $Article (@ArticleBox) {

        # ignore system sender type
        next ARTICLE
            if $ConfigObject->Get('Ticket::NewArticleIgnoreSystemSender')
            && $Article->{SenderType} eq 'system';

        # last ARTICLE if article was not shown
        if ( !$ArticleFlags{ $Article->{ArticleID} }->{Seen} ) {
            $ArticleAllSeen = 0;
            last ARTICLE;
        }
    }

    # mark ticket as seen if all article are shown
    if ($ArticleAllSeen) {
        $TicketObject->TicketFlagSet(
            TicketID => $Self->{TicketID},
            Key      => 'Seen',
            Value    => 1,
            UserID   => $Self->{UserID},
        );
    }

    # init js
    $LayoutObject->Block(
        Name => 'TicketZoomInit',
        Data => {
            %Param,
            TicketID       => $Self->{TicketID},
            ColumnResizing => $Self->{ColumnResizing}
        },
    );

    if (
        defined $Self->{Config}->{ArticleFlagsWithoutEdit}
        && ref $Self->{Config}->{ArticleFlagsWithoutEdit} eq 'HASH'
    ) {
        my %SkipList = %{ $Self->{Config}->{ArticleFlagsWithoutEdit} };
        for my $FlagKey ( keys( %SkipList ) ) {
            next if ( !$SkipList{ $FlagKey } );
            $LayoutObject->Block(
                Name => 'ArticleFlagsWithoutEdit',
                Data => {
                    FlagKey => $FlagKey
                },
            );
        }
    }

    # return output
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketZoomTabArticle',
        Data         => {
            %Param,
            %Ticket,
            %AclAction
        },
    );
}

sub _ArticleTree {
    my ( $Self, %Param ) = @_;

    my %Ticket          = %{ $Param{Ticket} };
    my %ArticleFlags    = %{ $Param{ArticleFlags} };
    my @ArticleBox      = @{ $Param{ArticleBox} };
    my $ArticleMaxLimit = $Param{ArticleMaxLimit};
    my $ArticleID       = $Param{ArticleID};

    # prepare table classes
    my $TableClasses;
    if ( $Self->{UseArticleColors} ) {
        $TableClasses = 'UseArticleColors';
    }

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # build thread string
    $LayoutObject->Block(
        Name => 'Tree',
        Data => {
            %Param,
        },
    );

    if ( $Param{Pagination} ) {
        $LayoutObject->Block(
            Name => 'ArticlePages',
            Data => $Param{Pagination},
        );
    }

    # check if expand/collapse view is usable (not available for too many
    # articles)
    if ( $Self->{ZoomExpand} && $#ArticleBox < $ArticleMaxLimit ) {
        $LayoutObject->Block(
            Name => 'Collapse',
            Data => {
                %Ticket,
                ArticleID      => $ArticleID,
                ZoomExpand     => $Self->{ZoomExpand},
                ZoomExpandSort => $Self->{ZoomExpandSort},
                Page           => $Param{Page},
                SelectedTab    => $Param{TabIndex},
            },
        );
    }

    elsif ( $#ArticleBox < $ArticleMaxLimit ) {
        $LayoutObject->Block(
            Name => 'Expand',
            Data => {
                %Ticket,
                ArticleID      => $ArticleID,
                ZoomExpand     => $Self->{ZoomExpand},
                ZoomExpandSort => $Self->{ZoomExpandSort},
                Page           => $Param{Page},
                SelectedTab    => $Param{TabIndex},
            },
        );
    }

    # article filter is activated in sysconfig
    if ( $Self->{ArticleFilterActive} ) {

        # define highlight style for links if filter is active
        my $HighlightStyle = 'menu';
        if ( $Self->{ArticleFilter} ) {
            $HighlightStyle = 'PriorityID-5';
        }

        # build article filter links
        $LayoutObject->Block(
            Name => 'ArticleFilterDialogLink',
            Data => {
                %Param,
                HighlightStyle => $HighlightStyle,
            },
        );

        # build article filter reset link only if filter is set
        if ( $Self->{ArticleFilter} ) {
            $LayoutObject->Block(
                Name => 'ArticleFilterResetLink',
                Data => {%Param},
            );
        }
    }

    # get needed objects
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # show article tree
    $LayoutObject->Block(
        Name => 'ArticleList',
        Data => {
            %Param,
            TableClasses => $TableClasses,
        },
    );

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldShow} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        $LayoutObject->Block(
            Name => 'TreeHeadDynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldConfig->{Label},
            },
        );
    }

    ARTICLE:
    for my $ArticleTmp (@ArticleBox) {
        my %Article = %$ArticleTmp;

        # article filter is activated in sysconfig and there are articles
        # that passed the filter
        if ( $Self->{ArticleFilterActive} ) {
            if ( $Self->{ArticleFilter} && $Self->{ArticleFilter}->{ShownArticleIDs} ) {

                # do not show article in tree if it does not match the filter
                if ( !$Self->{ArticleFilter}->{ShownArticleIDs}->{ $Article{ArticleID} } ) {
                    next ARTICLE;
                }
            }
        }

        # show article flags
        my $Class      = '';
        my $ClassRow   = '';
        my $NewArticle = 0;

        my %ArticleFlag = $TicketObject->ArticleFlagGet(
            ArticleID => $Article{ArticleID},
            UserID    => $Self->{UserID},
        );

        # ignore system sender types
        if (
            !$ArticleFlags{ $Article{ArticleID} }->{Seen}
            && (
                !$ConfigObject->Get('Ticket::NewArticleIgnoreSystemSender')
                || $ConfigObject->Get('Ticket::NewArticleIgnoreSystemSender')
                && $Article{SenderType} ne 'system'
            )
        ) {
            $NewArticle = 1;

            # show ticket flags
            # always show archived tickets as seen
            if ( $Ticket{ArchiveFlag} ne 'y' ) {
                $Class    .= ' UnreadArticles';
                $ClassRow .= ' UnreadArticles';
            }

            # just show ticket flags if agent belongs to the ticket
            my $ShowMeta;
            if (
                $Self->{UserID} == $Article{OwnerID}
                || $Self->{UserID} == $Article{ResponsibleID}
            ) {
                $ShowMeta = 1;
            }
            if ( !$ShowMeta && $ConfigObject->Get('Ticket::Watcher') ) {
                my %Watch = $TicketObject->TicketWatchGet(
                    TicketID => $Article{TicketID},
                );
                if ( $Watch{ $Self->{UserID} } ) {
                    $ShowMeta = 1;
                }
            }

            # show ticket flags
            if ($ShowMeta) {
                $Class .= ' Remarkable';
            }
            else {
                $Class .= ' Ordinary';
            }
        }

        # if this is the shown article -=> set class to active
        if ( defined $ArticleID && $ArticleID eq $Article{ArticleID} && !$Self->{ZoomExpand} ) {
            $ClassRow .= ' Active';
        }

        my $TmpSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => $Article{TicketNumber},
            Subject      => $Article{Subject} || '',
        );

        # set icon for ArticleType
        my $ArticleTypeIconConfig = $ConfigObject->Get('Ticket::ArticleTypeIcon');
        if ($ArticleTypeIconConfig) {
            $Article{ArticleTypeIcon} = $ArticleTypeIconConfig->{ $Article{ArticleType} };
        }

        # Determine communication direction
        my $ArticleDirectionIconConfig
            = $ConfigObject->Get('Ticket::ArticleDirectionIcon');
        if ($ArticleDirectionIconConfig) {

            # Determine communication direction
            if ( $Article{ArticleType} =~ /-(int|internal)$/smx ) {
                $Article{Direction}     = 'Internal message';
                $Article{DirectionIcon} = $ArticleDirectionIconConfig->{internal};
            }
            else {
                if ( $Article{SenderType} eq 'customer' ) {
                    $Article{Direction}     = 'Incoming message';
                    $Article{DirectionIcon} = $ArticleDirectionIconConfig->{incoming};
                }
                else {
                    $Article{Direction}     = 'Outgoing message';
                    $Article{DirectionIcon} = $ArticleDirectionIconConfig->{outgoing};
                }
            }
        }

        # complete icon sources
        foreach my $Icon (qw(SenderTypeIcon ArticleTypeIcon DirectionIcon)) {
            if ( $Article{$Icon} ) {
                $Article{$Icon} =
                    $ConfigObject->Get('Frontend::ImagePath') . '/'
                    . $Article{$Icon};
            }
        }

        $Article{SubjectLength} = 50;

        # use realname only or use realname and email address
        if ( $Self->{Config}->{ArticleListFrom} eq 'Value' ) {

            # save old $Article{FromRealname}
            $Article{FromRealnameTmp} = $Article{FromRealname};

            # set from to realname and email address
            $Article{FromRealname} = $Article{From};
        }

        # check if we need to show also expand/collapse icon
        $LayoutObject->Block(
            Name => 'TreeItem',
            Data => {
                %Article,
                Class          => $Class,
                ClassRow       => $ClassRow,
                Subject        => $TmpSubject,
                ZoomExpand     => $Self->{ZoomExpand},
                ZoomExpandSort => $Self->{ZoomExpandSort},
            },
        );

        # reset $Article{FromRealname}
        $Article{FromRealname} = $Article{FromRealnameTmp};

        # prepare lists
        my %SkipList  = ();
        my %ShareList = ();
        if (
            defined $Self->{Config}->{ArticleFlagsWithoutEdit}
            && ref $Self->{Config}->{ArticleFlagsWithoutEdit} eq 'HASH'
        ) {
            %SkipList = %{ $Self->{Config}->{ArticleFlagsWithoutEdit} };
        }
        if (
            defined $Self->{Config}->{ArticleFlagsShared}
            && ref $Self->{Config}->{ArticleFlagsShared} eq 'HASH'
        ) {
            %ShareList = %{ $Self->{Config}->{ArticleFlagsShared} };
        }

        # check if flag edit is allowed
        my $AllowFlagEdit = 0;
        if (
            !$Self->{Config}->{ArticleFlagsOnlyOwnerAndResponsible} ||
            (
                $Self->{Config}->{ArticleFlagsOnlyOwnerAndResponsible}
                && $Self->{UserID} == $Ticket{OwnerID}
                || (
                    $ConfigObject->Get('Ticket::Responsible')
                    && $Self->{UserID} == $Ticket{ResponsibleID}
                )
            )
        ) {
            $AllowFlagEdit = 1;
        }

        # show article flags
        for my $Flag ( sort( keys( %ArticleFlag ) ) ) {
            next if $Flag eq 'Seen';
            next if !defined $Self->{Config}->{ArticleFlags};
            next if !defined $Self->{Config}->{ArticleFlags}->{$Flag};

            # get article flag data (keywords, subject, note)
            my %ArticleFlagData = $TicketObject->ArticleFlagDataGet(
                ArticleID      => $Article{ArticleID},
                ArticleFlagKey => $Flag,
                UserID         => $Self->{UserID}
            );

            # get article flag class
            my $CSS = $Self->{Config}->{ArticleFlagCSS}->{$Flag} || '';

            # create article flag icon and hidden options dialog box
            $LayoutObject->Block(
                Name => 'TreeItemArticleFlagSet',
                Data => {
                    ArticleFlagIcon     => $Self->{Config}->{ArticleFlagIcons}->{$Flag},
                    ArticleFlagKey      => $Flag,
                    ArticleFlagValue    => $Self->{Config}->{ArticleFlags}->{$Flag},
                    TicketID            => $Self->{TicketID},
                    ArticleID           => $Article{ArticleID},
                    ArticleFlagSubject  => $ArticleFlagData{Subject},
                    ArticleFlagKeywords => $ArticleFlagData{Keywords},
                    ArticleFlagNote     => $ArticleFlagData{Note},
                    CSS                 => $CSS,
                    AllowFlagEdit       => $AllowFlagEdit,
                },
            );

            if (
                $AllowFlagEdit
                || (
                    $ShareList{ $Flag }
                    && !$SkipList{ $Flag }
                )
            ) {
                $LayoutObject->Block(
                    Name => 'TreeItemArticleFlagDialog',
                    Data => {
                        ArticleFlagIcon     => $Self->{Config}->{ArticleFlagIcons}->{$Flag},
                        ArticleFlagKey      => $Flag,
                        ArticleFlagValue    => $Self->{Config}->{ArticleFlags}->{$Flag},
                        TicketID            => $Self->{TicketID},
                        ArticleID           => $Article{ArticleID},
                        ArticleFlagSubject  => $ArticleFlagData{Subject},
                        ArticleFlagKeywords => $ArticleFlagData{Keywords},
                        ArticleFlagNote     => $ArticleFlagData{Note},
                        CSS                 => $CSS,
                        AllowFlagEdit       => $AllowFlagEdit,
                    },
                );

                if ($AllowFlagEdit) {
                    if ( !$SkipList{ $Flag } ) {
                        $LayoutObject->Block(
                            Name => 'TreeItemArticleFlagOptionEdit',
                            Data => {
                                ArticleFlagIcon     => $Self->{Config}->{ArticleFlagIcons}->{$Flag},
                                ArticleFlagKey      => $Flag,
                                ArticleFlagValue    => $Self->{Config}->{ArticleFlags}->{$Flag},
                                TicketID            => $Self->{TicketID},
                                ArticleID           => $Article{ArticleID},
                                ArticleFlagSubject  => $ArticleFlagData{Subject},
                                ArticleFlagKeywords => $ArticleFlagData{Keywords},
                                ArticleFlagNote     => $ArticleFlagData{Note},
                                CSS                 => $CSS,
                                AllowFlagEdit       => $AllowFlagEdit,
                            },
                        );
                    }
                    $LayoutObject->Block(
                        Name => 'TreeItemArticleFlagOptionDelete',
                        Data => {
                            ArticleFlagIcon     => $Self->{Config}->{ArticleFlagIcons}->{$Flag},
                            ArticleFlagKey      => $Flag,
                            ArticleFlagValue    => $Self->{Config}->{ArticleFlags}->{$Flag},
                            TicketID            => $Self->{TicketID},
                            ArticleID           => $Article{ArticleID},
                            ArticleFlagSubject  => $ArticleFlagData{Subject},
                            ArticleFlagKeywords => $ArticleFlagData{Keywords},
                            ArticleFlagNote     => $ArticleFlagData{Note},
                            CSS                 => $CSS,
                            AllowFlagEdit       => $AllowFlagEdit,
                        },
                    );
                }
                else {
                    $LayoutObject->Block(
                        Name => 'TreeItemArticleFlagOptionShow',
                        Data => {
                            ArticleFlagIcon     => $Self->{Config}->{ArticleFlagIcons}->{$Flag},
                            ArticleFlagKey      => $Flag,
                            ArticleFlagValue    => $Self->{Config}->{ArticleFlags}->{$Flag},
                            TicketID            => $Self->{TicketID},
                            ArticleID           => $Article{ArticleID},
                            ArticleFlagSubject  => $ArticleFlagData{Subject},
                            ArticleFlagKeywords => $ArticleFlagData{Keywords},
                            ArticleFlagNote     => $ArticleFlagData{Note},
                            CSS                 => $CSS,
                            AllowFlagEdit       => $AllowFlagEdit,
                        },
                    );
                }
            }
        }

        # always show archived tickets as seen
        if ( $NewArticle && $Ticket{ArchiveFlag} ne 'y' ) {
            $LayoutObject->Block(
                Name => 'TreeItemNewArticle',
                Data => {
                    %Article,
                    Class => $Class,
                },
            );
        }

        # Bugfix for IE7: a table cell should not be empty
        # (because otherwise the cell borders are not shown):
        # we add an empty element here
        else {
            $LayoutObject->Block(
                Name => 'TreeItemNoNewArticle',
                Data => {},
            );
        }

        # show dynamic field values
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicFieldShow} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $Value = $BackendObject->ValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Article{ArticleID},
            );

            # get print string for this dynamic field
            my $ValueStrg = $BackendObject->DisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Value,
                LayoutObject       => $LayoutObject,
            );

            $LayoutObject->Block(
                Name => 'TreeItemDynamicField',
                Data => {
                    Name  => $DynamicFieldConfig->{Name},
                    Title => $DynamicFieldConfig->{Label},
                    Value => $ValueStrg->{Value}
                },
            );
        }

        # show attachment info
        # Bugfix for IE7: a table cell should not be empty
        # (because otherwise the cell borders are not shown):
        # we add an empty element here
        if ( !$Article{Atms} || !%{ $Article{Atms} } ) {
            $LayoutObject->Block(
                Name => 'TreeItemNoAttachment',
                Data => {},
            );

            next ARTICLE;
        }
        else {

            my $Attachments = $Self->_CollectArticleAttachments(
                Article => \%Article,
            );

            $LayoutObject->Block(
                Name => 'TreeItemAttachment',
                Data => {
                    ArticleID   => $Article{ArticleID},
                    Attachments => $Attachments,
                },
            );
        }
    }

    # return output
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketZoomTabArticle',
        Data         => { %Param, %Ticket },
    );
}

sub _TicketItemSeen {
    my ( $Self, %Param ) = @_;

    my @ArticleIDs = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleIndex(
        TicketID => $Param{TicketID},
    );

    for my $ArticleID (@ArticleIDs) {
        $Self->_ArticleItemSeen(
            ArticleID => $ArticleID,
        );
    }

    return 1;
}

sub _ArticleItemSeen {
    my ( $Self, %Param ) = @_;

    # mark shown article as seen
    $Kernel::OM->Get('Kernel::System::Ticket')->ArticleFlagSet(
        ArticleID => $Param{ArticleID},
        Key       => 'Seen',
        Value     => 1,
        UserID    => $Self->{UserID},
    );

    return 1;
}

sub _ArticleItem {
    my ( $Self, %Param ) = @_;

    my %Ticket    = %{ $Param{Ticket} };
    my %Article   = %{ $Param{Article} };
    my %AclAction = %{ $Param{AclAction} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # cleanup subject
    $Article{Subject} = $TicketObject->TicketSubjectClean(
        TicketNumber => $Article{TicketNumber},
        Subject      => $Article{Subject} || '',
        Size         => 0,
    );

    # show article actions
    my @MenuItems = $Self->_ArticleMenu(
        %Param,
    );

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # collect article meta
    my @ArticleMetaData = $Self->_ArticleCollectMeta(
        Article => \%Article
    );

    $LayoutObject->Block(
        Name => 'ArticleItem',
        Data => {
            %Param, %Article, %AclAction,
            MenuItems       => \@MenuItems,
            ArticleMetaData => \@ArticleMetaData
        },
    );

    # show created by if different from User ID 1
    if ( $Article{CreatedBy} > 1 ) {
        $Article{CreatedByUser} = $Kernel::OM->Get('Kernel::System::User')->UserName( UserID => $Article{CreatedBy} );
        $LayoutObject->Block(
            Name => 'ArticleCreatedBy',
            Data => {%Article},
        );
        $LayoutObject->Block(
            Name => 'ArticleMailCreatedBy',
            Data => {%Article},
        );
    }

    # always show archived tickets as seen
    if ( $Ticket{ArchiveFlag} ne 'y' ) {

        # mark shown article as seen
        if ( $Param{Type} eq 'OnLoad' ) {
            $Self->_ArticleItemSeen( ArticleID => $Article{ArticleID} );
        }
        else {
            if (
                !$Self->{ZoomExpand}
                && defined $Param{ActualArticleID}
                && $Param{ActualArticleID} == $Article{ArticleID}
            ) {
                $LayoutObject->Block(
                    Name => 'ArticleItemMarkAsSeen',
                    Data => { %Param, %Article, %AclAction },
                );
            }
        }
    }

    # get cofig object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # do some strips && quoting
    my $RecipientDisplayType = $ConfigObject->Get('Ticket::Frontend::DefaultRecipientDisplayType') || 'Realname';
    my $SenderDisplayType    = $ConfigObject->Get('Ticket::Frontend::DefaultSenderDisplayType')    || 'Realname';
    KEY:
    for my $Key (qw(From To Cc Bcc)) {
        next KEY if !$Article{$Key};

        # use realname only or use realname and email address
        my $Realname = '';
        if ( $Self->{Config}->{ArticleDetailViewFrom} eq 'Realname' ) {
            $Realname = 'Realname'
        }

        my $DisplayType = $Key eq 'From'             ? $SenderDisplayType : $RecipientDisplayType;
        my $HiddenType  = $DisplayType eq 'Realname' ? 'Value'            : 'Realname';
        $LayoutObject->Block(
            Name => 'RowRecipient',
            Data => {
                Key                  => $Key,
                Value                => $Article{$Key},
                Realname             => $Article{ $Key . $Realname },
                ArticleID            => $Article{ArticleID},
                $HiddenType . Hidden => 'Hidden',
            },
        );
    }

    # show accounted article time
    if (
        $ConfigObject->Get('Ticket::ZoomTimeDisplay')
        && $ConfigObject->Get('Ticket::Frontend::AccountTime')
    ) {
        my $ArticleTime = $TicketObject->ArticleAccountedTimeGet(
            ArticleID => $Article{ArticleID}
        );
        if ($ArticleTime) {
            $LayoutObject->Block(
                Name => 'ArticleAccountedTime',
                Data => {
                    Key   => 'Time',
                    Value => $ArticleTime,
                },
            );
        }
    }

    # get dynamic field config for frontend module
    my $DynamicFieldFilter = {
        %{ $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")->{DynamicField} || {} },
        %{
            $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")
                ->{ProcessWidgetDynamicField}
                || {}
        },
    };

    # get the dynamic fields for article object
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Article'],
        FieldFilter => $DynamicFieldFilter || {},
    );
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $Value = $DynamicFieldBackendObject->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Article{ArticleID},
        );

        next DYNAMICFIELD if !$Value;
        next DYNAMICFIELD if $Value eq '';

        # get print string for this dynamic field
        my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
            ValueMaxChars      => $ConfigObject->
                Get('Ticket::Frontend::DynamicFieldsZoomMaxSizeArticle')
                || 160,    # limit for article display
            LayoutObject => $LayoutObject,
        );

        my $Label = $DynamicFieldConfig->{Label};

        $LayoutObject->Block(
            Name => 'ArticleDynamicField',
            Data => {
                Label => $Label,
            },
        );

        if ( $ValueStrg->{Link} ) {

            # output link element
            $LayoutObject->Block(
                Name => 'ArticleDynamicFieldLink',
                Data => {
                    %Ticket,

                    # alias for ticket title, Title will be overwritten
                    TicketTitle                 => $Ticket{Title},
                    Value                       => $ValueStrg->{Value},
                    Title                       => $ValueStrg->{Title},
                    Link                        => $ValueStrg->{Link},
                    LinkPreview                 => $ValueStrg->{LinkPreview},
                    $DynamicFieldConfig->{Name} => $ValueStrg->{Title}
                },
            );
        }
        else {

            # output non link element
            $LayoutObject->Block(
                Name => 'ArticleDynamicFieldPlain',
                Data => {
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );
        }

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'ArticleDynamicField' . $DynamicFieldConfig->{Name},
            Data => {
                Label => $Label,
                Value => $ValueStrg->{Value},
                Title => $ValueStrg->{Title},
            },
        );

        if ( $ValueStrg->{Link} ) {

            # output link element
            $LayoutObject->Block(
                Name => 'ArticleDynamicField' . $DynamicFieldConfig->{Name} . 'Link',
                Data => {
                    %Ticket,

                    # alias for ticket title, Title will be overwritten
                    TicketTitle                 => $Ticket{Title},
                    Value                       => $ValueStrg->{Value},
                    Title                       => $ValueStrg->{Title},
                    Link                        => $ValueStrg->{Link},
                    LinkPreview                 => $ValueStrg->{LinkPreview},
                    $DynamicFieldConfig->{Name} => $ValueStrg->{Title}
                },
            );
        }
        else {

            # output non link element
            $LayoutObject->Block(
                Name => 'ArticleDynamicField' . $DynamicFieldConfig->{Name} . 'Plain',
                Data => {
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );
        }
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    # run article view modules
    my $Config = $ConfigObject->Get('Ticket::Frontend::ArticleViewModule');
    if ( ref $Config eq 'HASH' ) {
        my %Jobs = %{$Config};
        for my $Job ( sort keys %Jobs ) {

            # load module
            if ( !$MainObject->Require( $Jobs{$Job}->{Module} ) ) {
                return $LayoutObject->ErrorScreen();
            }
            my $Object = $Jobs{$Job}->{Module}->new(
                %{$Self},
                TicketID  => $Self->{TicketID},
                ArticleID => $Article{ArticleID},
            );

            # run module
            my @Data = $Object->Check(
                Article => \%Article,
                %Ticket, Config => $Jobs{$Job}
            );
            for my $DataRef (@Data) {
                if ( !$DataRef->{Successful} ) {
                    $DataRef->{Result} = 'Error';
                }
                else {
                    $DataRef->{Result} = 'Notice';
                }

                $LayoutObject->Block(
                    Name => 'ArticleOption',
                    Data => $DataRef,
                );

                for my $Warning ( @{ $DataRef->{Warnings} } ) {
                    $LayoutObject->Block(
                        Name => 'ArticleOption',
                        Data => $Warning,
                    );
                }
            }

            # filter option
            $Object->Filter(
                Article => \%Article,
                %Ticket,
                Config  => $Jobs{$Job}
            );
        }
    }

    %Article = $TicketObject->ArticleGet(
        ArticleID     => $Article{ArticleID},
        DynamicFields => 0,
    );

    # get attachment index (without attachments)
    my %AtmIndex = $TicketObject->ArticleAttachmentIndex(
        ArticleID                  => $Article{ArticleID},
        StripPlainBodyAsAttachment => $Self->{StripPlainBodyAsAttachment},
        Article                    => \%Article,
        UserID                     => $Self->{UserID},
    );
    $Article{Atms} = \%AtmIndex;

    # add block for attachments
    if ( $Article{Atms} && %{ $Article{Atms} } ) {
        $LayoutObject->Block(
            Name => 'ArticleAttachment',
            Data => {},
        );

        my $AtmConfig = $ConfigObject->Get('Ticket::Frontend::ArticleAttachmentModule');
        ATTACHMENT:
        for my $FileID ( sort keys %AtmIndex ) {
            my %File = %{ $AtmIndex{$FileID} };
            $LayoutObject->Block(
                Name => 'ArticleAttachmentRow',
                Data => \%File,
            );

            # run article attachment modules
            next ATTACHMENT if ref $AtmConfig ne 'HASH';
            my %Jobs = %{$AtmConfig};
            JOB:
            for my $Job ( sort keys %Jobs ) {

                # load module
                if ( !$MainObject->Require( $Jobs{$Job}->{Module} ) ) {
                    return $LayoutObject->ErrorScreen();
                }
                my $Object = $Jobs{$Job}->{Module}->new(
                    %{$Self},
                    TicketID  => $Self->{TicketID},
                    ArticleID => $Article{ArticleID},
                );

                # run module
                my %Data = $Object->Run(
                    File => {
                        %File,
                        FileID => $FileID,
                    },
                    Article => \%Article,
                );

                # check for the display of the filesize
                if ( $Job eq '2-HTML-Viewer' ) {
                    $Data{DataFileSize} = ", " . $File{Filesize};
                }
                $LayoutObject->Block(
                    Name => $Data{Block} || 'ArticleAttachmentRowLink',
                    Data => {%Data},
                );
            }
        }
    }

    # get all article flags for this article
    my %ArticleFlag = $TicketObject->ArticleFlagGet(
        ArticleID => $Article{ArticleID},
        UserID    => $Self->{UserID},
    );

    my $Count = 0;
    for my $Flag ( sort( keys( %ArticleFlag ) ) ) {

        my $Key = '';
        if ( !$Count ) {
            $Key = 'MarkedAs';
        }

        next if !$Self->{Config}->{ArticleFlagIcons}->{$Flag};

        my %ArticleFlagData = $TicketObject->ArticleFlagDataGet(
            ArticleID      => $Article{ArticleID},
            ArticleFlagKey => $Flag,
            UserID         => $Self->{UserID},
        );

        $LayoutObject->Block(
            Name => 'ArticleFlagOption',
            Data => {
                %ArticleFlagData,
                Value           => $Self->{Config}->{ArticleFlags}->{$Flag},
                CSS             => $Self->{Config}->{ArticleFlagCSS}->{$Flag},
                ArticleFlagIcon => $Self->{Config}->{ArticleFlagIcons}->{$Flag}
            },
        );

        $Count++;
    }

    # show body as html or plain text
    my $ViewMode = 'BodyHTML';

    # in case show plain article body (if no html body as attachment exists of if rich
    # text is not enabled)
    if ( !$Self->{RichText} || !$Article{AttachmentIDOfHTMLBody} ) {
        $ViewMode = 'BodyPlain';

        # remember plain body for further processing by ArticleViewModules
        $Article{BodyPlain} = $Article{Body};

        # html quoting
        $Article{Body} = $LayoutObject->Ascii2Html(
            NewLine        => $ConfigObject->Get('DefaultViewNewLine'),
            Text           => $Article{Body},
            VMax           => $ConfigObject->Get('DefaultViewLines') || 5000,
            HTMLResultMode => 1,
            LinkFeature    => 1,
        );
    }

    # check if the browser sends the session id cookie
    # if not, add the session id to the url
    my $Session = '';
    if ( $LayoutObject->{SessionID} && !$LayoutObject->{SessionIDCookie} ) {
        $Session = ';' . $LayoutObject->{SessionName} . '=' . $LayoutObject->{SessionID};
    }

    # show body
    # Create a reference to an anonymous copy of %Article and pass it to
    # the LayoutObject, because %Article may be modified afterwards.
    $LayoutObject->Block(
        Name => $ViewMode,
        Data => {
            %Article,
            Session => $Session,
        },
    );

    # show message about links in iframes, if user didn't close it already
    if ( $ViewMode eq 'BodyHTML' && !$Self->{DoNotShowBrowserLinkMessage} ) {
        $LayoutObject->Block(
            Name => 'BrowserLinkMessage',
        );
    }

    # restore plain body for further processing by ArticleViewModules
    if ( !$Self->{RichText} || !$Article{AttachmentIDOfHTMLBody} ) {
        $Article{Body} = $Article{BodyPlain};
    }

    return 1;
}

sub _ArticleMenu {
    my ( $Self, %Param ) = @_;

    my %Ticket    = %{ $Param{Ticket} };
    my %Article   = %{ $Param{Article} };
    my %AclAction = %{ $Param{AclAction} };

    my @MenuItems;

    my %AclActionLookup = reverse %AclAction;
    my $IsModernize     = $Self->{Config}->{ArticleMenuModernize} // 1;

    # get needed objects
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # Owner and Responsible can mark articles as important or remove mark
    if (
        !$Self->{Config}->{ArticleFlagsOnlyOwnerAndResponsible} ||
        (
            $Self->{Config}->{ArticleFlagsOnlyOwnerAndResponsible}
            && $Self->{UserID} == $Ticket{OwnerID}
            || (
                $ConfigObject->Get('Ticket::Responsible')
                && $Self->{UserID} == $Ticket{ResponsibleID}
            )
        )
    ) {

        # Always use user id 1 because other users also have to see the important flag
        my %ArticleFlags = $TicketObject->ArticleFlagGet(
            ArticleID => $Article{ArticleID},
            UserID    => 1,
        );

        # get article flag selection string for this article
        my $ArticleFlagStrg
            = $Self->_ArticleFlagSelectionString( ArticleID => $Article{ArticleID} );

        my $Description = 'MarkAs';

        # set important menu item
        push @MenuItems, {
            ItemType        => 'Dropdown',
            DropdownType    => 'MarkAs',
            Description     => $Description,
            Name            => $Description,
            ArticleFlagStrg => $ArticleFlagStrg,
        };
    }

    # select the output template
    # check if compose link should be shown
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketCompose}
        && ( $AclActionLookup{AgentTicketCompose} )
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketCompose}
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketCompose} =~
        /(^|.*,)$Article{ArticleType}(,.*|$)/
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get('Ticket::Frontend::AgentTicketCompose');
        if ( $Config->{Permission} ) {
            my $Ok = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Ticket{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$Ok ) {
                $Access = 0;
            }
        }
        if ( $Config->{RequiredLock} ) {
            my $Locked = $TicketObject->TicketLockGet(
                TicketID => $Ticket{TicketID}
            );
            if ($Locked) {
                my $AccessOk = $TicketObject->OwnerCheck(
                    TicketID => $Ticket{TicketID},
                    OwnerID  => $Self->{UserID},
                );
                if ( !$AccessOk ) {
                    $Access = 0;
                }
            }
        }

        if ($Access) {

            # get StandardResponsesStrg
            my %StandardResponseHash = %{ $Param{StandardResponses} || {} };

            # get revers StandardResponseHash because we need to sort by Values
            # from %ReverseStandardResponseHash we get value of Key by %StandardResponseHash Value
            # and @StandardResponseArray is created as array of hashes with elements Key and Value

            my %ReverseStandardResponseHash = reverse %StandardResponseHash;
            my @StandardResponseArray       = map {
                {
                    Key   => $ReverseStandardResponseHash{$_},
                    Value => $_
                }
            } sort values %StandardResponseHash;

            # use this array twice (also for Reply All), so copy it first
            my @StandardResponseArrayReplyAll = @StandardResponseArray;

            unshift(
                @StandardResponseArray,
                {
                    Key   => '0',
                    Value => '- '
                        . $LayoutObject->{LanguageObject}->Translate('Reply') . ' -',
                    Selected => 1,
                }
            );

            # build html string
            my $StandardResponsesStrg = $LayoutObject->BuildSelection(
                Name  => 'ResponseID',
                ID    => 'ResponseID',
                Class => 'Small' . ($IsModernize ? ' Modernize' : ''),
                Data  => \@StandardResponseArray,
            );

            push @MenuItems, {
                ItemType              => 'Dropdown',
                DropdownType          => 'Reply',
                StandardResponsesStrg => $StandardResponsesStrg,
                Name                  => Translatable('Reply'),
                Class                 => 'TabAsPopup PopupType_TicketAction',
                Action                => 'AgentTicketCompose',
                FormID                => 'Reply' . $Article{ArticleID},
                ResponseElementID     => 'ResponseID',
                Type                  => $Param{Type},
            };

            # check if reply all is needed
            my $Recipients = '';
            KEY:
            for my $Key (qw(From To Cc Bcc)) {
                next KEY if !$Article{$Key};
                if ($Recipients) {
                    $Recipients .= ', ';
                }
                $Recipients .= $Article{$Key};
            }
            my $RecipientCount = 0;
            if ($Recipients) {
                my $EmailParser = Kernel::System::EmailParser->new(
                    %{$Self},
                    Mode => 'Standalone',
                );
                my @Addresses = $EmailParser->SplitAddressLine( Line => $Recipients );
                my %SystemAddress = $Kernel::OM->Get('Kernel::System::Queue')->GetSystemAddress(
                    QueueID => $Ticket{QueueID},
                );
                ADDRESS:
                for my $Address (@Addresses) {
                    my $Email = $EmailParser->GetEmailAddress( Email => $Address );
                    next ADDRESS if !$Email;
                    next ADDRESS if ( lc($Email) eq lc( $SystemAddress{Email} ) );
                    if ( $ConfigObject->Get('CheckEmailInternalAddress') ) {
                        my $IsLocal = $Kernel::OM->Get('Kernel::System::SystemAddress')
                            ->SystemAddressIsLocalAddress(
                            Address => $Email,
                            );
                        next ADDRESS if $IsLocal;
                    }
                    $RecipientCount++;
                }
            }
            if ( $RecipientCount > 1 ) {
                unshift(
                    @StandardResponseArrayReplyAll,
                    {
                        Key   => '0',
                        Value => '- '
                            . $LayoutObject->{LanguageObject}->Translate('Reply All') . ' -',
                        Selected => 1,
                    }
                );

                $StandardResponsesStrg = $LayoutObject->BuildSelection(
                    Name  => 'ResponseID',
                    ID    => 'ResponseIDAll' . $Article{ArticleID},
                    Class => 'Small' . ($IsModernize ? ' Modernize' : ''),
                    Data  => \@StandardResponseArrayReplyAll,
                );

                push @MenuItems, {
                    ItemType              => 'Dropdown',
                    DropdownType          => 'Reply',
                    StandardResponsesStrg => $StandardResponsesStrg,
                    Name                  => Translatable('Reply All'),
                    Class                 => 'TabAsPopup PopupType_TicketAction',
                    Action                => 'AgentTicketCompose',
                    FormID                => 'ReplyAll' . $Article{ArticleID},
                    ReplyAll              => 1,
                    ResponseElementID     => 'ResponseIDAll' . $Article{ArticleID},
                    Type                  => $Param{Type},
                };
            }
        }
    }

    # check if forward link should be shown
    # (only show forward on email-external, email-internal, phone, webrequest and fax
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketForward}
        && $AclActionLookup{AgentTicketForward}
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketForward}
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketForward} =~
        /(^|.*,)$Article{ArticleType}(,.*|$)/
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get('Ticket::Frontend::AgentTicketForward');
        if ( $Config->{Permission} ) {
            my $OK = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Ticket{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$OK ) {
                $Access = 0;
            }
        }
        if ( $Config->{RequiredLock} ) {
            if ( $TicketObject->TicketLockGet( TicketID => $Ticket{TicketID} ) ) {
                my $AccessOk = $TicketObject->OwnerCheck(
                    TicketID => $Ticket{TicketID},
                    OwnerID  => $Self->{UserID},
                );
                if ( !$AccessOk ) {
                    $Access = 0;
                }
            }
        }
        if ($Access) {
            if ( IsHashRefWithData( $Param{StandardForwards} ) ) {

                # get StandardForwardsStrg
                my %StandardForwardHash = %{ $Param{StandardForwards} };

                # get revers @StandardForwardHash because we need to sort by Values
                # from %ReverseStandarForward we get value of Key by %StandardForwardHash Value
                # and @StandardForwardArray is created as array of hashes with elements Key and Value
                my %ReverseStandarForward = reverse %StandardForwardHash;
                my @StandardForwardArray  = map {
                    {
                        Key   => $ReverseStandarForward{$_},
                        Value => $_
                    }
                } sort values %StandardForwardHash;

                unshift(
                    @StandardForwardArray,
                    {
                        Key   => '0',
                        Value => '- '
                            . $LayoutObject->{LanguageObject}->Translate('Forward')
                            . ' -',
                        Selected => 1,
                    }
                );

                # build html string
                my $StandardForwardsStrg = $LayoutObject->BuildSelection(
                    Name  => 'ForwardTemplateID',
                    ID    => 'ForwardTemplateID',
                    Class => 'Small' . ($IsModernize ? ' Modernize' : ''),
                    Data  => \@StandardForwardArray,
                );

                push @MenuItems, {
                    ItemType             => 'Dropdown',
                    DropdownType         => 'Forward',
                    StandardForwardsStrg => $StandardForwardsStrg,
                    Name                 => Translatable('Forward'),
                    Class                => 'TabAsPopup PopupType_TicketAction',
                    Action               => 'AgentTicketForward',
                    FormID               => 'Forward' . $Article{ArticleID},
                    ForwardElementID     => 'ForwardTemplateID',
                    Type                 => $Param{Type},
                };

            }
            else {

                push @MenuItems, {
                    ItemType    => 'Link',
                    Description => Translatable('Forward article via mail'),
                    Name        => Translatable('Forward'),
                    Class       => 'TabAsPopup PopupType_TicketAction',
                    Link        => "Action=AgentTicketForward;TicketID=$Ticket{TicketID};ArticleID=$Article{ArticleID}"
                };
            }
        }
    }

    # check if bounce link should be shown
    # (only show forward on email-external and email-internal
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketBounce}
        && $AclActionLookup{AgentTicketBounce}
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketBounce}
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketBounce} =~
        /(^|.*,)$Article{ArticleType}(,.*|$)/
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get('Ticket::Frontend::AgentTicketBounce');
        if ( $Config->{Permission} ) {
            my $OK = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Ticket{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$OK ) {
                $Access = 0;
            }
        }
        if ( $Config->{RequiredLock} ) {
            if ( $TicketObject->TicketLockGet( TicketID => $Ticket{TicketID} ) ) {
                my $AccessOk = $TicketObject->OwnerCheck(
                    TicketID => $Ticket{TicketID},
                    OwnerID  => $Self->{UserID},
                );
                if ( !$AccessOk ) {
                    $Access = 0;
                }
            }
        }
        if ($Access) {

            push @MenuItems, {
                ItemType    => 'Link',
                Description => 'Bounce Article to a different mail address',
                Name        => Translatable('Bounce'),
                Class       => 'TabAsPopup PopupType_TicketAction',
                Link        => "Action=AgentTicketBounce;TicketID=$Ticket{TicketID};ArticleID=$Article{ArticleID}"
            };
        }
    }

    # check if split link should be shown
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketPhone}
        && $AclActionLookup{AgentTicketPhone}
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketPhoneSplit}
        && $Self->{Config}->{ArticleEmailActions}->{AgentTicketPhoneSplit} =~
        /(^|.*,)$Article{ArticleType}(,.*|$)/
    ) {

        push @MenuItems, {
            ItemType    => 'Link',
            Description => Translatable('Split this article'),
            Name        => Translatable('Split'),
            Link        => "Action=AgentTicketPhone;TicketID=$Ticket{TicketID};ArticleID=$Article{ArticleID};LinkTicketID=$Ticket{TicketID}"
        };
    }

    # check if print link should be shown
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketPrint}
        && $AclActionLookup{AgentTicketPrint}
    ) {
        my $OK = $TicketObject->TicketPermission(
            Type     => 'ro',
            TicketID => $Ticket{TicketID},
            UserID   => $Self->{UserID},
            LogNo    => 1,
        );
        if ($OK) {

            push @MenuItems, {
                ItemType    => 'Link',
                Description => Translatable('Print this article'),
                Name        => Translatable('Print'),
                Class       => 'TabAsPopup PopupType_TicketAction',
                Link        => "Action=AgentTicketPrint;TicketID=$Ticket{TicketID};ArticleID=$Article{ArticleID};ArticleNumber=$Article{Count}"
            };
        }
    }

    # check if edit link should be shown
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentArticleEdit}
        && $AclActionLookup{AgentArticleEdit}
        && $Self->{Config}->{ArticleEmailActions}->{AgentArticleEdit}
        && $Self->{Config}->{ArticleEmailActions}->{AgentArticleEdit} =~
        /(^|.*,)$Article{ArticleType}(,.*|$)/
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get('Ticket::Frontend::AgentArticleEdit');
        if ( $Config->{Permission} ) {
            my $OK = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Ticket{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$OK ) {
                $Access = 0;
            }
        }
        if ( $Config->{RequiredLock} ) {
            if ( $TicketObject->TicketLockGet( TicketID => $Ticket{TicketID} ) ) {
                my $AccessOk = $TicketObject->OwnerCheck(
                    TicketID => $Ticket{TicketID},
                    OwnerID  => $Self->{UserID},
                );
                if ( !$AccessOk ) {
                    $Access = 0;
                }
            }
        }
        if (
            $Config->{OnlyResponsible}
            && $Self->{UserID} != $Ticket{ResponsibleID}
        ) {
            $Access = 0;
        }

        if ($Access) {
            push @MenuItems, {
                ItemType    => 'Link',
                Description => 'Edit article',
                Name        => Translatable('Edit article'),
                Class       => 'TabAsPopup PopupType_TicketAction',
                Link        => "Action=AgentArticleEdit;TicketID=$Ticket{TicketID};ArticleID=$Article{ArticleID};Count=$Article{Count}",
            };
        }
    }

    # check and download article attachments
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketAttachmentDownload}
        && $AclActionLookup{AgentTicketAttachmentDownload}
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get('Ticket::Frontend::AgentTicketAttachmentDownload');
        if ( $Config->{Permission} ) {
            my $OK = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Ticket{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$OK ) {
                $Access = 0;
            }
        }
        if ( $Config->{RequiredLock} ) {
            if ( $TicketObject->TicketLockGet( TicketID => $Ticket{TicketID} ) ) {
                my $AccessOk = $TicketObject->OwnerCheck(
                    TicketID => $Ticket{TicketID},
                    OwnerID  => $Self->{UserID},
                );
                if ( !$AccessOk ) {
                    $Access = 0;
                }
            }
        }

        my %ArticleAttachments = $TicketObject->ArticleAttachmentIndex(
            ArticleID                  => $Article{ArticleID},
            UserID                     => 1,
            Article                    => \%Article,
            StripPlainBodyAsAttachment => 1,
        );

        if ( $Access && %ArticleAttachments ) {
            push @MenuItems, {
                ItemType    => 'Link',
                Description => 'Download all Attachements for this article',
                Name        => Translatable('Attachments Download'),
                Class       => 'TabAsPopup PopupType_TicketAction',
                Link        => "Action=AgentTicketAttachmentDownload;TicketID=$Ticket{TicketID};ArticleID=$Article{ArticleID}",
            };
        }
    }

    # check if plain link should be shown
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketPlain}
        && $ConfigObject->Get('Ticket::Frontend::PlainView')
        && $AclActionLookup{AgentTicketPlain}
        && $Article{ArticleType} =~ /email/i
    ) {
        my $OK = $TicketObject->TicketPermission(
            Type     => 'ro',
            TicketID => $Ticket{TicketID},
            UserID   => $Self->{UserID},
            LogNo    => 1,
        );
        if ($OK) {

            push @MenuItems, {
                ItemType    => 'Link',
                Description => Translatable('View the source for this Article'),
                Name        => Translatable('Plain Format'),
                Class       => 'TabAsPopup PopupType_TicketAction',
                Link        => "Action=AgentTicketPlain;TicketID=$Ticket{TicketID};ArticleID=$Article{ArticleID}",
            };
        }
    }

    # check if internal reply link should be shown
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketNote}
        && $AclActionLookup{AgentTicketNote}
        && $Article{ArticleType} =~ /^note-(internal|external)$/i
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get('Ticket::Frontend::AgentTicketNote');
        if ( $Config->{Permission} ) {
            my $OK = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Ticket{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$OK ) {
                $Access = 0;
            }
        }

        if ( $Config->{RequiredLock} ) {
            if ( $TicketObject->TicketLockGet( TicketID => $Ticket{TicketID} ) ) {
                my $AccessOk = $TicketObject->OwnerCheck(
                    TicketID => $Ticket{TicketID},
                    OwnerID  => $Self->{UserID},
                );
                if ( !$AccessOk ) {
                    $Access = 0;
                }
            }
        }

        if ( $Access ) {
            my $Link
                = "Action=AgentTicketNote;TicketID=$Ticket{TicketID};ReplyToArticle=$Article{ArticleID}";
            my $Description = Translatable('Reply to note');

            # set important menu item
            push @MenuItems, {
                ItemType    => 'Link',
                Description => $Description,
                Name        => $Description,
                Class       => 'TabAsPopup PopupType_TicketAction',
                Link        => $Link,
            };
        }
    }

    return @MenuItems;
}

sub _ArticleCollectMeta {
    my ( $Self, %Param ) = @_;

    my %Article = %{ $Param{Article} };

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check whether auto article links should be used
    return if !$ConfigObject->Get('Ticket::Frontend::ZoomCollectMeta');
    return if !$ConfigObject->Get('Ticket::Frontend::ZoomCollectMetaFilters');

    my @Data;

    # find words to replace
    my %Config = %{ $ConfigObject->Get('Ticket::Frontend::ZoomCollectMetaFilters') };

    FILTER:
    for my $Filter ( values %Config ) {

        my %FilterData;

        # check for needed data
        next FILTER if !$Filter->{RegExp};
        next FILTER if !$Filter->{Meta};
        next FILTER if !$Filter->{Meta}->{Name};
        next FILTER if !$Filter->{Meta}->{URL};

        # iterage through regular expressions and create a hash with found matches
        my @Matches;
        for my $RegExp ( @{ $Filter->{RegExp} } ) {

            my @Count    = $RegExp =~ m{\(}gx;
            my $Elements = scalar @Count;

            if ( my @MatchData = $Article{Body} =~ m{([\s:]$RegExp)}gxi ) {
                my $Counter = 0;

                MATCH:
                while ( $MatchData[$Counter] ) {

                    my $WholeMatchString = $MatchData[$Counter];
                    $WholeMatchString =~ s/^\s+|\s+$//g;
                    if ( grep { $_->{Name} eq $WholeMatchString } @Matches ) {
                        $Counter += $Elements + 1;
                        next MATCH;
                    }

                    my %Parts;
                    for ( 1 .. $Elements ) {
                        $Parts{$_} = $MatchData[ $Counter + $_ ];
                    }
                    $Counter += $Elements + 1;

                    push @Matches, {
                        Name  => $WholeMatchString,
                        Parts => \%Parts,
                    };
                }
            }
        }

        if ( scalar @Matches ) {

            $FilterData{Name} = $Filter->{Meta}->{Name};

            # iterate trough matches and build URLs from configuration
            for my $Match (@Matches) {

                my $MatchQuote = $LayoutObject->Ascii2Html( Text => $Match->{Name} );
                my $URL        = $Filter->{Meta}->{URL};
                my $URLPreview = $Filter->{Meta}->{URLPreview};

                # replace the whole keyword
                my $MatchLinkEncode = $LayoutObject->LinkEncode( $Match->{Name} );
                $URL =~ s/<MATCH>/$MatchLinkEncode/g;
                $URLPreview =~ s/<MATCH>/$MatchLinkEncode/g;

                # replace the keyword components
                for my $Part ( sort keys %{ $Match->{Parts} || {} } ) {
                    $MatchLinkEncode = $LayoutObject->LinkEncode( $Match->{Parts}->{$Part} );
                    $URL =~ s/<MATCH$Part>/$MatchLinkEncode/g;
                    $URLPreview =~ s/<MATCH$Part>/$MatchLinkEncode/g;
                }

                push @{ $FilterData{Matches} }, {
                    Text       => $Match->{Name},
                    URL        => $URL,
                    URLPreview => $URLPreview,
                    Target     => $Filter->{Meta}->{Target} || '_blank',
                };
            }
            push @Data, \%FilterData;
        }
    }

    return @Data;
}

sub _CollectArticleAttachments {
    my ( $Self, %Param ) = @_;

    my %Article = %{ $Param{Article} };

    my %Attachments;

    # get cofig object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # download type
    my $Type = $ConfigObject->Get('AttachmentDownloadType') || 'attachment';

    $Article{AtmCount} = scalar keys %{ $Article{Atms} // {} };

    # if attachment will be forced to download, don't open a new download window!
    my $Target = 'target="AttachmentWindow" ';
    if ( $Type =~ /inline/i ) {
        $Target = 'target="attachment" ';
    }

    $Attachments{ZoomAttachmentDisplayCount}
        = $ConfigObject->Get('Ticket::ZoomAttachmentDisplayCount');

    ATTACHMENT:
    for my $FileID ( sort keys %{ $Article{Atms} } ) {
        push @{ $Attachments{Files} }, {
            ArticleID => $Article{ArticleID},
            %{ $Article{Atms}->{$FileID} },
            FileID => $FileID,
            Target => $Target,
            }
    }

    return \%Attachments;
}

sub _ArticleFlagSelectionString {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get all article flags for this article
    my %ArticleFlag = $TicketObject->ArticleFlagGet(
        ArticleID => $Param{ArticleID},
        UserID    => $Self->{UserID},
    );

    # get all available article flags
    my $ArticleFlags = $Self->{Config}->{ArticleFlags};
    my $IsModernize  = $Self->{Config}->{ArticleMenuModernize} // 1;

    my $ArticleFlagStrg = '';
    if ( ref $ArticleFlags eq 'HASH' && keys %{$ArticleFlags} ) {

        my %ArticleFlags = %{$ArticleFlags};

        # delete already used article flags
        for my $Flag ( keys %ArticleFlags ) {
            next if !defined $ArticleFlag{$Flag};
            delete $ArticleFlags{$Flag};
        }

        $ArticleFlags{0} = '- mark as -';
        if ( scalar %ArticleFlags ) {
            $ArticleFlagStrg = $LayoutObject->BuildSelection(
                Name         => 'ArticleFlagSelection_' . $Param{ArticleID},
                Data         => \%ArticleFlags,
                Translation  => 1,
                PossibleNone => 0,
                Sort         => 'AlphanumericValue',
                Class        => 'ArticleFlagSelection' . ($IsModernize ? ' Modernize' : ''),
            );
        }
    }

    return $ArticleFlagStrg;
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
