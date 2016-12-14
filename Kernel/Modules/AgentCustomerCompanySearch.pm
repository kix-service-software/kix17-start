# --
# Kernel/Modules/AgentCustomerCompanySearch.pm - a module used for the autocomplete feature
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# * Andreas(dot)Hergert(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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
    my $CustCompanyMapRef =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::CompanyBackendMapping');
    for my $CurrKey ( keys %CustomerCompanyList ) {
        my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
            CustomerID => $CurrKey,
        );
        my $Search = $CustomerCompanyList{$CurrKey};

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
            $Search = $CustomerCompanyStr;
        }

        push @Data, {
            CustomerCompanyKey   => $CurrKey,
            CustomerCompanyValue => $Search,
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
