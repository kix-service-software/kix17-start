# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::ConfigItemOverviewColumn;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    my @Params = ();

    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $UserObject           = $Kernel::OM->Get('Kernel::System::User');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $SelectedColumnsStrg = $ParamObject->GetParam( Param => 'SelectedColumns' );
    my $CallingAction       = $ParamObject->GetParam( Param => 'CallingAction' );
    my $ClassID             = $ParamObject->GetParam( Param => 'ClassID' );

    # get class name
    my $ClassName;
    if ( $ClassID ne 'All' ) {
        my $GeneralCatalogItem = $GeneralCatalogObject->ItemGet(
            ItemID => $ClassID,
        );
        return 1 if ( !$GeneralCatalogItem );
        $ClassName = $GeneralCatalogItem->{Name};
    }
    else {
        $ClassName = 'All';
    }

    my @SelectedColumns = split( /,/, $SelectedColumnsStrg );

    my @ColumnStringArray;
    my $ColumnString = '';

    for my $Column (@SelectedColumns) {
        $Column =~ s/^$ClassName\:\://g;
        push @ColumnStringArray, $Column;
    }

    $ColumnString = join( ",", @ColumnStringArray );

    if ( !$ConfigObject->Get('DemoSystem') ) {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserCustomCILV-' . $CallingAction . '-' . $ClassName,
            Value  => $ColumnString,
        );
    }

    $Self->{Message} = 'Preferences updated successfully!';
    return 1;
}

sub Error {
    my ( $Self, %Param ) = @_;

    return $Self->{Error} || '';
}

sub Message {
    my ( $Self, %Param ) = @_;

    return $Self->{Message} || '';
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
