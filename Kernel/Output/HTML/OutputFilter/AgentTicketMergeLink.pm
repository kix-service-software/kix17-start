# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::AgentTicketMergeLink;

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

    # get Template
    my $Templatename = $Param{TemplateFile} || '';
    return 1 if !$Templatename;

    # create HMTL
    my $SearchPattern
        = '&lt;\!\-\-\sKIX4OTRS\sMergeTargetLinkStart\s::(.*?)::(.*?)&gt;(.*?)&lt;(.*?)KIX4OTRS\sMergeTargetLinkEnd\s*(.*?)&gt;';
    if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms ) {
        if ( $Self->{UserType} eq 'User' ) {
            ${ $Param{Data} }
                =~ s{ $SearchPattern }{ <a  href="index.pl?Action=AgentTicketZoom;TicketID=$1" target="new">$3</a>}ixms;
        }
        elsif ( $Self->{UserType} eq 'Customer' ) {
            ${ $Param{Data} }
                =~ s{ $SearchPattern }{ <a  href="customer.pl?Action=CustomerTicketZoom;TicketID=$1" target="new">$3</a>}ixmsg;
        }
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
