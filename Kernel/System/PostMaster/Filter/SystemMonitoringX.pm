# --
# Copyright (C) 2001-2014 OTRS AG, http://otrs.com/
# Extensions Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de/
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Thomas(dot)Lange(at)cape(dash)it(dot)de
# --
# $Id$
#
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::SystemMonitoringX;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::EmailParser;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
);

# the base name for dynamic fields
# defines the name of a dynamic field even if the name is not set
our $DynamicFieldTicketTextPrefix  = 'TicketDynamicField';
our $DynamicFieldArticleTextPrefix = 'ArticleDynamicField';

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;
    $Self->{MainObject} = $Kernel::OM->Get('Kernel::System::Main');

    # parser-object needs to bei instantiated in OTRS V4-style - no workaround found yet
    $Self->{ParserObject} = Kernel::System::EmailParser->new(
        Mode => 'Standalone',
    );

    # check if it is nesessary to update CIs - load related objects
    if ( $Kernel::OM->Get('Kernel::Config')->Get('SystemMonitoringX::SetIncidentState') ) {
        if ( $Self->{MainObject}->Require('Kernel::System::GeneralCatalog') ) {
            $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
        }
        if ( $Self->{MainObject}->Require('Kernel::System::ITSMConfigItem') ) {
            $Self->{ConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
        }
    }

# Default (FALLBACK) Settings
# if new keys are updated or to be added in Kernel/Config/Files/SystemMonitoringX.xml, do the same right here
    $Self->{Config} = {
        Module                         => 'Kernel::System::PostMaster::Filter::SystemMonitoringX',
        'DynamicFieldContent::Ticket'  => 'Host,Service,Address,Alias',
        'DynamicFieldContent::Article' => 'State',

        DynamicFieldAlias   => 'SysMonXAlias',
        DynamicFieldAddress => 'SysMonXAddress',
        DynamicFieldHost    => 'SysMonXHost',
        DynamicFieldService => 'SysMonXService',
        DynamicFieldState   => 'SysMonXState',

        AcknowledgeName         => 'Nagios1',
        OTRSCreateTicketType    => 'Incident',
        OTRSCreateTicketQueue   => '',
        OTRSCreateTicketState   => '',
        OTRSCreateTicketService => '',
        OTRSCreateTicketSLA     => '',
        OTRSCreateSenderType    => 'system',
        OTRSCreateArticleType   => 'note-report',

        CloseNotIfLocked => 0,
        StopAfterMatch   => 1,

        AddressRegExp => '\s*Address:\s+(.*)\s*',
        AliasRegExp   => '\s*Alias:\s+(.*)\s*',
        FromAddressRegExp => '.*',    # always do a reaction - this differs from xml-configuration
        ToAddressRegExp =>
            '.*',  # regardless or the receipient - it is true - this differs from xml-configuration
        StateRegExp       => '\s*State:\s+(\S+)',
        HostRegExp        => '\s*Address:\s+(\d+\.\d+\.\d+\.\d+)\s*',
        ServiceRegExp     => '\s*Service:\s+(.*)\s*',
        NewTicketRegExp   => 'CRITICAL|DOWN|WARNING',
        CloseNotIfLocked  => '0',
        CloseTicketRegExp => 'OK|UP',
        CloseActionState  => 'closed successful',
        ClosePendingTime  => 60 * 60 * 24 * 2,                          # equals 2 days
        DefaultService    => 'Host',
    };

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get config options, use defaults unless value specified
    if ( $Param{JobConfig} && ref $Param{JobConfig} eq 'HASH' ) {

        for my $Key ( keys( %{ $Param{JobConfig} } ) ) {

            $Self->{Config}->{$Key} = $Param{JobConfig}->{$Key};
        }
    }

#rbo - T2016121190001552 - added KIX placeholders
    # replace KIX_CONFIG tags
    for my $Key ( keys %{ $Self->{Config} } ) {
        $Self->{Config}->{$Key} =~ s{<(KIX|OTRS)_CONFIG_(.+?)>}{$Self->{Config}->Get($2)}egx;
    }

    # see, whether to-address is of interest regarding system-monitoring
    my $ReceipientOfInterest = 0;
    if ( $Self->{Config}->{ToAddressRegExp} ) {
        my $Recipient = '';
        for my $CurrKey (qw(To Cc Resent-To)) {
            if ( $Param{GetParam}->{$CurrKey} ) {
                if ($Recipient) {
                    $Recipient .= ', ';
                }
                $Recipient .= $Param{GetParam}->{$CurrKey};
            }
        }

        my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $Recipient,
        );
        for my $CurrKey (@EmailAddresses) {
            my $Address = $Self->{ParserObject}->GetEmailAddress( Email => $CurrKey ) || '';
            if ( $Address && $Address =~ /$Self->{Config}->{ToAddressRegExp}/i ) {
                $ReceipientOfInterest = 1;
                last;
            }
        }
    }
    else {
        $ReceipientOfInterest = 1;
    }

    return 1 if !$ReceipientOfInterest;

    # check if sender is of interest
    return 1 if !$Param{GetParam}->{From};

    return 1 if $Param{GetParam}->{From} !~ /$Self->{Config}->{FromAddressRegExp}/i;
    $Self->_MailParse(%Param);

    # we need State and Host to proceed
    if ( !$Self->{State} || !$Self->{Host} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => 'SystemMonitoring Mail: '
                . 'SystemMonitoring: Could not find host address '
                . 'and/or state in mail => Ignoring',
        );

        return 1;
    }

    # Check for Service
    $Self->{Service} ||= $Self->{Config}->{DefaultService};
    # get Ticket ID
    my $TicketID = $Self->_TicketSearch();

    # OK, found ticket to deal with
    if ($TicketID) {

        $Self->_TicketUpdate(
            TicketID => $TicketID,
            Param    => \%Param,
        );
    }
    elsif ( $Self->{State} =~ /$Self->{Config}->{NewTicketRegExp}/ ) {
        $Self->_TicketCreate( \%Param );
    }
    else {
        $Self->_TicketDrop( \%Param );
    }

    return 1;
}

sub _GetDynamicFieldDefinition {
    my ( $Self, %Param ) = @_;
    for my $Argument (qw(Config Key Default Base Name ObjectType)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    my $Config     = $Param{Config};
    my $Key        = $Param{Key};          #DynamicFieldHost
    my $Default    = $Param{Default};      #1 the default value
    my $Base       = $Param{Base};         #DynamicFieldTicketTextPrefix
    my $Name       = $Param{Name};         #HostName
    my $ObjectType = $Param{ObjectType};

    my $ConfigDynamicField = $Config->{$Key};

    if ( !$ConfigDynamicField ) {
        $ConfigDynamicField = $Default;
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Missing CI Config $Key, using value $Default!"
        );
    }

    my $FieldNameHost = $ConfigDynamicField;

    if ( $ConfigDynamicField =~ /^\d+$/ ) {
        if ( ( $ConfigDynamicField < 1 ) || ( $ConfigDynamicField > 16 ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "Bad value $ConfigDynamicField for CI Config $Key, must be between 1 and 16!"
            );
            die "Bad value $ConfigDynamicField for CI Config $Key!";
        }
        $FieldNameHost = $Base . $ConfigDynamicField;
    }

    # define all dynamic fields for system monitoring, those need to be changed as well as if the
    # configuration is changed
    return (
        {
            Name       => $FieldNameHost,
            Label      => 'SystemMonitoring ' . $Name,
            FieldType  => 'Text',
            ObjectType => $ObjectType,
            Config     => {
                TranslatableValues => 1,
            },
        }
    );
}

sub GetDynamicFieldsDefinition {
    my ( $Self, %Param ) = @_;

    my $Config = $Param{Config};

    my @DynamicFieldContentTicket  = split( ',', $Config->{'DynamicFieldContent::Ticket'} );
    my @DynamicFieldContentArticle = split( ',', $Config->{'DynamicFieldContent::Article'} );

    for my $DFN (@DynamicFieldContentTicket) {
        push @{ $Param{NewFields} },
            $Self->_GetDynamicFieldDefinition(
            Config     => $Config,
            Key        => "DynamicField" . $DFN,
            Default    => 1,
            Base       => $DynamicFieldTicketTextPrefix,
            Name       => $DFN . "Name",
            ObjectType => "Ticket"
            );
    }

    for my $DFN (@DynamicFieldContentArticle) {
        push @{ $Param{NewFields} },
            $Self->_GetDynamicFieldDefinition(
            Config     => $Config,
            Key        => "DynamicField" . $DFN,
            Default    => 1,
            Base       => $DynamicFieldArticleTextPrefix,
            Name       => $DFN . "Name",
            ObjectType => "Article"
            );
    }

    return 1;
}

sub _IncidentStateIncident {
    my ( $Self, %Param ) = @_;

    # set the CI incident state to 'Incident'
    $Self->_SetIncidentState(
        Name          => $Self->{Host},
        IncidentState => 'Incident',
    );

    return 1;
}

sub _IncidentStateOperational {
    my ( $Self, %Param ) = @_;

    # set the CI incident state to 'Operational'
    $Self->_SetIncidentState(
        Name          => $Self->{Host},
        IncidentState => 'Operational',
    );

    return 1;
}

# the following are optional modules from the ITSM Kernel::System::GeneralCatalog and Kernel::System::ITSMConfigItem

sub _MailParse {
    my ( $Self, %Param ) = @_;

    if ( !$Param{GetParam} || !$Param{GetParam}->{Subject} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Subject!",
        );

        return;
    }

    my @DynamicFieldContentTicket = split( ',', $Self->{Config}->{'DynamicFieldContent::Ticket'} );
    my @DynamicFieldContentArticle
        = split( ',', $Self->{Config}->{'DynamicFieldContent::Article'} );
    my @DynamicFieldContent = ( @DynamicFieldContentTicket, @DynamicFieldContentArticle );

    my $Subject = $Param{GetParam}->{Subject};

    # Try to get State, Host and Service from email SUBJECT
    my @SubjectLines = split /\n/, $Subject;
    for my $Line (@SubjectLines) {

        for my $Item (@DynamicFieldContent) {

            if (
                $Self->{Config}->{ $Item . 'RegExp' }
                && $Line =~ /$Self->{Config}->{ $Item . 'RegExp' }/
                )
            {
                $Self->{$Item} = $1;
            }
        }
    }

    # split the body into separate lines
    my $Body = $Param{GetParam}->{Body} || die "Message has no Body";

    my @BodyLines = split /\n/, $Body;

    # to remember if an element was found before
    my %AlreadyMatched;

    LINE:
    for my $Line (@BodyLines) {

        # Try to get State, Host and Service from email BODY
        ELEMENT:

        for my $Element (@DynamicFieldContent) {
            next ELEMENT if !$Self->{Config}->{ $Element . 'RegExp' };

            next ELEMENT if $AlreadyMatched{$Element};

            my $Regex = $Self->{Config}->{ $Element . 'RegExp' };

            if ( $Line =~ /$Regex/ ) {

                # get the found element value
                $Self->{$Element} = $1;
                # remember that we found this element already
                $AlreadyMatched{$Element} = 1;
            }
        }
    }

    return 1;
}

sub _LogMessage {
    my ( $Self, %Param ) = @_;

    if ( !$Param{MessageText} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need MessageText!",
        );

        return;
    }

    my $MessageText = $Param{MessageText};

    # define log message
    $Self->{Service} ||= "No Service";
    $Self->{State}   ||= "No State";
    $Self->{Host}    ||= "No Host";
    $Self->{Address} ||= "No Address";
    $Self->{Alias}   ||= "No Alias";

    my $LogMessage = $MessageText . " - "
        . "Host: $Self->{Host}, "
        . "State: $Self->{State}, "

        . "Address: $Self->{Address}"
        . "Alias: $Self->{Alias}"

        . "Service: $Self->{Service}";

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'notice',
        Message  => 'SystemMonitoring Mail: ' . $LogMessage,
    );

    return 1;
}

sub _TicketSearch {
    my ( $Self, %Param ) = @_;

    # Is there a ticket for this Host/Service pair?
    my %Query = (
        Result    => 'ARRAY',
        Limit     => 1,
        UserID    => 1,
        StateType => 'Open',
    );

    for my $Type (qw(Host Service)) {
        my $DField = $Self->{Config}->{ 'DynamicField' . $Type };

        my $KeyName = $DField;
        if ( $DField =~ /^\d+$/ ) {
            $KeyName = $DynamicFieldTicketTextPrefix . $DField;
        }

        $KeyName = "DynamicField_$KeyName";

        my $KeyValue = $Self->{$Type};

        $Query{$KeyName}->{Equals} = $KeyValue;
    }

    # get dynamic field object
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    # Check if dynamic fields really exists.
    # If dynamic fields don't exists, TicketSearch will return all tickets
    # and then the new article/ticket could take wrong place.
    # The lesser of the three evils is to create a new ticket
    # instead of defacing existing tickets or dropping it.
    # This behavior will come true if the dynamic fields
    # are named like TicketDynamicFieldHost. Its also bad.
    my $Errors = 0;
    for my $Type (qw(Host Service)) {
        my $DField = $Self->{Config}->{ 'DynamicField' . $Type };

        if ( $DField =~ /^\d+$/ ) {
            $DField = $DynamicFieldTicketTextPrefix . $DField;
        }

        my $DynamicField = $DynamicFieldObject->DynamicFieldGet(

            Name => $DField,

        );

        if ( !IsHashRefWithData($DynamicField) ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "DynamicField "

                    . $DField
                    . " does not exists or misnamed."
                    . " The configuration is based on dynamic fields, so the number of the dynamic fields is expected"
                    . " (wrong value for dynamic field" . $Type . " is set).",
            );
            $Errors = 1;
        }
    }

    # get the first and only ticket id
    my $TicketID;

    if ( !$Errors ) {
        my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(%Query);

        if (@TicketIDs) {

            $TicketID = shift @TicketIDs;
        }
    }

    return $TicketID;
}

# the sub takes the param as a hash reference not as a copy, because it is updated
sub _TicketUpdate {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(TicketID Param)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $TicketID = $Param{TicketID};
    my $Param    = $Param{Param};

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket number
    my $TicketNumber = $TicketObject->TicketNumberLookup(
        TicketID => $TicketID,
        UserID   => 1,
    );

    # build subject
    $Param->{GetParam}->{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $TicketNumber,
        Subject      => $Param->{GetParam}->{Subject},
    );

#rbo - T2016121190001552 - renamed X-OTRS headers
    # set sender type and article type
    $Param->{GetParam}->{'X-KIX-FollowUp-SenderType'}  = $Self->{Config}->{OTRSCreateSenderType};
    $Param->{GetParam}->{'X-KIX-FollowUp-ArticleType'} = $Self->{Config}->{OTRSCreateArticleType};

    # Set Article Free Field for State
    my $ArticleDFNumber = $Self->{Config}->{'DynamicFieldState'};

    # ArticleDFNumber is a number
    if ( $ArticleDFNumber =~ /^\d+$/ ) {

#rbo - T2016121190001552 - renamed X-OTRS headers
        $Param->{GetParam}->{ 'X-KIX-FollowUp-ArticleKey' . $ArticleDFNumber } = 'State';
        $Param->{GetParam}->{ 'X-KIX-FollowUp-ArticleValue' . $ArticleDFNumber }
            = $Self->{State};
    }
    else {
        $Param->{GetParam}->{ 'X-KIX-FollowUp-DynamicField-' . $ArticleDFNumber }
            = $Self->{State};
    }

    if ( $Self->{State} =~ /$Self->{Config}->{CloseTicketRegExp}/ ) {

        if (
            $Self->{Config}->{CloseActionState} ne 'OLD'
            && !(
                $Self->{Config}->{CloseNotIfLocked}
                && $TicketObject->TicketLockGet( TicketID => $TicketID )
            )
            )
        {

#rbo - T2016121190001552 - renamed X-OTRS headers
            $Param->{GetParam}->{'X-KIX-FollowUp-State'} = $Self->{Config}->{CloseActionState};

            # get time object
            my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

            my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $TimeObject->SystemTime()
                    + $Self->{Config}->{ClosePendingTime},
            );
#rbo - T2016121190001552 - renamed X-OTRS headers
            $Param->{GetParam}->{'X-KIX-State-PendingTime'} = $TimeStamp;
        }

        # set log message
        $Self->_LogMessage( MessageText => 'Recovered' );

        # if the CI incident state should be set
        if ( $Kernel::OM->Get('Kernel::Config')->Get('SystemMonitoringX::SetIncidentState') ) {
            $Self->_IncidentStateOperational();
        }
    }
    else {

        # Attach note to existing ticket
        $Self->_LogMessage( MessageText => 'New Notice' );
    }

    # link ticket with CI, this is only possible if the ticket already exists,
    # e.g. in a subsequent email request, because we need a ticket id
    if ( $Kernel::OM->Get('Kernel::Config')->Get('SystemMonitoringX::LinkTicketWithCI') ) {

        # link ticket with CI
        $Self->_LinkTicketWithCI(
            Name     => $Self->{Host},
            TicketID => $TicketID,
        );
    }
    return 1;
}

# the sub takes the param as a hash reference not as a copy, because it is updated
sub _TicketCreate {
    my ( $Self, $Param ) = @_;

    # get Dynamic Field list
    my $DynamicFieldsTickets
        = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldList(
        Valid      => 1,
        ObjectType => 'Ticket',
        ResultType => 'HASH',
        );

    my @DynamicFieldContentTicket
        = split( ',', $Self->{Config}->{'DynamicFieldContent::Ticket'} );
    my @DynamicFieldContentArticle
        = split( ',', $Self->{Config}->{'DynamicFieldContent::Article'} );
    my @DynamicFieldContent = ( @DynamicFieldContentTicket, @DynamicFieldContentArticle );

    for my $ConfiguredDynamicField (@DynamicFieldContentTicket) {

        my $TicketDFNumber
            = $Self->{Config}->{ 'DynamicField' . $ConfiguredDynamicField };

        # identifier is a number
        if ( $TicketDFNumber =~ /^\d+$/ ) {
            $TicketDFNumber = $DynamicFieldTicketTextPrefix . $TicketDFNumber
        }
        my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
            'Name' => $TicketDFNumber,
        );
        if ( !IsHashRefWithData($DynamicField) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "DynamicField " . $TicketDFNumber
                    . " does not exists or missnamed.",
            );
        }
#rbo - T2016121190001552 - renamed X-OTRS headers
        $Param->{GetParam}->{ 'X-KIX-DynamicField-' . $TicketDFNumber }
            = $Self->{$ConfiguredDynamicField};
    }

    # Set Article Dynamic Field for State
    my $ArticleDFNumber = $Self->{Config}->{'DynamicFieldState'};

    # ArticleDFNumber is a number
    if ( $ArticleDFNumber =~ /^\d+$/ ) {

#rbo - T2016121190001552 - renamed X-OTRS headers
        $Param->{GetParam}->{ 'X-KIX-ArticleKey' . $ArticleDFNumber }   = 'State';
        $Param->{GetParam}->{ 'X-KIX-ArticleValue' . $ArticleDFNumber } = $Self->{State};
    }
    else {
        $Param->{GetParam}->{ 'X-KIX-FollowUp-DynamicField-' . $ArticleDFNumber }
            = $Self->{State};
    }

#rbo - T2016121190001552 - renamed X-OTRS headers
    # set sender type and article type
    $Param->{GetParam}->{'X-KIX-SenderType'} = $Self->{Config}->{OTRSCreateSenderType}
        || $Param->{GetParam}->{'X-KIX-SenderType'};
    $Param->{GetParam}->{'X-KIX-ArticleType'} = $Self->{Config}->{OTRSCreateArticleType}
        || $Param->{GetParam}->{'X-KIX-ArticleType'};

    $Param->{GetParam}->{'X-KIX-Queue'} = $Self->{Config}->{OTRSCreateTicketQueue}
        || $Param->{GetParam}->{'X-KIX-Queue'};
    $Param->{GetParam}->{'X-KIX-State'} = $Self->{Config}->{OTRSCreateTicketState}
        || $Param->{GetParam}->{'X-KIX-State'};
    $Param->{GetParam}->{'X-KIX-Type'} = $Self->{Config}->{OTRSCreateTicketType}
        || $Param->{GetParam}->{'X-KIX-Type'};
    $Param->{GetParam}->{'X-KIX-Service'} = $Self->{Config}->{OTRSCreateTicketService}
        || $Param->{GetParam}->{'X-KIX-Service'};
    $Param->{GetParam}->{'X-KIX-SLA'} = $Self->{Config}->{OTRSCreateTicketSLA}
        || $Param->{GetParam}->{'X-KIX-SLA'};

    # AcknowledgeNameField
    if ( $Self->{Config}->{AcknowledgeName} ) {
        my $AcknowledgeNameField
            = $Kernel::OM->Get('Kernel::Config')
            ->Get('Tool::Acknowledge::RegistrationAllocation');
        if ($AcknowledgeNameField) {
            if ( $AcknowledgeNameField =~ /^\d+$/ ) {
                $AcknowledgeNameField = $DynamicFieldTicketTextPrefix . $AcknowledgeNameField
            }
            my $DynamicField
                = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
                'Name' => $AcknowledgeNameField,
                );
            if ( !IsHashRefWithData($DynamicField) ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "DynamicField " . $AcknowledgeNameField
                        . " does not exists or missnamed.",
                );
            }
            else {
#rbo - T2016121190001552 - renamed X-OTRS headers
                $Param->{GetParam}->{ 'X-KIX-DynamicField-' . $AcknowledgeNameField }
                    = $Self->{Config}->{AcknowledgeName} || 'Nagios';
            }
        }
    }

    # set log message
    $Self->_LogMessage( MessageText => 'New Ticket' );
      $Kernel::OM->Get('Kernel::Config')->Get('SystemMonitoringX::SetIncidentState');

    # if the CI incident state should be set
    if ( $Kernel::OM->Get('Kernel::Config')->Get('SystemMonitoringX::SetIncidentState') ) {
        $Self->_IncidentStateIncident();
    }

    return 1;
}

# the sub takes the param as a hash reference not as a copy, because it is updated
sub _TicketDrop {
    my ( $Self, $Param ) = @_;

    # No existing ticket and no open condition -> drop silently
#rbo - T2016121190001552 - renamed X-OTRS headers
    $Param->{GetParam}->{'X-KIX-Ignore'} = 'yes';
    $Self->_LogMessage(
        MessageText => 'Mail Dropped, no matching ticket found, no open on this state ',
    );

    return 1;
}

sub _SetIncidentState {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name IncidentState )) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # check configitem object
    return if !$Self->{ConfigItemObject};

    # search configitem
    my $ConfigItemIDs = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
        Name => $Param{Name},
    );

    # if no config item with this name was found
    if ( !$ConfigItemIDs || ref $ConfigItemIDs ne 'ARRAY' || !@{$ConfigItemIDs} ) {

        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not find any CI with the name '$Param{Name}'. ",
        );

        return;
    }

    # if more than one config item with this name was found
    if ( scalar @{$ConfigItemIDs} > 1 ) {

        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can not set incident state for CI with the name '$Param{Name}'. "
                . "More than one CI with this name was found!",
        );

        return;
    }

    # we only found one config item
    my $ConfigItemID = shift @{$ConfigItemIDs};

    # get config item
    my $ConfigItem = $Self->{ConfigItemObject}->ConfigItemGet(
        ConfigItemID => $ConfigItemID,
    );

    # get latest version data of config item
    my $Version = $Self->{ConfigItemObject}->VersionGet(
        ConfigItemID => $ConfigItemID,
    );
    return if !$Version;
    return if ref $Version ne 'HASH';

    # get incident state list
    my $InciStateList = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::Core::IncidentState',
    );
    return if !$InciStateList;
    return if ref $InciStateList ne 'HASH';

    # reverse the incident state list
    my %ReverseInciStateList = reverse %{$InciStateList};

    # check if incident state is valid
    if ( !$ReverseInciStateList{ $Param{IncidentState} } ) {

        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid incident state '$Param{IncidentState}'!",
        );

        return;
    }

    # add a new version with the new incident state
    my $VersionID = $Self->{ConfigItemObject}->VersionAdd(
        %{$Version},
        InciStateID => $ReverseInciStateList{ $Param{IncidentState} },
        UserID      => 1,
    );
    return $VersionID;
}

sub _LinkTicketWithCI {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name TicketID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # check configitem object
    return if !$Self->{ConfigItemObject};

    # search configitem
    my $ConfigItemIDs = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
        Name => $Param{Name},
    );

    # if no config item with this name was found
    if ( !$ConfigItemIDs || ref $ConfigItemIDs ne 'ARRAY' || !@{$ConfigItemIDs} ) {

        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not find any CI with the name '$Param{Name}'. ",
        );

        return;
    }

    # if more than one config item with this name was found
    if ( scalar @{$ConfigItemIDs} > 1 ) {

        # log error
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can not set incident state for CI with the name '$Param{Name}'. "
                . "More than one CI with this name was found!",
        );

        return;
    }

    # we only found one config item
    my $ConfigItemID = shift @{$ConfigItemIDs};

    # link the ticket with the CI
    my $LinkResult = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkAdd(
        SourceObject => 'Ticket',
        SourceKey    => $Param{TicketID},
        TargetObject => 'ITSMConfigItem',
        TargetKey    => $ConfigItemID,
        Type         => 'RelevantTo',
        State        => 'Valid',
        UserID       => 1,
    );

    return $LinkResult;
}

1;
