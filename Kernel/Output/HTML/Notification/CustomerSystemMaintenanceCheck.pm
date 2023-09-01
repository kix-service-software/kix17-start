# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Notification::CustomerSystemMaintenanceCheck;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::SystemMaintenance',
    'Kernel::Output::HTML::Layout',
    'Kernel::Config',
    'Kernel::System::Time',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $SystemMaintenanceObject = $Kernel::OM->Get('Kernel::System::SystemMaintenance');
    my $LayoutObject            = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $ActiveMaintenance = $SystemMaintenanceObject->SystemMaintenanceIsActive();

    # check if system maintenance is active
    if ($ActiveMaintenance) {

        my $SystemMaintenanceData = $SystemMaintenanceObject->SystemMaintenanceGet(
            ID     => $ActiveMaintenance,
            UserID => $Self->{UserID},
        );

        my $NotifyMessage =
            $SystemMaintenanceData->{NotifyMessage}
            || $Kernel::OM->Get('Kernel::Config')->Get('SystemMaintenance::IsActiveDefaultNotification')
            || "System maintenance is active!";

        return $LayoutObject->Notify(
            Priority => 'Notice',
            Data =>
                $LayoutObject->{LanguageObject}->Translate(
                $NotifyMessage,
                ),
        );
    }

    my $SystemMaintenanceIsComming = $SystemMaintenanceObject->SystemMaintenanceIsComming();

    if ($SystemMaintenanceIsComming) {

        my $MaintenanceTime = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
            SystemTime => $SystemMaintenanceIsComming,
        );
        return $LayoutObject->Notify(
            Priority => 'Notice',
            Data =>
                $LayoutObject->{LanguageObject}->Translate(
                "A system maintenance period will start at: "
                )
                . $MaintenanceTime,
        );

    }

    return '';
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
