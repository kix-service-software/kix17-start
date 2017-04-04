# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Cache::Redis;

use strict;
use warnings;

use Redis;
use Digest::MD5 qw();
umask 002;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

use vars qw(@ISA);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    $Self->{Config} = $ConfigObject->Get('Cache::Module::Redis');
    if ( $Self->{Config} ) {
        $Self->_initRedis();
    }

    return $Self;
}

sub Set {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key Value TTL)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    return if !$Self->{RedisObject};

    my $PreparedKey = $Self->_prepareMemCacheKey(%Param);
    my $TTL = $Param{TTL};
    if ($Self->{Config}->{OverrideTTL}) {
        foreach my $TypePattern (keys %{$Self->{Config}->{OverrideTTL}}) {
            if ($Param{Type} =~ /^$TypePattern$/g) {
                $TTL = $Self->{Config}->{OverrideTTL}->{$TypePattern};
                last;
            }
        }
    }

    if ($Self->{Config}->{CacheMetaInfo}) {
		my $Result;
		
        # update indexes
        $Result->{'Memcached::CachedObjects'} = $Self->{RedisObject}->get(
            "Memcached::CachedObjects",
		);
		
		$Result->{"Memcached::CacheIndex::$Param{Type}"} = $Self->{RedisObject}->get(
            "Memcached::CacheIndex::$Param{Type}",
        );
		
        # update global object index
        if ( !$Result->{'Memcached::CachedObjects'} || ref( $Result->{'Memcached::CachedObjects'} ) ne 'HASH' ) {
            $Result->{'Memcached::CachedObjects'} = {};
        }
        $Result->{'Memcached::CachedObjects'}->{ $Param{Type} } = 1;

        # update cache index for Type
        if (
            !$Result->{"Memcached::CacheIndex::$Param{Type}"}
            || ref( $Result->{"Memcached::CacheIndex::$Param{Type}"} ) ne 'HASH'
            )
        {
            $Result->{"Memcached::CacheIndex::$Param{Type}"} = {};
        }
        $Result->{"Memcached::CacheIndex::$Param{Type}"}->{$PreparedKey} = 1;

		$Self->{RedisObject}->set(
			"Memcached::CacheIndex::$Param{Type}", 
			$Result->{"Memcached::CacheIndex::$Param{Type}"},
		);

		$Self->{RedisObject}->set(
			"Memcached::CachedObjects",
			$Result->{"Memcached::CachedObjects"},
		);

        return $Self->{RedisObject}->setex(
            $PreparedKey, 
			$TTL, 
			$Param{Value},
        );
    }
    else {
        # update indexes
        my $Result = $Self->{RedisObject}->get(
            "Memcached::CacheIndex::$Param{Type}",
        );

        # update cache index for Type
        if (!$Result || ref( $Result ) ne 'HASH') {
            $Result = {};
        }
        $Result->{$PreparedKey} = 1;

        $Self->{RedisObject}->set(
			"Memcached::CacheIndex::$Param{Type}", $Result
		),

        return $Self->{RedisObject}->setex(
            $PreparedKey, 
			$TTL, 
			$Param{Value},
        );
    }
}

sub Get {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return if !$Self->{RedisObject};

    return $Self->{RedisObject}->get(
        $Self->_prepareMemCacheKey(%Param),
    );
}

sub Delete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type Key)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return if ( !$Self->{RedisObject} );

    return $Self->{RedisObject}->del(
        $Self->_prepareMemCacheKey(%Param)
    );
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

    return if ( !$Self->{RedisObject} );

    if ( $Param{Type} ) {

        # get cache index for Type
        my $CacheIndex = $Self->{RedisObject}->get(
            "Memcached::CacheIndex::$Param{Type}",
        );
        if ( $CacheIndex && ref($CacheIndex) eq 'HASH' ) {
            $Self->{RedisObject}->delete_multi(
                keys %{$CacheIndex},
            );

            # delete cache index
            $Self->{RedisObject}->del(
                "Memcached::CacheIndex::$Param{Type}",
            );

            if ($Self->{Config}->{CacheMetaInfo}) {
                # delete from global object index
                $CacheIndex = $Self->{RedisObject}->get(
                    "Memcached::CachedObjects",
                );
                delete $CacheIndex->{ $Param{Type} };
                $Self->{RedisObject}->set(
                    "Memcached::CachedObjects",
                    $CacheIndex,
                );
            }
        }
        return 1;
    }
    else {
        return $Self->{RedisObject}->flushall();
    }
}

=item _initMemCache()

initialize connection to Redis

    my $Value = $CacheInternalObject->_initRedis();

=cut

sub _initRedis {
    my ( $Self, %Param ) = @_;

    my %InitParams = (
        server => $Self->{Config}->{Server},
        %{ $Self->{Config}->{Parameters} },
    );

    $Self->{RedisObject} = Redis->new(%InitParams)
        || die "Unable to initialize Redis connection!";

    return 1;
}

=item _prepareMemCacheKey()

Use MD5 digest of Key for memcached key (memcached key max length is 250);
we use here algo similar to original one from FileStorable.pm.
(thanks to Informatyka Boguslawski sp. z o.o. sp.k., http://www.ib.pl/ for testing and contributing the MD5 change)

    my $PreparedKey = $CacheInternalObject->_prepareMemCacheKey(
        'SomeKey',
    );

=cut

sub _prepareMemCacheKey {
    my ( $Self, %Param ) = @_;

    if ($Param{Raw}) {
        return $Param{Type}.'::'.$Param{Key};
    }

    my $Key = $Param{Key};
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeOutput( \$Key );
    $Key = Digest::MD5::md5_hex($Key);
    $Key = $Param{Type} . '::' . $Key;
    return $Key;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
