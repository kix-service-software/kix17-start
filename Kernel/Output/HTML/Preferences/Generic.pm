# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::Generic;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Web::Request',
    'Kernel::Config',
    'Kernel::System::AuthSession',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    for my $Needed (qw(UserID UserObject ConfigItem)) {
        die "Got no $Needed!" if ( !$Self->{$Needed} );
    }

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    my @Params;
    my $GetParam
        = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Self->{ConfigItem}->{PrefKey} );
    if ( !defined $GetParam ) {
        $GetParam = defined( $Param{UserData}->{ $Self->{ConfigItem}->{PrefKey} } )
            ? $Param{UserData}->{ $Self->{ConfigItem}->{PrefKey} }
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
            if ( !$Kernel::OM->Get('Kernel::Config')->Get('DemoSystem') ) {
                $Self->{UserObject}->SetPreferences(
                    UserID => $Param{UserData}->{UserID},
                    Key    => $Key,
                    Value  => $_,
                );
            }
            if ( $Param{UserData}->{UserID} eq $Self->{UserID} ) {

                # update SessionID
                $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
                    SessionID => $Self->{SessionID},
                    Key       => $Key,
                    Value     => $_,
                );
            }
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
