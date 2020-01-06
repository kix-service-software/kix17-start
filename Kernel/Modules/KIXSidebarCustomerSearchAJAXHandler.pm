# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarCustomerSearchAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::KIXSidebarCustomer',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}             = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}             = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerUserObject}       = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{KIXSidebarCustomerObject} = $Kernel::OM->Get('Kernel::System::KIXSidebarCustomer');
    $Self->{ParamObject}              = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Param{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' ) || '';
    if( $Param{Identifier} ) {
        my $KIXSidebarToolsConfig = $Self->{ConfigObject}->Get('KIXSidebarTools');
        for my $Data ( keys ( %{ $KIXSidebarToolsConfig->{Data} } ) ) {
            my ( $DataIdentifier, $DataAttribute ) = split( ':::', $Data, 2 );
            next if $Param{Identifier} ne $DataIdentifier;
            $Self->{SidebarConfig}->{$DataAttribute} =
                $KIXSidebarToolsConfig->{Data}->{ $Data } || '';
        }
    }

    if( !$Self->{SidebarConfig} ) {
        my $ConfigPrefix = '';
        if ( $Self->{LayoutObject}->{UserType} eq 'Customer' ) {
            $ConfigPrefix = 'Customer';
        }
        my $CompleteConfig = $Self->{ConfigObject}->Get($ConfigPrefix . 'Frontend::KIXSidebarBackend');
        if( $CompleteConfig && ref($CompleteConfig) eq 'HASH' ) {
            $Self->{SidebarConfig} = $CompleteConfig->{$Param{Identifier}} || $CompleteConfig->{'KIXSidebarCustomerSearch'};
        }
    }
    $Self->{SidebarConfig}->{Identifier} = $Param{Identifier};

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed params
    my $SearchString   = $Self->{ParamObject}->GetParam( Param => 'SearchString' )   || '';
    my $CallingAction  = $Self->{ParamObject}->GetParam( Param => 'CallingAction' )  || '';
    my $TicketID       = $Self->{ParamObject}->GetParam( Param => 'TicketID' )       || '';
    my $FormID         = $Self->{ParamObject}->GetParam( Param => 'FormID' )         || '';

    my $LinkType = $Self->{SidebarConfig}->{'LinkType'} || '3rdParty';
    my $LinkMode = '';

    my @CustomerBackends;
    if ( $Self->{SidebarConfig}->{'CustomerBackends'} ) {
        @CustomerBackends = split(',', $Self->{SidebarConfig}->{'CustomerBackends'});
    } else {
        my %BackendHash = $Self->{CustomerUserObject}->CustomerSourceList();
        @CustomerBackends = map { $_ } keys ( %BackendHash );
    }

    # set LinkMode
    if ($TicketID) {
        $LinkMode = 'Valid';
    } else {
        # set temporary formID as Ticketid
        $TicketID = $FormID;
        $LinkMode = 'Temporary';
    }

    if ($SearchString) {
        $SearchString = '*' . $SearchString . '*';
    }

    my $ResultHash = $Self->{KIXSidebarCustomerObject}->KIXSidebarCustomerSearch(
        TicketID         => $TicketID,
        LinkMode         => $LinkMode,
        LinkType         => $LinkType,
        SearchString     => $SearchString,
        CustomerBackends => \@CustomerBackends,
        Limit            => $Self->{SidebarConfig}->{'MaxResultCount'},
    );

    my $SearchResultCount = scalar keys ( %{ $ResultHash } );
    if ( !$SearchResultCount ) {
        $Self->{LayoutObject}->Block(
            Name => 'NoSearchResult',
            Data => {%Param},
        );
        my $Result = $Self->{LayoutObject}->Output(
            TemplateFile   => 'KIXSidebar/CustomerSearch',
            Data           => \%Param,
            KeepScriptTags => $Param{AJAX} || 0,
        );
        return $Result;
    }

    my $Style = '';
    my $MaxResultsDisplay = $Self->{SidebarConfig}->{'MaxResultDisplay'} || 10;
    my $ResultString = "$SearchResultCount";
    if ( $SearchResultCount > $MaxResultsDisplay ) {
        $Style = 'overflow-x:hidden;overflow-y:scroll;height:' . ( ( $MaxResultsDisplay + 1 ) * 20 ) . 'px;';
    }

    my $Frontend = 'Public';
    if ( $Self->{UserType} eq 'User' ) {
        $Frontend = 'Agent';
    } elsif ( $Self->{UserType} eq 'Customer' ) {
        $Frontend = 'Customer';
    }

    $Self->{LayoutObject}->Block(
        Name => 'KIXSidebarCustomerSearchResult',
        Data => {
            %Param,
            Style        => $Style,
            ResultString => $ResultString,
            Identifier   => $Self->{SidebarConfig}->{Identifier},
        },
    );

    my @HeadCols   = split( ",", $Self->{SidebarConfig}->{ShowDataHead} || '' );
    my @ResultCols = split( ",", $Self->{SidebarConfig}->{ShowData} || '' );
    my $HeadRow = ( scalar( @HeadCols ) == scalar( @ResultCols ) ) ? 1 : 0;

    if ( $HeadRow ) {
        if ( !$Self->{SidebarConfig}->{SelectionDisabled} ) {
            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarCustomerSearchResultHeadColumnCheck',
            );
        }
        for my $Head ( @HeadCols ) {
            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarCustomerSearchResultHeadColumnValue',
                Data => {
                    Head => $Head,
                },
            );
        }
    }

    my $MaxResultSize = $Self->{SidebarConfig}->{'MaxResultSize'} || 0;

    for my $CustomerID (
        sort {
            $ResultHash->{$b}->{'Link'} <=> $ResultHash->{$a}->{'Link'}
            || $ResultHash->{$a} cmp $ResultHash->{$b}
        }
        keys ( %{ $ResultHash } )
    ) {

        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarCustomerSearchResultRow',
            Data => {
                Identifier => $Self->{SidebarConfig}->{Identifier},
                Value      => $CustomerID,
            },
        );

        if ( !$Self->{SidebarConfig}->{SelectionDisabled} ) {
            my $Checked = '';
            if ( $ResultHash->{$CustomerID}->{'Link'} ) {
                $Checked = 'checked="checked"';
            }

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarCustomerSearchResultRowColumnCheck',
                Data => {
                    Identifier     => $Self->{SidebarConfig}->{Identifier},
                    Value          => $CustomerID,
                    LinkedTicketID => $TicketID,
                    LinkMode       => $LinkMode,
                    LinkType       => $LinkType,
                    IsChecked      => $Checked,
                },
            );
        }

        for ( my $index = 0; $index < ( scalar @ResultCols ); $index++ ) {

            my $Result      = $ResultHash->{$CustomerID}->{ $ResultCols[ $index ] } || '';
            my $ResultShort = $Result;

            if ( $MaxResultSize > 0 ) {
                $ResultShort = $Self->{LayoutObject}->Ascii2Html(
                    Text => $Result,
                    Max  => $MaxResultSize,
                );
            }

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarCustomerSearchResultRowColumnValue',
                Data => {
                    Result      => $Result,
                    ResultShort => $ResultShort,
                },
            );
        }
    }

    my $Content = $Self->{LayoutObject}->Output(
        TemplateFile   => 'KIXSidebar/CustomerSearch',
        Data           => \%Param,
        KeepScriptTags => $Param{AJAX} || 0,
    );

    return $Content;

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
