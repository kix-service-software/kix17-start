# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXSidebarCustomer;

use strict;
use warnings;

use utf8;

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
    'Kernel::System::LinkObject'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{CustomerUserObject} = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{LinkObject}         = $Kernel::OM->Get('Kernel::System::LinkObject');

    return $Self;
}

sub KIXSidebarCustomerSearch {
    my ( $Self, %Param ) = @_;

    my %Result;

    # get linked objects
    if ( $Param{TicketID} && $Param{LinkMode} && $Param{LinkType} ) {
        my %LinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => 'Person',
            State   => $Param{LinkMode},
            Type    => $Param{LinkType},
            UserID  => 1,
        );

        for my $ID ( keys %LinkKeyList ) {
            my %CustomerUser = $Self->{CustomerUserObject}->CustomerUserDataGet(
                User => $ID,
            );

            if (
                %CustomerUser
                && defined $CustomerUser{Source}
                && defined $CustomerUser{ValidID}
                && "$CustomerUser{ValidID}" eq "1"
            ) {

                SOURCE:
                for my $Source ( @{ $Param{CustomerBackends} } ) {
                    if ($CustomerUser{Source} eq $Source) {
                        $Result{ $ID } = \%CustomerUser;
                        $Result{ $ID }->{'Link'} = 1;
                        last SOURCE;
                    }
                }

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );

            }
        }
    }

    # Search only if Search-String was given
    if ( $Param{SearchString} ) {

        my %Customers = $Self->{CustomerUserObject}->CustomerSearch(
            Search => $Param{SearchString},
            Valid  => 1,
        );

        ID:
        for my $ID ( keys %Customers ) {
            next ID if ( $Result{ $ID } );

            my %CustomerUser = $Self->{CustomerUserObject}->CustomerUserDataGet(
                User => $ID,
            );

            if (
                %CustomerUser
                && defined $CustomerUser{Source}
                && defined $CustomerUser{ValidID}
                && "$CustomerUser{ValidID}" eq "1"
            ) {

                SOURCE:
                for my $Source ( @{ $Param{CustomerBackends} } ) {
                    if ($CustomerUser{Source} eq $Source) {
                        $Result{ $ID } = \%CustomerUser;
                        $Result{ $ID }->{'Link'} = 0;
                        last SOURCE;
                    }
                }

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }

    }

    return \%Result;
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
