# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get preferences
    my %Preferences;
    if ( defined $Param{CustomerID} && $Param{CustomerID} ) {
        my %CustomerCompany = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $Param{CustomerID},
        );
        return if ( !%CustomerCompany );

        %Preferences = $Kernel::OM->Get('Kernel::System::CustomerCompany')->GetPreferences(
            CustomerID => $Param{CustomerID},
        );
    }
    elsif ( defined $Param{CustomerUserLogin} && $Param{CustomerUserLogin} ) {
        my %CustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $Param{CustomerUserLogin},
        );
        return if ( !%CustomerUser );

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
                CustomerID    => $Param{CustomerID},
                CustomerLogin => $Param{CustomerUserLogin},
                Notes         => $Notes,
            },
        );
    }
    else {
        $LayoutObject->Block(
            Name => 'CustomerDashboardFurtherInformationRo',
            Data => {
                CustomerID    => $Param{CustomerID},
                CustomerLogin => $Param{CustomerUserLogin},
                Notes         => $Notes,
            },
        );
    }

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentCustomerDashboardFurtherInformation',
        Data         => {
            %{ $Self->{Config} },
            %Param,
            CustomerID    => $Param{CustomerID},
            CustomerLogin => $Param{CustomerUserLogin},
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
