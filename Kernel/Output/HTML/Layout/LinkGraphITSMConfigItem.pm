# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::LinkGraphITSMConfigItem;

use strict;
use warnings;

our @ObjectDependencies = ();

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub GetConfigItemSpecificLayoutContentForGraph {
    my ( $Self, $Param ) = @_;

    # get specific print
    $Self->Block(
        Name => 'SpecificPrint',
        Data => {
            RelCIClasses => $Param->{RelSubTypesString},
        },
    );
    $Param->{ObjectSpecificPrint} = $Self->Output(
        TemplateFile => 'AgentLinkGraphAdditionalITSMConfigItem',
        Data         => $Param,
    );

    # get specific context
    $Self->Block(
        Name => 'SpecificContext',
        Data => {},
    );
    $Param->{ObjectSpecificContext} = $Self->Output(
        TemplateFile => 'AgentLinkGraphAdditionalITSMConfigItem',
        Data         => $Param,
    );

    # get specific save-config
    $Self->Block(
        Name => 'SpecificSavedGraphs',
        Data => {},
    );
    $Param->{ObjectSpecificSavedGraphs} = $Self->Output(
        TemplateFile => 'AgentLinkGraphAdditionalITSMConfigItem',
        Data         => $Param,
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
