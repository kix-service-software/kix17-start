# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
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
