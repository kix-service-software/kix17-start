# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerUser::CustomerIDs;

use strict;
use warnings;

use Kernel::System::ObjectManager;

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

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # return if nothing should be shown...
    my $CallingAction = $Param{CallingAction} || '';
    my $ShowSelectBox = ( $CallingAction =~ /$Param{Config}->{ShowSelectBoxActionRegExp}/ ) ? 1 : 0;
    return 1 if !$ShowSelectBox;

    # generate output...
    my $OutputStrg = $LayoutObject->CustomerAssignedCustomerIDsTable(
        CustomerUserID => $Param{Data}->{UserLogin} || '',
        AJAX           => $Param{Data}->{AJAX}      || 0,
    );

    $LayoutObject->Block(
        Name => 'CustomerIDsSelection',
        Data => {
            CustomerIDsStrg => $OutputStrg,
        },
    );

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
