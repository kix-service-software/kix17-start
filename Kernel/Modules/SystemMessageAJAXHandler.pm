# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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
    'Kernel::System::CustomerUser'
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

    my %UserReads = map( { $_ => 1 } split( /;/, $Preferences{UserMessageRead} || '') );

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
        my %MessageList = $SystemMessageObject->MessageList(
            Valid  => 0,
        );

        $UserReads{$MessageID} = 1;

        for my $ID ( keys %UserReads ) {
            my %MessageData = $SystemMessageObject->MessageGet(
                MessageID => $ID
            );

            if (
                !%MessageData
                || $ValidObject->ValidLookup( ValidID => $MessageData{ValidID}) ne 'valid'
            ) {
                delete $UserReads{$ID}
            }
        }

        if ( $Self->{UserType} eq 'Customer' ) {
            $CustomerUserObject->SetPreferences(
                Key    => 'UserMessageRead',
                Value  => join( ';', keys %UserReads ),
                UserID => $Self->{UserID},
            );
        }
        elsif ( $Self->{UserType} eq 'User' ) {
            $UserObject->SetPreferences(
                Key    => 'UserMessageRead',
                Value  => join( ';', keys %UserReads ),
                UserID => $Self->{UserID},
            );
        }

        $Output = 1;
    }

    elsif ( $Module eq 'Header' ) {
        my $SBAgentAction    = $ConfigObject->Get('Frontend::KIXSidebarBackend')->{KIXSBSystemMessage}->{Actions}         || '';
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
            ) {
                $IsShow = 1;
            }
        }

        elsif ( $CallingAction =~ /^Public/ ) {
            $IsShow   = 1;
            $UserID   = '';
            $UserType = '';
        }

        if ( $IsShow ) {
            my %MessageList = $SystemMessageObject->MessageSearch(
                Action   => $CallingAction,
                Valid    => 1,
                UserID   => $UserID,
                UserType => $UserType
            );

            if ( %MessageList ) {
                $LayoutObject->Block(
                    Name => 'SystemMessageWidget',
                    Data => {
                    },
                );

                if ( $Config->{ShowTeaser} ) {
                    $LayoutObject->Block(
                        Name => 'SystemMessageHeadTeaser',
                    );
                }

                if ( $Config->{ShowCreatedBy} ) {
                    $LayoutObject->Block(
                        Name => 'SystemMessageHeadCreatedBy',
                    );
                }

                # show messages
                for my $MessageID ( sort keys %MessageList ) {

                    # get message data
                    my %MessageData = $SystemMessageObject->MessageGet(
                        MessageID => $MessageID,
                    );

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

                # check if content got shown, if true, render block
                my %Response;
                $Response{Content} = $LayoutObject->Output(
                    TemplateFile => 'SystemMessageDialog',
                    Data         => {
                    },
                );
                $Output = $LayoutObject->JSONEncode(
                    Data => \%Response
                );
            } else {
                $Output = 1;
            }
        } else {
            $Output = 1;
        }
    }

    elsif ( $Module eq 'KIXSidebar' ) {

        my %MessageList = $SystemMessageObject->MessageSearch(
            Action   => $CallingAction,
            Valid    => 1,
            UserID   => $Self->{UserID},
            UserType => $Self->{UserType}
        );

        if ( %MessageList ) {
            $LayoutObject->Block(
                Name => 'KIXSidebarMessageResult',
                Data => {
                    %Param,
                    Identifier    => $Self->{Identifier} || $Identifier,
                    TranslateText => \%TranslateText
                },
            );

            for my $MessageID ( sort keys %MessageList ) {

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
