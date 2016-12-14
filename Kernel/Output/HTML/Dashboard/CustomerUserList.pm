# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# KIX4OTRS-Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::CustomerUserList;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed parameters
    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get current filter
    my $Name = $ParamObject->GetParam( Param => 'Name' ) || '';
    my $PreferencesKey = 'UserDashboardCustomerUserListFilter' . $Self->{Name};

    $Self->{PrefKey} = 'UserDashboardPref' . $Self->{Name} . '-Shown';

    $Self->{PageShown} = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{ $Self->{PrefKey} }
        || $Self->{Config}->{Limit};

    $Self->{StartHit} = int( $ParamObject->GetParam( Param => 'StartHit' ) || 1 );

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    my @Params = (
        {
            Desc  => Translatable('Shown customer users'),
            Name  => $Self->{PrefKey},
            Block => 'Option',

            #            Block => 'Input',
            Data => {
                5  => ' 5',
                10 => '10',
                15 => '15',
                20 => '20',
                25 => '25',
            },
            SelectedID  => $Self->{PageShown},
            Translation => 0,
        },
    );

    return @Params;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },

        # remember, do not allow to use page cache
        # (it's not working because of internal filter)
        CacheTTL => undef,
        CacheKey => undef,
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # KIX4OTRS-capeIT
    # return if !$Param{CustomerID};
    return if !$Param{CustomerID} && !$Param{CustomerUserLogin};

    # EO KIX4OTRS-capeIT

    # get customer user object
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    # KIX4OTRS-capeIT
    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # my $CustomerIDs = { $CustomerUserObject->CustomerSearch( CustomerID => $Param{CustomerID} ) };
    my $CustomerIDs;
    my $CustomerIDUsed = 1;
    my %CustomerUserData;
    if ( defined $Param{CustomerID} ) {
        $CustomerIDs
            = {
            $CustomerUserObject->CustomerSearch(
                CustomerID          => $Param{CustomerID},
                MultipleCustomerIDs => 1
                )
            };
        $LayoutObject->Block(
            Name => 'OverviewResultCustomerLogin',
        );
    }
    else {
        my %TempHash;
        %CustomerUserData
            = $CustomerUserObject->CustomerUserDataGet( User => $Param{CustomerUserLogin} );
        $TempHash{ $Param{CustomerUserLogin} }
            = '"'
            . $CustomerUserData{UserFirstname} . ' '
            . $CustomerUserData{UserLastname} . '" <'
            . $CustomerUserData{UserEmail} . '>';
        $CustomerIDs    = \%TempHash;
        $CustomerIDUsed = 0;
        $LayoutObject->Block(
            Name => 'OverviewResultCustomerCompany',
        );
    }

    # show/disabled new phone/email-ticket link...
    if ( !$Self->{Config}->{PhoneTicketDisabled} ) {
        $LayoutObject->Block(
            Name => 'PhoneTicketHL',
        );
    }
    if ( !$Self->{Config}->{EmailTicketDisabled} ) {
        $LayoutObject->Block(
            Name => 'EmailTicketHL',
        );
    }

    # EO KIX4OTRS-capeIT

    # add page nav bar
    my $Total = scalar keys %{$CustomerIDs};

    # get layout object
    # KIX4OTRS-capeIT
    # moved upwards
    # my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    # EO KIX4OTRS-capeIT


    # my $LinkPage
    my $LinkPage;
    if ($CustomerIDUsed) {
        $LinkPage

            # EO KIX4OTRS-capeIT
            = 'Subaction=Element;Name='
            . $Self->{Name} . ';'
            . 'CustomerID='
            . $LayoutObject->LinkEncode( $Param{CustomerID} ) . ';';

        # KIX4OTRS-capeIT
    }
    else {
        $LinkPage
            = 'Subaction=Element;Name='
            . $Self->{Name} . ';'
            . 'CustomerLogin='
            . $LayoutObject->LinkEncode( $Param{CustomerUserLogin} ) . ';';
    }

    # EO KIX4OTRS-capeIT

    my %PageNav = $LayoutObject->PageNavBar(
        StartHit       => $Self->{StartHit},
        PageShown      => $Self->{PageShown},
        AllHits        => $Total || 1,
        Action         => 'Action=' . $LayoutObject->{Action},
        Link           => $LinkPage,
        AJAXReplace    => 'Dashboard' . $Self->{Name},
        IDPrefix       => 'Dashboard' . $Self->{Name},
        KeepScriptTags => $Param{AJAX},
    );

    $LayoutObject->Block(
        Name => 'ContentLargeCustomerUserListNavBar',
        Data => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
            %PageNav,
        },
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check the permission for the SwitchToCustomer feature
    if ( $ConfigObject->Get('SwitchToCustomer') ) {

        # get group object
        my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

        # get the group id which is allowed to use the switch to customer feature
        my $SwitchToCustomerGroupID = $GroupObject->GroupLookup(
            Group => $ConfigObject->Get('SwitchToCustomer::PermissionGroup'),
        );

        # get user groups, where the user has the rw privilege
        my %Groups = $GroupObject->PermissionUserGet(
            UserID => $Self->{UserID},
            Type   => 'rw',
        );

        # if the user is a member in this group he can access the feature
        if ( $Groups{$SwitchToCustomerGroupID} ) {

            $Self->{SwitchToCustomerPermission} = 1;

            $LayoutObject->Block(
                Name => 'OverviewResultSwitchToCustomer',
            );
        }
    }

    # show add new customer button if there are writable customer backends and if
    # the agent has permission
    my $AddAccess = $LayoutObject->Permission(
        Action => 'AdminCustomerUser',
        Type   => 'rw',                  # ro|rw possible
    );

    # get writable data sources
    my %CustomerSource = $CustomerUserObject->CustomerSourceList(
        ReadOnly => 0,
    );

    if ( $AddAccess && scalar keys %CustomerSource ) {
        $LayoutObject->Block(

            # KIX4OTRS-capeIT
            # Name => 'ContentLargeCustomerUserAdd',
            Name => 'OverviewResultEditCustomer',

            # EO KIX4OTRS-capeIT
            Data => {
                CustomerID => $Self->{CustomerID},
            },
        );
    }

    # get the permission for the phone ticket creation
    my $NewAgentTicketPhonePermission = $LayoutObject->Permission(
        Action => 'AgentTicketPhone',
        Type   => 'rw',
    );

    # check the permission for the phone ticket creation
    if ($NewAgentTicketPhonePermission) {
        $LayoutObject->Block(
            Name => 'OverviewResultNewAgentTicketPhone',
        );
    }

    # get the permission for the email ticket creation
    my $NewAgentTicketEmailPermission = $LayoutObject->Permission(
        Action => 'AgentTicketEmail',
        Type   => 'rw',
    );

    # check the permission for the email ticket creation
    if ($NewAgentTicketEmailPermission) {
        $LayoutObject->Block(
            Name => 'OverviewResultNewAgentTicketEmail',
        );
    }

    my @CustomerKeys = sort { lc( $CustomerIDs->{$a} ) cmp lc( $CustomerIDs->{$b} ) } keys %{$CustomerIDs};
    @CustomerKeys = splice @CustomerKeys, $Self->{StartHit} - 1, $Self->{PageShown};

    for my $CustomerKey (@CustomerKeys) {
        $LayoutObject->Block(
            Name => 'ContentLargeCustomerUserListRow',
            Data => {
                %Param,
                CustomerKey       => $CustomerKey,
                CustomerListEntry => $CustomerIDs->{$CustomerKey},
            },
        );

        # can edit?
        # KIX4OTRS-capeIT
        # if ( $AddAccess && scalar keys %CustomerSource ) {
        if ($CustomerIDUsed) {

            # EO KIX4OTRS-capeIT
            $LayoutObject->Block(
                Name => 'ContentLargeCustomerUserListRowCustomerKeyLink',
                Data => {
                    %Param,
                    CustomerKey       => $CustomerKey,
                    CustomerListEntry => $CustomerIDs->{$CustomerKey},
                },
            );
        }
        else {

            # KIX4OTRS-capeIT
            # multiple customers used
            my @CustomerIDs;
            if ( defined $CustomerUserData{UserCustomerIDs} && $CustomerUserData{UserCustomerIDs} )
            {
                @CustomerIDs = split( /,/, $CustomerUserData{UserCustomerIDs} );
            }

            # add UserCustomerID from customer data hash
            if ( !scalar grep( /$CustomerUserData{UserCustomerID}/, @CustomerIDs ) ) {
                push @CustomerIDs, $CustomerUserData{UserCustomerID};
            }

            # show all customer ids
            for my $Item (@CustomerIDs) {

                # EO KIX4OTRS-capeIT
                $LayoutObject->Block(

                    # KIX4OTRS-capeIT
                    Name => 'ContentLargeCustomerUserListRowCompanyKeyLink',

                    # EO KIX4OTRS-capeIT
                    Data => {
                        %Param,

                        # KIX4OTRS-capeIT
                        # CustomerKey       => $CustomerKey,
                        CustomerCompanyKey => $Item,
                        CustomerListEntry  => $CustomerIDs->{$CustomerKey},

                        # EO KIX4OTRS-capeIT
                    },
                );

                # KIX4OTRS-capeIT
            }

            # EO KIX4OTRS-capeIT
        }

        # KIX4OTRS-capeIT
        if ( $AddAccess && scalar keys %CustomerSource ) {
            $LayoutObject->Block(
                Name => 'ContentLargeCustomerUserListRowCustomerEditLink',
                Data => {
                    %Param,
                    CustomerKey       => $CustomerKey,
                    CustomerListEntry => $CustomerIDs->{$CustomerKey},
                },
            );
        }

        # EO KIX4OTRS-capeIT
        if ( $ConfigObject->Get('ChatEngine::Active') ) {

            # Check if agent has permission to start chats with the customer users.
            my $EnableChat = 1;
            my $ChatStartingAgentsGroup
                = $ConfigObject->Get('ChatEngine::PermissionGroup::ChatStartingAgents') || 'users';

            if (
                !defined $LayoutObject->{"UserIsGroup[$ChatStartingAgentsGroup]"}
                || $LayoutObject->{"UserIsGroup[$ChatStartingAgentsGroup]"} ne 'Yes'
                )
            {
                $EnableChat = 0;
            }
            if (
                $EnableChat
                && !$ConfigObject->Get('ChatEngine::ChatDirection::AgentToCustomer')
                )
            {
                $EnableChat = 0;
            }

            if ($EnableChat) {
                my $VideoChatEnabled = 0;
                my $VideoChatAgentsGroup
                    = $ConfigObject->Get('ChatEngine::PermissionGroup::VideoChatAgents') || 'users';

                # Enable the video chat feature if system is entitled and agent is a member of configured group.
                if (
                    defined $Self->{"UserIsGroup[$VideoChatAgentsGroup]"}
                    && $Self->{"UserIsGroup[$VideoChatAgentsGroup]"} eq 'Yes'
                    )
                {
                    if ( $Kernel::OM->Get('Kernel::System::Main')->Require( 'Kernel::System::VideoChat', Silent => 1 ) )
                    {
                        $VideoChatEnabled = $Kernel::OM->Get('Kernel::System::VideoChat')->IsEnabled();
                    }
                }

                my $CustomerEnableChat = 0;
                my $ChatAccess         = 0;
                my $VideoChatAvailable = 0;
                my $VideoChatSupport   = 0;

                # Default status is offline.
                my $UserState            = Translatable('Offline');
                my $UserStateDescription = $LayoutObject->{LanguageObject}->Translate('This user is currently offline');

                my $CustomerChatAvailability = $Kernel::OM->Get('Kernel::System::Chat')->CustomerAvailabilityGet(
                    UserID => $CustomerKey,
                );

                my %CustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
                    User => $CustomerKey,
                );
                $VideoChatSupport = 1 if $CustomerUser{VideoChatHasWebRTC};

                if ( $CustomerChatAvailability == 3 ) {
                    $UserState            = Translatable('Active');
                    $CustomerEnableChat   = 1;
                    $UserStateDescription = $LayoutObject->{LanguageObject}->Translate('This user is currently active');
                    $VideoChatAvailable   = 1;
                }
                elsif ( $CustomerChatAvailability == 2 ) {
                    $UserState            = Translatable('Away');
                    $CustomerEnableChat   = 1;
                    $UserStateDescription = $LayoutObject->{LanguageObject}->Translate('This user is currently away');
                }

                $LayoutObject->Block(
                    Name => 'ContentLargeCustomerUserListRowUserStatus',
                    Data => {
                        %CustomerUser,
                        UserState            => $UserState,
                        UserStateDescription => $UserStateDescription,
                    },
                );

                if (
                    $CustomerEnableChat
                    && $ConfigObject->Get('Ticket::Agent::StartChatWOTicket')
                    )
                {
                    $LayoutObject->Block(
                        Name => 'ContentLargeCustomerUserListRowChatIcons',
                        Data => {
                            %CustomerUser,
                            VideoChatEnabled   => $VideoChatEnabled,
                            VideoChatAvailable => $VideoChatAvailable,
                            VideoChatSupport   => $VideoChatSupport,
                        },
                    );
                }
            }
        }

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        my $TicketCountOpen = $TicketObject->TicketSearch(
            StateType            => 'Open',
            CustomerUserLoginRaw => $CustomerKey,
            Result               => 'COUNT',
            Permission           => $Self->{Config}->{Permission},
            UserID               => $Self->{UserID},
            CacheTTL             => $Self->{Config}->{CacheTTLLocal} * 60,
        );

        my $CustomerKeySQL = $Kernel::OM->Get('Kernel::System::DB')->QueryStringEscape( QueryString => $CustomerKey );

        $LayoutObject->Block(
            Name => 'ContentLargeCustomerUserListRowCustomerUserTicketsOpen',
            Data => {
                %Param,
                Count          => $TicketCountOpen,
                CustomerKey    => $CustomerKey,
                CustomerKeySQL => $CustomerKeySQL,
            },
        );

        my $TicketCountClosed = $TicketObject->TicketSearch(
            StateType            => 'closed',
            CustomerUserLoginRaw => $CustomerKey,
            Result               => 'COUNT',
            Permission           => $Self->{Config}->{Permission},
            UserID               => $Self->{UserID},
            CacheTTL             => $Self->{Config}->{CacheTTLLocal} * 60,
        );

        $LayoutObject->Block(
            Name => 'ContentLargeCustomerUserListRowCustomerUserTicketsClosed',
            Data => {
                %Param,
                Count          => $TicketCountClosed,
                CustomerKey    => $CustomerKey,
                CustomerKeySQL => $CustomerKeySQL,
            },
        );

        # KIX4OTRS-capeIT
        # see configuration for this dashboard-backend, e.g.:
        # AgentCustomerInformationCenter::Backend###0050-CIC-CustomerUserList->PhoneTicketDisabled
        # AgentCustomerInformationCenter::Backend###0050-CIC-CustomerUserList->EmailTicketDisabled
        # show/disabled new phone/email-ticket link...
        # if ($NewAgentTicketPhonePermission) {
        if ( !$Self->{Config}->{PhoneTicketDisabled} && $NewAgentTicketPhonePermission ) {

            # EO KIX4OTRS-capeIT
            $LayoutObject->Block(
                Name => 'ContentLargeCustomerUserListNewAgentTicketPhone',
                Data => {
                    %Param,
                    CustomerKey       => $CustomerKey,
                    CustomerListEntry => $CustomerIDs->{$CustomerKey},
                },
            );

            # KIX4OTRS-capeIT
        }

        # if ($NewAgentTicketEmailPermission) {
        if ( !$Self->{Config}->{EmailTicketDisabled} && $NewAgentTicketEmailPermission ) {

            # EO KIX4OTRS-capeIT
            $LayoutObject->Block(
                Name => 'ContentLargeCustomerUserListNewAgentTicketEmail',
                Data => {
                    %Param,
                    CustomerKey       => $CustomerKey,
                    CustomerListEntry => $CustomerIDs->{$CustomerKey},
                },
            );

            # KIX4OTRS-capeIT
        }

        # EO KIX4OTRS-capeIT

        if ( $ConfigObject->Get('SwitchToCustomer') && $Self->{SwitchToCustomerPermission} )
        {
            $LayoutObject->Block(
                Name => 'OverviewResultRowSwitchToCustomer',
                Data => {
                    %Param,
                    Count       => $TicketCountClosed,
                    CustomerKey => $CustomerKey,
                },
            );
        }
    }

    # show "none" if there are no customers
    if ( !%{$CustomerIDs} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeCustomerUserListNone',
            Data => {},
        );
    }

    # check for refresh time
    my $Refresh = '';
    if ( $Self->{UserRefreshTime} ) {
        $Refresh = 60 * $Self->{UserRefreshTime};
        my $NameHTML = $Self->{Name};
        $NameHTML =~ s{-}{_}xmsg;
        $LayoutObject->Block(
            Name => 'ContentLargeTicketGenericRefresh',
            Data => {
                %{ $Self->{Config} },
                Name        => $Self->{Name},
                NameHTML    => $NameHTML,
                RefreshTime => $Refresh,
                CustomerID  => $Param{CustomerID},
                # KIX4OTRS-capeIT
                CustomerUserLogin   => $Param{CustomerUserLogin},
                # EO KIX4OTRS-capeIT
            },
        );
    }

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardCustomerUserList',
        Data         => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
}

1;
