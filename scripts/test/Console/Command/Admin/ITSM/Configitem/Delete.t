# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $CommandObject = $Kernel::OM->Get('Kernel::System::Console::Command::Admin::ITSM::Configitem::Delete');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $ExitCode = $CommandObject->Execute();

$Self->Is(
    $ExitCode,
    1,
    "Admin::ITSM::Configitem::Delete exit code without options",
);

# check command with option --all and argument --accept n ( cancel deleting all config item)
$ExitCode = $CommandObject->Execute( '--all', 'n' );

$Self->Is(
    $ExitCode,
    0,
    "Option '--all' n",
);

# check command with class options (invalid class)
my $RandomClass = 'TestClass' . $Helper->GetRandomID();
$ExitCode = $CommandObject->Execute( '--class', $RandomClass );

$Self->Is(
    $ExitCode,
    1,
    "Option 'class' (but class $RandomClass doesn't exist) ",
);

# get general catalog object
my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

# add test general catalog item
my $GeneralCatalogItemID = $GeneralCatalogObject->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => $RandomClass,
    ValidID => 1,
    Comment => 'Comment',
    UserID  => 1,
);

$GeneralCatalogObject->GeneralCatalogPreferencesSet(
    ItemID => $GeneralCatalogItemID,
    Key    => 'Permission',
    Value  => 5,
);

$Self->True(
    $GeneralCatalogItemID,
    "Test general catalog item is created - $GeneralCatalogItemID ",
);

# get ConfigItem object
my $ConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

# get 'Planned' deployment state IDs
my $PlannedDeplStateDataRef = $GeneralCatalogObject->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Planned',
);
my $PlannedDeplStateID = $PlannedDeplStateDataRef->{ItemID};

my @ConfigItemNumbers;
my $ConfigItemID;

for ( 1 .. 10 ) {

    # create ConfigItem number
    my $ConfigItemNumber = $ConfigItemObject->ConfigItemNumberCreate(
        Type    => $Kernel::OM->Get('Kernel::Config')->Get('ITSMConfigItem::NumberGenerator'),
        ClassID => $GeneralCatalogItemID,
    );

    # add test ConfigItem
    $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Number  => $ConfigItemNumber,
        ClassID => $GeneralCatalogItemID,
        UserID  => 1,
    );

    push @ConfigItemNumbers, $ConfigItemNumber;

    # add new versions for the last added in previous loop
    my $ConfigItemName = 'TestConfigItem' . $Helper->GetRandomID();

    COUNT:
    for my $Count ( 1 .. 50 ) {

        my $VersionID = $ConfigItemObject->VersionAdd(
            Name         => $ConfigItemName . '-' . $Count,
            DefinitionID => 1,
            DeplStateID  => $PlannedDeplStateID,
            InciStateID  => 1,
            UserID       => 1,
            ConfigItemID => $ConfigItemID,
        );

        $Self->True(
            $VersionID,
            "Version $Count for config item $ConfigItemID is created - $ConfigItemName",
        );

        # change the date into past for the first 20 versions
        next COUNT if $Count > 10;

        # insert new version
        my $Success = $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL => 'UPDATE configitem_version
                SET create_time = \'2010-01-01 00:00:00\'
                WHERE id = ?',
            Bind => [
                \$VersionID,
            ],
        );
    }

    # check command with all-older-than-days-versions options (delete all versions older than one day)
    $ExitCode = $CommandObject->Execute( '--all-older-than-days-versions', 1 );

    $Self->Is(
        $ExitCode,
        0,
        "Exit code: Options --all-older-than-days-versions 1",
    );

    # get the list of remaining versions of this config item
    my $VersionList = $ConfigItemObject->VersionList(
        ConfigItemID => $ConfigItemID,
    );

    # result should only be 40 versions now
    $Self->Is(
        scalar @{$VersionList},
        40,
        "Number of remaining versions after running command with Options --all-older-than-days-versions 1",
    );

    # check command with all-but-keep-last-versions options (delete all versions but keep the last 30 versions)
    $ExitCode = $CommandObject->Execute( '--all-but-keep-last-versions', 30 );

    $Self->Is(
        $ExitCode,
        0,
        "Exit code: Options --all-but-keep-last-versions 30",
    );

    # get the list of remaining versions of this config item
    $VersionList = $ConfigItemObject->VersionList(
        ConfigItemID => $ConfigItemID,
    );

    # result should only be 40 versions now
    $Self->Is(
        scalar @{$VersionList},
        30,
        "Number of remaining versions after running command with Options --all-but-keep-last-versions 30",
    );

    # check command with all-old-versions options (delete all old versions except the last one)
    $ExitCode = $CommandObject->Execute('--all-old-versions');

    $Self->Is(
        $ExitCode,
        0,
        "Exit code: Options --all-old-versions",
    );

    # get the list of remaining versions of this config item
    $VersionList = $ConfigItemObject->VersionList(
        ConfigItemID => $ConfigItemID,
    );

    # result should only be 40 versions now
    $Self->Is(
        scalar @{$VersionList},
        1,
        "Number of remaining versions after running command with Options --all-old-versions",
    );
}

# check command with class options ($RandomClass class) and deployment-state 'Planned'
$ExitCode = $CommandObject->Execute( '--class', $RandomClass, '--deployment-state', 'Planned' );

$Self->Is(
    $ExitCode,
    0,
    "Exit code: Options --class $RandomClass --deployment-state' Planned",
);

# check command with configitem-number options
$ExitCode = $CommandObject->Execute(
    '--configitem-number', $ConfigItemNumbers[0], '--configitem-number',
    $ConfigItemNumbers[1]
);

$Self->Is(
    $ExitCode,
    0,
    "Exit code: Options --configitem-number",
);

# check command with class options ($RandomClass class)
# three config Items of ten created in test were deleted with the previous commands
# with the next command other seven will be deleted
$ExitCode = $CommandObject->Execute( '--class', $RandomClass );

$Self->Is(
    $ExitCode,
    0,
    "Exit code: Option --class $RandomClass",
);

# cleanup is done by RestoreDatabase

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
