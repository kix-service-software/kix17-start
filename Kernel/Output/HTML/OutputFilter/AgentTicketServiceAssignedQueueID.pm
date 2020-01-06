# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::AgentTicketServiceAssignedQueueID;

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

    # check data
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };

    # create search pattern if change event already defined for ServiceID
    my $SearchPattern
        = '(FormUpdate\(.*?\'AJAXUpdate\'\,\s\'ServiceID\'.*?\])(\)\;)';
    my $ReplacementString = ',function(){ Core.KIX4OTRS.ServiceAssignedQueue(); }';
    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms ) {
        # do replace
        ${ $Param{Data} }
            =~ s{ $SearchPattern }{ $1$ReplacementString$2 }ixms;
    }
    else {
        # create another replacement string
        $ReplacementString = '[% WRAPPER JSOnDocumentComplete %]'
            . '<script type="text/javascript">//<![CDATA['
            . '    $(\'#ServiceID\').bind(\'change\', function (Event) {'
            . '        Core.KIX4OTRS.ServiceAssignedQueue();'
            . '    });'
            . '//]]></script>'
            . '[% END %]';

        # append replace string
        ${ $Param{Data} } .= $ReplacementString;
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
