# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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
my $TypeObject         = $Kernel::OM->GetNew('Kernel::System::Type');
my $UnitTestDataObject = $Kernel::OM->GetNew('Kernel::System::UnitTest::Data');

# define needed variables
my $TypeNameCreate1 = 'Test';
my $TypeNameCreate2 = 'Test2';
my $TypeNameUpdate1 = 'Test1';
my $StartTime;
my $Success;

# init test case
$Self->TestCaseStart(
    TestCase    => 'Type',
    Feature     => 'Kernel::System::Type',
    Story       => 'System Module',
    Description => <<"END",
Check methods of system module Kernel::System::Type:
* TypeAdd
* TypeGet
* TypeUpdate
* TypeList
* TypeLookup
* NameExistsCheck
END
);

# init test steps
$Self->{'TestCase'}->{'PlanSteps'} = {
    '0001' => 'Check first type name does not exist',
    '0002' => 'Add first type',
    '0003' => 'Add second type',
    '0004' => 'Add existing type',
    '0005' => 'Check first type name does exist without ID',
    '0006' => 'Check first type name does exist with ID',
    '0007' => 'Get first type data by ID',
    '0008' => 'Get first type data by name',
    '0009' => 'Lookup first type name by ID',
    '0010' => 'Lookup first type ID by name',
    '0011' => 'Update first type to existing name',
    '0012' => 'Update first type to new name',
    '0013' => 'Update first type to invalid',
    '0014' => 'Get type list without parameter "Valid"',
    '0015' => 'Get type list with parameter "Valid" value "0"',
    '0016' => 'Get type list with parameter "Valid" value "1"',
    '0017' => 'Check type list without parameter not equals list with parameter value "0"',
    '0018' => 'Check type list without parameter equals list with parameter value "1"',
};

# begin transaction on database
$UnitTestDataObject->Database_BeginWork();

# TEST STEP - Check first type name does not exist
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0001'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Exist0001 = $TypeObject->NameExistsCheck(
    Name => $TypeNameCreate1,
);
$Success = $Self->Is(
    TestName   => 'Check first type name does not exist',
    CheckValue => 0,
    TestValue  => $Exist0001,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Create first type
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0002'} );
$StartTime = $Self->GetMilliTimeStamp();
my $TypeID0002 = $TypeObject->TypeAdd(
    Name    => $TypeNameCreate1,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->IsNot(
    TestName   => 'Create first type',
    CheckValue => undef,
    TestValue  => $TypeID0002,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Create second type
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0003'} );
$StartTime = $Self->GetMilliTimeStamp();
my $TypeID0003 = $TypeObject->TypeAdd(
    Name    => $TypeNameCreate2,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->IsNot(
    TestName   => 'Create second type',
    CheckValue => undef,
    TestValue  => $TypeID0003,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Create existing type
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0004'} );
$StartTime = $Self->GetMilliTimeStamp();
my $TypeID0004 = $TypeObject->TypeAdd(
    Name    => $TypeNameCreate1,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Create existing type',
    CheckValue => undef,
    TestValue  => $TypeID0004,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check first type name does exist without ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0005'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Exist0005 = $TypeObject->NameExistsCheck(
    Name => $TypeNameCreate1,
);
$Success = $Self->Is(
    TestName   => 'Check first type name does exist without ID',
    CheckValue => 1,
    TestValue  => $Exist0005,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check first type name does exist with ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0006'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Exist0006 = $TypeObject->NameExistsCheck(
    Name => $TypeNameCreate1,
    ID   => $TypeID0002,
);
$Success = $Self->Is(
    TestName   => 'Check first type name does exist with ID',
    CheckValue => 0,
    TestValue  => $Exist0006,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get first type data by ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0007'} );
$StartTime = $Self->GetMilliTimeStamp();
my %Type0007 = $TypeObject->TypeGet(
        ID => $TypeID0002,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get first type data by ID',
    CheckValue => {},
    TestValue  => \%Type0007,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get first type data by name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0008'} );
$StartTime = $Self->GetMilliTimeStamp();
my %Type0008 = $TypeObject->TypeGet(
        Name => $TypeNameCreate1,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get first type data by name',
    CheckValue => {},
    TestValue  => \%Type0008,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Lookup first type name by ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0009'} );
$StartTime = $Self->GetMilliTimeStamp();
my $TypeName0009 = $TypeObject->TypeLookup(
        TypeID => $TypeID0002,
);
$Success = $Self->Is(
    TestName   => 'Lookup first type name by ID',
    CheckValue => $TypeNameCreate1,
    TestValue  => $TypeName0009,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Lookup first type ID by name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0010'} );
$StartTime = $Self->GetMilliTimeStamp();
my $TypeID0010 = $TypeObject->TypeLookup(
        Type => $TypeNameCreate1,
);
$Success = $Self->Is(
    TestName   => 'Lookup first type ID by name',
    CheckValue => $TypeID0002,
    TestValue  => $TypeID0010,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first type to existing name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0011'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0011 = $TypeObject->TypeUpdate(
    ID      => $TypeID0002,
    Name    => $TypeNameCreate2,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first type to existing name',
    CheckValue => undef,
    TestValue  => $Update0011,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first type to new name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0012'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0012 = $TypeObject->TypeUpdate(
    ID      => $TypeID0002,
    Name    => $TypeNameUpdate1,
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first type to new name',
    CheckValue => '1',
    TestValue  => $Update0012,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first type to invalid
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0013'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0013 = $TypeObject->TypeUpdate(
    ID      => $TypeID0002,
    Name    => $TypeNameUpdate1,
    ValidID => 2,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first type to invalid',
    CheckValue => '1',
    TestValue  => $Update0013,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get type list without parameter "Valid"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0014'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0014 = $TypeObject->TypeList();
$Success = $Self->IsNotDeeply(
    TestName   => 'Get type list without parameter "Valid"',
    CheckValue => {},
    TestValue  => \%List0014,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get type list with parameter "Valid" value "0"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0015'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0015 = $TypeObject->TypeList(
    Valid => 0,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get type list with parameter "Valid" value "0"',
    CheckValue => {},
    TestValue  => \%List0015,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get type list with parameter "Valid" value "1"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0016'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0016 = $TypeObject->TypeList(
    Valid => 1,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get type list with parameter "Valid" value "1"',
    CheckValue => {},
    TestValue  => \%List0016,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check type list without parameter not equals list with parameter value "0"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0017'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsNotDeeply(
    TestName   => 'Check type list without parameter not equals list with parameter value "0"',
    CheckValue => \%List0014,
    TestValue  => \%List0015,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check type list without parameter equals list with parameter value "1"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0018'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsDeeply(
    TestName   => 'Check type list without parameter equals list with parameter value "1"',
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
