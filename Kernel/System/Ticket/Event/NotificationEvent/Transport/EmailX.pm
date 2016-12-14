# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# KIX4OTRS-Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# NotificationEventX-Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# Depends: KIX/KIX4OTRS, KIX4OTRS/Kernel/System/Ticket/Event/NotificationEvent/Transport/Email.pm, 1.4
#
# written/edited by:
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

# NotificationEventX-capeIT
#package Kernel::System::Ticket::Event::NotificationEvent::Transport::Email;
package Kernel::System::Ticket::Event::NotificationEvent::Transport::EmailX;
# EO NotificationEventX-capeIT
## nofilter(TidyAll::Plugin::OTRS::Perl::LayoutObject)
## nofilter(TidyAll::Plugin::OTRS::Perl::ParamObject)

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Ticket::Event::NotificationEvent::Transport::Base);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::Email',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Queue',
    'Kernel::System::SystemAddress',
    'Kernel::System::Ticket',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
# NotificationEventX-capeIT
    'Kernel::System::Crypt::PGP',
    'Kernel::System::Crypt::SMIME',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
# EO NotificationEventX-capeIT
);

=head1 NAME

Kernel::System::Ticket::Event::NotificationEvent::Transport::Email - email transport layer

=head1 SYNOPSIS

Notification event transport layer.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a notification transport object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new('');
    my $TransportObject = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent::Transport::Email');

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

    # get needed objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SystemAddressObject = $Kernel::OM->Get('Kernel::System::SystemAddress');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get recipient data
    my %Recipient = %{ $Param{Recipient} };

# NotificationEventX-capeIT
    # check if recipient hash has DynamicField
    if (
        $Recipient{DynamicFieldName}
        && $Recipient{DynamicFieldType}
    ) {
        # get objects
        my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
        my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
        my $UserObject         = $Kernel::OM->Get('Kernel::System::User');

        # get ticket
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );

        return 1 if ( !$Ticket{'DynamicField_' . $Recipient{DynamicFieldName}} );

        # get recipients from df
        my @DFRecipients = ();

        # process values from ticket data
        my @FieldRecipients = ();
        if (ref($Ticket{'DynamicField_' . $Recipient{DynamicFieldName}}) eq 'ARRAY') {
            @FieldRecipients = @{ $Ticket{'DynamicField_' . $Recipient{DynamicFieldName}} };
        } else {
            push(@FieldRecipients, $Ticket{'DynamicField_' . $Recipient{DynamicFieldName}});
        }
        FIELDRECIPIENT:
        for my $FieldRecipient (@FieldRecipients) {
            next FIELDRECIPIENT if !$FieldRecipient;

            my $AddressLine = '';
            # handle dynamic field by type
            if ($Recipient{DynamicFieldType} eq 'User') {
                my %UserData = $UserObject->GetUserData(
                    User  => $FieldRecipient,
                    Valid => 1
                );
                next FIELDRECIPIENT if !$UserData{UserEmail};
                $AddressLine = $UserData{UserEmail};
            } elsif ($Recipient{DynamicFieldType} eq 'CustomerUser') {
                my %CustomerUser = $CustomerUserObject->CustomerUserDataGet(
                    User => $FieldRecipient,
                );
                next FIELDRECIPIENT if !$CustomerUser{UserEmail};
                $AddressLine = $CustomerUser{UserEmail};
            } else {
                $AddressLine = $FieldRecipient;
            }

            # generate recipient
            my %DFRecipient = (
                Realname  => '',
                UserEmail => $AddressLine,
                Type      => $Recipient{Type},
            );

            # check recipients
            if ( $DFRecipient{UserEmail} && $DFRecipient{UserEmail} =~ /@/ ) {
                push (@DFRecipients, \%DFRecipient);
            }
        }

        # handle recipients
        for my $DFRecipient (@DFRecipients) {
            $Self->SendNotification(
                TicketID              => $Param{TicketID},
                UserID                => $Param{UserID},
                Notification          => $Param{Notification},
                CustomerMessageParams => $Param{CustomerMessageParams},
                Recipient             => $DFRecipient,
                Event                 => $Param{Event},
                Attachments           => $Param{Attachments},
            );
        }

        # done
        return 1;

    }
# EO NotificationEventX-capeIT

    if (
        $Recipient{Type} eq 'Customer'
        && $ConfigObject->Get('CustomerNotifyJustToRealCustomer')
        )
    {
        # return if not customer user ID
        return if !$Recipient{CustomerUserID};

        my %CustomerUser = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $Recipient{CustomerUserID},
        );

        if ( !$CustomerUser{UserEmail} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'info',
                Message  => "Send no customer notification because of missing "
                    . "customer email (CustomerUserID=$CustomerUser{CustomerUserID})!",
            );
            return;
        }
    }

    return if !$Recipient{UserEmail};

    return if $Recipient{UserEmail} !~ /@/;

    my $IsLocalAddress = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressIsLocalAddress(
        Address => $Recipient{UserEmail},
    );

    return if $IsLocalAddress;

    # create new array to prevent attachment growth (see bug#5114)
    my @Attachments = @{ $Param{Attachments} };

    my %Notification = %{ $Param{Notification} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # send notification
    my $From = $ConfigObject->Get('NotificationSenderName') . ' <'
        . $ConfigObject->Get('NotificationSenderEmail') . '>';

    if ( $Param{Notification}->{ContentType} && $Param{Notification}->{ContentType} eq 'text/html' ) {

        # Get configured template with fallback to Default.
        my $EmailTemplate = $Param{Notification}->{Data}->{TransportEmailTemplate}->[0] || 'Default';

        my $Home              = $Kernel::OM->Get('Kernel::Config')->Get('Home');
        my $TemplateDir       = "$Home/Kernel/Output/HTML/Templates/Standard/NotificationEvent/Email";
        my $CustomTemplateDir = "$Home/Custom/Kernel/Output/HTML/Templates/Standard/NotificationEvent/Email";

        if ( !-r "$TemplateDir/$EmailTemplate.tt" && !-r "$CustomTemplateDir/$EmailTemplate.tt" ) {
            $EmailTemplate = 'Default';
        }

        # generate HTML
        $Notification{Body} = $LayoutObject->Output(
            TemplateFile => "NotificationEvent/Email/$EmailTemplate",
            Data         => {
                TicketID => $Param{TicketID},
                Body     => $Notification{Body},
                Subject  => $Notification{Subject},
            },
        );
    }

# NotificationEventX-capeIT
    # prepare subject
    if (!$Notification{Data}->{RecipientSubject}) {
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TicketID},
        );

        $Notification{Subject} = $TicketObject->TicketSubjectClean(
            TicketNumber => $TicketNumber,
            Subject      => $Notification{Subject},
            Size         => 0,
        );
    }

    my %SendParams;
    # process crypt
    if ($Notification{Data}->{RecipientCrypt}->[0]) {

        # prepare recipient
        my @SearchAddress = Mail::Address->parse($Recipient{UserEmail});

        # backends currently only supports one recipient
        if ( $#SearchAddress == 0 ) {

            if ( $ConfigObject->Get('PGP') ) {
                # get pgp backend
                my $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::PGP');

                # Check() returns error-message or nothing if everything is fine
                if ( !$CryptObject->Check() ) {
                    my @PublicKeys = $CryptObject->PublicKeySearch(
                        Search => $SearchAddress[0]->address(),
                    );

                    PGPCRYPTKEY:
                    for my $DataRef (@PublicKeys) {
                        if ( $Notification{Type} =~ m/text\/html/ ) {
                            $SendParams{Crypt} = {
                                Type    => 'PGP',
                                SubType => 'Detached',
                                Key     => $DataRef->{Key},
                            };
                        } else {
                            $SendParams{Crypt} = {
                                Type    => 'PGP',
                                SubType => 'Inline',
                                Key     => $DataRef->{Key},
                            };
                        }
                        last PGPCRYPTKEY;
                    }
                }
            }

            if ( $ConfigObject->Get('SMIME') ) {
                # get smime backend
                my $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');

                # Check() returns error-message or nothing if everything is fine
                if ( !$CryptObject->Check() ) {
                    my @PublicKeys = $CryptObject->CertificateSearch(
                        Search => $SearchAddress[0]->address(),
                    );

                    SMIMECRYPTKEY:
                    for my $DataRef (@PublicKeys) {
                        $SendParams{Crypt} = {
                            Type    => 'SMIME',
                            SubType => 'Detached',
                            Key     => $DataRef->{Filename},
                        };
                        last SMIMECRYPTKEY;
                    }
                }
            }
        }

        if (
            !$SendParams{Crypt}
            && $Notification{Data}->{RecipientCrypt}->[0] == 2
        ) {
            return 1;
        }
    }
# EO NotificationEventX-capeIT

    # send notification
    if ( $Recipient{Type} eq 'Agent' ) {

# NotificationEventX-capeIT
        # process sign
        if ($Notification{Data}->{RecipientSign}->[0]) {
            # prepare recipient
            my @SearchAddress = Mail::Address->parse($ConfigObject->Get('NotificationSenderEmail'));

            # backends currently only supports one recipient
            if ( $#SearchAddress == 0 ) {

                if ( $ConfigObject->Get('PGP') ) {
                    # get pgp backend
                    my $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::PGP');

                    # Check() returns error-message or nothing if everything is fine
                    if ( !$CryptObject->Check() ) {
                        my @PrivateKeys = $CryptObject->PrivateKeySearch(
                            Search => $SearchAddress[0]->address(),
                        );

                        PGPSIGNKEY:
                        for my $DataRef (@PrivateKeys) {
                            if ( $Notification{Type} =~ m/text\/html/ ) {
                                $SendParams{Sign} = {
                                    Type    => 'PGP',
                                    SubType => 'Detached',
                                    Key     => $DataRef->{Key},
                                };
                            } else {
                                $SendParams{Sign} = {
                                    Type    => 'PGP',
                                    SubType => 'Inline',
                                    Key     => $DataRef->{Key},
                                };
                            }
                            last PGPSIGNKEY;
                        }
                    }
                }

                if ( $ConfigObject->Get('SMIME') ) {
                    # get smime backend
                    my $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');

                    # Check() returns error-message or nothing if everything is fine
                    if ( !$CryptObject->Check() ) {
                        my @PrivateKeys = $CryptObject->PrivateSearch(
                            Search => $SearchAddress[0]->address(),
                        );

                        SMIMESIGNKEY:
                        for my $DataRef (@PrivateKeys) {
                            $SendParams{Sign} = {
                                Type    => 'SMIME',
                                SubType => 'Detached',
                                Key     => $DataRef->{Filename},
                            };
                            last SMIMESIGNKEY;
                        }
                    }
                }
            }

            if (
                !$SendParams{Sign}
                && $Notification{Data}->{RecipientSign}->[0] == 2
            ) {
                return 1;
            }
        }
# EO NotificationEventX-capeIT

        # get needed objects
        my $EmailObject = $Kernel::OM->Get('Kernel::System::Email');

        my $Sent = $EmailObject->Send(
            From       => $From,
            To         => $Recipient{UserEmail},
            Subject    => $Notification{Subject},
            MimeType   => $Notification{ContentType},
            Type       => $Notification{ContentType},
            Charset    => 'utf-8',
            Body       => $Notification{Body},
            Loop       => 1,
            Attachment => $Param{Attachments},
# NotificationEventX-capeIT
            %SendParams,
# EO NotificationEventX-capeIT
        );

        if ( !$Sent ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "'$Notification{Name}' notification could not be sent to agent '$Recipient{UserEmail} ",
            );

            return;
        }

        # log event
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'info',
            Message  => "Sent agent '$Notification{Name}' notification to '$Recipient{UserEmail}'.",
        );

        # set event data
        $Self->{EventData} = {
            Event => 'ArticleAgentNotification',
            Data  => {
                TicketID => $Param{TicketID},

                # KIX4OTRS-capeIT
                # out of office-substitute notification
                RecipientMail => $Recipient{UserEmail},
                Notification  => \%Notification,
                Attachment    => $Param{Attachments},

                # EO KIX4OTRS-capeIT
            },
            UserID => $Param{UserID},
        };
    }
    else {

        # get queue object
        my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

        my %Address;

        # get article
        my %Article = $TicketObject->ArticleLastCustomerArticle(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );

        # set "From" address from Article if exist, otherwise use ticket information, see bug# 9035
        if (%Article) {
            %Address = $QueueObject->GetSystemAddress( QueueID => $Article{QueueID} );
        }
        else {

            # get ticket data
            my %Ticket = $TicketObject->TicketGet(
                TicketID => $Param{TicketID},
            );

            %Address = $QueueObject->GetSystemAddress( QueueID => $Ticket{QueueID} );
        }

# NotificationEventX-capeIT
        # process sign
        if ($Notification{Data}->{RecipientSign}) {
            # prepare recipient
            my @SearchAddress = Mail::Address->parse($Address{Email});

            # backends currently only supports one recipient
            if ( $#SearchAddress == 0 ) {

                if ( $ConfigObject->Get('PGP') ) {
                    # get pgp backend
                    my $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::PGP');

                    # Check() returns error-message or nothing if everything is fine
                    if ( !$CryptObject->Check() ) {
                        my @PrivateKeys = $CryptObject->PrivateKeySearch(
                            Search => $SearchAddress[0]->address(),
                        );

                        PGPSIGNKEY:
                        for my $DataRef (@PrivateKeys) {
                            if ( $Notification{Type} =~ m/text\/html/ ) {
                                $SendParams{Sign} = {
                                    Type    => 'PGP',
                                    SubType => 'Detached',
                                    Key     => $DataRef->{Key},
                                };
                            } else {
                                $SendParams{Sign} = {
                                    Type    => 'PGP',
                                    SubType => 'Inline',
                                    Key     => $DataRef->{Key},
                                };
                            }
                            last PGPSIGNKEY;
                        }
                    }
                }

                if ( $ConfigObject->Get('SMIME') ) {
                    # get smime backend
                    my $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');

                    # Check() returns error-message or nothing if everything is fine
                    if ( !$CryptObject->Check() ) {

                        my @PrivateKeys = $CryptObject->PrivateSearch(
                            Search => $SearchAddress[0]->address(),
                        );

                        SMIMESIGNKEY:
                        for my $DataRef (@PrivateKeys) {
                            $SendParams{Sign} = {
                                Type    => 'SMIME',
                                SubType => 'Detached',
                                Key     => $DataRef->{Filename},
                            };
                            last SMIMESIGNKEY;
                        }
                    }
                }
            }

            if (
                !$SendParams{Sign}
                && $Notification{Data}->{RecipientSign} == 2
            ) {
                return 1;
            }
        }
# EO NotificationEventX-capeIT

        my $ArticleType = 'email-notification-ext';

        if ( IsArrayRefWithData( $Param{Notification}->{Data}->{NotificationArticleTypeID} ) ) {

            # get notification article type
            $ArticleType = $TicketObject->ArticleTypeLookup(
                ArticleTypeID => $Param{Notification}->{Data}->{NotificationArticleTypeID}->[0],
            );
        }

        my $ArticleID = $TicketObject->ArticleSend(
            ArticleType    => $ArticleType,
            SenderType     => 'system',
            TicketID       => $Param{TicketID},
            HistoryType    => 'SendCustomerNotification',
            HistoryComment => "\%\%$Recipient{UserEmail}",
            From           => "$Address{RealName} <$Address{Email}>",
            To             => $Recipient{UserEmail},
            Subject        => $Notification{Subject},
            Body           => $Notification{Body},
            MimeType       => $Notification{ContentType},
            Type           => $Notification{ContentType},
            Charset        => 'utf-8',
            UserID         => $Param{UserID},
            Loop           => 1,
            Attachment     => $Param{Attachments},
# NotificationEventX-capeIT
            %SendParams,
# EO NotificationEventX-capeIT
        );

        if ( !$ArticleID ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "'$Notification{Name}' notification could not be sent to customer '$Recipient{UserEmail} ",
            );

            return;
        }

        # log event
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'info',
            Message  => "Sent customer '$Notification{Name}' notification to '$Recipient{UserEmail}'.",
        );

        # set event data
        $Self->{EventData} = {
            Event => 'ArticleCustomerNotification',
            Data  => {
                TicketID  => $Param{TicketID},
                ArticleID => $ArticleID,
            },
            UserID => $Param{UserID},
        };
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

    # get recipients by RecipientEmail
    if ( $Param{Notification}->{Data}->{RecipientEmail} ) {
        if ( $Param{Notification}->{Data}->{RecipientEmail}->[0] ) {
            my %Recipient;
            $Recipient{Realname}  = '';
            $Recipient{Type}      = 'Customer';
            $Recipient{UserEmail} = $Param{Notification}->{Data}->{RecipientEmail}->[0];

            # check if we have a specified article type
            if ( $Param{Notification}->{Data}->{NotificationArticleTypeID} ) {
                $Recipient{NotificationArticleType} = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeLookup(
                    ArticleTypeID => $Param{Notification}->{Data}->{NotificationArticleTypeID}->[0]
                ) || 'email-notification-ext';
            }

            # check recipients
            if ( $Recipient{UserEmail} && $Recipient{UserEmail} =~ /@/ ) {
                push @Recipients, \%Recipient;
            }
        }
    }

# NotificationEventX-capeIT
    # get object
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    # get dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    );

    # get dynamic fields config
    my %DynamicFieldConfig;
    for my $DynamicField (@{$DynamicFieldList}) {
        $DynamicFieldConfig{ $DynamicField->{ID} } = \%{$DynamicField};
    }

    # get recipients by RecipientAgentDF
    if (
        $Param{Notification}->{Data}->{RecipientAgentDF}
        && ref($Param{Notification}->{Data}->{RecipientAgentDF}) eq 'ARRAY'
    ) {
        FIELD:
        for my $ID ( sort( @{ $Param{Notification}->{Data}->{RecipientAgentDF} } ) ) {
            next FIELD if !$DynamicFieldConfig{$ID};

            # generate recipient
            my %Recipient = (
                DynamicFieldName => $DynamicFieldConfig{$ID}->{Name},
                DynamicFieldType => $DynamicFieldConfig{$ID}->{FieldType},
                Type             => 'Agent',
            );
            push (@Recipients, \%Recipient);
        }
    }

    # get recipients by RecipientCustomerDF
    if (
        $Param{Notification}->{Data}->{RecipientCustomerDF}
        && ref($Param{Notification}->{Data}->{RecipientCustomerDF}) eq 'ARRAY'
    ) {
        FIELD:
        for my $ID ( sort( @{ $Param{Notification}->{Data}->{RecipientCustomerDF} } ) ) {
            next FIELD if !$DynamicFieldConfig{$ID};

            # generate recipient
            my %Recipient = (
                DynamicFieldName => $DynamicFieldConfig{$ID}->{Name},
                DynamicFieldType => $DynamicFieldConfig{$ID}->{FieldType},
                Type             => 'Customer',
            );
            push (@Recipients, \%Recipient);
        }
    }
# EO NotificationEventX-capeIT

    return @Recipients;
}

sub TransportSettingsDisplayGet {
    my ( $Self, %Param ) = @_;

    KEY:
    for my $Key (qw(RecipientEmail)) {
        next KEY if !$Param{Data}->{$Key};
        next KEY if !defined $Param{Data}->{$Key}->[0];
        $Param{$Key} = $Param{Data}->{$Key}->[0];
    }

    my $Home              = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my $TemplateDir       = "$Home/Kernel/Output/HTML/Templates/Standard/NotificationEvent/Email";
    my $CustomTemplateDir = "$Home/Custom/Kernel/Output/HTML/Templates/Standard/NotificationEvent/Email";

    my @Files = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $TemplateDir,
        Filter    => '*.tt',
    );
    if ( -d $CustomTemplateDir ) {
        push @Files, $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
            Directory => $CustomTemplateDir,
            Filter    => '*.tt',
        );
    }

    # for deduplication
    my %Templates;

    for my $File (@Files) {
        $File =~ s{^.*/([^/]+)\.tt}{$1}smxg;
        $Templates{$File} = $File;
    }

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # Display article types for article creation if notification is sent
    # only use 'email-notification-*'-type articles
    my %NotificationArticleTypes = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeList( Result => 'HASH' );
    for my $NotifArticleTypeID ( sort keys %NotificationArticleTypes ) {
        if ( $NotificationArticleTypes{$NotifArticleTypeID} !~ /^email-notification-/ ) {
            delete $NotificationArticleTypes{$NotifArticleTypeID};
        }
    }
    $Param{NotificationArticleTypesStrg} = $LayoutObject->BuildSelection(
        Data        => \%NotificationArticleTypes,
        Name        => 'NotificationArticleTypeID',
        Translation => 1,
        SelectedID  => $Param{Data}->{NotificationArticleTypeID},
        Class       => 'Modernize',
    );

    $Param{TransportEmailTemplateStrg} = $LayoutObject->BuildSelection(
        Data        => \%Templates,
        Name        => 'TransportEmailTemplate',
        Translation => 0,
        SelectedID  => $Param{Data}->{TransportEmailTemplate},
        Class       => 'Modernize',
    );

# NotificationEventX-capeIT
    # get objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject  = $Kernel::OM->Get('Kernel::System::DynamicField');

    # get DynamicFields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        ObjectType => ['Ticket'],
        Valid      => 1,
    );

    if (
        $DynamicFieldList
        && ref($DynamicFieldList) eq 'ARRAY'
        && @{$DynamicFieldList}
    ) {

        my %AgentDynamicFieldHash = ();
        my %CustomerDynamicFieldHash = ();
        for my $DynamicField (@{$DynamicFieldList}) {
            next if (
                !$DynamicField
                || ref($DynamicField) ne 'HASH'
                || !%{$DynamicField}
            );

            $AgentDynamicFieldHash{$DynamicField->{ID}} = $DynamicField->{Name};
            $CustomerDynamicFieldHash{$DynamicField->{ID}} = $DynamicField->{Name};
        }

        my %BlockData;
        $BlockData{RecipientAgentDFStrg} .= $LayoutObject->BuildSelection(
            Data        => \%AgentDynamicFieldHash,
            Name        => 'RecipientAgentDF',
            Translation => 0,
            Multiple    => 1,
            Size        => 5,
            SelectedID  => $Param{Data}->{RecipientAgentDF},
            Sort        => 'AlphanumericID',
        );
        $BlockData{RecipientCustomerDFStrg} .= $LayoutObject->BuildSelection(
            Data        => \%CustomerDynamicFieldHash,
            Name        => 'RecipientCustomerDF',
            Translation => 0,
            Multiple    => 1,
            Size        => 5,
            SelectedID  => $Param{Data}->{RecipientCustomerDF},
            Sort        => 'AlphanumericID',
        );
        $LayoutObject->Block(
            Name => 'EmailXDynamicField',
            Data => \%BlockData,
        );
    }

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

    # check for enabled crypt module
    if (
        $ConfigObject->Get('SMIME')
        || $ConfigObject->Get('PGP')
    ) {
        my %CryptSignSelection = (
            0 => '-',
            1 => 'if possible',
            2 => 'mandatory',
        );

        my %BlockData;
        $BlockData{RecipientCryptStrg} = $LayoutObject->BuildSelection(
            Data        => \%CryptSignSelection,
            Name        => 'RecipientCrypt',
            Translation => 1,
            SelectedID  => $Param{Data}->{RecipientCrypt},
            Class       => 'Modernize',
        );
        $BlockData{RecipientSignStrg} = $LayoutObject->BuildSelection(
            Data        => \%CryptSignSelection,
            Name        => 'RecipientSign',
            Translation => 1,
            SelectedID  => $Param{Data}->{RecipientSign},
            Class       => 'Modernize',
        );
        $LayoutObject->Block(
            Name => 'EmailXCrypt',
            Data => \%BlockData,
        );
    }
# EO NotificationEventX-capeIT

    # generate HTML
    my $Output = $LayoutObject->Output(
# NotificationEventX-capeIT
#        TemplateFile => 'AdminNotificationEventTransportEmailSettings',
        TemplateFile => 'AdminNotificationEventTransportEmailXSettings',
# EO NotificationEventX-capeIT
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
# NotificationEventX-capeIT
#    for my $Parameter (qw(RecipientEmail NotificationArticleTypeID TransportEmailTemplate)) {
    for my $Parameter (qw(RecipientEmail NotificationArticleTypeID TransportEmailTemplate RecipientAgentDF RecipientCustomerDF RecipientSubject RecipientCrypt RecipientSign)) {
# EO NotificationEventX-capeIT
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

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
