# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Cache::Memcached;

use strict;
use warnings;

use Cache::Memcached::Fast;
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

    $Self->{Config} = $ConfigObject->Get('Cache::Module::Memcached');
    if ( $Self->{Config} ) {
        $Self->_initMemCache();
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

    return if !$Self->{MemcachedObject};

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

    # Memcached may not exceed 2592000 (30 days)
    # set zero (infinite ttl) if exceeded
    if ( $TTL > 2592000 ) {
        $TTL = 0;
    }

    if ($Self->{Config}->{CacheMetaInfo}) {
        # update indexes
        my $Result = $Self->{MemcachedObject}->get_multi(
            "Memcached::CachedObjects",
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
        ) {
            $Result->{"Memcached::CacheIndex::$Param{Type}"} = {};
        }
        $Result->{"Memcached::CacheIndex::$Param{Type}"}->{$PreparedKey} = 1;

        my $Success = $Self->{MemcachedObject}->set_multi(
            [ $PreparedKey, $Param{Value}, $TTL, ],
            [ "Memcached::CacheIndex::$Param{Type}", $Result->{"Memcached::CacheIndex::$Param{Type}"} ],
            [ "Memcached::CachedObjects",          $Result->{"Memcached::CachedObjects"} ],
        );
        if ( ref($Success) eq 'ARRAY' ) {
            my $SuccessResult = 1;
            RESULT:
            for my $SuccessEntry ( @{ $Success } ) {
                if ( !$SuccessEntry ) {
                    $SuccessResult = 0;
                    last RESULT;
                }
            }
            return $SuccessResult;
        }
        return $Success;
    }
    else {
        # update indexes
        my $Result = $Self->{MemcachedObject}->get(
            "Memcached::CacheIndex::$Param{Type}",
        );

        # update cache index for Type
        if (!$Result || ref( $Result ) ne 'HASH') {
            $Result = {};
        }
        $Result->{$PreparedKey} = 1;

        my $Success = $Self->{MemcachedObject}->set_multi(
            [ $PreparedKey, $Param{Value}, $TTL, ],
            [ "Memcached::CacheIndex::$Param{Type}", $Result ],
        );
        if ( ref($Success) eq 'ARRAY' ) {
            my $SuccessResult = 1;
            RESULT:
            for my $SuccessEntry ( @{ $Success } ) {
                if ( !$SuccessEntry ) {
                    $SuccessResult = 0;
                    last RESULT;
                }
            }
            return $SuccessResult;
        }
        return $Success;
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

    return if !$Self->{MemcachedObject};

    return $Self->{MemcachedObject}->get(
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

    return if ( !$Self->{MemcachedObject} );

    return $Self->{MemcachedObject}->delete(
        $Self->_prepareMemCacheKey(%Param)
    );
}

sub CleanUp {
    my ( $Self, %Param ) = @_;

    return if ( !$Self->{MemcachedObject} );

    if ( $Param{Type} ) {

        # get cache index for Type
        my $CacheIndex = $Self->{MemcachedObject}->get(
            "Memcached::CacheIndex::$Param{Type}",
        );
        if ( $CacheIndex && ref($CacheIndex) eq 'HASH' ) {
            $Self->{MemcachedObject}->delete_multi(
                keys %{$CacheIndex},
            );

            # delete cache index
            $Self->{MemcachedObject}->delete(
                "Memcached::CacheIndex::$Param{Type}",
            );

            if ($Self->{Config}->{CacheMetaInfo}) {
                # delete from global object index
                $CacheIndex = $Self->{MemcachedObject}->get(
                    "Memcached::CachedObjects",
                );
                delete $CacheIndex->{ $Param{Type} };
                $Self->{MemcachedObject}->set(
                    "Memcached::CachedObjects",
                    $CacheIndex,
                );
            }
        }
        return 1;
    }
    else {
        return $Self->{MemcachedObject}->flush_all();
    }
}

=item _initMemCache()

initialize connection to memcached

    my $Value = $CacheInternalObject->_initMemCache();

=cut

sub _initMemCache {
    my ( $Self, %Param ) = @_;

    my $InitParams = {
        servers => $Self->{Config}->{Servers},
        %{ $Self->{Config}->{Parameters} },
    };

    $Self->{MemcachedObject} = Cache::Memcached::Fast->new($InitParams)
        || die "Unable to initialize memcached connection!";

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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
