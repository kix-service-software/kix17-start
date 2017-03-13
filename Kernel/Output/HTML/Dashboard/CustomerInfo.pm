# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::CustomerInfo;

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

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    return if !$Param{CustomerUserLogin};

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    my $CustomerUserLogin  = $Param{CustomerUserLogin};
    my $CustomerInfoString = $ConfigObject->Get('DefaultCustomerInfoString');

    if ($CustomerUserLogin) {

        # get customer data
        my %CustomerData = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUserLogin,
        );
        my %CustomerUserList = $CustomerUserObject->CustomerSearch(
            UserLogin => $CustomerUserLogin,
        );

        # customer info string
        for my $KeyCustomerUserList ( sort keys %CustomerUserList ) {
            $Self->{Config}->{From} = $CustomerUserList{$KeyCustomerUserList};
        }
        $Self->{Config}->{CustomerTable} = $LayoutObject->AgentCustomerViewTable(
            Data          => \%CustomerData,
            Max           => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
            CallingAction => $Param{Action}
        );

        # customer details
        if ($CustomerInfoString) {
            $Param{CustomerDetailsTable} = $LayoutObject->AgentCustomerDetailsViewTable(
                Data => \%CustomerData,
                Max  => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize')
                ,
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

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardCustomerInfo',
        Data         => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
        },
        KeepScriptTags => $Param{AJAX},
    );

    # return content
    return $Content;
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
