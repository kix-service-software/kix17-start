# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Ralf(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::Output::HTML::CustomerUser::ConfigItem;

use strict;
use warnings;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for (
        qw(ConfigObject LogObject DBObject LayoutObject TicketObject MainObject UserID EncodeObject ParamObject)
        )
    {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $CallingAction = $Param{Data}->{CallingAction} || $Param{CallingAction} || '';
    my $ShowSelectBox = ( $CallingAction =~ /$Param{Config}->{ShowSelectBoxActionRegExp}/ ) ? 1 : 0;

    # return if nothing should be shown...
    return 1 if ( !$ShowSelectBox && !$Param{Config}->{ShowListOnly} );

    # return if required attribute not configured or given...
    return 1
        if (
        !$Param{Config}->{SearchAttribute}
        || !$Param{Data}->{ $Param{Config}->{SearchAttribute} }
        );

    # generate output...
    #    my $OutputStrg = $LayoutObject->CustomerAssignedConfigItemsTable(
    my $OutputStrg = $LayoutObject->KIXSideBarAssignedConfigItemsTable(
        SearchPattern => $Param{Data}->{ $Param{Config}->{SearchAttribute} },
        ShowSelectBox => $ShowSelectBox,
        CallingAction => $CallingAction || '',
        UserID        => $Self->{UserID} || '',
        AJAX          => $Param{Data}->{AJAX} || 0,
    );

    $LayoutObject->Block(
        Name => 'CustomerAssignedConfigItem',
        Data => {
            AssignedConfigItemStrg => $OutputStrg,
        },
    );

    return 1;
}

1;
