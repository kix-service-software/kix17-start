# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerDashboard::LinkedCIs;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::CustomerUser',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    return;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigItemObject     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $CustomerUserObject   = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $CustomerIDs;
    my %CustomerUserData;
    if ( defined $Param{CustomerID} ) {
        $CustomerIDs
            = { $CustomerUserObject->CustomerSearch( CustomerID => $Param{CustomerID} ) };
    }
    else {
        my %TempHash;
        %CustomerUserData
            = $CustomerUserObject->CustomerUserDataGet( User => $Param{CustomerUserLogin} );
        $TempHash{ $Param{CustomerUserLogin} }
            = '"'
            . $CustomerUserData{UserFirstname} . ' '
            . $CustomerUserData{UserLastname} . '" <'
            . $CustomerUserData{UserEmail} . '>';
        $CustomerIDs = \%TempHash;
    }

    return $Param{LinkConfigItemStrg} = $LayoutObject->CustomerDashboardAssignedConfigItemsTable(
        CustomerUserIDs => $CustomerIDs,
        UserID          => $Self->{UserID} || '',
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
