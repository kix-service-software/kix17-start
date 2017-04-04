# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Acl::LimitTemplateSelections;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Type',
    'Kernel::System::Queue',
    'Kernel::System::Service',
    'Kernel::System::SLA',
    'Kernel::System::Priority',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects...
    $Self->{LogObject}      = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}   = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{TypeObject}     = $Kernel::OM->Get('Kernel::System::Type');
    $Self->{QueueObject}    = $Kernel::OM->Get('Kernel::System::Queue');
    $Self->{ServiceObject}  = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{SLAObject}      = $Kernel::OM->Get('Kernel::System::SLA');
    $Self->{PriorityObject} = $Kernel::OM->Get('Kernel::System::Priority');

    $Self->{PriorityList} = { $Self->{PriorityObject}->PriorityList() };
    $Self->{TypeList}     = { $Self->{TypeObject}->TypeList() };
    $Self->{QueueList}    = { $Self->{QueueObject}->QueueList() };
    $Self->{ServiceList}  = {
        $Self->{ServiceObject}->ServiceList(
            Valid  => 1,
            UserID => 1,
            )
    };
    $Self->{SLAList} = {
        $Self->{SLAObject}->SLAList(
            Valid  => 1,
            UserID => 1,
            )
    };

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    return if ( !$Param{DefaultSet} );

    my %TTemplate = $Self->{TicketObject}->TicketTemplateGet(
        ID => $Param{DefaultSet},
    );

    my %TicketWhiteList = ();
    for my $CurrKey ( keys(%TTemplate) ) {

        next if ( !$TTemplate{$CurrKey} );
        next if ( !$TTemplate{$CurrKey.'Fixed'} );

        if ( $CurrKey eq 'QueueID' ) {
            $TicketWhiteList{Queue} = [ $Self->{QueueList}->{ $TTemplate{$CurrKey} } ];
        }
        elsif ( $CurrKey eq 'TypeID' ) {
            $TicketWhiteList{Type} = [ $Self->{TypeList}->{ $TTemplate{$CurrKey} } ];
        }
        elsif ( $CurrKey eq 'ServiceID' ) {
            $TicketWhiteList{Service} = [ $Self->{ServiceList}->{ $TTemplate{$CurrKey} } ];
        }
        elsif ( $CurrKey eq 'SLAID' ) {
            $TicketWhiteList{SLA} = [ $Self->{SLAList}->{ $TTemplate{$CurrKey} } ];
        }
        elsif ( $CurrKey eq 'PriorityID' ) {
            $TicketWhiteList{Priority} = [ $Self->{PriorityList}->{ $TTemplate{$CurrKey} } ];
        }
        elsif ( $CurrKey =~ /DynamicField_/ ) {
            $TicketWhiteList{$CurrKey} = [ $TTemplate{$CurrKey} ];
        }
    }

    # building the actual ACL...
    $Param{Acl}->{'802_LimitTemplateSelections'} = {
        Properties => {
            Frontend => {
                Action => [ '[regexp]' . ( $Param{Config}->{FrontendActions} || '' ) ],
                }
        },
        Possible => {
            Ticket => {%TicketWhiteList},
        },
    };

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
