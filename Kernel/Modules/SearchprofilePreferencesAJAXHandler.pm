# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::SearchprofilePreferencesAJAXHandler;

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

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Result;

    my %UserData = $UserObject->GetUserData( UserID => $Self->{UserID} );
    my $SearchProfileCategory
        = $ParamObject->GetParam( Param => 'PrefSearchProfileCategory' );
    my @SearchProfiles    = $ParamObject->GetArray( Param => 'SearchProfileName' );
    my @SearchProfilesNew = $ParamObject->GetArray( Param => 'SearchProfileNewName' );

    # if no category selected return
    if ( !$SearchProfileCategory || $SearchProfileCategory eq '-' ) {
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content =>
                '<select id="SearchProfileName" size="10" name="SearchProfileName" multiple="multiple"> </select>',
            Type    => 'inline',
            NoCache => 1,
        );
    }

    # add link type for quick link
    if ( $Self->{Subaction} eq 'AJAXUpdate' ) {

        my %SearchProfiles = $SearchProfileObject->SearchProfileList(
            Base            => 'TicketSearch',
            UserLogin       => $UserData{UserLogin},
            Category        => $SearchProfileCategory,
            SubscriptedOnly => 1,
        );

        my $OptionStrg = $LayoutObject->BuildSelection(
            Data        => $SearchProfiles{Data},
            SelectedID  => $SearchProfiles{SelectedData},
            Size        => 10,
            Name        => 'SearchProfileName',
            Translation => 0,
            OptionTitle => 1,
            Multiple    => 1,
            Class       => 'Modernize'
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $OptionStrg,
            Type        => 'inline',
            NoCache     => 1,
        );

    }
    elsif ( $Self->{Subaction} eq 'Subscribe' ) {

        # delete subscribed profiles for this category
        $SearchProfileObject->SearchProfileCategoryDelete(
            Category  => $SearchProfileCategory,
            State     => 'subscriber',
            UserLogin => $UserData{UserLogin},
        );

        for my $Profile (@SearchProfiles) {

            $Profile =~ m/^(.*?)::(.*?)::(.*?)$/;

            my $Base  = $1;
            my $Login = $2;
            my $Name  = $3;

            # delete old copied profile with this name
            $SearchProfileObject->SearchProfileDelete(
                Base      => $Base,
                Name      => $Name,
                UserLogin => $UserData{UserLogin},
            );

            # add new subscribed profiles
            $SearchProfileObject->SearchProfileCategoryAdd(
                Name      => $Profile,
                Category  => $SearchProfileCategory,
                State     => 'subscriber',
                UserLogin => $UserData{UserLogin},
            );
        }

        my %SearchProfiles = $SearchProfileObject->SearchProfileList(
            Base            => 'TicketSearch',
            UserLogin       => $UserData{UserLogin},
            Category        => $SearchProfileCategory,
            SubscriptedOnly => 1,
        );

        my $OptionStrg = $LayoutObject->BuildSelection(
            Data        => $SearchProfiles{Data},
            SelectedID  => $SearchProfiles{SelectedData},
            Size        => 10,
            Name        => 'SearchProfileName',
            Translation => 0,
            OptionTitle => 1,
            Multiple    => 1,
            Class       => 'Modernize'
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $OptionStrg,
            Type        => 'inline',
            NoCache     => 1,
        );

    }

    elsif ( $Self->{Subaction} eq 'Copy' ) {

        my @ExistingProfiles = ();
        SEARCHPROFILE:
        for my $Profile (@SearchProfiles) {

            $Profile =~ m/^(.*?)::(.*?)::(.*?)$/;

            my $Base  = $1;
            my $Login = $2;
            my $Name  = $3;

            # check if search profile already exists
            my %ExistingSearchProfile = $SearchProfileObject->SearchProfileGet(
                Base      => $Base,
                Name      => $Name,
                UserLogin => $UserData{UserLogin},
            );

            if (%ExistingSearchProfile) {
                push @ExistingProfiles, $Profile;
                next SEARCHPROFILE;
            }

            # add new copied profiles
            $SearchProfileObject->SearchProfileCopy(
                Base      => $Base,
                Name      => $Name,
                OldLogin  => $Login,
                UserLogin => $UserData{UserLogin},
            );
        }

        # parse the fields dialogs as JSON structure
        my $JSONArray = $LayoutObject->JSONEncode(
            Data => \@ExistingProfiles
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSONArray,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    elsif ( $Self->{Subaction} eq 'CopyOverwrite' ) {

        for my $Profile (@SearchProfilesNew) {

            $Profile =~ m/^(.*?)::(.*?)::(.*?)\|\|(.*?)$/;

            my $Base    = $1;
            my $Login   = $2;
            my $Name    = $3;
            my $NewName = $4;

            if ( $NewName eq $Name ) {

                # delete old subscribed profile with this name
                # other search profiles with same name will be deleted in SearchProfileCopy()
                $SearchProfileObject->SearchProfileCategoryDelete(
                    Category  => $SearchProfileCategory,
                    State     => 'subscriber',
                    UserLogin => $UserData{UserLogin},
                    Name      => $1.'::'.$2.'::'.$3,
                );

            }

            # add new copied profile
            $SearchProfileObject->SearchProfileCopy(
                Base      => $Base,
                Name      => $Name,
                NewName   => $NewName,
                OldLogin  => $Login,
                UserLogin => $UserData{UserLogin},
            );

        }

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => 1,
            Type        => 'inline',
            NoCache     => 1,
        );

    }

    return 1;
}

1;
