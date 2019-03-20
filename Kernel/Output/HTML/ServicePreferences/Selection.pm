# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ServicePreferences::Selection;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $GeneralCatalogObject;
    if ( $Kernel::OM->Get('Kernel::System::Main')
        ->Require( 'Kernel::System::GeneralCatalog', Silent => 1 ) )
    {
        $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    }
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my $TypeObject  = $Kernel::OM->Get('Kernel::System::Type');
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    my @Params = ();
    my $GetParam = $ParamObject->GetParam( Param => $Self->{ConfigItem}->{PrefKey} );
    if ( !defined($GetParam) ) {
        $GetParam
            = defined( $Param{ServiceData}->{ $Self->{ConfigItem}->{PrefKey} } )
            ? $Param{ServiceData}->{ $Self->{ConfigItem}->{PrefKey} }
            : $Self->{ConfigItem}->{DataSelected};
    }

    # KIX4OTRS-capeIT
    my %SelectionList = ();
    if ( $Self->{ConfigItem}->{SelectionSource} eq 'QueueList' ) {
        %SelectionList = $QueueObject->QueueList();
    }
    if ( $Self->{ConfigItem}->{SelectionSource} eq 'TypeList' ) {
        %SelectionList = $TypeObject->TypeList();
    }
    elsif (
        ( $Self->{ConfigItem}->{SelectionSource} eq 'GeneralCatalog' )
        &&
        ( $Self->{ConfigItem}->{GeneralCatalogClass} ) &&
        $GeneralCatalogObject
        )
    {
        my $ItemListRef = $GeneralCatalogObject->ItemList(
            Class => $Self->{ConfigItem}->{GeneralCatalogClass},
        );
        if ( $ItemListRef && ref($ItemListRef) eq 'HASH' ) {
            %SelectionList = %{$ItemListRef};
        }
    }

    # EO KIX4OTRS-capeIT

    push(
        @Params,
        {
            %Param,
            Name => $Self->{ConfigItem}->{PrefKey},
            SelectedID => $GetParam || '',

            # KIX4OTRS-capeIT
            Data         => \%SelectionList,
            Title        => $Self->{ConfigItem}->{ToolTip},
            PossibleNone => $Self->{ConfigItem}->{PossibleNone},

            # EO KIX4OTRS-capeIT
        },
    );

    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');

    for my $Key ( keys %{ $Param{GetParam} } ) {
        my @Array = @{ $Param{GetParam}->{$Key} };
        for (@Array) {

            # pref update db
            $ServiceObject->ServicePreferencesSet(
                ServiceID => $Param{ServiceData}->{ServiceID},
                Key       => $Key,
                Value     => $_,
            );
        }
    }
    $Self->{Message} = 'Preferences updated successfully!';
    return 1;
}

sub Error {
    my ( $Self, %Param ) = @_;

    return $Self->{Error} || '';
}

sub Message {
    my ( $Self, %Param ) = @_;

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
