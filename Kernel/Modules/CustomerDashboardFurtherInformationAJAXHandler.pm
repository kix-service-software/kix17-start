# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerDashboardFurtherInformationAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $ConfigObject            = $Kernel::OM->Get('Kernel::Config');
    my $CustomerDashboardConfig = $ConfigObject->Get('AgentCustomerInformationCenter::Backend');
    $Self->{DashletConfig}      = $CustomerDashboardConfig->{'0270-CIC-FurtherInformation'};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my %GetParam;
    for my $Key (qw(Notes CustomerID CustomerLogin)) {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
    }

    # check access
    my %Groups = $Kernel::OM->Get('Kernel::System::Group')->GroupMemberList(
        UserID => $Self->{UserID},
        Type   => 'rw',
        Result => 'HASH',
    );
    %Groups = reverse %Groups;
    my @Groups = keys %Groups;

    my $AccessRw = 0;
    my @GroupsRw = split( /,/, $Self->{DashletConfig}->{RwGroup} );
    for my $Group (@GroupsRw) {
        next if !grep { $_ eq $Group } @Groups;
        $AccessRw = 1;
        last;
    }

    # set notes as user preference
    my $Result = 0;
    if ($AccessRw) {

        if ( defined $GetParam{CustomerID} && $GetParam{CustomerID} ) {
            $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->SetPreferences(
                CustomerID => $GetParam{CustomerID},
                Key        => 'CustomerUserDashboardFurtherInformation',
                Value      => $GetParam{Notes},
            );
        }
        elsif ( defined $GetParam{CustomerLogin} && $GetParam{CustomerLogin} ) {
            $Result = $Kernel::OM->Get('Kernel::System::CustomerUser')->SetPreferences(
                UserID => $GetParam{CustomerLogin},
                Key    => 'CustomerUserDashboardFurtherInformation',
                Value  => $GetParam{Notes},
            );
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No CustomerLogin or CustomerID given!",
            );
            return;
        }
    }

    # build JSON output
    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            {
                Name => 'CustomerDashboardFurtherInformationResult',
                Data => $Result || ' ',
            },
        ],
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
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
