# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Migration::CustomerColumn2DynamicField;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Copy customer database columns to dynamic fields');
    $Self->AddOption(
        Name        => 'copy',
        Description => 'Format "<Table>::<Column>::<Dynamic Field>". Table has to be "customer_user" or "customer_company"',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/^customer_(?:user|company)::.+::[A-Za-z0-9]+$/,
        Multiple    => 1,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get options
    my @CopyList = @{ $Self->GetOption('copy') };

    ENTRY:
    for my $Entry ( @CopyList ) {
        # validate entry and get parameter
        my $EntryParameter = $Self->_GetEntryParameter(
            Entry => $Entry,
        );
        if ( !IsHashRefWithData( $EntryParameter ) ) {
            next ENTRY;
        }

        # process entry
        $Self->_ProcessEntry(
            Entry => $EntryParameter,
        );
    }

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

sub _GetEntryParameter {
    my ( $Self, %Param ) = @_;

    # check param
    if ( !$Param{Entry} ) {
        $Self->PrintError('Got no entry value!' . "\n");

        return;
    }

    # split entry
    my ( $Table, $Column, $DynamicField ) = split( /::/, $Param{Entry}, 3 );

    # check that all entry params are given
    if (
        !$Table
        || !$Column
        || !$DynamicField
    ) {
        $Self->PrintError('Invalid entry format "' . $Param{Entry} . '"!' . "\n");

        return;
    }

    # check for valid table
    if (
        $Table ne 'customer_user'
        && $Table ne 'customer_company'
    ) {
        $Self->PrintError('Invalid table "' . $Table . '"! Only "customer_user" and "customer_company" supported.' . "\n");

        return;
    }

    # check table column
    if (
        !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL   => 'SELECT * FROM ' . $Table,
            Limit => 1
        )
    ) {
        return;
    }
    my @ColumnNames = $Kernel::OM->Get('Kernel::System::DB')->GetColumnNames();
    my %ColumnMap   = map { $_ => 1 } @ColumnNames;
    if ( !$ColumnMap{ $Column } ) {
        $Self->PrintError('Invalid column "' . $Column . '" for table "' . $Table . '"!' . "\n");

        return;
    }

    # check dynamic field
    my $DynamicFieldConfig = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
        Name => $DynamicField,
    );
    if (
        !$DynamicFieldConfig
        || $DynamicFieldConfig->{ValidID} != 1
        || (
            $Table eq 'customer_user'
            && $DynamicFieldConfig->{ObjectType} ne 'CustomerUser'
        )
        || (
            $Table eq 'customer_company'
            && $DynamicFieldConfig->{ObjectType} ne 'CustomerCompany'
        )
    ) {
        $Self->PrintError('Invalid dynamic field "' . $DynamicField . '"!' . "\n");

        return;
    }

    return {
        Table        => $Table,
        Column       => $Column,
        DynamicField => $DynamicFieldConfig,
    }
}

sub _ProcessEntry {
    my ( $Self, %Param ) = @_;

    $Self->Print('<yellow>Copy table "' . $Param{Entry}->{Table} . '", column "' . $Param{Entry}->{Column} . '" to dynamic field "' . $Param{Entry}->{DynamicField}->{Name} . '"</yellow>' . "\n");

    # prepare id column
    my $ColumnID;
    if ( $Param{Entry}->{Table} eq 'customer_user' ) {
        $ColumnID = 'login';
    }
    elsif ( $Param{Entry}->{Table} eq 'customer_company' ) {
        $ColumnID = 'customer_id';
    }

    # prepare sql statement
    if (
        !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL => <<"END",
SELECT $ColumnID, $Param{Entry}->{Column}
FROM $Param{Entry}->{Table}
WHERE $Param{Entry}->{Column} IS NOT NULL
END
        )
    ) {
        return;
    }

    # fetch data from database
    my %Data;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # process data, write to dynamic field
    for my $ObjectID ( keys %Data ) {
        $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->ValueSet(
            DynamicFieldConfig => $Param{Entry}->{DynamicField},
            ObjectID           => $ObjectID,
            Value              => $Data{ $ObjectID },
            UserID             => 1
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
