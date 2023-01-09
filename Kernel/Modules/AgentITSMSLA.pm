# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentITSMSLA;

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

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # output overview
    $LayoutObject->Block(
        Name => 'Overview',
        Data => {%Param},
    );

    # get sla object
    my $SLAObject = $Kernel::OM->Get('Kernel::System::SLA');

    # get sla list
    my %SLAList = $SLAObject->SLAList(
        UserID => $Self->{UserID},
    );

    if (%SLAList) {
        for my $SLAID ( sort { $SLAList{$a} cmp $SLAList{$b} } keys %SLAList ) {

            # get sla data
            my %SLA = $SLAObject->SLAGet(
                SLAID  => $SLAID,
                UserID => $Self->{UserID},
            );

            # output overview row
            $LayoutObject->Block(
                Name => 'OverviewRow',
                Data => {
                    %SLA,
                },
            );
        }
    }

    # otherwise it displays a no data found message
    else {
        $LayoutObject->Block(
            Name => 'NoDataFoundMsg',
        );
    }

    # investigate refresh
    my $Refresh = $Self->{UserRefreshTime} ? 60 * $Self->{UserRefreshTime} : undef;

    # output header
    my $Output = $LayoutObject->Header(
        Title   => 'Overview',
        Refresh => $Refresh,
    );
    $Output .= $LayoutObject->NavigationBar();

    # generate output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentITSMSLA',
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
