# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::FollowUp;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID InmailUserID GetParam Tn AutoResponseType)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    my %GetParam = %{ $Param{GetParam} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    my $Comment          = $Param{Comment}          || '';
    my $Lock             = $Param{Lock}             || '';
    my $AutoResponseType = $Param{AutoResponseType} || '';

    # Check if owner of ticket is still valid
    my %UserInfo = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Ticket{OwnerID},
    );

    # 1) check user, out of office, unlock ticket
    if ( $UserInfo{OutOfOfficeMessage} ) {
        $TicketObject->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'unlock',
            UserID   => $Param{InmailUserID},
        );
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Ticket [$Param{Tn}] unlocked, current owner is out of office!",
        );
    }

    # 2) check user, just lock it if user is valid and ticket was closed
    elsif ( $UserInfo{ValidID} eq "1" ) {

        # set lock (if ticket should be locked on follow up)
        if ( $Lock && $Ticket{StateType} =~ /^close/i ) {
            $TicketObject->TicketLockSet(
                TicketID => $Param{TicketID},
                Lock     => 'lock',
                UserID   => $Param{InmailUserID},
            );
            if ( $Self->{Debug} > 0 ) {
                print "Lock: lock\n";
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "Ticket [$Param{Tn}] still locked",
                );
            }
        }
    }

    # 3) Unlock ticket, because current user is set to invalid
    else {
        $TicketObject->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'unlock',
            UserID   => $Param{InmailUserID},
        );
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Ticket [$Param{Tn}] unlocked, current owner is invalid!",
        );
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # set state
    my $NextStateRef = $ConfigObject->Get('TicketStateWorkflow::PostmasterFollowUpState');
    my $State        = '';

    if (
        $NextStateRef->{ $Ticket{Type} . ':::' . $Ticket{State} }
        || $NextStateRef->{ $Ticket{State} }
    ) {
        $State = $NextStateRef->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $NextStateRef->{ $Ticket{State} }
            || $NextStateRef->{''};
    }

    if ( $GetParam{'X-KIX-FollowUp-State'} || $GetParam{'X-OTRS-FollowUp-State'} ) {
        $State = $GetParam{'X-KIX-FollowUp-State'} || $GetParam{'X-OTRS-FollowUp-State'};
    }

    if ($State) {
        $TicketObject->TicketStateSet(
            State    => $State,
            TicketID => $Param{TicketID},
            UserID   => $Param{InmailUserID},
        );
        if ( $Self->{Debug} > 0 ) {
            print "State: $State\n";
        }
    }

    # set pending time
    if ( $GetParam{'X-KIX-FollowUp-State-PendingTime'} || $GetParam{'X-OTRS-FollowUp-State-PendingTime'} ) {

  # You can specify absolute dates like "2010-11-20 00:00:00" or relative dates, based on the arrival time of the email.
  # Use the form "+ $Number $Unit", where $Unit can be 's' (seconds), 'm' (minutes), 'h' (hours) or 'd' (days).
  # Only one unit can be specified. Examples of valid settings: "+50s" (pending in 50 seconds), "+30m" (30 minutes),
  # "+12d" (12 days). Note that settings like "+1d 12h" are not possible. You can specify "+36h" instead.

        my $TargetTimeStamp = $GetParam{'X-KIX-FollowUp-State-PendingTime'} || $GetParam{'X-OTRS-FollowUp-State-PendingTime'};

        my ( $Sign, $Number, $Unit ) = $TargetTimeStamp =~ m{^\s*([+-]?)\s*(\d+)\s*([smhd]?)\s*$}smx;

        if ($Number) {
            $Sign ||= '+';
            $Unit ||= 's';

            my $Seconds = $Sign eq '-' ? ( $Number * -1 ) : $Number;

            my %UnitMultiplier = (
                s => 1,
                m => 60,
                h => 60 * 60,
                d => 60 * 60 * 24,
            );

            $Seconds = $Seconds * $UnitMultiplier{$Unit};

            # get time object
            my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

            $TargetTimeStamp = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $TimeObject->SystemTime() + $Seconds,
            );
        }

        my $Updated = $TicketObject->TicketPendingTimeSet(
            String   => $TargetTimeStamp,
            TicketID => $Param{TicketID},
            UserID   => $Param{InmailUserID},
        );

        # debug
        if ($Updated) {
            if ( $Self->{Debug} > 0 ) {
                print "State-PendingTime: ".($GetParam{'X-OTRS-FollowUp-State-PendingTime'} || $GetParam{'X-OTRS-FollowUp-State-PendingTime'})."\n";
            }
        }
    }

    # set priority
    if ( $GetParam{'X-KIX-FollowUp-Priority'} || $GetParam{'X-OTRS-FollowUp-Priority'} ) {
        $TicketObject->TicketPrioritySet(
            TicketID => $Param{TicketID},
            Priority => $GetParam{'X-KIX-FollowUp-Priority'} || $GetParam{'X-OTRS-FollowUp-Priority'},
            UserID   => $Param{InmailUserID},
        );
        if ( $Self->{Debug} > 0 ) {
            print "PriorityUpdate: ".($GetParam{'X-KIX-FollowUp-Priority'} || $GetParam{'X-OTRS-FollowUp-Priority'})."\n";
        }
    }

    # set queue
    if ( $GetParam{'X-KIX-FollowUp-Queue'} || $GetParam{'X-OTRS-FollowUp-Queue'} ) {
        $TicketObject->TicketQueueSet(
            Queue    => $GetParam{'X-KIX-FollowUp-Queue'} || $GetParam{'X-OTRS-FollowUp-Queue'},
            TicketID => $Param{TicketID},
            UserID   => $Param{InmailUserID},
        );
        if ( $Self->{Debug} > 0 ) {
            print "QueueUpdate: ".($GetParam{'X-KIX-FollowUp-Queue'} || $GetParam{'X-OTRS-FollowUp-Queue'})."\n";
        }
    }

    # set lock
    if ( $GetParam{'X-KIX-FollowUp-Lock'} || $GetParam{'X-OTRS-FollowUp-Lock'} ) {
        $TicketObject->TicketLockSet(
            Lock     => $GetParam{'X-KIX-FollowUp-Lock'} || $GetParam{'X-OTRS-FollowUp-Lock'},
            TicketID => $Param{TicketID},
            UserID   => $Param{InmailUserID},
        );
        if ( $Self->{Debug} > 0 ) {
            print "Lock: ".($GetParam{'X-KIX-FollowUp-Lock'} || $GetParam{'X-OTRS-FollowUp-Lock'})."\n";
        }
    }

    # set ticket type
    if ( $GetParam{'X-KIX-FollowUp-Type'} || $GetParam{'X-OTRS-FollowUp-Type'} ) {
        $TicketObject->TicketTypeSet(
            Type     => $GetParam{'X-KIX-FollowUp-Type'} || $GetParam{'X-OTRS-FollowUp-Type'},
            TicketID => $Param{TicketID},
            UserID   => $Param{InmailUserID},
        );
        if ( $Self->{Debug} > 0 ) {
            print "Type: ".($GetParam{'X-KIX-FollowUp-Type'} || $GetParam{'X-OTRS-FollowUp-Type'})."\n";
        }
    }

    # set ticket service
    if ( $GetParam{'X-KIX-FollowUp-Service'} || $GetParam{'X-OTRS-FollowUp-Service'} ) {
        $TicketObject->TicketServiceSet(
            Service  => $GetParam{'X-KIX-FollowUp-Service'} || $GetParam{'X-OTRS-FollowUp-Service'},
            TicketID => $Param{TicketID},
            UserID   => $Param{InmailUserID},
        );
        if ( $Self->{Debug} > 0 ) {
            print "Service: ".($GetParam{'X-KIX-FollowUp-Service'} || $GetParam{'X-OTRS-FollowUp-Service'})."\n";
        }
    }

    # set ticket sla
    if ( $GetParam{'X-KIX-FollowUp-SLA'} || $GetParam{'X-OTRS-FollowUp-SLA'} ) {
        $TicketObject->TicketSLASet(
            SLA      => $GetParam{'X-KIX-FollowUp-SLA'} || $GetParam{'X-OTRS-FollowUp-SLA'},
            TicketID => $Param{TicketID},
            UserID   => $Param{InmailUserID},
        );
        if ( $Self->{Debug} > 0 ) {
            print "SLA: ".($GetParam{'X-KIX-FollowUp-SLA'} || $GetParam{'X-OTRS-FollowUp-SLA'})."\n";
        }
    }

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # dynamic fields
    my $DynamicFieldList =
        $DynamicFieldObject->DynamicFieldList(
        Valid      => 1,
        ResultType => 'HASH',
        ObjectType => 'Ticket',
        );

    # set dynamic fields for Ticket object type
    DYNAMICFIELDID:
    for my $DynamicFieldID ( sort keys %{$DynamicFieldList} ) {
        next DYNAMICFIELDID if !$DynamicFieldID;
        next DYNAMICFIELDID if !$DynamicFieldList->{$DynamicFieldID};
        my $Key = 'X-KIX-FollowUp-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        if ( !defined $GetParam{$Key} || !length $GetParam{$Key} ) {
            # fallback
            $Key = 'X-OTRS-FollowUp-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        }

        if (defined $GetParam{$Key} && length $GetParam{$Key}) {
            # get dynamic field config
            my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                ID => $DynamicFieldID,
            );

            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldGet,
                ObjectID           => $Param{TicketID},
                Value              => $GetParam{$Key},
                UserID             => $Param{InmailUserID},
            );

            if ( $Self->{Debug} > 0 ) {
                print "$Key: " . $GetParam{$Key} . "\n";
            }
        }
    }

    # reverse dynamic field list
    my %DynamicFieldListReversed = reverse %{$DynamicFieldList};

    # set ticket free text
    my %Values = (
        'X-KIX-FollowUp-TicketKey'   => 'TicketFreeKey',
        'X-KIX-FollowUp-TicketValue' => 'TicketFreeText',
        'X-OTRS-FollowUp-TicketKey'   => 'TicketFreeKey',
        'X-OTRS-FollowUp-TicketValue' => 'TicketFreeText',
    );
    for my $Item ( sort keys %Values ) {
        for my $Count ( 1 .. 16 ) {
            my $Key = $Item . $Count;
            if (
                defined $GetParam{$Key}
                && length $GetParam{$Key}
                && $DynamicFieldListReversed{ $Values{$Item} . $Count }
            ) {
                # get dynamic field config
                my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldListReversed{ $Values{$Item} . $Count },
                );
                if ($DynamicFieldGet) {
                    my $Success = $DynamicFieldBackendObject->ValueSet(
                        DynamicFieldConfig => $DynamicFieldGet,
                        ObjectID           => $Param{TicketID},
                        Value              => $GetParam{$Key},
                        UserID             => $Param{InmailUserID},
                    );
                }

                if ( $Self->{Debug} > 0 ) {
                    print "TicketKey$Count: " . $GetParam{$Key} . "\n";
                }
            }
        }
    }

    # set ticket free time
    for my $Count ( 1 .. 6 ) {
        my $Key = 'X-KIX-FollowUp-TicketTime' . $Count;
        if ( !defined $GetParam{$Key} || !length $GetParam{$Key} ) {
            # fallback
            $Key = 'X-OTRS-FollowUp-TicketTime' . $Count;
        }

        if ( defined $GetParam{$Key} && length $GetParam{$Key} ) {

            # get time object
            my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

            my $SystemTime = $TimeObject->TimeStamp2SystemTime(
                String => $GetParam{$Key},
            );

            if ( $SystemTime && $DynamicFieldListReversed{ 'TicketFreeTime' . $Count } ) {

                # get dynamic field config
                my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldListReversed{ 'TicketFreeTime' . $Count },
                );

                if ($DynamicFieldGet) {
                    my $Success = $DynamicFieldBackendObject->ValueSet(
                        DynamicFieldConfig => $DynamicFieldGet,
                        ObjectID           => $Param{TicketID},
                        Value              => $GetParam{$Key},
                        UserID             => $Param{InmailUserID},
                    );
                }

                if ( $Self->{Debug} > 0 ) {
                    print "TicketTime$Count: " . $GetParam{$Key} . "\n";
                }
            }
        }
    }

    # apply stricter methods to set article-type and -sender.
    my @SplitFrom = grep {/.+@.+/} split( /[<>,"\s\/\\()\[\]\{\}]/, $GetParam{From} );

    # check if email-from is a valid agent...
    if ( $ConfigObject->Get('TicketStateWorkflow::PostmasterFollowUpCheckAgentFrom') ) {
        for my $FromAddress (@SplitFrom) {
            my $UserObject = $Kernel::OM->Get('Kernel::System::User');
            my %UserData = $UserObject->UserSearch(
                PostMasterSearch => $FromAddress,
                ValidID          => 1,
            );

            for my $CurrUserID ( keys(%UserData) ) {
                if ( $UserData{$CurrUserID} =~ /^$FromAddress$/i ) {
                    $GetParam{'X-KIX-FollowUp-SenderType'} = 'agent';
                    last;
                }
            }

            last if ( $GetParam{'X-KIX-FollowUp-SenderType'} eq 'agent' );
        }
    }

    # check if from is known customer AND has the same customerID as in Ticket, if article type is not already set
    if (
        $ConfigObject->Get('TicketStateWorkflow::PostmasterFollowUpCheckCustomerIDFrom')
        && !$GetParam{'X-KIX-FollowUp-ArticleType'}
        && !$GetParam{'X-OTRS-FollowUp-ArticleType'}
    ) {
        $GetParam{'X-KIX-FollowUp-ArticleType'} = 'email-internal';
        for my $FromAddress (@SplitFrom) {
            my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
            my %UserListCustomer = $CustomerUserObject->CustomerSearch(
                PostMasterSearch => $FromAddress,
            );

            if (keys %UserListCustomer) {
                for my $CurrKey ( keys(%UserListCustomer) ) {
                    my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
                        User => $CurrKey,
                    );
                    if (
                        $CustomerUserData{UserCustomerID}
                        && $Ticket{CustomerID}
                        && $Ticket{CustomerID} eq $CustomerUserData{UserCustomerID}
                    ) {
                        $GetParam{'X-KIX-FollowUp-ArticleType'} = 'email-external';
                        last;
                    }
                }
            }
            # seems to be a customer user not existing in the database -> check if this one is identical to Ticket{CustomerUserID}
            elsif ($FromAddress && $Ticket{CustomerUserID} && $Ticket{CustomerUserID} eq $FromAddress) {
                $GetParam{'X-KIX-FollowUp-ArticleType'} = 'email-external';
                last;
            }

            last if ( $GetParam{'X-KIX-FollowUp-ArticleType'} eq 'email-external' );
        }
    }

    # do db insert
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID         => $Param{TicketID},
        ArticleType      => $GetParam{'X-KIX-FollowUp-ArticleType'} || $GetParam{'X-OTRS-FollowUp-ArticleType'} || 'email-external',
        SenderType       => $GetParam{'X-KIX-FollowUp-SenderType'} || $GetParam{'X-OTRS-FollowUp-SenderType'},
        From             => $GetParam{From},
        ReplyTo          => $GetParam{ReplyTo},
        To               => $GetParam{To},
        Cc               => $GetParam{Cc},
        Subject          => $GetParam{Subject},
        MessageID        => $GetParam{'Message-ID'},
        InReplyTo        => $GetParam{'In-Reply-To'},
        References       => $GetParam{'References'},
        ContentType      => $GetParam{'Content-Type'},
        Body             => $GetParam{Body},
        UserID           => $Param{InmailUserID},
        HistoryType      => 'FollowUp',
        HistoryComment   => "\%\%$Param{Tn}\%\%$Comment",
        AutoResponseType => $AutoResponseType,
        OrigHeader       => \%GetParam,
    );
    return if !$ArticleID;

    # debug
    if ( $Self->{Debug} > 0 ) {
        print "Follow up Ticket\n";
        ATTRIBUTE:
        for my $Attribute ( sort keys %GetParam ) {
            next ATTRIBUTE if !$GetParam{$Attribute};
            print "$Attribute: $GetParam{$Attribute}\n";
        }
    }

    # write plain email to the storage
    $TicketObject->ArticleWritePlain(
        ArticleID => $ArticleID,
        Email     => $Self->{ParserObject}->GetPlainEmail(),
        UserID    => $Param{InmailUserID},
    );

    # write attachments to the storage
    for my $Attachment ( $Self->{ParserObject}->GetAttachments() ) {
        $TicketObject->ArticleWriteAttachment(
            Filename           => $Attachment->{Filename},
            Content            => $Attachment->{Content},
            ContentType        => $Attachment->{ContentType},
            ContentID          => $Attachment->{ContentID},
            ContentAlternative => $Attachment->{ContentAlternative},
            Disposition        => $Attachment->{Disposition},
            ArticleID          => $ArticleID,
            UserID             => $Param{InmailUserID},
        );
    }

    # dynamic fields
    $DynamicFieldList =
        $DynamicFieldObject->DynamicFieldList(
        Valid      => 1,
        ResultType => 'HASH',
        ObjectType => 'Article'
        );

    # set dynamic fields for Article object type
    DYNAMICFIELDID:
    for my $DynamicFieldID ( sort keys %{$DynamicFieldList} ) {
        next DYNAMICFIELDID if !$DynamicFieldID;
        next DYNAMICFIELDID if !$DynamicFieldList->{$DynamicFieldID};

        my $Key = 'X-KIX-FollowUp-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        if ( !defined $GetParam{$Key} || !length $GetParam{$Key} ) {
            # fallback
            $Key = 'X-OTRS-FollowUp-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        }

        if ( defined $GetParam{$Key} && length $GetParam{$Key} ) {
            # get dynamic field config
            my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                ID => $DynamicFieldID,
            );

            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldGet,
                ObjectID           => $ArticleID,
                Value              => $GetParam{$Key},
                UserID             => $Param{InmailUserID},
            );

            if ( $Self->{Debug} > 0 ) {
                print "$Key: " . $GetParam{$Key} . "\n";
            }
        }
    }

    # reverse dynamic field list
    %DynamicFieldListReversed = reverse %{$DynamicFieldList};

    # set free article text
    %Values = (
        'X-KIX-FollowUp-ArticleKey'   => 'ArticleFreeKey',
        'X-KIX-FollowUp-ArticleValue' => 'ArticleFreeText',
        'X-OTRS-FollowUp-ArticleKey'   => 'ArticleFreeKey',
        'X-OTRS-FollowUp-ArticleValue' => 'ArticleFreeText',
    );
    for my $Item ( sort keys %Values ) {
        for my $Count ( 1 .. 16 ) {
            my $Key = $Item . $Count;
            if (
                defined $GetParam{$Key}
                && length $GetParam{$Key}
                && $DynamicFieldListReversed{ $Values{$Item} . $Count }
            ) {
                # get dynamic field config
                my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldListReversed{ $Values{$Item} . $Count },
                );
                if ($DynamicFieldGet) {
                    my $Success = $DynamicFieldBackendObject->ValueSet(
                        DynamicFieldConfig => $DynamicFieldGet,
                        ObjectID           => $ArticleID,
                        Value              => $GetParam{$Key},
                        UserID             => $Param{InmailUserID},
                    );
                }

                if ( $Self->{Debug} > 0 ) {
                    print "TicketKey$Count: " . $GetParam{$Key} . "\n";
                }
            }
        }
    }

    # write log
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => "FollowUp Article to Ticket [$Param{Tn}] created "
            . "(TicketID=$Param{TicketID}, ArticleID=$ArticleID). $Comment,"
    );

    return 1;
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
