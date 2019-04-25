# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarRemoteDBViewAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::KIXSidebarRemoteDBView',
    'Kernel::System::Ticket',
    'Kernel::System::Web::Request'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}                 = $Kernel::OM->Get('Kernel::Config');
    $Self->{LayoutObject}                 = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{KIXSidebarRemoteDBViewObject} = $Kernel::OM->Get('Kernel::System::KIXSidebarRemoteDBView');
    $Self->{TicketObject}                 = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{ParamObject}                  = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{Identifier} = $Self->{ParamObject}->GetParam( Param => 'Identifier' )
        || 'KIXSidebarRemoteDBView';
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

    my $FieldName = 'DynamicField_' . ( $Self->{SidebarConfig}->{'DynamicField'} || '' );

    my $Key      = '';
    my @KeyArray = $Self->{ParamObject}->GetArray( Param => $FieldName );
    if (@KeyArray) {
        $Key = \@KeyArray;
    }

    my $CallingAction = $Self->{ParamObject}->GetParam( Param => 'CallingAction' ) || '';
    my $TicketID      = $Self->{ParamObject}->GetParam( Param => 'TicketID' )      || '';

    my $Frontend  = 'Public';
    if ( $Self->{UserType} eq 'User' ) {
        $Frontend  = 'Agent';
    }
    elsif ( $Self->{UserType} eq 'Customer' ) {
        $Frontend  = 'Customer';
    }

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

        $Key = $TicketData{$FieldName} || '';
    }

    my @DatabaseFields = ();
    my @DatabaseLabels = ();
    my @DatabaseLinks  = ();

    for my $Config ( sort keys %{ $Self->{SidebarConfig} } ) {
        next if ( $Config !~ m/^DatabaseField::/ );

        my @FieldData = split( '::', $Config );
        next if ( ( scalar @FieldData ) < 3 );

        push( @DatabaseFields, $FieldData[2] );
        push( @DatabaseLinks, ( $Self->{SidebarConfig}->{$Config} || '' ) );
        if ( ( scalar @FieldData ) > 3 ) {
            push( @DatabaseLabels, $FieldData[3] );
        }
        else {
            push( @DatabaseLabels, $FieldData[2] );
        }
    }

    my $ResultArray = ();
    if ($Key) {
        $ResultArray = $Self->{KIXSidebarRemoteDBViewObject}->KIXSidebarRemoteDBViewSearch(
            DatabaseDSN               => $Self->{SidebarConfig}->{DatabaseDSN}           || '',
            DatabaseUser              => $Self->{SidebarConfig}->{DatabaseUser}          || '',
            DatabasePw                => $Self->{SidebarConfig}->{DatabasePw}            || '',
            DatabaseCacheTTL          => $Self->{SidebarConfig}->{DatabaseCacheTTL}      || '',
            DatabaseCaseSensitive     => $Self->{SidebarConfig}->{DatabaseCaseSensitive} || '',
            DatabaseTable             => $Self->{SidebarConfig}->{DatabaseTable}         || '',
            DatabaseType              => $Self->{SidebarConfig}->{DatabaseType}          || '',
            DatabaseFieldKey          => $Self->{SidebarConfig}->{DatabaseFieldKey}      || '',
            DatabaseFields            => \@DatabaseFields,
            DynamicFieldArrayHandling => $Self->{SidebarConfig}->{DynamicFieldArrayHandling},
            Key                       => $Key,
            Limit                     => $Self->{SidebarConfig}->{MaxResultCount},
        );
    }

    if ( ref($ResultArray) eq 'ARRAY' && @{$ResultArray} ) {

        $Self->{LayoutObject}->Block(
            Name => 'KIXSidebarRemoteDBViewResult' . $Frontend,
            Data => {
                Identifier => $Self->{Identifier},
                %Param,
            },
        );

        for my $Entry ( @{$ResultArray} ) {
            $Self->{LayoutObject}->Block(
                Name => 'KIXSidebarRemoteDBViewResult' . $Frontend . 'Page',
                Data => {
                    Identifier => $Self->{Identifier},
                    %Param,
                },
            );

            my $MaxResultSize = $Self->{SidebarConfig}->{'MaxResultSize'} || 0;

            for ( my $index = 0; $index < ( scalar @DatabaseFields ); $index++ ) {
                $Self->{LayoutObject}->Block(
                    Name => 'KIXSidebarRemoteDBViewResult' . $Frontend . 'Entry',
                    Data => {
                        Label => $DatabaseLabels[$index],
                    },
                );

                my $Result = $Entry->{ $DatabaseFields[$index] } || '';
                my $ResultShort = $Result;

                if ( $MaxResultSize > 0 ) {
                    $ResultShort = $Self->{LayoutObject}->Ascii2Html(
                        Text => $Result,
                        Max  => $MaxResultSize,
                    );
                }

                my $Link = $DatabaseLinks[$index] || '';

                if ($Link) {

                    if ( $Link =~ /\$Data\{"Key"\}/ ) {
                        my $Replace = $Key;
                        $Link =~ s/\$Data\{"Key"\}/$Replace/g;
                    }
                    if ( $Link =~ /\$QData\{"Key"\}/ ) {
                        my $Replace = $Self->{LayoutObject}->Ascii2Html( Text => $Key );
                        $Link =~ s/\$QData\{"Key"\}/$Replace/g;
                    }
                    if ( $Link =~ /\$LQData\{"Key"\}/ ) {
                        my $Replace = $Self->{LayoutObject}->LinkEncode($Key);
                        $Link =~ s/\$LQData\{"Key"\}/$Replace/g;
                    }
                    if ( $Link =~ /\$Data\{"Value"\}/ ) {
                        my $Replace = $Result;
                        $Link =~ s/\$Data\{"Value"\}/$Replace/g;
                    }
                    if ( $Link =~ /\$QData\{"Value"\}/ ) {
                        my $Replace = $Self->{LayoutObject}->Ascii2Html( Text => $Result );
                        $Link =~ s/\$QData\{"Value"\}/$Replace/g;
                    }
                    if ( $Link =~ /\$LQData\{"Value"\}/ ) {
                        my $Replace = $Self->{LayoutObject}->LinkEncode($Result);
                        $Link =~ s/\$LQData\{"Value"\}/$Replace/g;
                    }

                    $Self->{LayoutObject}->Block(
                        Name => 'KIXSidebarRemoteDBViewResult' . $Frontend . 'EntryLink',
                        Data => {
                            Link  => $Link,
                            Value => $ResultShort,
                            Title => $Result,
                        },
                    );

                }
                else {

                    $Self->{LayoutObject}->Block(
                        Name => 'KIXSidebarRemoteDBViewResult' . $Frontend . 'EntryQuote',
                        Data => {
                            Value => $ResultShort,
                            Title => $Result,
                        },
                    );

                }
            }
        }
    }
    else {
        $Self->{LayoutObject}->Block(
            Name => 'NoSearchResult',
            Data => {
                %Param
            },
        );
    }

    # output result
    my $Output = $Self->{LayoutObject}->Output(
        TemplateFile   => 'KIXSidebar/RemoteDBView',
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
