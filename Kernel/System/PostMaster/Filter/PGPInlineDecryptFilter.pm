# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::PGPInlineDecryptFilter;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Crypt::PGP',
);

sub new {
    my ( $Type, %Param ) = @_;

    # Allocate new hash for object.
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
    my ( $Self, %Param ) = @_;

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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
