# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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
            Desc  => Translatable('Shown contacts'),
            Name  => $Self->{PrefKey},
            Block => 'Option',
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

    return if !$Param{CustomerID} && !$Param{CustomerUserLogin};

    # get customer user object
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

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

    # add page nav bar
    my $Total = scalar keys %{$CustomerIDs};

    # my $LinkPage
    my $LinkPage;
    if ($CustomerIDUsed) {
        $LinkPage = 'Subaction=Element;Name='
            . $Self->{Name} . ';'
            . 'CustomerID='
            . $LayoutObject->LinkEncode( $Param{CustomerID} ) . ';';
    }
    else {
        $LinkPage
            = 'Subaction=Element;Name='
            . $Self->{Name} . ';'
            . 'CustomerLogin='
            . $LayoutObject->LinkEncode( $Param{CustomerUserLogin} ) . ';';
    }

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
            Name => 'OverviewResultEditCustomer',
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
        if ($CustomerIDUsed) {

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

            # multiple customers used
            my @CustomerIDs;
            if ( defined $CustomerUserData{UserCustomerIDs} && $CustomerUserData{UserCustomerIDs} ) {
                @CustomerIDs = split( /,/, $CustomerUserData{UserCustomerIDs} );
            }

            # add UserCustomerID from customer data hash
            if ( !scalar grep( {/$CustomerUserData{UserCustomerID}/} @CustomerIDs ) ) {
                push @CustomerIDs, $CustomerUserData{UserCustomerID};
            }

            # show all customer ids
            for my $Item (@CustomerIDs) {
                $LayoutObject->Block(
                    Name => 'ContentLargeCustomerUserListRowCompanyKeyLink',
                    Data => {
                        %Param,
                        CustomerCompanyKey => $Item,
                        CustomerListEntry  => $CustomerIDs->{$CustomerKey},
                    },
                );
            }
        }

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

        # see configuration for this dashboard-backend, e.g.:
        # AgentCustomerInformationCenter::Backend###0050-CIC-CustomerUserList->PhoneTicketDisabled
        # AgentCustomerInformationCenter::Backend###0050-CIC-CustomerUserList->EmailTicketDisabled
        # show/disabled new phone/email-ticket link...
        if ( !$Self->{Config}->{PhoneTicketDisabled} && $NewAgentTicketPhonePermission ) {

            $LayoutObject->Block(
                Name => 'ContentLargeCustomerUserListNewAgentTicketPhone',
                Data => {
                    %Param,
                    CustomerKey       => $CustomerKey,
                    CustomerListEntry => $CustomerIDs->{$CustomerKey},
                },
            );
        }

        if ( !$Self->{Config}->{EmailTicketDisabled} && $NewAgentTicketEmailPermission ) {

            $LayoutObject->Block(
                Name => 'ContentLargeCustomerUserListNewAgentTicketEmail',
                Data => {
                    %Param,
                    CustomerKey       => $CustomerKey,
                    CustomerListEntry => $CustomerIDs->{$CustomerKey},
                },
            );
        }

        if ( $ConfigObject->Get('SwitchToCustomer') && $Self->{SwitchToCustomerPermission} ) {
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
                Name              => $Self->{Name},
                NameHTML          => $NameHTML,
                RefreshTime       => $Refresh,
                CustomerID        => $Param{CustomerID},
                CustomerUserLogin => $Param{CustomerUserLogin},
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
