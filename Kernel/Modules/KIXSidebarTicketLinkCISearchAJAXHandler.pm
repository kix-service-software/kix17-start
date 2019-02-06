# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarTicketLinkCISearchAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::KIXSidebarTicketLinkCI',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request'
);

use Kernel::System::KIXSidebarTicketLinkCI;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}                 = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}                 = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{KIXSidebarTicketLinkCIObject} = $Kernel::OM->Get('Kernel::System::KIXSidebarTicketLinkCI');
    $Self->{TicketObject}                 = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}                  = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' )
        || 'KIXSidebarTicketLinkCI';
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

    my @TicketIDs = split( ',', $Self->{ParamObject}->GetParam( Param => 'TicketIDs' ) || '' );
    my $TicketID  = $Self->{ParamObject}->GetParam( Param => 'TicketID' ) || '';
    my $FormID    = $Self->{ParamObject}->GetParam( Param => 'FormID' ) || '';

    my $LinkType = $Self->{SidebarConfig}->{'LinkType'} || 'RelevantTo';
    my $LinkMode = '';

    my $SelectionDisabled = $Self->{SidebarConfig}->{'SelectionDisabled'} || 0;

    my $Frontend = 'Public';
    if ( $Self->{UserType} eq 'User' ) {
        $Frontend = 'Agent';
    }
    elsif ( $Self->{UserType} eq 'Customer' ) {
        $Frontend = 'Customer';
    }

    if ($TicketID) {
        $LinkMode = 'Valid';
    }
    else {

        # set temporary formID as Ticketid
        $TicketID = $FormID;
        $LinkMode = 'Temporary';
    }

    my $ResultHash = ();
    if (@TicketIDs) {
        $ResultHash = $Self->{KIXSidebarTicketLinkCIObject}->KIXSidebarTicketLinkCISearch(
            TicketIDs => \@TicketIDs,
            TicketID  => $TicketID,
            LinkMode  => $LinkMode,
            UserID    => $Self->{UserID},
            Limit     => $Self->{SidebarConfig}->{'MaxResultCount'},
        );
    }

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
        Name => 'KIXSidebarTicketLinkCISearchResult',
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
                || $ResultHash->{$a}->{'Name'} cmp $ResultHash->{$b}->{'Name'}
        }
        keys %{$ResultHash}
        )
    {

        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarTicketLinkCISearchResultRow',
            Data => {
                Identifier   => $Self->{Identifier},
                ConfigItemID => $ID,
            },
        );

        if ( !$SelectionDisabled ) {
            my $Checked = '';
            if ( $ResultHash->{$ID}->{'Link'} ) {
                $Checked = 'checked="checked"';
            }

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarTicketLinkCISearchResultColumnLink',
                Data => {
                    ConfigItemID   => $ID,
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
                Name => 'KIXSidebarTicketLinkCISearchResultColumnValue',
                Data => {
                    Value        => $Value,
                    ValueShort   => $ValueShort,
                    ConfigItemID => $ID,
                    Frontend     => $Frontend,
                },
            );
        }
    }

    # output result
    my $Output = $Self->{LayoutObject}->Output(
        TemplateFile => 'KIXSidebar/TicketLinkCISearch',
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
