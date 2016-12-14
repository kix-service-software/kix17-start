# --
# Kernel/Modules/KIXSidebarCISearchAJAXHandler.pm - a module used for the autocomplete feature
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de

# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarCISearchAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::KIXSidebarCI',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}       = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerUserObject} = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{KIXSidebarCIObject} = $Kernel::OM->Get('Kernel::System::KIXSidebarCI');
    $Self->{TicketObject}       = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}        = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Param{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' ) || '';
    if ( $Param{Identifier} ) {
        my $KIXSidebarToolsConfig = $Self->{ConfigObject}->Get('KIXSidebarTools');
        for my $Data ( keys ( %{ $KIXSidebarToolsConfig->{Data} } ) ) {
            my ( $DataIdentifier, $DataAttribute ) = split( ':::', $Data, 2 );
            next if $Param{Identifier} ne $DataIdentifier;
            $Self->{SidebarConfig}->{$DataAttribute} =
                $KIXSidebarToolsConfig->{Data}->{$Data} || '';
        }
    }

    if ( !$Self->{SidebarConfig} ) {
        my $ConfigPrefix = '';
        if ( $Self->{LayoutObject}->{UserType} eq 'Customer' ) {
            $ConfigPrefix = 'Customer';
        }
        my $CompleteConfig
            = $Self->{ConfigObject}->Get( $ConfigPrefix . 'Frontend::KIXSidebarBackend' );
        if ( $CompleteConfig && ref($CompleteConfig) eq 'HASH' ) {
            $Self->{SidebarConfig} = $CompleteConfig->{ $Param{Identifier} }
                || $CompleteConfig->{'KIXSidebarSearchCIs'};
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
    my $CustomerUserID = $Self->{ParamObject}->GetParam( Param => 'CustomerUserID' ) || '';

    my $LinkType = $Self->{SidebarConfig}->{'LinkType'} || 'RelevantTo';
    my $LinkMode = '';

    my $Frontend = 'Public';
    if ( $Self->{UserType} eq 'User' ) {
        $Frontend = 'Agent';
    }
    elsif ( $Self->{UserType} eq 'Customer' ) {
        $Frontend       = 'Customer';
        $CustomerUserID = $Self->{UserID};
    }

    my %TicketData;
    my $TIDSearchMaskRegexp = $Self->{SidebarConfig}->{'TicketIDSearchMaskRegExp'} || '';
    if (
        $TIDSearchMaskRegexp
        && $CallingAction
        && $CallingAction =~ /$TIDSearchMaskRegexp/
        && $TicketID      =~ /^\d+$/
        )
    {
        %TicketData = $Self->{TicketObject}->TicketGet(
            TicketID      => $TicketID,
            DynamicFields => 1,
            Extended      => 1,
            UserID        => 1,
            Silent        => 1,
        );
        $CustomerUserID = $TicketData{CustomerUserID} if ( $TicketData{CustomerUserID} );
    }

    my %KIXSideBarConfig = ();
    for my $ConfigKey ( sort ( keys ( %{ $Self->{SidebarConfig} } ) ) ) {
        if ( $ConfigKey =~ /###/ ) {
            my @ConfigKeyParam = split( /###/, $ConfigKey, 2 );
            if ( $ConfigKeyParam[0] && $ConfigKeyParam[1] ) {
                $KIXSideBarConfig{ $ConfigKeyParam[0] }->{ $ConfigKeyParam[1] }
                    = $Self->{SidebarConfig}->{$ConfigKey};
            }
        }
    }
    return $Self->{LayoutObject}->Output(
        TemplateFile   => 'KIXSidebar/CISearch',
        Data           => \%Param,
        KeepScriptTags => $Param{AJAX} || 0,
    ) if ( !%KIXSideBarConfig );

    my $CustomerSearchPattern = '';
    my $CustomerDataSeparator = '';
    if ( $Self->{SidebarConfig}->{RestrictedCustomerData} ) {
        if ($CustomerUserID) {
            my %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
                User => $CustomerUserID,
            );
            $CustomerSearchPattern
                = $CustomerUserData{ $Self->{SidebarConfig}->{RestrictedCustomerData} } || '';
            if ( !$CustomerSearchPattern ) {
                $Self->{LayoutObject}->Block(
                    Name => 'NoSearchResult',
                    Data => {%Param},
                );
                my $Result = $Self->{LayoutObject}->Output(
                    TemplateFile   => 'KIXSidebar/CISearch',
                    Data           => \%Param,
                    KeepScriptTags => $Param{AJAX} || 0,
                );
                return $Result;
            }
            $CustomerDataSeparator = $Self->{SidebarConfig}->{RestrictedCustomerDataSeparator}
                || '';
        }
        else {
            $Self->{LayoutObject}->Block(
                Name => 'NoSearchResult',
                Data => {%Param},
            );
            my $Result = $Self->{LayoutObject}->Output(
                TemplateFile   => 'KIXSidebar/CISearch',
                Data           => \%Param,
                KeepScriptTags => $Param{AJAX} || 0,
            );
            return $Result;
        }
    }

    # set LinkMode
    if ($TicketID) {
        $LinkMode = 'Valid';
    }
    else {

        # set temporary formID as Ticketid
        $TicketID = $FormID;
        $LinkMode = 'Temporary';
    }

    my $ResultHash = $Self->{KIXSidebarCIObject}->KIXSidebarCISearch(
        TicketID              => $TicketID,
        LinkMode              => $LinkMode,
        CIClasses             => $KIXSideBarConfig{SearchInClasses},
        CustomerSearchPattern => $CustomerSearchPattern,
        CustomerDataSeparator => $CustomerDataSeparator,
        SearchString          => '*' . $SearchString . '*',
        Limit                 => $Self->{SidebarConfig}->{'MaxResultCount'},
    );

    my $SearchResultCount = scalar ( keys ( %{$ResultHash} ) );
    if ( !$SearchResultCount ) {
        $Self->{LayoutObject}->Block(
            Name => 'NoSearchResult',
            Data => {%Param},
        );
        my $Result = $Self->{LayoutObject}->Output(
            TemplateFile   => 'KIXSidebar/CISearch',
            Data           => \%Param,
            KeepScriptTags => $Param{AJAX} || 0,
        );
        return $Result;
    }

    my $Style             = '';
    my $MaxResultDisplay = $Self->{SidebarConfig}->{'MaxResultDisplay'} || 10;
    my $ResultString      = '';
    if ( $Self->{SidebarConfig}->{SearchInputDisabled} ) {
        if ( $SearchResultCount > $MaxResultDisplay ) {
            $ResultString = "$MaxResultDisplay/$SearchResultCount";
            my $Counter = 0;
            for my $Key (
                sort {
                    $ResultHash->{$b}->{'Link'} <=> $ResultHash->{$a}->{'Link'}
                        || $ResultHash->{$a}->{'Number'} cmp $ResultHash->{$b}->{'Number'}
                }
                keys ( %{$ResultHash} )
                )
            {
                if ( $MaxResultDisplay < ++$Counter ) {
                    delete $ResultHash->{$Key};
                }
            }
        }
        else {
            $ResultString = "$SearchResultCount/$SearchResultCount";
        }
    }
    else {
        $ResultString = "$SearchResultCount";
        if ( $SearchResultCount > $MaxResultDisplay ) {
            $Style = 'overflow-x:hidden;overflow-y:scroll;height:'
                . ( ( $MaxResultDisplay + 1 ) * 20 ) . 'px;';
        }
    }

    $Self->{LayoutObject}->Block(
        Name => 'KIXSidebarCISearchResult',
        Data => {
            %Param,
            Style        => $Style,
            ResultString => $ResultString,
            Identifier   => $Self->{SidebarConfig}->{Identifier},
        },
    );

    my @ResultFields = ();
    my @ResultLabels = ();
    my @ResultLinks  = ();
    for my $Config ( sort ( keys ( %{ $KIXSideBarConfig{ShownAttributes} } ) ) ) {
        my @FieldData = split( '::', $Config );
        next if ( ( scalar @FieldData ) < 2 );

        my $Label = $KIXSideBarConfig{ShownAttributes}->{$Config} || $FieldData[1];
        push( @ResultFields, $FieldData[1] );
        push( @ResultLabels, $Label );
        push( @ResultLinks, ( ( scalar @FieldData ) == 3 && $FieldData[2] eq 'Link' ) ? 1 : 0 );
    }
    if ( !$Self->{SidebarConfig}->{SelectionDisabled} ) {
        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarCISearchResultHeadColumnCheck',
        );
    }
    for my $Head (@ResultLabels) {
        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarCISearchResultHeadColumnValue',
            Data => {
                Head => $Head,
            },
        );
    }

    for my $ConfigItemID (
        sort {
            $ResultHash->{$b}->{'Link'} <=> $ResultHash->{$a}->{'Link'}
                || $ResultHash->{$a}->{'Number'} cmp $ResultHash->{$b}->{'Number'}
        }
        keys ( %{$ResultHash} )
        )
    {

        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarCISearchResultRow',
            Data => {
                Identifier => $Self->{SidebarConfig}->{Identifier},
                Value      => $ConfigItemID,
            },
        );

        if ( !$Self->{SidebarConfig}->{SelectionDisabled} ) {
            my $Checked = '';
            if ( $ResultHash->{$ConfigItemID}->{'Link'} ) {
                $Checked = 'checked="checked"';
            }

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarCISearchResultRowColumnCheck',
                Data => {
                    Identifier     => $Self->{SidebarConfig}->{Identifier},
                    Value          => $ConfigItemID,
                    LinkedTicketID => $TicketID,
                    LinkMode       => $LinkMode,
                    LinkType       => $LinkType,
                    IsChecked      => $Checked,
                },
            );
        }

        my $MaxResultSize = $Self->{SidebarConfig}->{'MaxResultSize'} || 0;
        for ( my $index = 0; $index < ( scalar @ResultFields ); $index++ ) {

            my $Result = $ResultHash->{$ConfigItemID}->{ $ResultFields[$index] } || '';
            my $ResultShort = $Result;

            if ( $MaxResultSize > 0 ) {
                $ResultShort = $Self->{LayoutObject}->Ascii2Html(
                    Text => $Result,
                    Max  => $MaxResultSize,
                );
            }

            my $Link = $ResultLinks[$index] || '';

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarCISearchResultRowColumn',
                Data => {
                    Result      => $Result,
                },
            );

            if ($Link) {
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarCISearchResultRowColumnLink',
                    Data => {
                        Frontend    => $Frontend,
                        Result      => $Result,
                        ResultShort => $ResultShort,
                        Value       => $ConfigItemID,
                    },
                );
            }
            else {
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarCISearchResultRowColumnValue',
                    Data => {
                        Result      => $Result,
                        ResultShort => $ResultShort,
                    },
                );
            }
        }
    }

    my $Content = $Self->{LayoutObject}->Output(
        TemplateFile   => 'KIXSidebar/CISearch',
        Data           => \%Param,
        KeepScriptTags => $Param{AJAX} || 0,
    );

    return $Content;

}

1;
