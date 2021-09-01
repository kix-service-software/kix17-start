# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::DFTypeObjectReferenceAddLink;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor',
    'Kernel::System::CustomerUser',
    'Kernel::System::DynamicField',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ExecutorObject}     = $Kernel::OM->Get('Kernel::System::AsynchronousExecutor::LinkedTicketPersonExecutor');
    $Self->{CustomerUserObject} = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{LinkObject}         = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}          = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}       = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Self->{LogObject}
                ->Log( Priority => 'error', Message => "Need $_ in Data!" );
            return;
        }
    }

    # get current ticket data
    my %Ticket = $Self->{TicketObject}->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 1,
        Silent        => 1,
        UserID        => $Param{UserID},
    );
    return 1 if ( !%Ticket );

    # check event
    if ( $Param{Event} =~ /TicketDynamicFieldUpdate_(.*)/ ) {

        my $Field = "DynamicField_" . $1;
        my $DynamicFieldData = $Self->{DynamicFieldObject}->DynamicFieldGet( Name => $1 );

        # nothing to do if Dynamic Field not of type CustomerUser or if customer was deleted
        return if ( $DynamicFieldData->{FieldType} ne 'CustomerUser' );
        return if ( !$Ticket{$Field} );
        return if ( ref( $Ticket{$Field} ) ne 'ARRAY' );

        # process values
        CUSTOMERUSER:
        for my $CustomerUserID ( @{ $Ticket{$Field} } ) {
            next CUSTOMERUSER if ( !$CustomerUserID );

            # get customer user entry
            my %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet( User => $CustomerUserID );
            next CUSTOMERUSER if ( !%CustomerUserData );

            # call async execution
            $Self->{ExecutorObject}->AsyncCall(
                TicketID      => $Ticket{TicketID},
                PersonID      => $CustomerUserData{UserLogin},
                PersonHistory => $CustomerUserData{UserLogin},
                LinkType      => 'Customer',
                UserID        => $Param{UserID},
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
