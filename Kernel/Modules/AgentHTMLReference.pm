# --
# Modified version of the work: Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentHTMLReference;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output = '';

    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $Subaction    = $ParamObject->GetParam( Param => 'Subaction' ) || 'Overview';
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # security: cleanup input data to prevent directory traversal
    $Subaction =~ s{[./]}{}smxg;

    my $HeaderType = $ParamObject->GetParam( Param => 'Header' ) || '';

    # build output
    $Output .= $LayoutObject->Header(
        Title => 'AgentHTMLReference - ' . $Subaction,
        Type  => $HeaderType,
    );
    if ( !$HeaderType ) {
        $Output .= $LayoutObject->NavigationBar();
    }
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentHTMLReference' . $Subaction,
    );
    $Output .= $LayoutObject->Footer();

    return $Output;
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
