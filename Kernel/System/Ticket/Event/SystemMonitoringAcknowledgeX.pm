# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::SystemMonitoringAcknowledgeX;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

use LWP::UserAgent;
use URI::Escape qw();

our $DynamicFieldTicketTextPrefix  = 'TicketDynamicField';
our $DynamicFieldArticleTextPrefix = 'ArticleDynamicField';

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    $Self->{ConfigObject}       = $Kernel::OM->Get('Kernel::Config');

    # get correct dynamic fields
    $Self->{Fhost}    = $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Host');
    $Self->{Fservice} = $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Service');
    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event Config)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }

    if ( !$Param{Data}->{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Data->{TicketID}!",
        );

        return;
    }

    # check if acknowledge is active
    my $RelevantField = $Self->{ConfigObject}->Get('Tool::Acknowledge::RegistrationAllocation');
    my $AcknowledgeNameField = $RelevantField;
    if ($AcknowledgeNameField) {
        if ( $AcknowledgeNameField =~ /^\d+$/ ) {
            $AcknowledgeNameField = $DynamicFieldTicketTextPrefix . $AcknowledgeNameField
        }
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No DynamicField for acknowledge registration exists.",
        );
        return 1;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check if it's a system-monitoring related ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 1,
    );

    my $ConfigKey;
    if ( $Ticket{ "DynamicField_" . $AcknowledgeNameField } ) {
        $ConfigKey = $Ticket{ "DynamicField_" . $AcknowledgeNameField };
    }
    elsif ( $Ticket{$AcknowledgeNameField} ) {
        $ConfigKey = $Ticket{$AcknowledgeNameField};
    }
    else {
        $ConfigKey = $RelevantField;
    }
    return 1 if ( !$ConfigKey || $ConfigKey eq '' );

    # set host
    my $DFHost = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Host') ) {
        $DFHost
            = $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Host')
            ->{$ConfigKey};
    }
    if ( $DFHost && $DFHost =~ /^\d+$/ ) {
        $DFHost = $DynamicFieldTicketTextPrefix . $DFHost
    }
    if (!$DFHost) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => "No defined DynamicFieldHost!",
        );
        return 1;
    }

    $DFHost =~ s/DynamicField_//g;
    $Self->{Fhost} = "DynamicField_$DFHost";

    if ( !$Ticket{ $Self->{Fhost} } ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => "No Nagios Ticket!",
        );

        return 1;
    }

    # check if it's an acknowledge
    return 1 if $Ticket{Lock} ne 'lock';

    # set service
    my $FreeFieldService = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Service') ) {
        $FreeFieldService
            = $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Service')
            ->{$ConfigKey};
    }
    if ( $FreeFieldService && $FreeFieldService =~ /^\d+$/ ) {
        $FreeFieldService = $DynamicFieldTicketTextPrefix . $FreeFieldService
    }
    $FreeFieldService =~ s/DynamicField_//g;
    $Self->{Fservice} = "DynamicField_$FreeFieldService";

    # set address
    my $FreeFieldAddress = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Address') ) {
        $FreeFieldAddress
            = $Self->{ConfigObject}->Get('Tool::Acknowledge::DynamicField::Address')
            ->{$ConfigKey};
    }
    if ( $FreeFieldAddress && $FreeFieldAddress =~ /^\d+$/ ) {
        $FreeFieldAddress = $DynamicFieldTicketTextPrefix . $FreeFieldAddress
    }
    $FreeFieldAddress =~ s/DynamicField_//g;
    $Self->{Faddress} = "DynamicField_$FreeFieldAddress";

    # check if acknowledge is active
    my $Type = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::Type') ) {
        $Type = $Self->{ConfigObject}->Get('Tool::Acknowledge::Type')->{$ConfigKey};
    }
    return 1 if ( !$Type || $Type eq '' );

    # agent lookup
    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{UserID},
        Cached => 1,                # not required -> 0|1 (default 0)
    );

    my $Return;
    if ( $Type eq 'pipe' ) {
        $Return = $Self->_Pipe(

            ConfigKey => $ConfigKey,

            Ticket => \%Ticket,
            User   => \%User,
        );
    }
    elsif ( $Type eq 'http' ) {
        $Return = $Self->_HTTP(

            ConfigKey => $ConfigKey,

            Ticket => \%Ticket,
            User   => \%User,
        );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unknown Nagios acknowledge type ($Type)!",
        );

        return 1;
    }

    if ($Return) {
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Data}->{TicketID},
            HistoryType  => 'Misc',
            Name         => "Sent Acknowledge to Nagios ($Type).",
            CreateUserID => $Param{UserID},
        );

        return 1;
    }
    else {
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Data}->{TicketID},
            HistoryType  => 'Misc',
            Name         => "Was not able to send Acknowledge to Nagios ($Type)!",
            CreateUserID => $Param{UserID},
        );

        return;
    }
}

sub _Pipe {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Ticket User)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }
    my %Ticket = %{ $Param{Ticket} };
    my %User   = %{ $Param{User} };

    # send acknowledge to system monitoring
    my $CMD = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::CMD') ) {
        $CMD = $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::CMD')->{ $Param{ConfigKey} };
    }
    my $Data;
    if ( $Ticket{ $Self->{Fservice} } !~ /^host$/i ) {
        if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::NamedPipe::Service') ) {
            $Data = $Self->{ConfigObject}->Get('Tool::Acknowledge::NamedPipe::Service')
                ->{ $Param{ConfigKey} };
        }
    }
    else {
        if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::NamedPipe::Host') ) {
            $Data = $Self->{ConfigObject}->Get('Tool::Acknowledge::NamedPipe::Host')->{ $Param{ConfigKey} };
        }
    }

    # replace ticket tags
    TICKET:
    for my $Key ( sort keys %Ticket ) {
        next TICKET if !defined $Ticket{$Key};

        # strip not allowed characters
        $Ticket{$Key} =~ s/'//g;
        $Ticket{$Key} =~ s/;//g;

        $Ticket{$Key} =~ s/\r//g;

        $Data =~ s/<$Key>/$Ticket{$Key}/g;
    }

    # replace config tags
    $Data =~ s{<CONFIG_(.+?)>}{$Self->{ConfigObject}->Get($1)}egx;

    # replace login
    $Data =~ s/<LOGIN>/$User{UserLogin}/g;

    # replace host
    $Data =~ s/<HOST_NAME>/$Ticket{$Self->{Fhost}}/g;

    # replace service
    $Data =~ s/<SERVICE_NAME>/$Ticket{$Self->{Fservice}}/g;

    # replace address
    $Data =~ s/<ADDRESS_NAME>/$Ticket{$Self->{Faddress}}/g;

    # replace time stamp
    my $Time = time();
    $Data =~ s/<UNIXTIME>/$Time/g;

    # replace OUTPUTSTRING
    $CMD =~ s/<OUTPUTSTRING>/$Data/g;

    system($CMD);

    return 1;
}

sub _HTTP {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Ticket User)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );

            return;
        }
    }
    my %Ticket = %{ $Param{Ticket} };
    my %User   = %{ $Param{User} };

    my $URL = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::URL') ) {
        $URL = $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::URL')->{ $Param{ConfigKey} };
    }
    my $User = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::User') ) {
        $User = $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::User')->{ $Param{ConfigKey} };
    }
    my $Pw = "";
    if ( $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::Password') ) {
        $Pw = $Self->{ConfigObject}->Get('Tool::Acknowledge::HTTP::Password')->{ $Param{ConfigKey} };
    }

    if ( $Ticket{ $Self->{Fservice} } !~ /^host$/i ) {
        $URL =~ s/<CMD_TYP>/34/g;
    }
    else {
        $URL =~ s/<CMD_TYP>/33/g;
    }

    # replace host
    $URL =~ s/<HOST_NAME>/$Ticket{$Self->{Fhost}}/g;

    # replace service
    $URL =~ s/<SERVICE_NAME>/$Ticket{$Self->{Fservice}}/g;

    # replace address
    $URL =~ s/<ADDRESS_NAME>/$Ticket{$Self->{Faddress}}/g;

    # replace ticket tags
    TICKET:
    for my $Key ( sort keys %Ticket ) {
        next TICKET if !defined $Ticket{$Key};

        # strip not allowed chars
        $Ticket{$Key} =~ s/'//g;
        $Ticket{$Key} =~ s/;//g;

        # URLencode values
        $Ticket{$Key} = URI::Escape::uri_escape_utf8( $Ticket{$Key} );
        $URL =~ s/<$Key>/$Ticket{$Key}/g;
    }

#rbo - T2016121190001552 - added KIX placeholders
    # replace config tags
    $URL =~ s{<CONFIG_(.+?)>}{$Self->{ConfigObject}->Get($1)}egx;
    $URL =~ s{<(KIX|OTRS)_CONFIG_(.+?)>}{$Self->{ConfigObject}->Get($2)}egx;

    my $UserAgent = LWP::UserAgent->new();
    $UserAgent->timeout(15);

    my $Request = HTTP::Request->new( GET => $URL );
    $Request->authorization_basic( $User, $Pw );
    my $Response = $UserAgent->request($Request);
    if ( !$Response->is_success() ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't request $URL: " . $Response->status_line(),
        );

        return;
    }

    #    return $Response->content();
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
