# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::NotificationToOutOfOfficeSubstitute;

use strict;
use warnings;

use List::Util qw(first);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::Email',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::User',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}    = $Kernel::OM->Get('Kernel::Config');
    $Self->{HTMLUtilsObject} = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    $Self->{LogObject}       = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{SendmailObject}  = $Kernel::OM->Get('Kernel::System::Email');
    $Self->{TicketObject}    = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{TimeObject}      = $Kernel::OM->Get('Kernel::System::Time');
    $Self->{UserObject}      = $Kernel::OM->Get('Kernel::System::User');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(TicketID Notification)) {
        if ( !$Param{Data}->{$_} ) {
            $Self->{LogObject}
                ->Log(
                Priority => 'error',
                Message  => "NotificationToOutOfOfficeSubstitute: Need $_!"
                );
            return;
        }
    }
    my %Notification = %{ $Param{Data}->{Notification} };

    # check if recipient data is availible
    if ( !$Param{Data}->{RecipientMail} && !$Param{Data}->{RecipientID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "NotificationToOutOfOfficeSubstitute: Need RecipientMail or RecipientID!"
        );
        return;
    }
    my %User;
    if ( $Param{Data}->{RecipientID} ) {
        %User = $Self->{UserObject}->GetUserData(
            UserID => $Param{Data}->{RecipientID},
            Valid  => 1,
        );
    }
    else {
        my %UserList = $Self->{UserObject}->UserSearch(
            PostMasterSearch => $Param{Data}->{RecipientMail},
            Valid            => 1,
        );
        for my $Agent ( keys %UserList ) {
            %User = $Self->{UserObject}->GetUserData(
                UserID => $Agent,
                Valid  => 1,
            );
            last;
        }
    }

    # check if user's out of office-time is configured
    return if !%User || !$User{OutOfOffice} || !$User{OutOfOfficeSubstitute};

    # check if user is out of office right now
    my $CurrTime  = $Self->{TimeObject}->SystemTime();
    my $StartTime = "$User{OutOfOfficeStartYear}-$User{OutOfOfficeStartMonth}-$User{OutOfOfficeStartDay} 00:00:00";
    my $EndTime   = "$User{OutOfOfficeEndYear}-$User{OutOfOfficeEndMonth}-$User{OutOfOfficeEndDay} 23:59:59";

    $StartTime = $Self->{TimeObject}->TimeStamp2SystemTime( String => $StartTime );
    $EndTime   = $Self->{TimeObject}->TimeStamp2SystemTime( String => $EndTime );

    return if ( $StartTime > $CurrTime || $EndTime < $CurrTime );

    # get substitute data
    my %SubstituteUser = $Self->{UserObject}->GetUserData(
        UserID => $User{OutOfOfficeSubstitute},
        Valid  => 1,
    );
    return if !%SubstituteUser || !$SubstituteUser{UserEmail};

    # check if the notification needs to be sent just one time per day
    if ( $Notification{Data}->{OncePerDay} ) {

        # get ticket history
        my @HistoryLines = $Self->{TicketObject}->HistoryGet(
            TicketID => $Param{Data}->{TicketID},
            UserID   => $Param{UserID},
        );

        # get last notification sent ticket history entry for substitute user
        my $LastNotificationHistory = first {
            $_->{HistoryType} eq 'SendAgentNotification'
                && $_->{Name} eq "\%\%$Notification{Name}\%\%$SubstituteUser{UserLogin} as Substitute\%\%Email"
        }
        reverse @HistoryLines;

        if (
            $LastNotificationHistory
            && $LastNotificationHistory->{CreateTime}
        ) {
            # get last notification date
            my ( $s, $m, $h, $D, $M, $Y, $WD ) = $Self->{TimeObject}->SystemTime2Date(
                SystemTime => $Self->{TimeObject}->TimeStamp2SystemTime(
                    String => $LastNotificationHistory->{CreateTime},
                )
            );

            # get current date
            my ( $Cs, $Cm, $Ch, $CD, $CM, $CY, $CWD ) = $Self->{TimeObject}->SystemTime2Date(
                SystemTime => $CurrTime,
            );

            # do not send the notification if it has been sent already today
            if (
                $CY == $Y
                && $CM == $M
                && $CD == $D
            ) {
                return;
            }
        }
    }

    # prepare notification body
    if ( $User{OutOfOfficeSubstituteNote} ) {
        if ( $Notification{ContentType} && $Notification{ContentType} eq 'text/html' ) {
            $Notification{Body} = $Self->{HTMLUtilsObject}->DocumentStrip(
                String => $Notification{Body},
            );
            $Notification{Body} = $User{OutOfOfficeSubstituteNote}
                . "<br/>**********************************************************************<br/><br/>"
                . $Notification{Body};
            $Notification{Body} = $Self->{HTMLUtilsObject}->DocumentComplete(
                String  => $Notification{Body},
                Charset => 'utf-8',
            );
        }
        else {
            $Notification{Body} = $User{OutOfOfficeSubstituteNote}
                . "\n**********************************************************************\n\n"
                . $Notification{Body};
        }
    }

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message =>
            "Sent substitute email to '$SubstituteUser{UserEmail}' for agent '$User{UserLogin}'",
    );

    # send notification to substitute
    my $Success = $Self->{SendmailObject}->Send(
        From => $Self->{ConfigObject}->Get('NotificationSenderName') . ' <'
            . $Self->{ConfigObject}->Get('NotificationSenderEmail') . '>',
        To         => $SubstituteUser{UserEmail},
        Subject    => $Notification{Subject},
        MimeType   => $Notification{ContentType} || 'text/plain',
        Charset    => 'utf-8',
        Body       => $Notification{Body},
        Loop       => 1,
        Attachment => $Param{Data}->{Attachment} || [],
    );

    if ( $Success ) {
        # write history
        $Self->{TicketObject}->HistoryAdd(
            TicketID     => $Param{Data}->{TicketID},
            HistoryType  => 'SendAgentNotification',
            Name         => "\%\%$Notification{Name}\%\%$SubstituteUser{UserLogin} as Substitute\%\%Email",
            CreateUserID => $Param{UserID},
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
