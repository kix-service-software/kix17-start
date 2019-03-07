# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::SystemMessage;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Group',
    'Kernel::System::User',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::SystemMessage',
    'Kernel::System::JSON'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

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
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $GroupObject         = $Kernel::OM->Get('Kernel::System::Group');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');

    my $Config  = $ConfigObject->Get('SystemMessage');
    my $GroupID = $GroupObject->GroupLookup(
        Group => $Config->{GroupDashboard} || 'admin'
    );

    # get user groups
    my %GroupIDs  = $GroupObject->GroupMemberList(
        UserID => $Self->{UserID},
        Type   => 'rw',
        Result => 'HASH'
    );

    # get message list
    my @MessageIDList = $SystemMessageObject->MessageSearch(
        DateCheck => 1,
        Valid     => 1,
        UserID    => $Self->{UserID},
        UserType  => $Self->{UserType},
        SortBy    => 'Created',
        OrderBy   => 'Down',
        Result    => 'ARRAY'
    );

    # get user preferences
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    my %UserReads;
    if ( $Preferences{UserMessageRead} ) {
        my $JSONData = $JSONObject->Decode(
            Data => $Preferences{UserMessageRead}
        );
        %UserReads = %{$JSONData};
    }

    my $ForceDialog;
    my @MessageDataList;
    for my $MessageID ( @MessageIDList ) {

        # get message data
        my %MessageData = $SystemMessageObject->MessageGet(
            MessageID => $MessageID,
        );

        if (
            $MessageData{UsedDashboard}
            && !$ForceDialog
            && !$UserReads{$MessageID}
        ) {
            $ForceDialog = $MessageID;
        }

        push(@MessageDataList, \%MessageData);
    }

    $LayoutObject->Block(
        Name => 'DashboardSystemMessage',
        Data => {
           %{ $Self->{Config} },
           ForceDialog => $ForceDialog,
        },
    );

    if ( $Config->{ShowTeaser} ) {
        $LayoutObject->Block(
            Name => 'DashboardHeadTeaser',
        );
    }

    if ( $Config->{ShowCreatedBy} ) {
        $LayoutObject->Block(
            Name => 'DashboardHeadCreatedBy',
        );
    }

    if (
        $Config->{EditOnDashboard}
        && $GroupIDs{$GroupID}
    ) {
        $LayoutObject->Block(
            Name => 'DashboardHeadEdit',
        );
    }

    if (
        $Config->{DeleteOnDashboard}
        && $GroupIDs{$GroupID}
    ) {
        $LayoutObject->Block(
            Name => 'DashboardHeadDelete',
        );
    }

    # show messages
    my $Output = '';
    for my $MessageData ( @MessageDataList ) {

        $LayoutObject->Block(
            Name => 'DashboardRow',
            Data => $MessageData
        );

        if ( $Config->{ShowTeaser} ) {

            $LayoutObject->Block(
                Name => 'DashboardColumnTeaser',
                Data => $MessageData
            );
        }

        if ( $Config->{ShowCreatedBy} ) {

            my %UserData = $UserObject->GetUserData(
                UserID => $MessageData->{CreatedBy}
            );

            $LayoutObject->Block(
                Name => 'DashboardColumnCreatedBy',
                Data => \%UserData
            );
        }

        if (
            $Config->{EditOnDashboard}
            && $GroupIDs{$GroupID}
        ) {
            $LayoutObject->Block(
                Name => 'DashboardColumnEdit',
                Data => $MessageData
            );
        }

        if (
            $Config->{DeleteOnDashboard}
            && $GroupIDs{$GroupID}
        ) {
            $LayoutObject->Block(
                Name => 'DashboardColumnDelete',
                Data => $MessageData
            );
        }
    }

    # check if content got shown, if true, render block
    if (scalar(@MessageIDList)) {
        $Output = $LayoutObject->Output(
            TemplateFile => 'AgentDashboardSystemMessage',
            Data         => {
                %{ $Self->{Config} },
            },
        );
    }

    # return content
    return $Output;
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

