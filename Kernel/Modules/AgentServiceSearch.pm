# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentServiceSearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Encode',
    'Kernel::System::Service',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{LayoutObject}  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{EncodeObject}  = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{ServiceObject} = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{ParamObject}   = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search = $Self->{ParamObject}->GetParam( Param => 'Term' ) || '';

    # get queue list
    # search for name....
    my @ServiceIDs = $Self->{ServiceObject}->ServiceSearch(
        Name   => '*' . $Search . '*',
        UserID => 1,
    );

    # build data
    my @Data;
    for my $CurrKey (@ServiceIDs) {
        my %ServiceData = $Self->{ServiceObject}->ServiceGet(
            ServiceID => $CurrKey,
            UserID    => 1,
        );
        next if ( !%ServiceData );
        push @Data, {
            ServiceKey   => $CurrKey,
            ServiceValue => $ServiceData{Name},
        };
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
