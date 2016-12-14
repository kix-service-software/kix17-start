# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Ricky(dot)Kaiser(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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

    # get specific JavaScript
    $Self->Block(
        Name => 'SpecificJavaScript',
        Data => {
            %{$Param},
        },
    );
    $Param->{ObjectSpecificJavaScript} = $Self->Output(
        TemplateFile => 'AgentLinkGraphAdditionalITSMConfigItem',
        Data         => $Param,
    );
}

1;
