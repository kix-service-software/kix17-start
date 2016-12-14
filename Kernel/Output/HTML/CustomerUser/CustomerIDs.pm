# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::Output::HTML::CustomerUser::CustomerIDs;

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

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # return if nothing should be shown...
    my $CallingAction = $Param{Data}->{CallingAction} || '';
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
