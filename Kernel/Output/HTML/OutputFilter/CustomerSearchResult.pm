# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::CustomerSearchResult;

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

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get config
    $Self->{Config} = $ConfigObject->Get('Ticket::Frontend::CustomerTicketSearch');

    if ( $Self->{Config}->{OpenSearchResultPrintInNewTab} ) {

        # create replace string
        my $ReplaceString = '[% WRAPPER JSOnDocumentComplete %]'
            . '$(\'#Submit\').bind(\'click\',function(){'
            . '     if ( $(\'#ResultForm\').val() == "Print" ) {'
            . '         $(\'form[name="compose"]\').attr(\'target\', \'SearchResultPage\');'
            . '     }'
            . '});'
            . '[% END %]';

        # append replace string
        ${ $Param{Data} } .= $ReplaceString;
    }

    # return
    return 1;
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
