# --
# Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarConfigItemViewAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}     = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}     = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{ConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LinkObject}       = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{TicketObject}     = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}      = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' )
        || 'KIXSidebarConfigItemView';
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

    my @Keys = ();

    my $CallingAction = $Self->{ParamObject}->GetParam( Param => 'CallingAction' ) || '';
    my $TicketID      = $Self->{ParamObject}->GetParam( Param => 'TicketID' )      || '';

    if ( $Self->{SidebarConfig}->{'DynamicField'} ) {
        my $FieldName           = 'DynamicField_' . ( $Self->{SidebarConfig}->{'DynamicField'} || '' );
        my $TIDSearchMaskRegexp = $Self->{SidebarConfig}->{'TicketIDSearchMaskRegExp'} || '';

        if (
            $CallingAction
            && $TIDSearchMaskRegexp
            && $CallingAction =~ /$TIDSearchMaskRegexp/
            && $TicketID      =~ m/^\d+$/
        ) {
            my %TicketData = $Self->{TicketObject}->TicketGet(
                TicketID      => $TicketID,
                UserID        => $Self->{UserID},
                DynamicFields => 1,
                Silent        => 1,
            );

            if ( ref $TicketData{$FieldName} eq 'ARRAY' ) {
                @Keys = @{ $TicketData{$FieldName} };
            }
            else {
                @Keys = ( $TicketData{$FieldName} || '' );
            }
        }
        else {
            @Keys = $Self->{ParamObject}->GetArray( Param => $FieldName );
        }
    }
    else {
        if ( $TicketID =~ m/^\d+$/ ) {
            my %LinkListKey = $Self->{LinkObject}->LinkKeyList(
                Object1 => 'Ticket',
                Key1    => $TicketID,
                Object2 => 'ITSMConfigItem',
                State   => 'Valid',
                UserID  => $Self->{UserID},
            );

            if ( %LinkListKey ) {
                for my $ItemID ( sort keys %LinkListKey ) {
                    push( @Keys, $ItemID );
                }
            }
        }
    }

    my %CIAttributes = ();

    for my $Config ( sort keys %{ $Self->{SidebarConfig} } ) {
        next if ( $Config !~ m/^ConfigItemAttribute::/ );
        next if ( !$Self->{SidebarConfig}->{$Config} );

        my @FieldData = split( '::', $Config );
        next if ( ( scalar @FieldData ) != 2 );

        $CIAttributes{$FieldData[1]} = 1;
    }

    my $Result = 0;
    KEY:
    for my $Key ( @Keys ) {
        next KEY if (!$Key);

        my $VersionRef = $Self->{ConfigItemObject}->VersionGet(
            ConfigItemID => $Key,
            XMLDataGet   => 1,
        );

        if (
            $VersionRef
            && ref $VersionRef eq 'HASH'
            && $VersionRef->{XMLDefinition}
            && $VersionRef->{XMLData}
            && ref $VersionRef->{XMLDefinition} eq 'ARRAY'
            && ref $VersionRef->{XMLData} eq 'ARRAY'
            && $VersionRef->{XMLData}->[1]
            && ref $VersionRef->{XMLData}->[1] eq 'HASH'
            && $VersionRef->{XMLData}->[1]->{Version}
            && ref $VersionRef->{XMLData}->[1]->{Version} eq 'ARRAY'
        ) {
            if ( !$Result ) {
                $Result = 1;
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarConfigItemViewResult',
                    Data => {
                        Identifier => $Self->{Identifier},
                        %Param,
                    },
                );
            }
            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarConfigItemViewResultPage',
                Data => {
                    Identifier => $Self->{Identifier},
                    %Param,
                },
            );

            if ( $CIAttributes{'Name'} ) {
                # transform ascii to html
                $VersionRef->{Name} = $Self->{LayoutObject}->Ascii2Html(
                    Text           => $VersionRef->{Name},
                    HTMLResultMode => 1,
                    LinkFeature    => 1,
                );

                # output name
                $Self->{LayoutObject}->Block(
                    Name => 'Data',
                    Data => {
                        Name        => 'Name',
                        Description => 'The name of this config item',
                        Value       => $VersionRef->{Name},
                        Indentation  => 6,
                    },
                );
            }

            if ( $CIAttributes{'DeplState'} ) {
                # output deployment state
                $Self->{LayoutObject}->Block(
                    Name => 'Data',
                    Data => {
                        Name        => 'Deployment State',
                        Description => 'The deployment state of this config item',
                        Value       => $Self->{LayoutObject}->{LanguageObject}->Translate(
                            $VersionRef->{DeplState},
                        ),
                        Indentation => 6,
                    },
                );
            }

            if ( $CIAttributes{'InciState'} ) {
                # output incident state
                $Self->{LayoutObject}->Block(
                    Name => 'Data',
                    Data => {
                        Name        => 'Incident State',
                        Description => 'The incident state of this config item',
                        Value       => $Self->{LayoutObject}->{LanguageObject}->Translate(
                            $VersionRef->{InciState},
                        ),
                        Indentation => 6,
                    },
                );
            }

            # start xml output
            $Self->_XMLOutput(
                XMLDefinition        => $VersionRef->{XMLDefinition},
                XMLData              => $VersionRef->{XMLData}->[1]->{Version}->[1],
                ConfigItemAttributes => \%CIAttributes,
            );
        }
    }
    if ( !$Result ) {
        $Self->{LayoutObject}->Block(
            Name => 'NoSearchResult',
            Data => {
                %Param
            },
        );
    }

    # output result
    my $Output = $Self->{LayoutObject}->Output(
        TemplateFile   => 'KIXSidebar/ConfigItemView',
        Data           => \%Param,
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

sub _XMLOutput {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLData};
    return if !$Param{XMLDefinition};
    return if !$Param{ConfigItemAttributes};
    return if ref $Param{XMLData} ne 'HASH';
    return if ref $Param{XMLDefinition} ne 'ARRAY';
    return if ref $Param{ConfigItemAttributes} ne 'HASH';

    $Param{Level} ||= 0;

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # stop loop, if no content was given
            last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            # next, if empty content and ShowEmptyValue is not set
            next COUNTER if !$Self->{SidebarConfig}->{ShowEmptyValue} && !$Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

            if ( $Param{ConfigItemAttributes}->{$Item->{Key}} ) {
                # lookup value
                my $Value = $Self->{ConfigItemObject}->XMLValueLookup(
                    Item  => $Item,
                    Value => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content},
                );

                # create output string
                $Value = $Self->{LayoutObject}->ITSMConfigItemOutputStringCreate(
                    Value => $Value,
                    Item  => $Item,
                    Key   => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
                );

                # calculate indentation for left-padding css based on 15px per level and 10px as default
                my $Indentation = 6;

                if ( $Param{Level} ) {
                    $Indentation += 10 * $Param{Level};
                }

                # output data block
                $Self->{LayoutObject}->Block(
                    Name => 'Data',
                    Data => {
                        Name        => $Item->{Name},
                        Description => $Item->{Description} || $Item->{Name},
                        Value       => $Value,
                        Indentation => $Indentation,
                    },
                );
            }

            # start recursion, if "Sub" was found
            if ( $Item->{Sub} ) {
                $Self->_XMLOutput(
                    XMLDefinition        => $Item->{Sub},
                    XMLData              => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                    Level                => $Param{Level} + 1,
                    ConfigItemAttributes => $Param{ConfigItemAttributes},
                );
            }
        }
    }

    return 1;
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
