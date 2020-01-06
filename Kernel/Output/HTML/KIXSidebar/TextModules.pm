# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::TextModules;

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
    my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TypeObject   = $Kernel::OM->Get('Kernel::System::Type');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Content;

    if ( !$Param{TypeID} && $Param{Type} ) {
        $Param{TypeID} = $TypeObject->TypeLookup(
            Type => $Param{Type},
        );
    }
    if ( !$Param{TypeID} && !$Param{QueueID} && $Param{TicketID} ) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
        );
        %Param = (
            %Param,
            %Ticket,
        );
    }
    if ( $MainObject->Require('Kernel::System::TextModule') ) {

        my $ShowEmptyList = 1;
        my $CustomerUser;

        if ( $Self->{Action} =~ /^CustomerTicketMessage/ ) {
            $ShowEmptyList      = 0;
            $Param{Frontend}    = 'Customer';
            $CustomerUser       = $Self->{UserID};
        }
        elsif ( $Self->{Action} =~ /^Agent/ ) {
            $Param{Frontend}    = 'Agent';
            $CustomerUser       = $Param{CustomerUserID};
        }

        my $TextModulesTable = $LayoutObject->ShowAllTextModules(
            Action        => $Param{Action},
            UserLastname  => $Self->{UserLastname},
            UserFirstname => $Self->{UserFirstname},
            TicketTypeID  => $Param{TypeID},
            TicketStateID => $Param{StateID},
            %Param,
            Agent    => ( $Param{Frontend} eq 'Agent' )    ? '1'             : '',
            Customer => ( $Param{Frontend} eq 'Customer' ) ? '1'             : '',
            Public   => ( $Param{Frontend} eq 'Public' )   ? '1'             : '',
            UserID   => ( $Param{Frontend} eq 'Agent' )    ? $Self->{UserID} : '',
            CustomerUserID => $CustomerUser,
        );

        # output results
        if ( $Param{Frontend} eq 'Agent' ) {
            $Content = $LayoutObject->Output(
                TemplateFile => 'AgentKIXSidebarTextModules',
                Data         => {
                    %{ $Self->{Config} },
                    TextModulesTable => $TextModulesTable,
                },
                KeepScriptTags => $Param{AJAX},
            );
        }
        elsif ( $Param{Frontend} eq 'Customer' || $Param{Frontend} eq 'Public' ) {
            $Content = $LayoutObject->Output(
                TemplateFile => 'CustomerKIXSidebarTextModules',
                Data         => {
                    %{ $Self->{Config} },
                    TextModulesTable => $TextModulesTable,
                },
                KeepScriptTags => $Param{AJAX},
            );
        }
    }
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
