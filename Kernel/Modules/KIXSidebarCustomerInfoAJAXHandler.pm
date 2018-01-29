# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarCustomerInfoAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Result;
    my %GetParam;

    # article get customer emails
    if ( $Self->{Subaction} eq 'LoadCustomerEmails' ) {
        foreach (qw(TicketID ArticleID SelectedCustomerID)) {
            $GetParam{$_} = $ParamObject->GetParam( Param => $_ );
        }

        my $Content = $Self->_BuildTicketContactsSelection(
            ArticleID => $GetParam{ArticleID} || 0,
            TicketID => $GetParam{TicketID},
            SelectedID => $GetParam{SelectedCustomerID},
        );

        return $LayoutObject->Attachment(
            ContentType => 'text/html',
            Charset     => $LayoutObject->{UserCharset},
            Content     => $Content,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    return 1;
}

sub _BuildTicketContactsSelection {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $LinkObject         = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    # check needed stuff
    for (qw(TicketID)) {
        if ( !$Param{$_} ) {
            $LogObject->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get config to display email adress
    my $ArticleTabConfig
        = $ConfigObject->Get('Ticket::Frontend::AgentTicketZoomTabArticle');
    my $ViewFrom = $ArticleTabConfig->{ArticleDetailViewFrom};

    # get user preferences to show article contacts or linked persons
    my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1,
    );

    my %Article;

    # get article data
    if ( !$Param{ArticleID} ) {

        # get first article data
        %Article = $TicketObject->ArticleFirstArticle(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );
    }
    else {

        # get article data
        %Article = $TicketObject->ArticleGet(
            ArticleID     => $Param{ArticleID},
            DynamicFields => 0,
        );
    }

    my %EmailData = ();
    my %FoundData = ();

    # return empty selection if no customer user defined
    return $LayoutObject->BuildSelection(
        Name => 'CustomerUserEmail',
        Data => \%EmailData,
    ) if !$Ticket{CustomerUserID};

    # get selected customer
    my $SelectedID = $Param{SelectedID} || $Ticket{CustomerUserID};

    # get ticket customer data
    my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
        User => $Ticket{CustomerUserID},
    );
    my $UserCustomerID = $CustomerUserData{UserCustomerID} || $Ticket{CustomerUserID};

    # get ticket customer
    if (%CustomerUserData) {
        if ( $ViewFrom eq 'Realname' ) {
            $EmailData{'Ticket Customer'}->{ $Ticket{CustomerUserID} }
                = $CustomerUserData{UserFirstname} . ' ' . $CustomerUserData{UserLastname};
        }
        else {
            $EmailData{'Ticket Customer'}->{ $Ticket{CustomerUserID} }
                = $CustomerUserData{UserEmail};
        }
    }
    else {
        $EmailData{'Ticket Customer'}->{ $Ticket{CustomerUserID} } = $Ticket{CustomerUserID};
    }

    # get article or linked person data
    if (
        !$UserPreferences{UserKIXSidebarCustomerEmailSelection}
        || $UserPreferences{UserKIXSidebarCustomerEmailSelection} eq 'LinkedPersons'
        )
    {

        # get linked objects
        my $LinkListWithData = $LinkObject->LinkListWithData(
            Object  => 'Ticket',
            Key     => $Param{TicketID},
            Object2 => 'Person',
            State   => 'Valid',
            UserID  => $Self->{UserID},
        );

        if (
            $LinkListWithData
            && $LinkListWithData->{Person}
            && ref( $LinkListWithData->{Person} ) eq 'HASH'
            )
        {
            for my $LinkType ( sort keys %{ $LinkListWithData->{Person} } ) {
                next if !$LinkListWithData->{Person}->{$LinkType};
                next if !$LinkListWithData->{Person}->{$LinkType}->{Source};
                next if ref $LinkListWithData->{Person}->{$LinkType}->{Source} ne 'HASH';

                SEARCHRESULT:
                for my $UserID ( sort keys %{ $LinkListWithData->{Person}->{$LinkType}->{Source} } )
                {
                    next if $EmailData{'Ticket Customer'}->{$UserID};
                    my $Found = 0;
                    my $CustomerLogin
                        = $LinkListWithData->{Person}->{$LinkType}->{Source}->{$UserID}
                        ->{UserLogin};
                    my %SearchResultCustomerUserData
                        = %{ $LinkListWithData->{Person}->{$LinkType}->{Source}->{$UserID} };
                    my $EmailAddress = $SearchResultCustomerUserData{UserEmail};
                    next if !$EmailAddress;

                    # customer is ticket customer
                    if (
                        defined $SearchResultCustomerUserData{UserCustomerID}
                        && $UserCustomerID eq $SearchResultCustomerUserData{UserCustomerID}
                        )
                    {
                        if ( $ViewFrom eq 'Realname' ) {
                            $EmailData{'Customer Contact'}->{$CustomerLogin}
                                = $SearchResultCustomerUserData{UserFirstname} . ' '
                                . $SearchResultCustomerUserData{UserLastname};
                        }
                        else {
                            $EmailData{'Customer Contact'}->{$CustomerLogin} = $EmailAddress;
                        }
                        $FoundData{$EmailAddress} = 1;
                        $Found = 1;
                    }

                    # customer login known but not ticket customer
                    else {
                        if ( $ViewFrom eq 'Realname' ) {
                            $EmailData{$LinkType}->{$CustomerLogin}
                                = $SearchResultCustomerUserData{UserFirstname} . ' '
                                . $SearchResultCustomerUserData{UserLastname};
                        }
                        else {
                            $EmailData{$LinkType}->{$CustomerLogin} = $EmailAddress;
                        }
                        $FoundData{$EmailAddress} = 1;
                        $Found = 1;
                    }

                    # not found in list
                    if ( !$Found ) {
                        $FoundData{$EmailAddress} = 1;
                    }
                }
            }
        }
    }
    else {

        # get recipients from to, from, cc and bcc
        for my $Item (qw(To From Cc Bcc)) {
            next if !defined $Article{$Item} || !$Article{$Item};

            # handling for multi-recipients
            my @Recipients = split( /,/, $Article{$Item} );
            for my $Recipient (@Recipients) {
                next if !$Recipient;

                # extract email address
                if ( $Recipient =~ m/^(.*?)(<(.*?)>)?$/ ) {

                    # get email address
                    my $EmailAddress = ($2) ? $3 : $1;

                    next if !$EmailAddress;

                    # if already used
                    next if $FoundData{$EmailAddress};

                    # look up possible customer users
                    my $Found = 0;
                    my %List  = $CustomerUserObject->CustomerSearch(
                        PostMasterSearch => $EmailAddress,
                    );

                    # look up if user has the same user customer id
                    if (%List) {
                        SEARCHRESULT:
                        for my $SearchResult ( keys %List ) {
                            my %SearchResultCustomerUserData
                                = $CustomerUserObject->CustomerUserDataGet(
                                User => $SearchResult,
                                );

                            # customer is ticket customer
                            if ( $UserCustomerID eq $SearchResultCustomerUserData{UserCustomerID} )
                            {
                                if ( $ViewFrom eq 'Realname' ) {
                                    $EmailData{'Customer Contact'}->{$SearchResult}
                                        = $SearchResultCustomerUserData{UserFirstname} . ' '
                                        . $SearchResultCustomerUserData{UserLastname};
                                }
                                else {
                                    $EmailData{'Customer Contact'}->{$SearchResult} = $EmailAddress;
                                }
                                $FoundData{$EmailAddress} = 1;
                                $Found = 1;
                                last SEARCHRESULT;
                            }

                            # customer login known but not ticket customer
                            else {
                                if ( $ViewFrom eq 'Realname' ) {
                                    $EmailData{'3rdParty'}->{$SearchResult}
                                        = $SearchResultCustomerUserData{UserFirstname} . ' '
                                        . $SearchResultCustomerUserData{UserLastname};
                                }
                                else {
                                    $EmailData{'3rdParty'}->{$SearchResult} = $EmailAddress;
                                }
                                $FoundData{$EmailAddress} = 1;
                                $Found = 1;
                            }
                        }
                    }

                    # not found in list
                    if ( !$Found ) {
                        $FoundData{$EmailAddress} = 1;
                    }
                }
            }
        }
    }

    # build priorized data list
    my %ListPrio = (
        'Ticket Customer'  => 0,
        'Customer Contact' => 1,
        'Customer'         => 2,
        '3rdParty'         => 3,
        'Agent'            => 4,
    );

    #
    my @EmailDataList;
    foreach my $ContactType ( sort { $ListPrio{$a} <=> $ListPrio{$b} } keys %EmailData ) {
        push(
            @EmailDataList,
            {
                Key      => '',
                Value    => '--- ' . $LayoutObject->{LanguageObject}->Translate($ContactType) . ' ---',
                Disabled => 1,
            }
        );
        foreach
            my $Contact (
            sort { $EmailData{$ContactType}->{$a} cmp $EmailData{$ContactType}->{$b} }
            keys %{ $EmailData{$ContactType} }
            )
        {
            push(
                @EmailDataList,
                {
                    Key   => $Contact,
                    Value => '    ' . $EmailData{$ContactType}->{$Contact},
                }
                )
        }
        push(
            @EmailDataList,
            {
                Key      => '',
                Value    => '',
                Disabled => 1,
            }
        );
    }

    # create selection
    my $Content = $LayoutObject->BuildSelection(
        Name         => 'CustomerUserEmail',
        Data         => \@EmailDataList,
        SelectedID   => $SelectedID,
        Translation  => 0,
        PossibleNone => 0,
    );

    foreach my $ContactType ( sort { $ListPrio{$a} <=> $ListPrio{$b} } keys %EmailData ) {
        foreach my $Contact (
            sort { $EmailData{$ContactType}->{$a} cmp $EmailData{$ContactType}->{$b} }
            keys %{ $EmailData{$ContactType} }
        ) {
            my $DataType = 'Customer';
            if ( $ContactType eq 'Agent') {
                $DataType = 'Agent';
            }
            $Content =~ s/(value=\"$Contact\")/$1 data-type=\"$DataType\" /ig;
        }
    }

    return $Content;
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
