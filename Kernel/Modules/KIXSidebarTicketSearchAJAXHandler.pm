# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarTicketSearchAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::KIXSidebarTicket',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}           = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}           = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerUserObject}     = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{KIXSidebarTicketObject} = $Kernel::OM->Get('Kernel::System::KIXSidebarTicket');
    $Self->{TicketObject}           = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}            = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' )
        || 'KIXSidebarTicket';
    my $KIXSidebarToolsConfig = $Self->{ConfigObject}->Get('KIXSidebarTools');
    for my $Data ( keys %{ $KIXSidebarToolsConfig->{Data} } ) {
        my ( $DataIdentifier, $DataAttribute ) = split( ':::', $Data, 2 );
        next if $Self->{Identifier} ne $DataIdentifier;
        $Self->{SidebarConfig}->{$DataAttribute} =
            $KIXSidebarToolsConfig->{Data}->{$Data} || '';
    }

    if ( !$Self->{SidebarConfig} ) {
        my $ConfigPrefix = '';
        if ( $Self->{UserType} eq 'Customer' ) {
            $ConfigPrefix = 'Customer';
        }
        elsif ( $Self->{UserType} ne 'User' ) {
            $ConfigPrefix = 'Public';
        }
        my $CompleteConfig
            = $Self->{ConfigObject}->Get( $ConfigPrefix . 'Frontend::KIXSidebarBackend' );
        if ( $CompleteConfig && ref($CompleteConfig) eq 'HASH' ) {
            $Self->{SidebarConfig} = $CompleteConfig->{ $Self->{Identifier} };
        }
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $SearchString  = $Self->{ParamObject}->GetParam( Param => 'SearchString' )  || '';
    my $CallingAction = $Self->{ParamObject}->GetParam( Param => 'CallingAction' ) || '';
    my $TicketID      = $Self->{ParamObject}->GetParam( Param => 'TicketID' )      || '';
    my $FormID        = $Self->{ParamObject}->GetParam( Param => 'FormID' )        || '';
    my $CustomerUser  = $Self->{ParamObject}->GetParam( Param => 'CustomerUser' )  || '';
    my $CustomerID    = '';
    if ($CustomerUser) {
        my %CustomerUser = $Self->{CustomerUserObject}->CustomerUserDataGet(
            User => $CustomerUser,
        );
        if ( %CustomerUser && $CustomerUser{'UserCustomerID'} ) {
            $CustomerID = $CustomerUser{'UserCustomerID'};
        }
    }

    my $LinkType = $Self->{SidebarConfig}->{'LinkType'} || 'ParentChild';
    my $LinkMode = '';

    my $SelectionDisabled = $Self->{SidebarConfig}->{'SelectionDisabled'} || 0;

    my $Frontend = 'Public';
    if ( $Self->{UserType} eq 'User' ) {
        $Frontend = 'Agent';
    }
    elsif ( $Self->{UserType} eq 'Customer' ) {
        $Frontend     = 'Customer';
        $CustomerUser = $Self->{UserID};
        $CustomerID   = $Self->{CustomerID};
    }

    my $TIDSearchMaskRegexp = $Self->{SidebarConfig}->{'TicketIDSearchMaskRegExp'} || '';
    if (
        $TIDSearchMaskRegexp
        && $CallingAction
        && $CallingAction =~ /$TIDSearchMaskRegexp/
        && $TicketID      =~ m/^\d+$/
        )
    {
        my %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
            Silent   => 1,
        );
        if (%TicketData) {
            $SearchString = $TicketData{Title};
            $CustomerUser = $TicketData{CustomerUserID};
            $CustomerID   = $TicketData{CustomerID};
        }
    }

    if ( $Self->{SidebarConfig}->{'SearchAll'} ) {
        $SearchString = '*';
    }

    if ($TicketID) {
        $LinkMode = 'Valid';
    }
    elsif ($FormID) {

        # set temporary formID as Ticketid
        $TicketID = $FormID;
        $LinkMode = 'Temporary';
    }

    my $ResultHash = $Self->{KIXSidebarTicketObject}->KIXSidebarTicketSearch(
        SearchString   => $SearchString,
        SearchCustomer => $Self->{SidebarConfig}->{'SearchCustomer'},
        SearchStates   => $Self->{SidebarConfig}->{'SearchStates'},
        SearchQueues   => $Self->{SidebarConfig}->{'SearchQueues'},
        SearchTypes    => $Self->{SidebarConfig}->{'SearchTypes'},
        SearchExtended => $Self->{SidebarConfig}->{'SearchExtended'},
        TicketID       => $TicketID,
        LinkMode       => $LinkMode,
        CustomerUser   => $CustomerUser,
        CustomerID     => $CustomerID,
        Frontend       => $Frontend,
        UserID         => $Self->{UserID},
        Limit          => $Self->{SidebarConfig}->{'MaxResultCount'},
    );

    my $Style             = '';
    my $MaxResultDisplay = $Self->{SidebarConfig}->{'MaxResultDisplay'} || 10;
    my $SearchResultCount = scalar keys %{$ResultHash};
    if ( $SearchResultCount > $MaxResultDisplay ) {
        $Style = 'overflow-x:hidden;overflow-y:scroll;height:'
            . ( ( $MaxResultDisplay + 1 ) * 20 ) . 'px;';
    }

    my @Columns = split( ',', $Self->{SidebarConfig}->{'ShowColumns'} || '' );
    my $NumberOfCols = ( scalar @Columns ) + ( $SelectionDisabled ? 0 : 1 );

    $Self->{LayoutObject}->Block(
        Name => 'KIXSidebarTicketSearchResult',
        Data => {
            %Param,
            Identifier        => $Self->{Identifier},
            SearchResultCount => $SearchResultCount,
            NumberOfCols      => $NumberOfCols,
            Style             => $Style,
        },
    );

    my $MaxResultSize = $Self->{SidebarConfig}->{'MaxResultSize'} || 0;
    for my $ID (
        sort {
            $ResultHash->{$b}->{'Link'} <=> $ResultHash->{$a}->{'Link'}
                || $ResultHash->{$a}->{'Title'} cmp $ResultHash->{$b}->{'Title'}
        }
        keys %{$ResultHash}
        )
    {

        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarTicketSearchResultRow',
            Data => {
                Identifier => $Self->{Identifier},
                TicketID   => $ID,
            },
        );

        if ( !$SelectionDisabled ) {
            my $Checked = '';
            if ( $ResultHash->{$ID}->{'Link'} ) {
                $Checked = 'checked="checked"';
            }

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarTicketSearchResultColumnLink',
                Data => {
                    TicketID       => $ID,
                    LinkedTicketID => $TicketID,
                    LinkMode       => $LinkMode,
                    LinkType       => $LinkType,
                    IsChecked      => $Checked,
                },
            );
        }

        for my $Column (@Columns) {

            my $Value = $ResultHash->{$ID}->{$Column} || '';
            my $ValueShort = $Value;

            if ( $MaxResultSize > 0 ) {
                $ValueShort = $Self->{LayoutObject}->Ascii2Html(
                    Text => $Value,
                    Max  => $MaxResultSize,
                );
            }

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarTicketSearchResultColumnValue',
                Data => {
                    Value      => $Value,
                    ValueShort => $ValueShort,
                    TicketID   => $ID,
                    Frontend   => $Frontend,
                },
            );
        }
    }

    # output result
    my $Output = $Self->{LayoutObject}->Output(
        TemplateFile => 'KIXSidebar/TicketSearch',
        Data         => {
            %Param,
        },
        KeepScriptTags => 1,
    );

    return $Self->{LayoutObject}->Attachment(
        ContentType => 'application/json; charset='
            . $Self->{LayoutObject}->{Charset},
        Content => $Output || '',
        Type    => 'inline',
        NoCache => 1,
    );

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
