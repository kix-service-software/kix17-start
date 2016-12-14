# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $CustomerDashboardConfig
        = $ConfigObject->Get('AgentCustomerInformationCenter::Backend');
    $Self->{DashletConfig} = $CustomerDashboardConfig->{'0270-CIC-FurtherInformation'};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my %GetParam;
    for my $Key (qw(Notes CustomerUserID CustomerLogin))
    {
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

        my $UserID;
        if ( defined $GetParam{CustomerUserID} && $GetParam{CustomerUserID} ) {
            $UserID          = $GetParam{CustomerUserID};

            $Result = $Kernel::OM->Get('Kernel::System::CustomerCompany')->SetPreferences(
                UserID => $UserID,
                Key    => 'CustomerUserDashboardFurtherInformation',
                Value  => $GetParam{Notes},
            );
        }
        elsif ( defined $GetParam{CustomerLogin} && $GetParam{CustomerLogin} ) {
            $UserID          = $GetParam{CustomerLogin};

            $Result = $Kernel::OM->Get('Kernel::System::CustomerUser')->SetPreferences(
                UserID => $UserID,
                Key    => 'CustomerUserDashboardFurtherInformation',
                Value  => $GetParam{Notes},
            );
        }
        else {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No CustomerUserLogin or CustomerID given!",
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
