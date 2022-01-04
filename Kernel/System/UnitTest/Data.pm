# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest::Data;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Lock',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::Service',
    'Kernel::System::SLA',
    'Kernel::System::State',
    'Kernel::System::Type',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::UnitTest::Data - global test data interface

=head1 SYNOPSIS

Functions to create and manipulate test data

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create unit test data object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $UnitTestDataObject = $Kernel::OM->Get('Kernel::System::UnitTest:Data');

=cut
sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # init flags
    $Self->{Database_Rollback} = 0;

    return $Self;
}

=item Database_BeginWork()

    $UnitTestDataObject->Database_BeginWork()

Starts a database transaction (in order to isolate the test from the static database).

=cut
sub Database_BeginWork {
    my ( $Self, %Param ) = @_;

    # remember to rollback database
    $Self->{Database_Rollback} = 1;

    # connect to database
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    $DBObject->Connect();

    # begin work on database handle
    return $DBObject->{dbh}->begin_work();
}

=item Database_Rollback()

    $UnitTestDataObject->Database_Rollback()

Rolls back the current database transaction.

=cut
sub Database_Rollback {
    my ( $Self, %Param ) = @_;

    # check database rollback flag
    if ( !$Self->{Database_Rollback} ) {
        return 1;
    }

    # remember that databse is rolled back
    $Self->{Database_Rollback} = 0;

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # if there is no database handle, there's nothing to rollback
    if ( $DBObject->{dbh} ) {
        # rollback on database handle
        return $DBObject->{dbh}->rollback();
    }
    return 1;
}

=item Data_Cleanup()

    $UnitTestDataObject->Data_Cleanup()

Clean up data

=cut
sub Data_Cleanup {
    my ( $Self, %Param ) = @_;

    # restore database
    if ( $Self->{Database_Rollback} ) {
        $Self->Database_Rollback();
    }

    # clean caches
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    return 1;
}

=item Ticket_CheckPrepare()

    $UnitTestDataObject->Ticket_CheckPrepare( %TicketData )

Prepare ticket data for ticket data check

=cut
sub Ticket_CheckPrepare {
    my ( $Self, %Param ) = @_;

    # init return data
    my %Data = ();

    # copy some values
    for my $Key ( qw(Title CustomerID ArchiveFlag) ) {
        if ( defined( $Param{ $Key } ) ) {
            $Data{ $Key } = $Param{ $Key };
        }
    }

    # get CustomerUserID  from CustomerUser
    if ( $Param{'CustomerUser'} ) {
        $Data{'CustomerUserID'} = $Param{'CustomerUser'};
    }

    # get state id from state
    if ( $Param{'State'} ) {
        $Data{'State'}   = $Param{'State'};
        $Data{'StateID'} = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
            State => $Param{'State'},
        );
    }
    # get state from state id
    elsif ( $Param{'StateID'} ) {
        $Data{'StateID'} = $Param{'StateID'};
        $Data{'State'}   = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
            StateID => $Param{'StateID'},
        );
    }

    # get state type from state id
    if ( $Data{'StateID'} ) {
        my %State = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            ID => $Data{'StateID'},
        );
        $Data{'StateType'} = $State{'TypeName'};
    }

    # get priority id from priority
    if ( $Param{'Priority'} ) {
        $Data{'Priority'}   = $Param{'Priority'};
        $Data{'PriorityID'} = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
            Priority => $Param{'Priority'},
        );
    }
    # get priority from priority id
    elsif ( $Param{'PriorityID'} ) {
        $Data{'PriorityID'} = $Param{'PriorityID'};
        $Data{'Priority'}   = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
            PriorityID => $Param{'PriorityID'},
        );
    }

    # get lock id from lock
    if ( $Param{'Lock'} ) {
        $Data{'Lock'}   = $Param{'Lock'};
        $Data{'LockID'} = $Kernel::OM->Get('Kernel::System::Lock')->LockLookup(
            Lock => $Param{'Lock'},
        );
    }
    # get lock from lock id
    elsif ( $Param{'LockID'} ) {
        $Data{'LockID'} = $Param{'LockID'};
        $Data{'Lock'}   = $Kernel::OM->Get('Kernel::System::Lock')->LockLookup(
            LockID => $Param{'LockID'},
        );
    }

    # get queue id from queue
    if ( $Param{'Queue'} ) {
        $Data{'Queue'}   = $Param{'Queue'};
        $Data{'QueueID'} = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            Queue => $Param{'Queue'},
        );
    }
    # get queue from queue id
    elsif ( $Param{'QueueID'} ) {
        $Data{'QueueID'} = $Param{'QueueID'};
        $Data{'Queue'}   = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            QueueID => $Param{'QueueID'},
        );
    }

    # get group id from queue id
    if ( $Data{'QueueID'} ) {
        my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
            ID => $Data{'QueueID'},
        );
        $Data{'GroupID'} = $Queue{'GroupID'};
    }

    # get owner id from owner
    if ( $Param{'Owner'} ) {
        $Data{'Owner'}   = $Param{'Owner'};
        $Data{'OwnerID'} = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $Param{'Owner'},
        );
    }
    # get owner from owner id
    elsif ( $Param{'OwnerID'} ) {
        $Data{'OwnerID'} = $Param{'OwnerID'};
        $Data{'Owner'}   = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserID => $Param{'OwnerID'},
        );
    }

    # get responsible id from responsible
    if ( $Param{'Responsible'} ) {
        $Data{'Responsible'}   = $Param{'Responsible'};
        $Data{'ResponsibleID'} = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $Param{'Responsible'},
        );
    }
    # get responsible from responsible id
    elsif ( $Param{'ResponsibleID'} ) {
        $Data{'ResponsibleID'} = $Param{'ResponsibleID'};
        $Data{'Responsible'}   = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserID => $Param{'ResponsibleID'},
        );
    }

    # get type id from type
    if ( $Param{'Type'} ) {
        $Data{'Type'}   = $Param{'Type'};
        $Data{'TypeID'} = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup(
            Type => $Param{'Type'},
        );
    }
    # get type from type id
    elsif ( $Param{'TypeID'} ) {
        $Data{'TypeID'} = $Param{'TypeID'};
        $Data{'Type'}   = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup(
            TypeID => $Param{'TypeID'},
        );
    }

    # get service id from service
    if ( $Param{'Service'} ) {
        $Data{'Service'}   = $Param{'Service'};
        $Data{'ServiceID'} = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
            Name => $Param{'Service'},
        );
    }
    # get service from service id
    elsif ( $Param{'ServiceID'} ) {
        $Data{'ServiceID'} = $Param{'ServiceID'};
        $Data{'Service'}   = $Kernel::OM->Get('Kernel::System::Service')->ServiceLookup(
            ServiceID => $Param{'ServiceID'},
        );
    }
    # set empty service id
    else {
        $Data{'ServiceID'} = '';
    }

    # get sla id from sla
    if ( $Param{'SLA'} ) {
        $Data{'SLA'}   = $Param{'SLA'};
        $Data{'SLAID'} = $Kernel::OM->Get('Kernel::System::SLA')->SLALookup(
            Name => $Param{'SLA'},
        );
    }
    # get sla from sla id
    elsif ( $Param{'SLAID'} ) {
        $Data{'SLAID'} = $Param{'SLAID'};
        $Data{'SLA'}   = $Kernel::OM->Get('Kernel::System::SLA')->SLALookup(
            SLAID => $Param{'SLAID'},
        );
    }
    # set empty sla id
    else {
        $Data{'SLAID'} = '';
    }

    # get ChangeBy and CreateBy from user id
    if ( $Param{'UserID'} ) {
        $Data{'ChangeBy'} = $Param{'UserID'};
        $Data{'CreateBy'} = $Param{'UserID'};
    }

    return %Data;
}

sub DESTROY {
    my $Self = shift;

    # clean up
    $Self->Data_Cleanup();

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
