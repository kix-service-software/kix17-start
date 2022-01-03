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
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

# define needed variables
my $HomeDir = $ConfigObject->Get('Home');
my $StartTime;
my $Success;

# get cache backend files
my @BackendModuleFiles = $MainObject->DirectoryRead(
    Directory => $HomeDir . '/Kernel/System/Cache/',
    Filter    => '*.pm',
    Silent    => 1,
);

# process module files
MODULEFILE:
for my $ModuleFile (@BackendModuleFiles) {
    # check file name
    next MODULEFILE if ( !$ModuleFile );

    # extract module name
    my ($Module) = $ModuleFile =~ m{ \/+ ([a-zA-Z0-9]+) \.pm $ }xms;
    next MODULEFILE if ( !$Module );

    # init test case
    $Self->TestCaseStart(
        TestCase    => $Module . ' KeepTypes',
        Feature     => 'Cache',
        Story       => $Module,
        Description => <<"END",
Check keep types of cache module $Module
* Set A and B
* Remove C
* Check A and B
* Set A and B
* Remove A
* Check A and B
* Set A and B
* Remove all but A
* Check A and B
* Set A and B
* Remove all
* Check A and B
END
    );

    # init test steps
    $Self->{'TestCase'}->{'PlanSteps'} = {
        '0001' => 'Module configuration',
        '0002' => 'Module creation',
        '0003' => 'Cache set A/A',
        '0004' => 'Cache set B/B',
        '0005' => 'Inexistent cache type C removed',
        '0006' => 'Cache A/A is present',
        '0007' => 'Cache B/B is present',
        '0008' => 'Cache set A/A',
        '0009' => 'Cache set B/B',
        '0010' => 'Cache type A removed',
        '0011' => 'Cache A/A is not present',
        '0012' => 'Cache B/B is present',
        '0013' => 'Cache set A/A',
        '0014' => 'Cache set B/B',
        '0015' => 'All cache types removed except A',
        '0016' => 'Cache A/A is present',
        '0017' => 'Cache B/B is not present',
        '0018' => 'Cache set A/A',
        '0019' => 'Cache set B/B',
        '0020' => 'All cache types removed',
        '0021' => 'Cache A/A is not present',
        '0022' => 'Cache B/B is not present',
    };

    ## TEST STEP
    # set and check configuration 'Cache::Module'
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0001'} );
    $StartTime = $Self->GetMilliTimeStamp();
    $ConfigObject->Set(
        Key   => 'Cache::Module',
        Value => "Kernel::System::Cache::$Module",
    );
    $Success = $Self->Is(
        TestName   => 'Module configuration',
        CheckValue => 'Kernel::System::Cache::' . $Module,
        TestValue  => $ConfigObject->Get('Cache::Module'),
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # create and check cache module
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0002'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheObject = $Kernel::OM->GetNew('Kernel::System::Cache');
    $CacheObject->Configure(
        CacheInMemory  => 1,
        CacheInBackend => 1,
    );
    $Success = $Self->Is(
        TestName   => 'Module creation',
        CheckValue => 'Kernel::System::Cache::' . $Module,
        TestValue  => ref( $CacheObject->{CacheObject} ),
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    # flush the cache to have a clear test environment
    $CacheObject->CleanUp();

    ## TEST STEP
    # set cache A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0003'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetA1 = $CacheObject->Set(
        Type  => 'A',
        Key   => 'A',
        Value => 'A',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set A/A',
        TestValue  => $SuccessSetA1,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set cache B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0004'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetB1 = $CacheObject->Set(
        Type  => 'B',
        Key   => 'B',
        Value => 'B',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set B/B',
        TestValue  => $SuccessSetB1,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # cleanup inexistent cache type C
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0005'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessCleanupC = $CacheObject->CleanUp(
        Type  => 'C',
    );
    $Success = $Self->True(
        TestName   => 'Inexistent cache type C removed',
        TestValue  => $SuccessCleanupC,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value A/A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0006'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetA1 = $CacheObject->Get(
        Type => 'A',
        Key  => 'A',
    );
    $Success = $Self->Is(
        TestName   => 'Cache A/A is present',
        CheckValue => 'A',
        TestValue  => $CacheGetA1,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value B/B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0007'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetB1 = $CacheObject->Get(
        Type => 'B',
        Key  => 'B',
    );
    $Success = $Self->Is(
        TestName   => 'Cache B/B is present',
        CheckValue => 'B',
        TestValue  => $CacheGetB1,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set cache A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0008'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetA2 = $CacheObject->Set(
        Type  => 'A',
        Key   => 'A',
        Value => 'A',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set A/A',
        TestValue  => $SuccessSetA2,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set cache B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0009'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetB2 = $CacheObject->Set(
        Type  => 'B',
        Key   => 'B',
        Value => 'B',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set B/B',
        TestValue  => $SuccessSetB2,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # cleanup cache type A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0010'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessCleanupA = $CacheObject->CleanUp(
        Type  => 'A',
    );
    $Success = $Self->True(
        TestName   => 'Cache type A removed',
        TestValue  => $SuccessCleanupA,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value A/A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0011'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetA2 = $CacheObject->Get(
        Type => 'A',
        Key  => 'A',
    );
    $Success = $Self->Is(
        TestName   => 'Cache A/A is not present',
        CheckValue => undef,
        TestValue  => $CacheGetA2,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value B/B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0012'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetB2 = $CacheObject->Get(
        Type => 'B',
        Key  => 'B',
    );
    $Success = $Self->Is(
        TestName   => 'Cache B/B is present',
        CheckValue => 'B',
        TestValue  => $CacheGetB2,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set cache A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0013'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetA3 = $CacheObject->Set(
        Type  => 'A',
        Key   => 'A',
        Value => 'A',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set A/A',
        TestValue  => $SuccessSetA3,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set cache B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0014'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetB3 = $CacheObject->Set(
        Type  => 'B',
        Key   => 'B',
        Value => 'B',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set B/B',
        TestValue  => $SuccessSetB3,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # cleanup cache type A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0015'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessCleanupKeepA = $CacheObject->CleanUp(
        KeepTypes => ['A'],
    );
    $Success = $Self->True(
        TestName   => 'All cache types removed except A',
        TestValue  => $SuccessCleanupKeepA,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value A/A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0016'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetA3 = $CacheObject->Get(
        Type => 'A',
        Key  => 'A',
    );
    $Success = $Self->Is(
        TestName   => 'Cache A/A is present',
        CheckValue => 'A',
        TestValue  => $CacheGetA3,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value B/B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0017'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetB3 = $CacheObject->Get(
        Type => 'B',
        Key  => 'B',
    );
    $Success = $Self->Is(
        TestName   => 'Cache B/B is not present',
        CheckValue => undef,
        TestValue  => $CacheGetB3,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set cache A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0018'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetA4 = $CacheObject->Set(
        Type  => 'A',
        Key   => 'A',
        Value => 'A',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set A/A',
        TestValue  => $SuccessSetA4,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set cache B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0019'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetB4 = $CacheObject->Set(
        Type  => 'B',
        Key   => 'B',
        Value => 'B',
        TTL   => 60 * 60 * 24 * 20,
    );
    $Success = $Self->True(
        TestName   => 'Cache set B/B',
        TestValue  => $SuccessSetB4,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # cleanup cache
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0020'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessCleanup = $CacheObject->CleanUp();
    $Success = $Self->True(
        TestName   => 'All cache types removed',
        TestValue  => $SuccessCleanup,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value A/A
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0021'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetA4 = $CacheObject->Get(
        Type => 'A',
        Key  => 'A',
    );
    $Success = $Self->Is(
        TestName   => 'Cache A/A is not present',
        CheckValue => undef,
        TestValue  => $CacheGetA4,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get cache value B/B
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0022'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheGetB4 = $CacheObject->Get(
        Type => 'B',
        Key  => 'B',
    );
    $Success = $Self->Is(
        TestName   => 'Cache B/B is not present',
        CheckValue => undef,
        TestValue  => $CacheGetB4,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    # flush the cache
    $CacheObject->CleanUp();
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
