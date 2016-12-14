# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::CustomizeForm;

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
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{DynamicFieldFilter}
        = $ConfigObject->Get( "Ticket::Frontend::" . $Self->{Action} )->{DynamicField};

    # get params
    my %GetParam;
    for my $Key (qw(ServiceID QueueID Dest TypeID StateID NextStateID PriorityID DefaultSet)) {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
    }

    # get FieldOrderString
    my @FieldOrderArray = ();
    for my $HashKey ( keys %{ $Self->{Config} } ) {
        next if ( $HashKey !~ /[0-9]/ );
        if ( $HashKey && $Self->{Config}->{$HashKey} ) {
            my $NewElement = $HashKey . '::' . $Self->{Config}->{$HashKey};
            push( @FieldOrderArray, $NewElement );
        }
    }

    # build field order string
    $Param{FieldOrderString} = join( ",", @FieldOrderArray );

    # output result
    my $Output = $LayoutObject->Output(
        TemplateFile => 'AgentKIXSidebarCustomizeForm',
        Data         => {
            %Param,
            Action => $Self->{Action},
        },
    );

    return $Output;
}

1;
