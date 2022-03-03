package Crypt::SSLeay::MainContext;

# maintains a single instance of the Crypt::SSLeay::CTX class

use strict;
use Carp ();
use Exporter qw ( import );

use vars qw( @EXPORT @EXPORT_OK );
@EXPORT = ();
@EXPORT_OK = qw( main_ctx );

require Crypt::SSLeay::CTX;

# The following list is taken, with appreciation, from
# Ristic, I (2013) "OpenSSL Cookbook", Feisty Duck Ltd
# http://amzn.to/1z8rDdj
#
use constant CRYPT_SSLEAY_DEFAULT_CIPHER_LIST => join(
    q{:}, qw(
        kEECDH+ECDSA
        kEECDH
        kEDH
        HIGH
        +SHA
        +RC4
        RC4
        !aNULL
        !eNULL
        !LOW
        !3DES
        !MD5
        !EXP
        !DSS
        !PSK
        !SRP
        !kECDH
        !CAMELLIA
    )
);

sub main_ctx {
    my $ctx = Crypt::SSLeay::CTX->new(
        $ENV{CRYPT_SSLEAY_ALLOW_SSLv3} ? 1 : 0
    );

    if ($ENV{CRYPT_SSLEAY_CIPHER}) {
        $ctx->set_cipher_list($ENV{CRYPT_SSLEAY_CIPHER});
    }
    else {
        $ctx->set_cipher_list(
            CRYPT_SSLEAY_DEFAULT_CIPHER_LIST
        );
    }
    $ctx;
}

1;
