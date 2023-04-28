# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CustomerUser::Event::ServiceMemberUpdate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Service',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw( Data Event Config UserID )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for (qw( UserLogin NewData OldData )) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # only update CustomerUser <> Service if fields have really changed
    if ( $Param{Data}->{OldData}->{UserLogin} ne $Param{Data}->{NewData}->{UserLogin} ) {

        # get service object
        my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');

        my @Services = $ServiceObject->CustomerUserServiceMemberList(
            CustomerUserLogin => $Param{Data}->{OldData}->{UserLogin},
            Result            => 'ARRAY',
            DefaultServices   => 0,
        );

        for my $ServiceID (@Services) {

            # first remove old customer id as service member
            $ServiceObject->CustomerUserServiceMemberAdd(
                CustomerUserLogin => $Param{Data}->{OldData}->{UserLogin},
                ServiceID         => $ServiceID,
                Active            => 0,
                UserID            => 1,
            );

            # add new customer id as service member
            $ServiceObject->CustomerUserServiceMemberAdd(
                CustomerUserLogin => $Param{Data}->{NewData}->{UserLogin},
                ServiceID         => $ServiceID,
                Active            => 1,
                UserID            => 1,
            );
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
