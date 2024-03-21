# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
my $AuthSessionObject  = $Kernel::OM->GetNew('Kernel::System::AuthSession');
my $WebserviceObject   = $Kernel::OM->GetNew('Kernel::System::GenericInterface::Webservice');
my $MainObject         = $Kernel::OM->GetNew('Kernel::System::Main');
my $TimeObject         = $Kernel::OM->GetNew('Kernel::System::Time');
my $UnitTestDataObject = $Kernel::OM->GetNew('Kernel::System::UnitTest::Data');
my $YAMLObject         = $Kernel::OM->GetNew('Kernel::System::YAML');

# define needed variables
my $StartTime;
my $TestCaseDir  = $ConfigObject->Get('Home') . '/scripts/test/GenericInterface/Operation/ConfigItem/ConfigItemCreate';

# begin transaction on database
$UnitTestDataObject->Database_BeginWork();

# prepare webservice
$StartTime       = $Self->GetMilliTimeStamp();
my $WebserviceID = $WebserviceObject->WebserviceAdd(
    Name    => 'UnitTest-ConfigItemCreate',
    Config  => {
        Debugger => {
            DebugThreshold => 'error',
        },
        Provider => {
            Transport => {
                Type => 'REST'
            },
        }
    },
    ValidID => 1,
    UserID  => 1,
);
if ( !$WebserviceID ) {
    $Self->True(
        TestName  => 'Can not create Webservice for UnitTest!',
        TestValue => $WebserviceID,
        StartTime => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}

# load debugger object
$StartTime          = $Self->GetMilliTimeStamp();
my $DebuggerModule  = 'Kernel::GenericInterface::Debugger';
my $DebuggerSuccess = $MainObject->Require($DebuggerModule);
if ( !$DebuggerSuccess ) {
    $Self->True(
        TestName  => 'Can not load debugger module ' . $DebuggerModule . '!',
        TestValue => $DebuggerSuccess,
        StartTime => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}
$StartTime         = $Self->GetMilliTimeStamp();
my $DebuggerObject = $DebuggerModule->new(
    DebuggerConfig    => {
        DebuggerConfig => 'error',
    },
    WebserviceID      => $WebserviceID,
    CommunicationType => 'Provider',
);
if ( ref( $DebuggerObject ) ne $DebuggerModule ) {
    $Self->Is(
        TestName   => 'Can not create debugger object ' . $DebuggerModule . '!',
        CheckValue => $DebuggerModule,
        TestValue  => ref( $DebuggerObject ),
        StartTime  => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}

# load operation object
$StartTime           = $Self->GetMilliTimeStamp();
my $OperationModule  = 'Kernel::GenericInterface::Operation::ConfigItem::ConfigItemCreate';
my $OperationSuccess = $MainObject->Require($OperationModule);
if ( !$OperationSuccess ) {
    $Self->True(
        TestName  => 'Can not load operation backend module ' . $OperationModule . '!',
        TestValue => $OperationSuccess,
        StartTime => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}
$StartTime          = $Self->GetMilliTimeStamp();
my $OperationObject = $OperationModule->new(
    DebuggerObject => $DebuggerObject,
    WebserviceID   => $WebserviceID,
);
if ( ref( $OperationObject ) ne $OperationModule ) {
    $Self->Is(
        TestName   => 'Can not create operation backend object ' . $OperationModule . '!',
        CheckValue => $OperationModule,
        TestValue  => ref( $OperationObject ),
        StartTime  => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}

# create session
$StartTime    = $Self->GetMilliTimeStamp();
my $SessionID = $AuthSessionObject->CreateSessionID(
    UserType        => 'User',
    UserID          => 1,
    UserLogin       => 'root@localhost',
    UserLastRequest => $TimeObject->SystemTime(),
);
if ( !$SessionID ) {
    $Self->True(
        TestName  => 'Can not create session',
        TestValue => $SessionID,
        StartTime => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}

# get test case files
my @FilesInDirectory = $MainObject->DirectoryRead(
    Directory => $TestCaseDir,
    Filter    => '*.yml',
);

# process file list
FILE:
for my $File ( @FilesInDirectory ) {
    # init test case
    $Self->TestCaseStart(
        TestCase    => 'File: ' . $File,
        Feature     => 'Kernel::GenericInterface::Operation::ConfigItem::ConfigItemCreate',
        Story       => 'GenericInterface Operation ConfigItem::ConfigItemCreate',
        Description => 'Check return data of GenericInterface Operation ConfigItem::ConfigItemCreate'
    );

    # read file
    $StartTime     = $Self->GetMilliTimeStamp();
    my $ContentRef = $MainObject->FileRead(
        Location => $File,
        Mode     => 'utf8',
        Type     => 'Local',
        Result   => 'SCALAR',
    );
    if ( !$$ContentRef ) {
        $Self->IsNot(
            TestName   => 'Read file failed',
            CheckValue => undef,
            TestValue  => $$ContentRef,
            StartTime  => $StartTime,
        );
        next FILE;
    }

    # load yaml
    $StartTime       = $Self->GetMilliTimeStamp();
    my $TestCaseData = $YAMLObject->Load(
        Data => $$ContentRef,
    );
    if ( ref( $TestCaseData ) ne 'HASH' ) {
        $Self->IsNot(
            TestName   => 'Loading YAML failed',
            CheckValue => 'HASH',
            TestValue  => ref( $TestCaseData ),
            StartTime  => $StartTime,
        );
        next FILE;
    }

    # init test steps
    $Self->{'TestCase'}->{'PlanSteps'} = {};
    for my $StepKey ( keys( %{ $TestCaseData } ) ) {
        $Self->{'TestCase'}->{'PlanSteps'}->{ $StepKey } = $StepKey . ': ' . $TestCaseData->{ $StepKey }->{'StepName'};
    }

    # process test steps
    for my $StepKey ( sort( keys( %{ $TestCaseData } ) ) ) {
        delete( $Self->{'TestCase'}->{'PlanSteps'}->{ $StepKey } );
        $StartTime     = $Self->GetMilliTimeStamp();
        my $ReturnData = $OperationObject->Run(
            Data => {
                %{ $TestCaseData->{ $StepKey }->{'InputData'} },
                SessionID => $SessionID,
            },
        );
        $Self->IsDeeply(
            TestName   => $StepKey . ': ' . $TestCaseData->{ $StepKey }->{'StepName'},
            CheckValue => $TestCaseData->{ $StepKey }->{'CheckValue'},
            TestValue  => $ReturnData,
            StartTime  => $StartTime,
        );
    }

    # finish test case
    $Self->TestCaseStop();
}

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