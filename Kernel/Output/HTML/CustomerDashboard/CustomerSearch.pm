# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerDashboard::CustomerSearch;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed objects
    for my $Needed (qw(Config Name UserID)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

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

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $AutoCompleteConfig =
        $ConfigObject->Get('Ticket::Frontend::CustomerSearchAutoComplete');
    $LayoutObject->Block(
        Name => 'CustomerSearchAutoComplete',
        Data => {
            ActiveAutoComplete  => $AutoCompleteConfig->{Active},
            minQueryLength      => $AutoCompleteConfig->{MinQueryLength} || 2,
            queryDelay          => $AutoCompleteConfig->{QueryDelay} || 0.1,
            typeAhead           => $AutoCompleteConfig->{TypeAhead} || 'false',
            maxResultsDisplayed => $AutoCompleteConfig->{MaxResultsDisplayed} || 20,
        },
    );

    my $CustomerUserLogin = $Self->{Config}->{CustomerUserLogin};
    if ($CustomerUserLogin) {

        # initialize autocomplete for customer search on AJAXUpdate
        $LayoutObject->Block(
            Name => 'CustomerSearchAutoCompleteOnAJAX',
            Data => {
                ActiveAutoComplete => $AutoCompleteConfig->{Active},
            },
        );

        # get customer data
        my %CustomerData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $CustomerUserLogin,
        );
        my %CustomerUserList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
            UserLogin => $CustomerUserLogin,
        );

        # customer info string
        for my $KeyCustomerUserList ( sort keys %CustomerUserList ) {
            $Self->{Config}->{From} = $CustomerUserList{$KeyCustomerUserList};
        }
        $Self->{Config}->{CustomerTable} = $LayoutObject->AgentCustomerViewTable(
            Data => \%CustomerData,
            Max  => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
        );

        # customer details
        $Param{CustomerDetailsTable} = $LayoutObject->AgentCustomerDetailsViewTable(
            Data => \%CustomerData,
            Max  => $ConfigObject->Get('Ticket::Frontend::CustomerInfoComposeMaxSize'),
        );
        $LayoutObject->Block(
            Name => 'CustomerDetails',
            Data => \%Param,
        );
    }

    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentCustomerDashboardCustomerSearch',
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
