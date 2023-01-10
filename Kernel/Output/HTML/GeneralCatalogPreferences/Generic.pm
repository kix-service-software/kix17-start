# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::GeneralCatalogPreferences::Generic;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::Group',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get needed params
    for my $Needed (qw( UserID ConfigItem )) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    my @Params = ();
    my $GetParam
        = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Self->{ConfigItem}->{PrefKey} );

    if ( !defined($GetParam) ) {
        $GetParam = defined( $Param{GeneralCatalogData}->{ $Self->{ConfigItem}->{PrefKey} } )
            ? $Param{GeneralCatalogData}->{ $Self->{ConfigItem}->{PrefKey} }
            : $Self->{ConfigItem}->{DataSelected};
    }

    if ( !( defined $Self->{ConfigItem}->{Block} && $Self->{ConfigItem}->{Block} ) ) {
        $Self->{ConfigItem}->{Block} = 'Text';
    }

    if ( $Self->{ConfigItem}->{Block} eq 'Permission' ) {
        $Param{Data}         = { $Kernel::OM->Get('Kernel::System::Group')->GroupList( Valid => 1 ) };
        $Param{PossibleNone} = 1;
        $Param{Block}        = 'Option';
    }

    push(
        @Params,
        {
            %Param,
            Name       => $Self->{ConfigItem}->{PrefKey},
            SelectedID => $GetParam,
        },
    );

    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    for my $Key ( sort keys %{ $Param{GetParam} } ) {
        my @Array = @{ $Param{GetParam}->{$Key} };
        for my $Value (@Array) {

            # pref update db
            $Kernel::OM->Get('Kernel::System::GeneralCatalog')->GeneralCatalogPreferencesSet(
                ItemID => $Param{ItemID},
                Key    => $Key,
                Value  => $Value,
            );
        }
    }

    $Self->{Message} = 'Preferences updated successfully!';
    return 1;
}

sub Error {
    my $Self = shift;

    return $Self->{Error} || '';
}

sub Message {
    my $Self = shift;

    return $Self->{Message} || '';
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
