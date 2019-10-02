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

use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

my $HomeDir            = $ConfigObject->Get('Home');
my @BackendModuleFiles = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
    Directory => $HomeDir . '/Kernel/System/Cache/',
    Filter    => '*.pm',
    Silent    => 1,
);

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

    # discard cache object from internally stored objects
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Kernel::System::Cache'],
    );

    # create a local cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    die "Could not setup $Module" if !$CacheObject;

    # flush the cache to have a clear test environment
    $CacheObject->CleanUp();

    my $SetCaches = sub {
        $Self->True(
            $CacheObject->Set(
                Type  => 'A',
                Key   => 'A',
                Value => 'A',
                TTL   => 60 * 60 * 24 * 20,
            ),
            "$Module: Set A/A",
        );

        $Self->True(
            $CacheObject->Set(
                Type  => 'B',
                Key   => 'B',
                Value => 'B',
                TTL   => 60 * 60 * 24 * 20,
            ),
            "$Module: Set B/B",
        );
    };

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp( Type => 'C' ),
        "$Module: Inexistent cache type removed",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        'A',
        "$Module: Cache A/A is present",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        'B',
        "$Module: Cache B/B is present",
    );

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp( Type => 'A' ),
        "$Module: Cache type A removed",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        "$Module: Cache A/A is not present",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        'B',
        "$Module: Cache B/B is present",
    );

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp( KeepTypes => ['A'] ),
        "$Module: All cache types removed except A",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        'A',
        "$Module: Cache A/A is present",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        "$Module: Cache B/B is not present",
    );

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp(),
        "$Module: All cache types removed",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        "$Module: Cache A/A is not present",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        "$Module: Cache B/B is not present",
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
