# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarFAQSearchAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::KIXSidebarFAQ',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}        = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{KIXSidebarFAQObject} = $Kernel::OM->Get('Kernel::System::KIXSidebarFAQ');
    $Self->{TicketObject}        = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}         = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' )
        || 'KIXSidebarFAQ';
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

    my $FAQLink  = $Self->{SidebarConfig}->{'FAQLink'}  || 0;
    my $LinkType = $Self->{SidebarConfig}->{'LinkType'} || 'Normal';
    my $LinkMode = '';

    my $Frontend  = 'Public';
    my $Interface = 'public';
    if ( $Self->{UserType} eq 'User' ) {
        $Frontend  = 'Agent';
        $Interface = 'internal';
    }
    elsif ( $Self->{UserType} eq 'Customer' ) {
        $Frontend  = 'Customer';
        $Interface = 'external';
    }

    my $Compose = 1;

    if ($CallingAction) {

        my $NoComposeMaskRegexp = $Self->{SidebarConfig}->{'NoComposeMaskRegExp'} || '';
        if ( $NoComposeMaskRegexp && $CallingAction =~ /$NoComposeMaskRegexp/ ) {
            $Compose = 0;
        }

        my $TIDSearchMaskRegexp = $Self->{SidebarConfig}->{'TicketIDSearchMaskRegExp'} || '';
        if (
            $TIDSearchMaskRegexp
            && $CallingAction =~ /$TIDSearchMaskRegexp/
            && $TicketID      =~ m/^\d+$/
        ) {
            my %TicketData = $Self->{TicketObject}->TicketGet(
                TicketID => $TicketID,
                UserID   => 1,
                Silent   => 1,
            );
            $SearchString = $TicketData{Title} if ( $TicketData{Title} );
        }

    }

    if ($TicketID) {
        $LinkMode = 'Valid';
    }
    else {

        # set temporary formID as Ticketid
        $TicketID = $FormID;
        $LinkMode = 'Temporary';
    }

    my $ResultHash = $Self->{KIXSidebarFAQObject}->KIXSidebarFAQSearch(
        SearchString     => $SearchString,
        MatchAll         => $Self->{SidebarConfig}->{'MatchAll'},
        SearchMode       => $Self->{SidebarConfig}->{'SearchMode'},
        SearchStateTypes => $Self->{SidebarConfig}->{'SearchStateTypes'},
        Interface        => $Interface,
        TicketID         => $TicketID,
        LinkMode         => $LinkMode,
        Limit            => $Self->{SidebarConfig}->{'MaxResultCount'},
        UserID           => $Self->{UserID},
        UserLogin        => $Self->{UserLogin},
    );

    my $Style             = '';
    my $MaxResultDisplay = $Self->{SidebarConfig}->{'MaxResultDisplay'} || 10;
    my $SearchResultCount = scalar keys %{$ResultHash};

    if ( $SearchResultCount > $MaxResultDisplay ) {
        $Style = 'overflow-x:hidden;overflow-y:scroll;height:'
            . ( ( $MaxResultDisplay + 1 ) * 20 ) . 'px;';
    }

    my $NumberOfCols = $FAQLink ? 2 : 1;

    $Self->{LayoutObject}->Block(
        Name => 'KIXSidebarFAQSearchResult',
        Data => {
            %Param,
            Identifier        => $Self->{Identifier},
            SearchResultCount => $SearchResultCount,
            Style             => $Style,
            NumberOfCols      => $NumberOfCols,
        },
    );

    my $MaxResultSize = $Self->{SidebarConfig}->{'MaxResultSize'} || 0;
    for my $ID (
        sort {
            $ResultHash->{$b}->{'Link'} <=> $ResultHash->{$a}->{'Link'}
                || $ResultHash->{$a}->{'Title'} cmp $ResultHash->{$b}->{'Title'}
        }
        keys %{$ResultHash}
    ) {

        my $Result = $ResultHash->{$ID}->{'Title'} || '';
        my $ResultShort = $Result;

        if ( $MaxResultSize > 0 ) {
            $ResultShort = $Self->{LayoutObject}->Ascii2Html(
                Text => $Result,
                Max  => $MaxResultSize,
            );
        }

        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarFAQSearchResultRow',
            Data => {
                Identifier  => $Self->{Identifier},
                FAQID       => $ID,
                }
        );

        if ($FAQLink) {
            my $Checked = '';
            if ( $ResultHash->{$ID}->{'Link'} ) {
                $Checked = 'checked="checked"';
            }

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarFAQSearchResultColumnLink',
                Data => {
                    FAQID          => $ID,
                    LinkedTicketID => $TicketID,
                    LinkMode       => $LinkMode,
                    LinkType       => $LinkType,
                    IsChecked      => $Checked,
                    }
            );
        }

        if ($Compose) {
            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarFAQSearchResultColumnCompose',
                Data => {
                    Result      => $Result,
                    ResultShort => $ResultShort,
                    FAQID       => $ID,
                    }
            );
        }
        else {
            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarFAQSearchResultColumnView',
                Data => {
                    Result      => $Result,
                    ResultShort => $ResultShort,
                    FAQID       => $ID,
                    Frontend    => $Frontend,
                    }
            );
        }

    }

    # output result
    my $Output = $Self->{LayoutObject}->Output(
        TemplateFile => 'KIXSidebar/FAQSearch',
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
