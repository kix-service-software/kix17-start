# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::HeaderMeta::CustomerTicketSearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Session = '';
    if ( !$LayoutObject->{SessionIDCookie} ) {
        $Session = ';' . $LayoutObject->{SessionName} . '='
            . $LayoutObject->{SessionID};
    }
    my $Title = $Kernel::OM->Get('Kernel::Config')->Get('ProductName');
    $Title .= ' - ' . $LayoutObject->{LanguageObject}->Translate('Customer');
    $Title .= ' (' . $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Hook') . ')';
    $LayoutObject->Block(
        Name => 'MetaLink',
        Data => {
            Rel   => 'search',
            Type  => 'application/opensearchdescription+xml',
            Title => $Title,
            Href  => $LayoutObject->{Baselink} . 'Action=' . $Param{Config}->{Action}
                . ';Subaction=OpenSearchDescription' . $Session,
        },
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
