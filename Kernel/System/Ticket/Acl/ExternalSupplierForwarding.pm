# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::ExternalSupplierForwarding;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
);

sub new {
    my ( $Type, %Param ) = @_;

    #allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    #get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return 1 if !$Param{TicketID};

    my $FwdQueueRef   = $Kernel::OM->Get('Kernel::Config')->Get('ExternalSupplierForwarding::ForwardQueues');
    my @FwdQueueNames = keys( %{$FwdQueueRef} );

    my $FwdFaxQueueRef = $Kernel::OM->Get('Kernel::Config')->Get('ExternalSupplierForwarding::ForwardFaxQueues');
    my @FwdFaxQueueNames = keys( %{$FwdFaxQueueRef} );

    my @ExcludedQueues = ( @FwdQueueNames, @FwdFaxQueueNames );

    #---------------------------------------------------------------------------------
    #(0) do not allow move-queue action if forward-queue
    $Param{Acl}->{'500_ExternalSupplierForwarding'} = {
        Properties => {
            Ticket => {
                Queue => \@ExcludedQueues,
            },
        },
        Possible => {
            Action => {
                AgentTicketPrintForwardFax => 1,
            },
        },
    };

    #---------------------------------------------------------------------------------
    $Param{Acl}->{'499_ExternalSupplierForwarding'} = {
        Possible => {
            Action => {
                AgentTicketPrintForwardFax => 0,
            },
        },
    };

    return 1;
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
