# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Preferences::RemoveArticleFlags;

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
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

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

    # get config
    $Self->{Config} = $ConfigObject->Get('Ticket::Frontend::AgentTicketZoomTabArticle');
    my %ArticleFlagList = ();
    if ( defined $Self->{Config}->{ArticleFlags} && ref $Self->{Config}->{ArticleFlags} eq 'HASH' )
    {
        %ArticleFlagList = %{ $Self->{Config}->{ArticleFlags} };
    }

    my %ArticleFlags;
    for my $Flag ( keys %ArticleFlagList ) {
        next if !defined $Self->{Config}->{ArticleFlagsRemoveOnTicketClose}->{$Flag};
        next if $Self->{Config}->{ArticleFlagsRemoveOnTicketClose}->{$Flag} ne 'UserPref';
        $ArticleFlags{$Flag} = $ArticleFlagList{$Flag};
    }

    # get user preferences
    my %UserPreferences
        = $UserObject->GetPreferences( UserID => $Param{UserData}->{UserID} );

    # if user preferences are set split preferences string
    my @ArticleFlagsDeleteOnCloseArray;
    if (
        defined $UserPreferences{ArticleFlagsRemoveOnClose}
        && $UserPreferences{ArticleFlagsRemoveOnClose}
        )
    {
        @ArticleFlagsDeleteOnCloseArray
            = split( /\;/, $UserPreferences{ArticleFlagsRemoveOnClose} );
    }

    if ( !$Self->{Subaction} ) {

        push(
            @Params,
            {
                %Param,
                Block => 'SP'
            },
            {
                %Param,
                Key => 'RemoveArticleFlags',
                Name =>
                    $LayoutObject->{LanguageObject}->Translate('Removable Article Flag'),
                OptionStrg => $LayoutObject->BuildSelection(
                    Name => 'RemoveArticleFlags',
                    Data => \%ArticleFlags,

                    SelectedID  => \@ArticleFlagsDeleteOnCloseArray,
                    Size        => 5,
                    Translation => 1,
                    OptionTitle => 1,
                    Multiple    => 1,
                    Class => 'Modernize'
                ),
                Block => 'RemoveArticleFlags'
            },
        );

    }

    return @Params;

}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');

    my @FlagsToRemove = $ParamObject->GetArray( Param => 'RemoveArticleFlags' );

    return 1 if !scalar @FlagsToRemove;

    my $PreferencesString = join( ";", @FlagsToRemove );

    # pref update db
    if ( !$ConfigObject->Get('DemoSystem') ) {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'ArticleFlagsRemoveOnClose',
            Value  => $PreferencesString,
        );
    }

    # update SessionID
    $SessionObject->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'ArticleFlagsRemoveOnClose',
        Value     => $PreferencesString,
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
