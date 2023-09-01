# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentBook;

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

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    for my $Recipient (qw(ToCustomer CcCustomer BccCustomer CustomerData)) {
        $Param{$Recipient} = $ParamObject->GetParam( Param => $Recipient );
    }

    # get list of users
    my $Search = $ParamObject->GetParam( Param => 'Search' );
    my %CustomerUserList;

    # get customer user object
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    if ($Search) {
        %CustomerUserList = $CustomerUserObject->CustomerSearch(
            Search => $Search,
        );
    }
    my %List;
    for my $CustomerUser ( sort keys %CustomerUserList ) {
        my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
            User => $CustomerUser,
        );
        if ( $CustomerUserData{UserEmail} ) {
            $List{ $CustomerUserData{UserEmail} } = {
                Email       => $CustomerUserList{$CustomerUser},
                CustomerKey => $CustomerUser,
            };
        }
    }

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # build customer search auto-complete field
    $LayoutObject->Block(
        Name => 'CustomerSearchAutoComplete',
    );

    if (%List) {
        $LayoutObject->Block(
            Name => 'SearchResult',
        );

        my $Count = 1;
        for ( reverse sort { $List{$b}->{Email} cmp $List{$a}->{Email} } keys %List ) {
            $LayoutObject->Block(
                Name => 'Row',
                Data => {
                    Email => $List{$_}->{Email},
                    Count => $Count,
                    CustomerDataJSON =>
                        $Kernel::OM->Get('Kernel::System::JSON')
                        ->Encode( Data => { $List{$_}->{Email} => $List{$_}->{CustomerKey} } ),
                },
            );
            $Count++;
        }
    }

    # start with page ...
    my $Output = $LayoutObject->Header( Type => 'Small' );
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentBook',
        Data         => \%Param
    );
    $Output .= $LayoutObject->Footer( Type => 'Small' );

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
