# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::AutoCreateLinkedPerson;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor',
    'Kernel::System::CustomerUser',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::SystemAddress',
    'Kernel::System::State',
    'Kernel::System::Ticket',
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
    $Self->{ConfigObject}        = $Kernel::OM->Get('Kernel::Config');
    $Self->{ExecutorObject}      = $Kernel::OM->Get('Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor');
    $Self->{CustomerUserObject}  = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{LinkObject}          = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}           = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{SystemAddressObject} = $Kernel::OM->Get('Kernel::System::SystemAddress');
    $Self->{StateObject}         = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TicketObject}        = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{UserObject}          = $Kernel::OM->Get('Kernel::System::User');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    for my $CurrKey (qw(Event Data)) {
        if ( !$Param{$CurrKey} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $CurrKey!"
            );
            return;
        }
    }

    my %Data      = %{ $Param{Data} };
    my $ConfigRef = $Self->{ConfigObject}->Get('AutoCreateLinkedPerson');
    my @Blacklist = @{ $ConfigRef->{Blacklist} };

    my $Blacklisted;

    if ( $Param{Event} eq 'ArticleCreate' ) {

        # check required params...
        for my $CurrKey (qw(TicketID ArticleID)) {
            if ( !$Data{$CurrKey} ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "Need $CurrKey!"
                );
                return;
            }
        }

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );
        my %Article = $Self->{TicketObject}->ArticleGet(
            ArticleID => $Data{ArticleID},
        );

        if ( $Article{ArticleTypeID} && $Article{ArticleTypeID} <= 5 ) {

            # extract all receipients mail addresses...
            my @SplitAddresses;
            foreach (qw(From To Cc)) {
                next if ( !$Article{$_} );
                push(
                    @SplitAddresses,
                    grep {/.+@.+/}
                        split( /[<>,"\s\/\\()\[\]\{\}]/, $Article{$_} )
                );
            }

            # lookup each mail address and add corresponding link...
            MAILADDRESS:
            for my $CurrEmailAddress (@SplitAddresses) {

                # check if mail address is blacklisted
                $Blacklisted = 0;
                for my $Item (@Blacklist) {
                    next if $CurrEmailAddress !~ m/$Item/;
                    $Blacklisted = 1;
                    last;
                }
                next if $Blacklisted;

                # check for systemaddresses...
                next
                    if (
                    $Self->{SystemAddressObject}
                    ->SystemAddressIsLocalAddress( Address => $CurrEmailAddress )
                    );

                #---------------------------------------------------------------
                # check in agent backend for this mail address...
                my %UserListAgent = $Self->{UserObject}->UserSearch(
                    PostMasterSearch => $CurrEmailAddress,
                    ValidID          => 1,
                );
                for my $CurrUserID ( keys(%UserListAgent) ) {
                    next if ( $CurrUserID == 1 );
                    my %User = $Self->{UserObject}->GetUserData(
                        UserID => $CurrUserID,
                        Valid  => 1,
                    );
                    next if !$User{UserLogin};
                    $Blacklisted = 0;
                    for my $Item (@Blacklist) {
                        next if $User{UserLogin} !~ m/$Item/;
                        $Blacklisted = 1;
                        last;
                    }
                    next if $Blacklisted;

                    my $Type = "Agent";

                    # call async execution
                    $Self->{ExecutorObject}->AsyncCall(
                        TicketID      => $Data{TicketID},
                        PersonID      => $User{UserLogin},
                        PersonHistory => $CurrUserID,
                        LinkType      => $Type,
                        UserID        => $Param{UserID},
                    );

                    # avoid adding agent as customer user - next mail address...
                    next MAILADDRESS;
                }

                #---------------------------------------------------------------
                # check in customer backend for this mail address...
                my %UserListCustomer = $Self->{CustomerUserObject}->CustomerSearch(
                    PostMasterSearch => $CurrEmailAddress,
                );
                for my $CurrUserLogin ( keys(%UserListCustomer) ) {

                    my %CustomerUserData =
                        $Self->{CustomerUserObject}->CustomerUserDataGet( User => $CurrUserLogin, );

                    # set type customer if users CustomerID equals tickets CustomerID...
                    my $Type = "3rdParty";

                    my $LinkList = $Self->{LinkObject}->LinkList(
                        Object  => 'Ticket',
                        Key     => $Data{TicketID},
                        Object2 => 'Person',
                        State   => 'Valid',
                        UserID  => $Param{UserID},
                    );

                    # next if customer already linked
                    next
                        if defined $LinkList->{Person}->{Customer}->{Source}
                        ->{ $CustomerUserData{UserLogin} }
                        && $LinkList->{Person}->{Customer}->{Source}
                        ->{ $CustomerUserData{UserLogin} };
                    next
                        if defined $LinkList->{Person}->{'3rdParty'}->{Source}
                        ->{ $CustomerUserData{UserLogin} }
                        && $LinkList->{Person}->{'3rdParty'}->{Source}
                        ->{ $CustomerUserData{UserLogin} };

                    if (
                        $CustomerUserData{UserCustomerID}
                        && $Ticket{CustomerID}
                        && $Ticket{CustomerID} eq $CustomerUserData{UserCustomerID}
                    ) {
                        $Type = "Customer";
                    }

                    $Blacklisted = 0;
                    for my $Item (@Blacklist) {
                        next if $CurrUserLogin !~ m/$Item/;
                        $Blacklisted = 1;
                        last;
                    }
                    next if $Blacklisted;

                    # call async execution
                    $Self->{ExecutorObject}->AsyncCall(
                        TicketID      => $Data{TicketID},
                        PersonID      => $CustomerUserData{UserLogin},
                        PersonHistory => $CurrUserLogin,
                        LinkType      => $Type,
                        UserID        => $Param{UserID},
                    );

                    # avoid multiple links caused by multiple users for one mailaddress...
                    next MAILADDRESS;
                }

            }
        }

        #-----------------------------------------------------------------------
        # add current agent
        return if ( $Article{SenderTypeID} != 1 );
        return 1 if ( !$Param{UserID} || $Param{UserID} == 1 );

        my %User = $Self->{UserObject}->GetUserData(
            UserID => $Param{UserID},
            Valid  => 1,
        );
        return 1 if ( !$User{UserLogin} );
        $Blacklisted = 0;
        for my $Item (@Blacklist) {
            next if $User{UserLogin} !~ m/$Item/ && $User{UserEmail} !~ m/$Item/;
            $Blacklisted = 1;
            last;
        }
        next if $Blacklisted;

        # call async execution
        $Self->{ExecutorObject}->AsyncCall(
            TicketID      => $Data{TicketID},
            PersonID      => $User{UserLogin},
            PersonHistory => $User{UserLogin},
            LinkType      => 'Agent',
            UserID        => $Param{UserID},
        );

    }

    #---------------------------------------------------------------------------
    # EVENT TicketOwnerUpdate / TicketResponsibleUpdate...
    elsif (
        $Param{Event} eq 'TicketOwnerUpdate'
        || $Param{Event} eq 'TicketResponsibleUpdate'
    ) {

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );

        my $User =
            ( $Param{Event} eq 'TicketOwnerUpdate' )
            ? $Ticket{OwnerID}
            : $Ticket{ResponsibleID};
        return 1 if ( $User == 1 );

        my %User = $Self->{UserObject}->GetUserData(
            UserID => $User,
            Valid  => 1,
        );
        return 1 if ( !$User{UserLogin} );
        $Blacklisted = 0;
        for my $Item (@Blacklist) {
            next if $User{UserLogin} !~ m/$Item/ && $User{UserEmail} !~ m/$Item/;
            $Blacklisted = 1;
            last;
        }
        return 1 if $Blacklisted;

        # call async execution
        $Self->{ExecutorObject}->AsyncCall(
            TicketID      => $Data{TicketID},
            PersonID      => $User{UserLogin},
            PersonHistory => $User{UserLogin},
            LinkType      => 'Agent',
            UserID        => $Param{UserID},
        );
    }

    elsif ( $Param{Event} eq 'TicketCustomerUpdate' ) {

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );
        my %CustomerUserData =
            $Self->{CustomerUserObject}->CustomerUserDataGet( User => $Ticket{CustomerUserID} );

        $Blacklisted = 0;
        for my $Item (@Blacklist) {
            next
                if (
                !defined $CustomerUserData{UserEmail}
                || !defined $Ticket{CustomerUserID}
                || (
                    $Ticket{CustomerUserID} !~ m/$Item/
                    && $CustomerUserData{UserEmail} !~ m/$Item/
                )
                );
            $Blacklisted = 1;
            last;
        }
        return 1 if $Blacklisted;

        # call async execution
        $Self->{ExecutorObject}->AsyncCall(
            TicketID      => $Data{TicketID},
            PersonID      => $Ticket{CustomerUserID},
            PersonHistory => $Ticket{CustomerUserID},
            LinkType      => 'Customer',
            UserID        => $Param{UserID},
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
