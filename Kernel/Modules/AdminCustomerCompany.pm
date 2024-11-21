# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminCustomerCompany;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

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

    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $Nav = $ParamObject->GetParam( Param => 'Nav' ) || 0;
    my $NavigationBarType = $Nav eq 'Agent' ? 'Customers' : 'Admin';
    my $Search = $ParamObject->GetParam( Param => 'Search' );
    $Search
        ||= $ConfigObject->Get('AdminCustomerCompany::RunInitialWildcardSearch') ? '*' : '';
    my $LayoutObject          = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    my %GetParam;
    $GetParam{Source} = $ParamObject->GetParam( Param => 'Source' ) || 'CustomerCompany';

    # ------------------------------------------------------------ #
    # change
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Change' ) {
        my $CustomerID = $ParamObject->GetParam( Param => 'CustomerID' ) || '';

        # check needed stuff
        if ( !$CustomerID ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('No CustomerID is given!'),
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        my %Data = $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );

        # check needed stuff
        if ( !%Data ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Invalid CustomerID is given!'),
                Comment => Translatable('Please contact the administrator.'),
            );
        }

        $Data{CustomerCompanyID} = $CustomerID;
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar(
            Type => $NavigationBarType,
        );
        $Self->_Edit(
            Action => 'Change',
            Nav    => $Nav,
            %Data,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminCustomerCompany',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # change action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';
        my %Errors;
        $GetParam{CustomerCompanyID} = $ParamObject->GetParam( Param => 'CustomerCompanyID' );

        for my $Entry ( @{ $ConfigObject->Get( $GetParam{Source} )->{Map} } ) {
            $GetParam{ $Entry->[0] } = $ParamObject->GetParam( Param => $Entry->[0] ) // '';

            # check mandatory fields
            if ( !$GetParam{ $Entry->[0] } && $Entry->[4] ) {
                $Errors{ $Entry->[0] . 'Invalid' } = 'ServerError';
            }
        }

        if ( !defined $GetParam{CustomerID} ) {
            $GetParam{CustomerID} = $ParamObject->GetParam( Param => 'CustomerID' ) || '';
        }

        # check for duplicate entries
        if ( $GetParam{CustomerCompanyID} ne $GetParam{CustomerID} ) {

            # get CustomerCompany list
            my %List = $CustomerCompanyObject->CustomerCompanyList(
                Search => $Param{Search},
                Valid  => 0,
            );

            # check duplicate field
            if ( %List && $List{ $GetParam{CustomerID} } ) {
                $Errors{Duplicate} = 'ServerError';
            }
        }

        # if no errors occurred
        if ( !%Errors ) {

            # update customer company
            my $Update = $CustomerCompanyObject->CustomerCompanyUpdate(
                %GetParam,
                UserID => $Self->{UserID},
            );
            if ($Update) {

                # update preferences
                my %Preferences = ();
                if ( $ConfigObject->Get('CustomerCompanyPreferences') ) {
                    %Preferences = %{ $ConfigObject->Get('CustomerCompanyPreferences') };
                }
                GROUP:
                for my $Group ( sort keys %Preferences ) {
                    # get customer company data
                    my %CompanyData = $CustomerCompanyObject->CustomerCompanyGet(
                        CustomerID => $GetParam{CustomerID}
                    );
                    my $Module = $Preferences{$Group}->{Module};
                    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Module) ) {
                        return $LayoutObject->FatalError();
                    }
                    my $Object = $Module->new(
                        %{$Self},
                        ConfigItem => $Preferences{$Group},
                        Debug      => $Self->{Debug},
                    );
                    my @Params = $Object->Param( CustomerCompanyData => \%CompanyData );
                    if (@Params) {
                        my %GroupParam;
                        for my $ParamItem (@Params) {
                            my @Array = $ParamObject->GetArray( Param => $ParamItem->{Name} );
                            $GroupParam{ $ParamItem->{Name} } = \@Array;
                        }
                        if (
                            !$Object->Run(
                                GetParam            => \%GroupParam,
                                CustomerCompanyData => \%CompanyData
                            )
                        ) {
                            $Note .= $LayoutObject->Notify( Info => $Object->Error() );
                        }
                    }
                }

                # get user data and show screen again
                if ( !$Note ) {
                    $Self->_Overview(
                        Nav    => $Nav,
                        Search => $Search,
                        %GetParam,
                    );
                    my $Output = $LayoutObject->Header();
                    $Output .= $LayoutObject->NavigationBar(
                        Type => $NavigationBarType,
                    );
                    $Output .= $LayoutObject->Notify( Info => Translatable('Customer company updated!') );
                    $Output .= $LayoutObject->Output(
                        TemplateFile => 'AdminCustomerCompany',
                        Data         => \%Param,
                    );
                    $Output .= $LayoutObject->Footer();
                    return $Output;
                }
            }
            else {
                $Note .= $LayoutObject->Notify( Priority => 'Error' );
            }
        }

        # something went wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar(
            Type => $NavigationBarType,
        );

        $Output .= $Note;

        # set notification for duplicate entry
        if ( $Errors{Duplicate} ) {
            $Output .= $LayoutObject->Notify(
                Priority => 'Error',
                Info     => $LayoutObject->{LanguageObject}->Translate(
                    'Customer Company %s already exists!',
                    $GetParam{CustomerID},
                ),
            );
        }

        $Self->_Edit(
            Action => 'Change',
            Nav    => $Nav,
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminCustomerCompany',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' ) {
        $GetParam{Name} = $ParamObject->GetParam( Param => 'Name' );
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar(
            Type => $NavigationBarType,
        );
        $Self->_Edit(
            Action => 'Add',
            Nav    => $Nav,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminCustomerCompany',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';
        my %Errors;

        my $CustomerCompanyKey = $ConfigObject->Get( $GetParam{Source} )->{CustomerCompanyKey};
        my $CustomerCompanyID;

        for my $Entry ( @{ $ConfigObject->Get( $GetParam{Source} )->{Map} } ) {
            $GetParam{ $Entry->[0] } = $ParamObject->GetParam( Param => $Entry->[0] ) // '';

            # check mandatory fields
            if ( !$GetParam{ $Entry->[0] } && $Entry->[4] ) {
                $Errors{ $Entry->[0] . 'Invalid' } = 'ServerError';
            }

            # save customer company key for checking duplicate
            if ( $Entry->[2] eq $CustomerCompanyKey ) {
                $CustomerCompanyID = $GetParam{ $Entry->[0] };
            }
        }

        # get CustomerCompany list
        my %List = $CustomerCompanyObject->CustomerCompanyList(
            Search => $Param{Search},
            Valid  => 0,
        );

        # check duplicate field
        if ( %List && $List{$CustomerCompanyID} ) {
            $Errors{Duplicate} = 'ServerError';
        }

        # if no errors occurred
        if ( !%Errors ) {

            # add customer company
            my $CustomerID = $CustomerCompanyObject->CustomerCompanyAdd(
                %GetParam,
                UserID => $Self->{UserID},
            );

            # add company
            if ($CustomerID) {

                # update preferences
                my %Preferences = ();
                if ( $ConfigObject->Get('CustomerCompanyPreferences') ) {
                    %Preferences = %{ $ConfigObject->Get('CustomerCompanyPreferences') };
                }
                GROUP:
                for my $Group ( sort keys %Preferences ) {
                    # get customer company data
                    my %CompanyData = $CustomerCompanyObject->CustomerCompanyGet(
                        CustomerID => $GetParam{CustomerID}
                    );
                    my $Module = $Preferences{$Group}->{Module};
                    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Module) ) {
                        return $LayoutObject->FatalError();
                    }
                    my $Object = $Module->new(
                        %{$Self},
                        ConfigItem => $Preferences{$Group},
                        Debug      => $Self->{Debug},
                    );
                    my @Params = $Object->Param( CustomerCompanyData => \%CompanyData );
                    if (@Params) {
                        my %GroupParam;
                        for my $ParamItem (@Params) {
                            my @Array = $ParamObject->GetArray( Param => $ParamItem->{Name} );
                            $GroupParam{ $ParamItem->{Name} } = \@Array;
                        }
                        if (
                            !$Object->Run(
                                GetParam            => \%GroupParam,
                                CustomerCompanyData => \%CompanyData
                            )
                        ) {
                            $Note .= $LayoutObject->Notify( Info => $Object->Error() );
                        }
                    }
                }

                # get user data and show screen again
                if ( !$Note ) {
                    $Self->_Overview(
                        Nav    => $Nav,
                        Search => $Search,
                        %GetParam,
                    );
                    my $Output = $LayoutObject->Header();
                    $Output .= $LayoutObject->NavigationBar(
                        Type => $NavigationBarType,
                    );
                    $Output .= $LayoutObject->Notify(
                        Info => Translatable('Customer company added!'),
                    );
                    $Output .= $LayoutObject->Output(
                        TemplateFile => 'AdminCustomerCompany',
                        Data         => \%Param,
                    );
                    $Output .= $LayoutObject->Footer();
                    return $Output;
                }
            }
            else {
                $Note .= $LayoutObject->Notify( Priority => 'Error' );
            }
        }

        # something went wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar(
            Type => $NavigationBarType,
        );

        $Output .= $Note;

        # set notification for duplicate entry
        if ( $Errors{Duplicate} ) {
            $Output .= $LayoutObject->Notify(
                Priority => 'Error',
                Info     => $LayoutObject->{LanguageObject}->Translate(
                    'Customer Company %s already exists!',
                    $CustomerCompanyID,
                ),
            );
        }

        $Self->_Edit(
            Action => 'Add',
            Nav    => $Nav,
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminCustomerCompany',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------
    # overview
    # ------------------------------------------------------------
    else {
        $Self->_Overview(
            Nav    => $Nav,
            Search => $Search,
            %GetParam,
        );
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar(
            Type => $NavigationBarType,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminCustomerCompany',
            Data         => \%Param,
        );

        $Output .= $LayoutObject->Footer();
        return $Output;
    }
}

sub _Edit {
    my ( $Self, %Param ) = @_;

    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    my %CompanyData;

    # get params
    if ( $Param{CustomerCompanyID} ) {
        %CompanyData = $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $Param{CustomerCompanyID},
            UserID     => $Self->{UserID},
        );
    }

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block(
        Name => 'ActionOverview',
        Data => \%Param,
    );

    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => \%Param,
    );

    # shows header
    if ( $Param{Action} eq 'Change' ) {
        $LayoutObject->Block( Name => 'HeaderEdit' );
    }
    else {
        $LayoutObject->Block( Name => 'HeaderAdd' );
    }

    my $ValidObject = $Kernel::OM->Get('Kernel::System::Valid');

    $Param{'ValidOption'} = $LayoutObject->BuildSelection(
        Data       => { $ValidObject->ValidList(), },
        Name       => 'ValidID',
        Class      => 'Modernize',
        SelectedID => $Param{ValidID},
    );

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    for my $Entry ( @{ $ConfigObject->Get( $Param{Source} )->{Map} } ) {
        if ( $Entry->[0] ) {
            my $Block = 'Input';

            # build selections or input fields
            if ( $ConfigObject->Get( $Param{Source} )->{Selections}->{ $Entry->[0] } ) {
                my $OptionRequired = '';
                if ( $Entry->[4] ) {
                    $OptionRequired = 'Validate_Required';
                }

                # build ValidID string
                $Block = 'Option';
                $Param{Option} = $LayoutObject->BuildSelection(
                    Data =>
                        $ConfigObject->Get( $Param{Source} )->{Selections}
                        ->{ $Entry->[0] },
                    Name  => $Entry->[0],
                    Class => "$OptionRequired Modernize " .
                        ( $Param{Errors}->{ $Entry->[0] . 'Invalid' } || '' ),
                    Translation => 0,
                    SelectedID  => $Param{ $Entry->[0] },
                    Max         => 35,
                );

            }
            elsif ( $Entry->[0] =~ /^CustomerCompanyCountry/i ) {
                my $OptionRequired = '';
                if ( $Entry->[4] ) {
                    $OptionRequired = 'Validate_Required';
                }

                # build Country string
                my $CountryList = $Kernel::OM->Get('Kernel::System::ReferenceData')->CountryList();

                $Block = 'Option';
                $Param{Option} = $LayoutObject->BuildSelection(
                    Data         => $CountryList,
                    PossibleNone => 1,
                    Sort         => 'AlphanumericValue',
                    Name         => $Entry->[0],
                    Class        => "$OptionRequired Modernize " .
                        ( $Param{Errors}->{ $Entry->[0] . 'Invalid' } || '' ),
                    SelectedID => defined( $Param{ $Entry->[0] } ) ? $Param{ $Entry->[0] } : 1,
                );
            }
            elsif ( $Entry->[0] =~ /^ValidID/i ) {
                my $OptionRequired = '';
                if ( $Entry->[4] ) {
                    $OptionRequired = 'Validate_Required';
                }

                # build ValidID string
                $Block = 'Option';
                $Param{Option} = $LayoutObject->BuildSelection(
                    Data  => { $ValidObject->ValidList(), },
                    Name  => $Entry->[0],
                    Class => "$OptionRequired Modernize " .
                        ( $Param{Errors}->{ $Entry->[0] . 'Invalid' } || '' ),
                    SelectedID => defined( $Param{ $Entry->[0] } ) ? $Param{ $Entry->[0] } : 1,
                );
            }
            else {
                $Param{Value} = $Param{ $Entry->[0] } || '';
            }

            # show required flag
            if ( $Entry->[4] ) {
                $Param{MandatoryClass} = 'class="Mandatory"';
                $Param{StarLabel}      = '<span class="Marker">*</span>';
                $Param{RequiredClass}  = 'Validate_Required';
            }
            else {
                $Param{MandatoryClass} = '';
                $Param{StarLabel}      = '';
                $Param{RequiredClass}  = '';
            }

            # show required flag
            if ( $Entry->[7] ) {
                $Param{ReadOnlyType} = 'readonly="readonly"';
            }
            else {
                $Param{ReadOnlyType} = '';
            }

            # add form option
            if ( $Param{Type} && $Param{Type} eq 'hidden' ) {
                $Param{Preferences} .= $Param{Value};
            }
            else {
                $LayoutObject->Block(
                    Name => 'PreferencesGeneric',
                    Data => {
                        Item => $Entry->[1],
                        %Param
                    },
                );
                $LayoutObject->Block(
                    Name => "PreferencesGeneric$Block",
                    Data => {
                        %Param,
                        Item         => $Entry->[1],
                        Name         => $Entry->[0],
                        Value        => $Param{ $Entry->[0] },
                        InvalidField => $Param{Errors}->{ $Entry->[0] . 'Invalid' } || '',
                    },
                );
                if ( $Entry->[4] ) {
                    $LayoutObject->Block(
                        Name => "PreferencesGeneric${Block}Required",
                        Data => {
                            Name => $Entry->[0],
                        },
                    );
                }
            }
        }
    }

    # show each preferences setting
    my %Preferences = ();
    if ( $ConfigObject->Get('CustomerCompanyPreferences') ) {
        %Preferences = %{ $ConfigObject->Get('CustomerCompanyPreferences') };
    }
    for my $Item ( sort keys %Preferences ) {
        my $Module = $Preferences{$Item}->{Module}
            || 'Kernel::Output::HTML::CustomerCompanyPreferences::Generic';

        # load module
        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Module) ) {
            return $LayoutObject->FatalError();
        }
        my $Object = $Module->new(
            %{$Self},
            ConfigItem => $Preferences{$Item},
            Debug      => $Self->{Debug},
        );
        my @Params = $Object->Param( CustomerCompanyData => \%CompanyData );
        if (@Params) {
            for my $ParamItem (@Params) {
                $LayoutObject->Block(
                    Name => 'Item',
                    Data => { %Param, },
                );
                if (
                    ref( $ParamItem->{Data} ) eq 'HASH'
                    || ref( $Preferences{$Item}->{Data} ) eq 'HASH'
                ) {
                    my %BuildSelectionParams = (
                        %{ $Preferences{$Item} },
                        %{$ParamItem},
                    );
                    $BuildSelectionParams{Class} = join( ' ', $BuildSelectionParams{Class} // '', 'Modernize' );

                    $ParamItem->{'Option'} = $LayoutObject->BuildSelection(
                        %BuildSelectionParams,
                    );
                }
                $LayoutObject->Block(
                    Name => $ParamItem->{Block} || $Preferences{$Item}->{Block} || 'Option',
                    Data => {
                        %{ $Preferences{$Item} },
                        %{$ParamItem},
                    },
                );
            }
        }
    }
    return 1;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block(
        Name => 'ActionSearch',
        Data => \%Param,
    );

    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    # get writable data sources
    my %CustomerCompanySource = $CustomerCompanyObject->CustomerCompanySourceList(
        ReadOnly => 0,
    );

    # only show Add option if we have at least one writable backend
    if ( scalar keys %CustomerCompanySource ) {
        $Param{SourceOption} = $LayoutObject->BuildSelection(
            Data       => { %CustomerCompanySource, },
            Name       => 'Source',
            SelectedID => $Param{Source} || '',
            Class      => 'Modernize',
        );

        $LayoutObject->Block(
            Name => 'ActionAdd',
            Data => \%Param,
        );
    }

    # if there are any registries to search, the table is filled and shown
    if ( $Param{Search} ) {

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # same Limit as $Self->{CustomerCompanyMap}->{'CustomerCompanySearchListLimit'}
        # smallest Limit from all sources
        my $Limit = 400;
        SOURCE:
        for my $Count ( '', 1 .. 10 ) {
            next SOURCE if !$ConfigObject->Get("CustomerCompany$Count");
            my $CustomerUserMap = $ConfigObject->Get("CustomerCompany$Count");
            next SOURCE if !$CustomerUserMap->{CustomerCompanySearchListLimit};
            if ( $CustomerUserMap->{CustomerCompanySearchListLimit} < $Limit ) {
                $Limit = $CustomerUserMap->{CustomerCompanySearchListLimit};
            }
        }

        my %ListAll = $CustomerCompanyObject->CustomerCompanyList(
            Search => $Param{Search},
            Limit  => $Limit + 1,
            Valid  => 0,
        );

        if ( keys %ListAll <= $Limit ) {
            my $ListAll = keys %ListAll;
            $LayoutObject->Block(
                Name => 'OverviewHeader',
                Data => {
                    ListAll => $ListAll,
                    Limit   => $Limit,
                },
            );
        }

        my %List = $CustomerCompanyObject->CustomerCompanyList(
            Search => $Param{Search},
            Valid  => 0,
        );

        if ( keys %ListAll > $Limit ) {
            my $ListAll        = keys %ListAll;
            my $SearchListSize = keys %List;

            $LayoutObject->Block(
                Name => 'OverviewHeader',
                Data => {
                    SearchListSize => $SearchListSize,
                    ListAll        => $ListAll,
                    Limit          => $Limit,
                },
            );
        }

        $LayoutObject->Block(
            Name => 'OverviewResult',
            Data => \%Param,
        );

        # get valid list
        my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

        if ( !$ConfigObject->Get( $Param{Source} )->{Params}->{ForeignDB} ) {
            $LayoutObject->Block( Name => 'LocalDB' );
        }

        # if there are results to show
        if (%List) {
            for my $ListKey ( sort { $List{$a} cmp $List{$b} } keys %List ) {

                my %Data = $CustomerCompanyObject->CustomerCompanyGet( CustomerID => $ListKey );
                $LayoutObject->Block(
                    Name => 'OverviewResultRow',
                    Data => {
                        %Data,
                        Search => $Param{Search},
                        Nav    => $Param{Nav},
                    },
                );

                if ( !$ConfigObject->Get( $Param{Source} )->{Params}->{ForeignDB} ) {
                    $LayoutObject->Block(
                        Name => 'LocalDBRow',
                        Data => {
                            Valid => $ValidList{ $Data{ValidID} },
                            %Data,
                        },
                    );
                }

            }
        }

        # otherwise it displays a no data found message
        else {
            $LayoutObject->Block(
                Name => 'NoDataFoundMsg',
                Data => {},
            );
        }
    }

    # if there is nothing to search it shows a message
    else
    {
        $LayoutObject->Block(
            Name => 'NoSearchTerms',
            Data => {},
        );
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
