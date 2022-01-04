# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminOAuth2Profile;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

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

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $OAuth2Object = $Kernel::OM->Get('Kernel::System::OAuth2');

    # ------------------------------------------------------------ #
    # change
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Change' ) {
        my $ID   = $ParamObject->GetParam( Param => 'ID' ) || '';
        my %Data = $OAuth2Object->ProfileGet( ID => $ID );
        if ( !%Data ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ID of profile!'),
            );
        }
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_Edit(
            Action => 'Change',
            %Data,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminOAuth2Profile',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # change action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';
        my ( %GetParam, %Errors );
        for my $Parameter (qw(ID Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID)) {
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        # check needed data
        for my $Needed (qw(Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        my %Data = $OAuth2Object->ProfileGet( ID => $GetParam{ID} );
        if ( !%Data ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ID of profile!'),
            );
        }

        # check if a profile with this name already exists
        my $ExistingID = $OAuth2Object->ProfileLookup(
           Name => $GetParam{Name},
        );
        if (
            $ExistingID
            && $ExistingID != $GetParam{ID}
        ) {
            $Errors{NameExists} = 1;
            $Errors{'NameInvalid'} = 'ServerError';
        }

        # if no errors occurred
        if ( !%Errors ) {
            if ( $GetParam{ClientSecret} eq 'kix-dummy-secret-placeholder' ) {
                $GetParam{ClientSecret} = $Data{ClientSecret};
            }

            # update profile
            my $Update = $OAuth2Object->ProfileUpdate(
                %GetParam,
                UserID => $Self->{UserID}
            );
            if ($Update) {
                # check for refresh token
                my %TokenList = $OAuth2Object->TokenList(
                    ProfileID => $GetParam{ID},
                );

                # redirect to authorization if refresh token is missing
                if ( !$TokenList{'refresh'} ) {
                    my %AuthURL = $OAuth2Object->PrepareAuthURL(
                        %GetParam
                    );

                    # set state token
                    my $Success = $OAuth2Object->TokenAdd(
                        ProfileID => $GetParam{ID},
                        TokenType => 'state',
                        Token     => $AuthURL{State},
                    );
                    if ( !$Success ) {
                        return $LayoutObject->ErrorScreen(
                            Message => Translatable('Could not save state token for authentification!'),
                        );
                    }

                    # redirect to external site
                    return $LayoutObject->Redirect( ExtURL => $AuthURL{URL} );
                }
                # redirect to overview
                else {
                    $Self->_Overview();
                    my $Output = $LayoutObject->Header();
                    $Output .= $LayoutObject->NavigationBar();
                    $Output .= $LayoutObject->Notify( Info => Translatable('Profile updated!') );
                    $Output .= $LayoutObject->Output(
                        TemplateFile => 'AdminOAuth2Profile',
                        Data         => \%Param,
                    );
                    $Output .= $LayoutObject->Footer();
                    return $Output;
                }
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => 'Error' );
        $Self->_Edit(
            Action => 'Change',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminOAuth2Profile',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' ) {
        my %GetParam = (
            URLRedirect => $ConfigObject->Get('HttpType')
                         . '://'
                         . $ConfigObject->Get('FQDN')
                         . '/'
                         . $ConfigObject->Get('ScriptAlias')
                         . 'index.pl?Action=AdminOAuth2Profile&Subaction=ProcessAuthCode'
        );
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_Edit(
            %GetParam,
            Action => 'Add',
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminOAuth2Profile',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # add action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';
        my ( %GetParam, %Errors );
        for my $Parameter (qw(Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID)) {
            $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        # check needed data
        for my $Needed (qw(Name URLAuth URLToken URLRedirect ClientID ClientSecret Scope ValidID)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # check if a profile with this name already exists
        my $ExistingID = $OAuth2Object->ProfileLookup(
            Name => $GetParam{Name},
        );
        if ($ExistingID) {
            $Errors{NameExists} = 1;
            $Errors{'NameInvalid'} = 'ServerError';
        }

        # if no errors occurred
        if ( !%Errors ) {

            # add type
            my $NewProfileID = $OAuth2Object->ProfileAdd(
                %GetParam,
                UserID => $Self->{UserID}
            );
            if ( $NewProfileID ) {
                # redirect to authorization
                my %AuthURL = $OAuth2Object->PrepareAuthURL(
                    %GetParam
                );

                # set state token
                my $Success = $OAuth2Object->TokenAdd(
                    ProfileID => $NewProfileID,
                    TokenType => 'state',
                    Token     => $AuthURL{State},
                );
                if ( !$Success ) {
                    return $LayoutObject->ErrorScreen(
                        Message => Translatable('Could not save state token for authentification!'),
                    );
                }

                # redirect to external site
                return $LayoutObject->Redirect( ExtURL => $AuthURL{URL} );
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => 'Error' );
        $Self->_Edit(
            Action => 'Add',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminOAuth2Profile',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # delete
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Delete' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $ID = $ParamObject->GetParam( Param => 'ID' ) || '';

        my $Delete = $OAuth2Object->ProfileDelete(
            ID => $ID,
        );
        if ( !$Delete ) {
            return $LayoutObject->ErrorScreen();
        }

        $Self->_Overview();
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Info => Translatable('Profile deleted!') );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminOAuth2Profile',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # reauthorization
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Reauthorization' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $ID = $ParamObject->GetParam( Param => 'ID' ) || '';

        my %Data = $OAuth2Object->ProfileGet( ID => $ID );
        if ( !%Data ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Need ID of profile!'),
            );
        }

        # delete token of profile
        return if !$OAuth2Object->TokenDelete(
            ProfileID => $ID
        );

        my %AuthURL = $OAuth2Object->PrepareAuthURL(
            %Data
        );

        # set state token
        my $Success = $OAuth2Object->TokenAdd(
            ProfileID => $ID,
            TokenType => 'state',
            Token     => $AuthURL{State},
        );
        if ( !$Success ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Could not save state token for authentification!'),
            );
        }

        # redirect to external site
        return $LayoutObject->Redirect( ExtURL => $AuthURL{URL} );
    }

    # ------------------------------------------------------------ #
    # process authorization code
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ProcessAuthCode' ) {

        my %OAuth2Param;
        for my $Parameter (qw(state code session_state error error_description)) {
            $OAuth2Param{$Parameter} = $ParamObject->GetParam( Param => $Parameter ) || '';
        }

        if ($OAuth2Param{code} && $OAuth2Param{state}) {
            # get matching profile
            my $ProfileID = $OAuth2Object->TokenLookup(
                TokenType => 'state',
                Token     => $OAuth2Param{state},
            );
            if ( !$ProfileID ) {
                return $LayoutObject->ErrorScreen(
                    Message => Translatable('Could not find profile for provided state!'),
                );
            }

            # delete state token
            $OAuth2Object->TokenDelete(
                ProfileID => $ProfileID,
                TokenType => 'state',
            );

            # Get an access and refresh token.
            my $AccessToken = $OAuth2Object->RequestAccessToken(
                ProfileID => $ProfileID,
                GrantType => 'authorization_code',
                Code      => $OAuth2Param{code},
            );
            if ( !$AccessToken ) {
                return $LayoutObject->ErrorScreen(
                    Message => Translatable('Could not get access token!'),
                );
            }

            $Self->_Overview();
            my $Output = $LayoutObject->Header();
            $Output .= $LayoutObject->NavigationBar();
            $Output .= $LayoutObject->Notify( Info => Translatable('Profile activated!') );
            $Output .= $LayoutObject->Output(
                TemplateFile => 'AdminOAuth2Profile',
                Data         => \%Param,
            );
            $Output .= $LayoutObject->Footer();
            return $Output;
        }

        # load overview with error message
        $Self->_Overview();
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        if (length $OAuth2Param{error} || length $OAuth2Param{error_description}) {
            $Output .= $LayoutObject->Notify(
                Priority => 'Error',
                Info => $OAuth2Param{error} . ':' . $OAuth2Param{error_description}
            );
        }
        else {
            $Output .= $LayoutObject->Notify(
                Priority => 'Error',
                Info => Translatable('Please check the log for more information.')
            );
        }
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminOAuth2Profile',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------
    # overview
    # ------------------------------------------------------------
    else {

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_Overview();
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminOAuth2Profile',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

}

sub _Edit {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview' );

    # get valid list
    my %ValidList        = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();
    my %ValidListReverse = reverse %ValidList;

    $Param{ValidOption} = $LayoutObject->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID} || $ValidListReverse{valid},
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'ValidIDInvalid'} || '' ),
    );

    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => {
            %Param,
            %{ $Param{Errors} },
        },
    );

    # shows header
    if ( $Param{Action} eq 'Change' ) {
        $LayoutObject->Block( Name => 'HeaderEdit' );
    }
    else {
        $LayoutObject->Block( Name => 'HeaderAdd' );
    }

    # show appropriate messages for ServerError
    if ( defined $Param{Errors}->{NameExists} && $Param{Errors}->{NameExists} == 1 ) {
        $LayoutObject->Block( Name => 'ExistNameServerError' );
    }
    else {
        $LayoutObject->Block( Name => 'NameServerError' );
    }
    return 1;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $OAuth2Object = $Kernel::OM->Get('Kernel::System::OAuth2');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionAdd' );

    $LayoutObject->Block(
        Name => 'OverviewResult',
        Data => \%Param,
    );

    # get profile list
    my %ProfileList = $OAuth2Object->ProfileList(
        Valid  => 0,
    );

    # if there are any profile, they are shown
    if (%ProfileList) {

        # get valid list
        my %ValidList = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();

        for my $ProfileID ( sort { $ProfileList{$a} cmp $ProfileList{$b} } keys %ProfileList ) {

            # get profile data
            my %Data = $OAuth2Object->ProfileGet(
                ID => $ProfileID,
            );

            # get token for profile
            my %TokenList = $OAuth2Object->TokenList(
                ProfileID => $ProfileID,
            );
            # check for refresh token
            $Data{RefreshTokenExists} = 0;
            if ( $TokenList{'refresh'} ) {
                $Data{RefreshTokenExists} = 1;
            }
            $LayoutObject->Block(
                Name => 'OverviewResultRow',
                Data => {
                    Valid => $ValidList{ $Data{ValidID} },
                    %Data,
                },
            );
        }
    }

    # otherwise a no data found msg is displayed
    else {
        $LayoutObject->Block(
            Name => 'NoDataFoundMsg',
            Data => {},
        );
    }
    return 1;
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
