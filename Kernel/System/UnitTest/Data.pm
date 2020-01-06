# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest::Data;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Main',
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

=item Ticket_Prepare()

    $UnitTestDataObject->Ticket_Prepare( %TicketData )

Prepare ticket data for ticket creation

=cut
sub Ticket_Prepare {
    my ( $Self, %Param ) = @_;

    ## TODO
    return;
}

=item Ticket_CheckPrepare()

    $UnitTestDataObject->Ticket_CheckPrepare( %TicketData )

Prepare ticket data for ticket data check

=cut
sub Ticket_CheckPrepare {
    my ( $Self, %Param ) = @_;

    ## TODO

    return %Param;
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
