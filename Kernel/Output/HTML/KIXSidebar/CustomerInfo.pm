# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::CustomerInfo;

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
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Content;

    # only load customer info when not in ticket zoom (performance optimization)
    if ( $Self->{Action} ne 'AgentTicketZoom' ) {
        if ( !$Param{CustomerData} && $Param{CustomerUserID} ) {
            my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
                User => $Param{CustomerUserID},
            );
            $Param{CustomerData} = \%CustomerUserData;
        }

        if ( $Param{TicketID} && !$Param{TicketData} ) {
            my %Ticket = $TicketObject->TicketGet(
                TicketID      => $Param{TicketID},
                DynamicFields => 1,
                UserID        => $Param{UserID} || 1,
            );
            $Param{TicketData} = \%Ticket;
        }

        if ( $Param{ArticleID} && !$Param{ArticleData} ) {
            my %Article = $TicketObject->ArticleGet(
                ArticleID     => $Param{ArticleID},
                DynamicFields => 1,
                UserID        => $Param{UserID} || 1,
            );
            $Param{ArticleData} = \%Article;
        }

        # join Data parts
        my %Ticket;
        if ( $Param{TicketData} ) {
            %Ticket = %{ $Param{TicketData} };
        }
        my %Article;
        if ( $Param{ArticleData} ) {
            %Article = %{ $Param{ArticleData} };
        }
        $Param{TicketData} = {
            %Ticket,
            %Article,
        };

        # customer info string
        if ( ref( $Param{CustomerData} ) eq 'HASH' && %{ $Param{CustomerData} } ) {
            my $CustomerInfoString = $ConfigObject->Get('DefaultCustomerInfoString');

            $Param{CustomerTable} = $LayoutObject->AgentCustomerViewTable(
                Data          => $Param{CustomerData},
                Ticket        => $Param{TicketData},
                Max           => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
                CallingAction => $Param{Action}
            );

            if ($CustomerInfoString) {
                $Param{CustomerDetailsTable} = $LayoutObject->AgentCustomerDetailsViewTable(
                    Data   => $Param{CustomerData},
                    Ticket => $Param{TicketData},
                    Max    => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
                );
                $LayoutObject->Block(
                    Name => 'CustomerDetailsMagnifier',
                    Data => \%Param,
                );

            }

            $LayoutObject->Block(
                Name => 'CustomerDetails',
                Data => \%Param,
            );
        }
    }

    # show customer email selection in AgentTicketZoom and load info via AJAX call
    else {

        # create empty dropdown
        $Param{CustomerEmailSelection} = $LayoutObject->BuildSelection(
            Name         => 'CustomerUserEmail',
            Data         => [],
            Translation  => 0,
            PossibleNone => 0,
        );

        $LayoutObject->Block(
            Name => 'CustomerEmailSelection',
            Data => \%Param,
        );
    }

    # output result
    $Content = $LayoutObject->Output(
        TemplateFile => 'AgentKIXSidebarCustomerInfo',
        Data         => {
            %Param,
            %{ $Self->{Config} },
        },
        KeepScriptTags => $Param{AJAX},
    );

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
