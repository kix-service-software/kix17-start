# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::CIACCustomerCompany;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CustomerCompany',
    'Kernel::System::Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::CIACCustomerCompany - xml backend module

=head1 SYNOPSIS

All xml functions of CIACCustomerCompany objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::CIACCustomerCompany');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}          = $Kernel::OM->Get('Kernel::Config');
    $Self->{CustomerCompanyObject} = $Kernel::OM->Get('Kernel::System::CustomerCompany');
    $Self->{LogObject}             = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11, # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return '' if !$Param{Value};

    my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
        CustomerID => $Param{Value},
    );

    my $CustomerCompanyDataStr = '';
    my $CustCompanyMapRef =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::CompanyBackendMapping');

    if ( $CustCompanyMapRef && ref($CustCompanyMapRef) eq 'HASH' ) {

        for my $MappingField ( sort( keys( %{$CustCompanyMapRef} ) ) ) {
            if ( $CustomerCompanySearchList{ $CustCompanyMapRef->{$MappingField} } ) {
                $CustomerCompanyDataStr .= ' '
                    . $CustomerCompanySearchList{ $CustCompanyMapRef->{$MappingField} };
            }
        }

    }

    $CustomerCompanyDataStr =~ s/\s+$//g;
    $CustomerCompanyDataStr =~ s/^\s+//g;

    return $CustomerCompanyDataStr;
}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => $Param{Key},
            Block            => 'InputField',
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # check what should be exported: CustomerID or CustomerCompanyName
    my $CustCompanyContent =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::CustomerCompany::Content');

    return $Param{Value} if ( !$CustCompanyContent || ( $CustCompanyContent eq 'CustomerID' ) );

    # get CustomerCompany data
    my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
        CustomerID => $Param{Value},
    );

    # get company name
    my $CustomerCompanyDataStr = $CustomerCompanySearchList{CustomerCompanyName};

    $CustomerCompanyDataStr =~ s/\s+$//g;
    $CustomerCompanyDataStr =~ s/^\s+//g;

    # return company name
    return $CustomerCompanyDataStr;
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # search for name....
    my %CustomerCompanyList = $Self->{CustomerCompanyObject}->CustomerCompanyList(
        Search => '*' . $Param{Value} . '*',
    );

    if (
        %CustomerCompanyList
        && ( scalar( keys %CustomerCompanyList ) == 1 )
    ) {
        my @Result = keys %CustomerCompanyList;
        return $Result[0];
    }

    return $Param{Value};
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # check if content is CustomerID or CustomerCompanyName
    my $CustCompanyContent =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::CustomerCompany::Content');

    return $Param{Value} if ( !$CustCompanyContent );

    my $CustomerCompanyDataStr = '';

    if ( $CustCompanyContent eq 'CustomerID' && $Param{Value} ne '' ) {
        # check if it is a valid CustomerID
        my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
            CustomerID => $Param{Value},
        );

        if (%CustomerCompanySearchList) {
            $CustomerCompanyDataStr = $Param{Value};
        }
    }
    elsif ( $CustCompanyContent eq 'CustomerCompanyName' && $Param{Value} ne '') {

        # search for CustomerCompany data
        my %CustomerCompanySearchList = $Self->{CustomerCompanyObject}->CustomerCompanyList(
            Search => $Param{Value},
            Limit  => 500,
        );

        # check each found CustomerCompany
        if (%CustomerCompanySearchList) {
            foreach my $CustomerID ( keys(%CustomerCompanySearchList) ) {

                my %CustomerCompanyData = $Self->{CustomerCompanyObject}->CustomerCompanyGet(
                    CustomerID => $CustomerID,
                );

                # if CustomerCompanyName matches - use this CudtomerID and stop searching
                if ( $CustomerCompanyData{CustomerCompanyName} eq $Param{Value} ) {
                    $CustomerCompanyDataStr = $CustomerCompanyData{CustomerID};
                    last;
                }
            }
        }
    }

    # warning if no dada found for the given CustomerID or CustomerCompanyName
    if ( !$CustomerCompanyDataStr ) {
        $Self->{LogObject}->Log(
            Priority => 'warning',
            Message =>
                "Could not import CustomerUserCompany: no CustomerID found for CustomerCompanyName $Param{Value}!"
        );
        return $Param{Value};
    }

    $CustomerCompanyDataStr =~ s/\s+$//g;
    $CustomerCompanyDataStr =~ s/^\s+//g;

    return $CustomerCompanyDataStr;
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
