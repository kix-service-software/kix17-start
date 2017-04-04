# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::AutoCreateLinkedPerson;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CustomerUser',
    'Kernel::System::Link',
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

                    my $Success = $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'Person',
                        SourceKey    => $User{UserLogin},
                        TargetObject => 'Ticket',
                        TargetKey    => $Data{TicketID},
                        Type         => $Type,
                        State        => 'Valid',
                        UserID       => $Param{UserID},
                    );

                    $Self->{TicketObject}->HistoryAdd(
                        Name         => 'added involved person ' . $CurrUserID,
                        HistoryType  => 'TicketLinkAdd',
                        TicketID     => $Ticket{TicketID},
                        CreateUserID => 1,
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
                        )
                    {
                        $Type = "Customer";
                    }

                    $Blacklisted = 0;
                    for my $Item (@Blacklist) {
                        next if $CurrUserLogin !~ m/$Item/;
                        $Blacklisted = 1;
                        last;
                    }
                    next if $Blacklisted;

                    # add links to database
                    my $Success = $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'Person',
                        SourceKey    => $CustomerUserData{UserLogin},
                        TargetObject => 'Ticket',
                        TargetKey    => $Data{TicketID},
                        Type         => $Type,
                        State        => 'Valid',
                        UserID       => $Param{UserID},
                    );

                    $Self->{TicketObject}->HistoryAdd(
                        Name         => 'added involved person ' . $CurrUserLogin,
                        HistoryType  => 'TicketLinkAdd',
                        TicketID     => $Ticket{TicketID},
                        CreateUserID => 1,
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

        my $Success = $Self->{LinkObject}->LinkAdd(
            SourceObject => 'Person',
            SourceKey    => $User{UserLogin},
            TargetObject => 'Ticket',
            TargetKey    => $Data{TicketID},
            Type         => 'Agent',
            State        => 'Valid',
            UserID       => $Param{UserID},
        );

        $Self->{TicketObject}->HistoryAdd(
            Name         => 'added involved person ' . $User{UserLogin},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Ticket{TicketID},
            CreateUserID => 1,
        );

    }

    #---------------------------------------------------------------------------
    # EVENT TicketOwnerUpdate / TicketResponsibleUpdate...
    elsif (
        $Param{Event} eq 'TicketOwnerUpdate'
        || $Param{Event} eq 'TicketResponsibleUpdate'
        )
    {

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

        my $Success = $Self->{LinkObject}->LinkAdd(
            SourceObject => 'Person',
            SourceKey    => $User{UserLogin},
            TargetObject => 'Ticket',
            TargetKey    => $Data{TicketID},
            Type         => 'Agent',
            State        => 'Valid',
            UserID       => $Param{UserID},
        );

        $Self->{TicketObject}->HistoryAdd(
            Name         => 'added involved person ' . $User{UserLogin},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Ticket{TicketID},
            CreateUserID => 1,
        );
    }

    elsif ( $Param{Event} eq 'TicketCustomerUpdate' )
    {

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );
        my %CustomerUserData =
            $Self->{CustomerUserObject}->CustomerUserDataGet( User => $Ticket{CustomerUserID} );

        $Blacklisted = 0;
        for my $Item (@Blacklist) {
            next if $Ticket{CustomerUserID} !~ m/$Item/ && $CustomerUserData{UserEmail} !~ m/$Item/;
            $Blacklisted = 1;
            last;
        }
        return 1 if $Blacklisted;

        my $Success = $Self->{LinkObject}->LinkAdd(
            SourceObject => 'Person',
            SourceKey    => $Ticket{CustomerUserID},
            TargetObject => 'Ticket',
            TargetKey    => $Data{TicketID},
            Type         => 'Customer',
            State        => 'Valid',
            UserID       => $Param{UserID},
        );

        $Self->{TicketObject}->HistoryAdd(
            Name         => 'added involved person ' . $Ticket{CustomerUserID},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Ticket{TicketID},
            CreateUserID => 1,
        );
    }

    elsif ( $Param{Event} eq 'TicketMerge' ) {
        return if !$Data{MainTicketID};

        # get ticket data and ticket state
        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );
        my %State = $Self->{StateObject}->StateGet( ID => $Ticket{StateID} );

        # if ticket is merged, linked persons will be added to target
        if ( $State{TypeName} eq 'merged' ) {

            my $LinkList = $Self->{LinkObject}->LinkList(
                Object  => 'Ticket',
                Key     => $Data{TicketID},
                Object2 => 'Person',
                State   => 'Valid',
                UserID  => 1,
            );

            for my $LinkType ( keys %{ $LinkList->{Person} } ) {
                for my $Person ( keys %{ $LinkList->{Person}->{$LinkType}->{Source} } ) {

                    $Blacklisted = 0;
                    for my $Item (@Blacklist) {
                        next if $Person !~ m/$Item/;
                        $Blacklisted = 1;
                        last;
                    }
                    next if $Blacklisted;

                    my $Success = $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'Person',
                        SourceKey    => $Person,
                        TargetObject => 'Ticket',
                        TargetKey    => $Data{MainTicketID},
                        Type         => $LinkType,
                        State        => 'Valid',
                        UserID       => $Param{UserID},
                    );

                    $Self->{TicketObject}->HistoryAdd(
                        Name         => 'added involved person ',
                        HistoryType  => 'TicketLinkAdd',
                        TicketID     => $Data{MainTicketID},
                        CreateUserID => 1,
                    );
                }
            }
        }
    }

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
