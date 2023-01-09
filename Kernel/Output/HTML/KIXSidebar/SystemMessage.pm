# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::SystemMessage;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Output::HTML::Layout',
    'Kernel::System::SystemMessage'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my %MessageList = $SystemMessageObject->MessageSearch(
        Action   => $Param{Action},
        Valid    => 1,
        UserID   => $Param{UserID},
        UserType => $Param{UserType}
    );
    my $Content = '';

    return $Content if !%MessageList;

    my $AdditionalClasses = '';
    if (
        $Param{Config}->{'InitialCollapsed'}
        && $Param{Action} =~ /$Param{Config}->{'InitialCollapsed'}/
    ) {
        $AdditionalClasses .= 'Collapsed';
    }

    if ( $Param{Action} =~ /^Customer/) {
        $LayoutObject->Block(
            Name => 'CustomerWidgetHeader',
            Data => {
                %{$Param{Config}},
                AdditionalClasses => $AdditionalClasses,
            },
        );
    } else {
        $LayoutObject->Block(
            Name => 'WidgetHeader',
            Data => {
                %{$Param{Config}},
                AdditionalClasses => $AdditionalClasses,
            },
        );
    }

    $LayoutObject->Block(
        Name => 'SidebarFrame',
        Data => {
            %{$Param{Config}},
            AdditionalClasses => $AdditionalClasses,
        },
    );
    if ( $Param{Config}->{'InitialJS'} ) {
        $Self->{LayoutObject}->Block(
            Name => 'InitialJS',
            Data => {
                InitialJS => $Param{Config}->{'InitialJS'},
            },
        );
    }

    # output result
    $Content = $LayoutObject->Output(
        TemplateFile   => 'KIXSidebar/SystemMessage',
        Data           => {
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
