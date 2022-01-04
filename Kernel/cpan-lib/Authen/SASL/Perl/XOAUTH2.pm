# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Authen::SASL::Perl::XOAUTH2 ;

use strict ;
use warnings ;
use vars qw($VERSION @ISA);

$VERSION = "1.00";
@ISA     = qw( Authen::SASL::Perl );

my %secflags = (
    noanonymous => 1,
);

sub _order {
    return 1;
}

sub _secflags {
    shift;

    return scalar grep { $secflags{ $_ } } @_;
}

sub mechanism {
    return 'XOAUTH2';
};

sub client_start {
    my $Self = shift;

    return 'user=' . $Self->_call( 'user' ) . "\x01"
         . 'auth=' . $Self->_call( 'auth' )
         . ' ' . $Self->_call( 'access_token' ) . "\x01\x01";
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
