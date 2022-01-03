# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::Modules::AdminMailAccount;

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

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $MailAccount  = $Kernel::OM->Get('Kernel::System::MailAccount');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    my %GetParam = ();
    my @Params   = (
### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
#        qw(ID Login Password Host Type TypeAdd Comment ValidID QueueID IMAPFolder Trusted DispatchingBy)
        qw(ID Login Password Host Type TypeAdd Comment ValidID QueueID IMAPFolder Trusted DispatchingBy OAuth2_ProfileID)
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
    );
    for my $Parameter (@Params) {
        $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter );
    }

    # ------------------------------------------------------------ #
    # Run
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Run' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my %Data = $MailAccount->MailAccountGet(%GetParam);
        if ( !%Data ) {
            return $LayoutObject->ErrorScreen();
        }

        my $Ok = $MailAccount->MailAccountFetch(
            %Data,
            Limit  => 15,
            UserID => $Self->{UserID},
        );
        if ( !$Ok ) {
            return $LayoutObject->ErrorScreen();
        }
        return $LayoutObject->Redirect( OP => 'Action=AdminMailAccount;Ok=1' );
    }

    # ------------------------------------------------------------ #
    # delete
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Delete' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Delete = $MailAccount->MailAccountDelete(%GetParam);
        if ( !$Delete ) {
            return $LayoutObject->ErrorScreen();
        }
        return $LayoutObject->Redirect( OP => 'Action=AdminMailAccount' );
    }

    # ------------------------------------------------------------ #
    # add new mail account
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddNew' ) {
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_MaskAddMailAccount(
            Action => 'AddNew',
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminMailAccount',
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

        my %Errors;
### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
        my $OAuth2 = ( $GetParam{TypeAdd} && $GetParam{TypeAdd} =~ /_OAuth2$/ ) ? 1 : 0;
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###

       # check needed data
### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
#        for my $Needed (qw(Login Password Host)) {
        for my $Needed ( qw(Login Host), ( $OAuth2 ? qw() : qw(Password) ) ) {
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'AddInvalid' } = 'ServerError';
            }
        }
### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
#        for my $Needed (qw(TypeAdd ValidID)) {
        for my $Needed ( qw(TypeAdd ValidID), ( $OAuth2 ? qw(OAuth2_ProfileID) : qw() ) ) {
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # if no errors occurred
        if ( !%Errors ) {
            # add mail account
            my $ID = $MailAccount->MailAccountAdd(
                %GetParam,
                Type   => $GetParam{'TypeAdd'},
                UserID => $Self->{UserID},
            );
            if ($ID) {
                # load overview
                $Self->_Overview();
                my $Output = $LayoutObject->Header();
                $Output .= $LayoutObject->NavigationBar();
                $Output .= $LayoutObject->Notify( Info => Translatable('Mail account added!') );
                $Output .= $LayoutObject->Output(
                    TemplateFile => 'AdminMailAccount',
                    Data         => \%Param,
                );
                $Output .= $LayoutObject->Footer();
                return $Output;
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => 'Error' );
        $Self->_MaskAddMailAccount(
            Action => 'AddNew',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminMailAccount',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # update
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Update' ) {
        my %Data   = $MailAccount->MailAccountGet(%GetParam);
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Self->_MaskUpdateMailAccount(
            Action => 'Update',
            %Data,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminMailAccount',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # update action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'UpdateAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my %Errors;
### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
        my $OAuth2 = ( $GetParam{TypeAdd} && $GetParam{TypeAdd} =~ /_OAuth2$/ ) ? 1 : 0;
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###

        # check needed data
### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
#        for my $Needed (qw(Login Password Host)) {
        for my $Needed ( qw(Login Host), ( $OAuth2 ? qw() : qw(Password) ) ) {
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'EditInvalid' } = 'ServerError';
            }
        }
### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
#        for my $Needed (qw(Type ValidID DispatchingBy QueueID)) {
        for my $Needed ( qw(Type ValidID DispatchingBy QueueID), ( $OAuth2 ? qw(OAuth2_ProfileID) : qw() ) ) {
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }
        if ( !$GetParam{Trusted} ) {
            $Errors{TrustedInvalid} = 'ServerError' if ( $GetParam{Trusted} != 0 );
        }

        # if no errors occurred
        if ( !%Errors ) {
            if ( $GetParam{Password} eq 'kix-dummy-password-placeholder' ) {
                my %OriginalData = $MailAccount->MailAccountGet(%GetParam);
                $GetParam{Password} = $OriginalData{Password};
            }

            # update mail account
            my $Update = $MailAccount->MailAccountUpdate(
                %GetParam,
                UserID => $Self->{UserID},
            );
            if ($Update) {
                # load overview
                $Self->_Overview();
                my $Output = $LayoutObject->Header();
                $Output .= $LayoutObject->NavigationBar();
                $Output .= $LayoutObject->Notify( Info => Translatable('Mail account updated!') );
                $Output .= $LayoutObject->Output(
                    TemplateFile => 'AdminMailAccount',
                    Data         => \%Param,
                );
                $Output .= $LayoutObject->Footer();
                return $Output;
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $LayoutObject->Notify( Priority => 'Error' );
        $Self->_MaskUpdateMailAccount(
            Action => 'Update',
            Errors => \%Errors,
            %GetParam,
        );
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminMailAccount',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    else {
        $Self->_Overview();

        my $Ok = $ParamObject->GetParam( Param => 'Ok' );
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        if ($Ok) {
            $Output .= $LayoutObject->Notify( Info => Translatable('Finished') );
        }
        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminMailAccount',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $MailAccount  = $Kernel::OM->Get('Kernel::System::MailAccount');

    my %Backend = $MailAccount->MailAccountBackendList();

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

    my %List = $MailAccount->MailAccountList( Valid => 0 );

    # if there are any mail accounts, they are shown
    if (%List) {
        for my $ListKey ( sort { $List{$a} cmp $List{$b} } keys %List ) {
            my %Data = $MailAccount->MailAccountGet( ID => $ListKey );
            if ( !$Backend{ $Data{Type} } ) {
                $Data{Type} .= '(not installed!)';
            }

            my @List = $Kernel::OM->Get('Kernel::System::Valid')->ValidIDsGet();
            $Data{ShownValid} = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                ValidID => $Data{ValidID},
            );

            $LayoutObject->Block(
                Name => 'OverviewResultRow',
                Data => \%Data,
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

sub _MaskUpdateMailAccount {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get valid list
    my %ValidList        = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();
    my %ValidListReverse = reverse %ValidList;

    # build ValidID string
    $Param{ValidOption} = $LayoutObject->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID} || $ValidListReverse{valid},
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'ValidIDInvalid'} || '' ),
    );

    $Param{TypeOption} = $LayoutObject->BuildSelection(
        Data       => { $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountBackendList() },
        Name       => 'Type',
        SelectedID => $Param{Type} || $Param{TypeAdd} || '',
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'TypeInvalid'} || '' ),
    );

    $Param{TrustedOption} = $LayoutObject->BuildSelection(
        Data       => $Kernel::OM->Get('Kernel::Config')->Get('YesNoOptions'),
        Name       => 'Trusted',
        SelectedID => $Param{Trusted} || 0,
        Class      => 'Modernize ' . ( $Param{Errors}->{'TrustedInvalid'} || '' ),
    );

    $Param{DispatchingOption} = $LayoutObject->BuildSelection(
        Data => {
            From  => Translatable('Dispatching by email To: field.'),
            Queue => Translatable('Dispatching by selected Queue.'),
        },
        Name       => 'DispatchingBy',
        SelectedID => $Param{DispatchingBy},
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'DispatchingByInvalid'} || '' ),
    );

    $Param{QueueOption} = $LayoutObject->AgentQueueListOption(
        Data           => { $Kernel::OM->Get('Kernel::System::Queue')->QueueList( Valid => 1 ) },
        Name           => 'QueueID',
        SelectedID     => $Param{QueueID},
        OnChangeSubmit => 0,
        Class => 'Modernize Validate_Required ' . ( $Param{Errors}->{'QueueIDInvalid'} || '' ),
    );

### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
    $Param{OAuth2_ProfileOption} = $LayoutObject->BuildSelection(
        Data        => { $Kernel::OM->Get('Kernel::System::OAuth2')->ProfileList( Valid => 1 ) },
        Name        => 'OAuth2_ProfileID',
        SelectedID  => $Param{OAuth2_ProfileID} || '',
        Class       => 'Modernize',
        PossibleNone => 1
    );
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
    $LayoutObject->Block(
        Name => 'Overview',
        Data => { %Param, },
    );
    $LayoutObject->Block(
        Name => 'ActionList',
    );
    $LayoutObject->Block(
        Name => 'ActionOverview',
    );
    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => {
            %Param,
            %{ $Param{Errors} },
        },
    );

    return 1;
}

sub _MaskAddMailAccount {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get valid list
    my %ValidList        = $Kernel::OM->Get('Kernel::System::Valid')->ValidList();
    my %ValidListReverse = reverse %ValidList;

    # build ValidID string
    $Param{ValidOption} = $LayoutObject->BuildSelection(
        Data       => \%ValidList,
        Name       => 'ValidID',
        SelectedID => $Param{ValidID} || $ValidListReverse{valid},
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'ValidIDInvalid'} || '' ),
    );

    $Param{TypeOptionAdd} = $LayoutObject->BuildSelection(
        Data       => { $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountBackendList() },
        Name       => 'TypeAdd',
        SelectedID => $Param{Type} || $Param{TypeAdd} || '',
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'TypeAddInvalid'} || '' ),
    );

    $Param{TrustedOption} = $LayoutObject->BuildSelection(
        Data  => $Kernel::OM->Get('Kernel::Config')->Get('YesNoOptions'),
        Name  => 'Trusted',
        Class => 'Modernize ' . ( $Param{Errors}->{'TrustedInvalid'} || '' ),
        SelectedID => $Param{Trusted} || 0,
    );

    $Param{DispatchingOption} = $LayoutObject->BuildSelection(
        Data => {
            From  => Translatable('Dispatching by email To: field.'),
            Queue => Translatable('Dispatching by selected Queue.'),
        },
        Name       => 'DispatchingBy',
        SelectedID => $Param{DispatchingBy},
        Class      => 'Modernize Validate_Required ' . ( $Param{Errors}->{'DispatchingByInvalid'} || '' ),
    );

    $Param{QueueOption} = $LayoutObject->AgentQueueListOption(
        Data           => { $Kernel::OM->Get('Kernel::System::Queue')->QueueList( Valid => 1 ) },
        Name           => 'QueueID',
        SelectedID     => $Param{QueueID},
        OnChangeSubmit => 0,
        Class => 'Modernize Validate_Required ' . ( $Param{Errors}->{'QueueIDInvalid'} || '' ),
    );

### Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
    $Param{OAuth2_ProfileOption} = $LayoutObject->BuildSelection(
        Data        => { $Kernel::OM->Get('Kernel::System::OAuth2')->ProfileList( Valid => 1 ) },
        Name        => 'OAuth2_ProfileID',
        SelectedID  => $Param{OAuth2_ProfileID} || '',
        Class       => 'Modernize',
        PossibleNone => 1
    );
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2022 Rother OSS GmbH, https://otobo.de/ ###
    $LayoutObject->Block(
        Name => 'Overview',
        Data => { %Param, },
    );
    $LayoutObject->Block(
        Name => 'ActionList',
    );
    $LayoutObject->Block(
        Name => 'ActionOverview',
    );
    $LayoutObject->Block(
        Name => 'OverviewAdd',
        Data => {
            %Param,
            %{ $Param{Errors} },
        },
    );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. This program is
licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
For details, see the enclosed files LICENSE (AGPL) and
LICENSE-GPL3 (GPL3) for license information. If you did not receive
this files, see <https://www.gnu.org/licenses/agpl.txt> (APGL) and
<https://www.gnu.org/licenses/gpl-3.0.txt> (GPL3).

=cut