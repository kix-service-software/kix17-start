# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminLog;

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

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # print form
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    # get log data
    my $Log = $Kernel::OM->Get('Kernel::System::Log')->GetLog( Limit => 400 ) || '';

    # split data to lines
    my @Message = split /\n/, $Log;

    # create table
    ROW:
    for my $Row (@Message) {

        my @Parts = split /;;/, $Row;

        next ROW if !$Parts[3];

        my $ErrorClass = ( $Parts[1] =~ /error/ ) ? 'Error' : '';

        $LayoutObject->Block(
            Name => 'Row',
            Data => {
                ErrorClass => $ErrorClass,
                Time       => $Parts[0],
                Priority   => $Parts[1],
                Facility   => $Parts[2],
                Message    => $Parts[3],
            },
        );
    }

    # create & return output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminLog',
        Data         => \%Param,
    );
    $Output .= $LayoutObject->Footer();

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
