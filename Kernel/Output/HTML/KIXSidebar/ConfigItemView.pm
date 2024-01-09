# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::ConfigItemView;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject} = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $AdditionalClasses = '';
    if (
        $Param{Config}->{'InitialCollapsed'}
        && $Param{Action} =~ /$Param{Config}->{'InitialCollapsed'}/
    ) {
        $AdditionalClasses .= 'Collapsed';
    }

    my $TicketID = '';
    if (
        $Param{Config}->{'TicketIDSearchMaskRegExp'}
        && $Param{Action} =~ /$Param{Config}->{'TicketIDSearchMaskRegExp'}/
    ) {
        $TicketID = $Param{Ticket}->{TicketID} || '';
    }

    $Self->{LayoutObject}->Block(
        Name => 'SidebarFrame',
        Data => {
            %{$Param{Ticket} || {}},
            %{$Param{Config}},
            AdditionalClasses => $AdditionalClasses,
            TicketID          => $TicketID,
        },
    );

    my $TIDSearchMaskRegexp = $Param{Config}->{'TicketIDSearchMaskRegExp'} || '';
    if (
        !(
            $TIDSearchMaskRegexp
            && $Param{Action}
            && $Param{Action} =~ /$TIDSearchMaskRegexp/
            && $Param{TicketID}
        )
    ) {
        if (
            $Self->{ConfigObject}->Get( "Ticket::Frontend::" . $Param{Action} )
            && $Self->{ConfigObject}->Get( "Ticket::Frontend::" . $Param{Action} )->{DynamicField}
            && $Self->{ConfigObject}->Get( "Ticket::Frontend::" . $Param{Action} )->{DynamicField}->{ $Param{Config}->{DynamicField} }
        ) {
            $Self->{LayoutObject}->Block(
                Name => 'DynamicFieldSearch',
                Data => {
                    %{$Param{Ticket} || {}},
                    %{$Param{Config}},
                    TicketID => $TicketID,
                },
            );
        }
    }
    if ( $Param{Config}->{'InitialJS'} ) {
        $Self->{LayoutObject}->Block(
            Name => 'InitialJS',
            Data => {
                InitialJS => $Param{Config}->{'InitialJS'},
            },
        );
    }

    # output result
    my $Content = $Self->{LayoutObject}->Output(
        TemplateFile   => 'KIXSidebar/ConfigItemView',
        Data           => {
            %{$Param{Ticket} || {}},
            %{$Param{Config}},
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
