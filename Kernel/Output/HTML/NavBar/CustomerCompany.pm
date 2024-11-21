# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::NavBar::CustomerCompany;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
);

use Kernel::System::ObjectManager;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get UserID param
    $Self->{UserID} = $Param{UserID} || die "Got no UserID!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check if frontend module is registared
    my $Config = $ConfigObject->Get('Frontend::Module')->{AdminCustomerCompany};
    return if !$Config;

    # check if customer company support feature is active
    SOURCE:
    for my $Item ( '', 1 .. 10 ) {
        my $CustomerMap = $ConfigObject->Get( 'CustomerUser' . $Item );
        next SOURCE if !$CustomerMap;

        # return if CustomerCompany feature is used
        return if $CustomerMap->{CustomerCompanySupport};
    }

    # frontend module is enabled but not customer company support feature, then remove the menu entry
    my $NavBarName = $Config->{NavBarName};
    my %Return     = %{ $Param{NavBar}->{Sub} };

    # remove CustomerCompany from the CustomerMenu
    delete $Return{$NavBarName}->{ItemArea0009100};

    return ( Sub => \%Return );
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
