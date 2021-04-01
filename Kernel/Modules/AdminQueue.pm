# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminQueue;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->{'Admin::Frontend::AdminQueue'};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

    my $QueueID = $ParamObject->GetParam( Param => 'QueueID' ) || '';

    my @Params = (
        qw(
            QueueID           ParentQueueID       Name            GroupID
            UnlockTimeout     FollowUpLock        SystemAddressID Calendar
            DefaultSignKey    SalutationID        SignatureID     FollowUpID
            FirstResponseTime FirstResponseNotify UpdateTime      UpdateNotify
            SolutionTime      SolutionNotify
            Comment           ValidID
            )
    );

    # get possible sign keys
    my %KeyList;
    my %QueueData;

    if ($QueueID) {

        %QueueData = $QueueObject->QueueGet( ID => $QueueID );

        my $CryptObjectPGP = $Kernel::OM->Get('Kernel::System::Crypt::PGP');

        if ($CryptObjectPGP) {

            my @PrivateKeys = $CryptObjectPGP->PrivateKeySearch( Search => $QueueData{Email} );

            for my $DataRef (@PrivateKeys) {
                $KeyList{"PGP::Inline::$DataRef->{Key}"}   = "PGP-Inline: $DataRef->{Key} $DataRef->{Identifier}";
                $KeyList{"PGP::Detached::$DataRef->{Key}"} = "PGP-Detached: $DataRef->{Key} $DataRef->{Identifier}";
            }
        }

        my $CryptObjectSMIME = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');

        if ($CryptObjectSMIME) {

            my @PrivateKeys = $CryptObjectSMIME->PrivateSearch( Search => $QueueData{Email} );

            for my $DataRef (@PrivateKeys) {
                $KeyList{"SMIME::Detached::$DataRef->{Filename}"}
                    = "SMIME-Detached: $DataRef->{Filename} [$DataRef->{EndDate}] $DataRef->{Email}";
            }
        }
    }

    # ------------------------------------------------------------ #
    # change
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Change' ) {

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Self->_Edit(
            Action => 'Change',
            %Param,
            %QueueData,
            DefaultSignKeyList => \%KeyList,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminQueue',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # update action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';
        my ( %GetParam, %Errors );
        for my $Parameter (@Params) {
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        # check queue name
        if ( $GetParam{Name} =~ /::/ ) {
            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $Output .= $LayoutObject->Warning(
                Message => Translatable('Don\'t use :: in queue name!'),
                Comment => Translatable('Click back and change it!'),
            );
            $Output .= $LayoutObject->Footer();
            return $Output;
        }

        # get long queue name
        if ( $GetParam{ParentQueueID} ) {
            $GetParam{Name} = $QueueObject->QueueLookup(
                QueueID => $GetParam{ParentQueueID},
                )
                . '::'
                . $GetParam{Name};
        }

        # check needed data
        for my $Needed (
            qw(Name GroupID SystemAddressID SalutationID SignatureID ValidID FollowUpID)
        ) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # check if a queue exist with this name
        my $NameExists = $QueueObject->NameExistsCheck(
            Name => $GetParam{Name},
            ID   => $GetParam{QueueID}
        );
        if ($NameExists) {
            $Errors{NameExists} = 1;
            $Errors{'NameInvalid'} = 'ServerError';
        }

        # if no errors occurred
        if ( !%Errors ) {

            # update queue
            my $QueueUpdate = $QueueObject->QueueUpdate(
                %GetParam,
                UserID => $Self->{UserID}
            );

            if ($QueueUpdate) {

                # update preferences
                my %NewQueueData = $QueueObject->QueueGet( ID => $GetParam{QueueID} );

                my %Preferences;
                if ( $ConfigObject->Get('QueuePreferences') ) {
                    %Preferences = %{ $ConfigObject->Get('QueuePreferences') };
                }

                for my $Item ( sort keys %Preferences ) {

                    my $Module = $Preferences{$Item}->{Module}
                        || 'Kernel::Output::HTML::QueuePreferences::Generic';

                    # load module
                    if ( !$MainObject->Require($Module) ) {
                        return $LayoutObject->FatalError();
                    }
                    my $Object = $Module->new(
                        %{$Self},
                        ConfigItem => $Preferences{$Item},
                        Debug      => $Self->{Debug},
                    );

                    my @PrefParams = $Object->Param( QueueData => \%NewQueueData );

                    if (@PrefParams) {

                        my %GetPrefParam;
                        for my $ParamItem (@PrefParams) {

                            my @Array = $ParamObject->GetArray(
                                Param => $ParamItem->{Name},
                            );
                            $GetPrefParam{ $ParamItem->{Name} } = \@Array;
                        }

                        if (
                            !$Object->Run(
                                GetParam  => \%GetPrefParam,
                                QueueData => \%NewQueueData
                            )
                        ) {
                            $Note .= $LayoutObject->Notify( Info => $Object->Error() );
                        }
                    }
                }

                $Self->_Overview();

                my $Output = $LayoutObject->Header();
                $Output .= $LayoutObject->NavigationBar();
                $Output .= $LayoutObject->Notify( Info => Translatable('Queue updated!') );
                $Output .= $LayoutObject->Output(
                    TemplateFile => 'AdminQueue',
                    Data         => \%Param,
                );
                $Output .= $LayoutObject->Footer();

                return $Output;
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => 'Error' );

        $Self->_Edit(
            Action => 'Change',
            Errors => \%Errors,
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminQueue',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # add
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' ) {

        my %GetParam;
        $GetParam{Name} = $ParamObject->GetParam( Param => 'Name' );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Self->_Edit(
            Action => 'Add',
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminQueue',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # add action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';
        my ( %GetParam, %Errors );
        for my $Parameter (@Params) {
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        # check queue name
        if ( $GetParam{Name} =~ /::/ ) {

            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $Output .= $LayoutObject->Warning(
                Message => Translatable('Don\'t use :: in queue name!'),
                Comment => Translatable('Click back and change it!'),
            );
            $Output .= $LayoutObject->Footer();

            return $Output;
        }

        # get long queue name
        if ( $GetParam{ParentQueueID} ) {
            $GetParam{Name} = $QueueObject->QueueLookup(
                QueueID => $GetParam{ParentQueueID},
            ) . '::' . $GetParam{Name};
        }

        # check needed data
        for my $Needed (
            qw(Name GroupID SystemAddressID SalutationID SignatureID ValidID FollowUpID)
        ) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # check if some fields must be set with default values
        for my $Optional (
            qw(UnlockTimeout FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify SolutionTime SolutionNotify FollowUpLock Calendar)
        ) {

            # add default values
            if ( !$GetParam{$Optional} ) {
                $GetParam{$Optional} = 0;
            }
        }

        # check if a queue exist with this name
        my $NameExists = $QueueObject->NameExistsCheck( Name => $GetParam{Name} );
        if ($NameExists) {
            $Errors{NameExists} = 1;
            $Errors{'NameInvalid'} = 'ServerError';
        }

        # if no errors occurred
        if ( !%Errors ) {

            # create new queue
            my $ID = $QueueObject->QueueAdd(
                %GetParam,
                UserID          => $Self->{UserID},
                NoDefaultValues => 1,
            );

            if ($ID) {

                # update preferences
                my %NewQueueData = $QueueObject->QueueGet( ID => $ID );

                my %Preferences;
                if ( $ConfigObject->Get('QueuePreferences') ) {
                    %Preferences = %{ $ConfigObject->Get('QueuePreferences') };
                }

                for my $Item ( sort keys %Preferences ) {

                    my $Module = $Preferences{$Item}->{Module}
                        || 'Kernel::Output::HTML::QueuePreferences::Generic';

                    # load module
                    if ( !$MainObject->Require($Module) ) {
                        return $LayoutObject->FatalError();
                    }

                    my $Object = $Module->new(
                        %{$Self},
                        ConfigItem => $Preferences{$Item},
                        Debug      => $Self->{Debug},
                    );

                    my @PrefParams = $Object->Param( QueueData => \%NewQueueData );

                    if (@Params) {

                        my %GetPrefParam;
                        for my $ParamItem (@PrefParams) {

                            my @Array = $ParamObject->GetArray(
                                Param => $ParamItem->{Name},
                            );

                            $GetPrefParam{ $ParamItem->{Name} } = \@Array;
                        }

                        if (
                            !$Object->Run(
                                GetParam  => \%GetPrefParam,
                                QueueData => \%NewQueueData
                            )
                        ) {
                            $Note .= $LayoutObject->Notify( Info => $Object->Error() );
                        }
                    }
                }

                return $LayoutObject->Redirect(
                    OP => "Action=AdminQueueTemplates&Subaction=Queue&ID=$ID",
                );
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => 'Error' );

        $Self->_Edit(
            Action => 'Add',
            Errors => \%Errors,
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminQueue',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    else {

        $Self->_Overview();

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminQueue',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }
}

sub _Edit {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');

    # get validiy filter
    $Param{ValidityFilter} = $ParamObject->GetParam( Param => 'ValidityFilter' ) // $Self->{Config}->{ValidityFilter};

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );
    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block(
        Name => 'ActionOverview',
        Data => {
            ValidityFilter => $Param{ValidityFilter}
        }
    );

    # get valid list
    my %ValidList        = $ValidObject->ValidList();
    my %ValidListReverse = reverse %ValidList;

    $Param{ValidOption} = $LayoutObject->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID} || $ValidListReverse{valid},
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'ValidIDInvalid'} || '' ),
    );

    $Param{GroupOption} = $LayoutObject->BuildSelection(
        Data => {
            $DBObject->GetTableData(
                What  => 'id, name',
                Table => 'groups',
                Valid => 1,
            ),
        },
        Translation => 0,
        Name        => 'GroupID',
        SelectedID  => $Param{GroupID},
        Class       => 'Modernize Validate_Required ' . ( $Param{Errors}->{'GroupIDInvalid'} || '' ),
    );

    my $ParentQueue = '';
    if ( $Param{Name} ) {
        my @Queue = split( /::/, $Param{Name} );
        for ( my $i = 0; $i < $#Queue; $i++ ) {
            if ($ParentQueue) {
                $ParentQueue .= '::';
            }
            $ParentQueue .= $Queue[$i];
        }
        $Param{Name} = $Queue[-1];
    }

    my %Data = $QueueObject->QueueList( Valid => 0 );

    my $QueueName = '';
    KEY:
    for my $Key ( sort keys %Data ) {

        if ( $Param{QueueID} && $Param{QueueID} eq $Key ) {
            $QueueName = $Data{ $Param{QueueID} };
            last KEY;
        }
    }
    my %CleanHash = %Data;
    for my $Key ( sort keys %Data ) {
        if ( $CleanHash{$Key} eq $QueueName || $CleanHash{$Key} =~ /^\Q$QueueName\E\:\:/ ) {
            delete $CleanHash{$Key};
        }
    }

    # get list type
    my $ListType = $ConfigObject->Get('Ticket::Frontend::ListType');

    # get max queue level
    my $MaxParentLevel = ( $ConfigObject->Get('Ticket::Frontend::MaxQueueLevel') || 5 ) - 1;

    # verify if queue list should be a list or a tree
    if ( $ListType eq 'tree' ) {
        $Param{QueueOption} = $LayoutObject->AgentQueueListOption(
            Data => {
                '' => ' -',
                %CleanHash,
            },
            Name           => 'ParentQueueID',
            Selected       => $ParentQueue,
            MaxLevel       => $MaxParentLevel,
            OnChangeSubmit => 0,
            Class          => 'Modernize',
        );
    }
    else {

        # leave only queues with $MaxQueueLevel levels, because max allowed level is $MaxQueueLevel + 1:
        # new queue + $MaxQueueLevel levels of parent queue = $MaxQueueLevel + 1 levels
        for my $Key ( sort keys %CleanHash ) {
            my $CleanQueueName = $CleanHash{$Key};
            my @QueueNameLevel = split( ::, $CleanQueueName );
            my $QueueLevel     = $#QueueNameLevel + 1;
            if ( $QueueLevel > $MaxParentLevel ) {
                delete $CleanHash{$Key};
            }
        }

        $Param{QueueOption} = $LayoutObject->BuildSelection(
            Data          => \%CleanHash,
            Name          => 'ParentQueueID',
            SelectedValue => $ParentQueue,
            PossibleNone  => 1,
            HTMLQuote     => 0,
            Translation   => 0,
            Class         => 'Modernize',
        );
    }

    $Param{QueueLongOption} = $LayoutObject->AgentQueueListOption(
        Data           => { $QueueObject->QueueList( Valid => 0 ), },
        Name           => 'QueueID',
        Size           => 15,
        SelectedID     => $Param{QueueID},
        OnChangeSubmit => 0,
    );
    my %NotifyLevelList = (
        10 => '10%',
        20 => '20%',
        30 => '30%',
        40 => '40%',
        50 => '50%',
        60 => '60%',
        70 => '70%',
        80 => '80%',
        90 => '90%',
    );
    $Param{FirstResponseNotifyOptionStrg} = $LayoutObject->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'FirstResponseNotify',
        SelectedID   => $Param{FirstResponseNotify},
        PossibleNone => 1,
        Class        => 'Modernize',
    );
    $Param{UpdateNotifyOptionStrg} = $LayoutObject->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'UpdateNotify',
        SelectedID   => $Param{UpdateNotify},
        PossibleNone => 1,
        Class        => 'Modernize',
    );
    $Param{SolutionNotifyOptionStrg} = $LayoutObject->BuildSelection(
        Data         => \%NotifyLevelList,
        Translation  => 0,
        Name         => 'SolutionNotify',
        SelectedID   => $Param{SolutionNotify},
        PossibleNone => 1,
        Class        => 'Modernize',
    );
    $Param{SignatureOption} = $LayoutObject->BuildSelection(
        Data        => { $Kernel::OM->Get('Kernel::System::Signature')->SignatureList( Valid => 1 ), },
        Translation => 0,
        Name        => 'SignatureID',
        SelectedID  => $Param{SignatureID},
        Class => 'Modernize Validate_Required ' . ( $Param{Errors}->{'SignatureIDInvalid'} || '' ),
    );
    $Param{FollowUpLockYesNoOption} = $LayoutObject->BuildSelection(
        Data       => $ConfigObject->Get('YesNoOptions'),
        Name       => 'FollowUpLock',
        SelectedID => $Param{FollowUpLock} // 0,
        Class      => 'Modernize',
    );

    $Param{SystemAddressOption} = $LayoutObject->BuildSelection(
        Data => {
            $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressList( Valid => 1 ),
        },
        Translation  => 0,
        Name         => 'SystemAddressID',
        SelectedID   => $Param{SystemAddressID},
        PossibleNone => 1,                         # to avoid automatic assignments if the current SA is invalid
        Max          => 200,
        Class => 'Modernize Validate_Required ' . ( $Param{Errors}->{'SystemAddressIDInvalid'} || '' ),
    );

    my %DefaultSignKeyList = ();
    if ( $Param{DefaultSignKeyList} ) {
        %DefaultSignKeyList = %{ $Param{DefaultSignKeyList} };
    }
    $Param{DefaultSignKeyOption} = $LayoutObject->BuildSelection(
        Data => {
            '' => Translatable('-none-'),
            %DefaultSignKeyList
        },
        Name       => 'DefaultSignKey',
        Max        => 50,
        SelectedID => $Param{DefaultSignKey},
        Class      => 'Modernize',
    );
    $Param{SalutationOption} = $LayoutObject->BuildSelection(
        Data        => { $Kernel::OM->Get('Kernel::System::Salutation')->SalutationList( Valid => 1 ), },
        Translation => 0,
        Name        => 'SalutationID',
        SelectedID  => $Param{SalutationID},
        Class => 'Modernize Validate_Required ' . ( $Param{Errors}->{'SalutationIDInvalid'} || '' ),
    );
    $Param{FollowUpOption} = $LayoutObject->BuildSelection(
        Data => {
            $DBObject->GetTableData(
                What  => 'id, name',
                Valid => 1,
                Table => 'follow_up_possible',
            ),
        },
        Name       => 'FollowUpID',
        SelectedID => $Param{FollowUpID}
            || $ConfigObject->Get('AdminDefaultFollowUpID')
            || 1,
        Class => 'Modernize Validate_Required ' . ( $Param{Errors}->{'FollowUpIDInvalid'} || '' ),
    );
    my %Calendar = ( '' => '-' );

    my $Maximum = $ConfigObject->Get("MaximumCalendarNumber") || 50;

    for my $CalendarNumber ( '', 1 .. $Maximum ) {
        if ( $ConfigObject->Get("TimeVacationDays::Calendar$CalendarNumber") ) {
            $Calendar{$CalendarNumber} = "Calendar $CalendarNumber - "
                . $ConfigObject->Get( "TimeZone::Calendar" . $CalendarNumber . "Name" );
        }
    }
    $Param{CalendarOption} = $LayoutObject->BuildSelection(
        Data        => \%Calendar,
        Translation => 0,
        Name        => 'Calendar',
        SelectedID  => $Param{Calendar},
        Class       => 'Modernize',
    );

    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => {
            %Param,
            %{ $Param{Errors} },
        },
    );

    # shows header
    if ( $Param{Action} eq 'Change' ) {
        $LayoutObject->Block( Name => 'HeaderEdit' );
    }
    else {
        $LayoutObject->Block( Name => 'HeaderAdd' );
    }

    if ( $Param{DefaultSignKeyOption} ) {
        $LayoutObject->Block(
            Name => 'OptionalField',
            Data => \%Param,
        );
    }

    # show appropriate messages for ServerError
    if ( defined $Param{Errors}->{NameExists} && $Param{Errors}->{NameExists} == 1 ) {
        $LayoutObject->Block( Name => 'ExistNameServerError' );
    }
    else {
        $LayoutObject->Block( Name => 'NameServerError' );
    }

    # show each preferences setting
    my %Preferences;
    if ( $ConfigObject->Get('QueuePreferences') ) {
        %Preferences = %{ $ConfigObject->Get('QueuePreferences') };
    }

    for my $Item ( sort keys %Preferences ) {

        my $Module = $Preferences{$Item}->{Module}
            || 'Kernel::Output::HTML::QueuePreferences::Generic';

        # load module
        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Module) ) {
            return $LayoutObject->FatalError();
        }
        my $Object = $Module->new(
            %{$Self},
            ConfigItem => $Preferences{$Item},
            Debug      => $Self->{Debug},
        );

        my @Params = $Object->Param( QueueData => \%Param );

        if (@Params) {

            for my $ParamItem (@Params) {

                $LayoutObject->Block(
                    Name => 'Item',
                    Data => { %Param, },
                );

                if (
                    ref $ParamItem->{Data} eq 'HASH'
                    || ref $Preferences{$Item}->{Data} eq 'HASH'
                ) {
                    my %BuildSelectionParams = (
                        %{ $Preferences{$Item} },
                        %{$ParamItem},
                    );
                    $BuildSelectionParams{Class} = join( ' ', $BuildSelectionParams{Class} // '', 'Modernize' );
                    $ParamItem->{'Option'} = $LayoutObject->BuildSelection(
                        %BuildSelectionParams
                    );
                }

                $LayoutObject->Block(
                    Name => $ParamItem->{Block} || $Preferences{$Item}->{Block} || 'Option',
                    Data => {
                        %{ $Preferences{$Item} },
                        %{$ParamItem},
                    },
                );
            }
        }
    }

    # reformat from html to plain
    if ( $Param{ContentType} && $Param{ContentType} =~ /text\/html/i ) {
        $Param{Response} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii(
            String => $Param{Response},
        );
    }

    return 1;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ValidObject  = $Kernel::OM->Get('Kernel::System::Valid');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');

    # get valid list
    my %ValidList          = $ValidObject->ValidList();
    $Param{ValidityFilter} = $ParamObject->GetParam( Param => 'ValidityFilter' ) // $Self->{Config}->{ValidityFilter};

    $Param{ValidOption} = $LayoutObject->BuildSelection(
        Data       => {
            %ValidList,
            0 => 'all'
        },
        Name       => 'ValidityFilter',
        SelectedID => $Param{ValidityFilter},
        Class      => 'Modernize Fullsize',
    );

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionAdd' );
    $LayoutObject->Block(
        Name => 'ActionFilter',
        Data => {
            %Param
        }
    );

    $LayoutObject->Block(
        Name => 'OverviewResult',
        Data => \%Param,
    );

    # get queue list
    my %List = $QueueObject->QueueList(
        Valid => $Param{ValidityFilter},
    );

    # error handling
    if ( !%List ) {

        $LayoutObject->Block(
            Name => 'NoDataFoundMsg',
        );

        return 1;
    }

    for my $QueueID ( sort { $List{$a} cmp $List{$b} } keys %List ) {

        # get queue data
        my %Data = $QueueObject->QueueGet(
            ID => $QueueID,
        );

        # group lookup
        $Data{GroupName} = $GroupObject->GroupLookup(
            GroupID => $Data{GroupID},
        );

        $LayoutObject->Block(
            Name => 'OverviewResultRow',
            Data => {
                Valid          => $ValidList{ $Data{ValidID} },
                ValidityFilter => $Param{ValidityFilter},
                %Data,
            },
        );
    }

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
