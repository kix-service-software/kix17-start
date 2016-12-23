# --
# Kernel/Modules/KIXSidebarRemoteDBSearchAJAXHandler.pm - AJAX support module for KIXSidebarRemoteDB
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# * Frank(dot)Jacquemin(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarRemoteDBSearchAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerUser',
    'Kernel::System::KIXSidebarRemoteDB',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
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
    $Self->{KIXSidebarRemoteDBObject} = $Kernel::OM->Get('Kernel::System::KIXSidebarRemoteDB');
    $Self->{LogObject}                = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{TicketObject}             = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}              = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' )
        || 'KIXSidebarRemoteDB';
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

    my $SearchString   = $Self->{ParamObject}->GetParam( Param => 'SearchString' )   || '';
    my $CallingAction  = $Self->{ParamObject}->GetParam( Param => 'CallingAction' )  || '';
    my $TicketID       = $Self->{ParamObject}->GetParam( Param => 'TicketID' )       || '';
    my $CustomerUserID = $Self->{ParamObject}->GetParam( Param => 'CustomerUserID' ) || '';

    my $Identifier = $Self->{SidebarConfig}->{Identifier} || '';

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

    my %CustomerUserData;
    if ($CustomerUserID) {
        %CustomerUserData = $Self->{CustomerUserObject}->CustomerUserDataGet(
            User => $CustomerUserID,
        );
    }

    my @RestrictedDBAttributes = ();
    if ( defined( $Self->{SidebarConfig}->{RestrictedDBAttributes} ) ) {
        @RestrictedDBAttributes = split( ",", $Self->{SidebarConfig}->{RestrictedDBAttributes} );
    }
    my @RestrictedMandatory = ();
    if ( defined( $Self->{SidebarConfig}->{RestrictedMandatory} ) ) {
        @RestrictedMandatory = split( ",", $Self->{SidebarConfig}->{RestrictedMandatory} );
    }
    my @RestrictedOTRSObjects = ();
    if ( defined( $Self->{SidebarConfig}->{RestrictedOTRSObjects} ) ) {
        @RestrictedOTRSObjects = split( ",", $Self->{SidebarConfig}->{RestrictedOTRSObjects} );
    }
    my @RestrictedOTRSAttributes = ();
    if ( defined( $Self->{SidebarConfig}->{RestrictedOTRSAttributes} ) ) {
        @RestrictedOTRSAttributes
            = split( ",", $Self->{SidebarConfig}->{RestrictedOTRSAttributes} );
    }

    my @RestrictedValues = ();
    if (
        @RestrictedDBAttributes
        && @RestrictedOTRSObjects
        && @RestrictedOTRSAttributes
        && @RestrictedMandatory
        && scalar(@RestrictedOTRSAttributes) == scalar(@RestrictedOTRSObjects)
        && scalar(@RestrictedOTRSAttributes) == scalar(@RestrictedDBAttributes)
        && scalar(@RestrictedOTRSAttributes) == scalar(@RestrictedMandatory)
        )
    {
        for ( my $Index = 0; $Index < scalar(@RestrictedOTRSObjects); $Index++ ) {
            my $RestrictedValue = '';
            if (
                $RestrictedOTRSObjects[$Index] eq 'Configuration'
                && $RestrictedOTRSAttributes[$Index]
                )
            {
                my @RestrictedValueArray = split( ";", $RestrictedOTRSAttributes[$Index] );
                if (@RestrictedValueArray) {
                    $RestrictedValue = \@RestrictedValueArray;
                }
            }
            elsif (
                $RestrictedOTRSObjects[$Index] eq 'Ticket'
                )
            {
                $RestrictedValue = '';
                my @RestrictedValueArray
                    = $Self->{ParamObject}->GetArray( Param => $RestrictedOTRSAttributes[$Index] );
                if (@RestrictedValueArray) {
                    $RestrictedValue = \@RestrictedValueArray;
                }
                if ( $TicketData{ $RestrictedOTRSAttributes[$Index] } ) {
                    $RestrictedValue = $TicketData{ $RestrictedOTRSAttributes[$Index] };
                }
            }
            elsif (
                $RestrictedOTRSObjects[$Index] eq 'CustomerUser'
                && $CustomerUserData{ $RestrictedOTRSAttributes[$Index] }
                )
            {
                $RestrictedValue = $CustomerUserData{ $RestrictedOTRSAttributes[$Index] };
            }

            if ( !$RestrictedValue && $RestrictedMandatory[$Index] ) {
                $SearchString = "";
            }
            push( @RestrictedValues, $RestrictedValue );
        }
    }
    elsif (
        !@RestrictedDBAttributes
        && !@RestrictedOTRSObjects
        && !@RestrictedOTRSAttributes
        && !@RestrictedMandatory
        )
    {

        # do nothing
    }
    else {
        $SearchString = "";
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'Error',
            Message  => 'Invalid configuration of restrictions for '
                . $Self->{Identifier}
                . '.',
        );
    }

    my $ResultArray;
    if ($SearchString) {
        $ResultArray = $Self->{KIXSidebarRemoteDBObject}->KIXSidebarRemoteDBSearch(
            DatabaseDSN             => $Self->{SidebarConfig}->{DatabaseDSN},
            DatabaseUser            => $Self->{SidebarConfig}->{DatabaseUser},
            DatabasePw              => $Self->{SidebarConfig}->{DatabasePw},
            DatabaseCacheTTL        => $Self->{SidebarConfig}->{DatabaseCacheTTL},
            DatabaseCaseSensitive   => $Self->{SidebarConfig}->{DatabaseCaseSensitive},
            DatabaseTable           => $Self->{SidebarConfig}->{DatabaseTable},
            DatabaseType            => $Self->{SidebarConfig}->{DatabaseType},
            IdentifierAttribute     => $Self->{SidebarConfig}->{IdentifierAttribute},
            DynamicFieldAttributes  => $Self->{SidebarConfig}->{DynamicFieldAttributes},
            PopupAttributes         => $Self->{SidebarConfig}->{PopupAttributes},
            ShowAttributes          => $Self->{SidebarConfig}->{ShowAttributes},
            RestrictedMandatory     => \@RestrictedMandatory,
            RestrictedAttributes    => \@RestrictedDBAttributes,
            RestrictedValues        => \@RestrictedValues,
            RestrictedArrayHandling => $Self->{SidebarConfig}->{RestrictedArrayHandling},
            SearchAttribute         => $Self->{SidebarConfig}->{SearchAttribute},
            SearchValue             => $SearchString,
            Limit                   => $Self->{SidebarConfig}->{'MaxResultCount'},
        );
    }

    if ( $ResultArray && ref($ResultArray) eq 'ARRAY' && scalar( @{$ResultArray} > 0 ) ) {
        my $Style = '';
        my $MaxResultDisplay = $Self->{SidebarConfig}->{'MaxResultDisplay'} || 10;

        my $SearchResultCount = scalar( @{$ResultArray} );

        my $DynamicFieldString = $Self->{SidebarConfig}->{DynamicFields} || '';
        my @DynamicFields = split( ",", $DynamicFieldString );
        my $PopupHeadString = $Self->{SidebarConfig}->{PopupAttributesHead} || '';
        my @PopupHead    = split( ",", $PopupHeadString );
        my $DFOffset     = 0;
        my $PopupOffset  = 0;
        my $ResultOffset = 0;

        if ( $Self->{SidebarConfig}->{DynamicFieldAttributes} ) {
            my @TempDFAttrs = split( ",", $Self->{SidebarConfig}->{DynamicFieldAttributes} );
            if ( scalar(@TempDFAttrs) != scalar(@DynamicFields) ) {
                $DynamicFieldString = '';
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'Error',
                    Message  => 'Invalid configuration of dynamicfields for '
                        . $Self->{Identifier}
                        . '.',
                );
            }
            $ResultOffset = scalar(@TempDFAttrs);
            $PopupOffset  = scalar(@TempDFAttrs);
        }
        if ( $Self->{SidebarConfig}->{PopupAttributes} ) {
            my @TempPopupAttrs = split( ",", $Self->{SidebarConfig}->{PopupAttributes} );
            if ( scalar(@TempPopupAttrs) != scalar(@PopupHead) ) {
                $PopupHeadString = '';
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'Error',
                    Message  => 'Invalid configuration of popuphead for '
                        . $Self->{Identifier}
                        . '.',
                );
            }
            $ResultOffset += scalar(@TempPopupAttrs);
        }
        if ( $Self->{SidebarConfig}->{IdentifierAttribute} ) {
            $DFOffset++;
            $PopupOffset++;
            $ResultOffset++;
        }

        my @HeadCols   = split( ",", $Self->{SidebarConfig}->{ShowAttributesHead} || '' );
        my @ResultCols = split( ",", $Self->{SidebarConfig}->{ShowAttributes}     || '' );
        my $HeadRow = ( scalar(@HeadCols) == scalar(@ResultCols) ) ? 1 : 0;

        if ( $SearchResultCount > $MaxResultDisplay ) {
            $Style = 'overflow-x:hidden;overflow-y:scroll;height:'
                . ( ( $MaxResultDisplay + $HeadRow ) * 20 ) . 'px;';
        }

        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarRemoteDBSearchResult',
            Data => {
                %Param,
                Identifier => $Identifier,
                TicketID   => $Param{TicketID},
                Style      => $Style,
            },
        );

        if ($HeadRow) {
            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarRemoteDBSearchResultHead',
            );
            if ( $Self->{SidebarConfig}->{DynamicFieldAttributes} ) {
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBSearchResultHeadColumnCheck',
                );
            }
            if ( $Self->{SidebarConfig}->{PopupAttributes} ) {
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBSearchResultHeadColumnCheck',
                );
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBPopupContainer',
                    Data => {
                        Identifier => $Identifier,
                        }
                );
            }
            for my $Head (@HeadCols) {
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBSearchResultHeadColumnValue',
                    Data => {
                        Head => $Head,
                    },
                );
            }
        }

        my $MaxResultSize = $Self->{SidebarConfig}->{'MaxResultSize'} || 0;
        for my $ResultRow ( @{$ResultArray} ) {

            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarRemoteDBSearchResultRow',
                Data => {
                    Identifier => $Identifier,
                    Value      => $ResultRow->[0],
                },
            );

            if ( $Self->{SidebarConfig}->{DynamicFieldAttributes} ) {
                my $DFValueString = '';
                if ($DynamicFieldString) {
                    for ( my $DFCounter = $DFOffset; $DFCounter < $PopupOffset; $DFCounter++ ) {
                        if ($DFValueString) {
                            $DFValueString .= ','
                        }
                        $DFValueString
                            .= $Self->{LayoutObject}->LinkEncode( $ResultRow->[$DFCounter] );
                    }
                }
                my $IsChecked = '';
                if (
                    $DynamicFieldString
                    && @DynamicFields
                    )
                {
                    my $DFTicketValueString = '';
                    for my $DynamicField (@DynamicFields) {
                        if ($DFTicketValueString) {
                            $DFTicketValueString .= ','
                        }
                        if ( ref( $TicketData{ 'DynamicField_' . $DynamicField } ) eq 'ARRAY' ) {
                            $DFTicketValueString
                                .= $Self->{LayoutObject}
                                ->LinkEncode( $TicketData{ 'DynamicField_' . $DynamicField }->[0]
                                    || '' );
                        }
                        else {
                            $DFTicketValueString .= $Self->{LayoutObject}->LinkEncode(
                                $TicketData{ 'DynamicField_' . $DynamicField }
                                    || $Self->{ParamObject}
                                    ->GetParam( Param => 'DynamicField_' . $DynamicField )
                                    || ''
                            );
                        }
                    }

                    if ( $DFValueString eq $DFTicketValueString ) {
                        $IsChecked = 'checked="checked"';
                    }
                }

                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBSearchResultRowColumnCheck',
                    Data => {
                        Identifier    => $Identifier,
                        DynamicFields => $DynamicFieldString,
                        TicketID      => $TicketID,
                        Value         => $DFValueString,
                        IsChecked     => $IsChecked,
                    },
                );
            }

            if ( $Self->{SidebarConfig}->{PopupAttributes} ) {
                my $TicketIDPopup = $ResultRow->[0];
                $TicketIDPopup =~ s/[^A-Za-z0-9-_]/_/gxmsi;

                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBInfoRowColumn',
                    Data => {
                        TicketID   => $TicketIDPopup,
                        Identifier => $Identifier,
                        }
                );
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBPopupBlock',
                    Data => {
                        TicketID   => $TicketIDPopup,
                        Identifier => $Identifier,
                        }
                );
                if ($PopupHeadString) {
                    my @PopupAttributes = split( ",", $Self->{SidebarConfig}->{PopupAttributes} );
                    my $MinusIndex = $PopupOffset;
                    for ( my $PopupCnt = $PopupOffset; $PopupCnt < $ResultOffset; $PopupCnt++ ) {
                        $Self->{LayoutObject}->Block(
                            Name => 'KIXSidebarRemoteDBPopupRow',
                            Data => {
                                Label => $PopupHead[ $PopupCnt - $MinusIndex ],
                                Value => $ResultRow->[$PopupCnt],
                                }
                        );
                    }
                }
            }

            for (
                my $ResultIndex = $ResultOffset;
                $ResultIndex < scalar( @{$ResultRow} );
                $ResultIndex++
                )
            {

                my $Result = $ResultRow->[$ResultIndex] || '';
                my $ResultShort = $Result;

                if ( $MaxResultSize > 0 ) {
                    $ResultShort = $Self->{LayoutObject}->Ascii2Html(
                        Text => $Result,
                        Max  => $MaxResultSize,
                    );
                }

                my $LinkTicketID = '';
                if ( $Result && $Self->{SidebarConfig}->{TicketLink} ) {
                    $LinkTicketID = $Self->{TicketObject}->TicketCheckNumber( Tn => $Result );
                }

                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBSearchResultRowColumn',
                    Data => {
                        Result => $Result,
                        }
                );

                if ( $LinkTicketID && ( $Frontend eq 'Agent' || $Frontend eq 'Customer' ) ) {
                    $Self->{LayoutObject}->Block(
                        Name => 'KIXSidebarRemoteDBSearchResultRowColumnLink',
                        Data => {
                            Result      => $Result,
                            ResultShort => $ResultShort,
                            Frontend    => $Frontend
                            }
                    );
                }
                else {
                    $Self->{LayoutObject}->Block(
                        Name => 'KIXSidebarRemoteDBSearchResultRowColumnValue',
                        Data => {
                            Result      => $Result,
                            ResultShort => $ResultShort,
                            }
                    );
                }
            }
        }
    }
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoSearchResult',
        );

    }

    my $Output = $Self->{LayoutObject}->Output(
        TemplateFile => 'KIXSidebar/RemoteDBSearch',
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
