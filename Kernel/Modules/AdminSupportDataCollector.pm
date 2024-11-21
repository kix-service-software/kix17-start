# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminSupportDataCollector;

use strict;
use warnings;

use Kernel::System::SupportDataCollector::PluginBase;

use Kernel::System::VariableCheck qw(:all);

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

    return $Self->_SupportDataCollectorView(%Param);
}

sub _SupportDataCollectorView {
    my ( $Self, %Param ) = @_;

    my %SupportData = $Kernel::OM->Get('Kernel::System::SupportDataCollector')->Collect(
        UseCache => 1,
    );

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    if ( !$SupportData{Success} ) {
        $LayoutObject->Block(
            Name => 'SupportDataCollectionFailed',
            Data => \%SupportData,
        );
    }
    else {
        $LayoutObject->Block(
            Name => 'SupportData',
        );
        my ( $LastGroup, $LastSubGroup ) = ( '', '' );

        for my $Entry ( @{ $SupportData{Result} || [] } ) {

            $Entry->{StatusName} = $Kernel::System::SupportDataCollector::PluginBase::Status2Name{
                $Entry->{Status}
            };

            # get the display path, display type and additional information for the output
            my ( $DisplayPath, $DisplayType, $DisplayAdditional ) = split( m{[\@\:]}, $Entry->{DisplayPath} // '' );

            my ( $Group, $SubGroup ) = split( m{/}, $DisplayPath );
            if ( $Group ne $LastGroup ) {
                $LayoutObject->Block(
                    Name => 'SupportDataGroup',
                    Data => {
                        Group => $Group,
                    },
                );
            }
            $LastGroup = $Group // '';

            if ( !$SubGroup || $SubGroup ne $LastSubGroup ) {

                $LayoutObject->Block(
                    Name => 'SupportDataRow',
                    Data => $Entry,
                );
            }

            if ( $SubGroup && $SubGroup ne $LastSubGroup ) {

                $LayoutObject->Block(
                    Name => 'SupportDataSubGroup',
                    Data => {
                        %{$Entry},
                        SubGroup => $SubGroup,
                    },
                );
            }
            $LastSubGroup = $SubGroup // '';

            if ( $DisplayType && $DisplayType eq 'Table' && ref $Entry->{Value} eq 'ARRAY' ) {

                $LayoutObject->Block(
                    Name => 'SupportDataEntryTable',
                    Data => $Entry,
                );

                if ( IsArrayRefWithData( $Entry->{Value} ) ) {

                    # get the table columns
                    my @TableColumns = split( m{,}, $DisplayAdditional // '' );

                    my @Identifiers;
                    my @Labels;

                    COLUMN:
                    for my $Column (@TableColumns) {

                        next COLUMN if !$Column;

                        # get the identifier and label
                        my ( $Identifier, $Label ) = split( m{\|}, $Column );

                        # set the identifier as default label
                        $Label ||= $Identifier;

                        push @Identifiers, $Identifier;
                        push @Labels,      $Label;
                    }

                    $LayoutObject->Block(
                        Name => 'SupportDataEntryTableDetails',
                        Data => {
                            Identifiers => \@Identifiers,
                            Labels      => \@Labels,
                            %{$Entry},
                        },
                    );
                }
            }
            elsif ( !$SubGroup ) {

                $LayoutObject->Block(
                    Name => 'SupportDataEntry',
                    Data => $Entry,
                );
                if ( defined $Entry->{Value} && length $Entry->{Value} ) {
                    if ( $Entry->{Value} =~ m{\n} ) {
                        $LayoutObject->Block(
                            Name => 'SupportDataEntryValueMultiLine',
                            Data => $Entry,
                        );
                    }
                    else {
                        $LayoutObject->Block(
                            Name => 'SupportDataEntryValueSingleLine',
                            Data => $Entry,
                        );
                    }
                }
            }
            else {

                $LayoutObject->Block(
                    Name => 'SupportDataSubEntry',
                    Data => $Entry,
                );

                if ( $Entry->{Message} ) {
                    $LayoutObject->Block(
                        Name => 'SupportDataSubEntryMessage',
                        Data => {
                            Message => $Entry->{Message},
                        },
                    );
                }
            }
        }
    }

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminSupportDataCollector',
        Data         => \%Param,
    );
    $Output .= $LayoutObject->Footer();

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
