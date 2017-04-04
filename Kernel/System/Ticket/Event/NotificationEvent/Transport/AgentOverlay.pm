# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::NotificationEvent::Transport::AgentOverlay;
## nofilter(TidyAll::Plugin::OTRS::Perl::LayoutObject)
## nofilter(TidyAll::Plugin::OTRS::Perl::ParamObject)

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

    # prepare subject
    if (!$Param{Notification}->{Data}->{RecipientSubject}) {
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
    my $HTML = $Param{Notification}->{Subject} . '<br /><br />' . $Param{Notification}->{Body};
    my $Message = $HTMLUtilsObject->ToAscii( String => $HTML );
    $Message =~ s/\n/\\n/g;

    # prepare decay
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');
    my $Decay = $TimeObject->SystemTime() + ($Param{Notification}->{Data}->{RecipientDecay}->[0] * 60);
    if ($Param{Notification}->{Data}->{RecipientBusinessTime}->[0]) {

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
            Time      => $Param{Notification}->{Data}->{RecipientDecay}->[0] * 60,
            Calendar  => $Escalation{Calendar},
        );
    }

    # get id for overlay
    my $Success = $AgentOverlayObject->AgentOverlayAdd(
        Subject   => $Param{Notification}->{Subject},
        Message   => $Message,
        Decay     => $Decay,
        UserID    => $Recipient{UserID},
        Popup     => $Param{Notification}->{Data}->{RecipientPopup}->[0],
    );
    if ( !$Success ) {
        my $Message = "Could not add overlay for user_id $Recipient{UserID}!";

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => $Message,
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
        next KEY if !$Param{Data}->{$Key};
        next KEY if !defined $Param{Data}->{$Key}->[0];
        $Param{$Key} = $Param{Data}->{$Key}->[0];
    }

    $Param{RecipientDecay}         = $Param{RecipientDecay} || 1440;
    $Param{RecipientBusinessTime}  = ($Param{RecipientBusinessTime} || 0) ? 'checked=checked' : '';
    $Param{RecipientPopup}         = ($Param{RecipientPopup} || 0) ? 'checked=checked' : '';

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %SubjectSelection = (
        0 => 'Without Ticketnumber',
        1 => 'With Ticketnumber',
    );
    $Param{RecipientSubjectStrg} .= $LayoutObject->BuildSelection(
        Data        => \%SubjectSelection,
        Name        => 'RecipientSubject',
        Translation => 1,
        SelectedID  => $Param{Data}->{RecipientSubject} || '1',
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
        my @Data = $ParamObject->GetArray( Param => $Parameter );
        next PARAMETER if !@Data;
        $Param{GetParam}->{Data}->{$Parameter} = \@Data;
    }

    # Note: Example how to set errors and use them
    # on the normal AdminNotificationEvent screen
    # # set error
    # $Param{GetParam}->{$Parameter.'ServerError'} = 'ServerError';

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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
