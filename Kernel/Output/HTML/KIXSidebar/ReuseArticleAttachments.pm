# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::ReuseArticleAttachments;

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
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Content;

    # check if article attachments exist
    my @ArticleList = $TicketObject->ArticleContentIndex(
        TicketID                   => $Param{TicketID},
        StripPlainBodyAsAttachment => 1,
        UserID                     => $Self->{UserID},
    );
    my $FoundAttachments = 0;
    foreach my $Article (@ArticleList) {
        if ( %{ $Article->{Atms} } ) {
            $FoundAttachments = 1;
            last;
        }
    }

    return if ( !$FoundAttachments );

    # output result
    $Content = $LayoutObject->Output(
        TemplateFile => 'AgentKIXSidebarReuseArticleAttachments',
        Data         => {
            %Param,
            %{ $Self->{Config} },
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
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
