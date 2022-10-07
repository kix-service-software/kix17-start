# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::TicketOverview::Medium;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::User',
    'Kernel::System::Ticket',
    'Kernel::System::Main',
    'Kernel::System::Queue'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = \%Param;
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub ActionRow {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check if bulk feature is enabled
    my $BulkFeature = 0;
    if ( $Param{Bulk} && $ConfigObject->Get('Ticket::Frontend::BulkFeature') ) {
        my @Groups;
        if ( $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') ) {
            @Groups = @{ $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') };
        }
        if ( !@Groups ) {
            $BulkFeature = 1;
        }
        else {
            GROUP:
            for my $Group (@Groups) {
                next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
                if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                    $BulkFeature = 1;
                    last GROUP;
                }
            }
        }
    }

    $LayoutObject->Block(
        Name => 'DocumentActionRow',
        Data => \%Param,
    );

    if ($BulkFeature) {
        $LayoutObject->Block(
            Name => 'DocumentActionRowBulk',
            Data => {
                %Param,
                Name => Translatable('Bulk'),
            },
        );
    }

    # run ticket overview document item menu modules
    if (
        $Param{Config}->{OverviewMenuModules}
        && ref $ConfigObject->Get('Ticket::Frontend::OverviewMenuModule') eq 'HASH'
    ) {

        my %Menus = %{ $ConfigObject->Get('Ticket::Frontend::OverviewMenuModule') };
        MENUMODULE:
        for my $Menu ( sort keys %Menus ) {

            next MENUMODULE if !IsHashRefWithData( $Menus{$Menu} );
            next MENUMODULE if ( $Menus{$Menu}->{View} && $Menus{$Menu}->{View} ne $Param{View} );

            # load module
            if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Menus{$Menu}->{Module} ) ) {
                return $LayoutObject->FatalError();
            }
            my $Object = $Menus{$Menu}->{Module}->new( %{$Self} );

            # run module
            my $Item = $Object->Run(
                %Param,
                Config => $Menus{$Menu},
            );
            next MENUMODULE if !IsHashRefWithData($Item);

            if ( $Item->{Block} eq 'DocumentActionRowItem' ) {

                # add session id if needed
                if ( !$LayoutObject->{SessionIDCookie} && $Item->{Link} ) {
                    $Item->{Link}
                        .= ';'
                        . $LayoutObject->{SessionName} . '='
                        . $LayoutObject->{SessionID};
                }

                # create id
                $Item->{ID} = $Item->{Name};
                $Item->{ID} =~ s/(\s|&|;)//ig;

                my $Link = $Item->{Link};
                if ( $Item->{Target} ) {
                    $Link = '#';
                }

                my $Class = '';
                if ( $Item->{PopupType} ) {
                    $Class = 'AsPopup PopupType_' . $Item->{PopupType};
                }

                $LayoutObject->Block(
                    Name => $Item->{Block},
                    Data => {
                        ID          => $Item->{ID},
                        Name        => $LayoutObject->{LanguageObject}->Translate( $Item->{Name} ),
                        Link        => $LayoutObject->{Baselink} . $Item->{Link},
                        Description => $Item->{Description},
                        Block       => $Item->{Block},
                        Class       => $Class,
                    },
                );
            }
            elsif ( $Item->{Block} eq 'DocumentActionRowHTML' ) {

                next MENUMODULE if !$Item->{HTML};

                $LayoutObject->Block(
                    Name => $Item->{Block},
                    Data => $Item,
                );
            }
        }
    }

    # init for table control
    $LayoutObject->Block(
        Name => 'DocumentReadyStart',
        Data => \%Param,
    );

    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentTicketOverviewMedium',
        Data         => \%Param,
    );

    return $Output;
}

sub SortOrderBar {
    my ( $Self, %Param ) = @_;

    return '';
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(OriginalTicketIDs TicketIDs PageShown StartHit)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check if bulk feature is enabled
    my $BulkFeature = 0;
    if ( $Param{Bulk} && $ConfigObject->Get('Ticket::Frontend::BulkFeature') ) {
        my @Groups;
        if ( $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') ) {
            @Groups = @{ $ConfigObject->Get('Ticket::Frontend::BulkFeatureGroup') };
        }
        if ( !@Groups ) {
            $BulkFeature = 1;
        }
        else {
            GROUP:
            for my $Group (@Groups) {
                next GROUP if !$LayoutObject->{"UserIsGroup[$Group]"};
                if ( $LayoutObject->{"UserIsGroup[$Group]"} eq 'Yes' ) {
                    $BulkFeature = 1;
                    last GROUP;
                }
            }
        }
    }

    $LayoutObject->Block(
        Name => 'DocumentHeader',
        Data => \%Param,
    );

    my $OutputMeta = $LayoutObject->Output(
        TemplateFile => 'AgentTicketOverviewMedium',
        Data         => \%Param,
    );
    my $OutputRaw = '';
    if ( !$Param{Output} ) {
        $LayoutObject->Print( Output => \$OutputMeta );
    }
    else {
        $OutputRaw .= $OutputMeta;
    }
    my $Output        = '';
    my $Counter       = 0;
    my $CounterOnSite = 0;
    my @TicketIDsShown;

    # get needed un-/selected tickets for bulk feature
    my @SelectedItems     = @{ $Param{SelectedItems} };
    my %SelectedItemsHash = map( { $_ => 1 } @SelectedItems );
    my @UnselectedItems   = @{ $Param{UnselectedItems} };

    # check if there are tickets to show
    if ( scalar @{ $Param{TicketIDs} } ) {

        my $BulkActivate    = 0;
        my $ItemALLChecked  = '';
        my $SelectedAll     = 0;
        my $BulkSelectedAll = 0;

        if ( !scalar( @UnselectedItems ) ) {
            $ItemALLChecked = ' checked="checked"';
        }

        for my $TicketID ( @{ $Param{TicketIDs} } ) {
            my $ItemChecked = '';
            $Counter++;

            if (
                $Counter >= $Param{StartHit}
                && $Counter < ( $Param{PageShown} + $Param{StartHit} )
            ) {
                if ( $SelectedItemsHash{ $TicketID } ) {
                    $ItemChecked = ' checked="checked"';
                }

                if (
                    !$SelectedAll
                    && $Param{AllHits} > $Param{PageShown}
                ) {
                    $SelectedAll = 1;
                }

                push( @TicketIDsShown, $TicketID );
                $Output = $Self->_Show(
                    TicketID        => $TicketID,
                    Counter         => $CounterOnSite,
                    Bulk            => $BulkFeature,
                    Config          => $Param{Config},
                    ItemChecked     => $ItemChecked,
                    BulkActivate    => $BulkActivate,
                    BulkSelectedAll => $BulkSelectedAll,
                    ItemALLChecked  => $ItemALLChecked,
                );

                if (
                    !$BulkActivate
                    && $ItemChecked
                ) {
                    $BulkActivate = 1;
                }

                if (
                    !$BulkSelectedAll
                    && $SelectedAll
                ) {
                    $BulkSelectedAll = 1;
                }

                $CounterOnSite++;
                if ( !$Param{Output} ) {
                    $LayoutObject->Print( Output => $Output );
                }
                else {
                    $OutputRaw .= ${$Output};
                }
            }
        }
    }
    else {
        $LayoutObject->Block( Name => 'NoTicketFound' );
    }

    # check if bulk feature is enabled
    if ($BulkFeature) {
        $LayoutObject->Block(
            Name => 'DocumentFooter',
            Data => \%Param,
        );
        for my $TicketID (@TicketIDsShown) {
            $LayoutObject->Block(
                Name => 'DocumentFooterBulkItem',
                Data => \%Param,
            );
        }
        $OutputMeta = $LayoutObject->Output(
            TemplateFile => 'AgentTicketOverviewMedium',
            Data         => \%Param,
        );
        if ( !$Param{Output} ) {
            $LayoutObject->Print( Output => \$OutputMeta );
        }
        else {
            $OutputRaw .= $OutputMeta;
        }
    }

    return $OutputRaw;
}

sub _Show {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check if bulk feature is enabled
    if ( $Param{Bulk} ) {
        $LayoutObject->Block(
            Name => 'Bulk',
            Data => \%Param,
        );

        if ( !$Param{BulkActivate}
            && $Param{ItemChecked}
        ) {
            $LayoutObject->Block(
                Name => 'BulkActivate',
                Data => \%Param,
            );
        }
        if ( !$Param{BulkSelectedAll} ) {
            $LayoutObject->Block(
                Name => 'BulkSelectedAll',
            );
        }
    }

    # get move queues
    my %MoveQueues = $TicketObject->TicketMoveList(
        TicketID => $Param{TicketID},
        UserID   => $Self->{UserID},
        Action   => $LayoutObject->{Action},
        Type     => 'move_into',
    );

    # get last customer article
    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # Fallback for tickets without articles: get at least basic ticket data
    if ( !%Article ) {
        %Article = %Ticket;
        if ( !$Article{Title} ) {
            $Article{Title} = $LayoutObject->{LanguageObject}->Translate(
                'This ticket has no title or subject'
            );
        }
        $Article{Subject} = $Article{Title};
    }

    # show ticket create time in current view
    $Article{Created} = $Ticket{Created};
# ---
# ITSMIncidentProblemManagement
# ---
    # set criticality and impact
    $Article{Criticality} = $Article{DynamicField_ITSMCriticality} || '-';
    $Article{Impact}      = $Article{DynamicField_ITSMImpact}      || '-';
# ---

    # user info
    my %UserInfo = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Article{OwnerID},
    );
    %Article = ( %UserInfo, %Article );

    # create human age
    $Article{Age} = $LayoutObject->CustomerAge(
        Age   => $Article{Age},
        Space => ' '
    );

    # fetch all std. templates ...
    my %StandardTemplates = $Kernel::OM->Get('Kernel::System::Queue')->QueueStandardTemplateMemberList(
        QueueID       => $Article{QueueID},
        TemplateTypes => 1,
    );

    $Param{StandardResponsesStrg} = $LayoutObject->BuildSelection(
        Name => 'ResponseID',
        Data => $StandardTemplates{Answer} || {},
    );

    # customer info
    if ( $Param{Config}->{CustomerInfo} ) {
        if ( $Article{CustomerUserID} ) {
            $Article{CustomerName} = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerName(
                UserLogin => $Article{CustomerUserID},
            );
        }
    }

    # get ACL restrictions
    my %PossibleActions;
    my $Counter = 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get all registered Actions
    if ( ref $ConfigObject->Get('Frontend::Module') eq 'HASH' ) {

        my %Actions = %{ $ConfigObject->Get('Frontend::Module') };

        # only use those Actions that stats with AgentTicket
        %PossibleActions = map { ++$Counter => $_ }
            grep { substr( $_, 0, length 'AgentTicket' ) eq 'AgentTicket' }
            sort keys %Actions;
    }

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Article{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );

    my %AclAction = %PossibleActions;
    if ($ACL) {
        %AclAction = $TicketObject->TicketAclActionData();
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    # run ticket pre menu modules
    my @ActionItems;
    if ( ref $ConfigObject->Get('Ticket::Frontend::PreMenuModule') eq 'HASH' ) {
        my %Menus = %{ $ConfigObject->Get('Ticket::Frontend::PreMenuModule') };
        MENU:
        for my $Menu ( sort keys %Menus ) {

            # load module
            if ( !$MainObject->Require( $Menus{$Menu}->{Module} ) ) {
                return $LayoutObject->FatalError();
            }
            my $Object = $Menus{$Menu}->{Module}->new(
                %{$Self},
                TicketID => $Param{TicketID},
            );

            # run module
            my $Item = $Object->Run(
                %Param,
                Ticket => \%Article,
                ACL    => \%AclAction,
                Config => $Menus{$Menu},
            );
            next MENU if !$Item;
            next MENU if ref $Item ne 'HASH';

            # add session id if needed
            if ( !$LayoutObject->{SessionIDCookie} && $Item->{Link} ) {
                $Item->{Link}
                    .= ';'
                    . $LayoutObject->{SessionName} . '='
                    . $LayoutObject->{SessionID};
            }

            # create id
            $Item->{ID} = $Item->{Name};
            $Item->{ID} =~ s/(\s|&|;)//ig;

            my $Output;
            if ( $Item->{Block} ) {
                $LayoutObject->Block(
                    Name => $Item->{Block},
                    Data => $Item,
                );
                $Output = $LayoutObject->Output(
                    TemplateFile => 'AgentTicketOverviewMedium',
                    Data         => $Item,
                );
            }
            else {
                $Output = '<li id="'
                    . $Item->{ID}
                    . '"><a href="#" title="'
                    . $LayoutObject->{LanguageObject}->Translate( $Item->{Description} )
                    . '">'
                    . $LayoutObject->{LanguageObject}->Translate( $Item->{Name} )
                    . '</a></li>';
            }

            $Output =~ s/\n+//g;
            $Output =~ s/\s+/ /g;
            $Output =~ s/<\!--.+?-->//g;

            # check if the browser sends the session id cookie
            # if not, add the session id to the url
            my $SessionID = '';
            if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
                $SessionID = ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
            }

            push @ActionItems, {
                HTML        => $Output,
                ID          => $Item->{ID},
                Name        => $Item->{Name},
                Link        => $LayoutObject->{Baselink} . $Item->{Link} . $SessionID,
                Target      => $Item->{Target},
                PopupType   => $Item->{PopupType},
                Description => $Item->{Description},
                Block       => $Item->{Block},
            };
        }
    }

    # prepare subject
    $Article{Subject} = $TicketObject->TicketSubjectClean(
        TicketNumber => $Article{TicketNumber},
        Subject      => $Article{Subject} || '',
    );

    $LayoutObject->Block(
        Name => 'DocumentContent',
        Data => { %Param, %Article },
    );

    # if "Actions per Ticket" (Inline Action Row) is active
    if ( $Param{Config}->{TicketActionsPerTicket} ) {
        $LayoutObject->Block(
            Name => 'InlineActionRow',
            Data => \%Param,
        );

        # Add list entries for every action
        for my $Item (@ActionItems) {
            my $Link = $Item->{Link};
            if ( $Item->{Target} ) {
                $Link = '#';
            }

            my $Class = '';
            if ( $Item->{PopupType} ) {
                $Class = 'AsPopup PopupType_' . $Item->{PopupType};
            }

            if ( !$Item->{Block} ) {
                $LayoutObject->Block(
                    Name => 'InlineActionRowItem',
                    Data => {
                        TicketID    => $Param{TicketID},
                        QueueID     => $Article{QueueID},
                        ID          => $Item->{ID},
                        Name        => $Item->{Name},
                        Description => $Item->{Description},
                        Class       => $Class,
                        Link        => $Link,
                    },
                );
            }
            else {
                my $TicketID   = $Param{TicketID};
                my $SelectHTML = $Item->{HTML};
                $SelectHTML =~ s/id="DestQueueID"/id="DestQueueID$TicketID"/xmig;
                $SelectHTML =~ s/for="DestQueueID"/for="DestQueueID$TicketID"/xmig;
                $LayoutObject->Block(
                    Name => 'InlineActionRowItemHTML',
                    Data => {
                        HTML => $SelectHTML,
                    },
                );
            }
        }
    }

    # check if bulk feature is enabled
    if ( $Param{Bulk} ) {
        $LayoutObject->Block(
            Name => 'Bulk',
            Data => \%Param,
        );

        if ( !$Param{BulkActivate}
            && $Param{ItemChecked}
        ) {
            $LayoutObject->Block(
                Name => 'BulkActivate',
                Data => \%Param,
            );
        }
        if ( !$Param{BulkSelectedAll} ) {
            $LayoutObject->Block(
                Name => 'BulkSelectedAll',
            );
        }
    }

    # show ticket flags
    my @TicketMetaItems = $LayoutObject->TicketMetaItems(
        Ticket => \%Article,
    );
    for my $Item (@TicketMetaItems) {
        $LayoutObject->Block(
            Name => 'Meta',
            Data => $Item,
        );
        if ($Item) {
            $LayoutObject->Block(
                Name => 'MetaIcon',
                Data => $Item,
            );
        }
    }

    # get class for ticket highlight
    my $HighlightClass = $LayoutObject->GetTicketHighlight(
        View   => 'Large',
        Ticket => \%Article
    );

    if ( $HighlightClass ) {
        $LayoutObject->Block(
            Name => 'MetaIcon',
            Data => {
                Class     => 'Flag TicketOverviewHighlightClass',
                ClassSpan => $HighlightClass,
                Title     => $Article{State}
            },
        );
    }

    # run article modules
    if ( $Article{ArticleID} ) {
        if ( ref $ConfigObject->Get('Ticket::Frontend::ArticlePreViewModule') eq 'HASH' ) {
            my %Jobs = %{ $ConfigObject->Get('Ticket::Frontend::ArticlePreViewModule') };
            for my $Job ( sort keys %Jobs ) {

                # load module
                if ( !$MainObject->Require( $Jobs{$Job}->{Module} ) ) {
                    return $LayoutObject->FatalError();
                }
                my $Object = $Jobs{$Job}->{Module}->new(
                    %{$Self},
                    ArticleID => $Article{ArticleID},
                    UserID    => $Self->{UserID},
                    Debug     => $Self->{Debug},
                );

                # run module
                my @Data = $Object->Check(
                    Article => \%Article,
                    %Param, Config => $Jobs{$Job}
                );

                for my $DataRef (@Data) {
                    $LayoutObject->Block(
                        Name => 'ArticleOption',
                        Data => $DataRef,
                    );
                }

                # filter option
                $Object->Filter(
                    Article => \%Article,
                    %Param, Config => $Jobs{$Job}
                );
            }
        }
    }

    # create output
    $LayoutObject->Block(
        Name => 'AgentAnswer',
        Data => { %Param, %Article, %AclAction },
    );
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketCompose}
        && ( !defined $AclAction{AgentTicketCompose} || $AclAction{AgentTicketCompose} )
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get("Ticket::Frontend::AgentTicketCompose");
        if ( $Config->{Permission} ) {
            my $Ok = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Param{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$Ok ) {
                $Access = 0;
            }
            if ($Access) {
                $LayoutObject->Block(
                    Name => 'AgentAnswerCompose',
                    Data => { %Param, %Article, %AclAction },
                );
            }
        }
    }
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketPhoneOutbound}
        && (
            !defined $AclAction{AgentTicketPhoneOutbound}
            || $AclAction{AgentTicketPhoneOutbound}
        )
    ) {
        my $Access = 1;
        my $Config = $ConfigObject->Get("Ticket::Frontend::AgentTicketPhoneOutbound");
        if ( $Config->{Permission} ) {
            my $OK = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Param{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$OK ) {
                $Access = 0;
            }
        }
        if ($Access) {
            $LayoutObject->Block(
                Name => 'AgentAnswerPhoneOutbound',
                Data => { %Param, %Article, %AclAction },
            );
        }
    }

    # ticket type
    if ( $ConfigObject->Get('Ticket::Type') ) {
        $LayoutObject->Block(
            Name => 'Type',
            Data => {
                %Param,
                %Article,
                TypeTranslation => $ConfigObject->Get('Ticket::TypeTranslation'),
            },
        );
    }

    # ticket service
    if ( $ConfigObject->Get('Ticket::Service') && $Article{Service} ) {
        $LayoutObject->Block(
            Name => 'Service',
            Data => {
                %Param,
                %Article,
                ServiceTranslation => $ConfigObject->Get('Ticket::ServiceTranslation'),
            },
        );
        if ( $Article{SLA} ) {
            $LayoutObject->Block(
                Name => 'SLA',
                Data => {
                    %Param,
                    %Article,
                    SLATranslation => $ConfigObject->Get('Ticket::SLATranslation'),
                },
            );
        }
    }

    # get ticket escalation preferences
    my $TicketEscalation = $TicketObject->TicketEscalationCheck(
        TicketID => $Param{TicketID},
        UserID   => $Self->{UserID},
    );
    my $TicketEscalationDisabled = $TicketObject->TicketEscalationDisabledCheck(
        TicketID => $Param{TicketID},
        UserID   => $Self->{UserID},
    );

    # show first response time if needed
    if ( $TicketEscalation->{'FirstResponse'} ) {

        if ($TicketEscalationDisabled) {
            $Article{FirstResponseTimeHuman}       = $LayoutObject->{LanguageObject}->Translate('suspended');
            $Article{FirstResponseTimeWorkingTime} = $LayoutObject->{LanguageObject}->Translate('suspended');

            $LayoutObject->Block(
                Name => 'FirstResponseTime',
                Data => { %Param, %Article },
            );
        }
        else {
            $Article{FirstResponseTimeHuman} = $LayoutObject->CustomerAgeInHours(
                Age   => $Article{FirstResponseTime} || 0,
                Space => ' ',
            );
            $Article{FirstResponseTimeWorkingTime} = $LayoutObject->CustomerAgeInHours(
                Age   => $Article{FirstResponseTimeWorkingTime},
                Space => ' ',
            );
            if ( 60 * 60 * 1 > $Article{FirstResponseTime} ) {
                $Article{FirstResponseTimeClass} = 'Warning'
            }
            $LayoutObject->Block(
                Name => 'FirstResponseTime',
                Data => { %Param, %Article },
            );
        }
    }

    # show update time if needed
    if ( $TicketEscalation->{'Update'} ) {
        if ($TicketEscalationDisabled) {
            $Article{UpdateTimeHuman}       = $LayoutObject->{LanguageObject}->Translate('suspended');
            $Article{UpdateTimeWorkingTime} = $LayoutObject->{LanguageObject}->Translate('suspended');

            $LayoutObject->Block(
                Name => 'UpdateTime',
                Data => { %Param, %Article },
            );
        }
        else {
            $Article{UpdateTimeHuman} = $LayoutObject->CustomerAgeInHours(
                Age   => $Article{UpdateTime} || 0,
                Space => ' ',
            );
            $Article{UpdateTimeWorkingTime} = $LayoutObject->CustomerAgeInHours(
                Age   => $Article{UpdateTimeWorkingTime},
                Space => ' ',
            );
            if ( 60 * 60 * 1 > $Article{UpdateTime} ) {
                $Article{UpdateTimeClass} = 'Warning'
            }
            $LayoutObject->Block(
                Name => 'UpdateTime',
                Data => { %Param, %Article },
            );
        }
    }

    # show solution time if needed
    if ( $TicketEscalation->{'Solution'} ) {
        if ($TicketEscalationDisabled) {
            $Article{SolutionTimeHuman}       = $LayoutObject->{LanguageObject}->Translate('suspended');
            $Article{SolutionTimeWorkingTime} = $LayoutObject->{LanguageObject}->Translate('suspended');

            $LayoutObject->Block(
                Name => 'SolutionTime',
                Data => { %Param, %Article },
            );
        }
        else {
            $Article{SolutionTimeHuman} = $LayoutObject->CustomerAgeInHours(
                Age   => $Article{SolutionTime} || 0,
                Space => ' ',
            );
            $Article{SolutionTimeWorkingTime} = $LayoutObject->CustomerAgeInHours(
                Age   => $Article{SolutionTimeWorkingTime},
                Space => ' ',
            );
            if ( 60 * 60 * 1 > $Article{SolutionTime} ) {
                $Article{SolutionTimeClass} = 'Warning'
            }
            $LayoutObject->Block(
                Name => 'SolutionTime',
                Data => { %Param, %Article },
            );
        }
    }

    # Dynamic fields
    $Counter = 0;
    my $DisplayDynamicFieldTable = 1;

    # get dynamic field config for frontend module
    my $DynamicFieldFilter
        = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::OverviewMedium")->{DynamicField};

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $DynamicFieldFilter || {},
    );

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # get dynamic field backend object
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        # get field value
        my $Value = $DynamicFieldBackendObject->ValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $Param{TicketID},
        );

        next DYNAMICFIELD if ( !defined $Value );

        $Counter++;

        my $ValueStrg = $DynamicFieldBackendObject->DisplayValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
            ValueMaxChars      => 20,
            LayoutObject       => $LayoutObject,
        );

        my $Label = $DynamicFieldConfig->{Label};

        # show dynamic field table if at least one field is displayed
        if ( $DisplayDynamicFieldTable == 1 ) {
            $LayoutObject->Block(
                Name => 'DynamicFieldTable',
                Data => {},
            );
            $DisplayDynamicFieldTable = 0;
        }

        # create a new row if counter is starting
        if ( $Counter == 1 ) {
            $LayoutObject->Block(
                Name => 'DynamicFieldTableRow',
                Data => {},
            );
        }

        # outout dynamic field label
        $LayoutObject->Block(
            Name => 'DynamicFieldTableRowRecord',
            Data => {
                Label => $Label,
            },
        );

        if ( $ValueStrg->{Link} ) {
            my $HTMLLink = $Kernel::OM->GetNew('Kernel::Output::HTML::Layout')->Output(
                Template => '<a href="[% Data.Link | Interpolate %]" target="_blank" class="DynamicFieldLink">[% Data.Value %]</a>',
                Data     => {
                    Value                       => $ValueStrg->{Value},
                    Title                       => $ValueStrg->{Title},
                    Link                        => $ValueStrg->{Link},
                    $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                },
            );
            my %Safe = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
                String       => $HTMLLink,
                NoApplet     => 1,
                NoObject     => 1,
                NoEmbed      => 1,
                NoSVG        => 1,
                NoImg        => 1,
                NoIntSrcLoad => 0,
                NoExtSrcLoad => 1,
                NoJavaScript => 1,
            );
            if ( $Safe{Replace} ) {
                $HTMLLink = $Safe{String};
            }

            # outout dynamic field value link
            $LayoutObject->Block(
                Name => 'DynamicFieldTableRowRecordLink',
                Data => {
                    Value                       => $ValueStrg->{Value},
                    Title                       => $ValueStrg->{Title},
                    Link                        => $ValueStrg->{Link},
                    $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                    HTMLLink                    => $HTMLLink,
                },
            );
        }
        else {

            # outout dynamic field value plain
            $LayoutObject->Block(
                Name => 'DynamicFieldTableRowRecordPlain',
                Data => {
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );
        }

        # only 5 dynamic fields by row are allowed, reset couter if needed
        if ( $Counter == 5 ) {
            $Counter = 0;
        }

        # example of dynamic fields order customization
        # outout dynamic field label
        $LayoutObject->Block(
            Name => 'DynamicFieldTableRowRecord' . $DynamicFieldConfig->{Name},
            Data => {
                Label => $Label,
            },
        );

        if ( $ValueStrg->{Link} ) {

            # outout dynamic field value link
            $LayoutObject->Block(
                Name => 'DynamicFieldTableRowRecord' . $DynamicFieldConfig->{Name} . 'Link',
                Data => {
                    Value                       => $ValueStrg->{Value},
                    Title                       => $ValueStrg->{Title},
                    Link                        => $ValueStrg->{Link},
                    $DynamicFieldConfig->{Name} => $ValueStrg->{Title},
                },
            );
        }
        else {

            # outout dynamic field value plain
            $LayoutObject->Block(
                Name => 'DynamicFieldTableRowRecord' . $DynamicFieldConfig->{Name} . 'Plain',
                Data => {
                    Value => $ValueStrg->{Value},
                    Title => $ValueStrg->{Title},
                },
            );
        }
    }

    # fill the rest of the Dynamic Fields row with empty cells, this will look better
    if ( $Counter > 0 && $Counter < 5 ) {

        for ( $Counter + 1 ... 5 ) {

            # outout dynamic field label
            $LayoutObject->Block(
                Name => 'DynamicFieldTableRowRecord',
                Data => {
                    Label => '',
                },
            );

            # outout dynamic field value plain
            $LayoutObject->Block(
                Name => 'DynamicFieldTableRowRecordPlain',
                Data => {
                    Value => '',
                    Title => '',
                },
            );
        }
    }

    # test access to frontend module for Customer
    my $Access = $LayoutObject->Permission(
        Action => 'AgentTicketCustomer',
        Type   => 'rw',
    );
    if ($Access) {

        # test access to ticket
        my $Config = $ConfigObject->Get('Ticket::Frontend::AgentTicketCustomer');
        if ( $Config->{Permission} ) {
            my $OK = $TicketObject->TicketPermission(
                Type     => $Config->{Permission},
                TicketID => $Param{TicketID},
                UserID   => $Self->{UserID},
                LogNo    => 1,
            );
            if ( !$OK ) {
                $Access = 0;
            }
        }
    }

    # define proper tt block based on permissions
    my $CustomerIDBlock = $Access ? 'CustomerIDRW' : 'CustomerIDRO';
    $LayoutObject->Block(
        Name => $CustomerIDBlock,
        Data => { %Param, %Article },
    );

    # get MoveQueuesStrg
    if ( $ConfigObject->Get('Ticket::Frontend::MoveType') =~ /^form$/i ) {
        $Param{MoveQueuesStrg} = $LayoutObject->AgentQueueListOption(
            Name       => 'DestQueueID',
            Data       => \%MoveQueues,
            SelectedID => $Article{QueueID},
        );
    }
    if (
        $ConfigObject->Get('Frontend::Module')->{AgentTicketMove}
        && ( !defined $AclAction{AgentTicketMove} || $AclAction{AgentTicketMove} )
    ) {
        my $HasAccess = $TicketObject->TicketPermission(
            Type     => 'rw',
            TicketID => $Param{TicketID},
            UserID   => $Self->{UserID},
            LogNo    => 1,
        );
        my $MoveConfig = $ConfigObject->Get("Ticket::Frontend::AgentTicketMove");
        if (
            $HasAccess
            && (
                !$MoveConfig->{RequiredLock}
                || !$TicketObject->TicketLockGet( TicketID => $Param{TicketID} )
                || $TicketObject->OwnerCheck(
                    TicketID => $Param{TicketID},
                    OwnerID  => $Self->{UserID},
                )
            )
        ) {
            $LayoutObject->Block(
                Name => 'Move',
                Data => { %Param, %AclAction },
            );
        }
    }

    # add action items as js
    if ( @ActionItems && !$Param{Config}->{TicketActionsPerTicket} ) {
        $LayoutObject->Block(
            Name => 'DocumentReadyActionRowAdd',
            Data => {
                TicketID => $Param{TicketID},
                Data     => \@ActionItems,
            },
        );
    }

    # create & return output
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentTicketOverviewMedium',
        Data         => { %Param, %Article, %AclAction },
    );

    return \$Output;
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
