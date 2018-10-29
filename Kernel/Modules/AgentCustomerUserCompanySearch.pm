# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentCustomerUserCompanySearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerCompany',
    'Kernel::System::CustomerUser',
    'Kernel::System::Encode',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}          = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}          = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerCompanyObject} = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    $Self->{CustomerUserObject}    = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{EncodeObject}          = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{ParamObject}           = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search = $Self->{ParamObject}->GetParam( Param => 'Term' ) || '';

    my $AutoCompleteConfig = $Self->{ConfigObject}->Get('AutoComplete::Agent')->{CustomerSearch};

    my $MaxResults = $AutoCompleteConfig->{MaxResultsDisplayed} || 20;

    my @CustomerIDs = $Self->{CustomerUserObject}->CustomerIDList(
        SearchTerm => $Search || '',
    );

    my %CustomerCompanyList = $Self->{CustomerCompanyObject}->CustomerCompanyList(
        Search => $Search || '',
    );

    # add CustomerIDs for which no CustomerCompany are registered
    my %Seen;
    for my $CustomerID (@CustomerIDs) {

        # skip duplicates
        next CUSTOMERID if $Seen{$CustomerID};
        $Seen{$CustomerID} = 1;

        # identifies unknown companies
        if ( !exists $CustomerCompanyList{$CustomerID} ) {
            $CustomerCompanyList{$CustomerID} = $CustomerID;
        }

    }

    # build result list
    my @Result;
    CUSTOMERID:
    for my $CustomerID ( sort keys %CustomerCompanyList ) {
        push @Result,
            {
            CustomerUserCompanyKey   => $CustomerID,
            CustomerUserCompanyValue => $CustomerCompanyList{$CustomerID},
            };
        last CUSTOMERID if scalar @Result >= $MaxResults;
    }

    # build JSON output
    $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => \@Result,
    );

    # send JSON response
    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset=' . $Self->{LayoutObject}->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );
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
