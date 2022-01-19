# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::BulkTextModules;

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
    if (
        $MainObject->Require('Kernel::System::TextModule')
        && $Param{Action} eq 'AgentTicketBulk'
    ) {

        my $TextModulesTable = $LayoutObject->ShowAllBulkTextModules(
            Action        => $Param{Action},
            UserLastname  => $Self->{UserLastname},
            UserFirstname => $Self->{UserFirstname},
            Agent         => '1',
            UserID        => $Self->{UserID},
            Frontend      => 'Agent'
        );

        $LayoutObject->Block(
            Name => 'BulkTextModuleTable',
            Data => {
                %{ $Self->{Config} },
                TextModulesTable => $TextModulesTable,
            },
        );

        # output results
        $Content = $LayoutObject->Output(
            TemplateFile => 'KIXSidebar/BulkTextModules',
            Data         => {
                %{ $Self->{Config} },
                TextModulesTable => $TextModulesTable,
            },
            KeepScriptTags => $Param{AJAX},
        );
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
