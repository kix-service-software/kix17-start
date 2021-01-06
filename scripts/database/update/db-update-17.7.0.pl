#!/usr/bin/perl
# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin) . '/../../';
use lib dirname($RealBin) . '/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update-17.7.0.pl',
    },
);

use vars qw(%INC);

# migrate configuration of AgentOverlay with a prefix
_AddCIClassDefinitions();

exit 0;

sub _AddCIClassDefinitions {
    my ( $Self, %Param ) = @_;

    # create needed objects
    $Self->{ConfigObject}         = $Kernel::OM->Get('Kernel::Config');
    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{GroupObject}          = $Kernel::OM->Get('Kernel::System::Group');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ValidObject}          = $Kernel::OM->Get('Kernel::System::Valid');
    $Self->{ITSMConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    # define valid list
    my %Validlist = $Self->{ValidObject}->ValidList();
    my %TmpHash2  = reverse(%Validlist);
    $Self->{ReverseValidList} = \%TmpHash2;
    $Self->{ValidList}        = \%Validlist;

    # get path
    my $DefFilePath = $Self->{ConfigObject}->Get('Home')
        . '/scripts/database/update/InitialCIClassDefinitions/';

    # classes to update / create
    my %Classes = (
        'Computer' => {
            PermissionGroup => 'itsm-configitem',
            Valid           => 'valid',
        },
        'Hardware' => {
            PermissionGroup => 'itsm-configitem',
            Valid           => 'valid',
        },
        'Location' => {
            PermissionGroup => 'itsm-configitem',
            Valid           => 'valid',
        },
        'Network' => {
            PermissionGroup => 'itsm-configitem',
            Valid           => 'valid',
        },
    );

    # get existing classes
    my $CIClassRef = $Self->{GeneralCatalogObject}->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    my %CIClassList        = %{$CIClassRef};
    my %ReverseCIClassList = reverse(%CIClassList);

    for my $CIClassName ( keys(%Classes) ) {
        next if ( !$ReverseCIClassList{$CIClassName} );

        # find the class ID and data
        my $ItemID      = $ReverseCIClassList{$CIClassName};
        my $ItemDataRef = $Self->{GeneralCatalogObject}->ItemGet(
            ItemID => $ItemID,
        );

        # get count of definitions
        my $DefinitionsList = $Self->{ITSMConfigItemObject}->DefinitionList(
            ClassID => $ItemID,
        );
        my $DefinitionCount = scalar @{$DefinitionsList};

        # open definition file
        my $CIClassNameFileName = $CIClassName;
        $CIClassNameFileName    =~ s/\W//g;
        my $CurrDefFile         = $DefFilePath . $CIClassNameFileName . '.def';
        my $CurrDefStrg         = '';
        if ( open( my $FH, '<', $CurrDefFile ) ) {
            while (<$FH>) {
                $CurrDefStrg .= $_;
            }
            close($FH);
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => 'No CIclass definition file for automatic update'
                    . "of class <$CIClassName> found.",
            );
            next;
        }

        # get last definition
        my $LastDefinition = $Self->{ITSMConfigItemObject}->DefinitionGet(
            ClassID => $ItemID,
        );

        # stop update, if definition exists and is the same or more then one versions exists
        next if (
            $DefinitionCount > 1
            || (
                $LastDefinition->{DefinitionID}
                && $LastDefinition->{Definition} eq $CurrDefStrg
            )
        );

        # add the new class-definition...
        my $Result = $Self->{ITSMConfigItemObject}->DefinitionAdd(
            ClassID    => $ItemID,
            Definition => $CurrDefStrg,
            UserID     => 1,
        );
        if ($Result) {
            $Self->{LogObject}->Log(
                Priority => 'notice',
                Message  => "Updated definition for class <$CIClassName>.",
            );
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => 'Could not update definition for class'
                    . " <$CIClassName>.",
            );
        }
    }
    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
