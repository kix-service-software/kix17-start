# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::AddToAddressBook;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::AddressBook',
    'Kernel::System::CustomerUser',
    'Kernel::System::Log',
    'Kernel::System::SystemAddress',
    'Kernel::System::Ticket',
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
    $Self->{AddressBookObject}   = $Kernel::OM->Get('Kernel::System::AddressBook');
    $Self->{CustomerUserObject}  = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{LogObject}           = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{SystemAddressObject} = $Kernel::OM->Get('Kernel::System::SystemAddress');
    $Self->{TicketObject}        = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    for my $CurrKey (qw(Event Data)) {
        if ( !$Param{$CurrKey} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "AddToAddressBook: Need $CurrKey!"
            );
            return;
        }
    }

    if ( $Param{Event} eq 'ArticleCreate' ) {

        # check required params...
        for my $CurrKey (qw(ArticleID)) {
            if ( !$Param{Data}->{$CurrKey} ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "AddToAddressBook: Need $CurrKey!"
                );
                return;
            }
        }

        my %Article = $Self->{TicketObject}->ArticleGet(
            ArticleID => $Param{Data}->{ArticleID},
        );


        # extract all mail addresses
        my @SplitAddresses;
        foreach (qw(From To Cc)) {
            next if ( !$Article{$_} );
            push(@SplitAddresses, grep {/.+@.+/} split( /[<>,"\s\/\\()\[\]\{\}]/, $Article{$_} ) );
        }

        # lookup each mail address
        MAILADDRESS:
        for my $CurrEmailAddress (@SplitAddresses) {
            # accept only valid email adresses
            next if ($CurrEmailAddress =~ /^\s*'.*?'\s*$/g);

            # ignore system addresses
            next if ($Self->{SystemAddressObject}->SystemAddressIsLocalAddress( Address => $CurrEmailAddress ));

            # check customer backends for this mail address
            my %UserListCustomer = $Self->{CustomerUserObject}->CustomerSearch(
                PostMasterSearch => $CurrEmailAddress,
            );
            next MAILADDRESS if (%UserListCustomer);

            # check address book
            my %AddressList = $Self->{AddressBookObject}->AddressList(
                Search => $CurrEmailAddress,
            );
            next MAILADDRESS if (%AddressList);

            # nothing found => add this email address to the address book
            my $Result = $Self->{AddressBookObject}->AddAddress(
                Email => $CurrEmailAddress,
            );
            if ( !$Result ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "AddToAddressBook: unable to add email address \"$CurrEmailAddress\" to address book."
                );
            }
        }
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
