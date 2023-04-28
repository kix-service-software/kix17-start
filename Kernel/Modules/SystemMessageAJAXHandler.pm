# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::SystemMessageAJAXHandler;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::User',
    'Kernel::System::Valid',
    'Kernel::System::Web::Request',
    'Kernel::System::SystemMessage',
    'Kernel::System::CustomerUser',
    'Kernel::System::JSON',
    'Kernel::System::Time'
);

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
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject         = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SystemMessageObject = $Kernel::OM->Get('Kernel::System::SystemMessage');
    my $UserObject          = $Kernel::OM->Get('Kernel::System::User');
    my $CustomerUserObject  = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ValidObject         = $Kernel::OM->Get('Kernel::System::Valid');
    my $JSONObject          = $Kernel::OM->Get('Kernel::System::JSON');
    my $TimeObject          = $Kernel::OM->Get('Kernel::System::Time');

    my $Config        = $ConfigObject->Get('SystemMessage');
    my $Identifier    = $ParamObject->GetParam( Param => 'Identifier' )    || '';
    my $CallingAction = $ParamObject->GetParam( Param => 'CallingAction' ) || '';
    my $Module        = $ParamObject->GetParam( Param => 'Module' )        || '';
    my $MessageID     = $ParamObject->GetParam( Param => 'MessageID' )     || '';
    my %TranslateText = (
        MarkAsRead      => $LayoutObject->{LanguageObject}->Translate('Mark as read'),
        MarkAsReadClose => $LayoutObject->{LanguageObject}->Translate('Mark as read and close'),
        ReadMessage     => $LayoutObject->{LanguageObject}->Translate('Read this message'),
        Close           => $LayoutObject->{LanguageObject}->Translate('Close'),
    );

    # get user preferences
    my %Preferences;
    if ( defined( $Self->{UserType} ) ) {
        if ( $Self->{UserType} eq 'Customer' ) {
            %Preferences = $CustomerUserObject->GetPreferences(
                UserID => $Self->{UserID},
            );
        }
        elsif ( $Self->{UserType} eq 'User' ) {
            %Preferences = $UserObject->GetPreferences(
                UserID => $Self->{UserID},
            );
        }
    }

    my %UserReads;
    if ( $Preferences{UserMessageRead} ) {
        my $JSONData = $JSONObject->Decode(
            Data => $Preferences{UserMessageRead}
        );
        %UserReads = %{$JSONData};
    }

    my $Output = '&nbsp;';
    if ( $Self->{Subaction} eq 'AJAXMessageGet' ) {
        my %MessageData = $SystemMessageObject->MessageGet(
            MessageID => $MessageID
        );

        %MessageData = (
            %MessageData,
            %{$Config},
            TranslateText => \%TranslateText,
        );

        $MessageData{MarkAsRead} = '1';
        if (
            $UserReads{$MessageID}
            || $CallingAction =~ /^Public/
        ) {
            $MessageData{MarkAsRead} = 0;
        }

        $MessageData{Body} = $LayoutObject->Ascii2Html(
            Text           => $MessageData{Body},
            HTMLResultMode => 1
        );

        $LayoutObject->Block(
            Name => 'SystemMessageDialog',
            Data => \%MessageData
        );

        if ( $Config->{ShowTeaser} ) {

            $LayoutObject->Block(
                Name =>  'SystemMessageTeaser',
                Data => \%MessageData
            );
        }

        if ( $Config->{ShowCreatedBy} ) {
            my %UserData = $UserObject->GetUserData(
                UserID => $MessageData{CreatedBy}
            );

            $LayoutObject->Block(
                Name => 'SystemMessageCreateBy',
                Data => \%UserData
            );
        }

        # output result
        $MessageData{Content} = $LayoutObject->Output(
            TemplateFile => 'SystemMessageDialog',
            Data         => {
                %Param,
            },
            KeepScriptTags => 1,
        );

        $Output = $LayoutObject->JSONEncode(
            Data => \%MessageData
        );
    }

    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {

        $UserReads{$MessageID} = $TimeObject->SystemTime();

        my $NewUserReads = $JSONObject->Encode(
            Data => \%UserReads
        );

        if ( $Self->{UserType} eq 'Customer' ) {
            $CustomerUserObject->SetPreferences(
                Key    => 'UserMessageRead',
                Value  => $NewUserReads,
                UserID => $Self->{UserID},
            );
        }
        elsif ( $Self->{UserType} eq 'User' ) {
            $UserObject->SetPreferences(
                Key    => 'UserMessageRead',
                Value  => $NewUserReads,
                UserID => $Self->{UserID},
            );
        }

        $Output = 1;
    }

    elsif ( $Module eq 'Header' ) {
        my $SBAgentAction    = $ConfigObject->Get('Frontend::KIXSidebarBackend')->{KIXSBSystemMessage}->{Actions}         || '';
        my $AgentDashboard   = $ConfigObject->Get('DashboardBackend')->{'0000-SystemMessage'}                             || '';
        my $SBCustomerAction = $ConfigObject->Get('CustomerFrontend::KIXSidebarBackend')->{KIXSBSystemMessage}->{Actions} || '';
        my $IsShow           = 0;
        my $UserID           = $Self->{UserID};
        my $UserType         = $Self->{UserType};
        if ( $CallingAction =~ /^Customer/ ) {
            if (
                $CallingAction ne 'CustomerLogin'
                && $CallingAction !~ /$SBCustomerAction/
            ) {
                $IsShow = 1;
            }
        }

        elsif ( $CallingAction =~ /^Agent/ ) {
            if (
                $CallingAction ne 'Login'
                && $CallingAction !~ /$SBAgentAction/
                && (
                    $CallingAction ne 'AgentDashboard'
                    || !$AgentDashboard
                )
            ) {
                $IsShow = 1;
            }
        }

        elsif ( $CallingAction =~ /^Public/ ) {
            $IsShow   = 1;
            $UserID   = '';
            $UserType = '';
        }

        # init response data
        my %Response = ();

        # get message list
        my @MessageIDList = $SystemMessageObject->MessageSearch(
            Action   => $CallingAction,
            Valid    => 1,
            UserID   => $UserID,
            UserType => $UserType,
            SortBy   => 'Created',
            OrderBy  => 'Down',
            Result   => 'ARRAY'
        );

        # check if at least one message is available
        if ( scalar(@MessageIDList) ) {
            # check if messages should be shown by header
            if ( $IsShow ) {
                # init widget
                $LayoutObject->Block(
                    Name => 'SystemMessageWidget',
                    Data => {
                    },
                );

                # show teaser header if configured
                if ( $Config->{ShowTeaser} ) {
                    $LayoutObject->Block(
                        Name => 'SystemMessageHeadTeaser',
                    );
                }

                # show created by header if configured
                if ( $Config->{ShowCreatedBy} ) {
                    $LayoutObject->Block(
                        Name => 'SystemMessageHeadCreatedBy',
                    );
                }
            }

            # process messages
            for my $MessageID ( @MessageIDList ) {
                # get message data
                my %MessageData = $SystemMessageObject->MessageGet(
                    MessageID => $MessageID,
                );

                # check for popup message
                if (
                    !$Response{PopupID}
                    && !$UserReads{$MessageID}
                    && ref( $MessageData{PopupTemplates} ) eq 'ARRAY'
                    && grep( { $CallingAction eq $_ } @{$MessageData{PopupTemplates}} )
                ) {
                    $Response{PopupID} = $MessageID;
                }

                # check if messages should be shown by header
                if ( $IsShow ) {
                    $LayoutObject->Block(
                        Name => 'SystemMessageRow',
                        Data => \%MessageData
                    );

                    if ( $Config->{ShowTeaser} ) {
                        $LayoutObject->Block(
                            Name => 'SystemMessageColumnTeaser',
                            Data => \%MessageData
                        );
                    }

                    if ( $Config->{ShowCreatedBy} ) {

                        my %UserData = $UserObject->GetUserData(
                            UserID => $MessageData{CreatedBy}
                        );

                        $LayoutObject->Block(
                            Name => 'SystemMessageColumnCreatedBy',
                            Data => \%UserData
                        );
                    }
                }
            }

            # check if messages should be shown by header
            if ( $IsShow ) {
                # render output
                $Response{Content} = $LayoutObject->Output(
                    TemplateFile => 'SystemMessageDialog',
                    Data         => {},
                );
            }
        }

        $Output = $LayoutObject->JSONEncode(
            Data => \%Response
        );
    }

    elsif ( $Module eq 'KIXSidebar' ) {

        my @MessageIDList = $SystemMessageObject->MessageSearch(
            Action   => $CallingAction,
            Valid    => 1,
            UserID   => $Self->{UserID},
            UserType => $Self->{UserType},
            SortBy   => 'Created',
            OrderBy  => 'Down',
            Result   => 'ARRAY'
        );

        if ( scalar(@MessageIDList) ) {
            $LayoutObject->Block(
                Name => 'KIXSidebarMessageResult',
                Data => {
                    %Param,
                    Identifier    => $Self->{Identifier} || $Identifier,
                    TranslateText => \%TranslateText
                },
            );

            for my $MessageID ( @MessageIDList ) {

                my %MessageData = $SystemMessageObject->MessageGet(
                    MessageID => $MessageID
                );

                $LayoutObject->Block(
                    Name => 'KIXSidebarMessageResultRow',
                    Data => {
                        %MessageData,
                        %TranslateText,
                        Identifier => $Self->{Identifier} || $Identifier,
                    }
                );
            }

            # output result
            $Output = $LayoutObject->Output(
                TemplateFile => 'KIXSidebar/SystemMessage',
                Data         => {
                    Identifier => $Self->{Identifier} || $Identifier,
                },
                KeepScriptTags => 1,
            );
        }
    }

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $Output || '',
        Type        => 'inline',
        NoCache     => 1,
    );
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
