# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::SMIMEFetchFromCustomer;

use strict;
use warnings;

use Kernel::System::EmailParser;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Crypt::SMIME',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # Allocate new hash for object.
    my $Self = {};
    bless( $Self, $Type );

    # Get parser object.
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # Check needed stuff.
    for my $Needed (qw(JobConfig GetParam)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need $Needed!',
            );
            return;
        }
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    return 1 if !$ConfigObject->Get('SMIME');
    return 1 if !$ConfigObject->Get('SMIME::FetchFromCustomer');

    my $CryptObject;
    eval {
        $CryptObject = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');
    };
    return 1 if !$CryptObject;

    my @EmailAddressOnField = $Self->{ParserObject}->SplitAddressLine(
        Line => $Self->{ParserObject}->GetParam( WHAT => 'From' ),
    );

    my $IncomingMailAddress;

    for my $EmailAddress (@EmailAddressOnField) {
        $IncomingMailAddress = $Self->{ParserObject}->GetEmailAddress(
            Email => $EmailAddress,
        );
    }

    return 1 if !$IncomingMailAddress;

    my @Files = $CryptObject->FetchFromCustomer(
        Search => $IncomingMailAddress,
    );

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
