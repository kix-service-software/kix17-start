# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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
my $CacheType = "UnitTest_Cache_Configure";
my $HomeDir   = $ConfigObject->Get('Home');
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
        TestCase    => $Module,
        Description => 'Check cache module ' . $Module,
    );

    # init test steps
    $Self->{'TestCase'}->{'PlanSteps'} = {
        '0001' => 'Module configuration',
        '0002' => 'Module creation',
        '0003' => 'Cache set, backend and memory',
        '0004' => 'Cache get, backend and memory',
        '0005' => 'Cache get, backend only',
        '0006' => 'Cache get, memory only',
        '0007' => 'Cache get, both disabled',
        '0008' => 'Cache set, backend only',
        '0009' => 'Cache get from backend only',
        '0010' => 'Removed value from memory',
        '0011' => 'Cache set, memory only',
        '0012' => 'Removed value from backend',
        '0013' => 'Cache get from memory only',
        '0014' => 'Cache set, both disabled',
        '0015' => 'Removed value from backend',
        '0016' => 'Removed value from memory',
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
    # set value in memory and in backend
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0003'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSet = $CacheObject->Set(
        Type  => $CacheType,
        Key   => "Key1",
        Value => 1,
        TTL   => 60 * 60 * 24 * 3,
    );
    $Success = $Self->True(
        TestName   => 'Cache set, backend and memory',
        TestValue  => $SuccessSet,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value in memory and in backend
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0004'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueBoth = $CacheObject->Get(
        Type => $CacheType,
        Key  => 'Key1',
    );
    $Success = $Self->Is(
        TestName   => 'Cache get, backend and memory',
        CheckValue => 1,
        TestValue  => $CacheValueBoth,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from backend only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0005'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueBackend = $CacheObject->Get(
        Type          => $CacheType,
        Key           => 'Key1',
        CacheInMemory => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Cache get, backend only',
        CheckValue => 1,
        TestValue  => $CacheValueBackend,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from memory only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0006'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueMemory = $CacheObject->Get(
        Type           => $CacheType,
        Key            => 'Key1',
        CacheInBackend => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Cache get, memory only',
        CheckValue => 1,
        TestValue  => $CacheValueMemory,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value both options disabled
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0007'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueDisabled = $CacheObject->Get(
        Type           => $CacheType,
        Key            => 'Key1',
        CacheInMemory  => 0,
        CacheInBackend => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Cache get, both disabled',
        CheckValue => undef,
        TestValue  => $CacheValueDisabled,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set value only to backend. value has to be removed from memory
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0008'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetBackend = $CacheObject->Set(
        Type          => $CacheType,
        Key           => "Key1",
        Value         => 1,
        TTL           => 60 * 60 * 24 * 3,
        CacheInMemory => 0,
    );
    $Success = $Self->True(
        TestName   => 'Cache set, backend only',
        TestValue  => $SuccessSetBackend,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from backend only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0009'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueBackend3 = $CacheObject->Get(
        Type          => $CacheType,
        Key           => 'Key1',
        CacheInMemory => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Cache get from backend only',
        CheckValue => 1,
        TestValue  => $CacheValueBackend3,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from memory only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0010'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueMemory3 = $CacheObject->Get(
        Type           => $CacheType,
        Key            => 'Key1',
        CacheInBackend => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Removed value from memory',
        CheckValue => undef,
        TestValue  => $CacheValueMemory3,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set value only to memory. value has to be removed from backend
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0011'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetMemory = $CacheObject->Set(
        Type           => $CacheType,
        Key            => "Key1",
        Value          => 1,
        TTL            => 60 * 60 * 24 * 3,
        CacheInBackend => 0,
    );
    $Success = $Self->True(
        TestName   => 'Cache set, memory only',
        TestValue  => $SuccessSetMemory,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from backend only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0012'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueBackend2 = $CacheObject->Get(
        Type          => $CacheType,
        Key           => 'Key1',
        CacheInMemory => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Removed value from backend',
        CheckValue => undef,
        TestValue  => $CacheValueBackend2,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from memory only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0013'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueMemory2 = $CacheObject->Get(
        Type           => $CacheType,
        Key            => 'Key1',
        CacheInBackend => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Cache get from memory only',
        CheckValue => 1,
        TestValue  => $CacheValueMemory2,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # set value, but in no backend. value has to be removed
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0014'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $SuccessSetDisabled = $CacheObject->Set(
        Type           => $CacheType,
        Key            => "Key1",
        Value          => 1,
        TTL            => 60 * 60 * 24 * 3,
        CacheInMemory  => 0,
        CacheInBackend => 0,
    );
    $Success = $Self->True(
        TestName   => 'Cache set, both disabled',
        TestValue  => $SuccessSetDisabled,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from backend only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0015'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueBackend4 = $CacheObject->Get(
        Type          => $CacheType,
        Key           => 'Key1',
        CacheInMemory => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Removed value from backend',
        CheckValue => undef,
        TestValue  => $CacheValueBackend4,
        StartTime  => $StartTime,
    );
    next MODULEFILE if ( !$Success );
    ## EO TEST STEP

    ## TEST STEP
    # get value from memory only
    delete( $Self->{'TestCase'}->{'PlanSteps'}->{'0016'} );
    $StartTime = $Self->GetMilliTimeStamp();
    my $CacheValueMemory4 = $CacheObject->Get(
        Type           => $CacheType,
        Key            => 'Key1',
        CacheInBackend => 0,
    );
    $Success = $Self->Is(
        TestName   => 'Removed value from memory',
        CheckValue => undef,
        TestValue  => $CacheValueMemory4,
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
