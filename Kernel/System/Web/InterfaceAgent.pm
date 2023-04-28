# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Web::InterfaceAgent;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Auth',
    'Kernel::System::AuthSession',
    'Kernel::System::DB',
    'Kernel::System::Email',
    'Kernel::System::Group',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Scheduler',
    'Kernel::System::Time',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Web::InterfaceAgent - the agent web interface

=head1 SYNOPSIS

the global agent web interface (incl. auth, session, ...)

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create agent web interface object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    my $Debug = 0,
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::System::Web::InterfaceAgent' => {
            Debug   => 0,
            WebRequest => CGI::Fast->new(), # optional, e. g. if fast cgi is used,
                                            # the CGI object is already provided
        }
    );
    my $InterfaceAgent = $Kernel::OM->Get('Kernel::System::Web::InterfaceAgent');

=cut

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless( $Self, $Type );

    # Performance log
    $Self->{PerformanceLogStart} = time();

    # get debug level
    $Self->{Debug} = $Param{Debug} || 0;

    $Kernel::OM->ObjectParamAdd(
        'Kernel::System::Log' => {
            LogPrefix => $Kernel::OM->Get('Kernel::Config')->Get('CGILogPrefix'),
        },
        'Kernel::System::Web::Request' => {
            WebRequest => $Param{WebRequest} || 0,
        },
    );

    # debug info
    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => 'Global handle started...',
        );
    }

    return $Self;
}

=item Run()

execute the object

    $InterfaceAgent->Run();

=cut

sub Run {
    my $Self = shift;

    # get common framework params
    my %Param;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get session id
    $Param{SessionName} = $ConfigObject->Get('SessionName') || 'SessionID';
    $Param{SessionID} = $ParamObject->GetParam( Param => $Param{SessionName} ) || '';

    # drop old session id (if exists)
    my $QueryString = $ENV{QUERY_STRING} || '';
    $QueryString =~ s/(\?|&|;|)$Param{SessionName}(=&|=;|=.+?&|=.+?$)/;/g;

    # define framework params
    my $FrameworkParams = {
        Lang         => '',
        Action       => '',
        Subaction    => '',
        RequestedURL => $QueryString,
    };
    for my $Key ( sort keys %{$FrameworkParams} ) {
        $Param{$Key} = $ParamObject->GetParam( Param => $Key )
            || $FrameworkParams->{$Key};
    }

    # validate language
    if ( $Param{Lang} && $Param{Lang} !~ m{\A[a-z]{2}(?:_[A-Z]{2})?\z}xms ) {
        delete $Param{Lang};
    }

    # check if the browser sends the SessionID cookie and set the SessionID-cookie
    # as SessionID! GET or POST SessionID have the lowest priority.
    my $BrowserHasCookie = 0;
    if ( $ConfigObject->Get('SessionUseCookie') ) {
        $Param{SessionIDCookie} = $ParamObject->GetCookie( Key => $Param{SessionName} );
        if ( $Param{SessionIDCookie} ) {
            $Param{SessionID} = $Param{SessionIDCookie};
        }
    }

    $Kernel::OM->ObjectParamAdd(
        'Kernel::Output::HTML::Layout' => {
            Lang         => $Param{Lang},
            UserLanguage => $Param{Lang},
        },
        'Kernel::Language' => {
            UserLanguage => $Param{Lang}
        },
    );

    my $CookieSecureAttribute;
    if ( $ConfigObject->Get('HttpType') eq 'https' ) {

        # Restrict Cookie to HTTPS if it is used.
        $CookieSecureAttribute = 1;
    }

    my $DBCanConnect = $Kernel::OM->Get('Kernel::System::DB')->Connect();

    if ( !$DBCanConnect || $ParamObject->Error() ) {
        my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
        if ( !$DBCanConnect ) {
            $LayoutObject->FatalError(
                Comment => Translatable('Please contact the administrator.'),
            );
            return;
        }
        if ( $ParamObject->Error() ) {
            $LayoutObject->FatalError(
                Message => $ParamObject->Error(),
                Comment => Translatable('Please contact the administrator.'),
            );
            return;
        }
    }

    # get common application and add-on application params
    my %CommonObjectParam = %{ $ConfigObject->Get('Frontend::CommonParam') };
    for my $Key ( sort keys %CommonObjectParam ) {
        $Param{$Key} = $ParamObject->GetParam( Param => $Key ) || $CommonObjectParam{$Key};
    }

    # security check Action Param (replace non word chars)
    $Param{Action} =~ s/\W//g;

    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');

    # check request type
    if ( $Param{Action} eq 'PreLogin' ) {
        my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
        $Param{RequestedURL} = $Param{RequestedURL} || "Action=AgentDashboard";

        # login screen
        $LayoutObject->Print(
            Output => \$LayoutObject->Login(
                Title => 'Login',
                Mode  => 'PreLogin',
                %Param,
            ),
        );

        return;
    }
    elsif ( $Param{Action} eq 'Login' ) {

        # get params
        my $PostUser = $ParamObject->GetParam( Param => 'User' ) || '';
        my $PostPw = $ParamObject->GetParam(
            Param => 'Password',
            Raw   => 1
        ) || '';
        my $PostTwoFactorToken = $ParamObject->GetParam(
            Param => 'TwoFactorToken',
            Raw   => 1
        ) || '';

        # create AuthObject
        my $AuthObject = $Kernel::OM->Get('Kernel::System::Auth');

        # check submitted data
        my $User = $AuthObject->Auth(
            User           => $PostUser,
            Pw             => $PostPw,
            TwoFactorToken => $PostTwoFactorToken,
        );

        # login is invalid
        if ( !$User ) {

            my $Expires = '+' . $ConfigObject->Get('SessionMaxTime') . 's';
            if ( !$ConfigObject->Get('SessionUseCookieAfterBrowserClose') ) {
                $Expires = '';
            }

            $Kernel::OM->ObjectParamAdd(
                'Kernel::Output::HTML::Layout' => {
                    SetCookies => {
                        KIXBrowserHasCookie => $ParamObject->SetCookie(
                            Key      => 'KIXBrowserHasCookie',
                            Value    => 1,
                            Expires  => $Expires,
                            Path     => $ConfigObject->Get('ScriptAlias'),
                            Secure   => $CookieSecureAttribute,
                            HTTPOnly => 1,
                        ),
                    },
                    }
            );
            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

            # redirect to alternate login
            if ( $ConfigObject->Get('LoginURL') ) {
                $Param{RequestedURL} = $LayoutObject->LinkEncode( $Param{RequestedURL} );
                print $LayoutObject->Redirect(
                    ExtURL => $ConfigObject->Get('LoginURL')
                        . "?Reason=LoginFailed&RequestedURL=$Param{RequestedURL}",
                );
                return;
            }

            # show normal login
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title   => 'Login',
                    Message => $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
                        Type => 'Info',
                        What => 'Message',
                        )
                        || $LayoutObject->{LanguageObject}->Translate( $AuthObject->GetLastErrorMessage() )
                        || Translatable('Login failed! Your user name or password was entered incorrectly.'),
                    LoginFailed => 1,
                    MessageType => 'Error',
                    User        => $User,
                    %Param,
                ),
            );
            return;
        }

        # login is successful
        my %UserData = $UserObject->GetUserData(
            User  => $User,
            Valid => 1
        );

        # check if the browser supports cookies

        if ( $ParamObject->GetCookie( Key => 'KIXBrowserHasCookie' ) ) {
            $Kernel::OM->ObjectParamAdd(
                'Kernel::Output::HTML::Layout' => {
                    BrowserHasCookie => 1,
                },
            );
        }

        # check needed data
        if ( !$UserData{UserID} || !$UserData{UserLogin} ) {

            # redirect to alternate login
            if ( $ConfigObject->Get('LoginURL') ) {
                print $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Redirect(
                    ExtURL => $ConfigObject->Get('LoginURL') . '?Reason=SystemError',
                );
                return;
            }

            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

            # show need user data error message
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title => 'Panic!',
                    Message =>
                        Translatable(
                        'You could not be logged in to the system. Please check that your username and password have been entered correctly.'
                        ),
                    %Param,
                    MessageType => 'Error',
                ),
            );
            return;
        }

        # get groups rw/ro
        for my $Type (qw(rw ro)) {

            my %GroupData = $Kernel::OM->Get('Kernel::System::Group')->PermissionUserGet(
                UserID => $UserData{UserID},
                Type   => $Type,
            );

            for ( sort keys %GroupData ) {

                if ( $Type eq 'rw' ) {
                    $UserData{"UserIsGroup[$GroupData{$_}]"} = 'Yes';
                }
                else {
                    $UserData{"UserIsGroupRo[$GroupData{$_}]"} = 'Yes';
                }
            }
        }

        # create new session id
        my $NewSessionID = $SessionObject->CreateSessionID(
            %UserData,
            UserLastRequest => $Kernel::OM->Get('Kernel::System::Time')->SystemTime(),
            UserType        => 'User',
        );

        # show error message if no session id has been created
        if ( !$NewSessionID ) {

            # get error message
            my $Error = $SessionObject->SessionIDErrorMessage() || '';

            # output error message
            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title       => 'Login',
                    Message     => $Error,
                    MessageType => 'Error',
                    %Param,
                ),
            );
            return;
        }

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        # execution in 20 seconds
        my $ExecutionTime = $TimeObject->SystemTime2TimeStamp(
            SystemTime => ( $TimeObject->SystemTime() + 20 ),
        );

        # add a asychronous executor scheduler task to count the concurrent user
        $Kernel::OM->Get('Kernel::System::Scheduler')->TaskAdd(
            ExecutionTime            => $ExecutionTime,
            Type                     => 'AsynchronousExecutor',
            Name                     => 'PluginAsynchronous::ConcurrentUser',
            MaximumParallelInstances => 1,
            Data                     => {
                Object   => 'Kernel::System::SupportDataCollector::PluginAsynchronous::KIX::ConcurrentUsers',
                Function => 'RunAsynchronous',
            },
        );

        # set time zone offset if TimeZoneFeature is active
        if (
            $ConfigObject->Get('TimeZoneUser')
            && $ConfigObject->Get('TimeZoneUserBrowserAutoOffset')
        ) {
            my $TimeOffset = $ParamObject->GetParam( Param => 'TimeOffset' ) || 0;
            if ( $TimeOffset > 0 ) {
                $TimeOffset = '-' . ( $TimeOffset / 60 );
            }
            else {
                $TimeOffset = $TimeOffset / 60;
                $TimeOffset =~ s/-/+/;
            }

            $UserObject->SetPreferences(
                UserID => $UserData{UserID},
                Key    => 'UserTimeZone',
                Value  => $TimeOffset,
            );
            $SessionObject->UpdateSessionID(
                SessionID => $NewSessionID,
                Key       => 'UserTimeZone',
                Value     => $TimeOffset,
            );
        }

        # create a new LayoutObject with SessionIDCookie
        my $Expires = '+' . $ConfigObject->Get('SessionMaxTime') . 's';
        if ( !$ConfigObject->Get('SessionUseCookieAfterBrowserClose') ) {
            $Expires = '';
        }

        my $SecureAttribute;
        if ( $ConfigObject->Get('HttpType') eq 'https' ) {

            # Restrict Cookie to HTTPS if it is used.
            $SecureAttribute = 1;
        }

        $Kernel::OM->ObjectParamAdd(
            'Kernel::Output::HTML::Layout' => {
                SetCookies => {
                    SessionIDCookie => $ParamObject->SetCookie(
                        Key      => $Param{SessionName},
                        Value    => $NewSessionID,
                        Expires  => $Expires,
                        Path     => $ConfigObject->Get('ScriptAlias'),
                        Secure   => scalar $CookieSecureAttribute,
                        HTTPOnly => 1,
                    ),
                    KIXBrowserHasCookie => $ParamObject->SetCookie(
                        Key      => 'KIXBrowserHasCookie',
                        Value    => '',
                        Expires  => '-1y',
                        Path     => $ConfigObject->Get('ScriptAlias'),
                        Secure   => $CookieSecureAttribute,
                        HTTPOnly => 1,
                    ),
                },
                SessionID   => $NewSessionID,
                SessionName => $Param{SessionName},
            },
        );

        # redirect with new session id and old params
        # prepare old redirect URL -- do not redirect to Login or Logout (loop)!
        if ( $Param{RequestedURL} =~ /Action=(Logout|Login|LostPassword|PreLogin)/ ) {
            $Param{RequestedURL} = '';
        }

        # redirect with new session id
        print $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Redirect(
            OP    => $Param{RequestedURL},
            Login => 1,
        );
        return 1;
    }

    # logout
    elsif ( $Param{Action} eq 'Logout' ) {

        my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

        # check for given session id
        if ( !$Param{SessionID} ) {

            # redirect to alternate login
            if ( $ConfigObject->Get('LoginURL') ) {
                $Param{RequestedURL} = $LayoutObject->LinkEncode( $Param{RequestedURL} );
                print $LayoutObject->Redirect(
                    ExtURL => $ConfigObject->Get('LoginURL')
                        . "?RequestedURL=$Param{RequestedURL}",
                );
                return;
            }

            # show login screen
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title => 'Logout',
                    %Param,
                ),
            );
            return;
        }

        # check session id
        if ( !$SessionObject->CheckSessionID( SessionID => $Param{SessionID} ) ) {

            # redirect to alternate login
            if ( $ConfigObject->Get('LoginURL') ) {
                $Param{RequestedURL} = $LayoutObject->LinkEncode( $Param{RequestedURL} );
                print $LayoutObject->Redirect(
                    ExtURL => $ConfigObject->Get('LoginURL')
                        . "?Reason=InvalidSessionID&RequestedURL=$Param{RequestedURL}",
                );
                return;
            }

            # show login screen
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title       => 'Logout',
                    Message     => Translatable('Session invalid. Please log in again.'),
                    MessageType => 'Error',
                    %Param,
                ),
            );
            return;
        }

        # get session data
        my %UserData = $SessionObject->GetSessionIDData(
            SessionID => $Param{SessionID},
        );

        # create a new LayoutObject with %UserData
        $Kernel::OM->ObjectParamAdd(
            'Kernel::Output::HTML::Layout' => {
                SetCookies => {
                    SessionIDCookie => $ParamObject->SetCookie(
                        Key      => $Param{SessionName},
                        Value    => '',
                        Expires  => '-1y',
                        Path     => $ConfigObject->Get('ScriptAlias'),
                        Secure   => scalar $CookieSecureAttribute,
                        HTTPOnly => 1,
                    ),
                },
                %UserData,
            },
        );
        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::Output::HTML::Layout'] );
        $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

        # Prevent CSRF attacks
        $LayoutObject->ChallengeTokenCheck();

        # remove session id
        if ( !$SessionObject->RemoveSessionID( SessionID => $Param{SessionID} ) ) {
            $LayoutObject->FatalError(
                Message => Translatable('Can`t remove SessionID.'),
                Comment => Translatable('Please contact the administrator.'),
            );
            return;
        }

        # redirect to alternate login
        if ( $ConfigObject->Get('LogoutURL') ) {
            print $LayoutObject->Redirect(
                ExtURL => $ConfigObject->Get('LogoutURL') . "?Reason=Logout",
            );
            return 1;
        }

        # show logout screen
        my $LogoutMessage = $LayoutObject->{LanguageObject}->Translate('Logout successful.');

        $LayoutObject->Print(
            Output => \$LayoutObject->Login(
                Title       => 'Logout',
                Message     => $LogoutMessage,
                MessageType => 'Logout',
                %Param,
            ),
        );
        return 1;
    }

    # user lost password
    elsif ( $Param{Action} eq 'LostPassword' ) {

        # get needed objects
        my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
        my $EmailObject    = $Kernel::OM->Get('Kernel::System::Email');
        my $ValidObject    = $Kernel::OM->Get('Kernel::System::Valid');
        my $ExecutorObject = $Kernel::OM->Get('Kernel::System::AsynchronousExecutor::LostPasswordExecutor');

        # check feature
        if ( !$ConfigObject->Get('LostPassword') ) {

            # show normal login
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title       => 'Login',
                    Message     => $LayoutObject->{LanguageObject}->Translate('Feature not active!'),
                    MessageType => 'Error',
                ),
            );
            return;
        }

        # get valid ids
        my @ValidIDs = $ValidObject->ValidIDsGet();

        # get params
        my $User  = $ParamObject->GetParam( Param => 'User' )  || '';
        my $Token = $ParamObject->GetParam( Param => 'Token' ) || '';

        # process given token param
        if ( $Token ) {
            # check that token contains only valid characters
            if ( $Token !~ m/^[A-Za-z0-9]+$/ ) {
                $LayoutObject->Print(
                    Output => \$LayoutObject->Login(
                        Title       => 'Login',
                        Message     => $LayoutObject->{LanguageObject}->Translate('Invalid Token!'),
                        MessageType => 'Error',
                        %Param,
                    ),
                );
                return;
            }

            # lookup users for provided token
            my %UserList = $UserObject->SearchPreferences(
                Key   => 'UserToken',
                Value => $Token,
            );

            # check that there is only one user for given token
            if ( keys( %UserList ) != 1 ) {
                $LayoutObject->Print(
                    Output => \$LayoutObject->Login(
                        Title       => 'Login',
                        Message     => $LayoutObject->{LanguageObject}->Translate('Invalid Token!'),
                        MessageType => 'Error',
                        %Param,
                    ),
                );
                return;
            }

            # get user from list
            my $TokenUserID;
            for my $UserID ( keys( %UserList ) ) {
                $TokenUserID = $UserID;
            }

            # get user data
            my %UserData = $UserObject->GetUserData(
                UserID => $TokenUserID,
                Valid  => 1,
            );

            # verify user is valid
            my $UserIsValid;
            if ( $UserData{ValidID} ) {
                $UserIsValid = grep { $UserData{ValidID} == $_ } @ValidIDs;
            }
            if (
                !$UserData{UserID}
                || !$UserIsValid
            ) {
                $LayoutObject->Print(
                    Output => \$LayoutObject->Login(
                        Title       => 'Login',
                        Message     => $LayoutObject->{LanguageObject}->Translate('Invalid Token!'),
                        MessageType => 'Error',
                        %Param,
                    ),
                );
                return;
            }

            # verify token is valid
            my $TokenValid = $UserObject->TokenCheck(
                Token  => $Token,
                UserID => $UserData{UserID},
            );
            if ( !$TokenValid ) {
                $LayoutObject->Print(
                    Output => \$LayoutObject->Login(
                        Title       => 'Login',
                        Message     => $LayoutObject->{LanguageObject}->Translate('Invalid Token!'),
                        MessageType => 'Error',
                        %Param,
                    ),
                );
                return;
            }

            $ExecutorObject->AsyncCall(
                ObjectName     => 'Kernel::System::AsynchronousExecutor::LostPasswordExecutor',
                FunctionName   => 'Run',
                TaskName       => $Self->{Action} . '-' . $Token . '-Run',
                FunctionParams => {
                    CallAction => 'Run',
                    Token    => $Token,
                    UserData => \%UserData,
                    User     => $User,
                    Type     => 'User',
                },
                Attempts       => 1,
            );

            # return that new password was sent
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title       => 'Login',
                    Message     => $LayoutObject->{LanguageObject}->Translate('Sent new password. Please check your email.'),
                    MessageType => 'Success',
                    %Param,
                ),
            );
            return 1;
        }
        # process given user param
        elsif ( $User ) {
            # get user data
            my %UserData = $UserObject->GetUserData(
                User  => $User,
                Valid => 1
            );

            # verify user is valid
            my $UserIsValid;
            if ( $UserData{ValidID} ) {
                $UserIsValid = grep { $UserData{ValidID} == $_ } @ValidIDs;
            }
            if (
                $UserData{UserID}
                && $UserIsValid
            ) {
                $ExecutorObject->AsyncCall(
                    ObjectName     => 'Kernel::System::AsynchronousExecutor::LostPasswordExecutor',
                    FunctionName   => 'Run',
                    TaskName       => 'LostPasswordToken-' . $UserData{UserID} . '-Run',
                    FunctionParams => {
                        Subaction => 'TokenSend',
                        UserData => \%UserData,
                        User     => $User,
                        Type     => 'User',
                    },
                    Attempts       => 1,
                );
            }

            # Security: Always pretend that password reset instructions were sent to
            # make sure that requester cannot find out valid usernames by checking the result message
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title       => 'Login',
                    Message     => $LayoutObject->{LanguageObject}->Translate('Sent password reset instructions. Please check your email.'),
                    MessageType => 'Success',
                    %Param,
                ),
            );
            return 1;
        }

        # no user and token given
        $LayoutObject->FatalError(
            Message => 'Need User or Token!',
            Comment => Translatable('Please contact the administrator.'),
        );
        return;
    }

    # show login site
    elsif ( !$Param{SessionID} ) {

        # create AuthObject
        my $AuthObject   = $Kernel::OM->Get('Kernel::System::Auth');
        my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
        if ( $AuthObject->GetOption( What => 'PreAuth' ) ) {

            # automatic login
            $Param{RequestedURL} = $LayoutObject->LinkEncode( $Param{RequestedURL} );
            print $LayoutObject->Redirect(
                OP => "Action=PreLogin&RequestedURL=$Param{RequestedURL}",
            );
            return;
        }
        elsif ( $ConfigObject->Get('LoginURL') ) {

            # redirect to alternate login
            $Param{RequestedURL} = $LayoutObject->LinkEncode( $Param{RequestedURL} );
            print $LayoutObject->Redirect(
                ExtURL => $ConfigObject->Get('LoginURL')
                    . "?RequestedURL=$Param{RequestedURL}",
            );
            return;
        }

        # login screen
        $LayoutObject->Print(
            Output => \$LayoutObject->Login(
                Title => 'Login',
                %Param,
            ),
        );
        return;
    }

    # run modules if a version value exists
    elsif ( $Kernel::OM->Get('Kernel::System::Main')->Require("Kernel::Modules::$Param{Action}") ) {

        # check session id
        if ( !$SessionObject->CheckSessionID( SessionID => $Param{SessionID} ) ) {

            # put '%Param' into LayoutObject
            $Kernel::OM->ObjectParamAdd(
                'Kernel::Output::HTML::Layout' => {
                    SetCookies => {
                        SessionIDCookie => $ParamObject->SetCookie(
                            Key      => $Param{SessionName},
                            Value    => '',
                            Expires  => '-1y',
                            Path     => $ConfigObject->Get('ScriptAlias'),
                            Secure   => scalar $CookieSecureAttribute,
                            HTTPOnly => 1,
                        ),
                    },
                    %Param,
                },
            );

            $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::Output::HTML::Layout'] );
            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

            # create AuthObject
            my $AuthObject = $Kernel::OM->Get('Kernel::System::Auth');
            if ( $AuthObject->GetOption( What => 'PreAuth' ) ) {

                # automatic re-login
                $Param{RequestedURL} = $LayoutObject->LinkEncode( $Param{RequestedURL} );
                print $LayoutObject->Redirect(
                    OP => "?Action=PreLogin&RequestedURL=$Param{RequestedURL}",
                );
                return;
            }
            elsif ( $ConfigObject->Get('LoginURL') ) {

                # redirect to alternate login
                $Param{RequestedURL} = $LayoutObject->LinkEncode( $Param{RequestedURL} );
                print $LayoutObject->Redirect(
                    ExtURL => $ConfigObject->Get('LoginURL')
                        . "?Reason=InvalidSessionID&RequestedURL=$Param{RequestedURL}",
                );
                return;
            }

            # show login
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title => 'Login',
                    Message =>
                        $LayoutObject->{LanguageObject}->Translate( $SessionObject->SessionIDErrorMessage() ),
                    MessageType => 'Error',
                    %Param,
                ),
            );
            return;
        }

        # get session data
        my %UserData = $SessionObject->GetSessionIDData(
            SessionID => $Param{SessionID},
        );

        # check needed data
        if ( !$UserData{UserID} || !$UserData{UserLogin} || $UserData{UserType} ne 'User' ) {

            my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

            # redirect to alternate login
            if ( $ConfigObject->Get('LoginURL') ) {
                print $LayoutObject->Redirect(
                    ExtURL => $ConfigObject->Get('LoginURL') . '?Reason=SystemError',
                );
                return;
            }

            # show login screen
            $LayoutObject->Print(
                Output => \$LayoutObject->Login(
                    Title       => 'Panic!',
                    Message     => Translatable('Panic! Invalid Session!!!'),
                    MessageType => 'Error',
                    %Param,
                ),
            );
            return;
        }

        # check module registry
        my $ModuleReg = $ConfigObject->Get('Frontend::Module')->{ $Param{Action} };
        if ( !$ModuleReg ) {

            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message =>
                    "Module Kernel::Modules::$Param{Action} not registered in Kernel/Config.pm!",
            );
            $Kernel::OM->Get('Kernel::Output::HTML::Layout')->FatalError(
                Comment => Translatable('Please contact the administrator.'),
            );
            return;
        }

        # module permisson check
        if ( !$ModuleReg->{GroupRo} && !$ModuleReg->{Group} ) {
            $Param{AccessRo} = 1;
            $Param{AccessRw} = 1;
        }
        else {
            PERMISSION:
            for my $Permission (qw(GroupRo Group)) {
                my $AccessOk = 0;
                my $Group    = $ModuleReg->{$Permission};
                my $Key      = "UserIs$Permission";
                next PERMISSION if !$Group;
                if ( ref $Group eq 'ARRAY' ) {
                    INNER:
                    for ( @{$Group} ) {
                        next INNER if !$_;
                        next INNER if !$UserData{ $Key . "[$_]" };
                        next INNER if $UserData{ $Key . "[$_]" } ne 'Yes';
                        $AccessOk = 1;
                        last INNER;
                    }
                }
                else {
                    if (
                        $UserData{ $Key . "[$Group]" }
                        && $UserData{ $Key . "[$Group]" } eq 'Yes'
                    ) {
                        $AccessOk = 1;
                    }
                }
                if ( $Permission eq 'Group' && $AccessOk ) {
                    $Param{AccessRo} = 1;
                    $Param{AccessRw} = 1;
                }
                elsif ( $Permission eq 'GroupRo' && $AccessOk ) {
                    $Param{AccessRo} = 1;
                }
            }
            if ( !$Param{AccessRo} && !$Param{AccessRw} || !$Param{AccessRo} && $Param{AccessRw} ) {

                print $Kernel::OM->Get('Kernel::Output::HTML::Layout')->NoPermission(
                    Message => Translatable('No Permission to use this frontend module!')
                );
                return;
            }
        }

        # put '%Param' and '%UserData' into LayoutObject
        $Kernel::OM->ObjectParamAdd(
            'Kernel::Output::HTML::Layout' => {
                %Param,
                %UserData,
                ModuleReg => $ModuleReg,
            },
        );
        $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::Output::HTML::Layout'] );

        # update last request time
        if (
            !$ParamObject->IsAJAXRequest()
        ) {
            $SessionObject->UpdateSessionID(
                SessionID => $Param{SessionID},
                Key       => 'UserLastRequest',
                Value     => $Kernel::OM->Get('Kernel::System::Time')->SystemTime(),
            );
        }

        # pre application module
        my $PreModuleConfig = $ConfigObject->Get('PreApplicationModule');
        if ($PreModuleConfig) {
            my %PreModuleList;
            if ( ref $PreModuleConfig eq 'HASH' ) {
                %PreModuleList = %{$PreModuleConfig};
            }
            else {
                $PreModuleList{Init} = $PreModuleConfig;
            }

            MODULE:
            for my $PreModuleKey ( sort keys %PreModuleList ) {
                my $PreModule = $PreModuleList{$PreModuleKey};
                next MODULE if !$PreModule;
                next MODULE if !$Kernel::OM->Get('Kernel::System::Main')->Require($PreModule);

                # debug info
                if ( $Self->{Debug} ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'debug',
                        Message  => "PreApplication module $PreModule is used.",
                    );
                }

                my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

                # use module
                my $PreModuleObject = $PreModule->new(
                    %Param,
                    %UserData,
                    ModuleReg => $ModuleReg,
                );
                my $Output = $PreModuleObject->PreRun();
                if ($Output) {
                    $LayoutObject->Print( Output => \$Output );
                    return 1;
                }
            }
        }

        # debug info
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'debug',
                Message  => 'Kernel::Modules::' . $Param{Action} . '->new',
            );
        }

        my $FrontendObject = ( 'Kernel::Modules::' . $Param{Action} )->new(
            %Param,
            %UserData,
            ModuleReg => $ModuleReg,
            Debug     => $Self->{Debug},
        );

        # debug info
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'debug',
                Message  => 'Kernel::Modules::' . $Param{Action} . '->run',
            );
        }

        # ->Run $Action with $FrontendObject
        $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Print( Output => \$FrontendObject->Run() );

        # log request time
        if ( $ConfigObject->Get('PerformanceLog') ) {
            if ( ( !$QueryString && $Param{Action} ) || $QueryString !~ /Action=/ ) {
                $QueryString = 'Action=' . $Param{Action} . '&Subaction=' . $Param{Subaction};
            }
            my $File = $ConfigObject->Get('PerformanceLog::File');
            if ( open my $Out, '>>', $File ) {
                print $Out time()
                    . '::Agent::'
                    . ( time() - $Self->{PerformanceLogStart} )
                    . "::$UserData{UserLogin}::$QueryString\n";
                close $Out;

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => "Response::Agent: "
                        . ( time() - $Self->{PerformanceLogStart} )
                        . "s taken (URL:$QueryString:$UserData{UserLogin})",
                );
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Can't write $File: $!",
                );
            }
        }
        return 1;
    }

    # print an error screen
    my %Data = $SessionObject->GetSessionIDData(
        SessionID => $Param{SessionID},
    );
    $Kernel::OM->ObjectParamAdd(
        'Kernel::Output::HTML::Layout' => {
            %Param,
            %Data,
        },
    );
    $Kernel::OM->Get('Kernel::Output::HTML::Layout')->FatalError(
        Comment => Translatable('Please contact the administrator.'),
    );
    return;
}

sub DESTROY {
    my $Self = shift;

    # debug info
    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'debug',
            Message  => 'Global handle stopped.',
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
