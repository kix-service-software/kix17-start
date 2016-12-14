# --
# Kernel/System/PostMaster/Filter/PGPInlineDecryptFilter.pm - decrypts PGP-encoded emails
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Sebastian(dot)Reiss(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::PGPInlineDecryptFilter;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Crypt::PGP',
);

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{LogObject} = $Kernel::OM->Get('Kernel::System::Log');
    
    if ( !$Self->{CryptObject} ) {
        $Self->{CryptObject} = $Kernel::OM->Get('Kernel::System::Crypt::PGP');
    }

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my $Self  = shift;
    my %Param = @_;
    my $inBody;

    # get config options
    my %Config = ();
    if ( $Param{JobConfig} && ref( $Param{JobConfig} ) eq 'HASH' ) {
        %Config = %{ $Param{JobConfig} };
    }

    #------------------------------------------------------------------
    # NOTE: There is a 'bug' in Kernel::System::Crypt::PGP
    # in sub _CryptedWithKey, which is responsible for identifying
    # the keys used to encrypt the message. It parses the gpg output
    # for english output "encrypted with". This DOES NOT work if the
    # environment is set to another language.
    #------------------------------------------------------------------

    #Decrypt body....
    #print STDERR "Decrypting message...\n";
    if ( $Param{GetParam}->{Body} =~ /^-----BEGIN PGP MESSAGE-----/ ) {

        my %DecryptResult = $Self->{CryptObject}->Decrypt( Message => $Param{GetParam}->{Body} );

        if ( $DecryptResult{Successful} ) {
            $Param{GetParam}->{Body} = $DecryptResult{Data};
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Decrypt failure: " . $DecryptResult{Message},
            );
        }
    }

    return 1;
}
1;
