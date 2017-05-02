# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::DestQueue;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::SystemAddress',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub GetQueueID {
    my ( $Self, %Param ) = @_;

    # get email headers
    my %GetParam = %{ $Param{Params} };

    # check possible to, cc and resent-to emailaddresses
    my $Recipient = '';
    RECIPIENT:
    for my $Key (qw(Resent-To Envelope-To To Cc Delivered-To X-Original-To)) {

        next RECIPIENT if !$GetParam{$Key};

        if ($Recipient) {
            $Recipient .= ', ';
        }

        $Recipient .= $GetParam{$Key};
    }

    # get system address object
    my $SystemAddressObject = $Kernel::OM->Get('Kernel::System::SystemAddress');

    # get addresses
    my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine( Line => $Recipient );

    # check addresses
    my $QueueID;
    EMAIL:
    for my $Email (@EmailAddresses) {

        next EMAIL if !$Email;

        my $Address = $Self->{ParserObject}->GetEmailAddress( Email => $Email );

        next EMAIL if !$Address;

        # lookup queue id if recipiend address
        $QueueID = $SystemAddressObject->SystemAddressQueueID(
            Address => $Address,
        );

        # debug
        if ( $Self->{Debug} > 1 ) {
            if ($QueueID) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'debug',
                    Message =>
                        "Match email: $Email to QueueID $QueueID (MessageID:$GetParam{'Message-ID'})!",
                );
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'debug',
                    Message  => "Does not match email: $Email (MessageID:$GetParam{'Message-ID'})!",
                );
            }
        }

        last EMAIL if $QueueID;
    }

    return $QueueID if $QueueID;

    my $Queue = $Kernel::OM->Get('Kernel::Config')->Get('PostmasterDefaultQueue');

    return $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
        Queue => $Queue,
    ) || 1;
}

sub GetTrustedQueueID {
    my ( $Self, %Param ) = @_;

    # get email headers
    my %GetParam = %{ $Param{Params} };

#rbo - T2016121190001552 - renamed X-OTRS headers
    if( !$GetParam{'X-KIX-Queue'} ) {
        $GetParam{'X-KIX-Queue'} = $GetParam{'X-OTRS-Queue'};       # fallback
    }

    return if !$GetParam{'X-KIX-Queue'};

    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message =>
                "There exists a X-KIX-Queue header: $GetParam{'X-KIX-Queue'} (MessageID:$GetParam{'Message-ID'})!",
        );
    }

    # get dest queue
    return $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
        Queue => $GetParam{'X-KIX-Queue'},
    );

    return;
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
