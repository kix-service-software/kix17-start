# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerUser::ConfigItem;

use strict;
use warnings;

use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    for (
        qw(ConfigObject LogObject DBObject LayoutObject TicketObject MainObject UserID EncodeObject ParamObject)
    ) {
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
