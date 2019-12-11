# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->GetNew('Kernel::Config');

# define needed variables
my %AgentModules = (
    %{ $ConfigObject->Get('Frontend::Module') },
    %{ $ConfigObject->Get('Frontend::ToolBarModule') }
);
my %CustomerModules = (
    %{ $ConfigObject->Get('CustomerFrontend::Module') }
);
my %PublicModules = (
    %{ $ConfigObject->Get('PublicFrontend::Module') }
);
my %UsedAccessKeysAgent;
my %UsedAccessKeysCustomer;
my %UsedAccessKeysPublic;
my $StartTime;

# init test case for agent modules
$Self->TestCaseStart(
    TestCase    => 'Agent frontend',
    Feature     => 'Configuration',
    Story       => 'AccessKeys',
    Description => <<'END',
Check access keys of agent frontend modules
* Each access key can only be used onces for NavBar
END
);

# process agent modules
ACCESSKEYSAGENT:
for my $AgentModule ( sort( keys( %AgentModules ) ) ) {
    # check navbar items
    if (
        !$AgentModules{$AgentModule}->{NavBar}
        || !@{ $AgentModules{$AgentModule}->{NavBar} }
    ) {
        next ACCESSKEYSAGENT;
    }

    # process navbar items
    NAVBARITEMSAGENT:
    for my $NavBar ( sort( @{ $AgentModules{$AgentModule}->{NavBar} } ) ) {
        # check if navbar entry has access key
        my $NavBarKey  = $NavBar->{AccessKey} || '';
        next NAVBARITEMSAGENT if !$NavBarKey;

        # get navbar name
        my $NavBarName = $NavBar->{Name} || '';

        ## TEST STEP
        # check that access key is not already in use
        $StartTime = $Self->GetMilliTimeStamp();
        $Self->False(
            TestName  => $NavBarName . ': Check if access key "' . $NavBarKey . '" is already in use',
            TestValue => defined( $UsedAccessKeysAgent{$NavBarKey} ),
            StartTime => $StartTime,
        );
        ## EO TEST STEP

        # remember used access key
        $UsedAccessKeysAgent{$NavBarKey} = 1;
    }
}

# init test case for customer modules
$Self->TestCaseStart(
    TestCase    => 'Customer frontend',
    Feature     => 'Configuration',
    Story       => 'AccessKeys',
    Description => <<'END',
Check access keys of customer frontend modules
* Each access key can only be used onces for NavBar
END
);

# process customer modules
ACCESSKEYSCUSTOMER:
for my $CustomerModule ( sort( keys( %CustomerModules ) ) ) {
    # check navbar items
    if (
        !$CustomerModules{$CustomerModule}->{NavBar}
        || !@{ $CustomerModules{$CustomerModule}->{NavBar} }
    ) {
        next ACCESSKEYSCUSTOMER;
    }

    # process navbar items
    NAVBARITEMSCUSTOMER:
    for my $NavBar ( sort @{ $CustomerModules{$CustomerModule}->{NavBar} } ) {
        # check if navbar entry has access key
        my $NavBarKey = $NavBar->{AccessKey} || '';
        next NAVBARITEMSCUSTOMER if !$NavBarKey;

        # get navbar name
        my $NavBarName = $NavBar->{Name} || '';

        ## TEST STEP
        # check that access key is not already in use
        $StartTime = $Self->GetMilliTimeStamp();
        $Self->False(
            TestName  => $NavBarName . ': Check if access key "' . $NavBarKey . '" is already in use',
            TestValue => defined( $UsedAccessKeysCustomer{$NavBarKey} ),
            StartTime => $StartTime,
        );
        ## EO TEST STEP

        # remember used access key
        $UsedAccessKeysCustomer{$NavBarKey} = 1;
    }
}

# init test case for public modules
$Self->TestCaseStart(
    TestCase    => 'Public frontend',
    Feature     => 'Configuration',
    Story       => 'AccessKeys',
    Description => <<'END',
Check access keys of public frontend modules
* Each access key can only be used onces for NavBar
END
);

# process public modules
ACCESSKEYSPUBLIC:
for my $PublicModule ( sort( keys( %PublicModules ) ) ) {
    # check navbar items
    if (
        !$PublicModules{$PublicModule}->{NavBar}
        || !@{ $PublicModules{$PublicModule}->{NavBar} }
    ) {
        next ACCESSKEYSPUBLIC;
    }

    # process navbar items
    NAVBARITEMSPUBLIC:
    for my $NavBar ( sort @{ $PublicModules{$PublicModule}->{NavBar} } ) {
        # check if navbar entry has access key
        my $NavBarKey = $NavBar->{AccessKey} || '';
        next NAVBARITEMSPUBLIC if !$NavBarKey;

        # get navbar name
        my $NavBarName = $NavBar->{Name} || '';

        ## TEST STEP
        # check that access key is not already in use
        $StartTime = $Self->GetMilliTimeStamp();
        $Self->False(
            TestName  => $NavBarName . ': Check if access key "' . $NavBarKey . '" is already in use',
            TestValue => defined( $UsedAccessKeysPublic{$NavBarKey} ),
            StartTime => $StartTime,
        );
        ## EO TEST STEP

        # remember used access key
        $UsedAccessKeysPublic{$NavBarKey} = 1;
    }
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
