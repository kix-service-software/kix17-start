# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::KIXBase;

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

# disable redefine warnings in this scope
{
    no warnings 'redefine';

    # overwrite buildselection for added GenericAutoCompleteSearch
    sub Kernel::Output::HTML::Layout::BuildSelection {
        my ( $Self, %Param ) = @_;

        # check needed stuff
        for (qw(Name Data)) {
            if ( !$Param{$_} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
                return;
            }
        }

        # The parameters 'Ajax' and 'OnChange' are exclusive
        if ( $Param{Ajax} && $Param{OnChange} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "The parameters 'OnChange' and 'Ajax' exclude each other!"
            );
            return;
        }

        # KIX4OTRS-capeIT
        if (
            (
                $Kernel::OM->Get('Kernel::Config')->Get('Ticket::TypeTranslation')
                && ( $Param{Name} eq 'TypeID' || $Param{Name} eq 'TypeIDs' )
            ) ||
            (
                $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ServiceTranslation')
                && ( $Param{Name} eq 'ServiceID' || $Param{Name} eq 'ServiceIDs' )
            ) ||
            (
                $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SLATranslation')
                && ( $Param{Name} eq 'SLAID' || $Param{Name} eq 'SLAIDs' )
            )
            )
        {
            $Param{Translation} = 1;
        }

        # EO KIX4OTRS-capeIT

        # set OnChange if AJAX is used
        if ( $Param{Ajax} ) {
            if ( !$Param{Ajax}->{Depend} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'Need Depend Param Ajax option!',
                );
                $Self->FatalError();
            }
            if ( !$Param{Ajax}->{Update} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => 'Need Update Param Ajax option()!',
                );
                $Self->FatalError();
            }
            my $Selector = $Param{ID} || $Param{Name};
            $Param{OnChange} = "Core.AJAX.FormUpdate(\$('#"
                . $Selector . "'), '" . $Param{Ajax}->{Subaction} . "',"
                . " '$Param{Name}',"
                . " ['"
                . join( "', '", @{ $Param{Ajax}->{Update} } ) . "']);";
        }

        # create OptionRef
        my $OptionRef = $Self->_BuildSelectionOptionRefCreate(%Param);

        # create AttributeRef
        my $AttributeRef = $Self->_BuildSelectionAttributeRefCreate(%Param);

        # create DataRef
        my $DataRef = $Self->_BuildSelectionDataRefCreate(
            Data         => $Param{Data},
            AttributeRef => $AttributeRef,
            OptionRef    => $OptionRef,
        );

        # create FiltersRef
        my @Filters;
        my $FilterActive;
        if ( $Param{Filters} ) {
            my $Index = 1;
            for my $Filter ( sort keys %{ $Param{Filters} } ) {
                if (
                    $Param{Filters}->{$Filter}->{Name}
                    && $Param{Filters}->{$Filter}->{Values}
                    )
                {
                    my $FilterData = $Self->_BuildSelectionDataRefCreate(
                        Data         => $Param{Filters}->{$Filter}->{Values},
                        AttributeRef => $AttributeRef,
                        OptionRef    => $OptionRef,
                    );
                    push @Filters, {
                        Name => $Param{Filters}->{$Filter}->{Name},
                        Data => $FilterData,
                    };
                    if ( $Param{Filters}->{$Filter}->{Active} ) {
                        $FilterActive = $Index;
                    }
                }
                else {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => 'Each Filter must provide Name and Values!',
                    );
                    $Self->FatalError();
                }
                $Index++;
            }
            @Filters = sort { $a->{Name} cmp $b->{Name} } @Filters;
        }

        # KIX4OTRS-capeIT
        # get disabled selections
        if ( defined $Param{DisabledOptions} && ref $Param{DisabledOptions} eq 'HASH' ) {
            my $DisabledOptions = $Param{DisabledOptions};
            for my $Item ( keys %{ $Param{DisabledOptions} } ) {
                my $ItemValue = $Param{DisabledOptions}->{$Item};
                my @ItemArray = split( '::', $ItemValue );
                for ( my $Index = 0; $Index < scalar @{$DataRef}; $Index++ ) {
                    next
                        if (
                        $DataRef->[$Index]->{Value} !~ m/$ItemArray[-1]$/
                        || $DataRef->[$Index]->{Key} ne $Item
                        );
                    $DataRef->[$Index]->{Disabled} = 1;
                }
            }
        }

        # get UserPreferences
        if (
            ref $Kernel::OM->Get('Kernel::Config')
            ->Get('Ticket::Frontend::GenericAutoCompleteSearch') eq 'HASH'
            && defined $Self->{UserID}
            && $Self->{Action} !~ /^Customer/
            )
        {
            my $AutoCompleteConfig
                = $Kernel::OM->Get('Kernel::Config')
                ->Get('Ticket::Frontend::GenericAutoCompleteSearch');
            my %UserPreferences = $Kernel::OM->Get('Kernel::System::User')
                ->GetPreferences( UserID => $Self->{UserID} );

            my $SearchType;

            my $SearchTypeMappingKey;
            if ( $Self->{Action} && $Param{Name} ) {
                $SearchTypeMappingKey = $Self->{Action} . ":::" . $Param{Name};
            }

            if (
                $SearchTypeMappingKey
                && defined $AutoCompleteConfig->{SearchTypeMapping}->{$SearchTypeMappingKey}
                )
            {
                $SearchType = $AutoCompleteConfig->{SearchTypeMapping}->{$SearchTypeMappingKey};
            }

            # create string for autocomplete
            if (
                $SearchType
                && $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' }
                && $UserPreferences{ 'User' . $SearchType . 'SelectionStyle' } eq 'AutoComplete'
                )
            {
                my $AutoCompleteString
                    = '<input id="'
                    . $Param{Name}
                    . '" type="hidden" name="'
                    . $Param{Name}
                    . '" value=""/>'
                    . '<input id="'
                    . $Param{Name}
                    . 'autocomplete" type="text" name="'
                    . $Param{Name}
                    . 'autocomplete" value="" class=" W75pc AutocompleteOff Validate_Required"/>';

                $Self->AddJSOnDocumentComplete( Code => <<"EOF");
    Core.Config.Set("GenericAutoCompleteSearch.MinQueryLength",$AutoCompleteConfig->{MinQueryLength});
    Core.Config.Set("GenericAutoCompleteSearch.QueryDelay",$AutoCompleteConfig->{QueryDelay});
    Core.Config.Set("GenericAutoCompleteSearch.MaxResultsDisplayed",$AutoCompleteConfig->{MaxResultsDisplayed});
    Core.KIX4OTRS.GenericAutoCompleteSearch.Init(\$("#$Param{Name}autocomplete"),\$("#$Param{Name}"));
EOF
                return $AutoCompleteString;
            }
        }

        # EO KIX4OTRS-capeIT
        # generate output
        my $String = $Self->_BuildSelectionOutput(
            AttributeRef  => $AttributeRef,
            DataRef       => $DataRef,
            OptionTitle   => $Param{OptionTitle},
            TreeView      => $Param{TreeView},
            FiltersRef    => \@Filters,
            FilterActive  => $FilterActive,
            ExpandFilters => $Param{ExpandFilters},

            # KIX4OTRS-capeIT
            DisabledOptions => $Param{DisabledOptions},

            # EO KIX4OTRS-capeIT
        );
        return $String;
    }

    sub Kernel::Output::HTML::Layout::BuildSelectionJSON {
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

            # KIX4OTRS-capeIT
            if (
                (
                    $Kernel::OM->Get('Kernel::Config')->Get('Ticket::TypeTranslation')
                    && ( $Param{Name} eq 'TypeID' || $Param{Name} eq 'TypeIDs' )
                ) ||
                (
                    $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ServiceTranslation')
                    && ( $Param{Name} eq 'ServiceID' || $Param{Name} eq 'ServiceIDs' )
                ) ||
                (
                    $Kernel::OM->Get('Kernel::Config')->Get('Ticket::SLATranslation')
                    && ( $Param{Name} eq 'SLAID' || $Param{Name} eq 'SLAIDs' )
                )
                )
            {
                $Param{Translation} = 1;
            }

            my $Disabled = 0;
            my $DisabledOptions;
            if ( defined $Param{DisabledOptions} && ref $Param{DisabledOptions} eq 'HASH' ) {
                $Disabled        = 1;
                $DisabledOptions = $Param{DisabledOptions};
            }

            # EO KIX4OTRS-capeIT

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
            elsif ( ref $Param{Data} eq '' ) {

                # KIX4OTRS-capeIT
                if ( defined $Param{FieldDisabled} && $Param{FieldDisabled} ) {
                    my @DataArray;
                    push @DataArray, $Param{Data};
                    push @DataArray, Kernel::System::JSON::False();
                    $DataHash{ $Param{Name} } = \@DataArray;
                }
                else {
                    $DataHash{ $Param{Name} } = $Param{Data};
                }

                # EO KIX4OTRS-capeIT
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

                      # KIX4OTRS-capeIT
                      # to set a disabled option (Disabled is not included in JavaScript New Option)
                      # my $Disabled = Kernel::System::JSON::False();
                        my $DisabledOption = Kernel::System::JSON::False();

                        # EO KIX4OTRS-capeIT
                        if ( $Row->{Selected} ) {
                            $DefaultSelected = Kernel::System::JSON::True();
                        }
                        elsif ( $Row->{Disabled} ) {
                            $DefaultSelected = Kernel::System::JSON::False();

                            # KIX4OTRS-capeIT
                            # $Disabled        = Kernel::System::JSON::True();
                            $DisabledOption = Kernel::System::JSON::True();

                            # EO KIX4OTRS-capeIT
                        }

                        if ($Disabled) {
                            if ( $DisabledOptions->{$Key} ) {
                                $DisabledOption = Kernel::System::JSON::True();
                            }
                        }

                        # Selected parameter for JavaScript NewOption
                        my $Selected = $DefaultSelected;
                        push @DataArray,
                            [ $Key, $Value, $DefaultSelected, $Selected, $DisabledOption ];
                    }

                    # KIX4OTRS-capeIT
                    if ( defined $Param{FieldDisabled} && $Param{FieldDisabled} ) {
                        push @DataArray, Kernel::System::JSON::False();
                    }

                    # EO KIX4OTRS-capeIT
                    $DataHash{ $AttributeRef->{name} } = \@DataArray;
                }
            }
        }

        return $Self->JSONEncode(
            Data => \%DataHash,
        );
    }

    # reset all warnings
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
