# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarTicketSearchAJAXHandler;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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
    my %TicketData;
    if (
        $TIDSearchMaskRegexp
        && $CallingAction
        && $CallingAction =~ /$TIDSearchMaskRegexp/
        && $TicketID      =~ m/^\d+$/
    ) {
        %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 1,
            UserID        => 1,
            Silent        => 1,
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

    # prepare ticket search parameter based on dynamic field values
    my $ProcessSearch = 1;
    my %DFSearchHash = ();
     my @DFSearchFields = ();
    if ( defined( $Self->{SidebarConfig}->{SearchDFFields} ) ) {
        @DFSearchFields = split( ",", $Self->{SidebarConfig}->{SearchDFFields} );
    }
    my @DFSearchMandatory = ();
    if ( defined( $Self->{SidebarConfig}->{SearchDFMandatory} ) ) {
        @DFSearchMandatory = split( ",", $Self->{SidebarConfig}->{SearchDFMandatory} );
    }
    if (
        @DFSearchFields
        && @DFSearchMandatory
        && scalar(@DFSearchFields) == scalar(@DFSearchMandatory)
    ) {
        # get needed objects
        my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        DYNAMICFIELD:
        for ( my $Index = 0; $Index < scalar(@DFSearchFields); $Index++ ) {
            my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
                Name => $DFSearchFields[$Index],
            );
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # extract the dynamic field value form the web request
            my $DynamicFieldValue = $DynamicFieldBackendObject->EditFieldValueGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ParamObject        => $Self->{ParamObject},
                LayoutObject       => $Self->{LayoutObject},
            );

            # no value from web request, but TicketID given =>
            # retrieve value from existing ticket
            if(
                (
                    !$DynamicFieldValue
                    || (
                        ref($DynamicFieldValue) eq 'ARRAY'
                        && !scalar( @{$DynamicFieldValue} )
                    )
                )
                && %TicketData
                && $TicketData{'DynamicField_' . $DFSearchFields[$Index]}
            ) {
                $DynamicFieldValue = $TicketData{'DynamicField_' . $DFSearchFields[$Index]};
            }

            # prepare search parameter hash
            if(
                $DynamicFieldValue
                && (
                    ref($DynamicFieldValue) ne 'ARRAY'
                    || scalar( @{ $DynamicFieldValue } )
                )
            ) {
                $DFSearchHash{ 'DynamicField_' . $DFSearchFields[$Index] } = {
                    'Equals' => $DynamicFieldValue,
                };
            }
            elsif( $DFSearchMandatory[$Index] ) {
                $ProcessSearch = 0;
                last DYNAMICFIELD;
            }
        }
    }

    # execute ticket search in the system module
    my $ResultHash;
    if ( $ProcessSearch ) {
        $ResultHash = $Self->{KIXSidebarTicketObject}->KIXSidebarTicketSearch(
            SearchString        => $SearchString,
            SearchCustomer      => $Self->{SidebarConfig}->{'SearchCustomer'},
            SearchStates        => $Self->{SidebarConfig}->{'SearchStates'},
            SearchStateType     => $Self->{SidebarConfig}->{'SearchStateType'},
            SearchQueues        => $Self->{SidebarConfig}->{'SearchQueues'},
            SearchTypes         => $Self->{SidebarConfig}->{'SearchTypes'},
            SearchExtended      => $Self->{SidebarConfig}->{'SearchExtended'},
            SearchDynamicFields => \%DFSearchHash,
            TicketID            => $TicketID,
            LinkMode            => $LinkMode,
            CustomerUser        => $CustomerUser,
            CustomerID          => $CustomerID,
            Frontend            => $Frontend,
            UserID              => $Self->{UserID},
            Limit               => $Self->{SidebarConfig}->{'MaxResultCount'},
        );
    }
    else {
        $ResultHash = {};
    }

    # prepare result display
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
    ) {

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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
