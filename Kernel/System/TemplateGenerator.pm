# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::TemplateGenerator;

use strict;
use warnings;

use POSIX qw(strftime);

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::EmailParser;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::AutoResponse',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Encode',
    'Kernel::System::HTMLUtils',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::Salutation',
    'Kernel::System::Signature',
    'Kernel::System::StandardTemplate',
    'Kernel::System::SystemAddress',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::TemplateGenerator - signature lib

=head1 SYNOPSIS

All signature functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{RichText} = $Kernel::OM->Get('Kernel::Config')->Get('Frontend::RichText');

    $Self->{UserLanguage} = $Param{UserLanguage};

    return $Self;
}

=item Salutation()

generate salutation

    my $Salutation = $TemplateGeneratorObject->Salutation(
        TicketID => 123,
        UserID   => 123,
        Data     => $ArticleHashRef,
    );

returns
    Text
    ContentType

=cut

sub Salutation {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $TicketObject        = $Kernel::OM->Get('Kernel::System::Ticket');
    my $QueueObject         = $Kernel::OM->Get('Kernel::System::Queue');
    my $SalutationObject    = $Kernel::OM->Get('Kernel::System::Salutation');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $HTMLUtilsObject     = $Kernel::OM->Get('Kernel::System::HTMLUtils');

    # check needed stuff
    for (qw(TicketID Data UserID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get  queue
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get salutation
    my %Queue = $QueueObject->QueueGet(
        ID => $Ticket{QueueID},
    );
    my %Salutation = $SalutationObject->SalutationGet(
        ID => $Queue{SalutationID},
    );

    # do text/plain to text/html convert
    if ( $Self->{RichText} && $Salutation{ContentType} =~ /text\/plain/i ) {
        $Salutation{ContentType} = 'text/html';
        $Salutation{Text}        = $HTMLUtilsObject->ToHTML(
            String => $Salutation{Text},
        );
    }

    # do text/html to text/plain convert
    if ( !$Self->{RichText} && $Salutation{ContentType} =~ /text\/html/i ) {
        $Salutation{ContentType} = 'text/plain';
        $Salutation{Text}        = $HTMLUtilsObject->ToAscii(
            String => $Salutation{Text},
        );
    }

    # replace place holder stuff
    my @ListOfUnSupportedTag = qw/KIX_AGENT_SUBJECT KIX_AGENT_BODY KIX_CUSTOMER_BODY KIX_CUSTOMER_SUBJECT OTRS_AGENT_SUBJECT OTRS_AGENT_BODY OTRS_CUSTOMER_BODY OTRS_CUSTOMER_SUBJECT/;

    my $SalutationText = $Self->_RemoveUnSupportedTag(
        Text => $Salutation{Text} || '',
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

    # replace place holder stuff
    $SalutationText = $Self->_Replace(
        RichText  => $Self->{RichText},
        Text      => $SalutationText,
        TicketID  => $Param{TicketID},
        Data      => $Param{Data},
        UserID    => $Param{UserID},
        ArticleID => $Param{Data}->{ArticleID} || '',
    );

    # add urls
    if ( $Self->{RichText} ) {
        $SalutationText = $HTMLUtilsObject->LinkQuote(
            String => $SalutationText,
        );
    }

    return $SalutationText;
}

=item Signature()

generate salutation

    my $Signature = $TemplateGeneratorObject->Signature(
        TicketID => 123,
        UserID   => 123,
        Data     => $ArticleHashRef,
    );

or

    my $Signature = $TemplateGeneratorObject->Signature(
        QueueID => 123,
        UserID  => 123,
        Data    => $ArticleHashRef,
    );

returns
    Text
    ContentType

=cut

sub Signature {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $HTMLUtilsObject     = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $QueueObject         = $Kernel::OM->Get('Kernel::System::Queue');
    my $SignatureObject     = $Kernel::OM->Get('Kernel::System::Signature');
    my $TicketObject        = $Kernel::OM->Get('Kernel::System::Ticket');

    # check needed stuff
    for (qw(Data UserID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # need ticket id or queue id
    if ( !$Param{TicketID} && !$Param{QueueID} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'Need TicketID or QueueID!'
        );
        return;
    }

    # get salutation ticket based
    my %Queue;
    if ( $Param{TicketID} ) {

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );

        %Queue = $QueueObject->QueueGet(
            ID => $Ticket{QueueID},
        );
    }

    # get salutation queue based
    else {
        %Queue = $QueueObject->QueueGet(
            ID => $Param{QueueID},
        );
    }

    # get signature
    my %Signature = $SignatureObject->SignatureGet(
        ID => $Queue{SignatureID},
    );

    # do text/plain to text/html convert
    if ( $Self->{RichText} && $Signature{ContentType} =~ /text\/plain/i ) {
        $Signature{ContentType} = 'text/html';
        $Signature{Text}        = $HTMLUtilsObject->ToHTML(
            String => $Signature{Text},
        );
    }

    # do text/html to text/plain convert
    if ( !$Self->{RichText} && $Signature{ContentType} =~ /text\/html/i ) {
        $Signature{ContentType} = 'text/plain';
        $Signature{Text}        = $HTMLUtilsObject->ToAscii(
            String => $Signature{Text},
        );
    }

    # replace place holder stuff
    my @ListOfUnSupportedTag = qw/KIX_AGENT_SUBJECT KIX_AGENT_BODY KIX_CUSTOMER_BODY KIX_CUSTOMER_SUBJECT OTRS_AGENT_SUBJECT OTRS_AGENT_BODY OTRS_CUSTOMER_BODY OTRS_CUSTOMER_SUBJECT/;

    my $SignatureText = $Self->_RemoveUnSupportedTag(
        Text => $Signature{Text} || '',
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

    # replace place holder stuff
    $SignatureText = $Self->_Replace(
        RichText    => $Self->{RichText},
        Text        => $SignatureText,
        TicketID    => $Param{TicketID} || '',
        Data        => $Param{Data},
        QueueID     => $Param{QueueID},
        UserID      => $Param{UserID},
        ArticleID   => $Param{Data}->{ArticleID} || ''
    );

    # add urls
    if ( $Self->{RichText} ) {
        $SignatureText = $HTMLUtilsObject->LinkQuote(
            String => $SignatureText,
        );
    }

    return $SignatureText;
}

=item Sender()

generate sender address (FROM string) for emails

    my $Sender = $TemplateGeneratorObject->Sender(
        QueueID    => 123,
        UserID     => 123,
    );

returns:

    John Doe at Super Support <service@example.com>

and it returns the quoted real name if necessary

    "John Doe, Support" <service@example.tld>

=cut

sub Sender {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $QueueObject     = $Kernel::OM->Get('Kernel::System::Queue');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');

    # check needed stuff
    for (qw( UserID QueueID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get sender attributes
    my %Address = $QueueObject->GetSystemAddress(
        QueueID => $Param{QueueID},
    );

    # check config for agent real name
    my $UseAgentRealName = $ConfigObject->Get('Ticket::DefineEmailFrom');

    # get data from current agent
    my %UserData = $UserObject->GetUserData(
        UserID        => $Param{UserID},
        NoOutOfOffice => 1,
    );

    # use config for agent real name if agent preference is set
    if ( $UserData{'TicketDefineEmailFrom'} ) {
        $UseAgentRealName = $UserData{'TicketDefineEmailFrom'};
    }

    # prepare real name
    if ( $UseAgentRealName && $UseAgentRealName =~ /^(AgentName|AgentNameSystemAddressName)$/ ) {

        # set real name with user name
        if ( $UseAgentRealName eq 'AgentName' ) {

            # check for user data
            if ( $UserData{UserLastname} && $UserData{UserFirstname} ) {

                # rewrite RealName
                $Address{RealName} = "$UserData{UserFirstname} $UserData{UserLastname}";
            }
        }

        # set real name with user name
        if ( $UseAgentRealName eq 'AgentNameSystemAddressName' ) {

            # check for user data
            if ( $UserData{UserLastname} && $UserData{UserFirstname} ) {

                # rewrite RealName
                my $Separator = ' ' . $ConfigObject->Get('Ticket::DefineEmailFromSeparator')
                    || '';
                $Address{RealName} = $UserData{UserFirstname} . ' ' . $UserData{UserLastname}
                    . $Separator . ' ' . $Address{RealName};
            }
        }
    }

    # prepare realname quote
    if ( $Address{RealName} =~ /(?:[.]|,|@|\(|\)|:)/ && $Address{RealName} !~ /^(?:"|')/ ) {
        $Address{RealName} =~ s/"//g;    # remove any quotes that are already present
        $Address{RealName} = '"' . $Address{RealName} . '"';
    }
    my $Sender = "$Address{RealName} <$Address{Email}>";

    return $Sender;
}

=item Template()

generate template

    my $Template = $TemplateGeneratorObject->Template(
        TemplateID => 123
        TicketID   => 123,                  # Optional
        Data       => $ArticleHashRef,      # Optional
        UserID     => 123,
    );

Returns:

    $Template =>  'Some text';

=cut

sub Template {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $CustomerUserObject  = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $HTMLUtilsObject     = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $TemplateObject      = $Kernel::OM->Get('Kernel::System::StandardTemplate');
    my $TicketObject        = $Kernel::OM->Get('Kernel::System::Ticket');

    # check needed stuff
    for (qw(TemplateID UserID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get user language
    my $Language;
    if ( defined $Param{TicketID} ) {

        # get ticket data
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
        );

        # check if template is member of ticket queue
        my %StandardTemplates = $Kernel::OM->Get('Kernel::System::Queue')->QueueStandardTemplateMemberList(
            QueueID       => $Ticket{QueueID},
            TemplateTypes => 0,
        );
        return '' if ( !$StandardTemplates{ $Param{TemplateID} } );

        # get recipient
        my %User = $CustomerUserObject->CustomerUserDataGet(
            User => $Ticket{CustomerUserID},
        );
        $Language = $User{UserLanguage};
    }

    # if customer language is not defined, set default language
    $Language //= $ConfigObject->Get('DefaultLanguage') || 'en';

    my %Template = $TemplateObject->StandardTemplateGet(
        ID => $Param{TemplateID},
    );

    # do text/plain to text/html convert
    if (
        $Self->{RichText}
        && $Template{ContentType} =~ /text\/plain/i
        && $Template{Template}
    ) {
        $Template{ContentType} = 'text/html';
        $Template{Template}    = $HTMLUtilsObject->ToHTML(
            String => $Template{Template},
        );
    }

    # do text/html to text/plain convert
    if (
        !$Self->{RichText}
        && $Template{ContentType} =~ /text\/html/i
        && $Template{Template}
    ) {
        $Template{ContentType} = 'text/plain';
        $Template{Template}    = $HTMLUtilsObject->ToAscii(
            String => $Template{Template},
        );
    }

    # replace place holder stuff
    my @ListOfUnSupportedTag = qw/KIX_AGENT_SUBJECT KIX_AGENT_BODY KIX_CUSTOMER_BODY KIX_CUSTOMER_SUBJECT OTRS_AGENT_SUBJECT OTRS_AGENT_BODY OTRS_CUSTOMER_BODY OTRS_CUSTOMER_SUBJECT/;

    my $TemplateText = $Self->_RemoveUnSupportedTag(
        Text                 => $Template{Template} || '',
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

    # replace place holder stuff
    $TemplateText = $Self->_Replace(
        RichText  => $Self->{RichText},
        Text      => $TemplateText      || '',
        TicketID  => $Param{TicketID}   || '',
        Data      => $Param{Data}       || {},
        ArticleID => $Param{ArticleID}  || '',
        UserID    => $Param{UserID},
        Language  => $Language,
    );

    return $TemplateText;
}

=item Attributes()

generate attributes

    my %Attributes = $TemplateGeneratorObject->Attributes(
        TicketID   => 123,
        ArticleID  => 123,
        ResponseID => 123
        UserID     => 123,
        Action     => 'Forward', # Possible values are Reply and Forward, Reply is default.
    );

returns
    StandardResponse
    Salutation
    Signature

=cut

sub Attributes {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');

    # check needed stuff
    for (qw(TicketID Data UserID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get queue
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # prepare subject ...
    $Param{Data}->{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $Param{Data}->{Subject} || '',
        Action       => $Param{Action}          || '',
    );

    # get sender address
    $Param{Data}->{From} = $Self->Sender(
        QueueID => $Ticket{QueueID},
        UserID  => $Param{UserID},
    );

    return %{ $Param{Data} };
}

=item AutoResponse()

generate response

AutoResponse
    TicketID
        Owner
        Responsible
        CUSTOMER_DATA
    ArticleID
        CUSTOMER_SUBJECT
        CUSTOMER_EMAIL
    UserID

    To
    Cc
    Bcc
    Subject
    Body
    ContentType

    my %AutoResponse = $TemplateGeneratorObject->AutoResponse(
        TicketID         => 123,
        OrigHeader       => {},
        AutoResponseType => 'auto reply',
        UserID           => 123,
    );

=cut

sub AutoResponse {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $AutoResponseObject  = $Kernel::OM->Get('Kernel::System::AutoResponse');
    my $CustomerUserObject  = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $HTMLUtilsObject     = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $QueueObject         = $Kernel::OM->Get('Kernel::System::Queue');
    my $SystemAddressObject = $Kernel::OM->Get('Kernel::System::SystemAddress');
    my $TicketObject        = $Kernel::OM->Get('Kernel::System::Ticket');

    # check needed stuff
    for (qw(TicketID AutoResponseType OrigHeader UserID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get auto default responses
    my %AutoResponse = $AutoResponseObject->AutoResponseGetByTypeQueueID(
        QueueID => $Ticket{QueueID},
        Type    => $Param{AutoResponseType},
    );

    return if !%AutoResponse;

    # get old article for quoting
    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    for (qw(From To Cc Subject Body)) {
        if ( !$Param{OrigHeader}->{$_} ) {
            $Param{OrigHeader}->{$_} = $Article{$_} || '';
        }
        chomp $Param{OrigHeader}->{$_};
    }

    # format body (only if longer than 86 chars)
    if ( $Param{OrigHeader}->{Body} ) {
        if ( length $Param{OrigHeader}->{Body} > 86 ) {
            my @Lines = split /\n/, $Param{OrigHeader}->{Body};
            LINE:
            for my $Line (@Lines) {
                my $LineWrapped = $Line =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;

                next LINE if $LineWrapped;

                # if the regex does not match then we need
                # to add the missing new line of the split
                # else we will lose e.g. empty lines of the body.
                # (bug#10679)
                $Line .= "\n";
            }
            $Param{OrigHeader}->{Body} = join '', @Lines;
        }
    }

    # fill up required attributes
    for (qw(Subject Body)) {
        if ( !$Param{OrigHeader}->{$_} ) {
            $Param{OrigHeader}->{$_} = "No $_";
        }
    }

    # get recipient
    my %User = $CustomerUserObject->CustomerUserDataGet(
        User => $Ticket{CustomerUserID},
    );

    # get user language
    my $Language = $User{UserLanguage} || $ConfigObject->Get('DefaultLanguage') || 'en';

    # do text/plain to text/html convert
    if ( $Self->{RichText} && $AutoResponse{ContentType} =~ /text\/plain/i ) {
        $AutoResponse{ContentType} = 'text/html';
        $AutoResponse{Text}        = $HTMLUtilsObject->ToHTML(
            String => $AutoResponse{Text},
        );
    }

    # do text/html to text/plain convert
    if ( !$Self->{RichText} && $AutoResponse{ContentType} =~ /text\/html/i ) {
        $AutoResponse{ContentType} = 'text/plain';
        $AutoResponse{Text}        = $HTMLUtilsObject->ToAscii(
            String => $AutoResponse{Text},
        );
    }

    # replace place holder stuff
    $AutoResponse{Text} = $Self->_Replace(
        RichText    => $Self->{RichText},
        Text        => $AutoResponse{Text},
        Data        => {
            %{ $Param{OrigHeader} },
            From => $Param{OrigHeader}->{To},
            To   => $Param{OrigHeader}->{From},
        },
        TicketID    => $Param{TicketID},
        UserID      => $Param{UserID},
        Language    => $Language,
        ArticleID   => $Article{ArticleID}
    );
    $AutoResponse{Subject} = $Self->_Replace(
        RichText    => 0,
        Text        => $AutoResponse{Subject},
        Data        => {
            %{ $Param{OrigHeader} },
            From => $Param{OrigHeader}->{To},
            To   => $Param{OrigHeader}->{From},
        },
        TicketID    => $Param{TicketID},
        UserID      => $Param{UserID},
        Language    => $Language,
        ArticleID   => $Article{ArticleID}
    );

    $AutoResponse{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $AutoResponse{Subject},
        Type         => 'New',
        NoCleanup    => 1,
    );

    # get sender attributes based on auto response type
    if ( $AutoResponse{SystemAddressID} ) {

        my %Address = $SystemAddressObject->SystemAddressGet(
            ID => $AutoResponse{SystemAddressID},
        );

        $AutoResponse{SenderAddress}  = $Address{Name};
        $AutoResponse{SenderRealname} = $Address{Realname};
    }

    # get sender attributes based on queue
    else {

        my %Address = $QueueObject->GetSystemAddress(
            QueueID => $Ticket{QueueID},
        );

        $AutoResponse{SenderAddress}  = $Address{Email};
        $AutoResponse{SenderRealname} = $Address{RealName};
    }

    # add urls and verify to be full html document
    if ( $Self->{RichText} ) {

        $AutoResponse{Text} = $HTMLUtilsObject->LinkQuote(
            String => $AutoResponse{Text},
        );

        $AutoResponse{Text} = $HTMLUtilsObject->DocumentComplete(
            Charset => 'utf-8',
            String  => $AutoResponse{Text},
        );
    }

    return %AutoResponse;
}

=item NotificationEvent()

replace all KIX smart tags in the notification body and subject

    my %NotificationEvent = $TemplateGeneratorObject->NotificationEvent(
        TicketID              => 123,
        Recipient             => $UserDataHashRef,          # Agent or Customer data get result
        Notification          => $NotificationDataHashRef,
        CustomerMessageParams => $ArticleHashRef,           # optional
        UserID                => 123,
    );

=cut

sub NotificationEvent {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $HTMLUtilsObject     = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject        = $Kernel::OM->Get('Kernel::System::Ticket');

    # check needed stuff
    for my $Needed (qw(TicketID Notification Recipient UserID)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !IsHashRefWithData( $Param{Notification} ) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Notification is invalid!",
        );
        return;
    }

    my %Notification = %{ $Param{Notification} };

    # exchanging original reference prevent it to grow up
    if ( ref $Param{CustomerMessageParams} && ref $Param{CustomerMessageParams} eq 'HASH' ) {
        my %LocalCustomerMessageParams = %{ $Param{CustomerMessageParams} };
        $Param{CustomerMessageParams} = \%LocalCustomerMessageParams;
    }

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get last article from customer
    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get last article from agent
    my @ArticleBoxAgent = $TicketObject->ArticleGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    my %ArticleAgent;

    ARTICLE:
    for my $Article ( reverse @ArticleBoxAgent ) {

        next ARTICLE if $Article->{SenderType} ne 'agent';

        %ArticleAgent = %{$Article};

        last ARTICLE;
    }

    # set the accounted time as part of the articles information
    ARTICLE:
    for my $ArticleData ( \%Article, \%ArticleAgent ) {

        next ARTICLE if !$ArticleData->{ArticleID};

        # get accounted time
        my $AccountedTime = $TicketObject->ArticleAccountedTimeGet(
            ArticleID => $ArticleData->{ArticleID},
        );

        $ArticleData->{TimeUnit} = $AccountedTime;
    }

    # get system default language
    my $DefaultLanguage = $ConfigObject->Get('DefaultLanguage') || 'en';
    my $Languages       = [ $Param{Recipient}->{UserLanguage}, $DefaultLanguage, 'en' ];

    my $Language;
    LANGUAGE:
    for my $Item ( @{$Languages} ) {
        next LANGUAGE if !$Item;
        next LANGUAGE if !$Notification{Message}->{$Item};

        # set language
        $Language = $Item;
        last LANGUAGE;
    }

    # if no language, then take the first one available
    if ( !$Language ) {
        my @NotificationLanguages = sort keys %{ $Notification{Message} };
        $Language = $NotificationLanguages[0];
    }

    # copy the correct language message attributes to a flat structure
    for my $Attribute (qw(Subject Body ContentType)) {
        $Notification{$Attribute} = $Notification{Message}->{$Language}->{$Attribute};
    }

    for my $Key (qw(From To Cc Subject Body ContentType ArticleType)) {
        if ( !$Param{CustomerMessageParams}->{$Key} ) {
            $Param{CustomerMessageParams}->{$Key} = $Article{$Key} || '';
        }
        chomp $Param{CustomerMessageParams}->{$Key};
    }

    # format body (only if longer the 86 chars)
    if ( $Param{CustomerMessageParams}->{Body} ) {
        if ( length $Param{CustomerMessageParams}->{Body} > 86 ) {
            my @Lines = split /\n/, $Param{CustomerMessageParams}->{Body};
            LINE:
            for my $Line (@Lines) {
                my $LineWrapped = $Line =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;

                next LINE if $LineWrapped;

                # if the regex does not match then we need
                # to add the missing new line of the split
                # else we will lose e.g. empty lines of the body.
                # (bug#10679)
                $Line .= "\n";
            }
            $Param{CustomerMessageParams}->{Body} = join '', @Lines;
        }
    }

    # get customer article data for replacing
    # (KIX_COMMENT and KIX_CUSTOMER_BODY and KIX_CUSTOMER_EMAIL could be the same)
    $Param{CustomerMessageParams}->{CustomerBody} = $Article{Body} || '';
    if (
        $Param{CustomerMessageParams}->{CustomerBody}
        && length $Param{CustomerMessageParams}->{CustomerBody} > 86
    ) {
        $Param{CustomerMessageParams}->{CustomerBody} =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;
    }

    # fill up required attributes
    for my $Text (qw(Subject Body)) {
        if ( !$Param{CustomerMessageParams}->{$Text} ) {
            $Param{CustomerMessageParams}->{$Text} = "No $Text";
        }
    }

    my $Start = '<';
    my $End   = '>';
    if ( $Notification{ContentType} =~ m{text\/html} ) {
        $Start = '&lt;';
        $End   = '&gt;';
    }

    # replace <KIX_CUSTOMER_DATA_*> tags early from CustomerMessageParams, the rests will be replaced
    # by ticket customer user
    KEY:
    for my $Key ( sort keys %{ $Param{CustomerMessageParams} || {} } ) {

        next KEY if !$Param{CustomerMessageParams}->{$Key};

        $Notification{Body} =~ s/${Start}(KIX|OTRS)_CUSTOMER_DATA_$Key${End}/$Param{CustomerMessageParams}->{$Key}/gi;
        $Notification{Subject} =~ s/<(KIX|OTRS)_CUSTOMER_DATA_$Key>/$Param{CustomerMessageParams}->{$Key}{$_}/gi;
    }

    # do text/plain to text/html convert
    if ( $Self->{RichText} && $Notification{ContentType} =~ /text\/plain/i ) {
        $Notification{ContentType} = 'text/html';
        $Notification{Body}        = $HTMLUtilsObject->ToHTML(
            String => $Notification{Body},
        );
    }

    # do text/html to text/plain convert
    if ( !$Self->{RichText} && $Notification{ContentType} =~ /text\/html/i ) {
        $Notification{ContentType} = 'text/plain';
        $Notification{Body}        = $HTMLUtilsObject->ToAscii(
            String => $Notification{Body},
        );
    }

    # get notify texts
    for my $Text (qw(Subject Body)) {
        if ( !$Notification{$Text} ) {
            $Notification{$Text} = "No Notification $Text for $Param{Type} found!";
        }
    }

    # replace place holder stuff
    $Notification{Body} = $Self->_Replace(
        RichText  => $Self->{RichText},
        Text      => $Notification{Body},
        Recipient => $Param{Recipient},
        Data      => $Param{CustomerMessageParams},
        DataAgent => \%ArticleAgent,
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        Language  => $Language,
        ArticleID => $Param{ArticleID} || '',
    );
    $Notification{Subject} = $Self->_Replace(
        RichText  => 0,
        Text      => $Notification{Subject},
        Recipient => $Param{Recipient},
        Data      => $Param{CustomerMessageParams},
        DataAgent => \%ArticleAgent,
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        Language  => $Language,
        ArticleID => $Param{ArticleID} || '',
    );

    $Notification{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $Notification{Subject} || '',
        Type         => 'New',
    );

    # add URLs and verify to be full HTML document
    if ( $Self->{RichText} ) {

        $Notification{Body} = $HTMLUtilsObject->LinkQuote(
            String => $Notification{Body},
        );
    }

    return %Notification;
}

=item ReplacePlaceHolder()
    just a wrapper for external access to sub _Replace
=cut

sub ReplacePlaceHolder {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for (qw(Text Data UserID)) {
        if ( !defined $Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message => "Need $_!"
            );
            return;
        }
    }

    if ( !defined $Param{Language}
        || !$Param{Language}
    ) {
        $Param{Language}
            = $Self->{UserLanguage}
            || $ConfigObject->Get('DefaultLanguage')
            || 'en';
    }

    return $Self->_Replace(
        %Param,
    );
}

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject                = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject                = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomerUserObject          = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $DynamicFieldObject          = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject   = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $HTMLUtilsObject             = $Kernel::OM->Get('Kernel::System::HTMLUtils');
    my $JSONObject                  = $Kernel::OM->Get('Kernel::System::JSON');
    my $LogObject                   = $Kernel::OM->Get('Kernel::System::Log');
    my $QueueObject                 = $Kernel::OM->Get('Kernel::System::Queue');
    my $SystemAddress               = $Kernel::OM->Get('Kernel::System::SystemAddress');
    my $TicketObject                = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject                  = $Kernel::OM->Get('Kernel::System::User');

    # check needed stuff
    for (qw(Text RichText Data UserID)) {
        if ( !defined $Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Param{Text} =~ s{OTRS_}{KIX_}g;
    $Param{RichText} =~ s{OTRS_}{KIX_}g;

    # check for mailto links
    # since the subject and body of those mailto links are
    # uri escaped we have to uri unescape them, replace
    # possible placeholders and then re-uri escape them
    $Param{Text} =~ s{
        (href="mailto:[^\?]+\?)([^"]+")
    }
    {
        my $MailToHref        = $1;
        my $MailToHrefContent = $2;

        $MailToHrefContent =~ s{
            ((?:subject|body)=)(.+?)("|&)
        }
        {
            my $SubjectOrBodyPrefix  = $1;
            my $SubjectOrBodyContent = $2;
            my $SubjectOrBodySuffix  = $3;

            my $SubjectOrBodyContentUnescaped = URI::Escape::uri_unescape $SubjectOrBodyContent;

            my $SubjectOrBodyContentReplaced = $Self->_Replace(
                %Param,
                Text     => $SubjectOrBodyContentUnescaped,
                RichText => 0,
            );

            my $SubjectOrBodyContentEscaped = URI::Escape::uri_escape_utf8 $SubjectOrBodyContentReplaced;

            $SubjectOrBodyPrefix . $SubjectOrBodyContentEscaped . $SubjectOrBodySuffix;
        }egx;

        $MailToHref . $MailToHrefContent;
    }egx;

    my $Start = '<';
    my $End   = '>';
    if ( $Param{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Param{Text} =~ s/(\n|\r)//g;
    }

    my %Ticket;
    if ( $Param{TicketID} ) {
        %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );
    }

    my %Article;
    if ( $Param{ArticleID} ) {
        %Article = $TicketObject->ArticleGet(
            ArticleID => $Param{ArticleID},
        );
    }

    # translate ticket and aticle values if needed
    if ( $Param{Language} ) {

        my $LanguageObject = Kernel::Language->new(
            UserLanguage => $Param{Language},
        );

        # Translate the diffrent values.
        for my $Field (qw(Type State StateType Lock Priority)) {
            $Ticket{$Field} = $LanguageObject->Translate( $Ticket{$Field} );
        }

        # Transform the date values from the ticket data (but not the dynamic field values).
        ATTRIBUTE:
        for my $Attribute ( sort keys %Ticket ) {
            next ATTRIBUTE if $Attribute =~ m{ \A DynamicField_ }xms;
            next ATTRIBUTE if !$Ticket{$Attribute};

            if ( $Ticket{$Attribute} =~ m{\A(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)\z}xi ) {
                $Ticket{$Attribute} = $LanguageObject->FormatTimeString(
                    $Ticket{$Attribute},
                    'DateFormat',
                    'NoSeconds',
                );
            }
        }

        # Translate the diffrent values.
        for my $Field (qw(Type State StateType Lock Priority)) {
            $Article{$Field} = $LanguageObject->Translate( $Article{$Field} );
        }

        # Transform the date values from the ticket data (but not the dynamic field values).
        ATTRIBUTE:
        for my $Attribute ( sort keys %Article ) {
            next ATTRIBUTE if $Attribute =~ m{ \A DynamicField_ }xms;
            next ATTRIBUTE if !$Article{$Attribute};

            if ( $Article{$Attribute} =~ m{\A(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)\z}xi ) {
                $Article{$Attribute} = $LanguageObject->FormatTimeString(
                    $Article{$Attribute},
                    'DateFormat',
                    'NoSeconds',
                );
            }
        }
    }

    my %Queue;
    if ( $Param{QueueID} ) {
        %Queue = $QueueObject->QueueGet(
            ID => $Param{QueueID},
        );
    }

    # replace config options
    my $Tag = $Start . 'KIX_CONFIG_';
    $Param{Text} =~ s{$Tag(.+?)$End}{
        my $Replace = '';
        # Mask secret config options.
        if ($1 =~ m{(Password|Pw)\d*$}smxi) {
            $Replace = 'xxx';
        }
        else {
            $Replace = $ConfigObject->Get($1) // '';
        }
        $Replace;
    }egx;

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    my %Recipient = %{ $Param{Recipient} || {} };

    if ( !%Recipient && $Param{RecipientID} ) {

        %Recipient = $UserObject->GetUserData(
            UserID        => $Param{RecipientID},
            NoOutOfOffice => 1,
        );
    }

    my $HashGlobalReplace = sub {
        my ( $ReplaceTag, %H ) = @_;

        # Generate one single matching string for all keys to save performance.
        my $Keys = join '|', map {quotemeta} grep { defined $H{$_} } keys %H;

        # Add all keys also as lowercase to be able to match case insensitive,
        #   e. g. <KIX_CUSTOMER_From> and <KIX_CUSTOMER_FROM>.
        for my $Key ( sort keys %H ) {
            $H{ lc $Key } = $H{$Key};
        }

        $Param{Text} =~ s/(?:$ReplaceTag)($Keys)$End/$H{ lc $1 }/ieg;
    };

    # get recipient data and replace it with <KIX_...
    $Tag = $Start . 'KIX_';

    # include more readable tag <KIX_NOTIFICATION_RECIPIENT
    my $RecipientTag = $Start . 'KIX_NOTIFICATION_RECIPIENT_';

    if (%Recipient) {

        # HTML quoting of content
        if ( $Param{RichText} ) {
            ATTRIBUTE:
            for my $Attribute ( sort keys %Recipient ) {
                next ATTRIBUTE if !$Recipient{$Attribute};
                $Recipient{$Attribute} = $HTMLUtilsObject->ToHTML(
                    String => $Recipient{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$RecipientTag", %Recipient );
    }

    # cleanup
    $Param{Text} =~ s/$RecipientTag.+?$End/-/gi;

    # get owner data and replace it with <KIX_OWNER_...
    $Tag = $Start . 'KIX_OWNER_';

    # include more readable version <KIX_TICKET_OWNER
    my $OwnerTag = $Start . 'KIX_TICKET_OWNER_';

    if ( $Ticket{OwnerID} ) {

        my %Owner = $UserObject->GetUserData(
            UserID        => $Ticket{OwnerID},
            NoOutOfOffice => 1,
        );

        # html quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %Owner ) {
                next ATTRIBUTE if !$Owner{$Attribute};
                $Owner{$Attribute} = $HTMLUtilsObject->ToHTML(
                    String => $Owner{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$OwnerTag", %Owner );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;
    $Param{Text} =~ s/$OwnerTag.+?$End/-/gi;

    # get owner data and replace it with <KIX_RESPONSIBLE_...
    $Tag = $Start . 'KIX_RESPONSIBLE_';

    # include more readable version <KIX_TICKET_RESPONSIBLE
    my $ResponsibleTag = $Start . 'KIX_TICKET_RESPONSIBLE_';

    if ( $Ticket{ResponsibleID} ) {
        my %Responsible = $UserObject->GetUserData(
            UserID        => $Ticket{ResponsibleID},
            NoOutOfOffice => 1,
        );

        # HTML quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %Responsible ) {
                next ATTRIBUTE if !$Responsible{$Attribute};
                $Responsible{$Attribute} = $HTMLUtilsObject->ToHTML(
                    String => $Responsible{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$ResponsibleTag", %Responsible );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;
    $Param{Text} =~ s/$ResponsibleTag.+?$End/-/gi;

    my $Tag2;

    if (
        $Param{UserID}
        && ( !$Param{Frontend} || ( $Param{Frontend} && $Param{Frontend} ne 'Customer' ) )
    ) {
        $Tag = $Start . 'KIX_Agent_';

        $Tag2 = $Start . 'KIX_CURRENT_';

        my %CurrentUser = $UserObject->GetUserData(
            UserID        => $Param{UserID},
            NoOutOfOffice => 1,
        );

        # html quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %CurrentUser ) {
                next ATTRIBUTE if !$CurrentUser{$Attribute};
                $CurrentUser{$Attribute} = $HTMLUtilsObject->ToHTML(
                    String => $CurrentUser{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$Tag2", %CurrentUser );

        # replace other needed stuff
        $Param{Text} =~ s/$Start KIX_FIRST_NAME $End/$CurrentUser{UserFirstname}/gxms;
        $Param{Text} =~ s/$Start KIX_LAST_NAME $End/$CurrentUser{UserLastname}/gxms;

        # cleanup
        $Param{Text} =~ s/$Tag2.+?$End/-/gi;
    }

    # ticket data
    $Tag = $Start . 'KIX_TICKET_';

    # html quoting of content
    if ( $Param{RichText} ) {

        ATTRIBUTE:
        for my $Attribute ( sort keys %Ticket ) {
            next ATTRIBUTE if !$Ticket{$Attribute};
            $Ticket{$Attribute} = $HTMLUtilsObject->ToHTML(
                String => $Ticket{$Attribute},
            );
        }
    }

    # Dropdown, Checkbox and MultipleSelect DynamicFields, can store values (keys) that are
    # different from the the values to display
    # <KIX_TICKET_DynamicField_NameX> returns the stored key
    # <KIX_TICKET_DynamicField_NameX_Value> returns the display value

    my %DynamicFields;

    # For systems with many Dynamic fields we do not want to load them all unless needed
    # Find what Dynamic Field Values are requested
    while ( $Param{Text} =~ m/$Tag DynamicField_(\S+?)(_Value)? $End/gixms ) {
        $DynamicFields{$1} = 1;
    }

    # to store all the required DynamicField display values
    my %DynamicFieldDisplayValues;

    # get the dynamic fields for ticket object
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    ) || [];

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # we only load the ones requested
        next DYNAMICFIELD if !$DynamicFields{ $DynamicFieldConfig->{Name} };

        my $LanguageObject;

        # translate values if needed
        if ( $Param{Language} ) {
            $LanguageObject = Kernel::Language->new(
                UserLanguage => $Param{Language},
            );
        }

        # get the display value for each dynamic field
        my $DisplayValue = $DynamicFieldBackendObject->ValueLookup(
            DynamicFieldConfig => $DynamicFieldConfig,
            Key                => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            LanguageObject     => $LanguageObject,
        );

        # get the readable value (value) for each dynamic field
        my $DisplayValueStrg = $DynamicFieldBackendObject->ReadableValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $DisplayValue,
        );

        # fill the DynamicFielsDisplayValues
        if ($DisplayValueStrg) {
            $DynamicFieldDisplayValues{ 'DynamicField_' . $DynamicFieldConfig->{Name} . '_Value' }
                = $DisplayValueStrg->{Value};
        }

        # get the readable value (key) for each dynamic field
        my $ValueStrg = $DynamicFieldBackendObject->ReadableValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
        );

        # replace ticket content with the value from ReadableValueRender (if any)
        if ( IsHashRefWithData($ValueStrg) ) {
            $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $ValueStrg->{Value};
        }
    }

    # replace it
    $HashGlobalReplace->( $Tag, %Ticket, %DynamicFieldDisplayValues );

    # COMPAT
    $Param{Text} =~ s/$Start KIX_TICKET_ID $End/$Ticket{TicketID}/gixms;
    $Param{Text} =~ s/$Start KIX_TICKET_NUMBER $End/$Ticket{TicketNumber}/gixms;
    if ( $Param{TicketID} ) {
        $Param{Text} =~ s/$Start KIX_QUEUE $End/$Ticket{Queue}/gixms;
    }
    if ( $Param{QueueID} ) {
        $Param{Text} =~ s/$Start KIX_TICKET_QUEUE $End/$Queue{Name}/gixms;
    }

    if ( $Ticket{Service} && $Param{Text} ) {
        my $LevelSeparator        = $ConfigObject->Get('TemplateGenerator::LevelSeparator');
        my $ServiceLevelSeparator = '::';
        if ( $LevelSeparator && ref($LevelSeparator) eq 'HASH' && $LevelSeparator->{Service} ) {
            $ServiceLevelSeparator = $LevelSeparator->{Service};
        }
        my @Service = split( $ServiceLevelSeparator, $Ticket{Service} );

        my $MatchPattern = $Start . "KIX_TICKET_Service_Level_(.*?)" . $End;
        while ( $Param{Text} =~ /$MatchPattern/ ) {
            my $ReplacePattern = $Start . "KIX_TICKET_Service_Level_" . $1 . $End;
            my $Level = ( $1 eq 'MAX' ) ? -1 : ($1) - 1;
            if ( $Service[$Level] ) {
                $Param{Text} =~ s/$ReplacePattern/$Service[$Level]/gixms
            }
            else {
                $Param{Text} =~ s/$ReplacePattern/-/gixms
            }

        }
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    # get customer and agent params and replace it with <KIX_CUSTOMER_... or <KIX_AGENT_...
    my %ArticleData = (
        'KIX_CUSTOMER_' => $Param{Data}      || {},
        'KIX_AGENT_'    => $Param{DataAgent} || {},
    );

    # use a list to get customer first
    for my $DataType (qw(KIX_CUSTOMER_ KIX_AGENT_)) {
        my %Data = %{ $ArticleData{$DataType} };

        # HTML quoting of content
        if (
            $Param{RichText}
            && ( !$Data{ContentType} || $Data{ContentType} !~ /application\/json/ )
        ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %Data ) {
                next ATTRIBUTE if !$Data{$Attribute};

                $Data{$Attribute} = $HTMLUtilsObject->ToHTML(
                    String => $Data{$Attribute},
                );
            }
        }

        if (%Data) {

            # check if original content isn't text/plain, don't use it
            if ( $Data{'Content-Type'} && $Data{'Content-Type'} !~ /(?:text\/plain|\btext\b)/i ) {
                $Data{Body} = '-> no quotable message <-';
            }

            # replace <KIX_CUSTOMER_*> and <KIX_AGENT_*> tags
            $Tag = $Start . $DataType;
            $HashGlobalReplace->( $Tag, %Data );

            # prepare body (insert old email) <KIX_CUSTOMER_EMAIL[n]>, <KIX_CUSTOMER_NOTE[n]>
            #   <KIX_CUSTOMER_BODY[n]>, <KIX_AGENT_EMAIL[n]>..., <KIX_COMMENT>
            my $Pattern = "$Start(?:(?:$DataType(EMAIL|NOTE|BODY)\\[(\\d+?)\\])|(?:KIX_COMMENT))$End";
            if ( $Param{Text} =~ /$Pattern/g ) {

                my $Line       = $2 || 2500;
                my $NewOldBody = '';
                my @Body       = split( /\n/, $Data{Body} );

                for my $Counter ( 0 .. $Line - 1 ) {

                    # 2002-06-14 patch of Pablo Ruiz Garcia
                    if ( $#Body >= $Counter ) {

                        # add no quote char, do it later by using DocumentCleanup()
                        if ( $Param{RichText} ) {
                            $NewOldBody .= $Body[$Counter];
                        }

                        # add "> " as quote char
                        else {
                            $NewOldBody .= "> $Body[$Counter]";
                        }

                        # add new line
                        if ( $Counter < ( $Line - 1 ) ) {
                            $NewOldBody .= "\n";
                        }
                    }
                    $Counter++;
                }

                chomp $NewOldBody;

                # HTML quoting of content
                if ( $Param{RichText} && $NewOldBody ) {

                    # remove trailing new lines
                    for ( 1 .. 10 ) {
                        $NewOldBody =~ s/(<br\/>)\s{0,20}$//gs;
                    }

                    # add quote
                    $NewOldBody = "<blockquote type=\"cite\">$NewOldBody</blockquote>";
                    $NewOldBody = $HTMLUtilsObject->DocumentCleanup(
                        String => $NewOldBody,
                    );
                }

                # replace tag
                $Param{Text} =~ s/$Pattern/$NewOldBody/g;
            }

            # replace <KIX_CUSTOMER_SUBJECT[]>  and  <KIX_AGENT_SUBJECT[]> tags
            $Tag = "$Start$DataType" . 'SUBJECT';
            if ( $Param{Text} =~ /$Tag\[(\d+?)\]$End/g ) {

                my $SubjectChar = $1 || 50;
                my $Subject     = $TicketObject->TicketSubjectClean(
                    TicketNumber => $Ticket{TicketNumber},
                    Subject      => $Data{Subject},
                );

                $Subject =~ s/^(.{$SubjectChar}).*$/$1 [...]/;
                $Param{Text} =~ s/$Tag\[\d+?\]$End/$Subject/g;
            }

            # replace <KIX_> tags
            $Tag = $Start . 'KIX_';
            for ( keys %Data ) {
                next if !defined $Data{$_};
                $Param{Text} =~ s/$Tag$_$End/$Data{$_}/gi;
            }

            if ( $DataType eq 'KIX_CUSTOMER_' ) {

                # Arnold Ligtvoet
                # get <KIX_EMAIL_DATE[]> from body and replace with received date
                $Tag = $Start . 'KIX_EMAIL_DATE';

                if ( $Param{Text} =~ /$Tag\[(.+?)\]$End/g ) {

                    my $TimeZone = $1;
                    my $EmailDate = strftime( '%A, %B %e, %Y at %T ', localtime );
                    $EmailDate .= "($TimeZone)";
                    $Param{Text} =~ s/$Tag\[.+?\]$End/$EmailDate/g;
                }
            }
        }

        if ( $DataType eq 'KIX_CUSTOMER_' ) {
            # get and prepare realname
            $Tag = $Start . 'KIX_CUSTOMER_REALNAME';
            if ( $Param{Text} =~ /$Tag$End/i ) {

                my $From;

                if ( $Ticket{CustomerUserID} ) {

                    $From = $CustomerUserObject->CustomerName(
                        UserLogin => $Ticket{CustomerUserID}
                    );
                }

                # try to get the real name directly from the data
                $From //= $Recipient{Realname};

                # get real name based on reply-to
                if (
                    !$From
                    && $Data{ReplyTo}
                ) {
                    $From = $Data{ReplyTo};

                    # remove email addresses
                    $From =~ s/&lt;.*&gt;|<.*>|\(.*\)|\"|&quot;|;|,//g;

                    # remove leading/trailing spaces
                    $From =~ s/^\s+//g;
                    $From =~ s/\s+$//g;
                }

                # generate real name based on sender line
                if ( !$From ) {
                    $From = $Data{To} || '';

                    # remove email addresses
                    $From =~ s/&lt;.*&gt;|<.*>|\(.*\)|\"|&quot;|;|,//g;

                    # remove leading/trailing spaces
                    $From =~ s/^\s+//g;
                    $From =~ s/\s+$//g;
                }

                # replace <KIX_CUSTOMER_REALNAME> with from
                $Param{Text} =~ s/$Tag$End/$From/g;
            }
        }
    }

    # get customer data and replace it with <KIX_CUSTOMER_DATA_...
    $Tag  = $Start . 'KIX_CUSTOMER_';
    $Tag2 = $Start . 'KIX_CUSTOMER_DATA_';

    if ( $Ticket{CustomerUserID}
        || $Param{Data}->{CustomerUserID}
        || ( defined $Param{Frontend} && $Param{Frontend} eq 'Customer' )
    ) {

        my $CustomerUserID    = $Param{Data}->{CustomerUserID} || $Ticket{CustomerUserID};
        my $CustomerCompanyID = $Param{Data}->{CustomerID}     || $Ticket{CustomerID};

        my %CustomerUser = $CustomerUserObject->CustomerUserDataGet(
            User       => $CustomerUserID,
            CustomerID => $CustomerCompanyID,
        );

        # HTML quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %CustomerUser ) {
                next ATTRIBUTE if !$CustomerUser{$Attribute};
                $CustomerUser{$Attribute} = $HTMLUtilsObject->ToHTML(
                    String => $CustomerUser{$Attribute},
                );
            }
        }

        # replace it
        $HashGlobalReplace->( "$Tag|$Tag2", %CustomerUser );
    }

    # cleanup all not needed <KIX_CUSTOMER_DATA_ tags
    $Param{Text} =~ s/(?:$Tag|$Tag2).+?$End/-/gi;

    # cleanup all not needed <KIX_AGENT_ tags
    $Tag = $Start . 'KIX_AGENT_';
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    $Tag  = $Start . 'KIX_ARTICLE_RECIPIENT_';
    if ($Param{ArticleID}
        && $Param{Text} =~ /$Tag.+?$End/g
    ) {
        # get list of unsupported tags
        my @RecipientUnSupportedTag = qw(
            KIX_ARTICLE_RECIPIENT_UserPassword
            KIX_ARTICLE_RECIPIENT_CreateBy
            KIX_ARTICLE_RECIPIENT_ChangeBy
            KIX_ARTICLE_RECIPIENT_UserID
            KIX_ARTICLE_RECIPIENT_CustomerCompanyValidID
            KIX_ARTICLE_RECIPIENT_UserDefaultTicketQueue
            KIX_ARTICLE_RECIPIENT_Config
            KIX_ARTICLE_RECIPIENT_UserConfigItemOverviewSmallPageShown
            KIX_ARTICLE_RECIPIENT_UserDefaultService
            KIX_ARTICLE_RECIPIENT_UserShowTickets
            KIX_ARTICLE_RECIPIENT_CompanyConfig
            KIX_ARTICLE_RECIPIENT_UserGoogleAuthenticatorSecretKey
        );

        # replace all unsupported tags first
        $Param{Text} = $Self->_RemoveUnSupportedTag(
            Text                    => $Param{Text} || '',
            ListOfUnSupportedTag    => \@RecipientUnSupportedTag,
        );

        # get needed email parse object
        my $ParserObject = Kernel::System::EmailParser->new(
            Mode         => 'Standalone',
            Debug        => 0,
        );

        my $Address     = '';
        my $RealName    = '';
        # check article type and replace To with From (in case)
        if ( $Article{SenderType} !~ /customer/ ) {

            for my $Email ( Mail::Address->parse( $Article{To} ) ) {
                my $IsLocal = $SystemAddress->SystemAddressIsLocalAddress(
                    Address => $Email->address(),
                );
                if (
                    !$ConfigObject->Get('CheckEmailInternalAddress')
                    || !$IsLocal
                ) {
                    $Address    = $Article{To};
                    $RealName   = $Article{ToRealname};
                }
            }
        } else {
            $Address    = $Article{From};
            $RealName   = $Article{FromRealname};
        }

        # split addresses into a array
        my @AddressList = $ParserObject->SplitAddressLine(
            Line => $Address,
        );

        # to get the senders email address back
        my $SenderEmail = $ParserObject->GetEmailAddress(
            Email => $AddressList[0],
        );

        if ($SenderEmail) {
            my %CustomerUser;

            # search with the mail address for a customer
            my %List = $CustomerUserObject->CustomerSearch(
                PostMasterSearch => $SenderEmail,
                Valid            => 1,
            );

            #If there is a customer, then get the customer data otherwise return the real name or address
            if ( %List ) {
                USERLIST:
                for my $UserID (keys %List) {
                    %CustomerUser = $CustomerUserObject->CustomerUserDataGet(
                        User => $UserID,
                    );
                    # html quoteing of content
                    if ( $Param{RichText} ) {
                        for ( keys %CustomerUser ) {
                            next if !$CustomerUser{$_};
                            $CustomerUser{$_} = $HTMLUtilsObject->ToHTML(
                                String => $CustomerUser{$_},
                            );
                        }
                    }

                    # replace it
                    for my $Key ( keys %CustomerUser ) {
                        next if !defined $CustomerUser{$Key};
                        $Param{Text} =~ s/$Tag$Key$End/$CustomerUser{$Key}/gi;
                    }
                    last USERLIST;
                }
            } else {
                my $Key = 'Realname';
                if ($RealName) {
                    $Param{Text} =~ s/$Tag$Key$End/$RealName/gi;
                } else {
                    $Param{Text} =~ s/$Tag$Key$End/$SenderEmail/gi;
                }
            }
        }
    }
    # cleanup all not needed <KIX_ARTICLE_RECIPIENT_ tags
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    # get article data and replace it with <KIX_ARTICLE_DATA_...
    $Tag  = $Start . 'KIX_ARTICLE_';
    $Tag2 = $Start . 'KIX_ARTICLE_DATA_';
    if ( $Param{ArticleID} ) {

        # html quoteing of content
        if ( $Param{RichText} ) {
            for ( keys %Article ) {
                next if !$Article{$_};
                $Article{$_} = $HTMLUtilsObject->ToHTML(
                    String => $Article{$_},
                );
            }
        }

        # replace it
        for my $Key ( keys %Article ) {
            next if !defined $Article{$Key};
            $Param{Text} =~ s/$Tag$Key$End/$Article{$Key}/gi;
            $Param{Text} =~ s/$Tag2$Key$End/$Article{$Key}/gi;
        }
    }

    # cleanup all not needed <KIX_ARTICLE_ and <KIX_ARTICLE_DATA_ tags
    $Param{Text} =~ s/$Tag.+?$End/-/gi;
    $Param{Text} =~ s/$Tag2.+?$End/-/gi;

    # get first article data and replace it with <KIX_FIRST_...
    $Tag = $Start . 'KIX_FIRST_';
    if ( $Param{Text} =~ /$Tag.+$End/i ) {
        my %FirstArticle = $TicketObject->ArticleFirstArticle(
            TicketID => $Param{TicketID},
        );

        # replace <KIX_FIRST_BODY> and <KIX_FIRST_COMMENT> tags
        for my $Key (qw(KIX_FIRST_BODY KIX_FIRST_COMMENT)) {
            $Tag2 = $Start . $Key;
            if ( $Param{Text} =~ /$Tag2$End(\n|\r|)/g ) {
                my $Line       = 2500;
                my @Body       = split( /\n/, $FirstArticle{Body} );
                my $NewOldBody = '';
                for ( my $i = 0; $i < $Line; $i++ ) {
                    if ( $#Body >= $i ) {

                        # add no quote char, do it later by using DocumentCleanup()
                        if ( $Param{RichText} ) {
                            $NewOldBody .= $Body[$i];
                        }

                        # add "> " as quote char
                        else {
                            $NewOldBody .= "> $Body[$i]";
                        }

                        # add new line
                        if ( $i < ( $Line - 1 ) ) {
                            $NewOldBody .= "\n";
                        }
                    }
                    else {
                        last;
                    }
                }
                chomp $NewOldBody;

                # html quoting of content
                if ( $Param{RichText} && $NewOldBody ) {

                    # remove trailing new lines
                    for ( 1 .. 10 ) {
                        $NewOldBody =~ s/(<br\/>)\s{0,20}$//gs;
                    }

                    # add quote
                    $NewOldBody = "<blockquote type=\"cite\">$NewOldBody</blockquote>";
                    $NewOldBody
                        = $HTMLUtilsObject->DocumentCleanup(
                        String => $NewOldBody,
                        );
                }

                # replace tag
                $Param{Text} =~ s/$Tag2$End/$NewOldBody/g;
            }
        }

        # replace <KIX_FIRST_EMAIL[]> tags
        $Tag2 = $Start . 'KIX_FIRST_EMAIL';
        if ( $Param{Text} =~ /$Tag2\[(\d+?)\]$End/g ) {
            my $Line       = $1;
            my @Body       = split( /\n/, $FirstArticle{Body} );
            my $NewOldBody = '';
            for ( my $i = 0; $i < $Line; $i++ ) {

                # 2002-06-14 patch of Pablo Ruiz Garcia
                if ( $#Body >= $i ) {

                    # add no quote char, do it later by using DocumentCleanup()
                    if ( $Param{RichText} ) {
                        $NewOldBody .= $Body[$i];
                    }

                    # add "> " as quote char
                    else {
                        $NewOldBody .= "> $Body[$i]";
                    }

                    # add new line
                    if ( $i < ( $Line - 1 ) ) {
                        $NewOldBody .= "\n";
                    }
                }
            }
            chomp $NewOldBody;

            # html quoting of content
            if ( $Param{RichText} && $NewOldBody ) {

                # remove trailing new lines
                for ( 1 .. 10 ) {
                    $NewOldBody =~ s/(<br\/>)\s{0,20}$//gs;
                }

                # add quote
                $NewOldBody = "<blockquote type=\"cite\">$NewOldBody</blockquote>";
                $NewOldBody = $HTMLUtilsObject->DocumentCleanup(
                    String => $NewOldBody,
                );
            }

            # replace tag
            $Param{Text} =~ s/$Tag2\[\d+?\]$End/$NewOldBody/g;
        }

        # replace <KIX_FIRST_SUBJECT[]> tags
        $Tag2 = $Start . 'KIX_FIRST_SUBJECT';
        if ( $Param{Text} =~ /$Tag2\[(\d+?)\]$End/g ) {
            my $SubjectChar = $1 || 50;
            my $Subject     = $TicketObject->TicketSubjectClean(
                TicketNumber => $Ticket{TicketNumber},
                Subject      => $FirstArticle{Subject},
            );
            $Subject =~ s/^(.{$SubjectChar}).*$/$1 [...]/;
            $Param{Text} =~ s/$Tag2\[\d+?\]$End/$Subject/g;
        }

        # html quoteing of content
        if ( $Param{RichText} ) {
            for ( keys %FirstArticle ) {
                next if !$FirstArticle{$_};
                $FirstArticle{$_} = $HTMLUtilsObject->ToHTML(
                    String => $FirstArticle{$_},
                );
            }
        }

        # replace it
        for my $Key ( keys %FirstArticle ) {
            next if !defined $FirstArticle{$Key};
            $Param{Text} =~ s/$Tag$Key$End/$FirstArticle{$Key}/gi;
        }
    }

    # cleanup all not needed <KIX_FIRST_ tags
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    return $Param{Text};
}

=head2 _RemoveUnSupportedTag()

cleanup all not supported tags

    my $Text = $TemplateGeneratorObject->_RemoveUnSupportedTag(
        Text => $SomeTextWithTags,
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

=cut

sub _RemoveUnSupportedTag {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    # check needed stuff
    for my $Item (qw(Text ListOfUnSupportedTag)) {
        if ( !defined $Param{$Item} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Item!"
            );
            return;
        }
    }

    my $Start = '<';
    my $End   = '>';
    if ( $Self->{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Param{Text} =~ s/(\n|\r)//g;
    }

    # cleanup all not supported tags
    my $NotSupportedTag = $Start . "(?:" . join( "|", @{ $Param{ListOfUnSupportedTag} } ) . ")" . $End;
    $Param{Text} =~ s/$NotSupportedTag/-/gi;

    return $Param{Text};

}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
