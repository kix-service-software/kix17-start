# --
# Kernel/System/KIXSidebarTicketLinkCI.pm - KIXSidebarTicketLinkCI backend
# based on Kernel/System/KIXSidebarTools.pm
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Frank(dot)Oberender(at)cape-it(dot)de
# * Rene(dot)Boehm(at)cape-it(dot)de
# * Stefan(dot)Mehlig(at)cape-it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXSidebarTicketLinkCI;

use strict;
use warnings;

use utf8;

our @ObjectDependencies = (
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject',
    'Kernel::System::Log'
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LinkObject}       = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}        = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

sub KIXSidebarTicketLinkCISearch {
    my ( $Self, %Param ) = @_;

    if ( !$Param{TicketIDs} || ref( $Param{TicketIDs} ) ne 'ARRAY' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "Need TicketIDs as ArrayRef!",
        );
        return;
    }

    my %TicketLinkKeyList = ();
    if ( $Param{TicketID} && $Param{LinkMode} ) {
        %TicketLinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => 'ITSMConfigItem',
            State   => $Param{LinkMode},
            UserID  => 1,
        );
    }

    my %Result = ();

    for my $TicketID ( @{ $Param{TicketIDs} } ) {
        my %LinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $TicketID,
            Object2 => 'ITSMConfigItem',
            State   => 'Valid',
            UserID  => 1,
        );

        for my $ID ( keys %LinkKeyList ) {

            # Skip entries added by previous TicketID
            next if ( $Result{$ID} );

            my $VersionRef = $Self->{ConfigItemObject}->VersionGet(
                ConfigItemID => $ID,
                XMLDataGet   => 0,
            );
            if (
                $VersionRef
                && ( ref($VersionRef) eq 'HASH' )
                && $VersionRef->{Name}
                && $VersionRef->{Number}
                )
            {
                $Result{$ID} = $VersionRef;
                $Result{$ID}->{'Link'} = ( $TicketLinkKeyList{$ID} ? 1 : 0 );

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }
    }

    return \%Result;
}

1;
