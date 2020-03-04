# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $TicketObject       = $Kernel::OM->GetNew('Kernel::System::Ticket');
my $UnitTestDataObject = $Kernel::OM->GetNew('Kernel::System::UnitTest::Data');

# define needed variables
my %TestData = (
    'Ticket' => {
        'Title'         => 'Test Ticket Title',
        'Queue'         => 'Raw',
        'Lock'          => 'unlock',
        'Priority'      => '3 normal',
        'State'         => 'new',
        'Type'          => 'Incident',
        'CustomerID'    => 'TestCustomerCompany',
        'CustomerUser'  => 'test@cape-it.de',
        'OwnerID'       => 1,
        'ResponsibleID' => 1,
        'ArchiveFlag'   => 'n',
        'UserID'        => 1,
    },
);
my $StartTime;
my $Success;

# init test case
$Self->TestCaseStart(
    TestCase    => 'Ticket Create Simple',
    Feature     => 'Ticket',
    Story       => 'Create Ticket',
    Description => <<"END",
Create a new ticket with valid values of all mandatory default ticket attributes:
* Ticket type
* Ticket status
* Ticket queue
* Ticket priority
* Ticket customer contact
* Ticket customer company
* Ticket owner
* Ticket responsible
* Ticket title
* ticket archive flag
END
);

# init test steps
$Self->{'TestCase'}->{'PlanSteps'} = {
    '0001' => 'Ticket Create',
    '0002' => 'Ticket Check',
};

# begin transaction on database
$UnitTestDataObject->Database_BeginWork();

# get test data for ticket
my %TestTicketCreateData = %{ $TestData{'Ticket'} };
my %TestTicketCheckData  = $UnitTestDataObject->Ticket_CheckPrepare( %{ $TestData{'Ticket'} } );

# TEST STEP
# create test ticket
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0001'} );
$StartTime = $Self->GetMilliTimeStamp();
my $TicketID = $TicketObject->TicketCreate( %TestTicketCreateData );
$Success = $Self->IsNot(
    TestName   => 'Ticket Create',
    CheckValue => undef,
    TestValue  => $TicketID,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP
# get and compare test ticket
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0002'} );
$StartTime = $Self->GetMilliTimeStamp();
my %Ticket = $TicketObject->TicketGet(
    TicketID      => $TicketID,
    UserID        => 1,
    Silent        => 1,
);
# clean up dynamic values
for my $Key ( qw(TicketID TicketNumber Age Created CreateTimeUnix Changed EscalationResponseTime EscalationSolutionTime EscalationTime EscalationUpdateTime RealTillTimeNotUsed UntilTime UnlockTimeout) ) {
    delete( $Ticket{$Key} );
}
$Success = $Self->IsDeeply(
    TestName  => 'Ticket Check',
    CheckData => \%TestTicketCheckData,
    TestData  => \%Ticket,
    StartTime => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# rollback transaction on database
$UnitTestDataObject->Database_Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
