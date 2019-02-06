# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# use ReferenceData ISO list
$ConfigObject->Set(
    Key   => 'ReferenceData::OwnCountryList',
    Value => undef,
);

my $ReferenceDataObject = $Kernel::OM->Get('Kernel::System::ReferenceData');

# tests the method to make sure there are at least 100 countries
my $CountryList = $ReferenceDataObject->CountryList();

my $CountryListLength = scalar keys %$CountryList;

$Self->True(
    $CountryListLength > 100,
    "There are $CountryListLength countries registered",
);

# let's assume these countries don't go anywhere
my @CountryList = ( 'Netherlands', 'Germany', 'Switzerland', 'United States of America', 'Japan' );

for my $Country (@CountryList) {
    $Self->True(
        $$CountryList{$Country},
        "Testing existence of country ($Country)",
    );
}

# set configuration to small list
$ConfigObject->Set(
    Key   => 'ReferenceData::OwnCountryList',
    Value => {
        'FR' => 'France',
        'NL' => 'Netherlands',
        'DE' => 'Germany'
    },
);

$CountryList = $ReferenceDataObject->CountryList();

@CountryList = ( 'Switzerland', 'United States', 'Japan' );

for my $Country (@CountryList) {
    $Self->False(
        $$CountryList{$Country},
        "OwnCountryList: Testing non-existence of country ($Country)",
    );
}

@CountryList = ( 'France', 'Netherlands', 'Germany' );

for my $Country (@CountryList) {
    $Self->True(
        $$CountryList{$Country},
        "OwnCountryList: Testing existence of country ($Country)",
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
