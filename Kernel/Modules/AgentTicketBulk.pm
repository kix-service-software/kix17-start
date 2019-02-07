# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketBulk;

use strict;
use warnings;

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

    # get needed objects
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject        = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $UploadCacheObject   = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $EncodeObject        = $Kernel::OM->Get('Kernel::System::Encode');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');
    my $BulkExecutor        = $Kernel::OM->Get('Kernel::System::AsynchronousExecutor::BulkExecutor');

    my @TicketIDs;
    my %GetTickets;
    my %Error;
    my %Time;
    my %GetParam;

    $Param{FormID}   = $ParamObject->GetParam( Param => 'FormID' );
    if ( !$Param{FormID} ) {
        $Param{FormID} = $UploadCacheObject->FormIDCreate();
    }

    my @ContentItems = $UploadCacheObject->FormIDGetAllFilesData(
        FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID},
    );

    if ( $Self->{Subaction} eq 'CancelAndClose' ) {
        $UploadCacheObject->FormIDRemove( FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID} );

        return $LayoutObject->PopupClose(
            Reload => 1,
        );
    }

    elsif ( $Self->{Subaction} eq 'CancelandUnlock' ) {

        my @TicketIDs;
        for my $Item (@ContentItems) {
            next if $Item->{Filename} ne 'LockedItemIDs';
            $Item->{Content} = $EncodeObject->Convert(
                Text => $Item->{Content},
                From => 'utf-8',
                To   => 'iso-8859-1',
            );
            push(@TicketIDs, split(',', $Item->{Content}));
        }

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # check needed stuff
        if ( !@TicketIDs ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate('Can\'t lock Tickets, no TicketIDs are given!')
                    . ' - '
                    . $LayoutObject->{LanguageObject}->Translate('Please contact the administrator.'),
            );
        }

        TICKET_ID:
        for my $TicketID (@TicketIDs) {

            my %JobParam = (
                CallAction              => 'BulkCancel',
                FormID                  => $Param{FormID},
                TicketID                => $TicketID,
                Action                  => $Self->{Action},
                UserID                  => $Self->{UserID},
            );
            my $Success = $BulkExecutor->AsyncCall(
                ObjectName     => 'Kernel::System::AsynchronousExecutor::BulkExecutor',
                FunctionName   => 'Run',
                TaskName       => $Self->{Action} . '-' . $Param{FormID} . '-BulkCancel',
                FunctionParams => \%JobParam,
                Attempts       => 1,
            );
        }

        return $LayoutObject->ProgressBar(
            FormID       => $Param{FormID},
            MaxCount     => scalar @TicketIDs,
            IgnoredCount => 0,
            ItemCount    => scalar @TicketIDs,

            TaskName     => $Self->{Action} . '-' . $Param{FormID} . '-BulkCancel',
            TaskType     => 'AsynchronousExecutor',

            Action       => $Self->{Action},
            LoaderText   => 'Unlocking the tickets, please wait a moment...',

            Title        => 'Ticket Bulk Action',
            EndParam     => {
                Subaction    => 'CancelandUnlockEnd',
                UserID       => $Self->{UserID}
            },
            FooterType   => 'Small',
            HeaderType   => 'Small',
        );
    }

    elsif ( $Self->{Subaction} eq 'CancelandUnlockEnd' ) {
        my @CancelErrorID;

        for my $Item (@ContentItems) {
            next if $Item->{Filename} !~ /^CancelError_[0-9]+$/;
            $Item->{Content} = $EncodeObject->Convert(
                Text => $Item->{Content},
                From => 'utf-8',
                To   => 'iso-8859-1',
            );
            push(@CancelErrorID, $Item->{Content});
        }

        if ( scalar @CancelErrorID ) {
            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}->Translate( "Ticket (%s) is not unlocked!", join(',',@CancelErrorID) ),
            );
        }
        $UploadCacheObject->FormIDRemove( FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID} );

        return $LayoutObject->PopupClose(
            Reload => 1,
        );

    }

    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {
        my $QueueID = $ParamObject->GetParam( Param => 'QueueID' ) || '';

        # Get all users.
        my %AllGroupsMembers = $Kernel::OM->Get('Kernel::System::User')->UserList(
            Type  => 'Long',
            Valid => 1
        );

        # Put only possible rw agents to owner list.
        if ( !$ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
            my %AllGroupsMembersNew;
            my @QueueIDs;

            if ($QueueID) {
                push @QueueIDs, $QueueID;
            }
            else {
                my @TicketIDs = grep {$_} $ParamObject->GetArray( Param => 'TicketID' );
                for my $TicketID (@TicketIDs) {
                    my %Ticket = $TicketObject->TicketGet(
                        TicketID      => $TicketID,
                        DynamicFields => 0,
                    );
                    push @QueueIDs, $Ticket{QueueID};
                }
            }

            my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
            my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

            for my $QueueID (@QueueIDs) {
                my $GroupID = $QueueObject->GetQueueGroupID( QueueID => $QueueID );
                my %GroupMember = $GroupObject->PermissionGroupGet(
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

        my @JSONData = (
            {
                Name         => 'OwnerID',
                Data         => \%AllGroupsMembers,
                PossibleNone => 1,
            }
        );

        if (
            $ConfigObject->Get('Ticket::Responsible')
            && $ConfigObject->Get("Ticket::Frontend::$Self->{Action}")->{Responsible}
            )
        {
            push @JSONData, {
                Name         => 'ResponsibleID',
                Data         => \%AllGroupsMembers,
                PossibleNone => 1,
            };
        }

        my $JSON = $LayoutObject->BuildSelectionJSON( [@JSONData] );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    elsif ( $Self->{Subaction} eq 'DoEnd') {
        # redirect
        my $ActionFlag   = $ParamObject->GetParam( Param => 'ActionFlag' );
        my $MainTicketID = $ParamObject->GetParam( Param => 'TicketID' ) || undef;

        if ($ActionFlag) {
            my $DestURL = defined $MainTicketID && $MainTicketID !~ /^null$/i
                ? "Action=AgentTicketZoom;TicketID=$MainTicketID"
                : ( $Self->{LastScreenOverview} || 'Action=AgentDashboard' );

            $UploadCacheObject->FormIDRemove( FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID} );

            return $LayoutObject->PopupClose(
                URL => $DestURL,
            );
        } else {

            my @ContentItems = $UploadCacheObject->FormIDGetAllFilesData(
                FormID => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID},
            );

            for my $Item (@ContentItems) {
                $Item->{Content} = $EncodeObject->Convert(
                    Text => $Item->{Content},
                    From => 'utf-8',
                    To   => 'iso-8859-1',
                );
                if ( $Item->{Filename} eq 'GetParam' ) {
                    %GetParam = $JSONObject->Decode( Data => $Item->{Content});
                }

                elsif ( $Item->{Filename} eq 'Time' ) {
                    %Time = $JSONObject->Decode( Data => $Item->{Content});
                }
            }
        }
    }

    # check if bulk feature is enabled
    if ( !$ConfigObject->Get('Ticket::Frontend::BulkFeature') ) {
        return $LayoutObject->ErrorScreen(
            Message => $LayoutObject->{LanguageObject}->Translate('Bulk feature is not enabled!'),
        );
    }

    if( $Param{FormID} ) {
        for my $Item (@ContentItems) {
            $Item->{Content} = $EncodeObject->Convert(
                Text => $Item->{Content},
                From => 'utf-8',
                To   => 'iso-8859-1',
            );

            if ( $Item->{Filename} eq 'ItemIDs' ) {
                @TicketIDs = split(',',$Item->{Content});
            }

            elsif ($Item->{Filename} =~ /^Ticket_([0-9]+)$/) {
                my $Data    = $JSONObject->Decode( Data => $Item->{Content});
                my ($ID)    = $1;
                next if !defined $ID;
                $GetTickets{$ID} = $Data;
            }
        }
    }

    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # get involved tickets, filtering empty TicketIDs
    my @IgnoreLockedTicketIDs;
    my @ValidTicketIDs;

    if ( $Self->{Subaction} eq 'TicketLocking' ) {
        # check if only locked tickets have been selected
        if ( $Config->{RequiredLock} ) {
            for my $TicketID (@TicketIDs) {
                if ( $TicketObject->TicketLockGet( TicketID => $TicketID ) ) {
                    my $AccessOk = $TicketObject->OwnerCheck(
                        TicketID => $TicketID,
                        OwnerID  => $Self->{UserID},
                    );
                    if ($AccessOk) {
                        push @ValidTicketIDs, $TicketID;
                    }
                    else {
                        push @IgnoreLockedTicketIDs, $TicketID;
                    }
                }
                else {
                    push @ValidTicketIDs, $TicketID;
                }
            }
        }
        else {
            @ValidTicketIDs = @TicketIDs;
        }
        # check needed stuff
        if ( !@ValidTicketIDs ) {
            if ( $Config->{RequiredLock} ) {
                return $LayoutObject->ErrorScreen(
                    Message => $LayoutObject->{LanguageObject}->Translate('No selectable TicketID is given!')
                        . ' - '
                        . $LayoutObject->{LanguageObject}->Translate('You either selected no ticket or only tickets which are locked by other agents.'),
                );
            }
            else {
                return $LayoutObject->ErrorScreen(
                    Message => $LayoutObject->{LanguageObject}->Translate('No TicketID is given!')
                        . ' - '
                        . $LayoutObject->{LanguageObject}->Translate('You need to select at least one ticket.'),
                );
            }
        }
    }

    my $Output = $LayoutObject->Header(
        Type => 'Small',
    );

    # get bulk modules from SysConfig
    my $BulkModuleConfig = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::BulkModule') || {};

    # create bulk module objects
    my @BulkModules;
    MODULECONFIG:
    for my $ModuleConfig ( sort keys %{$BulkModuleConfig} ) {

        next MODULECONFIG if !$ModuleConfig;
        next MODULECONFIG if !$BulkModuleConfig->{$ModuleConfig};
        next MODULECONFIG if ref $BulkModuleConfig->{$ModuleConfig} ne 'HASH';
        next MODULECONFIG if !$BulkModuleConfig->{$ModuleConfig}->{Module};

        my $Module = $BulkModuleConfig->{$ModuleConfig}->{Module};

        my $ModuleObject;
        eval {
            $ModuleObject = $Kernel::OM->Get($Module);
        };

        if ( !$ModuleObject ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Could not create a new object for $Module!",
            );
            next MODULECONFIG;
        }

        if ( ref $ModuleObject ne $Module ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Object for $Module is invalid!",
            );
            next MODULECONFIG;
        }

        push @BulkModules, $ModuleObject;
    }

    # get needed objects
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');

    # get all parameters and check for errors
    if ( $Self->{Subaction} eq 'Do' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # get all parameters
        for my $Key (
            qw(OwnerID Owner ResponsibleID Responsible PriorityID Priority QueueID Queue Subject
            Body ArticleTypeID ArticleType TypeID StateID State MergeToSelection MergeTo LinkTogether
            EmailSubject EmailBody EmailTimeUnits
            LinkTogetherParent Unlock MergeToChecked MergeToOldestChecked)
            )
        {
            $GetParam{$Key} = $ParamObject->GetParam( Param => $Key ) || '';
        }

        for my $Key (qw(TimeUnits)) {
            $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
        }

        # get time stamp based on user time zone
        %Time = $LayoutObject->TransfromDateSelection(
            Year   => $ParamObject->GetParam( Param => 'Year' ),
            Month  => $ParamObject->GetParam( Param => 'Month' ),
            Day    => $ParamObject->GetParam( Param => 'Day' ),
            Hour   => $ParamObject->GetParam( Param => 'Hour' ),
            Minute => $ParamObject->GetParam( Param => 'Minute' ),
        );

        if ( $GetParam{'MergeToSelection'} eq 'OptionMergeTo' ) {
            $GetParam{'MergeToChecked'} = 'checked';
        }
        elsif ( $GetParam{'MergeToSelection'} eq 'OptionMergeToOldest' ) {
            $GetParam{'MergeToOldestChecked'} = 'checked';
        }

        # check some stuff
        if (
            $GetParam{Subject}
            && $ConfigObject->Get('Ticket::Frontend::AccountTime')
            && $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
            && $GetParam{TimeUnits} eq ''
            )
        {
            $Error{'TimeUnitsInvalid'} = 'ServerError';
        }

        if (
            $GetParam{EmailSubject}
            && $ConfigObject->Get('Ticket::Frontend::AccountTime')
            && $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
            && $GetParam{EmailTimeUnits} eq ''
            )
        {
            $Error{'EmailTimeUnitsInvalid'} = 'ServerError';
        }

        # Body and Subject must both be filled in or both be empty
        if ( $GetParam{Subject} eq '' && $GetParam{Body} ne '' ) {
            $Error{'SubjectInvalid'} = 'ServerError';
        }
        if ( $GetParam{Subject} ne '' && $GetParam{Body} eq '' ) {
            $Error{'BodyInvalid'} = 'ServerError';
        }

        # Email Body and Email Subject must both be filled in or both be empty
        if ( $GetParam{EmailSubject} eq '' && $GetParam{EmailBody} ne '' ) {
            $Error{'EmailSubjectInvalid'} = 'ServerError';
        }
        if ( $GetParam{EmailSubject} ne '' && $GetParam{EmailBody} eq '' ) {
            $Error{'EmailBodyInvalid'} = 'ServerError';
        }

        # check if pending date must be validated
        if ( $GetParam{StateID} || $GetParam{State} ) {
            my %StateData;
            if ( $GetParam{StateID} ) {
                %StateData = $StateObject->StateGet(
                    ID => $GetParam{StateID},
                );
            }
            else {
                %StateData = $StateObject->StateGet(
                    Name => $GetParam{State},
                );
            }

            # get time object
            my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

            if ( $StateData{TypeName} =~ /^pending/i ) {
                if ( !$TimeObject->Date2SystemTime( %Time, Second => 0 ) ) {
                    $Error{'DateInvalid'} = 'ServerError';
                }
                if (
                    $TimeObject->Date2SystemTime( %Time, Second => 0 )
                    < $TimeObject->SystemTime()
                    )
                {
                    $Error{'DateInvalid'} = 'ServerError';
                }
            }
        }

        # get check item object
        my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

        if ( $GetParam{'MergeToSelection'} eq 'OptionMergeTo' && $GetParam{'MergeTo'} ) {
            $CheckItemObject->StringClean(
                StringRef => \$GetParam{'MergeTo'},
                TrimLeft  => 1,
                TrimRight => 1,
            );
            my $TicketID = $TicketObject->TicketCheckNumber(
                Tn => $GetParam{'MergeTo'},
            );
            if ( !$TicketID ) {
                $Error{'MergeToInvalid'} = 'ServerError';
            }
        }
        if ( $GetParam{'LinkTogetherParent'} ) {
            $CheckItemObject->StringClean(
                StringRef => \$GetParam{'LinkTogetherParent'},
                TrimLeft  => 1,
                TrimRight => 1,
            );
            my $TicketID = $TicketObject->TicketCheckNumber(
                Tn => $GetParam{'LinkTogetherParent'},
            );
            if ( !$TicketID ) {
                $Error{'LinkTogetherParentInvalid'} = 'ServerError';
            }
        }

        # call Validate() in all ticket bulk modules
        if (@BulkModules) {
            MODULEOBJECT:
            for my $ModuleObject (@BulkModules) {
                next MODULEOBJECT if !$ModuleObject->can('Validate');

                my @Result = $ModuleObject->Validate(
                    UserID => $Self->{UserID},
                );

                next MODULEOBJECT if !@Result;

                # include all validation errors in the common error hash
                for my $ValidationError (@Result) {
                    $Error{ $ValidationError->{ErrorKey} } = $ValidationError->{ErrorValue};
                }
            }
        }
    }

    # process tickets
    my %Notify;
    my @TicketIDSelected;
    my @LockedTicketIDs;
    my $MainTicketID;
    my $ActionFlag    = 0;
    my $Counter       = 1;
    $Param{TicketsWereLocked} = 0;

    if ( ( $Self->{Subaction} eq 'Do' ) && ( !%Error ) ) {

        # merge to
        if ( $GetParam{'MergeToSelection'} eq 'OptionMergeTo' && $GetParam{'MergeTo'} ) {
            $MainTicketID = $TicketObject->TicketIDLookup(
                TicketNumber => $GetParam{'MergeTo'},
            );
        }

        # merge to oldest
        elsif ( $GetParam{'MergeToSelection'} eq 'OptionMergeToOldest' ) {

            # find oldest
            my $TicketIDOldest;
            my $TicketIDOldestID;
            for my $TicketIDCheck (@TicketIDs) {
                my %Ticket = $TicketObject->TicketGet(
                    TicketID      => $TicketIDCheck,
                    DynamicFields => 0,
                );
                if ( !defined $TicketIDOldest ) {
                    $TicketIDOldest   = $Ticket{CreateTimeUnix};
                    $TicketIDOldestID = $TicketIDCheck;
                }
                if ( $TicketIDOldest > $Ticket{CreateTimeUnix} ) {
                    $TicketIDOldest   = $Ticket{CreateTimeUnix};
                    $TicketIDOldestID = $TicketIDCheck;
                }
            }
            $MainTicketID = $TicketIDOldestID;
        }
    }

    TICKET_ID:
    for my $TicketID (@TicketIDs) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 0,
        );

        # check permissions
        my $Access = $TicketObject->TicketPermission(
            Type     => 'rw',
            TicketID => $TicketID,
            UserID   => $Self->{UserID}
        );
        if ( !$Access ) {

            # error screen, don't show ticket
            push( @{$Notify{Notice}}, $Ticket{TicketNumber} . ": " . $LayoutObject->{LanguageObject}->Translate("You don't have write access to this ticket."));
            next TICKET_ID;
        }

        # check if it's already locked by somebody else
        if ( !$Config->{RequiredLock} ) {
            push( @{$Notify{Info}}, $Ticket{TicketNumber} . ": " . $LayoutObject->{LanguageObject}->Translate("Ticket selected."));
        }
        else {
            if ( $Self->{Subaction} eq 'TicketLocking' ) {
                my %JobParam = (
                    CallAction              => 'BulkLock',
                    FormID                  => $Param{FormID},
                    TicketID                => $TicketID,
                    Action                  => $Self->{Action},
                    UserID                  => $Self->{UserID},
                    IgnoreLockedTicketIDs   => \@IgnoreLockedTicketIDs
                );
                my $Success = $BulkExecutor->AsyncCall(
                    ObjectName     => 'Kernel::System::AsynchronousExecutor::BulkExecutor',
                    FunctionName   => 'Run',
                    TaskName       => $Self->{Action} . '-' . $Param{FormID} . '-BulkLock',
                    FunctionParams => \%JobParam,
                    Attempts       => 1,
                );
            }

            elsif ( $Self->{Subaction} ne 'Do' ) {
                if ( $GetTickets{$TicketID}->{Locked} ) {
                    push(@LockedTicketIDs, $TicketID);
                }
                if ( $GetTickets{$TicketID}->{TicketsWereLocked}
                    && !$Param{TicketsWereLocked}
                ) {
                    $Param{TicketsWereLocked} = $GetTickets{$TicketID}->{TicketsWereLocked};
                }
                if ( $GetTickets{$TicketID}->{Priority}
                    && $GetTickets{$TicketID}->{Notify}
                ) {
                    push( @{$Notify{$GetTickets{$TicketID}->{Priority}}}, $GetTickets{$TicketID}->{Notify});
                }
            }
        }

        # remember selected ticket ids
        push @TicketIDSelected, $TicketID;

        # do some actions on tickets
        if ( ( $Self->{Subaction} eq 'Do' ) && ( !%Error ) ) {

            # challenge token check for write action
            $LayoutObject->ChallengeTokenCheck();

            my %JobParam = (
                CallAction      => 'BulkDo',
                Ticket          => \%Ticket,
                Time            => \%Time,
                FormID          => $Param{FormID},
                TicketID        => $TicketID,
                Action          => $Self->{Action},
                UserID          => $Self->{UserID},
                UserFirstname   => $Self->{UserFirstname},
                UserLastname    => $Self->{UserLastname},
                UserEmail       => $Self->{UserEmail},
                BulkModules     => \@BulkModules,
                GetParam        => \%GetParam,
                Counter         => $Counter,
                MainTicketID    => $MainTicketID,
                TicketIDs       => \@TicketIDs,
            );
            my $Success = $BulkExecutor->AsyncCall(
                ObjectName     => 'Kernel::System::AsynchronousExecutor::BulkExecutor',
                FunctionName   => 'Run',
                TaskName       => $Self->{Action} . '-' . $Param{FormID} . '-BulkDo',
                FunctionParams => \%JobParam,
                Attempts       => 1,
            );
            $ActionFlag = 1;
        }
        $Counter++;
    }

    if ( scalar @LockedTicketIDs ) {
        my $FileID = $UploadCacheObject->FormIDAddFile(
            FormID      => $Param{FormID}.'.'.$Self->{Action}.'.'.$Self->{UserID},
            Filename    => 'LockedItemIDs',
            Content     => join(',', @LockedTicketIDs),
            ContentType => 'text/xml',
        );
    }

    if ( $Config->{RequiredLock}
         && $Self->{Subaction} eq 'TicketLocking'
    ) {
        return $LayoutObject->ProgressBar(
            FormID          => $Param{FormID},
            MaxCount        => scalar @TicketIDSelected,
            IgnoredCount    => scalar @IgnoreLockedTicketIDs,
            ItemCount       => scalar @TicketIDs,

            TaskName        => $Self->{Action} . '-' . $Param{FormID} . '-BulkLock',
            TaskType        => 'AsynchronousExecutor',

            AbortCheck      => 2,
            AbortSubaction  => 'CancelAndClose',
            Action          => $Self->{Action},

            LoaderText      => 'Locking the tickets, please wait a moment...',
            Title           => 'Ticket Bulk Action',
            EndParam        => {
                UserID       => $Self->{UserID}
            },
            FooterType      => 'Small',
            HeaderType      => 'Small',
        );
    }

    elsif ( $Self->{Subaction} eq 'Do' ) {
        return $LayoutObject->ProgressBar(
            FormID          => $Param{FormID},
            MaxCount        => scalar @TicketIDSelected,
            IgnoredCount    => scalar @IgnoreLockedTicketIDs,
            ItemCount       => scalar @TicketIDs,

            TaskName        => $Self->{Action} . '-' . $Param{FormID} . '-BulkDo',
            TaskType        => 'AsynchronousExecutor',

            AbortCheck      => 1,
            AbortSubaction  => 'DoEnd',
            Action          => $Self->{Action},

            LoaderText      => 'Tickets will be saved, please wait a moment...',
            Title           => 'Ticket Bulk Action',
            EndParam        => {
                TicketID     => $MainTicketID,
                ActionFlag   => $ActionFlag,
                FormID       => $Param{FormID},
                Subaction    => 'DoEnd',
                UserID       => $Self->{UserID}
            },
            FooterType      => 'Small',
            HeaderType      => 'Small',
        );
    }

    $Output .= $Self->_Mask(
        %Param,
        %GetParam,
        %Time,
        Notify        => \%Notify,
        TicketIDs     => \@TicketIDSelected,
        Errors        => \%Error,
        BulkModules   => \@BulkModules,
    );
    $Output .= $LayoutObject->Footer(
        Type => 'Small',
    );
    return $Output;
}

sub _Mask {
    my ( $Self, %Param ) = @_;

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # prepare errors!
    if ( $Param{Errors} ) {
        for my $KeyError ( sort keys %{ $Param{Errors} } ) {
            $Param{$KeyError} = $LayoutObject->Ascii2Html( Text => $Param{Errors}->{$KeyError} );
        }
    }

    $LayoutObject->Block(
        Name => 'BulkAction',
        Data => \%Param,
    );

    if ( $Param{Notify} ) {
        $LayoutObject->Block(
            Name => 'BulkNotify',
        );
        for my $Priority ( qw(Error Notice Info) ) {
            for my $Notify ( @{$Param{Notify}->{$Priority}} ) {
                    $LayoutObject->Block(
                    Name => 'BulkNotifyRow',
                    Data => {
                        Priority => $Priority,
                        Notify   => $Notify
                    }
                );
            }
        }
    }

    # remember ticket ids
    if ( $Param{TicketIDs} ) {
        for my $TicketID ( @{ $Param{TicketIDs} } ) {
            $LayoutObject->Block(
                Name => 'UsedTicketID',
                Data => {
                    TicketID => $TicketID,
                },
            );
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $Config       = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # build ArticleTypeID string
    my %DefaultNoteTypes = %{ $Config->{ArticleTypes} };
    my %NoteTypes = $TicketObject->ArticleTypeList( Result => 'HASH' );
    for my $KeyNoteType ( sort keys %NoteTypes ) {
        if ( !$DefaultNoteTypes{ $NoteTypes{$KeyNoteType} } ) {
            delete $NoteTypes{$KeyNoteType};
        }
    }

    if ( $Param{ArticleTypeID} ) {
        $Param{NoteStrg} = $LayoutObject->BuildSelection(
            Data       => \%NoteTypes,
            Name       => 'ArticleTypeID',
            SelectedID => $Param{ArticleTypeID},
            Class      => 'Modernize',
        );
    }
    else {
        $Param{NoteStrg} = $LayoutObject->BuildSelection(
            Data          => \%NoteTypes,
            Name          => 'ArticleTypeID',
            SelectedValue => $Config->{ArticleTypeDefault},
            Class         => 'Modernize',
        );
    }

    # build next states string
    if ( $Config->{State} ) {
        my %State;

        # get state object
        my $StateObject = $Kernel::OM->Get('Kernel::System::State');

        # KIX4OTRS-capeIT
        # my %StateList = $StateObject->StateGetStatesByType(
        #     StateType => $Config->{StateType},
        #     Result    => 'HASH',
        #     Action    => $Self->{Action},
        #     UserID    => $Self->{UserID},
        # );

        my %StateList = ();
        my $TSWFConfig = $ConfigObject->Get('TicketStateWorkflow') || '';
        if ( $TSWFConfig && ref($TSWFConfig) eq 'HASH' ) {
            %StateList = $TicketObject->TSWFCommonNextStates(
                TicketIDs => $Param{TicketIDs},
                StateType => $Config->{StateType},
                Action    => $Self->{Action},
                UserID    => $Self->{UserID},
            );
            if ( !%StateList ) {
                $StateList{''} = 'no state update possible - no common next states';
            }
        }
        else {
            %StateList = $StateObject->StateGetStatesByType(
                StateType => $Config->{StateType},
                Result    => 'HASH',
                Action    => $Self->{Action},
                UserID    => $Self->{UserID},
            );
        }

        # if ( !$Config->{StateDefault} ) {
        if ( !$Config->{StateDefault} && !( defined( $StateList{''} ) ) ) {
        # EO KIX4OTRS-capeIT
            $StateList{''} = '-';
        }
        if ( !$Param{StateID} ) {
            if ( $Config->{StateDefault} ) {
                $State{SelectedValue} = $Config->{StateDefault};
            }
        }
        else {
            $State{SelectedID} = $Param{StateID};
        }

        $Param{NextStatesStrg} = $LayoutObject->BuildSelection(
            Data => \%StateList,
            Name => 'StateID',
            %State,
            Class => 'Modernize',
        );
        $LayoutObject->Block(
            Name => 'State',
            Data => \%Param,
        );

        STATE_ID:
        for my $StateID ( sort keys %StateList ) {
            next STATE_ID if !$StateID;
            my %StateData = $StateObject->StateGet( ID => $StateID );
            next STATE_ID if $StateData{TypeName} !~ /pending/i;
            $Param{DateString} = $LayoutObject->BuildDateSelection(
                %Param,
                Format               => 'DateInputFormatLong',
                DiffTime             => $ConfigObject->Get('Ticket::Frontend::PendingDiffTime') || 0,
                Class                => $Param{Errors}->{DateInvalid} || '',
                Validate             => 1,
                ValidateDateInFuture => 1,
            );
            $LayoutObject->Block(
                Name => 'StatePending',
                Data => \%Param,
            );
            last STATE_ID;
        }
    }

    # types
    if ( $ConfigObject->Get('Ticket::Type') && $Config->{TicketType} ) {
        my %Type = $TicketObject->TicketTypeList(
            %Param,
            Action => $Self->{Action},
            UserID => $Self->{UserID},
        );
        $Param{TypeStrg} = $LayoutObject->BuildSelection(
            Data         => \%Type,
            PossibleNone => 1,
            Name         => 'TypeID',
            SelectedID   => $Param{TypeID},
            Sort         => 'AlphanumericValue',
            Translation  => 0,
            Class        => 'Modernize',
        );
        $LayoutObject->Block(
            Name => 'Type',
            Data => {%Param},
        );
    }

    # get needed objects
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # owner list
    if ( $Config->{Owner} ) {
        my %AllGroupsMembers = $UserObject->UserList(
            Type  => 'Long',
            Valid => 1
        );

        # only put possible rw agents to possible owner list
        if ( !$ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
            my %AllGroupsMembersNew;
            for my $TicketID ( @{ $Param{TicketIDs} } ) {
                my %Ticket = $TicketObject->TicketGet(
                    TicketID      => $TicketID,
                    DynamicFields => 0,
                );
                my $GroupID = $QueueObject->GetQueueGroupID( QueueID => $Ticket{QueueID} );
                my %GroupMember = $GroupObject->PermissionGroupGet(
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
        $Param{OwnerStrg} = $LayoutObject->BuildSelection(
            Data         => \%AllGroupsMembers,
            Name         => 'OwnerID',
            Translation  => 0,
            SelectedID   => $Param{OwnerID},
            PossibleNone => 1,
            Class        => 'Modernize',
        );
        $LayoutObject->Block(
            Name => 'Owner',
            Data => \%Param,
        );
    }

    # responsible list
    if ( $ConfigObject->Get('Ticket::Responsible') && $Config->{Responsible} ) {
        my %AllGroupsMembers = $UserObject->UserList(
            Type  => 'Long',
            Valid => 1
        );

        # only put possible rw agents to possible owner list
        if ( !$ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
            my %AllGroupsMembersNew;
            for my $TicketID ( @{ $Param{TicketIDs} } ) {
                my %Ticket = $TicketObject->TicketGet(
                    TicketID      => $TicketID,
                    DynamicFields => 0,
                );
                my $GroupID = $QueueObject->GetQueueGroupID( QueueID => $Ticket{QueueID} );
                my %GroupMember = $GroupObject->PermissionGroupGet(
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
        $Param{ResponsibleStrg} = $LayoutObject->BuildSelection(
            Data         => \%AllGroupsMembers,
            PossibleNone => 1,
            Name         => 'ResponsibleID',
            Translation  => 0,
            SelectedID   => $Param{ResponsibleID},
            Class        => 'Modernize',
        );
        $LayoutObject->Block(
            Name => 'Responsible',
            Data => \%Param,
        );
    }

    # build move queue string
    my %MoveQueues = $TicketObject->MoveList(
        UserID => $Self->{UserID},
        Action => $Self->{Action},
        Type   => 'move_into',
    );
    $Param{MoveQueuesStrg} = $LayoutObject->AgentQueueListOption(
        Data           => { %MoveQueues, '' => '-' },
        Multiple       => 0,
        Size           => 0,
        Name           => 'QueueID',
        OnChangeSubmit => 0,
        Class          => 'Modernize',
    );

    # get priority
    if ( $Config->{Priority} ) {
        my %Priority;
        my %PriorityList = $Kernel::OM->Get('Kernel::System::Priority')->PriorityList(
            Valid  => 1,
            UserID => $Self->{UserID},
        );
        if ( !$Config->{PriorityDefault} ) {
            $PriorityList{''} = '-';
        }
        if ( !$Param{PriorityID} ) {
            if ( $Config->{PriorityDefault} ) {
                $Priority{SelectedValue} = $Config->{PriorityDefault};
            }
        }
        else {
            $Priority{SelectedID} = $Param{PriorityID};
        }
        $Param{PriorityStrg} = $LayoutObject->BuildSelection(
            Data => \%PriorityList,
            Name => 'PriorityID',
            %Priority,
            Class => 'Modernize',

        );
        $LayoutObject->Block(
            Name => 'Priority',
            Data => \%Param,
        );
    }

    # show time accounting box
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        $Param{TimeUnitsRequired} = (
            $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
            ? 'Validate_DependingRequiredAND Validate_Depending_Subject'
            : ''
        );
        $Param{TimeUnitsRequiredEmail} = (
            $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
            ? 'Validate_DependingRequiredAND Validate_Depending_EmailSubject'
            : ''
        );

        if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabelMandatory',
                Data => { TimeUnitsRequired => $Param{TimeUnitsRequired} },
            );
            $LayoutObject->Block(
                Name => 'TimeUnitsLabelMandatoryEmail',
                Data => { TimeUnitsRequired => $Param{TimeUnitsRequiredEmail} },
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabel',
                Data => \%Param,
            );
            $LayoutObject->Block(
                Name => 'TimeUnitsLabelEmail',
                Data => \%Param,
            );
        }
        $LayoutObject->Block(
            Name => 'TimeUnits',
            Data => \%Param,
        );
        $LayoutObject->Block(
            Name => 'TimeUnitsEmail',
            Data => \%Param,
        );
    }

    $Param{LinkTogetherYesNoOption} = $LayoutObject->BuildSelection(
        Data       => $ConfigObject->Get('YesNoOptions'),
        Name       => 'LinkTogether',
        SelectedID => $Param{LinkTogether} // 0,
        Class      => 'Modernize',
    );

    $Param{UnlockYesNoOption} = $LayoutObject->BuildSelection(
        Data       => $ConfigObject->Get('YesNoOptions'),
        Name       => 'Unlock',
        SelectedID => $Param{Unlock} // 1,
        Class      => 'Modernize',
    );

    # show spell check
    if ( $LayoutObject->{BrowserSpellChecker} ) {
        $LayoutObject->Block(
            Name => 'SpellCheck',
            Data => {},
        );
    }

    # add rich text editor for note & email
    if ( $LayoutObject->{BrowserRichText} ) {

        # use height/width defined for this screen
        $Param{RichTextHeight} = $Config->{RichTextHeight} || 0;
        $Param{RichTextWidth}  = $Config->{RichTextWidth}  || 0;

        $LayoutObject->Block(
            Name => 'RichText',
            Data => \%Param,
        );
    }

    # reload parent window
    if ( $Param{TicketsWereLocked} ) {

        my $URL = $Self->{LastScreenOverview};

        # add session if no cookies are enabled
        if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
            $URL .= ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
        }

        $LayoutObject->Block(
            Name => 'ParentReload',
            Data => {
                URL => $URL,
            },
        );

        # show undo&close link
        $LayoutObject->Block(
            Name => 'UndoClosePopup',
            Data => {%Param},
        );
    }
    else {

        # show cancel&close link
        $LayoutObject->Block(
            Name => 'CancelClosePopup',
            Data => {%Param},
        );
    }

    my @BulkModules = @{ $Param{BulkModules} };

    # call Display() in all ticket bulk modules
    if (@BulkModules) {

        my @BulkModuleContent;

        MODULEOBJECT:
        for my $ModuleObject (@BulkModules) {
            next MODULEOBJECT if !$ModuleObject->can('Display');

            my $ModuleContent = $ModuleObject->Display(
                Errors => $Param{Errors},
                UserID => $Self->{UserID},
            );

            push @BulkModuleContent, $ModuleContent;
        }

        $Param{BulkModuleContent} = \@BulkModuleContent;
    }

    # get output back
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketBulk',
        Data         => \%Param
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
