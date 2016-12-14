# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::OnlineHelp;

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
    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check if output contains logout button
    my $AgentPattern = '<a class="LogoutButton" id="LogoutButton"';

    # add help link to existing logout link in agent frontend
    if ( ${ $Param{Data} } =~ /$AgentPattern/g ) {

        my $URL = $ConfigObject->Get('KIXHelpURL');
        my $Replace
            = "<a href=\"$URL\" target=\"_blank\" id=\"KIXHelp\" class=\"KIXHelp\" title=\""
            . $LayoutObject->{LanguageObject}->Translate('KIX Online Help')
            . "\"><i class=\"fa fa-medkit\"></i></a>";
        ${ $Param{Data} } =~ s/($AgentPattern)/$Replace$1/g;
    }
    return 1;
}

1;
