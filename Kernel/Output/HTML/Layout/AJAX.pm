# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::AJAX;

use strict;
use warnings;

use Kernel::System::JSON ();

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Output::HTML::Layout::AJAX - all AJAX-related HTML functions

=head1 SYNOPSIS

All AJAX-related HTML functions

=head1 PUBLIC INTERFACE

=over 4

=item BuildSelectionJSON()

build a JSON output js witch can be used for e. g. data for pull downs

    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            Data          => $ArrayRef,      # use $HashRef, $ArrayRef or $ArrayHashRef (see below)
            Name          => 'TheName',      # name of element
            SelectedID    => [1, 5, 3],      # (optional) use integer or arrayref (unable to use with ArrayHashRef)
            SelectedValue => 'test',         # (optional) use string or arrayref (unable to use with ArrayHashRef)
            Sort          => 'NumericValue', # (optional) (AlphanumericValue|NumericValue|AlphanumericKey|NumericKey|TreeView) unable to use with ArrayHashRef
            SortReverse   => 0,              # (optional) reverse the list
            Translation   => 1,              # (optional) default 1 (0|1) translate value
            PossibleNone  => 0,              # (optional) default 0 (0|1) add a leading empty selection
            Max => 100,                      # (optional) default 100 max size of the shown value
        ],
        [
            # ...
        ]
    );

=cut

sub BuildSelectionJSON {
    my ( $Self, $Array ) = @_;
    my %DataHash;

    for my $Data ( @{$Array} ) {
        my %Param = %{$Data};

        # log object
        my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

        # check needed stuff
        for (qw(Name)) {
            if ( !defined $Param{$_} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
                return;
            }
        }

        if (
            (
                $Kernel::OM->Get('Kernel::Config')->Get('Ticket::TypeTranslation')
                && ( $Param{Name} eq 'TypeID' || $Param{Name} eq 'TypeIDs' )
            )
            || (
                $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ServiceTranslation')
                && ( $Param{Name} eq 'ServiceID' || $Param{Name} eq 'ServiceIDs' )
            )
            || (
                $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SLATranslation')
                && ( $Param{Name} eq 'SLAID' || $Param{Name} eq 'SLAIDs' )
            )
        ) {
            $Param{Translation} = 1;
        }

        my $Disabled = 0;
        my $DisabledOptions;
        if (
            defined( $Param{DisabledOptions} )
            && ref( $Param{DisabledOptions} ) eq 'HASH'
        ) {
            $Disabled        = 1;
            $DisabledOptions = $Param{DisabledOptions};
        }

        if ( !defined( $Param{Data} ) ) {
            if ( !$Param{PossibleNone} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Need Data!"
                );
                return;
            }
            $DataHash{''} = '-';
        }
        elsif ( ref( $Param{Data} ) eq '' ) {

            if ( defined $Param{FieldDisabled} && $Param{FieldDisabled} ) {
                my @DataArray;
                push @DataArray, $Param{Data};
                push @DataArray, Kernel::System::JSON::False();
                $DataHash{ $Param{Name} } = \@DataArray;
            }
            else {
                $DataHash{ $Param{Name} } = $Param{Data};
            }
        }
        elsif ( defined $Param{KeepData} && $Param{KeepData} ) {
            $DataHash{ $Param{Name} } = $Param{Data};
        }
        else {

            # create OptionRef
            my $OptionRef = $Self->_BuildSelectionOptionRefCreate(
                %Param,
                HTMLQuote => 0,
            );

            # create AttributeRef
            my $AttributeRef = $Self->_BuildSelectionAttributeRefCreate(%Param);

            # create DataRef
            my $DataRef = $Self->_BuildSelectionDataRefCreate(
                Data         => $Param{Data},
                AttributeRef => $AttributeRef,
                OptionRef    => $OptionRef,
            );

            # create data structure
            if ( $AttributeRef && $DataRef ) {
                my @DataArray;
                for my $Row ( @{$DataRef} ) {
                    my $Key = '';
                    if ( defined $Row->{Key} ) {
                        $Key = $Row->{Key};
                    }
                    my $Value = '';
                    if ( defined $Row->{Value} ) {
                        $Value = $Row->{Value};
                    }

                    # DefaultSelected parameter for JavaScript New Option
                    my $DefaultSelected = Kernel::System::JSON::False();

                    # to set a disabled option (Disabled is not included in JavaScript New Option)
                    my $DisabledOption = Kernel::System::JSON::False();

                    if ( $Row->{Selected} ) {
                        $DefaultSelected = Kernel::System::JSON::True();
                    }
                    elsif ( $Row->{Disabled} ) {
                        $DefaultSelected = Kernel::System::JSON::False();
                        $DisabledOption  = Kernel::System::JSON::True();
                    }

                    if ($Disabled) {
                        if ( $DisabledOptions->{$Key} ) {
                            $DisabledOption = Kernel::System::JSON::True();
                        }
                    }

                    # Selected parameter for JavaScript NewOption
                    my $Selected = $DefaultSelected;
                    push( @DataArray, [ $Key, $Value, $DefaultSelected, $Selected, $DisabledOption ] );
                }

                if ( defined $Param{FieldDisabled} && $Param{FieldDisabled} ) {
                    push @DataArray, Kernel::System::JSON::False();
                }

                $DataHash{ $AttributeRef->{name} } = \@DataArray;
            }
        }
    }

    return $Self->JSONEncode(
        Data => \%DataHash,
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
