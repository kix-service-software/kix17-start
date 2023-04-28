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
my $ConfigObject    = $Kernel::OM->GetNew('Kernel::Config');
my $HTMLUtilsObject = $Kernel::OM->GetNew('Kernel::System::HTMLUtils');
my $MainObject      = $Kernel::OM->GetNew('Kernel::System::Main');
my $YAMLObject      = $Kernel::OM->GetNew('Kernel::System::YAML');

# define needed variables
my $StartTime;
my $TestCaseDir = $ConfigObject->Get('Home') . '/scripts/test/HTMLUtils/ToAscii';

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
        Feature     => 'Kernel::System::HTMLUtils::ToAscii',
        Story       => 'Module Kernel::System::HTMLUtils, method ToAscii',
        Description => 'Check output for method ToAscii of system module Kernel::System::HTMLUtils'
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
        my $ToAscii = $HTMLUtilsObject->ToAscii(
            String => $TestCaseData->{ $StepKey }->{'InputValue'}
        );
        $Self->Is(
            TestName   => $StepKey . ': ' . $TestCaseData->{ $StepKey }->{'StepName'},
            CheckValue => $TestCaseData->{ $StepKey }->{'CheckValue'},
            TestValue  => $ToAscii,
            StartTime  => $StartTime,
        );
    }

    # finish test case
    $Self->TestCaseStop();
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
