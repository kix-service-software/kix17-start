# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ToolBar::TicketSearchProfile;

use strict;
use warnings;

our @ObjectDependencies = (
    # KIX4OTRS-capeIT
    'Kernel::Config',
    # EO KIX4OTRS-capeIT

    'Kernel::System::User',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::SearchProfile',

    # KIX4OTRS-capeIT
    'Kernel::System::GeneralCatalog',

    # EO KIX4OTRS-capeIT
);

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

    # KIX4OTRS-capeIT
    # get needed objects
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    # EO KIX4OTRS-capeIT

    # get user data
    my %User = $UserObject->GetUserData(
        UserID => $Self->{UserID},
    );

    # KIX4OTRS-capeIT
    # get all possible search profiles
    my $Config = $ConfigObject->Get('ToolbarSearchProfile');
    my @Bases = $SearchProfileObject->SearchProfilesBasesGet();
    my %SearchProfiles;
    for my $Base (@Bases) {

        next if $Base =~ /(.*?)Search(.*)/ && !defined $Config->{$1};

        my %Profiles = $SearchProfileObject->SearchProfileList(
            Base             => $Base,
            UserLogin        => $User{UserLogin},
            WithSubscription => 1
        );

        my $DisplayBase = $Base;
        my $Extended    = '';
        if ( $Base =~ /(.*?)Search(.*)/ ) {
            if ( $2 && $1 eq 'ConfigItem' ) {
                my $Classes
                    = $GeneralCatalogObject->ItemList(
                    Class => 'ITSM::ConfigItem::Class'
                    );
                $DisplayBase = $1;
                if ( defined $Classes->{$2} && $Classes->{$2} ) {
                    $DisplayBase
                        .= "::" . $LayoutObject->{LanguageObject}->Get( $Classes->{$2} );
                }
                elsif ( $2 eq 'All' ) {
                    $DisplayBase .= "::" . $LayoutObject->{LanguageObject}->Get('All');
                }
            }
            else {
                $DisplayBase = $1;
            }
        }

        for my $Profile ( keys %Profiles ) {
            if ( $Profile =~ /(.*?)::(.*)/ ) {
                $SearchProfiles{ $Base . '::' . $Profile } = $DisplayBase . '::' . $LayoutObject->{LanguageObject}->Get($1) . $Extended;
            }
        }
    }

    # EO KIX4OTRS-capeIT

    # create search profiles string
    my $ProfilesStrg = $LayoutObject->BuildSelection(
        Data => {
            # KIX4OTRS-capeIT
            # '', '-',
            # $SearchProfileObject->SearchProfileList(
            #     Base      => 'TicketSearch',
            #     UserLogin => $User{UserLogin},
            # ),
            %SearchProfiles

            # EO KIX4OTRS-capeIT
        },

        # KIX4OTRS-capeIT
        # Name       => 'Profile',
        # ID         => 'ToolBarSearchProfile',
        Name => 'SearchProfile',
        ID   => 'ToolBarSearchProfiles',

        # EO KIX4OTRS-capeIT
        Title      => $LayoutObject->{LanguageObject}->Translate('Search template'),
        SelectedID => '',
        Max        => $Param{Config}->{MaxWidth},
        Class      => 'Modernize',

        # KIX4OTRS-capeIT
        TreeView     => 1,
        Sort         => 'TreeView',
        PossibleNone => 1
        # EO KIX4OTRS-capeIT
    );

    my $Priority = $Param{Config}->{'Priority'};
    my %Return   = ();
    $Return{ $Priority++ } = {
        Block       => $Param{Config}->{Block},
        Description => $Param{Config}->{Description},
        Name        => $Param{Config}->{Name},
        Image       => '',
        Link        => $ProfilesStrg,
        AccessKey   => '',
    };
    return %Return;
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
