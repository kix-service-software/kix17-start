# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Permission::CreatorCheck;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CheckItem',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
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
    for (qw(TicketID UserID Type)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get ticket data without dynamic fields
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
        Silent        => 1,
    );
    return if !%Ticket;
    return if !$Ticket{CreateBy};

    # get queue config
    my $Queues = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Permission::CreatorCheck::Queues');

    # check queues
    if ( $Queues && ref $Queues eq 'HASH' && %{$Queues} && $Ticket{Queue} ) {

        return if !$Queues->{ $Ticket{Queue} };

        # get check item object
        my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

        # extract permission list
        my @PermissionList = split ',', $Queues->{ $Ticket{Queue} };

        my %PermissionList;
        STRING:
        for my $String (@PermissionList) {

            next STRING if !$String;

            # trim the string
            $CheckItemObject->StringClean(
                StringRef => \$String,
            );

            next STRING if !$String;

            $PermissionList{$String} = 1;
        }

        # if a permission like 'note' is given, the 'ro' permission is required to calculate the right permission
        $PermissionList{ro} = 1;

        return if !$PermissionList{rw} && !$PermissionList{ $Param{Type} };
    }

    return 1 if $Ticket{CreateBy} eq $Param{UserID};

    # return no access
    return;
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
