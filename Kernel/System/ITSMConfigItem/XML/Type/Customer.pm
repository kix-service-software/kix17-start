# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Customer;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::Customer - xml backend module

=head1 SYNOPSIS

All xml functions of customer objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeCustomerBackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::Customer');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

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

    my %CustomerSearchList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
        UserLogin => $Param{Value},
        Valid     => 0,
    );

    return $CustomerSearchList{ $Param{Value} } || $Param{Value};
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # create attribute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
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

    return if !defined $Param{Value};
    return $Param{Value};
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
    return $Param{Value};
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
