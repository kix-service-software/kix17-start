# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::SearchProfile;

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
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');

    my @Params = ();
    my %UserData;

    # check needed param, if no user id is given, do not show this box
    if ( !$Param{UserData}->{UserID} ) {
        return ();
    }
    if ( $Param{UserData}->{UserID} ) {
        %UserData = $UserObject->GetUserData(
            UserID => $Param{UserData}->{UserID},
        );
    }

    my $Category = $ParamObject->GetParam( Param => 'PrefSearchProfileCategory' );
    my %SearchProfileCategories = ( '' => '-' );
    %SearchProfileCategories
        = ( %SearchProfileCategories, $SearchProfileObject->SearchProfileCategoryList() );

    if (
        !$Category
        && scalar keys %SearchProfileCategories
        && defined( $SearchProfileCategories{ ( sort( keys %SearchProfileCategories ) )[0] } )
        )
    {
        $Category = $SearchProfileCategories{ ( sort( keys %SearchProfileCategories ) )[0] };
    }

    my %SearchProfiles = $SearchProfileObject->SearchProfileList(
        Base            => 'TicketSearch',
        UserLogin       => $UserData{UserLogin},
        Category        => $Category,
        SubscriptedOnly => 1,
    );

    if ( !$Self->{Subaction} ) {

        push(
            @Params,
            {
                %Param,
                Block => 'SP'
            },
            {
                %Param,
                Key        => 'SearchProfileCategory',
                Name       => $LayoutObject->{LanguageObject}->Translate('Search Profile Category'),
                OptionStrg => $LayoutObject->BuildSelection(
                    Data        => \%SearchProfileCategories,
                    Name        => 'PrefSearchProfileCategory',
                    Translation => 0,
                    OptionTitle => 1,
                    Class       => 'Modernize'
                ),
                Block => 'SearchProfile'
            },
            {
                %Param,
                Key        => 'SearchProfileName',
                Name       => $LayoutObject->{LanguageObject}->Translate('Search Profile'),
                OptionStrg => $LayoutObject->BuildSelection(
                    Data        => $SearchProfiles{Data},
                    SelectedID  => $SearchProfiles{SelectedData},
                    Size        => 10,
                    Name        => 'SearchProfileName',
                    Translation => 0,
                    OptionTitle => 1,
                    Multiple    => 1,
                    Class       => 'Modernize'
                ),
                Block => 'SearchProfile'
            },
            {
                %Param,
                Block => 'SearchProfileSubmit'
            },
        );

    }

    return @Params;

}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
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

    # get type
    my $Type = $ParamObject->GetParam( Param => 'Type' );

    if ( !defined $Type || !$Type ) {

        my %UserData = $UserObject->GetUserData( UserID => $Self->{UserID} );
        my $SearchProfileCategory
            = $ParamObject->GetParam( Param => 'PrefSearchProfileCategory' );

        my %SearchProfiles = $SearchProfileObject->SearchProfileList(
            Base      => 'TicketSearch',
            UserLogin => $UserData{UserLogin},
            Category  => $SearchProfileCategory,
        );

        my %SearchProfileCategories = $SearchProfileObject->SearchProfileCategoryList();

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'SearchProfileName',
                    Data         => $SearchProfiles{Data},
                    SelectedID   => $SearchProfiles{SelectedData},
                    Translation  => 0,
                    PossibleNone => 0,
                    Class => 'Modernize'
                },
                {
                    Name         => 'PrefSearchProfileCategory',
                    Data         => \%SearchProfileCategories,
                    SelectedID   => $SearchProfileCategory,
                    Translation  => 0,
                    PossibleNone => 0,
                    Class => 'Modernize'
                },
            ],
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );

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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
