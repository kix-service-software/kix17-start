# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::TypeReference;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Type'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::TypeReference - xml backend module

=head1 SYNOPSIS

All xml functions of TypeReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeDummyBackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::TypeReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{TypeObject} = $Kernel::OM->Get('Kernel::System::Type');

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

    my %TypeData = $Self->{TypeObject}->TypeGet(
        ID     => $Param{Value},
        UserID => 1,
    );

    my $TypeName = $Param{Value};

    if ( %TypeData && $TypeData{Name} ) {
        $TypeName = $TypeData{Name};
    }

    return $TypeName;
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

    return;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # lookup name for given Type ID
    my %TypeData = $Self->{TypeObject}->TypeGet(
        ID => $Param{Value},
    );
    if ( %TypeData && $TypeData{Name} ) {
        return $TypeData{Name};
    }

    return '';
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # lookup name for given Type ID
    my %TypeData = $Self->{TypeObject}->TypeGet(
        ID => $Param{Value},
    );
    if ( %TypeData && $TypeData{Name} ) {
        return $TypeData{Name};
    }

    return '';
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return '';
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # check if Queue name was given
    my $TypeID = $Self->{TypeObject}->TypeLookup(
        Type => $Param{Value},
    );
    return $TypeID if $TypeID;

    # check if given value is a valid Type ID
    if ( $Param{Value} !~ /\D/ ) {
        my $TypeName = $Self->{TypeObject}->TypeLookup(
            TypeID => $Param{Value},
        );
        return $Param{Value} if $TypeName;
    }

    return '';
}

1;


=head1 VERSION

$Revision$ $Date$

=cut



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
