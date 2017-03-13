# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::SearchProfileAutoSubscribe;

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

    # get needed objects
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');

    my @Params = ();
    my %UserData;

    # check needed param, if no user id is given, do not show this box
    if ( $Self->{Subaction} ne 'Add' && !$Param{UserData}->{UserID} ) {
        return ();
    }
    if ( $Param{UserData}->{UserID} ) {
        %UserData = $UserObject->GetUserData(
            UserID => $Param{UserData}->{UserID},
        );
    }

    my $AutoSubscribeStrg = $UserData{SearchProfileAutoSubscribe} || '';
    my @AutoSubscribeCategories = split( /;/, $AutoSubscribeStrg );
    my %SearchProfileCategories =
        $SearchProfileObject->SearchProfileCategoryList();

    # if ( !$Self->{Subaction} ) {
    push(
        @Params,
        { %Param, Block => 'SPAS' },
        {
            %Param,
            Key        => 'SearchProfileAutoSubscribe',
            Name       => $LayoutObject->{LanguageObject}->Translate('Search Profile Category'),
            OptionStrg => $LayoutObject->BuildSelection(
                Data        => \%SearchProfileCategories,
                Name        => 'PrefSearchProfileAutoSubscribe',
                SelectedID  => \@AutoSubscribeCategories,
                Translation => 0,
                OptionTitle => 1,
                Multiple    => 1,
                Class       => 'Modernize'
            ),
            Block => 'SearchProfileAutoSubscribe'
        },
    );

    #   }

    return @Params;

}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $SessionObject       = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');

    # check needed param, if no user id is given, do not show this box
    my %UserData;
    if ( !$Param{UserData}->{UserID} ) {
        return ();
    }

    # get user data
    if ( $Param{UserData}->{UserID} ) {
        %UserData = $UserObject->GetUserData(
            UserID => $Param{UserData}->{UserID},
        );
    }

    # get selected categories
    my @AutoSubscribeCategories =
        $ParamObject
        ->GetArray( Param => 'PrefSearchProfileAutoSubscribe' );
    my $AutoSubscribeStrg = join( ";", @AutoSubscribeCategories );

    # get all available categories
    my %SearchProfileCategories =
        $SearchProfileObject->SearchProfileCategoryList();

    # get already selected categories for auto-subscribe
    my $AutoSubscribeStrgOld = $UserData{SearchProfileAutoSubscribe} || '';
    my @AutoSubscribeCategoriesOld = split( /;/, $AutoSubscribeStrgOld );

    # get disabled categories to delete subscribed search profiles from subscribed list
    for my $Category ( keys %SearchProfileCategories ) {
        next if !grep { $_ eq $Category } @AutoSubscribeCategoriesOld;
        next if grep  { $_ eq $Category } @AutoSubscribeCategories;
        $SearchProfileObject->SearchProfileCategoryDelete(
            Category  => $Category,
            UserLogin => $UserData{UserLogin},
            State     => 'subscriber'
        );
    }

    # subscribe to all profiles for selected categories
    for my $Category (@AutoSubscribeCategories) {
        my %SearchProfilesByCategory =
            $SearchProfileObject->SearchProfilesByCategory(
            UserLogin => $UserData{UserLogin},
            Base      => 'TicketSearch',
            Category  => $Category
            );

        # do not subscribe to already subscribed search profiles
        my @SelectedProfiles = @{ $SearchProfilesByCategory{SelectedData} };
        for my $Profile ( keys %{ $SearchProfilesByCategory{Data} } ) {
            next if grep { $_ eq $Profile } @SelectedProfiles;
            $SearchProfileObject->SearchProfileCategoryAdd(
                Name      => $Profile,
                Category  => $Category,
                State     => 'subscriber',
                UserLogin => $UserData{UserLogin},
            );
        }
    }

    # pref update db
    if ( !$ConfigObject->Get('DemoSystem') ) {
        $UserObject->SetPreferences(
            UserID => $Param{UserData}->{UserID},
            Key    => 'SearchProfileAutoSubscribe',
            Value  => $AutoSubscribeStrg,
        );
    }

    # update SessionID
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'SearchProfileAutoSubscribe',
        Value     => $AutoSubscribeStrg,
    );

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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
