# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentQueueSearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Encode',
    'Kernel::System::Queue',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LayoutObject} = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{EncodeObject} = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{QueueObject}  = $Kernel::OM->Get('Kernel::System::Queue');
    $Self->{ParamObject}  = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search = $Self->{ParamObject}->GetParam( Param => 'Term' ) || '';



    $Search =~ s/\_/\./g;
    $Search =~ s/\%/\.\*/g;
    $Search =~ s/\*/\.\*/g;

    # get queue list
    # search for name....
    my %Queues = $Self->{QueueObject}->QueueList(
        Valid => 1,
    );

    # build data
    my @Data;
    for my $QueueID (keys %Queues) {
        if ( $Queues{$QueueID} =~ /$Search/i ) {
            push @Data, {
                QueueKey   => $QueueID,
                QueueValue => $Queues{$QueueID},
            };
        }
    }

    # build JSON output
    $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => \@Data,
    );

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
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
