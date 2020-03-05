# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentCustomerCompanySearch;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerCompany',
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
    $Self->{EncodeObject}          = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{ParamObject}           = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $JSON = '';

    # get needed params
    my $Search = $Self->{ParamObject}->GetParam( Param => 'Term' ) || '';

    # get queue list
    # search for name....
    my %CustomerCompanyList = $Self->{CustomerCompanyObject}->CustomerCompanyList(
        Search => '*' . $Search . '*',
    );

    # build data
    my @Data;
    my $CustCompanyMapRef = $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::CompanyBackendMapping');
    for my $CurrKey ( sort keys %CustomerCompanyList ) {
        my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
            CustomerID => $CurrKey,
        );
        my $NewSearch = $CustomerCompanyList{$CurrKey};

        my $CustomerCompanyStr = '';
        if ( $CustCompanyMapRef && ref($CustCompanyMapRef) eq 'HASH' ) {

            for my $MappingField ( sort( keys( %{$CustCompanyMapRef} ) ) ) {
                if ( $CustomerCompanySearchList{ $CustCompanyMapRef->{$MappingField} } ) {
                    $CustomerCompanyStr .= ' '
                        . $CustomerCompanySearchList{ $CustCompanyMapRef->{$MappingField} };
                }
            }

        }
        $CustomerCompanyStr =~ s/\s+$//g;
        $CustomerCompanyStr =~ s/^\s+//g;

        if ( $CustomerCompanyStr ne '' ) {
            $NewSearch = $CustomerCompanyStr;
        }

        push @Data, {
            CustomerCompanyKey   => $CurrKey,
            CustomerCompanyValue => $NewSearch,
        };
    }

    # build JSON output
    $JSON = $Self->{LayoutObject}->JSONEncode(
        Data => \@Data,
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
