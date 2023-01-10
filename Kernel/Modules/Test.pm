# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::Test;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::ObjectManager;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get test page header
    my $Output = $LayoutObject->Header( Title => 'KIX Test Page' );

    # example blocks
    $LayoutObject->Block(
        Name => 'Row',
        Data => {
            Text    => 'Some Text for the first line',
            Counter => 1,
        },
    );
    $LayoutObject->Block(
        Name => 'Row',
        Data => {
            Text    => 'Some Text for the next line',
            Counter => 2,
        },
    );
    for ( 1 .. 2 ) {

        # fist block
        $LayoutObject->Block(
            Name => 'System',
            Data => {
                Type    => 'System',
                Counter => $_,
            },
        );

        # sub block of System
        $LayoutObject->Block(
            Name => 'User',
            Data => {
                Type    => 'User',
                Counter => $_,
            },
        );

        # sub blocks of User
        $LayoutObject->Block(
            Name => 'UserID',
            Data => {
                Type    => 'UserID',
                Counter => $_,
            },
        );

        # just if $_ > 1
        if ( $_ > 1 ) {
            $LayoutObject->Block(
                Name => 'UserID',
                Data => {
                    Type    => 'UserID',
                    Counter => $_,
                },
            );
        }

        # add this block 3 times
        for ( 4 .. 6 ) {
            $LayoutObject->Block(
                Name => 'UserIDA',
                Data => {
                    Type    => 'UserIDA',
                    Counter => $_,
                },
            );
        }
    }

    # add the times block at least
    $LayoutObject->Block(
        Name => 'Times',
        Data => {
            Type    => 'Times',
            Counter => 443,
        },
    );

    # get test page
    $Output .= $LayoutObject->Output(
        TemplateFile => 'Test',
        Data         => \%Param
    );

    # get test page footer
    $Output .= $LayoutObject->Footer();

    # return test page
    return $Output;
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
