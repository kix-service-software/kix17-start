# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars qw($Self);

use Data::Dumper;
use Kernel::System::Encode;
use Kernel::System::GeneralCatalog;
use Kernel::System::ImportExport;
use Kernel::System::ImportExport::ObjectBackend::CustomerCompany;
use Kernel::System::CustomerCompany;
use Kernel::System::XML;

$Self->{CustomerCompanyObject}   = Kernel::System::CustomerCompany->new( %{$Self} );
$Self->{EncodeObject}            = Kernel::System::Encode->new( %{$Self} );
$Self->{GeneralCatalogObject}    = Kernel::System::GeneralCatalog->new( %{$Self} );
$Self->{ImportExportObject}      = Kernel::System::ImportExport->new( %{$Self} );
$Self->{ObjectBackendObject}     = Kernel::System::ImportExport::ObjectBackend::CustomerCompany->new( %{$Self} );
    

# ------------------------------------------------------------ #
# make preparations
# ------------------------------------------------------------ #

# add some test templates for later checks
my @TemplateIDs;
for ( 1 .. 30 ) {

    # add a test template for later checks
    my $TemplateID = $Self->{ImportExportObject}->TemplateAdd(
        Object  => 'CustomerCompany',
        Format  => 'UnitTest' . int rand 1_000_000,
        Name    => 'UnitTest' . int rand 1_000_000,
        ValidID => 1,
        UserID  => 1,
    );

    push @TemplateIDs, $TemplateID;
}

my $TestCount = 1;


# ------------------------------------------------------------ #
# ObjectList test 1 (check CSV item)
# ------------------------------------------------------------ #

# get object list
my $ObjectList1 = $Self->{ImportExportObject}->ObjectList();

# check object list
$Self->True(
    $ObjectList1 && ref $ObjectList1 eq 'HASH' && $ObjectList1->{CustomerCompany},
    "Test $TestCount: ObjectList() - CustomerCompany exists",
);

$TestCount++;


# ------------------------------------------------------------ #
# ObjectAttributesGet test 1 (check attribute hash)
# ------------------------------------------------------------ #

#
#
# TO DO 
#
#




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
