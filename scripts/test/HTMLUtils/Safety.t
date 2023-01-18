# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
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
my $HTMLUtilsObject    = $Kernel::OM->GetNew('Kernel::System::HTMLUtils');
my $MainObject         = $Kernel::OM->GetNew('Kernel::System::Main');
my $YAMLObject         = $Kernel::OM->GetNew('Kernel::System::YAML');

# define needed variables
my $StartTime;
my $TestCaseDir = $ConfigObject->Get('Home') . '/scripts/test/HTMLUtils/Safety';
my $TestString  = 'Lorem ipsum dolor sit amet';

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
        Feature     => 'Kernel::System::HTMLUtils::Safety',
        Story       => 'Module Kernel::System::HTMLUtils, method Safety',
        Description => 'Check output for method Safety of system module Kernel::System::HTMLUtils'
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
        $StartTime = $Self->GetMilliTimeStamp();
        my %Safety = $HTMLUtilsObject->Safety(
            %{ $TestCaseData->{ $StepKey }->{'InputData'} }
        );
        $Self->IsDeeply(
            TestName   => $StepKey . ': ' . $TestCaseData->{ $StepKey }->{'StepName'},
            CheckValue => $TestCaseData->{ $StepKey }->{'CheckValue'},
            TestValue  => \%Safety,
            StartTime  => $StartTime,
        );
    }

    # finish test case
    $Self->TestCaseStop();
}

# init test case for result ref
$Self->TestCaseStart(
    TestCase    => 'Ref check',
    Feature     => 'Kernel::System::HTMLUtils::Safety',
    Story       => 'Module Kernel::System::HTMLUtils, method Safety',
    Description => 'Check ref of output string equals input string for method Safety of system module Kernel::System::HTMLUtils'
);

# init test steps
$Self->{'TestCase'}->{'PlanSteps'} = {
    '0001' => 'Check input without ref',
    '0002' => 'Check input with ref',
};

# TEST STEP - 0001: Check input without ref
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0001'} );
$StartTime = $Self->GetMilliTimeStamp();
my %Safety0001 = $HTMLUtilsObject->Safety(
    String => $TestString
);
$Self->Is(
    TestName   => '0001: Check input without ref',
    CheckValue => '',
    TestValue  => ref( $Safety0001{String} ),
    StartTime  => $StartTime,
);
# EO TEST STEP

# TEST STEP - 0002: Check input with ref
delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0002'} );
$StartTime = $Self->GetMilliTimeStamp();
my %Safety0002 = $HTMLUtilsObject->Safety(
    String => \$TestString
);
$Self->Is(
    TestName   => '0002: Check input with ref',
    CheckValue => 'REF',
    TestValue  => ref( $Safety0002{String} ),
    StartTime  => $StartTime,
);
# EO TEST STEP

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
