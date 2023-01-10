# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AsynchronousExecutor::LostPasswordExecutor;

use base qw(Kernel::System::AsynchronousExecutor);

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Email',
    'Kernel::System::User',
    'Kernel::System::CustomerUser',
    'Kernel::Output::HTML::Layout',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

#------------------------------------------------------------------------------
# BEGIN run method
#
sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Param{Subaction} eq 'PasswordSend' ) {
        return $Self->_PasswordSend(%Param);
    }
    elsif ( $Param{Subaction} eq 'TokenSend' ) {
        return $Self->_TokenSend(%Param);
    }

    return {
        Success    => 1,
        ReSchedule => 0,
    };
}

sub _PasswordSend {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $EmailObject  = $Kernel::OM->Get('Kernel::System::Email');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UserObject;

    my %UserData          = %{$Param{UserData}};
    my $PreferencesGroups;
    my $UserID;

    if ( $Param{Type} eq 'User' ) {
        $UserObject        = $Kernel::OM->Get('Kernel::System::User');
        $PreferencesGroups = $ConfigObject->Get('PreferencesGroups');
        $UserID            = 1;
    }
    else {
        $UserObject        = $Kernel::OM->Get('Kernel::System::CustomerUser');
        $PreferencesGroups = $ConfigObject->Get('CustomerPreferencesGroups');
        $UserID            = $ConfigObject->Get('CustomerPanelUserID');
    }

    # get new password
    $UserData{NewPW} = $UserObject->GenerateRandomPassword(
        Size => $PreferencesGroups->{Password}->{PasswordMinSize}
    );

    # update new password
    my $Success = $UserObject->SetPassword(
        UserLogin => $UserData{UserLogin},
        PW        => $UserData{NewPW},
        UserID    => $UserID
    );
    if ( !$Success ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "LostPassword: Reset password unsuccessful ($UserData{UserLogin})."
        );
        return {
            Success    => 0,
            ReSchedule => 0,
        };
    }

    my ($Body, $Subject) = '';
    if ( $Param{Type} eq 'User' ) {
        $Body    = $ConfigObject->Get('NotificationBodyLostPassword')
            || 'New Password is: <KIX_NEWPW>';
        $Subject = $ConfigObject->Get('NotificationSubjectLostPassword')
            || 'New Password!';
    }
    else {
        $Body    = $ConfigObject->Get('CustomerPanelBodyLostPassword')
            || 'New Password is: <KIX_NEWPW>';
        $Subject = $ConfigObject->Get('CustomerPanelSubjectLostPassword')
            || 'New Password!';
    }
    # send notify email with new password
    for ( sort keys %UserData ) {
        $Body =~ s/<(KIX|OTRS)_$_>/$UserData{$_}/gi;
    }

    # send notify email
    my $Sent = $EmailObject->Send(
        To       => $UserData{UserEmail},
        Subject  => $Subject,
        Charset  => $LayoutObject->{UserCharset},
        MimeType => 'text/plain',
        Body     => $Body
    );

    if ( !$Sent ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "LostPassword: Email could not be send ($UserData{UserLogin})."
        );
        return {
            Success    => 0,
            ReSchedule => 0,
        };
    }

    return {
        Success    => 1,
        ReSchedule => 0,
    };
}

sub _TokenSend {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $EmailObject  = $Kernel::OM->Get('Kernel::System::Email');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UserObject;

    my %UserData = %{$Param{UserData}};

    if ( $Param{Type} eq 'User' ) {
        $UserObject = $Kernel::OM->Get('Kernel::System::User');
    }
    else {
        $UserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    }

    # generate token
    $UserData{Token} = $UserObject->TokenGenerate(
        UserID => $UserData{UserID},
    );

    # prepare notify email with link
    my ($Body, $Subject) = '';
    my @ErrorLog;
    if ( $Param{Type} eq 'User' ) {
        $Body    = $ConfigObject->Get('NotificationBodyLostPasswordToken');
        $Subject = $ConfigObject->Get('NotificationSubjectLostPasswordToken');
        push( @ErrorLog, ['NotificationBodyLostPasswordToken', 'NotificationSubjectLostPasswordToken']);
    }
    else {
        $Body    = $ConfigObject->Get('CustomerPanelBodyLostPasswordToken');
        $Subject = $ConfigObject->Get('CustomerPanelSubjectLostPasswordToken');
        push( @ErrorLog, ['CustomerPanelBodyLostPasswordToken', 'CustomerPanelSubjectLostPasswordToken']);

    }
    if ( !$Body ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "LostPasswordToken: $ErrorLog[0] is missing!"
        );
        return {
            Success    => 0,
            ReSchedule => 0,
        };
    }
    if ( !$Subject ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "LostPasswordToken: $ErrorLog[1] is missing!"
        );
        return {
            Success    => 0,
            ReSchedule => 0,
        };
    }
    for ( sort keys %UserData ) {
        $Body =~ s/<(KIX|OTRS)_$_>/$UserData{$_}/gi;
    }

    # send notify email
    my $Sent = $EmailObject->Send(
        To       => $UserData{UserEmail},
        Subject  => $Subject,
        Charset  => $LayoutObject->{UserCharset},
        MimeType => 'text/plain',
        Body     => $Body
    );

    if ( !$Sent ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "LostPasswordToken: Email could not be send ($UserData{UserLogin})."
        );
        return {
            Success    => 0,
            ReSchedule => 0,
        };
    }

    return {
        Success    => 1,
        ReSchedule => 0,
    };
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
