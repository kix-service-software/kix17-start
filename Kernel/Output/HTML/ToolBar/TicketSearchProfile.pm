# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ToolBar::TicketSearchProfile;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::User',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::SearchProfile',
    'Kernel::System::GeneralCatalog',
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

    # get needed objects
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    # get user data
    my %User = $UserObject->GetUserData(
        UserID => $Self->{UserID},
    );

    # get all possible search profiles
    my $Config = $ConfigObject->Get('ToolbarSearchProfile');
    my @Bases = $SearchProfileObject->SearchProfilesBasesGet();
    my %SearchProfilesHash;
    my @SearchProfilesData;
    for my $Base (@Bases) {

        next if $Base =~ /(.*?)Search(.*)/ && !defined $Config->{$1};

        my %Profiles = $SearchProfileObject->SearchProfileList(
            Base             => $Base,
            UserLogin        => $User{UserLogin},
            WithSubscription => 1
        );
        next if ( !keys( %Profiles ) );

        my $DisplayBase = $Base;
        my $Extended    = '';
        if ( $Base =~ /(.*?)Search(.*)/ ) {
            if ( $2 && $1 eq 'ConfigItem' ) {
                # add config item base to data
                if ( !$SearchProfilesHash{'ConfigItemSearch'} ) {
                    $SearchProfilesHash{'ConfigItemSearch'} = 1;
                    push(@SearchProfilesData, {
                        Key      => 'ConfigItemSearch',
                        Value    => 'ConfigItem',
                        Disabled => 1,
                    });
                }

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

        # add display base to data
        if ( !$SearchProfilesHash{$DisplayBase} ) {
            $SearchProfilesHash{$DisplayBase} = 1;
            push(@SearchProfilesData, {
                Key      => $Base,
                Value    => $DisplayBase,
                Disabled => 1,
            });
        }

        for my $Profile ( keys( %Profiles ) ) {
            if ( $Profile =~ /(.*?)::(.*)/ ) {
                # add profile to data
                if ( !$SearchProfilesHash{$DisplayBase . '::' . $LayoutObject->{LanguageObject}->Get($1) . $Extended} ) {
                    $SearchProfilesHash{$DisplayBase . '::' . $LayoutObject->{LanguageObject}->Get($1) . $Extended} = 1;
                    push(@SearchProfilesData, {
                        Key      => $Base . '::' . $Profile,
                        Value    => $DisplayBase . '::' . $LayoutObject->{LanguageObject}->Get($1) . $Extended,
                    });
                }
            }
        }
    }

    # create search profiles string
    my $ProfilesStrg = $LayoutObject->BuildSelection(
        Data         => \@SearchProfilesData,
        Name         => 'SearchProfile',
        ID           => 'ToolBarSearchProfiles',
        Title        => $LayoutObject->{LanguageObject}->Translate('Search template'),
        SelectedID   => '',
        Max          => $Param{Config}->{MaxWidth},
        Class        => 'Modernize',
        TreeView     => 1,
        Sort         => 'TreeView',
        PossibleNone => 1
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
