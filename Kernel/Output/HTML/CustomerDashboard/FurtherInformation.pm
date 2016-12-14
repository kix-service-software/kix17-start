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

package Kernel::Output::HTML::CustomerDashboard::FurtherInformation;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },

        # Don't cache this globally as it contains JS that is not inside of the HTML.
        CacheTTL => undef,
        CacheKey => undef,
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get preferences
    my %Preferences;
    if ( defined $Param{CustomerID} && $Param{CustomerID} ) {
        %Preferences = $Kernel::OM->Get('Kernel::System::CustomerCompany')->GetPreferences(
            UserID => $Param{CustomerID},
        );
    }
    elsif ( defined $Param{CustomerUserLogin} && $Param{CustomerUserLogin} ) {
        %Preferences = $Kernel::OM->Get('Kernel::System::CustomerUser')->GetPreferences(
            UserID => $Param{CustomerUserLogin},
        );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No CustomerUserLogin or CustomerID given!",
        );
        return;
    }
    my $Notes = $Preferences{CustomerUserDashboardFurtherInformation} || '';

    # check access
    my %Groups = $Kernel::OM->Get('Kernel::System::Group')->GroupMemberList(
        UserID => $Self->{UserID},
        Type   => 'rw',
        Result => 'HASH',
    );
    %Groups = reverse %Groups;
    my @Groups = keys %Groups;

    my $AccessRw = 0;
    my @GroupsRw = split( /,/, $Self->{Config}->{RwGroup} );
    for my $Group (@GroupsRw) {
        next if !grep { $_ eq $Group } @Groups;
        $AccessRw = 1;
        last;
    }

    if ($AccessRw) {
        $LayoutObject->Block(
            Name => 'CustomerDashboardFurtherInformationRw',
            Data => {
                CustomerUserID => $Param{CustomerID},
                CustomerLogin  => $Param{CustomerUserLogin},
                Notes => $Notes,
            },
        );
    }
    else {
        $LayoutObject->Block(
            Name => 'CustomerDashboardFurtherInformationRo',
            Data => {
                CustomerUserID => $Param{CustomerID},
                CustomerLogin  => $Param{CustomerUserLogin},
                Notes => $Notes,
            },
        );
    }

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentCustomerDashboardFurtherInformation',
        Data         => {
            %{ $Self->{Config} },
            %Param,
            CustomerUserID => $Param{CustomerID},
            CustomerLogin  => $Param{CustomerUserLogin},
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
}

1;
