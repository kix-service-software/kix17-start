# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutCIACCustomerCompany;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::CustomerCompany',
    'Kernel::System::Log',
    'Kernel::System::Web::Request'
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItemLayoutCustomerCompany - layout backend module

=head1 SYNOPSIS

All layout functions of CIACCustomerCompany objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::Output::HTML::ITSMConfigItemLayoutCIACCustomerCompany');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}          = $Kernel::OM->Get('Kernel::Config');
    $Self->{LanguageObject}        = $Kernel::OM->Get('Kernel::Language');
    $Self->{LayoutObject}          = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{CustomerCompanyObject} = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    $Self->{LogObject}             = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ParamObject}           = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

=item OutputStringCreate()

create output string

    my $Value = $BackendObject->OutputStringCreate(
        Value => 11,       # (optional)
    );

=cut

sub OutputStringCreate {
    my ( $Self, %Param ) = @_;

    # transform ascii to html
    $Param{Value} = $Self->{LayoutObject}->Ascii2Html(
        Text => $Param{Value} || '',
        HTMLResultMode => 1,
    );

    return $Param{Value};
}

=item FormDataGet()

get form data as hash reference

    my $FormDataRef = $BackendObject->FormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub FormDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    my %FormData;

    # get selected CustomerCompany
    $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} );

    # check search button
    if ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonSearch' ) ) {
        $Param{Item}->{Form}->{ $Param{Key} }->{Search}
            = $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Search' );
    }

    # check select button
    elsif ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonSelect' ) ) {
        $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Select' );
    }

    # check clear button
    elsif ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonClear' ) ) {
        $FormData{Value} = '';
    }
    else {

        # reset value if search field is emty
        if (
            !$Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Search' )
            && defined $FormData{Value}
        ) {
            $FormData{Value} = '';
        }

        # check required option
        if ( $Param{Item}->{Input}->{Required} && !$FormData{Value} ) {
            $Param{Item}->{Form}->{ $Param{Key} }->{Invalid} = 1;
            $FormData{Invalid} = 1;
        }
    }

    return \%FormData;
}

=item InputCreate()

create a input string

    my $Value = $BackendObject->InputCreate(
        Key => 'Item::1::Node::3',
        Value => 11,       # (optional)
        Item => $ItemRef,
    );

=cut

sub InputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    my $Value = '';
    if ( defined $Param{Value} ) {
        $Value = $Param{Value};
    }
    elsif ( $Param{Item}->{Input}->{ValueDefault} ) {
        $Value = $Param{Item}->{Input}->{ValueDefault};
    }
    my $Size         = $Param{Item}->{Input}->{Size} || 50;
    my $Search       = '';
    my $StringOption = '';
    my $StringSelect = '';
    my $Class        = 'W50pc CustomerCompanySearch';
    my $Required     = $Param{Required} || '';
    my $Invalid      = $Param{Invalid} || '';
    my $ItemId       = $Param{ItemId} || '';

    if ($Required) {
        $Class .= ' Validate_Required';
    }

    if ($Invalid) {
        $Class .= ' ServerError';
    }

    # CustomerCompany search
    if ( $Param{Item}->{Form}->{ $Param{Key} }->{Search} ) {
        my @SearchArray = split( ' ', $Param{Item}->{Form}->{ $Param{Key} }->{Search} );
        my $SearchString = join( '+', @SearchArray );

        # start search
        my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyList(
            Search => '*' . $SearchString . '*',
        );

        if ( %CustomerCompanySearchList && scalar( keys %CustomerCompanySearchList ) > 1 ) {

            # create option list
            $StringOption = $Self->{LayoutObject}->BuildSelection(
                Name => $Param{Key} . '::Select',
                Data => \%CustomerCompanySearchList,
            );
            $StringOption .= '<br>';

            # create select button
            $StringSelect = '<input class="button" type="submit" name="'
                . $Param{Key}
                . '::ButtonSelect" '
                . 'value="'
                . $Self->{LanguageObject}->Translate( "Select" )
                . '">&nbsp;';

            # set search
            $Search = $Param{Item}->{Form}->{ $Param{Key} }->{Search};
        }
        elsif (%CustomerCompanySearchList) {

            # get CustomerCompany data
            $Value = ( keys %CustomerCompanySearchList )[0];
            my %CustomerCompanyData = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
                CustomerID => $Value,
            );

            my $CustCompanyMapRef = $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::CompanyBackendMapping');

            if ( $CustCompanyMapRef && ref($CustCompanyMapRef) eq 'HASH' ) {

                for my $MappingField ( sort( keys( %{$CustCompanyMapRef} ) ) ) {
                    if ( $CustomerCompanyData{ $CustCompanyMapRef->{$MappingField} } ) {
                        $Search .= ' '
                            . $CustomerCompanyData{ $CustCompanyMapRef->{$MappingField} };
                    }
                }
            }

            $Search =~ s/\s+$//g;
            $Search =~ s/^\s+//g;

        }
    }

    # create CustomerCompany string
    elsif ($Value) {

        # get CustomerCompany data
        my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
            CustomerID => $Value,
        );

        my $CustCompanyMapRef =
            $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::CompanyBackendMapping');

        if ( $CustCompanyMapRef && ref($CustCompanyMapRef) eq 'HASH' ) {

            for my $MappingField ( sort( keys( %{$CustCompanyMapRef} ) ) ) {
                if ( $CustomerCompanySearchList{ $CustCompanyMapRef->{$MappingField} } ) {
                    $Search .= ' '
                        . $CustomerCompanySearchList{ $CustCompanyMapRef->{$MappingField} };
                }
            }

        }

        $Search =~ s/\s+$//g;
        $Search =~ s/^\s+//g;

    }

    # AutoComplete CIClass
    my $AutoCompleteConfig = $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Frontend::CommonSearchAutoComplete');

    #create string...
    my $String = '';
    if (
        $AutoCompleteConfig
        && ref($AutoCompleteConfig) eq 'HASH'
        && $AutoCompleteConfig->{Active}
    ) {

        $Self->{LayoutObject}->Block(
            Name => 'CustomerCompanySearchAutoComplete',
            Data => {
                minQueryLength      => $AutoCompleteConfig->{MinQueryLength}      || 2,
                queryDelay          => $AutoCompleteConfig->{QueryDelay}          || 0.1,
                maxResultsDisplayed => $AutoCompleteConfig->{MaxResultsDisplayed} || 20,
                dynamicWidth        => $AutoCompleteConfig->{DynamicWidth}        || 1,
            },
        );
        $Self->{LayoutObject}->Block(
            Name => 'CustomerCompanySearchInit',
            Data => {
                ItemID             => $ItemId,
                ActiveAutoComplete => 'true',
                }
        );

        $String = $Self->{LayoutObject}->Output(
            TemplateFile => 'AgentCustomerCompanySearch',
        );
        $String .= '<input type="hidden" name="'
            . $Param{Key}
            . '" value="'
            . $Value
            . '" id="'
            . $ItemId . 'Selected'
            . '"/>'
            . '<input type="text" name="'
            . $Param{Key}
            . '::Search" class="'
            . $Class
            . '" id="'
            . $ItemId
            . '" SearchClass="'
            . 'CustomerCompanySearch'
            . '" value="'
            . $Search . '"/>';
    }
    else {
        $String
            = '<input type="hidden" name="'
            . $Param{Key}
            . '" value="'
            . $Value . '">'
            . '<input type="Text" name="'
            . $Param{Key}
            . '::Search" size="'
            . $Size
            . '" value="'
            . $Search . '">' . '<br>'
            . $StringOption
            . $StringSelect
            . '<input class="button" type="submit" name="'
            . $Param{Key}
            . '::ButtonSearch" value="'
            . $Self->{LanguageObject}->Translate( "Search" )
            . '">'
            . '&nbsp;'
            . '<input class="button" type="submit" name="'
            . $Param{Key}
            . '::ButtonClear" value="'
            . $Self->{LanguageObject}->Translate( "Clear" )
            . '">';
    }

    return $String;
}

=item SearchFormDataGet()

get search form data

    my $Value = $BackendObject->SearchFormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchFormDataGet {
    my ( $Self, %Param ) = @_;

    #check needed stuff
    if ( !$Param{Key} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Key!'
        );
        return;
    }

    # get form data
    my $Value;
    if ( $Param{Value} ) {
        $Value = $Param{Value};
    }
    else {
        $Value = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Param{Key} );
    }

    return $Value;
}

=item SearchInputCreate()

create a search input string

    my $Value = $BackendObject->SearchInputCreate(
        Key => 'Item::1::Node::3',
    );

=cut

sub SearchInputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # hash with values for the input field
    my %FormData;

    if ( $Param{Value} ) {
        $FormData{Value} = $Param{Value};
    }

    # create input field
    my $InputString = $Self->InputCreate(
        %FormData,
        Key    => $Param{Key},
        Item   => $Param{Item},
        ItemId => $Param{Key},
    );

    return $InputString;
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
