#!/usr/bin/perl
# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
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
use lib dirname($RealBin).'/../../';
use lib dirname($RealBin).'/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'db-update-17.5.0.pl',
    },
);

use vars qw(%INC);

# save current SystemID
_SaveSystemID();

# migrate configuration for shown deployment states for config item link graph
_MigrateDeploymentStateConfiguration();

# Add a default quick state if state "closed successful" exists
_AddDefaultQuickState();

exit 0;

sub _SaveSystemID {
    my ( $Self, %Param ) = @_;

    # get SystemID from config object
    my $SystemID = $Kernel::OM->Get('Kernel::Config')->Get('SystemID');

    # update SysConfig
    my $Result = $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigItemUpdate(
        Key   => 'SystemID',
        Value => $SystemID,
        Valid => 1,
    );

    return $Result;
}

sub _MigrateDeploymentStateConfiguration {
    # get needed object
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    # prepare config mapping
    my %ConfigMapping = (
        'ConfigItemOverview::HighlightMapping' => 'ConfigItemLinkGraph::HighlightMapping',
    );

    # process mapping
    for my $ConfigName ( keys( %ConfigMapping ) ) {
        # get current configuration
        my %ConfigItem = $SysConfigObject->ConfigItemGet(
            Name => $ConfigName,
        );
        my $Config = $ConfigObject->Get($ConfigName);

        # update new configuration
        $SysConfigObject->ConfigItemUpdate(
            Key   => $ConfigMapping{$ConfigName},
            Value => $Config || '',
            Valid => $ConfigItem{Valid},
        );
    }
    return 1;
}

sub _AddDefaultQuickState {
    my $StateObject      = $Kernel::OM->Get('Kernel::System::State');
    my $QuickStateObject = $Kernel::OM->Get('Kernel::System::QuickState');
    my $ValidObject      = $Kernel::OM->Get('Kernel::System::Valid');
    my $LogObject        = $Kernel::OM->Get('Kernel::System::Log');

    # get state list
    my %StateList = $StateObject->StateList(
        UserID => 1,
        Valid  => 0
    );

    # get valid list
    my %ValidList = $ValidObject->ValidList();

    my %StateListReverse = reverse(%StateList);
    my %ValidListReverse = reverse(%ValidList);

    if (%StateList) {
        my @StateListKeys = sort keys %StateListReverse;
        if ( grep( { 'closed successful' eq $_ } @StateListKeys ) ) {
            my $Success = $QuickStateObject->QuickStateAdd(
                Name    => 'Ticket Schließen',
                StateID => $StateListReverse{'closed successful'},
                ValidID => $ValidListReverse{'valid'},
                Config  => '',
                UserID  => 1
            );

            if (!$Success) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Unable to add quick state 'Ticket Schließen'!"
                );
            }
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
