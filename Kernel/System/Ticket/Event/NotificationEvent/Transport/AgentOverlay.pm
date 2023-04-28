# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::NotificationEvent::Transport::AgentOverlay;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Ticket::Event::NotificationEvent::Transport::Base);

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::AgentOverlay',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::Web::Request',
);

=head1 NAME

Kernel::System::Ticket::Event::NotificationEvent::Transport::AgentOverlay - AgentOverlay transport layer

=head1 SYNOPSIS

Notification event transport layer.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a notification transport object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new('');
    my $TransportObject = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent::Transport::AgentOverlay');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed prefix
    $Self->{Prefix} = 'AgentOverlay';

    return $Self;
}

sub SendNotification {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID Notification Recipient)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need $Needed!',
            );
            return;
        }
    }

    # cleanup event data
    $Self->{EventData} = undef;

    # get recipient data
    my %Recipient = %{ $Param{Recipient} };

    if ($Recipient{Type} eq 'Customer') {
        my $Message = "Transportation to customer not implemented!";

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'info',
            Message  => $Message,
        );

        return;
    }

    return if !$Recipient{UserID};

    # get objects
    my $AgentOverlayObject = $Kernel::OM->Get('Kernel::System::AgentOverlay');
    my $HTMLUtilsObject    = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');

    my %SettingData;
    for my $Key ( qw(Subject Decay BusinessTime Popup) ) {
        $SettingData{$Key} = $Param{Notification}->{Data}->{$Self->{Prefix} . 'Recipient' . $Key};
    }

    # prepare subject
    if (!$SettingData{Subject}) {
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TicketID},
        );

        $Param{Notification}->{Subject} = $TicketObject->TicketSubjectClean(
            TicketNumber => $TicketNumber,
            Subject      => $Param{Notification}->{Subject},
            Size         => 0,
        );
    }

    # prepare message
    my $HTML    = $Param{Notification}->{Subject} . '<br /><br />' . $Param{Notification}->{Body};
    my $Message = $HTMLUtilsObject->ToAscii( String => $HTML );
    $Message =~ s/\n/\\n/g;

    # prepare decay
    my $Decay = $TimeObject->SystemTime() + ($SettingData{Decay}->[0] * 60);
    if ($SettingData{BusinessTime}->[0]) {

        # get ticket
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
        );

        # get escalation preferences for calender
        my %Escalation = $TicketObject->TicketEscalationPreferences(
            Ticket => \%Ticket,
            UserID => $Param{UserID},
        );

        # calculate target
        $Decay = $TimeObject->DestinationTime(
            StartTime => $TimeObject->SystemTime(),
            Time      => $SettingData{Decay}->[0] * 60,
            Calendar  => $Escalation{Calendar},
        );
    }

    # get id for overlay
    my $Success = $AgentOverlayObject->AgentOverlayAdd(
        Subject   => $Param{Notification}->{Subject},
        Message   => $Message,
        Decay     => $Decay,
        UserID    => $Recipient{UserID},
        Popup     => $SettingData{Popup}->[0],
    );

    if ( !$Success ) {
        my $ErrorMessage = "Could not add overlay for user_id $Recipient{UserID}!";

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $ErrorMessage,
        );

        return;
    }

    return 1;
}

sub GetTransportRecipients {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Notification)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed",
            );
        }
    }

    my @Recipients;

    return @Recipients;
}

sub TransportSettingsDisplayGet {
    my ( $Self, %Param ) = @_;

    KEY:
    for my $Key (qw(RecipientDecay RecipientBusinessTime RecipientPopup)) {
        next KEY if !$Param{Data}->{$Self->{Prefix} . $Key};
        next KEY if !defined $Param{Data}->{$Self->{Prefix} . $Key}->[0];
        $Param{$Key} = $Param{Data}->{$Self->{Prefix} . $Key}->[0];
    }

    $Param{$Self->{Prefix} . 'RecipientDecay'}         = $Param{RecipientDecay}         || 1440;
    $Param{$Self->{Prefix} . 'RecipientBusinessTime'}  = ($Param{RecipientBusinessTime} || 0) ? 'checked=checked' : '';
    $Param{$Self->{Prefix} . 'RecipientPopup'}         = ($Param{RecipientPopup}        || 0) ? 'checked=checked' : '';

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %SubjectSelection = (
        0 => 'Without Ticketnumber',
        1 => 'With Ticketnumber',
    );
    $Param{$Self->{Prefix} . 'RecipientSubjectStrg'} .= $LayoutObject->BuildSelection(
        Data        => \%SubjectSelection,
        Name        => $Self->{Prefix} . 'RecipientSubject',
        Translation => 1,
        SelectedID  => $Param{Data}->{$Self->{Prefix} . 'RecipientSubject'} || '1',
        Sort        => 'AlphanumericID',
    );

    # generate HTML
    my $Output       = $LayoutObject->Output(
        TemplateFile => 'AdminNotificationEventTransportAgentOverlaySettings',
        Data         => \%Param,
    );

    return $Output;
}

sub TransportParamSettingsGet {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(GetParam)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed",
            );
        }
    }

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    PARAMETER:
    for my $Parameter (qw(RecipientDecay RecipientBusinessTime RecipientPopup RecipientSubject)) {
        my @Data = $ParamObject->GetArray( Param => $Self->{Prefix} . $Parameter );
        next PARAMETER if !@Data;
        $Param{GetParam}->{Data}->{$Self->{Prefix} . $Parameter} = \@Data;
    }

    return 1;
}

sub IsUsable {
    my ( $Self, %Param ) = @_;

    # define if this transport is usable on
    # this specific moment
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
