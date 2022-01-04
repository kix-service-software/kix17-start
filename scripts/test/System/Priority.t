# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
my $PriorityObject     = $Kernel::OM->GetNew('Kernel::System::Priority');
my $UnitTestDataObject = $Kernel::OM->GetNew('Kernel::System::UnitTest::Data');

# define needed variables
my $PriorityNameCreate1 = 'Test';
my $PriorityNameCreate2 = 'Test2';
my $PriorityNameUpdate1 = 'Test1';
my $StartTime;
my $Success;

# init test case
$Self->TestCaseStart(
    TestCase    => 'Priority',
    Feature     => 'Kernel::System::Priority',
    Story       => 'System Module',
    Description => <<"END",
Check methods of system module Kernel::System::Priority:
* PriorityAdd
* PriorityGet
* PriorityUpdate
* PriorityList
* PriorityLookup
* NameExistsCheck
END
);

# init test steps
$Self->{'TestCase'}->{'PlanSteps'} = {
    '0001' => 'Check first priority name does not exist',
    '0002' => 'Add first priority',
    '0003' => 'Add second priority',
    '0004' => 'Add existing priority',
    '0005' => 'Check first priority name does exist without ID',
    '0006' => 'Check first priority name does exist with ID',
    '0007' => 'Get first priority data by ID',
    '0008' => 'Get first priority data by name',
    '0009' => 'Lookup first priority name by ID',
    '0010' => 'Lookup first priority ID by name',
    '0011' => 'Update first priority to existing name',
    '0012' => 'Update first priority to new name',
    '0013' => 'Update first priority to invalid',
    '0014' => 'Get priority list without parameter "Valid"',
    '0015' => 'Get priority list with parameter "Valid" value "0"',
    '0016' => 'Get priority list with parameter "Valid" value "1"',
    '0017' => 'Check priority list without parameter not equals list with parameter value "0"',
    '0018' => 'Check priority list without parameter equals list with parameter value "1"',
};

# begin transaction on database
$UnitTestDataObject->Database_BeginWork();

# TEST STEP - Check first priority name does not exist
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0001'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Exist0001 = $PriorityObject->NameExistsCheck(
    Name => $PriorityNameCreate1,
);
$Success = $Self->Is(
    TestName   => 'Check first priority name does not exist',
    CheckValue => 0,
    TestValue  => $Exist0001,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Create first priority
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0002'} );
$StartTime = $Self->GetMilliTimeStamp();
my $PriorityID0002 = $PriorityObject->PriorityAdd(
    Name    => $PriorityNameCreate1,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->IsNot(
    TestName   => 'Create first priority',
    CheckValue => undef,
    TestValue  => $PriorityID0002,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Create second priority
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0003'} );
$StartTime = $Self->GetMilliTimeStamp();
my $PriorityID0003 = $PriorityObject->PriorityAdd(
    Name    => $PriorityNameCreate2,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->IsNot(
    TestName   => 'Create second priority',
    CheckValue => undef,
    TestValue  => $PriorityID0003,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Create existing priority
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0004'} );
$StartTime = $Self->GetMilliTimeStamp();
my $PriorityID0004 = $PriorityObject->PriorityAdd(
    Name    => $PriorityNameCreate1,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Create existing priority',
    CheckValue => undef,
    TestValue  => $PriorityID0004,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check first priority name does exist without ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0005'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Exist0005 = $PriorityObject->NameExistsCheck(
    Name => $PriorityNameCreate1,
);
$Success = $Self->Is(
    TestName   => 'Check first priority name does exist without ID',
    CheckValue => 1,
    TestValue  => $Exist0005,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check first priority name does exist with ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0006'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Exist0006 = $PriorityObject->NameExistsCheck(
    Name => $PriorityNameCreate1,
    ID   => $PriorityID0002,
);
$Success = $Self->Is(
    TestName   => 'Check first priority name does exist with ID',
    CheckValue => 0,
    TestValue  => $Exist0006,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get first priority data by ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0007'} );
$StartTime = $Self->GetMilliTimeStamp();
my %Priority0007 = $PriorityObject->PriorityGet(
        ID => $PriorityID0002,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get first priority data by ID',
    CheckValue => {},
    TestValue  => \%Priority0007,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get first priority data by name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0008'} );
$StartTime = $Self->GetMilliTimeStamp();
my %Priority0008 = $PriorityObject->PriorityGet(
        Name => $PriorityNameCreate1,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get first priority data by name',
    CheckValue => {},
    TestValue  => \%Priority0008,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Lookup first priority name by ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0009'} );
$StartTime = $Self->GetMilliTimeStamp();
my $PriorityName0009 = $PriorityObject->PriorityLookup(
        PriorityID => $PriorityID0002,
);
$Success = $Self->Is(
    TestName   => 'Lookup first priority name by ID',
    CheckValue => $PriorityNameCreate1,
    TestValue  => $PriorityName0009,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Lookup first priority ID by name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0010'} );
$StartTime = $Self->GetMilliTimeStamp();
my $PriorityID0010 = $PriorityObject->PriorityLookup(
        Priority => $PriorityNameCreate1,
);
$Success = $Self->Is(
    TestName   => 'Lookup first priority ID by name',
    CheckValue => $PriorityID0002,
    TestValue  => $PriorityID0010,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first priority to existing name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0011'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0011 = $PriorityObject->PriorityUpdate(
    ID      => $PriorityID0002,
    Name    => $PriorityNameCreate2,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first priority to existing name',
    CheckValue => undef,
    TestValue  => $Update0011,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first priority to new name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0012'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0012 = $PriorityObject->PriorityUpdate(
    ID      => $PriorityID0002,
    Name    => $PriorityNameUpdate1,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first priority to new name',
    CheckValue => '1',
    TestValue  => $Update0012,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first priority to invalid
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0013'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0013 = $PriorityObject->PriorityUpdate(
    ID      => $PriorityID0002,
    Name    => $PriorityNameUpdate1,
    ValidID => 2,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first priority to invalid',
    CheckValue => '1',
    TestValue  => $Update0013,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get priority list without parameter "Valid"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0014'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0014 = $PriorityObject->PriorityList();
$Success = $Self->IsNotDeeply(
    TestName   => 'Get priority list without parameter "Valid"',
    CheckValue => {},
    TestValue  => \%List0014,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get priority list with parameter "Valid" value "0"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0015'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0015 = $PriorityObject->PriorityList(
    Valid => 0,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get priority list with parameter "Valid" value "0"',
    CheckValue => {},
    TestValue  => \%List0015,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get priority list with parameter "Valid" value "1"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0016'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0016 = $PriorityObject->PriorityList(
    Valid => 1,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get priority list with parameter "Valid" value "1"',
    CheckValue => {},
    TestValue  => \%List0016,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check priority list without parameter not equals list with parameter value "0"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0017'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsNotDeeply(
    TestName   => 'Check priority list without parameter not equals list with parameter value "0"',
    CheckValue => \%List0014,
    TestValue  => \%List0015,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check priority list without parameter equals list with parameter value "1"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0018'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsDeeply(
    TestName   => 'Check priority list without parameter equals list with parameter value "1"',
    CheckValue => \%List0014,
    TestValue  => \%List0016,
    StartTime  => $StartTime,
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
