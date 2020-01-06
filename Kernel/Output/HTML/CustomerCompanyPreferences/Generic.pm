# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::CustomerCompanyPreferences::Generic;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Web::Request',
    'Kernel::System::CustomerCompany',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get env
    for ( sort keys %Param ) {
        $Self->{$_} = $Param{$_};
    }

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    my @Params = ();
    my $GetParam
        = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Self->{ConfigItem}->{PrefKey} );

    if ( !defined($GetParam) ) {
        $GetParam = defined( $Param{CustomerCompanyData}->{ $Self->{ConfigItem}->{PrefKey} } )
            ? $Param{CustomerCompanyData}->{ $Self->{ConfigItem}->{PrefKey} }
            : $Self->{ConfigItem}->{DataSelected};
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
        for (@Array) {

            # pref update db
            $Kernel::OM->Get('Kernel::System::CustomerCompany')->SetPreferences(
                CustomerID => $Param{CustomerCompanyData}->{CustomerID},
                Key        => $Key,
                Value      => $_,
            );
        }
    }
    $Self->{Message} = Translatable('Preferences updated successfully!');
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
