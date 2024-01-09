# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::SystemMessage;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
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

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    # check if the user has preferences for this widget
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    $Self->{PrefKeyShowRead}  = 'UserDashboardPref' . $Self->{Name} . '-ShowRead';

    if ( !$Self->{ShowRead} ) {
        $Self->{ShowRead} = $Preferences{ $Self->{PrefKeyShowRead} } || '0';
    }
    else {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Self->{PrefKeyShowRead},
            Value  => $Self->{ShowRead},
        );
    }

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    my @Params = (
        {
            Desc  => Translatable('Show already read messages'),
            Name  => $Self->{PrefKeyShowRead},
            Block => 'Option',
            Data  => {
                '0' => 'No',
                '1' => 'Yes'
            },
            SelectedID  => $Self->{ShowRead} || '0',
            Translation => 1,
        }
    );

    return @Params;
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
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');

    my $Config  = $ConfigObject->Get('SystemMessage');

    # get message list
    my @MessageIDList = $SystemMessageObject->MessageSearch(
        Action          => 'AgentDashboard',
        DateCheck       => 1,
        Valid           => 1,
        IgnoreUserReads => $Self->{ShowRead},
        UserID          => $Self->{UserID},
        UserType        => $Self->{UserType},
        SortBy          => 'Created',
        OrderBy         => 'Down',
        Result          => 'ARRAY'
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

    $LayoutObject->Block(
        Name => 'DashboardSystemMessage',
        Data => {
           %{ $Self->{Config} },
           Name => $Self->{Name},
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

    # show messages
    if ( scalar(@MessageIDList) ) {
        for my $MessageID ( @MessageIDList ) {

            # get message data
            my %MessageData = $SystemMessageObject->MessageGet(
                MessageID => $MessageID,
            );

            $LayoutObject->Block(
                Name => 'DashboardRow',
                Data => \%MessageData
            );

            if ( $Config->{ShowTeaser} ) {

                $LayoutObject->Block(
                    Name => 'DashboardColumnTeaser',
                    Data => \%MessageData
                );
            }

            if ( $Config->{ShowCreatedBy} ) {

                my %UserData = $UserObject->GetUserData(
                    UserID => $MessageData{CreatedBy}
                );

                $LayoutObject->Block(
                    Name => 'DashboardColumnCreatedBy',
                    Data => \%UserData
                );
            }
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'DashboardSystemMessageNone',
        );
    }

    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardSystemMessage',
    );

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

