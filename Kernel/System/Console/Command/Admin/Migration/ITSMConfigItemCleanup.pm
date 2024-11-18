# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Migration::ITSMConfigItemCleanup;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::ITSMConfigItem',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Migrate all config items to newest definition, delete old versions, delete obsolete definitions.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Migrating config items to current definitions...</yellow>\n");

    # get latest definition for classes
    my %DefinitionList;
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => <<'END',
SELECT class_id, id
FROM configitem_definition
ORDER BY id DESC
END
    );
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        if ( !$DefinitionList{ $Row[0] } ) {
            $DefinitionList{ $Row[0] } = $Row[1];
        }
    }

    # get all config item ids
    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => <<'END',
SELECT id, class_id
FROM configitem
END
    );
    my %ConfigItemList = ();
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ConfigItemList{ $Row[0] } = $Row[1];
    }

    # process config items
    my $Count           = 0;
    my $ConfigItemCount = scalar( keys( %ConfigItemList ) );
    CONFIGITEM:
    for my $ConfigItemID ( sort( keys( %ConfigItemList ) ) ) {
        $Count += 1;
        if ( $Count % 100 == 0 ) {
            my $Percent = int( $Count / ( $ConfigItemCount / 100 ) );
            $Self->Print(' - <yellow>' . $Count . '</yellow> of <yellow>' . $ConfigItemCount . '</yellow> processed (<yellow>' . $Percent . '%</yellow>)' . "\n");
        }

        # get definition id of latest version
        $Kernel::OM->Get('Kernel::System::DB')->Prepare(
            SQL   => <<'END',
SELECT definition_id
FROM configitem_version
WHERE configitem_id = ?
ORDER BY id DESC
END
            Bind  => [ \$ConfigItemID ],
            Limit => 1,
        );
        my $IsLatestDefinition = 0;
        while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
            if ( $DefinitionList{ $ConfigItemList{ $ConfigItemID } } eq $Row[0] ) {
                $IsLatestDefinition = 1;
            }
        }

        # check if new version is needed
        if ( !$IsLatestDefinition ) {
            # get current version data
            my $VersionRef = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionGet(
                ConfigItemID => $ConfigItemID,
                XMLDataGet   => 1,
            );

            if ( !IsHashRefWithData( $VersionRef ) ) {
                next CONFIGITEM;
            }

            # add new version
            $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionAdd(
                ConfigItemID => $ConfigItemID,
                Name         => $VersionRef->{Name},
                DefinitionID => $DefinitionList{ $ConfigItemList{ $ConfigItemID } },
                DeplStateID  => $VersionRef->{DeplStateID},
                InciStateID  => $VersionRef->{InciStateID},
                XMLData      => $VersionRef->{XMLData},
                UserID       => 1,
            );
        }
    }

    $Self->Print("<yellow>Delete old config item versions...</yellow>\n");

    # get list of all versions grouped by config item
    my $VersionsAll = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionListAll();

    # prepare list of versions to delete
    my @VersionsToDelete;
    if ( IsHashRefWithData( $VersionsAll ) ) {

        # process config items
        CONFIGITEMID:
        for my $ConfigItemID ( sort( keys( %{$VersionsAll} ) ) ) {

            next CONFIGITEMID if ( !IsHashRefWithData( $VersionsAll->{ $ConfigItemID } ) );

            # make sure that the versions are numerically sorted
            my @ReducedVersions = sort { $a <=> $b } ( keys( %{ $VersionsAll->{ $ConfigItemID } } ) );

            # remove the last (newest) version of current config item
            pop( @ReducedVersions );

            # add versions to list
            push( @VersionsToDelete, @ReducedVersions );
        }
    }

    # delete list of versions
    $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionDelete(
        VersionIDs => \@VersionsToDelete,
        UserID     => 1,
    );

    $Self->Print("<yellow>Delete obsolete definitions definitions...</yellow>\n");

    # delete obsolete definitions
    $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => <<'END',
DELETE FROM configitem_definition
WHERE id NOT IN (
    SELECT DISTINCT definition_id FROM configitem_version
)
END
    );

    # cleanup cache
    $Self->Print("<yellow>Cleanup cache...</yellow>\n");
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # show successfull output
    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
