# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::UnitTest::Helper;

use strict;
use warnings;

use Time::HiRes;

use Kernel::System::SysConfig;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Cache',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::UnitTest::Helper - unit test helper functions

=over 4

=cut

=item new()

construct a helper object.

    use Kernel::System::ObjectManager;

    my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

=cut
sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item GetRandomNumber()

creates a random Number that can be used in tests as a unique identifier.

It is guaranteed that within a test this function will never return a duplicate.

Please note that these numbers are not really random and should only be used
to create test data.

=cut

# Use package variables here (instead of attributes in $Self)
# to make it work across several unit tests that run during the same second.
my %GetRandomNumberPrevious;

sub GetRandomNumber {

    my $PIDReversed = reverse $$;
    my $PID = reverse sprintf '%.6d', $PIDReversed;

    my $Prefix = $PID . substr time(), -5, 5;

    return $Prefix . $GetRandomNumberPrevious{$Prefix}++ || 0;
}

=item GetMilliTimeStamp()

returns the current time stamp in milliseconds

    my $MilliTimestamp = $UnitTestObject->GetMilliTimeStamp();

=cut
sub GetMilliTimeStamp {
    my ( $Self, %Param ) = @_;

    my $MilliTimestamp = int(Time::HiRes::time() * 1000);

    return $MilliTimestamp;
}

=item BeginWork()

    $Helper->BeginWork()

Starts a database transaction (in order to isolate the test from the static database).

=cut
sub BeginWork {
    my ( $Self, %Param ) = @_;
    $Self->{RestoreDatabase} = 1;
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    $DBObject->Connect();
    return $DBObject->{dbh}->begin_work();
}

=item Rollback()

    $Helper->Rollback()

Rolls back the current database transaction.

=cut
sub Rollback {
    my ( $Self, %Param ) = @_;
    my $DatabaseHandle = $Kernel::OM->Get('Kernel::System::DB')->{dbh};

    # if there is no database handle, there's nothing to rollback
    if ($DatabaseHandle) {
        return $DatabaseHandle->rollback();
    }
    return 1;
}

=item GetTestHTTPHostname()

returns a hostname for HTTP based tests, possibly including the port.

=cut
sub GetTestHTTPHostname {
    my ( $Self, %Param ) = @_;

    my $Host = $Kernel::OM->Get('Kernel::Config')->Get('TestHTTPHostname');
    return $Host if $Host;

    my $FQDN = $Kernel::OM->Get('Kernel::Config')->Get('FQDN');

    # try to resolve fqdn host
    if ( $FQDN ne 'yourhost.example.com' && gethostbyname($FQDN) ) {
        $Host = $FQDN;
    }

    # try to resolve localhost instead
    if ( !$Host && gethostbyname('localhost') ) {
        $Host = 'localhost';
    }

    # use hardcoded localhost ip address
    if ( !$Host ) {
        $Host = '127.0.0.1';
    }

    return $Host;
}

my $FixedTime;

=item FixedTimeSet()

makes it possible to override the system time as long as this object lives.
You can pass an optional time parameter that should be used, if not,
the current system time will be used.

All regular perl calls to time(), localtime() and gmtime() will use this
fixed time afterwards. If this object goes out of scope, the 'normal' system
time will be used again.

=cut
sub FixedTimeSet {
    my ( $Self, $TimeToSave ) = @_;

    $FixedTime = $TimeToSave // CORE::time();

    # This is needed to reload objects that directly use the time functions
    #   to get a hold of the overrides.
    my @Objects = (
        'Kernel::System::Time',
        'Kernel::System::Cache::FileStorable',
        'Kernel::System::PID',
    );

    for my $Object (@Objects) {
        my $FilePath = $Object;
        $FilePath =~ s{::}{/}xmsg;
        $FilePath .= '.pm';
        if ( $INC{$FilePath} ) {
            no warnings 'redefine';
            delete $INC{$FilePath};
            $Kernel::OM->Get('Kernel::System::Main')->Require($Object);
        }
    }

    return $FixedTime;
}

=item FixedTimeUnset()

restores the regular system time behaviour.

=cut
sub FixedTimeUnset {
    my ($Self) = @_;

    undef $FixedTime;

    return;
}

=item FixedTimeAddSeconds()

adds a number of seconds to the fixed system time which was previously
set by FixedTimeSet(). You can pass a negative value to go back in time.

=cut
sub FixedTimeAddSeconds {
    my ( $Self, $SecondsToAdd ) = @_;

    return if ( !defined $FixedTime );
    $FixedTime += $SecondsToAdd;
    return;
}

# See http://perldoc.perl.org/5.10.0/perlsub.html#Overriding-Built-in-Functions
BEGIN {
    *CORE::GLOBAL::time = sub {
        return defined $FixedTime ? $FixedTime : CORE::time();
    };
    *CORE::GLOBAL::localtime = sub {
        my ($Time) = @_;
        if ( !defined $Time ) {
            $Time = defined $FixedTime ? $FixedTime : CORE::time();
        }
        return CORE::localtime($Time);
    };
    *CORE::GLOBAL::gmtime = sub {
        my ($Time) = @_;
        if ( !defined $Time ) {
            $Time = defined $FixedTime ? $FixedTime : CORE::time();
        }
        return CORE::gmtime($Time);
    };
}

=item ConfigSettingChange()

temporarily change a configuration setting system wide to another value,
both in the current ConfigObject and also in the system configuration on disk.

This will be reset when the Helper object is destroyed.

Please note that this will not work correctly in clustered environments.

    $Helper->ConfigSettingChange(
        Valid => 1,            # (optional) enable or disable setting
        Key   => 'MySetting',  # setting name
        Value => { ... } ,     # setting value
    );

=cut
sub ConfigSettingChange {
    my ( $Self, %Param ) = @_;

    my $Valid = $Param{Valid} // 1;
    my $Key   = $Param{Key};
    my $Value = $Param{Value};

    die "Need 'Key'" if !defined $Key;

    my $RandomNumber = $Self->GetRandomNumber();

    my $KeyDump = $Key;
    $KeyDump =~ s|'|\\'|smxg;
    $KeyDump = "\$Self->{'$KeyDump'}";
    $KeyDump =~ s|\#{3}|'}->{'|smxg;

    # Also set at runtime in the ConfigObject. This will be destroyed at the end of the unit test.
    $Kernel::OM->Get('Kernel::Config')->Set(
        Key   => $Key,
        Value => $Valid ? $Value : undef,
    );

    my $ValueDump;
    if ($Valid) {
        $ValueDump = $Kernel::OM->Get('Kernel::System::Main')->Dump($Value);
        $ValueDump =~ s/\$VAR1/$KeyDump/;
    }
    else {
        $ValueDump = "delete $KeyDump;"
    }

    my $PackageName = "ZZZZUnitTest$RandomNumber";

    my $Content = <<"EOF";
# KIX config file (automatically generated)
# VERSION:1.1
package Kernel::Config::Files::$PackageName;
use strict;
use warnings;
no warnings 'redefine';
use utf8;
sub Load {
    my (\$File, \$Self) = \@_;
    $ValueDump
}
1;
EOF
    my $Home     = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my $FileName = "$Home/Kernel/Config/Files/$PackageName.pm";
    $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
        Location => $FileName,
        Mode     => 'utf8',
        Content  => \$Content,
    ) || die "Could not write $FileName";

    return 1;
}

=item ConfigSettingCleanup()

remove all config setting changes from ConfigSettingChange();

=cut
sub ConfigSettingCleanup {
    my ( $Self, %Param ) = @_;

    my $Home  = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my @Files = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => "$Home/Kernel/Config/Files",
        Filter    => "ZZZZUnitTest*.pm",
    );
    for my $File (@Files) {
        $Kernel::OM->Get('Kernel::System::Main')->FileDelete(
            Location => $File,
        ) || die "Could not delete $File";
    }
    return 1;
}

sub DESTROY {
    my $Self = shift;

    # reset time freeze
    FixedTimeUnset();

    # restore system configuration if needed
    if ( $Self->{SysConfigBackup} ) {
        $Self->{SysConfigObject}->Upload( Content => $Self->{SysConfigBackup} );
        $Self->{UnitTestObject}->True( 1, 'Restored the system configuration' );
    }

    # remove any configuration changes
    $Self->ConfigSettingCleanup();

    # restore database, clean caches
    if ( $Self->{RestoreDatabase} ) {
        my $RollbackSuccess = $Self->Rollback();
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();
        $Self->{UnitTestObject}->True( $RollbackSuccess, 'Rolled back all database changes and cleaned up the cache.' );
    }

    return;
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
