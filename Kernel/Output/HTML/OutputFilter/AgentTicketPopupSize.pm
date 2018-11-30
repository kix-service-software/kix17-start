# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::AgentTicketPopupSize;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # create replace string
    my $ReplaceString = '[% WRAPPER JSOnDocumentComplete %]'
        . '<script type="text/javascript">//<![CDATA['
        . 'Core.KIX4OTRS.ResizePopup (\'' . $LayoutObject->{EnvRef}->{Action} . '\');'
        . 'if ( $(\'body\').hasClass(\'RealPopup\') ) {'
        . '    $(\'#AppWrapper\').addClass(\'NonMarginTop\');'
        . '}'
        . '//]]></script>'
        . '[% END %]';

    # append replace string
    ${ $Param{Data} } .= $ReplaceString;

    # return
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
