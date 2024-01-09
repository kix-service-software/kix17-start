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
my $ConfigObject         = $Kernel::OM->GetNew('Kernel::Config');
my $AuthSessionObject    = $Kernel::OM->GetNew('Kernel::System::AuthSession');
my $GeneralCatalogObject = $Kernel::OM->GetNew('Kernel::System::GeneralCatalog');
my $WebserviceObject     = $Kernel::OM->GetNew('Kernel::System::GenericInterface::Webservice');
my $ConfigItemObject     = $Kernel::OM->GetNew('Kernel::System::ITSMConfigItem');
my $MainObject           = $Kernel::OM->GetNew('Kernel::System::Main');
my $TimeObject           = $Kernel::OM->GetNew('Kernel::System::Time');
my $UnitTestDataObject   = $Kernel::OM->GetNew('Kernel::System::UnitTest::Data');
my $YAMLObject           = $Kernel::OM->GetNew('Kernel::System::YAML');

# define needed variables
my $StartTime;
my $TestCaseDir  = $ConfigObject->Get('Home') . '/scripts/test/GenericInterface/Operation/ConfigItem/ConfigItemUpdate';

# begin transaction on database
$UnitTestDataObject->Database_BeginWork();

# prepare webservice
$StartTime       = $Self->GetMilliTimeStamp();
my $WebserviceID = $WebserviceObject->WebserviceAdd(
    Name    => 'UnitTest-ConfigItemUpdate',
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
my $OperationModule  = 'Kernel::GenericInterface::Operation::ConfigItem::ConfigItemUpdate';
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

# create config item
$StartTime      = $Self->GetMilliTimeStamp();
my $ClassRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Computer',
);
if ( ref( $ClassRef ) ne 'HASH' ) {
    $Self->IsNot(
        TestName   => 'Can not get GeneralCatalog entry for class Computer',
        CheckValue => 'HASH',
        TestValue  => ref( $ClassRef ),
        StartTime  => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}
$StartTime        = $Self->GetMilliTimeStamp();
my $DefinitionRef = $ConfigItemObject->DefinitionGet(
    ClassID => $ClassRef->{ItemID},
);
if ( ref( $DefinitionRef ) ne 'HASH' ) {
    $Self->IsNot(
        TestName   => 'Can not get definition data for class Computer',
        CheckValue => 'HASH',
        TestValue  => ref( $DefinitionRef ),
        StartTime  => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}
$StartTime      = $Self->GetMilliTimeStamp();
my $DeploymentRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);
if ( ref( $DeploymentRef ) ne 'HASH' ) {
    $Self->IsNot(
        TestName   => 'Can not get GeneralCatalog entry for deployment state Production',
        CheckValue => 'HASH',
        TestValue  => ref( $DeploymentRef ),
        StartTime  => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}
$StartTime      = $Self->GetMilliTimeStamp();
my $IncidentRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Operational',
);
if ( ref( $IncidentRef ) ne 'HASH' ) {
    $Self->IsNot(
        TestName   => 'Can not get GeneralCatalog entry for incident state Operational',
        CheckValue => 'HASH',
        TestValue  => ref( $IncidentRef ),
        StartTime  => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}
$StartTime      = $Self->GetMilliTimeStamp();
my $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
    ClassID => $ClassRef->{ItemID},
    UserID  => 1,
);
if ( !$ConfigItemID ) {
    $Self->True(
        TestName  => 'Can not create config item',
        TestValue => $ConfigItemID,
        StartTime => $StartTime,
    );
    # rollback transaction on database
    $UnitTestDataObject->Database_Rollback();
    return;
}
my $VersionID = $ConfigItemObject->VersionAdd(
    ConfigItemID => $ConfigItemID,
    Name         => 'Test',
    DefinitionID => $DefinitionRef->{DefinitionID},
    DeplStateID  => $DeploymentRef->{ItemID},
    InciStateID  => $IncidentRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    Vendor => [
                        undef,
                        {
                            Content => 'Vendor',
                        },
                    ],
                },
            ],
        },
    ],
    UserID       => 1,
);
if ( !$VersionID ) {
    $Self->True(
        TestName  => 'Can not create version for config item',
        TestValue => $VersionID,
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
        Feature     => 'Kernel::GenericInterface::Operation::ConfigItem::ConfigItemUpdate',
        Story       => 'GenericInterface Operation ConfigItem::ConfigItemUpdate',
        Description => 'Check return data of GenericInterface Operation ConfigItem::ConfigItemUpdate'
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
                SessionID    => $SessionID,
                ConfigItemID => $ConfigItemID,
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