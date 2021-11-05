# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AsynchronousExecutor::BulkExecutor;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);


our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::State',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Web::UploadCache',
    'Kernel::System::JSON',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}            = $Kernel::OM->Get('Kernel::Config');
    $Self->{CustomerUserObject}      = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{JSONObject}              = $Kernel::OM->Get('Kernel::System::JSON');
    $Self->{LogObject}               = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{StateObject}             = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TicketObject}            = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{UploadCacheObject}       = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    $Self->{UserObject}              = $Kernel::OM->Get('Kernel::System::User');
    $Self->{TemplateGeneratorObject} = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

    return $Self;
}

#------------------------------------------------------------------------------
# BEGIN run method
#
sub Run {
    my ( $Self, %Param ) = @_;

    my %UserData = $Self->{UserObject}->GetUserData(
        UserID => $Param{UserID},
    );

    $Kernel::OM->ObjectParamAdd(
        'Kernel::Output::HTML::Layout' => {
            UserLanguage => $UserData{UserLanguage},
        },
    );

    $Self->{LayoutObject}   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{LanguageObject} = $Self->{LayoutObject}->{LanguageObject};

    if ( $Param{CallAction} eq 'BulkLock' ) {
        return $Self->_BulkLock(
            %Param,
        );
    }

    elsif ( $Param{CallAction} eq 'BulkDo' ) {
        return $Self->_BulkDo(
            %Param,
        );
    }

    elsif ( $Param{CallAction} eq 'BulkCancel' ) {
        return $Self->_BulkCancel(
            %Param,
        );
    }
}

sub _BulkLock {
    my ( $Self, %Param ) = @_;

    my %GetParam;
    my %Data;
    my $ReSchedule             = 0;
    my $Success                = 0;
    my $FormID                 = $Param{FormID}.'.'.$Param{Action}.'.'.$Param{UserID};
    my @IgnoreLockedTicketIDs  = $Param{IgnoreLockedTicketIDs};
    my %Ticket                 = $Self->{TicketObject}->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID}
    );

    if ( grep ( { $_ eq $Param{TicketID} } @IgnoreLockedTicketIDs ) ) {
        $Data{Notify}   = $Ticket{TicketNumber}. ": " . $Self->{LanguageObject}->Translate("Ticket is locked by another agent and will be ignored!");
        $Data{Priority} = 'Error';

    }
    elsif ( $Ticket{Lock} eq 'unlock' ) {
        $Data{Notify}   = $Ticket{TicketNumber}. ": " . $Self->{LanguageObject}->Translate("Ticket locked.");
        $Data{Priority} = 'Notice';

        # set lock
        $Self->{TicketObject}->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'lock',
            UserID   => $Param{UserID},
        );

        # set user id
        $Self->{TicketObject}->TicketOwnerSet(
            TicketID  => $Param{TicketID},
            UserID    => $Param{UserID},
            NewUserID => $Param{UserID},
        );

        $Data{Locked}            = 1;
        $Data{TicketsWereLocked} = 1;

        $Success    = 1;
    }
    else {
        $Data{Notify}   = $Ticket{TicketNumber}. ": " . $Self->{LanguageObject}->Translate("Ticket selected.");
        $Data{Priority} = 'Info';

        $Success    = 1;
    }

    my $FileID = $Self->{UploadCacheObject}->FormIDAddFile(
        FormID      => $FormID,
        Filename    => 'Ticket_' . $Param{TicketID},
        Content     => $Self->{JSONObject}->Encode( Data => \%Data),
        ContentType => 'text/xml',
    );

    return {
        Success    => $Success,
        ReSchedule => $ReSchedule,
    };
}

sub _BulkDo {
    my ( $Self, %Param ) = @_;

    my $Config      = $Self->{ConfigObject}->Get("Ticket::Frontend::$Param{Action}");
    my %GetParam    = %{$Param{GetParam}};
    my @BulkModules = @{$Param{BulkModules}};
    my %Ticket      = %{$Param{Ticket}};
    my %Time        = %{$Param{Time}};
    my @TicketIDs   = @{$Param{TicketIDs}};

    # set owner
    if ( $Config->{Owner} && ( $GetParam{'OwnerID'} || $GetParam{'Owner'} ) ) {
        my %AllGroupsMembers = $Self->{UserObject}->UserList(
            Type  => 'Long',
            Valid => 1
        );

        # only put possible rw agents to possible owner list
        if ( !$Self->{ConfigObject}->Get('Ticket::ChangeOwnerToEveryone') ) {
            my %AllGroupsMembersNew;
            if (
                $GetParam{'QueueID'}
                || $GetParam{'Queue'}
            ) {
                if ( !$GetParam{'QueueID'} ) {
                    $GetParam{'QueueID'} = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                        Queue => $GetParam{'Queue'},
                        Valid => 1,
                    );
                }

                my $GroupID = $Kernel::OM->Get('Kernel::System::Queue')->GetQueueGroupID( QueueID => $GetParam{'QueueID'} );
                my %GroupMember = $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupGet(
                    GroupID => $GroupID,
                    Type    => 'rw',
                );

                USER_ID:
                for my $UserID ( sort keys %GroupMember ) {
                    next USER_ID if !$AllGroupsMembers{$UserID};
                    $AllGroupsMembersNew{$UserID} = $AllGroupsMembers{$UserID};
                }
                %AllGroupsMembers = %AllGroupsMembersNew;
            }
            else {
                for my $TicketID ( @TicketIDs ) {
                    my %Ticket = $Self->{TicketObject}->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 0,
                    );
                    my $GroupID = $Kernel::OM->Get('Kernel::System::Queue')->GetQueueGroupID( QueueID => $Ticket{QueueID} );
                    my %GroupMember = $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupGet(
                        GroupID => $GroupID,
                        Type    => 'rw',
                    );

                    USER_ID:
                    for my $UserID ( sort keys %GroupMember ) {
                        next USER_ID if !$AllGroupsMembers{$UserID};
                        $AllGroupsMembersNew{$UserID} = $AllGroupsMembers{$UserID};
                    }
                    %AllGroupsMembers = %AllGroupsMembersNew;
                }
            }
        }
        if ( !$GetParam{'OwnerID'} ) {
            $GetParam{'OwnerID'} = $Self->{UserObject}->UserLookup(
                UserLogin => $GetParam{'Owner'},
            );
        }
        if ( $AllGroupsMembers{ $GetParam{'OwnerID'} } ) {
            $Self->{TicketObject}->TicketOwnerSet(
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
                NewUser   => $GetParam{'Owner'},
                NewUserID => $GetParam{'OwnerID'},
            );
            if ( !$Config->{RequiredLock} && $Ticket{StateType} !~ /^close/i ) {
                $Self->{TicketObject}->TicketLockSet(
                    TicketID => $Param{TicketID},
                    Lock     => 'lock',
                    UserID   => $Param{UserID},
                );
            }
        }
    }

    # set responsible
    if (
        $Self->{ConfigObject}->Get('Ticket::Responsible')
        && $Config->{Responsible}
        && ( $GetParam{'ResponsibleID'} || $GetParam{'Responsible'} )
    ) {
        my %AllGroupsMembers = $Self->{UserObject}->UserList(
            Type  => 'Long',
            Valid => 1
        );

        # only put possible rw agents to possible responsible list
        if ( !$Self->{ConfigObject}->Get('Ticket::ChangeOwnerToEveryone') ) {
            my %AllGroupsMembersNew;
            if (
                $GetParam{'QueueID'}
                || $GetParam{'Queue'}
            ) {
                if ( !$GetParam{'QueueID'} ) {
                    $GetParam{'QueueID'} = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                        Queue => $GetParam{'Queue'},
                        Valid => 1,
                    );
                }

                my $GroupID = $Kernel::OM->Get('Kernel::System::Queue')->GetQueueGroupID( QueueID => $GetParam{'QueueID'} );
                my %GroupMember = $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupGet(
                    GroupID => $GroupID,
                    Type    => 'rw',
                );

                USER_ID:
                for my $UserID ( sort keys %GroupMember ) {
                    next USER_ID if !$AllGroupsMembers{$UserID};
                    $AllGroupsMembersNew{$UserID} = $AllGroupsMembers{$UserID};
                }
                %AllGroupsMembers = %AllGroupsMembersNew;
            }
            else {
                for my $TicketID ( @TicketIDs ) {
                    my %Ticket = $Self->{TicketObject}->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 0,
                    );
                    my $GroupID = $Kernel::OM->Get('Kernel::System::Queue')->GetQueueGroupID( QueueID => $Ticket{QueueID} );
                    my %GroupMember = $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupGet(
                        GroupID => $GroupID,
                        Type    => 'rw',
                    );

                    USER_ID:
                    for my $UserID ( sort keys %GroupMember ) {
                        next USER_ID if !$AllGroupsMembers{$UserID};
                        $AllGroupsMembersNew{$UserID} = $AllGroupsMembers{$UserID};
                    }
                    %AllGroupsMembers = %AllGroupsMembersNew;
                }
            }
        }
        if ( !$GetParam{'ResponsibleID'} ) {
            $GetParam{'ResponsibleID'} = $Self->{UserObject}->UserLookup(
                UserLogin => $GetParam{'Responsible'},
            );
        }
        if ( $AllGroupsMembers{ $GetParam{'ResponsibleID'} } ) {
            $Self->{TicketObject}->TicketResponsibleSet(
                TicketID  => $Param{TicketID},
                UserID    => $Param{UserID},
                NewUser   => $GetParam{'Responsible'},
                NewUserID => $GetParam{'ResponsibleID'},
            );
        }
    }

    # set priority
    if (
        $Config->{Priority}
        && ( $GetParam{'PriorityID'} || $GetParam{'Priority'} )
    ) {
        $Self->{TicketObject}->TicketPrioritySet(
            TicketID   => $Param{TicketID},
            UserID     => $Param{UserID},
            Priority   => $GetParam{'Priority'},
            PriorityID => $GetParam{'PriorityID'},
        );
    }

    # set type
    if ( $Self->{ConfigObject}->Get('Ticket::Type') && $Config->{TicketType} ) {
        if ( $GetParam{'TypeID'} ) {
            $Self->{TicketObject}->TicketTypeSet(
                TypeID   => $GetParam{'TypeID'},
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
    }

    # set queue
    if ( $GetParam{'QueueID'} || $GetParam{'Queue'} ) {
        $Self->{TicketObject}->TicketQueueSet(
            QueueID  => $GetParam{'QueueID'},
            Queue    => $GetParam{'Queue'},
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );
    }

    if (
        $Self->{ConfigObject}->Get('Ticket::Watcher')
        && $Config->{TicketWatch}
    ) {
        if ( $GetParam{'Watch'} ) {
            if ( $GetParam{'Watch'} eq 'Watch' ) {
                $Self->{TicketObject}->TicketWatchSubscribe(
                    TicketID    => $Param{TicketID},
                    WatchUserID => $Param{UserID},
                    UserID      => $Param{UserID},
                );
            }
            elsif ( $GetParam{'Watch'} eq 'Unwatch' ) {
                $Self->{TicketObject}->TicketWatchUnsubscribe(
                    TicketID    => $Param{TicketID},
                    WatchUserID => $Param{UserID},
                    UserID      => $Param{UserID},
                );
            }
        }
    }

    # send email
    my $EmailArticleID;
    if (
        $GetParam{'EmailSubject'}
        && $GetParam{'EmailBody'}
    ) {

        $GetParam{EmailSubject} = $Self->_ReplacePlaceHolder(
            Text      => $GetParam{EmailSubject},
            Data      => {},
            RichText  => 0,
            UserID    => $Param{UserID},
            TicketID  => $Param{TicketID},
            WhiteList => $Config->{PlaceholderWhitelist} || ''
        );
        $GetParam{EmailBody} = $Self->_ReplacePlaceHolder(
            Text      => $GetParam{EmailBody},
            Data      => {},
            RichText  => $Self->{ConfigObject}->Get('Frontend::RichText'),
            UserID    => $Param{UserID},
            TicketID  => $Param{TicketID},
            WhiteList => $Config->{PlaceholderWhitelist} || ''
        );

        my $MimeType = 'text/plain';
        if ( $Self->{LayoutObject}->{BrowserRichText} ) {
            $MimeType = 'text/html';

            # verify html document
            $GetParam{'EmailBody'} = $Self->{LayoutObject}->RichTextDocumentComplete(
                String => $GetParam{'EmailBody'},
            );
        }

        # get customer email address
        my $Customer;
        if ( $Ticket{CustomerUserID} ) {
            my %Customer = $Self->{CustomerUserObject}->CustomerUserDataGet(
                User => $Ticket{CustomerUserID}
            );
            if ( $Customer{UserEmail} ) {
                $Customer = $Customer{UserEmail};
            }
        }

        # check if we have an address, otherwise deduct it from the articles
        if ( !$Customer ) {
            my %Data = $Self->{TicketObject}->ArticleLastCustomerArticle(
                TicketID      => $Param{TicketID},
                DynamicFields => 0,
            );

            # use ReplyTo if set, otherwise use From
            $Customer = $Data{ReplyTo} ? $Data{ReplyTo} : $Data{From};

            # check article type and replace To with From (in case)
            if ( $Data{SenderType} !~ /customer/ ) {

                # replace From/To, To/From because sender is agent
                $Customer = $Data{To};
            }

        }

        # get template generator object
        my $TemplateGeneratorObject = $Kernel::OM->ObjectParamAdd(
            'Kernel::System::TemplateGenerator' => {
                CustomerUserObject => $Self->{CustomerUserObject},
                }
        );

        $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

        # generate sender name
        my $From = $TemplateGeneratorObject->Sender(
            QueueID => $Ticket{QueueID},
            UserID  => $Param{UserID},
        );

        # generate subject
        my $TicketNumber = $Self->{TicketObject}->TicketNumberLookup( TicketID => $Param{TicketID} );

        my $EmailSubject = $Self->{TicketObject}->TicketSubjectBuild(
            TicketNumber => $TicketNumber,
            Subject      => $GetParam{EmailSubject} || '',
        );

        $EmailArticleID = $Self->{TicketObject}->ArticleSend(
            TicketID       => $Param{TicketID},
            ArticleType    => 'email-external',
            SenderType     => 'agent',
            From           => $From,
            To             => $Customer,
            Subject        => $EmailSubject,
            Body           => $GetParam{EmailBody},
            MimeType       => $MimeType,
            Charset        => $Self->{LayoutObject}->{UserCharset},
            UserID         => $Param{UserID},
            HistoryType    => 'SendAnswer',
            HistoryComment => '%%' . $Customer . ' (To)',
        );
    }

    # add note
    my $ArticleID;
    if (
        $GetParam{'Subject'}
        && $GetParam{'Body'}
        && ( $GetParam{'ArticleTypeID'} || $GetParam{'ArticleType'} )
    ) {

        $GetParam{Subject} = $Self->_ReplacePlaceHolder(
            Text      => $GetParam{Subject},
            Data      => {},
            RichText  => 0,
            UserID    => $Param{UserID},
            TicketID  => $Param{TicketID},
            Frontend  => 'Agent',
            WhiteList => $Config->{PlaceholderWhitelist} || ''
        );
        $GetParam{Body} = $Self->_ReplacePlaceHolder(
            Text      => $GetParam{Body},
            Data      => {},
            RichText  => $Self->{ConfigObject}->Get('Frontend::RichText'),
            UserID    => $Param{UserID},
            TicketID  => $Param{TicketID},
            Frontend  => 'Agent',
            WhiteList => $Config->{PlaceholderWhitelist} || ''
        );

        my $MimeType = 'text/plain';
        if ( $Self->{LayoutObject}->{BrowserRichText} ) {
            $MimeType = 'text/html';

            # verify html document
            $GetParam{'Body'} = $Self->{LayoutObject}->RichTextDocumentComplete(
                String => $GetParam{'Body'},
            );
        }
        $ArticleID = $Self->{TicketObject}->ArticleCreate(
            TicketID       => $Param{TicketID},
            ArticleTypeID  => $GetParam{'ArticleTypeID'},
            ArticleType    => $GetParam{'ArticleType'},
            SenderType     => 'agent',
            From           => "$Param{UserFirstname} $Param{UserLastname} <$Param{UserEmail}>",
            Subject        => $GetParam{'Subject'},
            Body           => $GetParam{'Body'},
            MimeType       => $MimeType,
            Charset        => $Self->{LayoutObject}->{UserCharset},
            UserID         => $Param{UserID},
            HistoryType    => 'AddNote',
            HistoryComment => '%%Bulk',
        );
    }

    # set state
    if ( $Config->{State} && ( $GetParam{'StateID'} || $GetParam{'State'} ) ) {
        $Self->{TicketObject}->TicketStateSet(
            TicketID => $Param{TicketID},
            StateID  => $GetParam{'StateID'},
            State    => $GetParam{'State'},
            UserID   => $Param{UserID},
        );
        my %UpdatedTicket = $Self->{TicketObject}->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );
        my %StateData = $Self->{StateObject}->StateGet(
            ID => $UpdatedTicket{StateID},
        );

        # should i set the pending date?
        if ( $UpdatedTicket{StateType} =~ /^pending/i ) {

            # set pending time
            $Self->{TicketObject}->TicketPendingTimeSet(
                %Time,
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }

        # should I set an unlock?
        if ( $UpdatedTicket{StateType} =~ /^close/i ) {
            $Self->{TicketObject}->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'unlock',
                UserID   => $Param{UserID},
            );
        }
    }

    # time units for note
    if ( $GetParam{TimeUnits} && $ArticleID ) {
        if ( $Self->{ConfigObject}->Get('Ticket::Frontend::BulkAccountedTime') ) {
            $Self->{TicketObject}->TicketAccountTime(
                TicketID  => $Param{TicketID},
                ArticleID => $ArticleID,
                TimeUnit  => $GetParam{'TimeUnits'},
                UserID    => $Param{UserID},
            );
        }
        elsif (
            !$Self->{ConfigObject}->Get('Ticket::Frontend::BulkAccountedTime')
            && $Param{Counter} == 1
        ) {
            $Self->{TicketObject}->TicketAccountTime(
                TicketID  => $Param{TicketID},
                ArticleID => $ArticleID,
                TimeUnit  => $GetParam{'TimeUnits'},
                UserID    => $Param{UserID},
            );
        }
    }

    # time units for email
    if ( $GetParam{EmailTimeUnits} && $EmailArticleID ) {
        if ( $Self->{ConfigObject}->Get('Ticket::Frontend::BulkAccountedTime') ) {
            $Self->{TicketObject}->TicketAccountTime(
                TicketID  => $Param{TicketID},
                ArticleID => $EmailArticleID,
                TimeUnit  => $GetParam{'EmailTimeUnits'},
                UserID    => $Param{UserID},
            );
        }
        elsif (
            !$Self->{ConfigObject}->Get('Ticket::Frontend::BulkAccountedTime')
            && $Param{Counter} == 1
        ) {
            $Self->{TicketObject}->TicketAccountTime(
                TicketID  => $Param{TicketID},
                ArticleID => $EmailArticleID,
                TimeUnit  => $GetParam{'EmailTimeUnits'},
                UserID    => $Param{UserID},
            );
        }
    }

    # merge
    if ( $Param{MainTicketID} && $Param{MainTicketID} ne $Param{TicketID} ) {
        $Self->{TicketObject}->TicketMerge(
            MainTicketID  => $Param{MainTicketID},
            MergeTicketID => $Param{TicketID},
            UserID        => $Param{UserID},
        );
    }

    # get link object
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # link all tickets to a parent
    if ( $GetParam{'LinkTogetherParent'} ) {
        my $MainTicketID = $Self->{TicketObject}->TicketIDLookup(
            TicketNumber => $GetParam{'LinkTogetherParent'},
        );

        for my $TicketIDPartner (@TicketIDs) {
            if ( $MainTicketID ne $Param{TicketID} ) {
                # remove links of same link group
                $Self->_PrepareLinkAdd(
                    SourceObject => 'Ticket',
                    SourceKey    => $MainTicketID,
                    TargetObject => 'Ticket',
                    TargetKey    => $Param{TicketID},
                    Type         => 'ParentChild',
                    State        => 'Valid',
                    UserID       => $Param{UserID},
                );

                # add link
                $LinkObject->LinkAdd(
                    SourceObject => 'Ticket',
                    SourceKey    => $MainTicketID,
                    TargetObject => 'Ticket',
                    TargetKey    => $Param{TicketID},
                    Type         => 'ParentChild',
                    State        => 'Valid',
                    UserID       => $Param{UserID},
                );
            }
        }
    }

    # link together
    if ( $GetParam{'LinkTogether'} ) {
        for my $TicketIDPartner (@TicketIDs) {
            if ( $Param{TicketID} ne $TicketIDPartner ) {
                # remove links of same link group
                $Self->_PrepareLinkAdd(
                    SourceObject => 'Ticket',
                    SourceKey    => $Param{TicketID},
                    TargetObject => 'Ticket',
                    TargetKey    => $TicketIDPartner,
                    Type         => 'Normal',
                    State        => 'Valid',
                    UserID       => $Param{UserID},
                );

                # add link
                $LinkObject->LinkAdd(
                    SourceObject => 'Ticket',
                    SourceKey    => $Param{TicketID},
                    TargetObject => 'Ticket',
                    TargetKey    => $TicketIDPartner,
                    Type         => 'Normal',
                    State        => 'Valid',
                    UserID       => $Param{UserID},
                );
            }
        }
    }

    # should I unlock tickets at user request?
    if ( $GetParam{'Unlock'} ) {
        $Self->{TicketObject}->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'unlock',
            UserID   => $Param{UserID},
        );
    }

    # call Store() in all ticket bulk modules
    if (@BulkModules) {

        MODULEOBJECT:
        for my $ModuleObject (@BulkModules) {
            next MODULEOBJECT if !$ModuleObject->can('Store');

            $ModuleObject->Store(
                TicketID => $Param{TicketID},
                UserID   => $Param{UserID},
            );
        }
    }

    return {
        Success     => 1,
        ReSchedule  => 0,
    };
}

sub _BulkCancel {
    my ( $Self, %Param ) = @_;

    my $FormID  = $Param{FormID}.'.'.$Param{Action}.'.'.$Param{UserID};
    my $Success = 1;
    my $Access  = $Self->{TicketObject}->TicketPermission(
        Type     => 'lock',
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        return $Self->{LayoutObject}->NoPermission( WithHeader => 'yes' );
    }

    # set unlock
    my $Lock = $Self->{TicketObject}->TicketLockSet(
        TicketID => $Param{TicketID},
        Lock     => 'unlock',
        UserID   => $Param{UserID},
    );
    if ( !$Lock ) {
        my $FileID = $Self->{UploadCacheObject}->FormIDAddFile(
            FormID      => $FormID,
            Filename    => 'CancelError_' . $Param{TicketID},
            Content     => $Param{TicketID},
            ContentType => 'text/xml',
        );

        $Success = 0;
    }

    return {
        Success     => $Success,
        ReSchedule  => 0,
    }
}

=item AsyncCall()

creates a scheduler daemon task to execute a function asynchronously.

    my $Success = $Object->AsyncCall(
        ObjectName               => 'Kernel::System::Ticket',   # optional, if not given the object is used from where
                                                                # this function was called
        FunctionName             => 'MyFunction',               # the name of the function to execute
        FunctionParams           => \%MyParams,                 # a ref with the required parameters for the function
        Attempts                 => 3,                          # optional, default: 1, number of tries to lock the
                                                                #   task by the scheduler
        MaximumParallelInstances => 1,                          # optional, default: 0 (unlimited), number of same
                                                                #   function calls form the same object that can be
                                                                #   executed at the the same time
    );

Returns:

    $Success = 1;  # of false in case of an error

=cut

sub AsyncCall {
    my ( $Self, %Param ) = @_;

    my $FunctionName = $Param{FunctionName};

    if ( !IsStringWithData($FunctionName) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Function needs to be a non empty string!",
        );
        return;
    }

    my $ObjectName = $Param{ObjectName} || ref $Self;

    # create a new object
    my $LocalObject;
    eval {
        $LocalObject = $Kernel::OM->Get($ObjectName);
    };

    # check if is possible to create the object
    if ( !$LocalObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not create $ObjectName object!",
        );

        return;
    }

    # check if object reference is the same as expected
    if ( ref $LocalObject ne $ObjectName ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$ObjectName object is not valid!",
        );
        return;
    }

    # check if the object can execute the function
    if ( !$LocalObject->can($FunctionName) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$ObjectName can not execute $FunctionName()!",
        );
        return;
    }

    if ( $Param{FunctionParams} && !ref $Param{FunctionParams} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "FunctionParams needs to be a hash or list reference.",
        );
        return;
    }

    # create a new task
    my $TaskID = $Kernel::OM->Get('Kernel::System::Scheduler')->TaskAdd(
        Type                     => 'AsynchronousExecutor',
        Name                     => $Param{TaskName},
        Attempts                 => $Param{Attempts} || 1,
        MaximumParallelInstances => $Param{MaximumParallelInstances} || 0,
        Data                     => {
            Object   => $ObjectName,
            Function => $FunctionName,
            Params   => $Param{FunctionParams} // {},
        },
    );

    if ( !$TaskID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not create new AsynchronousExecutor: '$Param{TaskName}' task!",
        );
        return;
    }

    return 1;
}

sub _PrepareLinkAdd {
    my ( $Self, %Param ) = @_;

    # get link object
    my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');

    # get all links that the source object already has
    my $Links = $LinkObject->LinkList(
        Object => $Param{SourceObject},
        Key    => $Param{SourceKey},
        State  => $Param{State},
        UserID => $Param{UserID},
    );

    # check type groups
    OBJECT:
    for my $Object ( sort keys %{$Links} ) {

        next OBJECT if $Object ne $Param{TargetObject};

        TYPE:
        for my $Type ( sort keys %{ $Links->{$Object} } ) {

            # extract source and target
            my $Source = $Links->{$Object}->{$Type}->{Source} ||= {};
            my $Target = $Links->{$Object}->{$Type}->{Target} ||= {};

            # check if source and target object are already linked
            next TYPE if !$Source->{ $Param{TargetKey} } && !$Target->{ $Param{TargetKey} };

            # check the type groups
            my $TypeGroupCheck = $LinkObject->PossibleType(
                Type1 => $Type,
                Type2 => $Param{Type},
            );

            next TYPE if $TypeGroupCheck;

            # remove if existing link type is in a type group with the new link
            my $Success = $LinkObject->LinkDelete(
                Object1 => $Param{SourceObject},
                Key1    => $Param{SourceKey},
                Object2 => $Param{TargetObject},
                Key2    => $Param{TargetKey},
                Type    => $Type,
                UserID  => $Param{UserID},
            );
        }
    }

    return;
}

sub _ReplacePlaceHolder {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text RichText)) {
        if ( !defined $Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Text = $Param{Text};
    $Text =~ s{OTRS_}{KIX_}g;

    my $Start = '<';
    my $End   = '>';
    if ( $Param{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Text =~ s/(\n|\r)//g;
    }

    if ( !$Param{WhiteList} ) {
        my $Tag = $Start . 'KIX_.*' . $End;
        $Text =~ s/$Tag/-/;
    }
    else {
        my $Tag     = $Start . 'KIX_.*?' . $End;
        my @Matches = $Text =~ /($Tag)/gm;

        if ( scalar(@Matches) ){
            my %Matchlist = map{ $_ => 0 } @Matches;

            for my $Match ( sort keys %Matchlist ) {
                for my $Prio ( sort keys %{$Param{WhiteList}} ) {
                    my $TagPattern = $Start . 'KIX_' . $Param{WhiteList}->{$Prio} . $End;
                    if ( $Match =~ /$TagPattern/ ) {
                        $Matchlist{$Match}++;
                    }
                }
            }

            for my $Match ( sort keys %Matchlist ) {
                next if $Matchlist{$Match};

                $Text =~ s/$Match/-/;
            }

            $Text = $Self->{TemplateGeneratorObject}->ReplacePlaceHolder(
                %Param,
                Text => $Text
            );
        }
    }

    return $Text;
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
