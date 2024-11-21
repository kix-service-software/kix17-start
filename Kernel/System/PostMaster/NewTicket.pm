# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::NewTicket;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::HTMLUtils',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::Service',
    'Kernel::System::SLA',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::Type',
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
    for my $Needed (qw(InmailUserID GetParam)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    my %GetParam         = %{ $Param{GetParam} };
    my $Comment          = $Param{Comment} || '';
    my $AutoResponseType = $Param{AutoResponseType} || '';

    # get ticket template
    my %TicketTemplate;

    if ( $GetParam{'X-KIX-TicketTemplate'} || $GetParam{'X-OTRS-TicketTemplate'} ) {
        %TicketTemplate = $Kernel::OM->Get('Kernel::System::Ticket')->TicketTemplateGet(
            Name => $GetParam{'X-KIX-TicketTemplate'} || $GetParam{'X-OTRS-TicketTemplate'},
        );
    }

    # get queue id and name
    my $QueueID = $TicketTemplate{QueueID} || $Param{QueueID} || die "need QueueID!";

    # skip new ticket if queue already has message
    if (
        $Param{SkipTicketIDs}
        && ref( $Param{SkipTicketIDs} ) eq 'HASH'
    ) {
        for my $TicketID ( keys( %{ $Param{SkipTicketIDs} } ) ) {
            my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
                TicketID      => $TicketID,
                DynamicFields => 0,
                UserID        => 1,
            );
            if (
                %Ticket
                && $Ticket{QueueID} eq $QueueID
            ) {
                my $MessageID = $GetParam{'Message-ID'};

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "New ticket, but message id already exists in queue ($MessageID). New ticket is skipped."
                );
                return ( 6, $TicketID );
            }
        }
    }

    my $Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
        QueueID => $QueueID,
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get state
    my $State;
    if ( defined $TicketTemplate{StateID} ) {
        $State = $Kernel::OM->Get('Kernel::System::State')
            ->StateLookup( StateID => $TicketTemplate{StateID} );
    }
    else {
        $State = $ConfigObject->Get('PostmasterDefaultState') || 'new';
    }

    if ( $GetParam{'X-KIX-State'} || $GetParam{'X-OTRS-State'} ) {

        my $StateID = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
            State => $GetParam{'X-KIX-State'} || $GetParam{'X-OTRS-State'},
        );

        if ($StateID) {
            $State = $GetParam{'X-KIX-State'} || $GetParam{'X-OTRS-State'};
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "State "
                    . ( $GetParam{'X-KIX-State'} || $GetParam{'X-OTRS-State'} )
                    . " does not exist, falling back to $State!"
            );
        }
    }

    # get priority
    my $Priority;
    if ( defined $TicketTemplate{PriorityID} ) {
        $Priority
            = $Kernel::OM->Get('Kernel::System::Priority')
            ->PriorityLookup( PriorityID => $TicketTemplate{PriorityID} );
    }
    else {
        $Priority = $ConfigObject->Get('PostmasterDefaultPriority') || '3 normal';
    }

    if ( $GetParam{'X-KIX-Priority'} || $GetParam{'X-OTRS-Priority'} ) {

        my $PriorityID = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
            Priority => $GetParam{'X-KIX-Priority'} || $GetParam{'X-OTRS-Priority'},
        );

        if ($PriorityID) {
            $Priority = $GetParam{'X-KIX-Priority'} || $GetParam{'X-OTRS-Priority'};
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "Priority "
                    . ( $GetParam{'X-KIX-Priority'} || $GetParam{'X-OTRS-Priority'} )
                    . " does not exist, falling back to $Priority!"
            );
        }
    }

    my $TypeID;

    if ( $GetParam{'X-KIX-Type'} || $GetParam{'X-OTRS-Type'} ) {

        # Check if type exists
        $TypeID = $Kernel::OM->Get('Kernel::System::Type')
            ->TypeLookup( Type => ( $GetParam{'X-KIX-Type'} || $GetParam{'X-OTRS-Type'} ) );

        if ( !$TypeID ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "Type "
                    . ( $GetParam{'X-KIX-Type'} || $GetParam{'X-OTRS-Type'} )
                    . " does not exist, falling back to default type."
            );
        }
    }

    # get sender email
    my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
        Line => $GetParam{'X-KIX-From'} || $GetParam{From},
    );

    for my $Address (@EmailAddresses) {
        $GetParam{SenderEmailAddress} = $Self->{ParserObject}->GetEmailAddress(
            Email => $Address,
        );
    }

    # get customer id (sender email) if there is no customer id given
    if (
        ( !$GetParam{'X-KIX-CustomerNo'} && $GetParam{'X-KIX-CustomerUser'} )
        || ( !$GetParam{'X-OTRS-CustomerNo'} && $GetParam{'X-OTRS-CustomerUser'} )
    ) {

        # get customer user object
        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

        # get customer user data form X-KIX-CustomerUser
        my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
            User => $GetParam{'X-KIX-CustomerUser'} || $GetParam{'X-OTRS-CustomerUser'},
        );

        if (%CustomerData) {
            $GetParam{'X-KIX-CustomerNo'} = $CustomerData{UserCustomerID};
        }
    }

    # get customer user data form From: (sender address)
    if ( !$GetParam{'X-KIX-CustomerUser'} && !$GetParam{'X-OTRS-CustomerUser'} ) {

        my %CustomerData;
        if ( $GetParam{'X-KIX-From'} || $GetParam{From} ) {

            my @EmailAddressesFrom = $Self->{ParserObject}->SplitAddressLine(
                Line => $GetParam{'X-KIX-From'} || $GetParam{From},
            );

            for my $Address (@EmailAddressesFrom) {
                $GetParam{EmailFrom} = $Self->{ParserObject}->GetEmailAddress(
                    Email => $Address,
                );
            }

            if ( $GetParam{EmailFrom} ) {

                # get customer user object
                my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

                my %List = $CustomerUserObject->CustomerSearch(
                    PostMasterSearch => lc( $GetParam{EmailFrom} ),
                );

                for my $UserLogin ( sort keys %List ) {
                    %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                        User => $UserLogin,
                    );
                }
            }
        }

        # take CustomerID from customer backend lookup or from from field
        if (
            $CustomerData{UserLogin}
            && !( $GetParam{'X-KIX-CustomerUser'} || $GetParam{'X-OTRS-CustomerUser'} )
        ) {
            $GetParam{'X-KIX-CustomerUser'} = $CustomerData{UserLogin};

            # notice that UserLogin is from customer source backend
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Take UserLogin ($CustomerData{UserLogin}) from "
                    . "customer source backend based on ($GetParam{'EmailFrom'}).",
            );
        }
        if (
            $CustomerData{UserCustomerID}
            && !( $GetParam{'X-KIX-CustomerNo'} || $GetParam{'X-OTRS-CustomerNo'} )
        ) {
            $GetParam{'X-KIX-CustomerNo'} = $CustomerData{UserCustomerID};

            # notice that UserCustomerID is from customer source backend
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Take UserCustomerID ($CustomerData{UserCustomerID})"
                    . " from customer source backend based on ($GetParam{'EmailFrom'}).",
            );
        }
    }

    # if there is no customer id found
    if (
        !( $GetParam{'X-KIX-CustomerUser'} || $GetParam{'X-OTRS-CustomerUser'} )
        && $TicketTemplate{CustomerLogin}
    ) {
        $GetParam{'X-KIX-CustomerUser'} = $TicketTemplate{CustomerLogin};
    }

    # if there is no customer id found!
    if ( !( $GetParam{'X-KIX-CustomerNo'} || $GetParam{'X-OTRS-CustomerNo'} ) ) {
        $GetParam{'X-KIX-CustomerNo'} = $GetParam{SenderEmailAddress};
    }

    # if there is no customer user found!
    if ( !( $GetParam{'X-KIX-CustomerUser'} || $GetParam{'X-OTRS-CustomerUser'} ) ) {
        $GetParam{'X-KIX-CustomerUser'} = $GetParam{SenderEmailAddress};
    }

    # get ticket owner
    my $OwnerID
        = $GetParam{'X-KIX-OwnerID'}
        || $GetParam{'X-OTRS-OwnerID'}
        || $TicketTemplate{OwnerID}
        || $Param{InmailUserID};

    if ( $GetParam{'X-KIX-Owner'} || $GetParam{'X-OTRS-Owner'} ) {

        my $TmpOwnerID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $GetParam{'X-KIX-Owner'} || $GetParam{'X-OTRS-Owner'},
        );

        $OwnerID = $TmpOwnerID || $OwnerID;
    }

    my %Opts;
    if ( $GetParam{'X-KIX-ResponsibleID'} || $GetParam{'X-OTRS-ResponsibleID'} ) {
        $Opts{ResponsibleID}
            = $GetParam{'X-KIX-ResponsibleID'} || $GetParam{'X-OTRS-ResponsibleID'};
    }

    elsif ( defined $TicketTemplate{ResponsibleID} ) {
        $Opts{ResponsibleID} = $TicketTemplate{ResponsibleID};
    }

    if ( $GetParam{'X-KIX-Responsible'} || $GetParam{'X-OTRS-Responsible'} ) {

        my $TmpResponsibleID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $GetParam{'X-KIX-Responsible'} || $GetParam{'X-OTRS-Responsible'},
        );

        $Opts{ResponsibleID} = $TmpResponsibleID || $Opts{ResponsibleID};
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket type
    my $Type;
    if ( $ConfigObject->Get('Ticket::Type') && defined $TicketTemplate{TypeID} ) {
        $Type = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup( TypeID => $TicketTemplate{TypeID} );
    }

    # get service
    my $Service;
    if ( defined $TicketTemplate{ServiceID} ) {
        $Service = $Kernel::OM->Get('Kernel::System::Service')
            ->ServiceLookup( ServiceID => $TicketTemplate{ServiceID} );
    }

    # get sla
    my $SLA;
    if ( defined $TicketTemplate{SLAID} ) {
        $SLA
            = $Kernel::OM->Get('Kernel::System::SLA')->SLALookup( SLAID => $TicketTemplate{SLAID} );
    }

    # get subject
    my $Subject = $GetParam{Subject};
    if (
        defined $TicketTemplate{Subject}
        && $TicketTemplate{Subject} =~ m/(.*?)<(KIX|OTRS)_EMAIL_SUBJECT>(.*)/g
    ) {
        $Subject = $1 . $Subject . $3;
    }

    # create new ticket
    my $NewTn    = $TicketObject->TicketCreateNumber();
    my $TicketID = $TicketObject->TicketCreate(
        %Opts,
        TN             => $NewTn,
        Title          => $Subject,
        QueueID        => $QueueID || $TicketTemplate{QueueID},
        Lock           => $GetParam{'X-KIX-Lock'} || $GetParam{'X-OTRS-Lock'} || 'unlock',
        Priority       => $Priority,
        State          => $State,
        Type           => $Type    || $GetParam{'X-KIX-Type'}    || $GetParam{'X-OTRS-Type'}    || '',
        Service        => $Service || $GetParam{'X-KIX-Service'} || $GetParam{'X-OTRS-Service'} || '',
        SLA            => $SLA     || $GetParam{'X-KIX-SLA'}     || $GetParam{'X-OTRS-SLA'}     || '',
        TicketTemplate => ( %TicketTemplate && $TicketTemplate{ID} ) ? $TicketTemplate{ID} : '',
        CustomerID     => $GetParam{'X-KIX-CustomerNo'}   || $GetParam{'X-OTRS-CustomerNo'},
        CustomerUser   => $GetParam{'X-KIX-CustomerUser'} || $GetParam{'X-OTRS-CustomerUser'},
        OwnerID        => $OwnerID,
        UserID         => $Param{InmailUserID},
    );

    if ( !$TicketID ) {
        return;
    }

    # debug
    if ( $Self->{Debug} > 0 ) {
        print "New Ticket created!\n";
        print "TicketNumber: $NewTn\n";
        print "TicketID: $TicketID\n";
        print "Priority: $Priority\n";
        print "State: $State\n";
        print "CustomerID: "
            . ( $GetParam{'X-KIX-CustomerNo'} || $GetParam{'X-OTRS-CustomerNo'} ) . "\n";
        print "CustomerUser: "
            . ( $GetParam{'X-KIX-CustomerUser'} || $GetParam{'X-OTRS-CustomerUser'} ) . "\n";
        for my $Value (qw(Type Service SLA Lock)) {

            if ( $GetParam{ 'X-KIX-' . $Value } || $GetParam{ 'X-OTRS-' . $Value } ) {
                print "Type: "
                    . ( $GetParam{ 'X-KIX-' . $Value } || $GetParam{ 'X-OTRS-' . $Value } ) . "\n";
            }
        }
    }

    # set pending time
    if ( $GetParam{'X-KIX-State-PendingTime'} || $GetParam{'X-OTRS-State-PendingTime'} ) {

# You can specify absolute dates like "2010-11-20 00:00:00" or relative dates, based on the arrival time of the email.
# Use the form "+ $Number $Unit", where $Unit can be 's' (seconds), 'm' (minutes), 'h' (hours) or 'd' (days).
# Only one unit can be specified. Examples of valid settings: "+50s" (pending in 50 seconds), "+30m" (30 minutes),
# "+12d" (12 days). Note that settings like "+1d 12h" are not possible. You can specify "+36h" instead.

        my $TargetTimeStamp = $GetParam{'X-KIX-State-PendingTime'} || $GetParam{'X-OTRS-State-PendingTime'};

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

        my $Set = $TicketObject->TicketPendingTimeSet(
            String   => $TargetTimeStamp,
            TicketID => $TicketID,
            UserID   => $Param{InmailUserID},
        );

        # debug
        if ( $Set && $Self->{Debug} > 0 ) {
            print "State-PendingTime: "
                . ( $GetParam{'X-KIX-State-PendingTime'} || $GetParam{'X-OTRS-State-PendingTime'} )
                . "\n";
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

        my $Key = 'X-KIX-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        if ( !defined $GetParam{$Key} || !length $GetParam{$Key} ) {

            # fallback
            $Key = 'X-OTRS-DynamicField-' . $DynamicFieldList->{$DynamicFieldID}
        }

        if ( defined $GetParam{$Key} && length $GetParam{$Key} ) {

            # get dynamic field config
            my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                ID => $DynamicFieldID,
            );

            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldGet,
                ObjectID           => $TicketID,
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
    # for backward compatibility (should be removed in a future version)
    my %Values = (
        'X-KIX-TicketKey'    => 'TicketFreeKey',
        'X-KIX-TicketValue'  => 'TicketFreeText',
        'X-OTRS-TicketKey'   => 'TicketFreeKey',
        'X-OTRS-TicketValue' => 'TicketFreeText',
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
                        ObjectID           => $TicketID,
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
    # for backward compatibility (should be removed in a future version)
    for my $Count ( 1 .. 6 ) {
        my $Key = 'X-KIX-TicketTime' . $Count;
        if ( !defined $GetParam{$Key} || !length $GetParam{$Key} ) {

            # fallback
            $Key = 'X-OTRS-TicketTime' . $Count;
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
                        ObjectID           => $TicketID,
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

    # get body
    my $Body         = $GetParam{Body};
    my $RichTextUsed = $ConfigObject->Get('Frontend::RichText');
    if ( defined $TicketTemplate{Body} ) {
        if (   $RichTextUsed
            && $TicketTemplate{Body} =~ m/(.*?)&lt;(KIX|OTRS)_EMAIL_BODY&gt;(.*)/msg
        ) {
            $Body                     = $1 . $Body . $3;
            $GetParam{'Content-Type'} = 'text/html';
        }
        elsif (
            !$RichTextUsed
            && $TicketTemplate{Body} =~ m/(.*?)<(KIX|OTRS)_EMAIL_BODY>(.*)/msg
        ) {
            $Body = $1 . $Body . $3;
        }
    }

    # get article type
    my $ArticleType;
    if ( defined $TicketTemplate{ArticleType} ) {
        $ArticleType = $TicketObject->ArticleTypeLookup( ArticleTypeID => $TicketTemplate{ArticleType} );
    }

    # do article db insert
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID         => $TicketID,
        ArticleType      => $GetParam{'X-KIX-ArticleType'} || $GetParam{'X-OTRS-ArticleType'} || $ArticleType || 'email-external',
        SenderType       => $GetParam{'X-KIX-SenderType'}  || $GetParam{'X-OTRS-SenderType'},
        From             => $GetParam{'X-KIX-From'}        || $GetParam{From},
        ReplyTo          => $GetParam{ReplyTo},
        To               => $GetParam{To},
        Cc               => $GetParam{Cc},
        Subject          => $Subject,
        MessageID        => $GetParam{'Message-ID'},
        InReplyTo        => $GetParam{'In-Reply-To'},
        References       => $GetParam{'References'},
        ContentType      => $GetParam{'Content-Type'},
        Body             => $Body,
        UserID           => $Param{InmailUserID},
        HistoryType      => 'EmailCustomer',
        HistoryComment   => "\%\%$Comment",
        OrigHeader       => \%GetParam,
        AutoResponseType => $AutoResponseType,
        Queue            => $Queue,
    );

    # close ticket if article create failed!
    if ( !$ArticleID ) {
        $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => $Param{InmailUserID},
        );
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't process email with MessageID <$GetParam{'Message-ID'}>! "
                . "Please create a bug report with this email (From: $GetParam{From}, Located "
                . "under var/spool/problem-email*) on http://kixdesk.com/!",
        );
        return;
    }

    if ( $Param{LinkToTicketID} ) {

        my $SourceKey = $Param{LinkToTicketID};
        my $TargetKey = $TicketID;

        $Kernel::OM->Get('Kernel::System::LinkObject')->LinkAdd(
            SourceObject => 'Ticket',
            SourceKey    => $SourceKey,
            TargetObject => 'Ticket',
            TargetKey    => $TargetKey,
            Type         => 'Normal',
            State        => 'Valid',
            UserID       => $Param{InmailUserID},
        );
    }

    # debug
    if ( $Self->{Debug} > 0 ) {
        ATTRIBUTE:
        for my $Attribute ( sort keys %GetParam ) {
            next ATTRIBUTE if !$GetParam{$Attribute};
            print "$Attribute: $GetParam{$Attribute}\n";
        }
    }

    # dynamic fields
    $DynamicFieldList =
        $DynamicFieldObject->DynamicFieldList(
        Valid      => 1,
        ResultType => 'HASH',
        ObjectType => 'Article',
        );

    # set dynamic fields for Article object type
    DYNAMICFIELDID:
    for my $DynamicFieldID ( sort keys %{$DynamicFieldList} ) {
        next DYNAMICFIELDID if !$DynamicFieldID;
        next DYNAMICFIELDID if !$DynamicFieldList->{$DynamicFieldID};

        my $Key = 'X-KIX-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        if ( !defined $GetParam{$Key} || !length $GetParam{$Key} ) {

            # fallback
            $Key = 'X-OTRS-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
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
    # for backward compatibility (should be removed in a future version)
    %Values = (
        'X-KIX-ArticleKey'    => 'ArticleFreeKey',
        'X-KIX-ArticleValue'  => 'ArticleFreeText',
        'X-OTRS-ArticleKey'   => 'ArticleFreeKey',
        'X-OTRS-ArticleValue' => 'ArticleFreeText',
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

    # add created ticket to ticket hash to be skipped
    $Param{SkipTicketIDs}->{ $TicketID } = 1;

    return ( 1, $TicketID );
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
