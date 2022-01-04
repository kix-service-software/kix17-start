# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::DefaultService;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get config
    $Self->{Config}
        = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::CustomerTicketMessage");

    return $Self;
}

sub Param {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ServiceObject    = $Kernel::OM->Get('Kernel::System::Service');

    my $CustomerUserLogin = $Param{UserData}{UserLogin} ? $Param{UserData}{UserLogin} : "-";
    my %Service = $ServiceObject->CustomerUserServiceMemberList(
        CustomerUserLogin => $CustomerUserLogin,
        Result            => 'HASH',
    );
    if (%Service) {
        for ( keys %Service ) {
            $Service{"$Service{$_}"} = $Service{$_};
            delete $Service{$_};
        }
    }
    $Service{'-'} = '-';

    my @Params;
    push(
        @Params,
        {
            %Param,
            Name        => $Self->{ConfigItem}->{PrefKey},
            Data        => \%Service,
            Translation => 0,
            HTMLQuote   => 0,
            SelectedID  => $ParamObject->GetParam( Param => 'UserDefaultService' )
                || $Param{UserData}->{UserDefaultService}
                || $Self->{Config}->{ServiceDefault},
            Block => 'Option',
            Max   => 100,
        },
    );
    return @Params;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $UserObject = $Param{UserObject} || $Kernel::OM->Get('Kernel::System::CustomerUser');

    for my $Key ( keys %{ $Param{GetParam} } ) {
        my @Array = @{ $Param{GetParam}->{$Key} };
        for (@Array) {

            # pref update db
            if ( !$ConfigObject->Get('DemoSystem') ) {
                $UserObject->SetPreferences(
                    UserID => $Param{UserData}->{UserID},
                    Key    => $Key,
                    Value  => $_,
                );
            }

            # update SessionID
            if ( $Param{UserData}->{UserID} eq $Self->{UserID} ) {
                $SessionObject->UpdateSessionID(
                    SessionID => $Self->{SessionID},
                    Key       => $Key,
                    Value     => $_,
                );
            }
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
