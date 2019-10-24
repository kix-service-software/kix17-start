# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use Time::HiRes;
use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

# define needed variables
my $HomeDir            = $ConfigObject->Get('Home');
my @BackendModuleFiles = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
    Directory => $HomeDir . '/Kernel/System/Cache/',
    Filter    => '*.pm',
    Silent    => 1,
);
my $StartTime;

MODULEFILE:
for my $ModuleFile (@BackendModuleFiles) {

    next MODULEFILE if !$ModuleFile;

    # extract module name
    my ($Module) = $ModuleFile =~ m{ \/+ ([a-zA-Z0-9]+) \.pm $ }xms;

    next MODULEFILE if !$Module;

    $ConfigObject->Set(
        Key   => 'Cache::Module',
        Value => "Kernel::System::Cache::$Module",
    );

    # create a local cache object
    my $CacheObject = $Kernel::OM->GetNew('Kernel::System::Cache');

    die "Could not setup $Module" if !$CacheObject;

    # flush the cache to have a clear test environment
    $CacheObject->CleanUp();

    my $SetCaches = sub {
        $StartTime = Time::HiRes::time();
        $Self->True(
            $CacheObject->Set(
                Type  => 'A',
                Key   => 'A',
                Value => 'A',
                TTL   => 60 * 60 * 24 * 20,
            ),
            "$Module: Set A/A",
            $StartTime,
        );

        $StartTime = Time::HiRes::time();
        $Self->True(
            $CacheObject->Set(
                Type  => 'B',
                Key   => 'B',
                Value => 'B',
                TTL   => 60 * 60 * 24 * 20,
            ),
            "$Module: Set B/B",
            $StartTime,
        );
    };

    $SetCaches->();

    $StartTime = Time::HiRes::time();
    $Self->True(
        $CacheObject->CleanUp( Type => 'C' ),
        "$Module: Inexistent cache type removed",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->Is(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        'A',
        "$Module: Cache A/A is present",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->Is(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        'B',
        "$Module: Cache B/B is present",
        $StartTime,
    );

    $SetCaches->();

    $StartTime = Time::HiRes::time();
    $Self->True(
        $CacheObject->CleanUp( Type => 'A' ),
        "$Module: Cache type A removed",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->False(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        "$Module: Cache A/A is not present",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->Is(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        'B',
        "$Module: Cache B/B is present",
        $StartTime,
    );

    $SetCaches->();

    $StartTime = Time::HiRes::time();
    $Self->True(
        $CacheObject->CleanUp( KeepTypes => ['A'] ),
        "$Module: All cache types removed except A",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->Is(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        'A',
        "$Module: Cache A/A is present",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->False(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        "$Module: Cache B/B is not present",
        $StartTime,
    );

    $SetCaches->();

    $StartTime = Time::HiRes::time();
    $Self->True(
        $CacheObject->CleanUp(),
        "$Module: All cache types removed",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->False(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        "$Module: Cache A/A is not present",
        $StartTime,
    );

    $StartTime = Time::HiRes::time();
    $Self->False(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        "$Module: Cache B/B is not present",
        $StartTime,
    );

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
