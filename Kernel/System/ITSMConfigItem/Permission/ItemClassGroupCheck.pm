# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Permission::ItemClassGroupCheck;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::Group',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::ITSMConfigItem::Permission::ItemClassGroupCheck - check if a user can access an item

=head1 SYNOPSIS

All config item functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CheckObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::Permission::ItemClassGroupCheck');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

this method does the check if the user can access an item

    my $HasAccess = $CheckObject->Run(
        UserID => 123,
        Type   => 'ro',
        ItemID => 345,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID Type ItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # KIX4OTRS-capeIT
    # check frontend
    if ( !defined $Param{Frontend} || !$Param{Frontend} ) {
        $Param{Frontend} = 'Agent';
    }

    my $CustomerGroupSupport = $Kernel::OM->Get('Kernel::Config')->Get('CustomerGroupSupport');

    # EO KIX4OTRS-capeIT

    # get config item data
    my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{ItemID},
    );

    # get Class data
    my $ClassItem = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
        ItemID => $ConfigItem->{ClassID}
    );

    # KIX4OTRS-capeIT
    # get config item data
    my $ConfigItemData = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->VersionGet(
        ConfigItemID => $Param{ItemID},
        XMLDataGet   => 1,
    );

    my $KeyName = '';
    for my $ClassAttributeHash ( @{ $ConfigItemData->{XMLDefinition} } ) {
        next if ( $ClassAttributeHash->{Input}->{Type} ne 'CIGroupAccess' );
        $KeyName = $ClassAttributeHash->{Key};
    }

    my $Array = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->GetAttributeValuesByKey(
        KeyName       => $KeyName,
        XMLData       => $ConfigItemData->{XMLData}->[1]->{Version}->[1],
        XMLDefinition => $ConfigItemData->{XMLDefinition},
    );

    my @AccessGroupIDs = ();
    if ( scalar @{$Array} ) {
        my @AccessGroups = split( /,/, $Array->[0] );
        for my $Group (@AccessGroups) {
            $Group =~ s/^\s+|\s+$//g;
            my $TempGroupID = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
                Group => $Group
            );
            if ($TempGroupID) {
                push @AccessGroupIDs, $TempGroupID;
            }
        }
    }

    # EO KIX4OTRS-capeIT

    # get user groups
    # KIX4OTRS-capeIT
    my @GroupIDs;
    if ( $Param{Frontend} eq 'Agent' ) {

        # EO KIX4OTRS-capeIT
        @GroupIDs = $Kernel::OM->Get('Kernel::System::Group')->GroupMemberList(
            UserID => $Param{UserID},
            Type   => $Param{Type},
            Result => 'ID',
            Cached => 1,
        );

        # KIX4OTRS-capeIT
    }
    elsif ( $Param{Frontend} eq 'Customer' && $CustomerGroupSupport ) {
        @GroupIDs = $Kernel::OM->Get('Kernel::System::CustomerGroup')->GroupMemberList(
            UserID => $Param{UserID},
            Type   => $Param{Type},
            Result => 'ID',
            Cached => 1,
        );
    }
    else {
        return 1;
    }

    # EO KIX4OTRS-capeIT

    # looking for group id, return access if user is in group
    # KIX4OTRS-capeIT
    my $DefaultAccess = 0;
    my $GroupAccess   = 0;

    if ( scalar @{$Array} ) {

    # EO KIX4OTRS-capeIT
        for my $GroupID (@GroupIDs) {

            # KIX4OTRS-capeIT
            # return 1 if $ClassItem->{Permission} && $GroupID eq $ClassItem->{Permission};
            $DefaultAccess = 1 if $ClassItem->{Permission} && $GroupID eq $ClassItem->{Permission};
            $GroupAccess = 1 if grep { $_ eq $GroupID } @AccessGroupIDs;
            last if ( $DefaultAccess && $GroupAccess );

            # EO KIX4OTRS-capeIT
        }

        # KIX4OTRS-capeIT
    }
    else {

        # group access ok if no access group attribute set
        $GroupAccess = 1;
        for my $GroupID (@GroupIDs) {
            $DefaultAccess = 1 if $ClassItem->{Permission} && $GroupID eq $ClassItem->{Permission};
        }
    }

    # EO KIX4OTRS-capeIT
    # return no access
    # KIX4OTRS-capeIT
    # return;
    return ( $DefaultAccess && $GroupAccess );

    # EO KIX4OTRS-capeIT

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
