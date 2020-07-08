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
my $ConfigObject       = $Kernel::OM->GetNew('Kernel::Config');
my $StateObject        = $Kernel::OM->GetNew('Kernel::System::State');
my $UnitTestDataObject = $Kernel::OM->GetNew('Kernel::System::UnitTest::Data');

# define needed variables
my $StateNameCreate1    = 'Test';
my $StateNameCreate2    = 'Test (123)';
my $StateCommentCreate2 = 'This state is created by an unittest (System/State.t)';
my $StateNameUpdate1    = '"Test" <a.b@c.de>';
my $StartTime;
my $Success;

# init test case
$Self->TestCaseStart(
    TestCase    => 'State',
    Feature     => 'Kernel::System::State',
    Story       => 'System Module',
    Description => <<"END",
Check methods of system module Kernel::System::State:
* StateAdd
* StateGet
* StateUpdate
* StateGetStatesByType
* StateList
* StateLookup
* StateTypeList
* StateTypeLookup
END
);

# init test steps
$Self->{'TestCase'}->{'PlanSteps'} = {
    '0001' => 'Get state type list',
    '0002' => 'Lookup random state type name by ID',
    '0003' => 'Lookup random state type ID by name',
    '0004' => 'Add first state with random state type',
    '0005' => 'Add second state with comment and random state type',
    '0006' => 'Add existing state',
    '0007' => 'Get first state data by ID',
    '0008' => 'Get first state data by name',
    '0009' => 'Lookup first state name by ID',
    '0010' => 'Lookup first state ID by name',
    '0011' => 'Update first state to existing name',
    '0012' => 'Update first state to new name',
    '0013' => 'Update first state to random type',
    '0014' => 'Update first state to invalid',
    '0015' => 'Get state list without parameter "Valid"',
    '0016' => 'Get state list with parameter "Valid" value "0"',
    '0017' => 'Get state list with parameter "Valid" value "1"',
    '0018' => 'Check state list without parameter not equals list with parameter value "0"',
    '0019' => 'Check state list without parameter equals list with parameter value "1"',
    '0020' => 'Get state list by type with parameter "Type" value "Viewable"',
    '0021' => 'Get state list by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"',
    '0022' => 'Check state list parameter "Type" equals list with parameter "StateType"',
    '0023' => 'Get state id array by type with parameter "Type" value "Viewable"',
    '0024' => 'Get state id array by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"',
    '0025' => 'Check state id array parameter "Type" equals list with parameter "StateType"',
    '0026' => 'Get state name array by type with parameter "Type" value "Viewable"',
    '0027' => 'Get state name array by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"',
    '0028' => 'Check state name array parameter "Type" equals list with parameter "StateType"',
};

# begin transaction on database
$UnitTestDataObject->Database_BeginWork();

# TEST STEP - Get state type list
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0001'} );
$StartTime = $Self->GetMilliTimeStamp();
my %StateTypeList = $StateObject->StateTypeList(
    UserID  => 1,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state type list',
    CheckValue => undef,
    TestValue  => \%StateTypeList,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
my $StateTypeCount = keys( %StateTypeList );
my @StateTypeKeys  = keys( %StateTypeList );
# EO TEST STEP

# TEST STEP - Lookup random state type name by ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0002'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateTypeIDIndex0002 = int( rand( $StateTypeCount ) );
my $StateTypeName = $StateObject->StateTypeLookup(
    StateTypeID => $StateTypeKeys[ $StateTypeIDIndex0002 ],
);
$Success = $Self->Is(
    TestName   => 'Lookup random state type name by ID',
    CheckValue => $StateTypeList{ $StateTypeKeys[ $StateTypeIDIndex0002 ] },
    TestValue  => $StateTypeName,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Lookup random state type ID by name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0003'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateTypeNameIndex0003 = int( rand( $StateTypeCount ) );
my $StateTypeID = $StateObject->StateTypeLookup(
    StateType => $StateTypeList{ $StateTypeKeys[ $StateTypeNameIndex0003 ] },
);
$Success = $Self->Is(
    TestName   => 'Lookup random state type ID by name',
    CheckValue => $StateTypeKeys[ $StateTypeNameIndex0003 ],
    TestValue  => $StateTypeID,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Add first state with random state type
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0004'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateTypeIDIndex0004 = int( rand( $StateTypeCount ) );
my $StateID0004 = $StateObject->StateAdd(
    Name    => $StateNameCreate1,
    TypeID  => $StateTypeKeys[ $StateTypeIDIndex0004 ],
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->IsNot(
    TestName   => 'Add first state with random state type',
    CheckValue => undef,
    TestValue  => $StateID0004,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Add second state with comment and random state type
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0005'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateTypeIDIndex0005 = int( rand( $StateTypeCount ) );
my $StateID0005 = $StateObject->StateAdd(
    Name    => $StateNameCreate2,
    Comment => $StateCommentCreate2,
    TypeID  => $StateTypeKeys[ $StateTypeIDIndex0005 ],
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->IsNot(
    TestName   => 'Add second state with comment and random state type',
    CheckValue => undef,
    TestValue  => $StateID0005,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Add existing state
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0006'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateID0006 = $StateObject->StateAdd(
    Name    => $StateNameCreate1,
    TypeID  => $StateTypeKeys[ $StateTypeIDIndex0004 ],
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Add existing state',
    CheckValue => undef,
    TestValue  => $StateID0006,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get first state data by ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0007'} );
$StartTime = $Self->GetMilliTimeStamp();
my %State0007 = $StateObject->StateGet(
        ID => $StateID0004,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get first state data by ID',
    CheckValue => undef,
    TestValue  => \%State0007,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get first state data by name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0008'} );
$StartTime = $Self->GetMilliTimeStamp();
my %State0008 = $StateObject->StateGet(
        Name => $StateNameCreate1,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get first state data by name',
    CheckValue => undef,
    TestValue  => \%State0008,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Lookup first state name by ID
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0009'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateName0009 = $StateObject->StateLookup(
        StateID => $StateID0004,
);
$Success = $Self->Is(
    TestName   => 'Lookup first state name by ID',
    CheckValue => $StateNameCreate1,
    TestValue  => $StateName0009,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Lookup first state ID by name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0010'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateID0010 = $StateObject->StateLookup(
        State => $StateNameCreate1,
);
$Success = $Self->Is(
    TestName   => 'Lookup first state ID by name',
    CheckValue => $StateID0004,
    TestValue  => $StateID0010,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first state to existing name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0011'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0011 = $StateObject->StateUpdate(
    ID      => $StateID0004,
    Name    => $StateNameCreate2,
    TypeID  => $StateTypeKeys[ $StateTypeIDIndex0004 ],
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first state to existing name',
    CheckValue => undef,
    TestValue  => $Update0011,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first state to new name
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0012'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0012 = $StateObject->StateUpdate(
    ID      => $StateID0004,
    Name    => $StateNameUpdate1,
    TypeID  => $StateTypeKeys[ $StateTypeIDIndex0004 ],
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first state to new name',
    CheckValue => '1',
    TestValue  => $Update0012,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first state to random type
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0013'} );
$StartTime = $Self->GetMilliTimeStamp();
my $StateTypeIDIndex0013 = int( rand( $StateTypeCount ) );
my $Update0013 = $StateObject->StateUpdate(
    ID      => $StateID0004,
    Name    => $StateNameUpdate1,
    TypeID  => $StateTypeKeys[ $StateTypeIDIndex0013 ],
    ValidID => 1,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first state to random type',
    CheckValue => '1',
    TestValue  => $Update0013,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Update first state to invalid
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0014'} );
$StartTime = $Self->GetMilliTimeStamp();
my $Update0014 = $StateObject->TypeUpdate(
    ID      => $StateID0004,
    Name    => $StateNameUpdate1,
    TypeID  => $StateTypeKeys[ $StateTypeIDIndex0013 ],
    ValidID => 2,
    UserID  => 1,
);
$Success = $Self->Is(
    TestName   => 'Update first state to invalid',
    CheckValue => '1',
    TestValue  => $Update0014,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state list without parameter "Valid"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0015'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0015 = $StateObject->StateList();
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state list without parameter "Valid"',
    CheckValue => undef,
    TestValue  => \%List0015,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state list with parameter "Valid" value "0"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0016'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0016 = $StateObject->StateList(
    Valid => 0,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state list with parameter "Valid" value "0"',
    CheckValue => undef,
    TestValue  => \%List0016,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state list with parameter "Valid" value "1"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0017'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0017 = $StateObject->StateList(
    Valid => 1,
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state list with parameter "Valid" value "1"',
    CheckValue => undef,
    TestValue  => \%List0017,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check state list without parameter not equals list with parameter value "0"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0018'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsNotDeeply(
    TestName   => 'Check state list without parameter not equals list with parameter value "0"',
    CheckValue => \%List0015,
    TestValue  => \%List0016,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check state list without parameter equals list with parameter value "1"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0019'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsDeeply(
    TestName   => 'Check state list without parameter equals list with parameter value "1"',
    CheckValue => \%List0015,
    TestValue  => \%List0017,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state list by type with parameter "Type" value "Viewable"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0020'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0020 = $StateObject->StateGetStatesByType(
    Result => 'HASH',
    Type   => 'Viewable',
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state list by type with parameter "Type" value "Viewable"',
    CheckValue => undef,
    TestValue  => \%List0020,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state list by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0021'} );
$StartTime = $Self->GetMilliTimeStamp();
my %List0021 = $StateObject->StateGetStatesByType(
    Result    => 'HASH',
    StateType => $ConfigObject->Get('Ticket::ViewableStateType'),
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state list by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"',
    CheckValue => undef,
    TestValue  => \%List0021,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check state list parameter "Type" equals list with parameter "StateType"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0022'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsDeeply(
    TestName   => 'Check state list parameter "Type" equals list with parameter "StateType"',
    CheckValue => \%List0020,
    TestValue  => \%List0021,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state id array by type with parameter "Type" value "Viewable"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0023'} );
$StartTime = $Self->GetMilliTimeStamp();
my @IDArray0023 = $StateObject->StateGetStatesByType(
    Result => 'ID',
    Type   => 'Viewable',
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state id array by type with parameter "Type" value "Viewable"',
    CheckValue => undef,
    TestValue  => \@IDArray0023,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state id array by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0024'} );
$StartTime = $Self->GetMilliTimeStamp();
my @IDArray0024 = $StateObject->StateGetStatesByType(
    Result    => 'ID',
    StateType => $ConfigObject->Get('Ticket::ViewableStateType'),
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state id array by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"',
    CheckValue => undef,
    TestValue  => \@IDArray0024,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check state id array parameter "Type" equals list with parameter "StateType"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0025'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsDeeply(
    TestName   => 'Check state id array parameter "Type" equals list with parameter "StateType"',
    CheckValue => \@IDArray0023,
    TestValue  => \@IDArray0024,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state name array by type with parameter "Type" value "Viewable"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0026'} );
$StartTime = $Self->GetMilliTimeStamp();
my @NameArray0026 = $StateObject->StateGetStatesByType(
    Result => 'Name',
    Type   => 'Viewable',
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state name array by type with parameter "Type" value "Viewable"',
    CheckValue => undef,
    TestValue  => \@NameArray0026,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Get state name array by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0027'} );
$StartTime = $Self->GetMilliTimeStamp();
my @NameArray0027 = $StateObject->StateGetStatesByType(
    Result    => 'Name',
    StateType => $ConfigObject->Get('Ticket::ViewableStateType'),
);
$Success = $Self->IsNotDeeply(
    TestName   => 'Get state name array by type with parameter "StateType" value matching content for SysConfig "Ticket::ViewableStateType"',
    CheckValue => undef,
    TestValue  => \@NameArray0027,
    StartTime  => $StartTime,
);
return 1 if ( !$Success );
# EO TEST STEP

# TEST STEP - Check state name array parameter "Type" equals list with parameter "StateType"
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0028'} );
$StartTime = $Self->GetMilliTimeStamp();
$Success = $Self->IsDeeply(
    TestName   => 'Check state name array parameter "Type" equals list with parameter "StateType"',
    CheckValue => \@NameArray0026,
    TestValue  => \@NameArray0027,
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
