# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::LinkObjectTargetIdentifier;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::ObjectManager;

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
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check data
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };

    # get identifier from sysconfig
    my $LinkObjectTargetIdentifier
        = $ConfigObject->Get('Ticket::LinkObjectTargetIdentifier');

    # create HMTL
    my $SearchPattern = '(TargetIdentifier=).*?([;"])';

    # do replace
    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms ) {
        ${ $Param{Data} } =~ s{$SearchPattern}{$1$LinkObjectTargetIdentifier$2}ixms;
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
