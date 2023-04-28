# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ToolBar::Link;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
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

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if frontend module is used
    my $Action = $Param{Config}->{Action};
    if ($Action) {
        return if !$Kernel::OM->Get('Kernel::Config')->Get('Frontend::Module')->{$Action};
    }

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get item definition
    my $Text      = $LayoutObject->{LanguageObject}->Translate( $Param{Config}->{Name} );
    my $URL       = $LayoutObject->{Baselink} . $Param{Config}->{Link};
    my $Priority  = $Param{Config}->{Priority};
    my $AccessKey = $Param{Config}->{AccessKey};
    my $CssClass  = $Param{Config}->{CssClass};
    my $Icon      = $Param{Config}->{Icon};

    my %Return;
    $Return{$Priority} = {
        Block       => 'ToolBarItem',
        Description => $Text,
        Class       => $CssClass,
        Icon        => $Icon,
        Link        => $URL,
        AccessKey   => $AccessKey,
    };
    return %Return;
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
