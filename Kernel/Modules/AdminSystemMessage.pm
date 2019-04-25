# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminSystemMessage;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Log',
    'Kernel::System::Message',
    'Kernel::System::Time',
    'Kernel::System::Valid',
    'Kernel::System::Web::Request',
    'Kernel::System::Web::UploadCache',
);

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $UploadCacheObject   = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');
    my $TimeObject          = $Kernel::OM->Get('Kernel::System::Time');
    my $LogObject           = $Kernel::OM->Get('Kernel::System::Log');

    my $LanguageObject    = $LayoutObject->{LanguageObject};

    $Param{FormID} = $ParamObject->GetParam( Param => 'FormID' );
    if ( !$Param{FormID} ) {
        $Param{FormID} = $UploadCacheObject->FormIDCreate();
    }
    $Self->{FormID} = $Param{FormID};

    # ------------------------------------------------------------ #
    # return all displayed templates of the message
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'AJAXDisplay' ) {
        # get ID
        my $ID   = $ParamObject->GetParam( Param => 'MessageID' ) || '';
        my %Data = $SystemMessageObject->MessageGet(
            MessageID => $ID
        );
        my %Response;
        if ( %Data ) {
            $Response{Title}   = $Data{Title};
            $Response{Close}   = $LayoutObject->{LanguageObject}->Translate('Close');
            $Response{Content} = '<table class="DataTable">'
                . '<thead>'
                . '  <tr>'
                . '    <th>'
                . $LayoutObject->{LanguageObject}->Translate('Display')
                . '    </th>'
                . '  </tr>'
                . '</thead>'
                . '<tbody>';
            for my $Template ( @{$Data{Templates}} ) {
                $Response{Content} .= '<tr>'
                    . '  <td>'
                    . $Template
                    . '  </td>'
                    . '</tr>';
            }
            $Response{Content} .= '</tbody>'
                . '</table>';
        }

        my $JSONStrg = $LayoutObject->JSONEncode(
            Data => \%Response
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSONStrg || 1,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # ------------------------------------------------------------ #
    # delete
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Delete' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my $Note = '';

        # get ID
        my $ID = $ParamObject->GetParam( Param => 'MessageID' ) || '';

        if ( !$ID ) {
            return $LayoutObject->ErrorScreen(
                Message => "No ID is given!",
            );
        }

        my $Success = $SystemMessageObject->MessageDelete(
            ID => $ID,
        );

        if ( !$Success ) {
            $Note .= $LayoutObject->Notify( Priority => 'Error' );
        } else {
            $Note .= $LayoutObject->Notify(
                Info => $LanguageObject->Translate("Message deleted!")
            );
        }

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note;
        $Output .= $Self->_Overview();
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # -----------------------------------------------------------
    # add
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'Add' ) {
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_Mask(
            %Param
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # add action
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'AddAction' ) {
        my $Note = '';
        my %GetParam;
        my %Errors;

        for my $Needed ( qw(ValidID Title ShortText Body) ) {
            $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid'} = 'ServerError';
            }
        }

        for my $Needed ( qw(ValidFromUsed ValidToUsed UsedDashboard) ) {
            $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        }

        @{$GetParam{Templates}} = $ParamObject->GetArray( Param => 'Templates' );

        if (!scalar( @{$GetParam{Templates}} ) ) {
            $Errors{ 'TemplatesInvalid'} = 'ServerError';
        }

        if (
            $GetParam{ValidFromUsed}
            && $GetParam{ValidToUsed}
        ) {

            for my $Prefix ( qw(ValidFrom ValidTo) ) {
                my %TimeData;
                for my $Key ( qw(Year Month Day Hour Minute) ) {
                    $TimeData{$Key} = $ParamObject->GetParam( Param => $Prefix . $Key) || 0;
                }

                $GetParam{$Prefix} = $TimeObject->Date2SystemTime(
                    %TimeData,
                    Second => 0,
                );
            }
            if ( $GetParam{ValidFrom} > $GetParam{ValidTo} ) {
                $Errors{ 'ValidFromInvalid'} = 'ServerError';
                $Errors{ 'ValidToInvalid'}   = 'ServerError';
            }
        }

        elsif (
            $GetParam{ValidFromUsed}
            || $GetParam{ValidToUsed}
        ) {
            my $Prefix;
            if ( $GetParam{ValidFromUsed} ) {
                $Prefix = 'ValidFrom';
            } else {
                $Prefix = 'ValidTo';
            }
            my %TimeData;
            for my $Key ( qw(Year Month Day Hour Minute) ) {
                $TimeData{$Key} = $ParamObject->GetParam( Param => $Prefix . $Key) || 0;
            }

            $GetParam{$Prefix} = $TimeObject->Date2SystemTime(
                %TimeData,
                Second => 0,
            );
        }
        if ( !%Errors ) {

            my $MessageID = $SystemMessageObject->MessageAdd(
                %GetParam,
                UserID  => $Self->{UserID}
            );

            if ( $MessageID ) {

                my $Output = $LayoutObject->Header();
                $Output .= $LayoutObject->NavigationBar();
                $Output .= $Note;
                $Output .= $LayoutObject->Notify(
                    Info => $LanguageObject->Translate("Message added!") );
                $Output .= $Self->_Overview();
                $Output .= $LayoutObject->Footer();

                return $Output;
            } else {
                $Note .= $LayoutObject->Notify( Priority => 'Error' );
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note;
        $Output .= $Self->_Mask(
            %Param,
            %GetParam,
            %Errors
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # change
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'Change' ) {
        my $ID = $ParamObject->GetParam( Param => 'MessageID' );

        my %Data = $SystemMessageObject->MessageGet(
            MessageID => $ID
        );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Self->_Mask(
            %Param,
            %Data
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # change action
    # -----------------------------------------------------------
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {
        my $Note = '';
        my %GetParam;
        my %Errors;

        for my $Needed ( qw(ValidID MessageID Title ShortText Body) ) {
            $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid'} = 'ServerError';
            }
        }

        for my $Needed ( qw(ValidFromUsed ValidToUsed UsedDashboard) ) {
            $GetParam{$Needed} = $ParamObject->GetParam( Param => $Needed ) || '';
        }

        @{$GetParam{Templates}} = $ParamObject->GetArray( Param => 'Templates' );

        if (!scalar( @{$GetParam{Templates}} ) ) {
            $Errors{ 'TemplatesInvalid'} = 'ServerError';
        }

        if (
            $GetParam{ValidFromUsed}
            && $GetParam{ValidToUsed}
        ) {

            for my $Prefix ( qw(ValidFrom ValidTo) ) {
                my %TimeData;
                for my $Key ( qw(Year Month Day Hour Minute) ) {
                    $TimeData{$Key} = $ParamObject->GetParam( Param => $Prefix . $Key) || 0;
                }

                $GetParam{$Prefix} = $TimeObject->Date2SystemTime(
                    %TimeData,
                    Second => 0,
                );
            }
            if ( $GetParam{ValidFrom} > $GetParam{ValidTo} ) {
                $Errors{ 'ValidFromInvalid'} = 'ServerError';
                $Errors{ 'ValidToInvalid'}   = 'ServerError';
            }
        }

        elsif (
            $GetParam{ValidFromUsed}
            || $GetParam{ValidToUsed}
        ) {
            my $Prefix;
            if ( $GetParam{ValidFromUsed} ) {
                $Prefix = 'ValidFrom';
            } else {
                $Prefix = 'ValidTo';
            }
            my %TimeData;
            for my $Key ( qw(Year Month Day Hour Minute) ) {
                $TimeData{$Key} = $ParamObject->GetParam( Param => $Prefix . $Key) || 0;
            }

            $GetParam{$Prefix} = $TimeObject->Date2SystemTime(
                %TimeData,
                Second => 0,
            );
        }

        if ( !%Errors ) {
            my $Success = $SystemMessageObject->MessageUpdate(
                %GetParam,
                UserID  => $Self->{UserID}
            );

            if ( $Success ) {

                my $Output = $LayoutObject->Header();
                $Output .= $LayoutObject->NavigationBar();
                $Output .= $Note;
                $Output .= $LayoutObject->Notify(
                    Info => $LanguageObject->Translate("Message updated!") );
                $Output .= $Self->_Overview();
                $Output .= $LayoutObject->Footer();

                return $Output;
            } else {
                $Note .= $LayoutObject->Notify( Priority => 'Error' );
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();
        $Output .= $Note;
        $Output .= $Self->_Mask(
            %Param,
            %GetParam,
            %Errors
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # -----------------------------------------------------------
    # overview
    # -----------------------------------------------------------

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $Self->_Overview(
        %Param
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _Mask {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $TimeObject          = $Kernel::OM->Get('Kernel::System::Time');

    my $Config =  $ConfigObject->Get("SystemMessage");

    my @TemplateList;
    for my $Key ( qw(Frontend CustomerFrontend PublicFrontend) ) {
        MODULE:
        for my $Module ( sort keys %{ $ConfigObject->Get( $Key . '::Module' ) } ) {
            next MODULE if $Module !~ /^(?:Customer|Login|Agent|Public)/;
            next MODULE if $Module =~ /(Handler|AJAXHandler|Add|Delete|Edit|Print|Event|Dashboard)$/;
            if (
                $Config->{ActionWhitelist}
                && IsArrayRefWithData($Config->{ActionWhitelist})
                && !grep( { $Module eq $_ } @{$Config->{ActionWhitelist}} )
            ) {
                next MODULE;
            }
            if (
                $Config->{ActionBlacklist}
                && IsArrayRefWithData($Config->{ActionBlacklist})
                && grep( { $Module eq $_ } @{$Config->{ActionBlacklist}} )
            ) {
                next MODULE;
            }
            next MODULE if grep( { $Module eq $_ } @TemplateList);
            push (@TemplateList, $Module);
        }
    }

    my %ValidList  = $ValidObject->ValidList();

    if ( !defined $Param{ValidIDInvalid} ) {
        $Param{ValidIDInvalid} = '';
    }
    if ( !defined $Param{TemplatesInvalid} ) {
        $Param{TemplatesInvalid} = '';
    }

    my $CurrentTime   = $TimeObject->SystemTime();
    my %Diffs = (
        ValidFrom => 0,
        ValidTo   => 86400
    );

    for ( qw(ValidFrom ValidTo) ) {
        my %TimeData;
        if ( $Param{$_} ) {
            my ($Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay) = $TimeObject->SystemTime2Date(
                SystemTime => $Param{$_},
            );

            %TimeData = (
                $_ . 'Year'     => $Year,
                $_ . 'Month'    => $Month,
                $_ . 'Day'      => $Day,
                $_ . 'Hour'     => $Hour,
                $_ . 'Minute'   => $Min,
                $_ . 'Second'   => $Sec,
                $_ . 'Used'     => 1,
            );
        } else {
            my ($Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay) = $TimeObject->SystemTime2Date(
                SystemTime => $CurrentTime + $Diffs{$_},
            );

            %TimeData = (
                $_ . 'Year'     => $Year,
                $_ . 'Month'    => $Month,
                $_ . 'Day'      => $Day,
                $_ . 'Hour'     => $Hour,
                $_ . 'Minute'   => $Min,
                $_ . 'Second'   => $Sec,
            );
        }

        $Param{$_ . 'Option'} = $LayoutObject->BuildDateSelection(
            %TimeData,
            Prefix          => $_,
            Format          => 'DateInputFormatLong',
            $_ . 'Optional' => 1
        );
    }

    $Param{ValidIDOption} = $LayoutObject->BuildSelection(
        Name         => 'ValidID',
        Data         => \%ValidList,
        Translation  => 1,
        SelectedID   => $Param{ValidID} || '',
        Class        => 'Modernize Validate_Required ' . $Param{ValidIDInvalid}
    );

    $Param{TemplatesOption} = $LayoutObject->BuildSelection(
        Name         => 'Templates',
        Data         => \@TemplateList,
        SelectedID   => $Param{Templates} || '',
        Class        => 'Modernize Validate_Required ' . $Param{TemplatesInvalid},
        Multiple     => 1,
        PossibleNone => 1,
        Translation  => 0
    );

    $Param{IsChecked} = 'checked="checked"' if $Param{UsedDashboard};

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview');

    $LayoutObject->Block(
        Name => 'OverviewEdit',
        Data => {
            %Param,
            Subaction  => $Param{Subaction} || $Self->{Subaction},
        }
    );

    return $LayoutObject->Output(
        TemplateFile => 'AdminSystemMessage',
        Data         => \%Param,
    );
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');

    $Param{Search} = $ParamObject->GetParam( Param => 'Search' ) || '*';

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block(
        Name => 'ActionSearch',
        Data => {
            Search => $Param{Search}
        }
    );
    $LayoutObject->Block( Name => 'ActionAdd' );

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    my %List = $SystemMessageObject->MessageSearch(
        Search => $Param{Search}. '*',
        Valid  => 0,
    );

    # print the list of quick states
    $Self->_PagingListShow(
        Messages => \%List,
        Total    => scalar keys %List,
        Search   => $Param{Search},
    );

    return $LayoutObject->Output(
        TemplateFile => 'AdminSystemMessage',
        Data         => \%Param,
    );
}

sub _PagingListShow {
    my ( $Self, %Param ) = @_;

    # need objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $TimeObject          = $Kernel::OM->Get('Kernel::System::Time');

    # check start option, if higher than fields available, set
    # it to the last field page
    my $StartHit = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

    # get personal page shown count
    my $PageShownPreferencesKey = 'AdminSystemMessageOverviewPageShown';
    my $PageShown               = $Self->{$PageShownPreferencesKey} || 35;
    my $Group                   = 'SystemMessageOverviewPageShown';

    # get data selection
    my %Data;
    my $Config = $ConfigObject->Get('PreferencesGroups');
    if (
        $Config
        && $Config->{$Group}
        && $Config->{$Group}->{Data}
    ) {
        %Data = %{ $Config->{$Group}->{Data} };
    }

    my $Session = '';
    if ($Self->{SessionID}
        && !$ConfigObject->Get('SessionUseCookie')
    ) {
        $Session = $ConfigObject->Get('SessionName') . '=' . $Self->{SessionID} . ';';
    }

    # calculate max. shown per page
    if ( $StartHit > $Param{Total} ) {
        my $Pages = int( ( $Param{Total} / $PageShown ) + 0.99999 );
        $StartHit = ( ( $Pages - 1 ) * $PageShown ) + 1;
    }
    # build nav bar
    my $Limit = $Param{Limit} || 20_000;
    my %PageNav = $LayoutObject->PageNavBar(
        Limit     => $Limit,
        StartHit  => $StartHit,
        PageShown => $PageShown,
        AllHits   => $Param{Total} || 0,
        Action    => 'Action=' . $LayoutObject->{Action},
        Link      => "Search=$Param{Search};",
        IDPrefix  => $LayoutObject->{Action},
    );

    # build shown dynamic fields per page
    $Param{RequestedURL}    = "Action=$Self->{Action}";
    $Param{Group}           = $Group;
    $Param{PreferencesKey}  = $PageShownPreferencesKey;
    $Param{PageShownString} = $LayoutObject->BuildSelection(
        Name        => $PageShownPreferencesKey,
        SelectedID  => $PageShown,
        Translation => 0,
        Data        => \%Data,
    );

    if (%PageNav) {
        $LayoutObject->Block(
            Name => 'OverviewNavBarPageNavBar',
            Data => \%PageNav,
        );

        $LayoutObject->Block(
            Name => 'ContextSettings',
            Data => { %PageNav, %Param, },
        );
    }

    my $MaxFieldOrder = 0;

    # check if at least 1 conversation guide is registered in the system
    if ( $Param{Total} ) {

        # get conversation guide details
        my $Counter = 0;
        my %List = %{$Param{Messages}};
         # get valid list
        my %ValidList = $ValidObject->ValidList();
        for my $ListKey ( sort { $List{$a} cmp $List{$b} } keys %List ) {
            $Counter++;
            if ( $Counter >= $StartHit && $Counter < ( $PageShown + $StartHit ) ) {
                my %MessageData = $SystemMessageObject->MessageGet(
                    MessageID => $ListKey,
                );

                if ( $ValidList{ $MessageData{ValidID} } ne 'valid' ) {
                    $MessageData{Invalid} = 'Invalid';
                }

                my %UserData = $UserObject->GetUserData(
                    UserID => $MessageData{CreatedBy}
                );
                if ( $MessageData{ValidFrom} ) {
                    $MessageData{ValidFrom} = $TimeObject->SystemTime2TimeStamp(
                        SystemTime => $MessageData{ValidFrom},
                    );
                }
                if ( $MessageData{ValidTo} ) {
                    $MessageData{ValidTo} = $TimeObject->SystemTime2TimeStamp(
                        SystemTime => $MessageData{ValidTo},
                    );
                }

                $LayoutObject->Block(
                    Name => 'OverviewResultRow',
                    Data => {
                        MessageID => $MessageData{MessageID},
                        Title     => $MessageData{Title},
                        ShortText => $MessageData{ShortText},
                        ValidFrom => $MessageData{ValidFrom} || '-',
                        ValidTo   => $MessageData{ValidTo}   || '-',
                        Username  => $UserData{UserFirstname} . ' ' . $UserData{UserLastname},
                        Valid     => $ValidList{ $Data{ValidID} },
                        Session   => $Session
                    },
                );
            }
        }
    }

    return;
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
