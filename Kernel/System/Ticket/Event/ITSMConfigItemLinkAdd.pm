# --
# Kernel/System/Ticket/Event/ITSMConfigItemLinkAdd.pm - Create ITSMConfigItem link
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::ITSMConfigItemLinkAdd;
use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::LinkObject',
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );
       
    # get needed objects
    $Self->{ConfigObject}       = $Kernel::OM->Get('Kernel::Config');
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{LinkObject}         = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}          = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "Need $_!",
            );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "Need $_ in Data!",
            );
            return;
        }
    }

    if ( $Param{Event} =~ m/TicketDynamicFieldUpdate/ ) {

        $Param{Event} =~ s/TicketDynamicFieldUpdate_(.*?)/$1/g;

        my $DynamicField = $Self->{DynamicFieldObject}->DynamicFieldGet(
            Name => $Param{Event},
        );

        return if ( $DynamicField->{FieldType} ne 'ITSMConfigItemReference' );
        return if ( !$Param{Data}->{Value} );

        if ( ref( $Param{Data}->{Value} ) eq 'ARRAY' ) {
            for my $Value ( @{ $Param{Data}->{Value} } ) {

                # add links to database
                my $Success = $Self->{LinkObject}->LinkAdd(
                    SourceObject => 'Ticket',
                    SourceKey    => $Param{Data}->{TicketID},
                    TargetObject => 'ITSMConfigItem',
                    TargetKey    => $Value,
                    Type         => $Param{Config}->{LinkType},
                    State        => 'Valid',
                    UserID       => $Param{UserID},
                );
            }
        }
        else {
            # add links to database
            my $Success = $Self->{LinkObject}->LinkAdd(
                SourceObject => 'Ticket',
                SourceKey    => $Param{Data}->{TicketID},
                TargetObject => 'ITSMConfigItem',
                TargetKey    => $Param{Data}->{Value},
                Type         => $Param{Config}->{LinkType},
                State        => 'Valid',
                UserID       => $Param{UserID},
            );
        }
    }

    return 1;
}

1;
