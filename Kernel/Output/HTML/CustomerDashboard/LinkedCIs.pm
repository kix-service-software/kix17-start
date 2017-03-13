# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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
    my $Content;

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

    return $Param{LinkConfigItemStrg}
        = $LayoutObject->CustomerDashboardAssignedConfigItemsTable(
        CustomerUserIDs => $CustomerIDs,
        UserID => $Self->{UserID} || '',
        );

    return $Param{LinkConfigItemStrg};
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
