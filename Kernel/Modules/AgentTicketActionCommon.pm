# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketActionCommon;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::EmailParser;
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # get article for whom this should be a reply, if available
    my $ReplyToArticle = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'ReplyToArticle' ) || "";

    # check if ReplyToArticle really belongs to the ticket
    my %ReplyToArticleContent;
    if ($ReplyToArticle) {
        %ReplyToArticleContent = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleGet(
            ArticleID     => $ReplyToArticle,
            DynamicFields => 0,
            UserID        => $Self->{UserID},
        );

        $Self->{ReplyToArticle}        = $ReplyToArticle;
        $Self->{ReplyToArticleContent} = \%ReplyToArticleContent;

        # get sender of original note (to inform sender about answer)
        if ( $ReplyToArticleContent{CreatedBy} ) {
            my @ReplyToSenderID = ( $ReplyToArticleContent{CreatedBy} );
            $Self->{ReplyToSenderUserID} = \@ReplyToSenderID;
        }

        # if article belongs to other ticket, don't use it as reply
        if ( $ReplyToArticleContent{TicketID} ne $Self->{TicketID} ) {
            $Self->{ReplyToArticle} = "";
        }

        # if article is not of type note-internal, don't use it as reply
        if ( $ReplyToArticleContent{ArticleType} !~ /^note-(?:internal|external)$/i ) {
            $Self->{ReplyToArticle} = "";
        }
    }

    # get form id
    $Self->{FormID} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'FormID' );

    # create form id
    if ( !$Self->{FormID} ) {
        $Self->{FormID} = $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDCreate();
    }

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');

    # the following allows us to easily register new ticket actions
    # without own dtl's and pm's...
    $Self->{DTLAction} = $Self->{Action};
    $Self->{PretendAction} = $ParamObject->GetParam( Param => 'PretendAction' ) || '';
    if ( $Self->{PretendAction} ) {
        if ( !$ConfigObject->Get("Ticket::Frontend::$Self->{PretendAction}") ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Kernel::Module::AgentTicketActionCommon: PretendAction "
                    . "<$Self->{PretendAction}> called but not availabe in "
                    . "configuration (using fallback).",
            );
            $Self->{PretendAction} = '';
        }
        else {
            $Self->{Action} = $Self->{PretendAction};
        }
    }

    my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Self->{UserID} );
    $Self->{RedirectDestination} = $Preferences{RedirectAfterTicketClose} || '0';

    # check needed stuff
    if ( !$Self->{TicketID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No TicketID is given!'),
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    # get config of frontend module
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Config->{Permission},
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {
        return $LayoutObject->NoPermission(
            Message => $LayoutObject->{LanguageObject}->Translate( 'You need %s permissions!', $Config->{Permission} ),
            WithHeader => 'yes',
        );
    }

    # get ACL restrictions
    my %PossibleActions = ( 1 => $Self->{Action} );

    my $ACL = $TicketObject->TicketAcl(
        Data          => \%PossibleActions,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();

    # check if ACL restrictions exist
    if ( $ACL || IsHashRefWithData( \%AclAction ) ) {

        my %AclActionLookup = reverse %AclAction;

        # show error screen if ACL prohibits this action
        if ( !$AclActionLookup{ $Self->{Action} } ) {
            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    $LayoutObject->Block(
        Name => 'Properties',
        Data => {
            FormID         => $Self->{FormID},
            ReplyToArticle => $Self->{ReplyToArticle},
            PretendAction  => $Self->{PretendAction} || '',
            %Ticket,
            %Param,
        },
    );

    # show right header
    if ( $Self->{PretendAction} ) {
        my $HeaderTitle =
            $ConfigObject->Get('Frontend::Module')->{ $Self->{PretendAction} }->{Title};
        $LayoutObject->Block(
            Name => 'HeaderPretendAction',
            Data => {
                Text => $HeaderTitle,
            },
        );
    }
    else {
        $LayoutObject->Block(
            Name => 'Header' . $Self->{Action},
            Data => {
                %Ticket,
            },
        );
    }

    # get lock state
    if ( $Config->{RequiredLock} ) {
        if ( !$TicketObject->TicketLockGet( TicketID => $Self->{TicketID} ) ) {
            $TicketObject->TicketLockSet(
                TicketID => $Self->{TicketID},
                Lock     => 'lock',
                UserID   => $Self->{UserID}
            );
            my $Success = $TicketObject->TicketOwnerSet(
                TicketID  => $Self->{TicketID},
                UserID    => $Self->{UserID},
                NewUserID => $Self->{UserID},
            );

            # show lock state
            if ($Success) {

                %Ticket = $TicketObject->TicketGet(
                    TicketID      => $Self->{TicketID},
                    DynamicFields => 1,
                );

                $LayoutObject->Block(
                    Name => 'PropertiesLock',
                    Data => {
                        %Param,
                        TicketID => $Self->{TicketID},
                    },
                );
            }
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Self->{TicketID},
                OwnerID  => $Self->{UserID},
            );
            if ( !$AccessOk ) {
                my $Output = $LayoutObject->Header(
                    Type      => 'Small',
                    Value     => $Ticket{Number},
                    BodyClass => 'Popup',
                );
                $Output .= $LayoutObject->Warning(
                    Message => Translatable('Sorry, you need to be the ticket owner to perform this action.'),
                    Comment => Translatable('Please change the owner first.'),
                );
                $Output .= $LayoutObject->Footer(
                    Type => 'Small',
                );
                return $Output;
            }

            # show back link
            $LayoutObject->Block(
                Name => 'TicketBack',
                Data => {
                    %Param,
                    TicketID => $Self->{TicketID},
                },
            );
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'TicketBack',
            Data => {
                %Param,
                %Ticket,
            },
        );
    }

    # get params
    my %GetParam;
    for my $Key (
        qw(
        NewStateID NewPriorityID TimeUnits ArticleTypeID Title Body Subject NewQueueID
        Year Month Day Hour Minute NewOwnerID NewResponsibleID TypeID ServiceID SLAID
        Expand ReplyToArticle StandardTemplateID CreateArticle
        DestQueue NewOwnerType OldOwnerID ElementChanged
        )
    ) {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
    }

    # ACL compatibility translation
    my %ACLCompatGetParam = (
        StateID       => $GetParam{NewStateID},
        PriorityID    => $GetParam{NewPriorityID},
        QueueID       => $GetParam{NewQueueID},
        OwnerID       => $GetParam{NewOwnerID},
        ResponsibleID => $GetParam{NewResponsibleID},
    );

    # get dynamic field values form http request
    my %DynamicFieldValues;
# ---
# ITSMIncidentProblemManagement
# ---
    # to store the reference to the dynamic field for the impact
    my $ImpactDynamicFieldConfig;
# ---

    # define the dynamic fields to show based on the object type
    my $ObjectType = ['Ticket'];

    # only screens that add notes can modify Article dynamic fields
    if ( $Config->{Note} ) {
        $ObjectType = [ 'Ticket', 'Article' ];
    }

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => $ObjectType,
        FieldFilter => $Config->{DynamicField} || {},
    );

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # extract the dynamic field value form the web request
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} } = $DynamicFieldBackendObject->EditFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ParamObject        => $ParamObject,
            LayoutObject       => $LayoutObject,
        );
# ---
# ITSMIncidentProblemManagement
# ---
        # impact field was found
        if ( $DynamicFieldConfig->{Name} eq 'ITSMImpact' ) {

            # store the reference to the impact field
            $ImpactDynamicFieldConfig = $DynamicFieldConfig;
        }
# ---
    }

# ---
# ITSMIncidentProblemManagement
# ---
    # get needed stuff
    $GetParam{DynamicField_ITSMImpact} = $ParamObject->GetParam(Param => 'DynamicField_ITSMImpact');
    $GetParam{PriorityRC}              = $ParamObject->GetParam(Param => 'PriorityRC');
    $GetParam{ElementChanged}          = $ParamObject->GetParam(Param => 'ElementChanged') || '';

    # check if priority needs to be recalculated
    if ( $GetParam{ElementChanged} eq 'ServiceID' || ( $GetParam{DynamicField_ITSMImpact} && $GetParam{ElementChanged} eq 'DynamicField_ITSMImpact' ) ) {
        $GetParam{PriorityRC} = 1;
    }

    # set service id from ticket
    if ( !defined $GetParam{ServiceID} && $Ticket{ServiceID} ) {
        $GetParam{ServiceID} = $Ticket{ServiceID};
    }

    # set impact from ticket
    if ( !defined $GetParam{DynamicField_ITSMImpact} ) {
        $GetParam{DynamicField_ITSMImpact} = $Ticket{DynamicField_ITSMImpact};
    }

    my %Service;
    if ( $GetParam{ServiceID} ) {

        # get service
        %Service = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
            ServiceID     => $GetParam{ServiceID},
            IncidentState => $Config->{ShowIncidentState} || 0,
            UserID        => $Self->{UserID},
        );

        # recalculate impact if impact is not set until now
        if ( !$GetParam{DynamicField_ITSMImpact} && $GetParam{ElementChanged} ne 'DynamicField_ITSMImpact' ) {

            # get default selection
            my $DefaultSelection = $ImpactDynamicFieldConfig->{Config}->{DefaultValue};

            if ($DefaultSelection) {

                # get default impact
                $GetParam{DynamicField_ITSMImpact} = $DefaultSelection;

                # set priority if no priority set
                if (
                    !$GetParam{NewPriorityID}
                    && ( !defined $Ticket{Priority} || !$Ticket{Priority} )
                ) {
                    $GetParam{PriorityRC} = 1;
                }
            }
        }

        # recalculate priority
        if ( $GetParam{PriorityRC} && $GetParam{DynamicField_ITSMImpact} && $Config->{Priority} ) {

            if ( $GetParam{DynamicField_ITSMImpact} ) {

                # get priority
                $GetParam{PriorityIDFromImpact} = $Kernel::OM->Get('Kernel::System::ITSMCIPAllocate')->PriorityAllocationGet(
                    Criticality => $Service{Criticality},
                    Impact      => $GetParam{DynamicField_ITSMImpact},
                );

                if ( $GetParam{PriorityIDFromImpact} ) {
                    $GetParam{NewPriorityID} = $GetParam{PriorityIDFromImpact};
                }
            }
            else {
                $GetParam{NewPriorityID} = '';
            }
        }
    }

    # no service was selected
    else {

        # do not show the default selection
        $ImpactDynamicFieldConfig->{Config}->{DefaultValue} = '';

        # show only the empty selection
        $ImpactDynamicFieldConfig->{Config}->{PossibleValues} = {};
        $GetParam{DynamicField_ITSMImpact} = '';
    }

    # set the selected impact
    $DynamicFieldValues{ITSMImpact} = $GetParam{DynamicField_ITSMImpact};

# ---
    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    DYNAMICFIELD:
    for my $DynamicFieldItem ( sort keys %DynamicFieldValues ) {
        next DYNAMICFIELD if !$DynamicFieldItem;
        next DYNAMICFIELD if !$DynamicFieldValues{$DynamicFieldItem};

        $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicFieldItem } = $DynamicFieldValues{$DynamicFieldItem};
    }
    $GetParam{DynamicField} = \%DynamicFieldACLParameters;

    # transform pending time, time stamp based on user time zone
    if (
        defined $GetParam{Year}
        && defined $GetParam{Month}
        && defined $GetParam{Day}
        && defined $GetParam{Hour}
        && defined $GetParam{Minute}
    ) {
        %GetParam = $LayoutObject->TransformDateSelection(
            %GetParam,
        );
    }

    # rewrap body if no rich text is used
    if ( $GetParam{Body} && !$LayoutObject->{BrowserRichText} ) {
        $GetParam{Body} = $LayoutObject->WrapPlainText(
            MaxCharacters => $ConfigObject->Get('Ticket::Frontend::TextAreaNote'),
            PlainText     => $GetParam{Body},
        );
    }

    # get upload cache object
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    # run acl to prepare TicketAclFormData
    my $ShownDFACL = $Kernel::OM->Get('Kernel::System::Ticket')->TicketAcl(
        %GetParam,
        %ACLCompatGetParam,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Ticket',
        ReturnSubType => '-',
        Data          => {},
        UserID        => $Self->{UserID},
    );

    # update 'Shown' for $Self->{DynamicField}
    $Self->_GetShownDynamicFields();

    if ( $Self->{Subaction} eq 'Store' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # store action
        my %Error;

        # If is an action about attachments
        my $IsUpload = 0;

        # attachment delete
        my @AttachmentIDs = ();
        for my $Name ( $ParamObject->GetParamNames() ) {
            if ( $Name =~ m{ \A AttachmentDelete (\d+) \z }xms ) {
                push (@AttachmentIDs, $1);
            };
        }

        COUNT:
        for my $Count ( reverse sort @AttachmentIDs ) {
            my $Delete = $ParamObject->GetParam( Param => "AttachmentDelete$Count" );
            next COUNT if !$Delete;
            %Error                   = ();
            $Error{AttachmentDelete} = 1;
            $UploadCacheObject->FormIDRemoveFile(
                FormID => $Self->{FormID},
                FileID => $Count,
            );
            $IsUpload = 1;
        }

        # attachment upload
        if ( $ParamObject->GetParam( Param => 'AttachmentUpload' ) ) {
            $IsUpload                = 1;
            %Error                   = ();
            $Error{AttachmentUpload} = 1;
            my %UploadStuff = $ParamObject->GetUploadAll(
                Param => 'FileUpload',
            );
            $UploadCacheObject->FormIDAddFile(
                FormID      => $Self->{FormID},
                Disposition => 'attachment',
                %UploadStuff,
            );
        }

        # get all attachments meta data
        my @Attachments = $UploadCacheObject->FormIDGetAllFilesMeta(
            FormID => $Self->{FormID},
        );

        # get state object
        my $StateObject = $Kernel::OM->Get('Kernel::System::State');

        # check pending time
        if ( $GetParam{NewStateID} ) {
            my %StateData = $StateObject->StateGet(
                ID => $GetParam{NewStateID},
            );

            if ( !$IsUpload ) {

                # check state type
                if ( $StateData{TypeName} =~ /^pending/i ) {

                    # check needed stuff
                    for my $Needed (qw(Year Month Day Hour Minute)) {
                        if ( !defined $GetParam{$Needed} ) {
                            $Error{'DateInvalid'} = 'ServerError';
                        }
                    }

                    # get time object
                    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

                    # check date
                    if ( !$TimeObject->Date2SystemTime( %GetParam, Second => 0 ) ) {
                        $Error{'DateInvalid'} = 'ServerError';
                    }
                    if (
                        $TimeObject->Date2SystemTime( %GetParam, Second => 0 )
                        < $TimeObject->SystemTime()
                    ) {
                        $Error{'DateInvalid'} = 'ServerError';
                    }
                }
            }
        }

        if ( !$IsUpload ) {
            if ( $Config->{Note} && $Config->{NoteMandatory} ) {

                # check subject
                if ( !$GetParam{Subject} ) {
                    $Error{'SubjectInvalid'} = 'ServerError';
                }

                # check body
                if ( !$GetParam{Body} ) {
                    $Error{'BodyInvalid'} = 'ServerError';
                }
            }

            # check owner
            if ( $Config->{Owner} && $Config->{OwnerMandatory} ) {
                if ( !$GetParam{NewOwnerID} ) {
                    $Error{'NewOwnerInvalid'} = 'ServerError';
                }
            }
            if (
                $Config->{Owner}
                && $GetParam{NewOwnerID}
            ) {
                my $PossibleOwners = $Self->_GetOwners(
                    %GetParam,
                    %ACLCompatGetParam,
                    QueueID  => $GetParam{NewQueueID} || $Ticket{QueueID},
                    StateID  => $GetParam{NewStateID} || $Ticket{StateID},
                    AllUsers => $GetParam{OwnerAll},
                );
                if ( !$PossibleOwners->{ $GetParam{NewOwnerID} } ) {
                    $Error{'NewOwnerInvalid'} = 'ServerError';
                }
            }

            # check responsible
            if (
                $ConfigObject->Get('Ticket::Responsible')
                && $Config->{Responsible}
                && $GetParam{NewResponsibleID}
            ) {
                my $PossibleResponsibles = $Self->_GetResponsibles(
                    %GetParam,
                    %ACLCompatGetParam,
                    QueueID  => $GetParam{NewQueueID} || $Ticket{QueueID},
                    StateID  => $GetParam{NewStateID} || $Ticket{StateID},
                    AllUsers => $GetParam{OwnerAll},
                );
                if ( !$PossibleResponsibles->{ $GetParam{NewResponsibleID} } ) {
                    $Error{'NewResponsibleInvalid'} = 'ServerError';
                }
            }

            # check title
            if ( $Config->{Title} && !$GetParam{Title} ) {
                $Error{'TitleInvalid'} = 'ServerError';
            }

            # check type
            if (
                ( $ConfigObject->Get('Ticket::Type') )
                &&
                ( $Config->{TicketType} ) &&
                ( !$GetParam{TypeID} )
            ) {
                $Error{'TypeIDInvalid'} = ' ServerError';
            }

            # check service
            if (
                $ConfigObject->Get('Ticket::Service')
                && $Config->{Service}
                && $GetParam{SLAID}
                && !$GetParam{ServiceID}
            ) {
                $Error{'ServiceInvalid'} = ' ServerError';
            }

            # check mandatory service
            if (
                $ConfigObject->Get('Ticket::Service')
                && $Config->{Service}
                && $Config->{ServiceMandatory}
                && !$GetParam{ServiceID}
            ) {
                $Error{'ServiceInvalid'} = ' ServerError';
            }

            # check mandatory sla
            if (
                $ConfigObject->Get('Ticket::Service')
                && $Config->{Service}
                && $Config->{SLAMandatory}
                && !$GetParam{SLAID}
            ) {
                $Error{'SLAInvalid'} = ' ServerError';
            }

            # check time units, but only if the current screen has a note
            #   (accounted time can only be stored if and article is generated)
            if (
                $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
                && $Config->{Note}
                && $GetParam{TimeUnits} eq ''
            ) {
                $Error{'TimeUnitsInvalid'} = ' ServerError';
            }
        }

        # check expand
        if ( $GetParam{Expand} ) {
            %Error = ();
            $Error{Expand} = 1;
        }

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {

                # get PossibleValues
                my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                # check if field has PossibleValues property in its configuration
                if ( IsHashRefWithData($PossibleValues) ) {

                    # convert possible values key => value to key => key for ACLs using a Hash slice
                    my %AclData = %{$PossibleValues};
                    @AclData{ keys %AclData } = keys %AclData;

                    # set possible values filter from ACLs
                    $ACL = $TicketObject->TicketAcl(
                        %GetParam,
                        %ACLCompatGetParam,
                        QueueID       => $GetParam{NewQueueID} || $GetParam{QueueID} || 0,
                        Action        => $Self->{Action},
                        TicketID      => $Self->{TicketID},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => \%AclData,
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();

                        # convert Filer key => key back to key => value using map
                        %{$DynamicFieldConfig->{ShownPossibleValues}} = map { $_ => $PossibleValues->{$_} } keys %Filter;
                    }
                }
            }
        }

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $ValidationResult;

            # do not validate on attachment upload or if field is disabled
            if (
                !$IsUpload
                && $DynamicFieldConfig->{Shown}
            ) {

                $ValidationResult = $DynamicFieldBackendObject->EditFieldValueValidate(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
                    ParamObject          => $ParamObject,
                    Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                );

                if ( !IsHashRefWithData($ValidationResult) ) {
                    return $LayoutObject->ErrorScreen(
                        Message => $LayoutObject->{LanguageObject}->Translate(
                            'Could not perform validation on field %s!',
                            $DynamicFieldConfig->{Label}
                        ),
                        Comment => Translatable('Please contact the administrator.'),
                    );
                }

                # propagate validation error to the Error variable to be detected by the frontend
                if ( $ValidationResult->{ServerError} ) {
                    $Error{ $DynamicFieldConfig->{Name} } = ' ServerError';
                }
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
                Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                ServerError          => $ValidationResult->{ServerError}  || '',
                ErrorMessage         => $ValidationResult->{ErrorMessage} || '',
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
            );
        }

        # check errors
        if (%Error) {

            my $Output = $LayoutObject->Header(
                Type      => 'Small',
                Value     => $Ticket{TicketNumber},
                BodyClass => 'Popup',
            );

            $Output .= $Self->_Mask(
                Attachments       => \@Attachments,
                TimeUnitsRequired => (
                    $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
                    ? 'Validate_Required'
                    : ''
                ),
                %Ticket,
                DynamicFieldHTML => \%DynamicFieldHTML,
                IsUpload         => $IsUpload,
                %GetParam,
                %ACLCompatGetParam,
                %Error,
            );
            $Output .= $LayoutObject->Footer(
                Type => 'Small',
            );
            return $Output;
        }

        # set new title
        if ( $Config->{Title} ) {
            if ( defined $GetParam{Title} ) {
                $TicketObject->TicketTitleUpdate(
                    Title    => $GetParam{Title},
                    TicketID => $Self->{TicketID},
                    UserID   => $Self->{UserID},
                );
            }
        }

        # set new type
        if ( $ConfigObject->Get('Ticket::Type') && $Config->{TicketType} ) {
            if ( $GetParam{TypeID} ) {
                $TicketObject->TicketTypeSet(
                    %GetParam,
                    %ACLCompatGetParam,
                    TypeID   => $GetParam{TypeID},
                    TicketID => $Self->{TicketID},
                    UserID   => $Self->{UserID},
                );
            }
        }

        # set new service
        if ( $ConfigObject->Get('Ticket::Service') && $Config->{Service} ) {
            if ( defined $GetParam{ServiceID} ) {
                $TicketObject->TicketServiceSet(
                    %GetParam,
                    %ACLCompatGetParam,
                    ServiceID      => $GetParam{ServiceID},
                    TicketID       => $Self->{TicketID},
                    CustomerUserID => $Ticket{CustomerUserID},
                    UserID         => $Self->{UserID},
                );
            }
            if ( defined $GetParam{SLAID} ) {
                $TicketObject->TicketSLASet(
                    SLAID    => $GetParam{SLAID},
                    TicketID => $Self->{TicketID},
                    UserID   => $Self->{UserID},
                );
            }
        }

        my $UnlockOnAway = 1;

        # set new owner
        my @NotifyDone;
        if ( $Config->{Owner} ) {
            my $BodyText = $LayoutObject->RichText2Ascii(
                String => $GetParam{Body} || '',
            );
 
            my $Success = $TicketObject->TicketOwnerSet(
                TicketID  => $Self->{TicketID},
                UserID    => $Self->{UserID},
                NewUserID => $GetParam{NewOwnerID},
                Comment   => $BodyText,
            );

            if (
                $GetParam{NewOwnerID}
                && $GetParam{NewOwnerID} != $Ticket{OwnerID}
            ) {
                $TicketObject->TicketLockSet(
                    TicketID => $Self->{TicketID},
                    Lock     => 'lock',
                    UserID   => $Self->{UserID},
                );
                $UnlockOnAway = 0;

                # remember to not notify owner twice
                if (
                    defined $Success
                    && $Success eq '1'
                ) {
                    push @NotifyDone, $GetParam{NewOwnerID};
                }
            }
        }

        # set new responsible
        if ( $ConfigObject->Get('Ticket::Responsible') && $Config->{Responsible} ) {
            if ( $GetParam{NewResponsibleID} ) {
                my $BodyText = $LayoutObject->RichText2Ascii(
                    String => $GetParam{Body} || '',
                );
                my $Success = $TicketObject->TicketResponsibleSet(
                    TicketID  => $Self->{TicketID},
                    UserID    => $Self->{UserID},
                    NewUserID => $GetParam{NewResponsibleID},
                    Comment   => $BodyText,
                );

                # remember to not notify responsible twice
                if (
                    defined $Success
                    && $Success eq '1'
                ) {
                    push @NotifyDone, $GetParam{NewResponsibleID};
                }
            }
        }

        # move ticket to a new queue, but only if the queue was changed
        if (
            $Config->{Queue}
            && $GetParam{NewQueueID}
            && $GetParam{NewQueueID} ne $Ticket{QueueID}
        ) {

            # move ticket (send notification if no new owner is selected)
            my $BodyAsText = '';
            if ( $LayoutObject->{BrowserRichText} ) {
                $BodyAsText = $LayoutObject->RichText2Ascii(
                    String => $GetParam{Body} || 0,
                );
            }
            else {
                $BodyAsText = $GetParam{Body} || 0;
            }
            my $Move = $TicketObject->TicketQueueSet(
                QueueID            => $GetParam{NewQueueID},
                UserID             => $Self->{UserID},
                TicketID           => $Self->{TicketID},
                SendNoNotification => $GetParam{NewUserID},
                Comment            => $BodyAsText,
            );
            if ( !$Move ) {
                return $LayoutObject->ErrorScreen();
            }
        }

        # add note
        my $ArticleID = '';
        my $ReturnURL;

        # set priority
        if ( $Config->{Priority} && $GetParam{NewPriorityID} ) {
            $TicketObject->TicketPrioritySet(
                TicketID   => $Self->{TicketID},
                PriorityID => $GetParam{NewPriorityID},
                UserID     => $Self->{UserID},
            );
        }

        # set state
        if ( $Config->{State} && $GetParam{NewStateID} ) {
            $TicketObject->TicketStateSet(
                TicketID     => $Self->{TicketID},
                StateID      => $GetParam{NewStateID},
                UserID       => $Self->{UserID},
                DynamicField => $GetParam{DynamicField},
            );

            # unlock the ticket after close
            my %StateData = $StateObject->StateGet(
                ID => $GetParam{NewStateID},
            );

            # set unlock on close state
            if ( $StateData{TypeName} =~ /^close/i ) {
                $TicketObject->TicketLockSet(
                    TicketID => $Self->{TicketID},
                    Lock     => 'unlock',
                    UserID   => $Self->{UserID},
                );
            }

            # set pending time on pending state
            elsif ( $StateData{TypeName} =~ /^pending/i ) {

                # set pending time
                $TicketObject->TicketPendingTimeSet(
                    UserID   => $Self->{UserID},
                    TicketID => $Self->{TicketID},
                    %GetParam,
                );
            }

            # redirect parent window to last screen overview on closed tickets
            if (
                !$Self->{RedirectDestination}
                && $StateData{TypeName}
                && $StateData{TypeName} =~ /^close/i
            ) {
                $ReturnURL = $Self->{LastScreenOverview} || 'Action=AgentDashboard';
            }
        }

        if (
            $GetParam{CreateArticle}
            && $Config->{Note}
            && ( $GetParam{Subject} || $GetParam{Body} )
        ) {

            if ( !$GetParam{Subject} ) {
                if ( $Config->{Subject} ) {
                    my $Subject = $LayoutObject->Output(
                        Template => $Config->{Subject},
                    );
                    $GetParam{Subject} = $Subject;
                }
                $GetParam{Subject} = $GetParam{Subject}
                    || $LayoutObject->{LanguageObject}->Translate('No subject');
            }

            # if there is no ArticleTypeID, use the default value
            if ( !defined $GetParam{ArticleTypeID} ) {
                $GetParam{ArticleType} = $Config->{ArticleTypeDefault};
            }

            # get pre loaded attachment
            my @NewAttachments = $UploadCacheObject->FormIDGetAllFilesData(
                FormID => $Self->{FormID},
            );

            # get submit attachment
            my %UploadStuff = $ParamObject->GetUploadAll(
                Param => 'FileUpload',
            );
            if (%UploadStuff) {
                push @NewAttachments, \%UploadStuff;
            }

            my $MimeType = 'text/plain';
            if ( $LayoutObject->{BrowserRichText} ) {
                $MimeType = 'text/html';

                # remove unused inline images
                my @NewAttachmentData;
                ATTACHMENT:
                for my $Attachment (@NewAttachments) {
                    my $ContentID = $Attachment->{ContentID};
                    if (
                        $ContentID
                        && ( $Attachment->{ContentType} =~ /image/i )
                        && ( $Attachment->{Disposition} eq 'inline' )
                    ) {
                        my $ContentIDHTMLQuote = $LayoutObject->Ascii2Html(
                            Text => $ContentID,
                        );

                        # workaround for link encode of rich text editor, see bug#5053
                        my $ContentIDLinkEncode = $LayoutObject->LinkEncode($ContentID);
                        $GetParam{Body} =~ s/(ContentID=)$ContentIDLinkEncode/$1$ContentID/g;

                        # ignore attachment if not linked in body
                        next ATTACHMENT
                            if $GetParam{Body} !~ /(?:\Q$ContentIDHTMLQuote\E|\Q$ContentID\E)/i;
                    }

                    # remember inline images and normal attachments
                    push @NewAttachmentData, \%{$Attachment};
                }
                @NewAttachments = @NewAttachmentData;

                # verify html document
                $GetParam{Body} = $LayoutObject->RichTextDocumentComplete(
                    String => $GetParam{Body},
                );
            }

            my $From = "\"$Self->{UserFirstname} $Self->{UserLastname}\" <$Self->{UserEmail}>";
            my @NotifyUserIDs;

            # get list of users that will be informed without selection in informed/involved list
            my @UserListWithoutSelection
                = split( ',', $ParamObject->GetParam( Param => 'UserListWithoutSelection' ) || "" );

            # get inform user list
            my @InformUserID = $ParamObject->GetArray( Param => 'InformUserID' );

            # get involved user list
            my @InvolvedUserID = $ParamObject->GetArray( Param => 'InvolvedUserID' );

            if ( $Config->{InformAgent} ) {
                push @NotifyUserIDs, @InformUserID;
            }

            if ( $Config->{InvolvedAgent} ) {
                push @NotifyUserIDs, @InvolvedUserID;
            }

            if ( $Self->{ReplyToArticle} ) {
                push @NotifyUserIDs, @UserListWithoutSelection;
            }

            $ArticleID = $TicketObject->ArticleCreate(
                TicketID                        => $Self->{TicketID},
                SenderType                      => 'agent',
                From                            => $From,
                MimeType                        => $MimeType,
                Charset                         => $LayoutObject->{UserCharset},
                UserID                          => $Self->{UserID},
                HistoryType                     => $Config->{HistoryType},
                HistoryComment                  => $Config->{HistoryComment},
                ForceNotificationToUserID       => \@NotifyUserIDs,
                ExcludeMuteNotificationToUserID => \@NotifyDone,
                UnlockOnAway                    => $UnlockOnAway,
                Attachment                      => \@NewAttachments,
                %GetParam,
            );
            if ( !$ArticleID ) {
                return $LayoutObject->ErrorScreen();
            }

            # time accounting
            if ( $GetParam{TimeUnits} ) {
                $TicketObject->TicketAccountTime(
                    TicketID  => $Self->{TicketID},
                    ArticleID => $ArticleID,
                    TimeUnit  => $GetParam{TimeUnits},
                    UserID    => $Self->{UserID},
                );
            }

            # remove pre submitted attachments
            $UploadCacheObject->FormIDRemove( FormID => $Self->{FormID} );
        }

        # set dynamic fields
        # cycle through the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if !$DynamicFieldConfig->{Shown};

            # set the object ID (TicketID or ArticleID) depending on the field configration
            my $ObjectID = $DynamicFieldConfig->{ObjectType} eq 'Article' ? $ArticleID : $Self->{TicketID};

            # set the value
            my $Success = $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $ObjectID,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $Self->{UserID},
            );
        }
# ---
# ITSMIncidentProblemManagement
# ---
        if ( ($GetParam{ServiceID} && $Service{Criticality} ) || !$GetParam{ServiceID} ) {

            # get config for criticality dynamic field
            my $CriticalityDynamicFieldConfig = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
                Name => 'ITSMCriticality',
            );

            # get possible values for criticality
            my $CriticalityPossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                DynamicFieldConfig => $CriticalityDynamicFieldConfig,
            );

            # reverse the list to find out the key
            my %ReverseCriticalityPossibleValues = reverse %{ $CriticalityPossibleValues };

            # set the criticality
            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $CriticalityDynamicFieldConfig,
                ObjectID           => $Self->{TicketID},
                Value              => $ReverseCriticalityPossibleValues{ $Service{Criticality} || '' },
                UserID             => $Self->{UserID},
            );
        }
# ---

        # set priority
        if ( $Config->{Priority} && $GetParam{NewPriorityID} ) {
            $TicketObject->TicketPrioritySet(
                TicketID   => $Self->{TicketID},
                PriorityID => $GetParam{NewPriorityID},
                UserID     => $Self->{UserID},
            );
        }

        # load new URL in parent window and close popup
        $ReturnURL ||= "Action=AgentTicketZoom;TicketID=$Self->{TicketID};ArticleID=$ArticleID";

        # use redirect adress according to module configuration
        if ( $Config->{RedirectURL} ) {
            $ReturnURL =
                $Config->{RedirectURL} . ";TicketID=$Self->{TicketID};ArticleID=$ArticleID";
        }

        return $LayoutObject->PopupClose(
            URL => $ReturnURL,
        );
    }

    # ---
    # ITSMIncidentProblemManagement
    # ---
    elsif ( $Self->{Subaction} eq 'GetServiceIncidentState' ) {

        # get the selected service id
        my $ServiceID = $ParamObject->GetParam( Param => 'ServiceID' ) || '';

        # build empty response hash
        my %Response = (
            CurInciSignal => '',
            CurInciState  => '&nbsp',
        );

        # only if service id is selected and incident state should be shown in this screen
        if ( $ServiceID && $Config->{ShowIncidentState} ) {

            # set incident signal
            my %InciSignals = (
                operational => 'greenled',
                warning     => 'yellowled',
                incident    => 'redled',
            );

            # build the response
            %Response = (
                CurInciSignal => $InciSignals{ $Service{CurInciStateType} },
                CurInciState  => $LayoutObject->{LanguageObject}->Translate($Service{CurInciState}),
            );
        }

        # encode response to JSON
        my $JSON = $LayoutObject->JSONEncode(
            Data => \%Response,
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # ---
    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {
        my $CustomerUser = $GetParam{SelectedCustomerUser} || $Ticket{CustomerUserID};
        my $ElementChanged = $ParamObject->GetParam( Param => 'ElementChanged' ) || '';
        my $ServiceID;

        # get service value from param if field is visible in the screen
        if ( $ConfigObject->Get('Ticket::Service') && $Config->{Service} ) {
            $ServiceID = $GetParam{ServiceID} || '';
        }

        # otherwise use ticket service value since it can't be changed
        elsif ( $ConfigObject->Get('Ticket::Service') ) {
            $ServiceID = $Ticket{ServiceID} || '';
        }

        my $QueueID = $GetParam{NewQueueID} || $Ticket{QueueID};
        my $StateID = $GetParam{NewStateID} || $Ticket{StateID};

        # get list type
        my $TreeView = 0;
        if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
            $TreeView = 1;
        }

        my $Owners = $Self->_GetOwners(
            %GetParam,
            %ACLCompatGetParam,
            QueueID  => $QueueID,
            StateID  => $StateID,
            AllUsers => $GetParam{OwnerAll},
        );
        my $OldOwners = $Self->_GetOldOwners(
            %GetParam,
            %ACLCompatGetParam,
            QueueID  => $QueueID,
            StateID  => $StateID,
            AllUsers => $GetParam{OwnerAll},
        );
        my $ResponsibleUsers = $Self->_GetResponsibles(
            %GetParam,
            %ACLCompatGetParam,
            QueueID  => $QueueID,
            StateID  => $StateID,
            AllUsers => $GetParam{OwnerAll},
        );
        my $Priorities = $Self->_GetPriorities(
            %GetParam,
            %ACLCompatGetParam,
        );
        my $Services = $Self->_GetServices(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser,
            QueueID        => $QueueID,
            StateID        => $StateID,
        );
        my $Types = $Self->_GetTypes(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser,
            QueueID        => $QueueID,
            StateID        => $StateID,
        );

        my %MoveQueues = $TicketObject->TicketMoveList(
            %GetParam,
            %ACLCompatGetParam,
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID},
            Action   => $Self->{Action},
            Type     => 'move_into',
        );

        # reset previous ServiceID to reset SLA-List if no service is selected
        if ( !defined $ServiceID || !$Services->{$ServiceID} ) {
            $ServiceID = '';
        }

        # get assigned queue if set
        if ( $ServiceID && $GetParam{ElementChanged} eq 'ServiceID' ) {

            # retrieve service data...
            my %ServiceData = $Kernel::OM->Get('Kernel::System::Service')->ServiceGet(
                ServiceID => $ServiceID,
                UserID    => 1,
            );

            if ( %ServiceData && $ServiceData{AssignedQueueID} ) {
                $QueueID = $ServiceData{AssignedQueueID};

                # re-evaluate owners and responsible
                $Owners = $Self->_GetOwners(
                    %GetParam,
                     %ACLCompatGetParam,
                    QueueID  => $QueueID,
                    NewQueueID => $QueueID,
                    AllUsers => $GetParam{OwnerAll},
                );
                $OldOwners = $Self->_GetOldOwners(
                    %GetParam,
                    %ACLCompatGetParam,
                    QueueID  => $QueueID,
                    NewQueueID => $QueueID,
                    AllUsers => $GetParam{OwnerAll},
                );
                $ResponsibleUsers = $Self->_GetResponsibles(
                    %GetParam,
                    %ACLCompatGetParam,
                    QueueID  => $QueueID,
                    NewQueueID => $QueueID,
                    AllUsers => $GetParam{OwnerAll},
                );
            }
        }

        my $SLAs = $Self->_GetSLAs(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser,
            QueueID        => $QueueID,
            StateID        => $StateID,
            ServiceID      => $ServiceID,
        );
        my $NextStates = $Self->_GetNextStates(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser || '',
            QueueID        => $QueueID,
            StateID        => $StateID,
        );

        # update Dynamic Fields Possible Values via AJAX
        my @DynamicFieldAJAX;
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ( !$IsACLReducible ) {
                $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                    $DynamicFieldBackendObject->EditFieldRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Mandatory =>
                        $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                    LayoutObject    => $LayoutObject,
                    ParamObject     => $ParamObject,
                    AJAXUpdate      => 0,
                    UpdatableFields => $Self->_GetFieldsToUpdate(),
                    );

                next DYNAMICFIELD;
            }

            my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            # convert possible values key => value to key => key for ACLs using a Hash slice
            my %AclData = %{$PossibleValues};
            @AclData{ keys %AclData } = keys %AclData;

            # set possible values filter from ACLs
            $ACL = $TicketObject->TicketAcl(
                %GetParam,
                %ACLCompatGetParam,
                Action        => $Self->{Action},
                TicketID      => $Self->{TicketID},
                QueueID       => $GetParam{NewQueueID} || $QueueID || 0,
                ReturnType    => 'Ticket',
                ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data          => \%AclData,
                UserID        => $Self->{UserID},
            );
            if ($ACL) {
                my %Filter = $TicketObject->TicketAclData();

                # convert Filer key => key back to key => value using map
                %{$PossibleValues} = map { $_ => $PossibleValues->{$_} } keys %Filter;
            }

            my $DataValues = $DynamicFieldBackendObject->BuildSelectionDataGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                PossibleValues     => $PossibleValues,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            ) || $PossibleValues;

            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValues,
                Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
            );

            # add dynamic field to the list of fields to update
            push(
                @DynamicFieldAJAX,
                {
                    Name        => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data        => $DataValues,
                    SelectedID  => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                    Translation => $DynamicFieldConfig->{Config}->{TranslatableValues} || 0,
                    Max         => 100,
                }
            );
        }

        # if we have DynamicFields use just those that are OK by ACL Rules
        my %Output;
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {

            for my $DynamicFieldHTMLKey ( ('Label', 'Field') ) {
                my $CurrentDynamicFieldHTML
                    = $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }->{ $DynamicFieldHTMLKey };
                $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }->{ $DynamicFieldHTMLKey }
                    = $CurrentDynamicFieldHTML;
            }
            if ( $DynamicFieldConfig->{Shown} == 1 ) {
                $Output{ ( "DynamicField_" . $DynamicFieldConfig->{Name} ) } = (
                    $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }->{Label}
                        . qq~\n<div class="Field">~
                        . $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }->{Field}
                        . qq~\n</div>\n<div class="Clear"></div>\n~
                );
            }
            else {
                $Output{ ( "DynamicField_" . $DynamicFieldConfig->{Name} ) } = "";
            }
        }

        my @FormDisplayOutput;
        if ( IsHashRefWithData( \%Output ) ) {
            push @FormDisplayOutput, {
                Name => 'FormDisplay',
                Data => \%Output,
                Max  => 10000,
            };
        }

        my $StandardTemplates = $Self->_GetStandardTemplates(
            %GetParam,
            QueueID => $QueueID || '',
        );

        my @TemplateAJAX;

        # update ticket body and attachements if needed.
        if ( $ElementChanged eq 'StandardTemplateID' ) {
            my @TicketAttachments;
            my $TemplateText;

            # remove all attachments from the Upload cache
            my $RemoveSuccess = $UploadCacheObject->FormIDRemove(
                FormID => $Self->{FormID},
            );
            if ( !$RemoveSuccess ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Form attachments could not be deleted!",
                );
            }

            # get the template text and set new attachments if a template is selected
            if ( IsPositiveInteger( $GetParam{StandardTemplateID} ) ) {
                my $TemplateGenerator = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

                # set template text, replace smart tags (limited as ticket is not created)
                $TemplateText = $TemplateGenerator->Template(
                    TemplateID => $GetParam{StandardTemplateID},
                    TicketID   => $Self->{TicketID},
                    UserID     => $Self->{UserID},
                );

                # if ReplyToArticle is given, get this article to generate
                # the quoted article content
                if ( $Self->{ReplyToArticle} ) {

                    # get article to quote
                    my $Body = $LayoutObject->ArticleQuote(
                        TicketID          => $Self->{TicketID},
                        ArticleID         => $Self->{ReplyToArticle},
                        FormID            => $Self->{FormID},
                        UploadCacheObject => $UploadCacheObject,
                    );

                    # prepare quoted body content
                    $Body = $Self->_GetQuotedReplyBody(
                        %{ $Self->{ReplyToArticleContent} },
                        Body => $Body,
                    );

                    if ( $LayoutObject->{BrowserRichText} ) {
                        $TemplateText = $TemplateText . '<br><br>' . $Body;
                    }
                    else {
                        $TemplateText = $TemplateText . "\n\n" . $Body;
                    }
                }

                # create StdAttachmentObject
                my $StdAttachmentObject = $Kernel::OM->Get('Kernel::System::StdAttachment');

                # add std. attachments to ticket
                my %AllStdAttachments = $StdAttachmentObject->StdAttachmentStandardTemplateMemberList(
                    StandardTemplateID => $GetParam{StandardTemplateID},
                );
                for ( sort keys %AllStdAttachments ) {
                    my %AttachmentsData = $StdAttachmentObject->StdAttachmentGet( ID => $_ );
                    $UploadCacheObject->FormIDAddFile(
                        FormID      => $Self->{FormID},
                        Disposition => 'attachment',
                        %AttachmentsData,
                    );
                }

                # send a list of attachments in the upload cache back to the clientside JavaScript
                # which renders then the list of currently uploaded attachments
                @TicketAttachments = $UploadCacheObject->FormIDGetAllFilesMeta(
                    FormID => $Self->{FormID},
                );
            }

            @TemplateAJAX = (
                {
                    Name => 'UseTemplateNote',
                    Data => '0',
                },
                {
                    Name => 'RichText',
                    Data => $TemplateText || '',
                },
                {
                    Name     => 'TicketAttachments',
                    Data     => \@TicketAttachments,
                    KeepData => 1,
                },
            );
        }

        # create hash with DisabledOptions
        my $ListOptionJson = $LayoutObject->AgentListOptionJSON(
            [
                {
                    Name => 'NewQueueID',
                    Data => \%MoveQueues,
                },
                {
                    Name => 'Services',
                    Data => $Services,
                },
            ],
        );

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name            => 'NewQueueID',
                    Data            => $ListOptionJson->{NewQueueID}->{Data},
                    SelectedID      => $QueueID,
                    Translation     => 0,
                    PossibleNone    => 1,
                    TreeView        => $TreeView,
                    Max             => 100,
                    DisabledOptions => $ListOptionJson->{NewQueueID}->{DisabledOptions} || 0,
                },
                {
                    Name         => 'NewOwnerID',
                    Data         => $Owners,
                    SelectedID   => $GetParam{NewOwnerID},
                    Translation  => 0,
                    PossibleNone => 1,
                    Max          => 100,
                },
                {
                    Name         => 'OldOwnerID',
                    Data         => $OldOwners,
                    SelectedID   => $GetParam{OldOwnerID},
                    Translation  => 0,
                    PossibleNone => 1,
                    Max          => 100,
                },
                {
                    Name         => 'NewResponsibleID',
                    Data         => $ResponsibleUsers,
                    SelectedID   => $GetParam{NewResponsibleID},
                    Translation  => 0,
                    PossibleNone => 1,
                    Max          => 100,
                },
                {
                    Name         => 'NewStateID',
                    Data         => $NextStates,
                    SelectedID   => $GetParam{NewStateID},
                    Translation  => 1,
                    PossibleNone => $Config->{StateDefault} ? 0 : 1,
                    Max          => 100,
                },
                {
                    Name         => 'NewPriorityID',
                    Data         => $Priorities,
                    SelectedID   => $GetParam{NewPriorityID},
                    PossibleNone => 0,
                    Translation  => 1,
                    Max          => 100,
                },
                {
                    Name            => 'ServiceID',
                    Data            => $ListOptionJson->{Services}->{Data},
                    SelectedID      => $GetParam{ServiceID},
                    PossibleNone    => 1,
                    Translation     => $ConfigObject->Get('Ticket::ServiceTranslation') || 0,
                    TreeView        => $TreeView,
                    DisabledOptions => $ListOptionJson->{Services}->{DisabledOptions} || 0,
                    Max             => 100,
                },
                {
                    Name         => 'SLAID',
                    Data         => $SLAs,
                    SelectedID   => $GetParam{SLAID},
                    PossibleNone => 1,
                    Translation  => $ConfigObject->Get('Ticket::SLATranslation') || 0,
                    Max          => 100,
                },
                {
                    Name         => 'StandardTemplateID',
                    Data         => $StandardTemplates,
                    SelectedID   => $GetParam{StandardTemplateID},
                    PossibleNone => 1,
                    Translation  => 1,
                    Max          => 100,
                },
                {
                    Name         => 'TypeID',
                    Data         => $Types,
                    SelectedID   => $GetParam{TypeID},
                    PossibleNone => 1,
                    Translation  => 0,
                    Max          => 100,
                },
                @DynamicFieldAJAX,
                @TemplateAJAX,
                @FormDisplayOutput,
            ],
        );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # update position
    elsif ( $Self->{Subaction} eq 'UpdatePosition' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my @Backends = $ParamObject->GetArray( Param => 'Backend' );

        # get new order
        my $Key  = $Self->{Action} . 'Position';
        my $Data = '';
        for my $Backend (@Backends) {
            $Data .= $Backend . ';';
        }

        # update ssession
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => $Key,
            Value     => $Data,
        );

        # update preferences
        if ( !$ConfigObject->Get('DemoSystem') ) {
            $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Key,
                Value  => $Data,
            );
        }

        # redirect
        return $LayoutObject->Attachment(
            ContentType => 'text/html',
            Charset     => $LayoutObject->{UserCharset},
            Content     => '',
        );
    }

    else {

        my $Body = '';

        # if ReplyToArticle is given, get this article to generate
        # the quoted article content
        if ( $Self->{ReplyToArticle} ) {

            # get article to quote
            $Body = $LayoutObject->ArticleQuote(
                TicketID          => $Self->{TicketID},
                ArticleID         => $Self->{ReplyToArticle},
                FormID            => $Self->{FormID},
                UploadCacheObject => $UploadCacheObject,
            );

            # prepare quoted body content
            $Body = $Self->_GetQuotedReplyBody(
                %{ $Self->{ReplyToArticleContent} },
                Body => $Body,
            );
        }

        # if a body content was pre defined, add this before the quoted article content
        if ( $GetParam{Body} ) {

            # make sure body is rich text
            if ( $LayoutObject->{BrowserRichText} ) {
                $GetParam{Body} = $LayoutObject->Ascii2RichText(
                    String => $GetParam{Body},
                );
            }

            $Body = $GetParam{Body} . $Body;
        }

        # fillup configured default vars
        if ( $Body eq '' && $Config->{Body} ) {
            $Body = $LayoutObject->Output(
                Template => $Config->{Body},
            );

            # make sure body is rich text
            if ( $LayoutObject->{BrowserRichText} ) {
                $Body = $LayoutObject->Ascii2RichText(
                    String => $Body,
                );
            }
        }

        # set Body var to calculated content
        $GetParam{Body} = $Body;

        # check if external sources should be removed from body
        if ( $ConfigObject->Get('Frontend::RemoveExternalSource') ) {
            my %SafetyCheckResultNoExt = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
                String       => $GetParam{Body},
                NoExtSrcLoad => 1,
            );
            $GetParam{Body} = $SafetyCheckResultNoExt{String};
        }

        if ( $Self->{ReplyToArticle} ) {
            my $TicketSubjectRe = $ConfigObject->Get('Ticket::SubjectRe') || 'Re';
            $GetParam{Subject} = $TicketSubjectRe . ': ' . $Self->{ReplyToArticleContent}{Subject};
        }
        elsif ( !defined $GetParam{Subject} && $Config->{Subject} ) {
            $GetParam{Subject} = $LayoutObject->Output(
                Template => $Config->{Subject},
            );
        }

        else {

            # fillup configured default vars
            if ( !defined $GetParam{Body} && $Config->{Body} ) {
                $GetParam{Body} = $LayoutObject->Output(
                    Template => $Config->{Body},
                );

                # make sure body is rich text
                if ( $LayoutObject->{BrowserRichText} ) {
                    $GetParam{Body} = $LayoutObject->Ascii2RichText(
                        String => $GetParam{Body},
                    );
                }
            }
            if ( !defined $GetParam{Subject} && $Config->{Subject} ) {
                $GetParam{Subject} = $LayoutObject->Output(
                    Template => $Config->{Subject},
                );
            }
        }

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {

                # get PossibleValues
                my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                );

                # check if field has PossibleValues property in its configuration
                if ( IsHashRefWithData($PossibleValues) ) {

                    # convert possible values key => value to key => key for ACLs using a Hash slice
                    my %AclData = %{$PossibleValues};
                    @AclData{ keys %AclData } = keys %AclData;

                    # set possible values filter from ACLs
                    $ACL = $TicketObject->TicketAcl(
                        %GetParam,
                        %ACLCompatGetParam,
                        Action        => $Self->{Action},
                        TicketID      => $Self->{TicketID},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => \%AclData,
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();

                        # convert Filer key => key back to key => value using map
                        %{$DynamicFieldConfig->{ShownPossibleValues}} = map { $_ => $PossibleValues->{$_} }
                            keys %Filter;
                    }
                }
            }
        }

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # to store dynamic field value from database (or undefined)
            my $Value;

            # only get values for Ticket fields (all screens based on AgentTickeActionCommon
            # generates a new article, then article fields will be always empty at the beginning)
            if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {

                # get value stored on the database from Ticket
                $Value = $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
                Value                => $Value,
                Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
            );
        }

        # print form ...
        my $Output = $LayoutObject->Header(
            Type      => 'Small',
            Value     => $Ticket{TicketNumber},
            BodyClass => 'Popup',
        );
        $Output .= $Self->_Mask(
            TimeUnitsRequired => (
                $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
                ? 'Validate_Required'
                : ''
            ),
            %GetParam,
            %ACLCompatGetParam,
            %Ticket,
            DynamicFieldHTML => \%DynamicFieldHTML,
        );

        $Output .= $LayoutObject->Footer(
            Type => 'Small',
        );
        return $Output;
    }
}

sub _Mask {
    my ( $Self, %Param ) = @_;

    # get list type
    my $TreeView = 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
        $TreeView = 1;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # get config of frontend module
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # load KIXSidebar
    $Param{KIXSidebarContent} = $LayoutObject->AgentKIXSidebar(
        %Param,
        %Ticket,
        Action => $Self->{Action}
    );
    $Param{SidebarWidthString} = $Self->{Action} . 'SidebarWidth';
    $LayoutObject->Block(
        Name => 'KIXSidebar',
        Data => \%Param,
    );

    # Widget Ticket Actions
    if (
        (
            $ConfigObject->Get('Ticket::Type')
            && $Config->{TicketType}
        )
        || (
            $ConfigObject->Get('Ticket::Service')
            && $Config->{Service}
        )
        || (
            $ConfigObject->Get('Ticket::Responsible')
            && $Config->{Responsible}
        )
        || $Config->{Title}
        || $Config->{Queue}
        || $Config->{Owner}
        || $Config->{State}
        || $Config->{Priority}
    ) {
        $LayoutObject->Block(
            Name => 'WidgetTicketActions',
        );
    }

    if ( $Config->{Title} ) {
        $LayoutObject->Block(
            Name => 'Title',
            Data => \%Param,
        );
    }

    my $DynamicFieldNames = $Self->_GetFieldsToUpdate(
        OnlyDynamicFields => 1,
    );

    # create a string with the quoted dynamic field names separated by commas
    if ( !$Param{DynamicFieldNamesStrg} ) {
        $Param{DynamicFieldNamesStrg} = '';
    }

    # create a string with the quoted dynamic field names separated by commas
    if ( IsArrayRefWithData($DynamicFieldNames) ) {
        for my $Field ( @{$DynamicFieldNames} ) {
            $Param{DynamicFieldNamesStrg} .= ", '" . $Field . "'";
        }
    }

    # types
    if ( $ConfigObject->Get('Ticket::Type') && $Config->{TicketType} ) {
        my %Type = $TicketObject->TicketTypeList(
            %Param,
            Action => $Self->{Action},
            UserID => $Self->{UserID},
        );
        $Param{TypeStrg} = $LayoutObject->BuildSelection(
            Class => 'Validate_Required Modernize ' . ( $Param{Errors}->{TypeIDInvalid} || ' ' ),
            Data  => \%Type,
            Name  => 'TypeID',
            SelectedID   => $Param{TypeID},
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 0,
        );
        $LayoutObject->Block(
            Name => 'Type',
            Data => {%Param},
        );
    }

    # services
    if ( $ConfigObject->Get('Ticket::Service') && $Config->{Service} ) {
        my $Services = $Self->_GetServices(
            %Param,
            Action         => $Self->{Action},
            CustomerUserID => $Ticket{CustomerUserID},
            UserID         => $Self->{UserID},
        );

        my $ListOptionJson = $LayoutObject->AgentListOptionJSON(
            [
                {
                    Name => 'Services',
                    Data => $Services,
                },
            ],
        );

        # reset previous ServiceID to reset SLA-List if no service is selected
        if ( !$Param{ServiceID} || !$Services->{ $Param{ServiceID} } ) {
            $Param{ServiceID} = '';
        }

        if ( $Config->{ServiceMandatory} ) {

            $Param{ServiceStrg} = $LayoutObject->BuildSelection(
                Data            => $ListOptionJson->{Services}->{Data},
                Name            => 'ServiceID',
                SelectedID      => $Param{ServiceID},
                Class           => 'Validate_Required Modernize ' . ( $Param{ServiceInvalid} || ' ' ),
                PossibleNone    => 1,
                TreeView        => $TreeView,
                DisabledOptions => $ListOptionJson->{Services}->{DisabledOptions} || 0,
                Sort            => 'TreeView',
                Translation     => $ConfigObject->Get('Ticket::ServiceTranslation') || 0,
                Max             => 200,
            );

            $LayoutObject->Block(
                Name => 'ServiceMandatory',
                Data => {%Param},
            );
        }
        else {

            $Param{ServiceStrg} = $LayoutObject->BuildSelection(
                Data            => $ListOptionJson->{Services}->{Data},
                Name            => 'ServiceID',
                SelectedID      => $Param{ServiceID},
                Class           => 'Modernize ' . ( $Param{ServiceInvalid} || ' ' ),
                PossibleNone    => 1,
                TreeView        => $TreeView,
                Sort            => 'TreeView',
                DisabledOptions => $ListOptionJson->{Services}->{DisabledOptions} || 0,
                Translation     => $ConfigObject->Get('Ticket::ServiceTranslation') || 0,
                Max             => 200,
            );

            $LayoutObject->Block(
                Name => 'Service',
                Data => {%Param},
            );
        }

        my %SLA = $TicketObject->TicketSLAList(
            %Param,
            Action => $Self->{Action},
            UserID => $Self->{UserID},
        );

        if ( $Config->{SLAMandatory} ) {

            $Param{SLAStrg} = $LayoutObject->BuildSelection(
                Data         => \%SLA,
                Name         => 'SLAID',
                SelectedID   => $Param{SLAID},
                Class        => 'Validate_Required Modernize ' . ( $Param{SLAInvalid} || ' ' ),
                PossibleNone => 1,
                Sort         => 'AlphanumericValue',
                Translation  => $ConfigObject->Get('Ticket::SLATranslation') || 0,
                Max          => 200,
            );

            $LayoutObject->Block(
                Name => 'SLAMandatory',
                Data => {%Param},
            );
        }
        else {

            $Param{SLAStrg} = $LayoutObject->BuildSelection(
                Data         => \%SLA,
                Name         => 'SLAID',
                SelectedID   => $Param{SLAID},
                Class        => 'Modernize',
                PossibleNone => 1,
                Sort         => 'AlphanumericValue',
                Translation  => $ConfigObject->Get('Ticket::SLATranslation') || 0,
                Max          => 200,
            );

            $LayoutObject->Block(
                Name => 'SLA',
                Data => {%Param},
            );
        }
    }

    if ( $Config->{Queue} ) {

        # fetch all queues
        my %MoveQueues = $TicketObject->TicketMoveList(
            %Param,
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID},
            Action   => $Self->{Action},
            Type     => 'move_into',
        );

        # set move queues
        $Param{QueuesStrg} = $LayoutObject->AgentQueueListOption(
            Data           => { %MoveQueues, '' => '-' },
            Multiple       => 0,
            Size           => 0,
            Class          => 'NewQueueID Modernize',
            Name           => 'NewQueueID',
            SelectedID     => $Param{NewQueueID} || '',
            TreeView       => $TreeView,
            CurrentQueueID => $Param{QueueID},
            OnChangeSubmit => 0,
        );

        $LayoutObject->Block(
            Name => 'Queue',
            Data => {%Param},
        );
    }

    # get needed objects
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');

    my %InitialSelected;
    if (
        $ConfigObject->Get('Ticket::ProcessingOptions::InitialDataShown')
        && $ConfigObject->Get('Ticket::ProcessingOptions::InitialDataShown')->{ $Self->{Action} }
    ) {
        $InitialSelected{OwnerID}       = $Ticket{OwnerID};
        $InitialSelected{ResponsibleID} = $Ticket{ResponsibleID};
        $InitialSelected{State}         = $Ticket{State};
    }

    if ( $Config->{Owner} ) {
        # get available permissions and set permission group type accordingly.
        my $ConfigPermissions   = $ConfigObject->Get('System::Permission');
        my $PermissionGroupType = ( grep { $_ eq 'owner' } @{$ConfigPermissions} ) ? 'owner' : 'rw';

        # get login list of users
        my %UserLoginList = $UserObject->UserList(
            Type  => 'Short',
            Valid => 1,
        );

        # prepare acl data
        my %ACLUsers;

        # show all system users
        if ( $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
            %ACLUsers = %UserLoginList;
        }

        # show all subscribed users who have the appropriate permission in the queue group
        else {
            my $GID = $QueueObject->GetQueueGroupID(
                QueueID => $Ticket{QueueID}
            );

            my %MemberList = $GroupObject->PermissionGroupGet(
                GroupID => $GID,
                Type    => $PermissionGroupType,
            );

            for my $MemberKey ( keys( %MemberList ) ) {
                if ( $UserLoginList{ $MemberKey } ) {
                    $ACLUsers{ $MemberKey } = $UserLoginList{ $MemberKey };
                }
            }
        }

        # apply acl
        my $ACL = $TicketObject->TicketAcl(
            %Ticket,
            Action        => $Self->{Action},
            ReturnType    => 'Ticket',
            ReturnSubType => 'NewOwner',
            Data          => \%ACLUsers,
            UserID        => $Self->{UserID},
        );
        if ( $ACL ) {
            %ACLUsers = $TicketObject->TicketAclData();
        }

        # prepare display data
        my %UserNameList = $UserObject->UserList(
            Type  => 'Long',
            Valid => 1,
        );
        my %ShownUsers = map( { $_ => $UserNameList{$_} } keys( %ACLUsers ) );

        # get previous ticket owner
        my %OldUserNameList;
        my %OldACLUsers;
        my @OldUserInfo = $TicketObject->TicketOwnerList(
            TicketID => $Self->{TicketID}
        );
        if ( @OldUserInfo ) {
            my $Counter = 1;
            USER:
            for my $User ( reverse @OldUserInfo ) {
                next USER if $OldACLUsers{ $User->{UserID} };

                $OldACLUsers{ $User->{UserID} } = $User->{UserLogin};

                $OldUserNameList{ $User->{UserID} } = "$Counter: $User->{UserFullname}";
                $Counter++;
            }
        }

        # apply acl
        my $OldACL = $TicketObject->TicketAcl(
            %Ticket,
            Action        => $Self->{Action},
            ReturnType    => 'Ticket',
            ReturnSubType => 'OldOwner',
            Data          => \%OldACLUsers,
            UserID        => $Self->{UserID},
        );
        if ( $OldACL ) {
            %OldACLUsers = $TicketObject->TicketAclData();
        }

        # prepare display data
        my %OldOwnersShown = map( { $_ => $OldUserNameList{$_} } keys( %OldACLUsers ) );

        # build string
        $Param{OwnerStrg} = $LayoutObject->BuildSelection(
            Data       => \%ShownUsers,
            SelectedID => $Param{NewOwnerID} || $InitialSelected{OwnerID},
            Name       => 'NewOwnerID',
            Class      => 'Modernize '
                . ( $Config->{OwnerMandatory} ? 'Validate_Required ' : '' )
                . ( $Param{NewOwnerInvalid} || '' ),
            Size         => 1,
            PossibleNone => 1,
            Filters      => {
                OldOwners => {
                    Name   => $LayoutObject->{LanguageObject}->Translate('Previous Owner'),
                    Values => \%OldOwnersShown,
                },
            },
        );

        $LayoutObject->Block(
            Name => $Config->{OwnerMandatory} ? 'OwnerMandatory' : 'Owner',
            Data => \%Param,
        );
    }

    if ( $ConfigObject->Get('Ticket::Responsible') && $Config->{Responsible} ) {

        # get available permissions and set permission group type accordingly.
        my $ConfigPermissions   = $ConfigObject->Get('System::Permission');
        my $PermissionGroupType = ( grep { $_ eq 'responsible' } @{$ConfigPermissions} ) ? 'responsible' : 'rw';

        # get login list of users
        my %UserLoginList = $UserObject->UserList(
            Type  => 'Short',
            Valid => 1,
        );

        # prepare acl data
        my %ACLUsers;

        # show all system users
        if ( $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
            %ACLUsers = %UserLoginList;
        }

        # show all subscribed users who have the appropriate permission in the queue group
        else {
            my $GID = $QueueObject->GetQueueGroupID(
                QueueID => $Ticket{QueueID}
            );

            my %MemberList = $GroupObject->PermissionGroupGet(
                GroupID => $GID,
                Type    => $PermissionGroupType,
            );

            for my $MemberKey ( keys( %MemberList ) ) {
                if ( $UserLoginList{ $MemberKey } ) {
                    $ACLUsers{ $MemberKey } = $UserLoginList{ $MemberKey };
                }
            }
        }

        # apply acl
        my $ACL = $TicketObject->TicketAcl(
            %Ticket,
            Action        => $Self->{Action},
            ReturnType    => 'Ticket',
            ReturnSubType => 'Responsible',
            Data          => \%ACLUsers,
            UserID        => $Self->{UserID},
        );
        if ( $ACL ) {
            %ACLUsers = $TicketObject->TicketAclData();
        }

        # prepare display data
        my %UserNameList = $UserObject->UserList(
            Type  => 'Long',
            Valid => 1,
        );
        my %ShownUsers = map( { $_ => $UserNameList{$_} } keys( %ACLUsers ) );

        # get responsible
        $Param{ResponsibleStrg} = $LayoutObject->BuildSelection(
            Data         => \%ShownUsers,
            SelectedID   => $Param{NewResponsibleID} || $InitialSelected{ResponsibleID},
            Name         => 'NewResponsibleID',
            Class        => 'Modernize ' . ( $Param{NewResponsibleInvalid} || '' ),
            PossibleNone => 1,
            Size         => 1,
        );

        $LayoutObject->Block(
            Name => 'Responsible',
            Data => \%Param,
        );
    }

    if ( $Config->{State} ) {

        my %State;
        my %StateList = $TicketObject->TicketStateList(
            Action   => $Self->{Action},
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID},
        );

        # set selected state
        if ( !$Param{NewStateID} ) {
            $State{SelectedValue} = $Config->{StateDefault}
                || $InitialSelected{State}
                || '';
        }
        else {
            $State{SelectedID} = $Param{NewStateID};
        }

        # build next states string
        $Param{StateStrg} = $LayoutObject->BuildSelection(
            Data         => \%StateList,
            Name         => 'NewStateID',
            Class        => 'Modernize',
            PossibleNone => $Config->{StateDefault} ? 0 : 1,
            %State,
        );
        $LayoutObject->Block(
            Name => 'State',
            Data => \%Param,
        );

        if ( IsArrayRefWithData( $Config->{StateType} ) ) {

            STATETYPE:
            for my $StateType ( @{ $Config->{StateType} } ) {

                next STATETYPE if !$StateType;
                next STATETYPE if $StateType !~ /pending/i;

                # get used calendar
                my $Calendar = $TicketObject->TicketCalendarGet(
                    %Ticket,
                );

                $Param{DateString} = $LayoutObject->BuildDateSelection(
                    %Param,
                    Format               => 'DateInputFormatLong',
                    YearPeriodPast       => 0,
                    YearPeriodFuture     => 5,
                    DiffTime             => $ConfigObject->Get('Ticket::Frontend::PendingDiffTime') || 0,
                    Class                => $Param{DateInvalid} || ' ',
                    Validate             => 1,
                    ValidateDateInFuture => 1,
                    Calendar             => $Calendar,
                );

                $LayoutObject->Block(
                    Name => 'StatePending',
                    Data => \%Param,
                );

                last STATETYPE;
            }
        }
    }

    # get priority
    if ( $Config->{Priority} ) {

        my %Priority;
        my %PriorityList = %{ $Self->_GetPriorities(%Param) };

        if ( !$Param{NewPriorityID} ) {
            if ( $Config->{PriorityDefault} ) {
                $Priority{SelectedValue} = $Config->{PriorityDefault};
            }
            else {
                $Priority{SelectedValue} = $Ticket{Priority};
            }
        }
        else {
            $Priority{SelectedID} = $Param{NewPriorityID};
        }
        $Priority{SelectedID} ||= $Param{PriorityID};
        $Param{PriorityStrg} = $LayoutObject->BuildSelection(
            %Priority,
            Data        => \%PriorityList,
            Name        => 'NewPriorityID',
            Class       => 'Modernize',
            Translation => 1,
        );
        $LayoutObject->Block(
            Name => 'Priority',
            Data => \%Param,
        );
    }
    # End Widget Ticket Actions

    # Widget Dynamic Fields
    if ( IsArrayRefWithData($Self->{DynamicField}) ) {
        $LayoutObject->Block(
            Name => 'WidgetDynamicFields',
        );
    }
    # ---
    # ITSMIncidentProblemManagement
    # ---
    my @IndividualDynamicFields;
    # ---

    # Dynamic fields
    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {

        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # skip fields that HTML could not be retrieved
        next DYNAMICFIELD if !IsHashRefWithData(
            $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} }
        );

        # get the html strings form $Param
        my $DynamicFieldHTML = $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} };

        # ---
        # ITSMIncidentProblemManagement
        # ---
        # remember dynamic fields that should be displayed individually
        if ( $DynamicFieldConfig->{Name} eq 'ITSMImpact' ) {
            push @IndividualDynamicFields, $DynamicFieldConfig;
            next DYNAMICFIELD;
        }
        # ---

        if ( !$DynamicFieldConfig->{Shown} ) {
            my $DynamicFieldName = $DynamicFieldConfig->{Name};

            $LayoutObject->AddJSOnDocumentComplete( Code => <<"END");
Core.Form.Validate.DisableValidation(\$('.Row_DynamicField_$DynamicFieldName'));
\$('.Row_DynamicField_$DynamicFieldName').addClass('Hidden');
END
        }

        $LayoutObject->Block(
            Name => 'DynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'DynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );
    }

    # ---
    # ITSMIncidentProblemManagement
    # ---
    # cycle trough dynamic fields that should be displayed individually
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @IndividualDynamicFields ) {

        # get the html strings form $Param
        my $DynamicFieldHTML = $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} };

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'DynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );
    }
# ---

    # End Widget Dynamic Fields

    # Widget Article
    if ( $Config->{Note} ) {

        $Param{WidgetStatus} = 'Collapsed';

        if (
            $Config->{NoteMandatory}
            || $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
            || $Param{IsUpload}
            || $Self->{ReplyToArticle}
        ) {
            $Param{WidgetStatus} = 'Expanded';
        }

        if (
            $Config->{NoteMandatory}
            || $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
        ) {
            $Param{SubjectRequired} = 'Validate_Required';
            $Param{BodyRequired}    = 'Validate_Required';
        }
        else {
            $Param{SubjectRequired} = 'Validate_DependingRequiredAND Validate_Depending_CreateArticle';
            $Param{BodyRequired}    = 'Validate_DependingRequiredAND Validate_Depending_CreateArticle';
        }

        $LayoutObject->Block(
            Name => 'WidgetArticle',
            Data => {%Param},
        );

        # get all user ids of agents, that can be shown in this dialog
        # based on queue rights
        my %ShownUsers;
        my %AllGroupsMembers = $UserObject->UserList(
            Type  => 'Long',
            Valid => 1,
        );
        my $GID = $QueueObject->GetQueueGroupID( QueueID => $Ticket{QueueID} );
        my %MemberList = $GroupObject->PermissionGroupGet(
            GroupID => $GID,
            Type    => 'note',
        );
        for my $UserID ( sort keys %MemberList ) {
            $ShownUsers{$UserID} = $AllGroupsMembers{$UserID};
        }

        # create email parser object
        my $EmailParserObject = Kernel::System::EmailParser->new(
            Mode  => 'Standalone',
            Debug => 0,
        );

        # check and retrieve involved and informed agents of ReplyTo Note
        my @ReplyToUsers;
        my %ReplyToUsersHash;
        my %ReplyToUserIDs;
        if ( $Self->{ReplyToArticle} ) {
            my @ReplyToParts = $EmailParserObject->SplitAddressLine(
                Line => $Self->{ReplyToArticleContent}->{To} || '',
            );

            REPLYTOPART:
            for my $SingleReplyToPart (@ReplyToParts) {
                my $ReplyToAddress = $EmailParserObject->GetEmailAddress(
                    Email => $SingleReplyToPart,
                );

                next REPLYTOPART if !$ReplyToAddress;
                push @ReplyToUsers, $ReplyToAddress;
            }

            $ReplyToUsersHash{$_}++ for @ReplyToUsers;

            # get user ids of available users
            for my $UserID ( sort keys %ShownUsers ) {
                my %UserData = $UserObject->GetUserData(
                    UserID => $UserID,
                );

                my $UserEmail = $UserData{UserEmail};
                if ( $ReplyToUsersHash{$UserEmail} ) {
                    $ReplyToUserIDs{$UserID} = 1;
                }
            }

            # add original note sender to list of user ids
            for my $UserID ( sort @{ $Self->{ReplyToSenderUserID} } ) {

                # if sender replies to himself, do not include sender in list
                if ( $UserID ne $Self->{UserID} ) {
                    $ReplyToUserIDs{$UserID} = 1;
                }
            }

            # remove user id of active user
            delete $ReplyToUserIDs{ $Self->{UserID} };
        }

        if ( $Config->{InformAgent} || $Config->{InvolvedAgent} ) {
            $LayoutObject->Block(
                Name => 'InformAdditionalAgents',
            );
        }

        # get param object
        my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

        # get all agents for "involved agents"
        if ( $Config->{InvolvedAgent} ) {

            my @UserIDs = $TicketObject->TicketInvolvedAgentsList(
                TicketID => $Self->{TicketID},
            );

            my @InvolvedAgents;
            my $Counter = 1;

            # get involved user list
            my @InvolvedUserID = $ParamObject->GetArray( Param => 'InvolvedUserID' );

            USER:
            for my $User ( reverse @UserIDs ) {

                my $Value = "$Counter: $User->{UserFullname}";
                if ( $User->{OutOfOfficeMessage} ) {
                    $Value .= " $User->{OutOfOfficeMessage}";
                }

                push @InvolvedAgents, {
                    Key   => $User->{UserID},
                    Value => $Value,
                };
                $Counter++;

                # add involved user as selected entries, if available in ReplyToAddresses list
                if ( $Self->{ReplyToArticle} && $ReplyToUserIDs{ $User->{UserID} } ) {
                    push @InvolvedUserID, $User->{UserID};
                    delete $ReplyToUserIDs{ $User->{UserID} };
                }
            }

            my $InvolvedAgentSize = $ConfigObject->Get('Ticket::Frontend::InvolvedAgentMaxSize') || 3;
            $Param{InvolvedAgentStrg} = $LayoutObject->BuildSelection(
                Data       => \@InvolvedAgents,
                SelectedID => \@InvolvedUserID,
                Name       => 'InvolvedUserID',
                Class      => 'Modernize',
                Multiple   => 1,
                Size       => $InvolvedAgentSize,
            );

            # block is called below "inform agents"
        }

        # agent list
        if ( $Config->{InformAgent} ) {

            # get inform user list
            my @InformUserID = $ParamObject->GetArray( Param => 'InformUserID' );

            if ( $Self->{ReplyToArticle} ) {

                # get email address of all users and compare to replyto-addresses
                for my $UserID ( sort keys %ShownUsers ) {
                    if ( $ReplyToUserIDs{$UserID} ) {
                        push @InformUserID, $UserID;
                        delete $ReplyToUserIDs{$UserID};
                    }
                }
            }

            my $InformAgentSize = $ConfigObject->Get('Ticket::Frontend::InformAgentMaxSize') || 3;
            $Param{OptionStrg}  = $LayoutObject->BuildSelection(
                Data       => \%ShownUsers,
                SelectedID => \@InformUserID,
                Name       => 'InformUserID',
                Class      => 'Modernize',
                Multiple   => 1,
                Size       => $InformAgentSize,
            );
            $LayoutObject->Block(
                Name => 'InformAgent',
                Data => \%Param,
            );
        }

        # get involved
        if ( $Config->{InvolvedAgent} ) {

            $LayoutObject->Block(
                Name => 'InvolvedAgent',
                Data => \%Param,
            );
        }

        # show list of agents, that receive this note (ReplyToNote)
        # at least sender of original note and all recepients of the original note
        # that couldn't be selected with involved/inform agents
        if ( $Self->{ReplyToArticle} ) {

            my $UsersHashSize = keys %ReplyToUserIDs;
            my $Counter       = 0;
            $Param{UserListWithoutSelection} = join( ',', keys %ReplyToUserIDs );

            if ( $UsersHashSize > 0 ) {
                $LayoutObject->Block(
                    Name => 'InformAgentsWithoutSelection',
                    Data => \%Param,
                );

                for my $UserID ( sort keys %ReplyToUserIDs ) {
                    $Counter++;

                    my %UserData = $UserObject->GetUserData(
                        UserID => $UserID,
                    );

                    $LayoutObject->Block(
                        Name => 'InformAgentsWithoutSelectionSingleUser',
                        Data => \%UserData,
                    );

                    # output a separator (InformAgentsWithoutSelectionSingleUserSeparator),
                    # if not last entry
                    if ( $Counter < $UsersHashSize ) {
                        $LayoutObject->Block(
                            Name => 'InformAgentsWithoutSelectionSingleUserSeparator',
                            Data => \%UserData,
                        );
                    }
                }
            }
        }

        # add rich text editor
        if ( $LayoutObject->{BrowserRichText} ) {

            # use height/width defined for this screen
            $Param{RichTextHeight} = $Config->{RichTextHeight} || 0;
            $Param{RichTextWidth}  = $Config->{RichTextWidth}  || 0;

            $LayoutObject->Block(
                Name => 'RichText',
                Data => \%Param,
            );
        }

        if (
            $Config->{NoteMandatory}
            || $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
        ) {
            $LayoutObject->Block(
                Name => 'SubjectLabelMandatory',
            );
            $LayoutObject->Block(
                Name => 'RichTextLabelMandatory',
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'SubjectLabel',
            );
            $LayoutObject->Block(
                Name => 'RichTextLabel',
            );
        }

        # build text template string
        my %StandardTemplates = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateList(
            Valid => 1,
            Type  => 'Note',
        );

        my $QueueStandardTemplates = $Self->_GetStandardTemplates(
            %Param,
            TicketID => $Self->{TicketID} || '',
        );

        if (
            IsHashRefWithData(
                $QueueStandardTemplates
                    || ( $Config->{Queue} && IsHashRefWithData( \%StandardTemplates ) )
            )
        ) {
            $Param{StandardTemplateStrg} = $LayoutObject->BuildSelection(
                Data         => $QueueStandardTemplates    || {},
                Name         => 'StandardTemplateID',
                SelectedID   => $Param{StandardTemplateID} || '',
                Class        => 'Modernize',
                PossibleNone => 1,
                Sort         => 'AlphanumericValue',
                Translation  => 1,
                Max          => 200,
            );
            $LayoutObject->Block(
                Name => 'StandardTemplate',
                Data => {%Param},
            );
        }

        # show attachments
        ATTACHMENT:
        for my $Attachment ( @{ $Param{Attachments} } ) {
            if (
                $Attachment->{ContentID}
                && $LayoutObject->{BrowserRichText}
                && ( $Attachment->{ContentType} =~ /image/i )
                && ( $Attachment->{Disposition} eq 'inline' )
            ) {
                next ATTACHMENT;
            }
            $LayoutObject->Block(
                Name => 'Attachment',
                Data => $Attachment,
            );
        }

        # build ArticleTypeID string
        my %ArticleType;

        # set article type of this note to the same type as the article for whom this is the reply
        if ( $Self->{ReplyToArticle} && !$Param{ArticleTypeID} ) {
            $ArticleType{SelectedID} = $Self->{ReplyToArticleContent}{ArticleTypeID};
        }
        elsif ( !$Param{ArticleTypeID} ) {
            $ArticleType{SelectedValue} = $Config->{ArticleTypeDefault};
        }
        else {
            $ArticleType{SelectedID} = $Param{ArticleTypeID};
        }

        # get possible notes
        if ( $Config->{ArticleTypes} ) {
            my %DefaultNoteTypes = %{ $Config->{ArticleTypes} };
            my %NoteTypes = $TicketObject->ArticleTypeList( Result => 'HASH' );
            for my $KeyNoteType ( sort keys %NoteTypes ) {
                if ( !$DefaultNoteTypes{ $NoteTypes{$KeyNoteType} } ) {
                    delete $NoteTypes{$KeyNoteType};
                }
            }

            $Param{ArticleTypeStrg} = $LayoutObject->BuildSelection(
                Data  => \%NoteTypes,
                Name  => 'ArticleTypeID',
                Class => 'Modernize',
                %ArticleType,
            );
            $LayoutObject->Block(
                Name => 'ArticleType',
                Data => \%Param,
            );
        }

        # show time accounting box
        if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
            if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
                $LayoutObject->Block(
                    Name => 'TimeUnitsLabelMandatory',
                    Data => \%Param,
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'TimeUnitsLabel',
                    Data => \%Param,
                );
            }
            $LayoutObject->Block(
                Name => 'TimeUnits',
                Data => \%Param,
            );
        }
    }

    # End Widget Article

    # get output back
    return $LayoutObject->Output( TemplateFile => $Self->{DTLAction}, Data => \%Param );
}

sub _GetNextStates {
    my ( $Self, %Param ) = @_;

    my %NextStates = $Kernel::OM->Get('Kernel::System::Ticket')->TicketStateList(
        TicketID => $Self->{TicketID},
        Action   => $Self->{Action},
        UserID   => $Self->{UserID},
        %Param,
    );

    return \%NextStates;
}

sub _GetOwners {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

    # get available permissions and set permission group type accordingly.
    my $ConfigPermissions   = $ConfigObject->Get('System::Permission');
    my $PermissionGroupType = ( grep { $_ eq 'owner' } @{$ConfigPermissions} ) ? 'owner' : 'rw';

    # get login list of users
    my %UserLoginList = $UserObject->UserList(
        Type  => 'Short',
        Valid => 1,
    );

    # prepare acl data
    my %ACLUsers;

    # show all system users
    if ( $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
        %ACLUsers = %UserLoginList;
    }

    # show all subscribed users who have the appropriate permission in the queue group
    elsif ( $Param{QueueID} ) {
        my $GID = $QueueObject->GetQueueGroupID(
            QueueID => $Param{NewQueueID} || $Param{QueueID}
        );

        my %MemberList = $GroupObject->PermissionGroupGet(
            GroupID => $GID,
            Type    => $PermissionGroupType,
        );

        for my $MemberKey ( keys( %MemberList ) ) {
            if ( $UserLoginList{ $MemberKey } ) {
                $ACLUsers{ $MemberKey } = $UserLoginList{ $MemberKey };
            }
        }
    }

    # apply acl
    my $ACL = $TicketObject->TicketAcl(
        %Param,
        Action        => $Self->{Action},
        ReturnType    => 'Ticket',
        ReturnSubType => 'NewOwner',
        Data          => \%ACLUsers,
        UserID        => $Self->{UserID},
    );
    if ( $ACL ) {
        %ACLUsers = $TicketObject->TicketAclData();
    }

    # prepare display data
    my %UserNameList = $UserObject->UserList(
        Type  => 'Long',
        Valid => 1,
    );
    my %ShownUsers = map( { $_ => $UserNameList{$_} } keys( %ACLUsers ) );

    return \%ShownUsers;
}

sub _GetOldOwners {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get previous ticket owner
    my %UserNameList;
    my %ACLUsers;
    my @OldUserInfo = $TicketObject->TicketOwnerList(
        TicketID => $Self->{TicketID}
    );
    if ( @OldUserInfo ) {
        my $Counter = 1;
        USER:
        for my $User ( reverse @OldUserInfo ) {
            next USER if $ACLUsers{ $User->{UserID} };

            $ACLUsers{ $User->{UserID} } = $User->{UserLogin};

            $UserNameList{ $User->{UserID} } = "$Counter: $User->{UserFullname}";
            $Counter++;
        }
    }

    # apply acl
    my $ACL = $TicketObject->TicketAcl(
        %Param,
        Action        => $Self->{Action},
        ReturnType    => 'Ticket',
        ReturnSubType => 'OldOwner',
        Data          => \%ACLUsers,
        UserID        => $Self->{UserID},
    );
    if ( $ACL ) {
        %ACLUsers = $TicketObject->TicketAclData();
    }

    # prepare display data
    my %ShownUsers = map( { $_ => $UserNameList{$_} } keys( %ACLUsers ) );

    return \%ShownUsers;
}

sub _GetResponsibles {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

    # get available permissions and set permission group type accordingly.
    my $ConfigPermissions   = $ConfigObject->Get('System::Permission');
    my $PermissionGroupType = ( grep { $_ eq 'responsible' } @{$ConfigPermissions} ) ? 'responsible' : 'rw';

    # get login list of users
    my %UserLoginList = $UserObject->UserList(
        Type  => 'Short',
        Valid => 1,
    );

    # prepare acl data
    my %ACLUsers;

    # show all system users
    if ( $ConfigObject->Get('Ticket::ChangeOwnerToEveryone') ) {
        %ACLUsers = %UserLoginList;
    }

    # show all subscribed users who have the appropriate permission in the queue group
    elsif ( $Param{QueueID} ) {
        my $GID = $QueueObject->GetQueueGroupID(
            QueueID => $Param{QueueID}
        );

        my %MemberList = $GroupObject->PermissionGroupGet(
            GroupID => $GID,
            Type    => $PermissionGroupType,
        );

        for my $MemberKey ( keys( %MemberList ) ) {
            if ( $UserLoginList{ $MemberKey } ) {
                $ACLUsers{ $MemberKey } = $UserLoginList{ $MemberKey };
            }
        }
    }

    # apply acl
    my $ACL = $TicketObject->TicketAcl(
        %Param,
        Action        => $Self->{Action},
        ReturnType    => 'Ticket',
        ReturnSubType => 'Responsible',
        Data          => \%ACLUsers,
        UserID        => $Self->{UserID},
    );
    if ( $ACL ) {
        %ACLUsers = $TicketObject->TicketAclData();
    }

    # prepare display data
    my %UserNameList = $UserObject->UserList(
        Type  => 'Long',
        Valid => 1,
    );
    my %ShownUsers = map( { $_ => $UserNameList{$_} } keys( %ACLUsers ) );

    return \%ShownUsers;
}

sub _GetServices {
    my ( $Self, %Param ) = @_;

    # get service
    my %Service;

    # get options for default services for unknown customers
    my $DefaultServiceUnknownCustomer = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Service::Default::UnknownCustomer');

    # check if no CustomerUserID is selected
    # if $DefaultServiceUnknownCustomer = 0 leave CustomerUserID empty, it will not get any services
    # if $DefaultServiceUnknownCustomer = 1 set CustomerUserID to get default services
    if (
        !$Param{CustomerUserID}
        && $DefaultServiceUnknownCustomer
    ) {
        $Param{CustomerUserID} = '<DEFAULT>';
    }

    # get service list
    if ( $Param{CustomerUserID} ) {
        %Service = $Kernel::OM->Get('Kernel::System::Ticket')->TicketServiceList(
            %Param,
            TicketID => $Self->{TicketID},
            Action   => $Self->{Action},
            UserID   => $Self->{UserID},
        );
    }
    return \%Service;
}

sub _GetSLAs {
    my ( $Self, %Param ) = @_;

    # if non set customers can get default services then they should also be able to get the SLAs
    #  for those services (this works during ticket creation).
    # if no CustomerUserID is set, TicketSLAList will complain during AJAX updates as UserID is not
    #  passed. See bug 11147.

    # get options for default services for unknown customers
    my $DefaultServiceUnknownCustomer
        = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Service::Default::UnknownCustomer');

    # check if no CustomerUserID is selected
    # if $DefaultServiceUnknownCustomer = 0 leave CustomerUserID empty, it will not get any services
    # if $DefaultServiceUnknownCustomer = 1 set CustomerUserID to get default services
    if ( !$Param{CustomerUserID} && $DefaultServiceUnknownCustomer ) {
        $Param{CustomerUserID} = '<DEFAULT>';
    }

    my %SLA;
    if ( $Param{ServiceID} ) {
        %SLA = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSLAList(
            %Param,
            TicketID => $Self->{TicketID},
            Action   => $Self->{Action},
            UserID   => $Self->{UserID},
        );
    }
    return \%SLA;
}

sub _GetPriorities {
    my ( $Self, %Param ) = @_;

    my %Priorities = $Kernel::OM->Get('Kernel::System::Ticket')->TicketPriorityList(
        %Param,
        Action   => $Self->{Action},
        UserID   => $Self->{UserID},
        TicketID => $Self->{TicketID},
    );

    # get config of frontend module
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Self->{Action}");

    if ( !$Config->{PriorityDefault} ) {
        $Priorities{''} = '-';
    }
    return \%Priorities;
}

sub _GetFieldsToUpdate {
    my ( $Self, %Param ) = @_;

    my @UpdatableFields;

    # set the fields that can be updateable via AJAXUpdate
    if ( !$Param{OnlyDynamicFields} ) {
        @UpdatableFields = qw(
            TypeID ServiceID SLAID NewOwnerID NewResponsibleID NewStateID
            NewPriorityID
        );
    }

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsACLReducible = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsACLReducible',
        );
        next DYNAMICFIELD if !$IsACLReducible;

        push @UpdatableFields, 'DynamicField_' . $DynamicFieldConfig->{Name};
    }

    return \@UpdatableFields;
}

sub _GetQuotedReplyBody {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    if ( $LayoutObject->{BrowserRichText} ) {

        # rewrap body if exists
        if ( $Param{Body} ) {
            $Param{Body} =~ s/\t/ /g;
            my $Quote = $LayoutObject->Ascii2Html(
                Text => $ConfigObject->Get('Ticket::Frontend::Quote') || '',
                HTMLResultMode => 1,
            );
            if ($Quote) {

                # quote text
                $Param{Body} = "<blockquote type=\"cite\">$Param{Body}</blockquote>\n";

                # cleanup not compat. tags
                $Param{Body} = $LayoutObject->RichTextDocumentCleanup(
                    String => $Param{Body},
                );

                my $ResponseFormat
                    = $LayoutObject->{LanguageObject}->FormatTimeString( $Param{Created}, 'DateFormat', 'NoSeconds' );
                $ResponseFormat .= ' - ' . $Param{From} . ' ';
                $ResponseFormat
                    .= $LayoutObject->{LanguageObject}->Translate('wrote') . ':';

                $Param{Body} = $ResponseFormat . $Param{Body};

            }
            else {
                $Param{Body} = "<br/>" . $Param{Body};

                if ( $Param{Created} ) {
                    $Param{Body} = $LayoutObject->{LanguageObject}->Translate('Date') .
                        ": $Param{Created}<br/>" . $Param{Body};
                }

                for (qw(Subject ReplyTo Reply-To Cc To From)) {
                    if ( $Param{$_} ) {
                        $Param{Body} = $LayoutObject->{LanguageObject}->Translate($_) .
                            ": $Param{$_}<br/>" . $Param{Body};
                    }
                }

                my $From = $LayoutObject->Ascii2RichText(
                    String => $Param{From},
                );

                my $MessageFrom = $LayoutObject->{LanguageObject}->Translate('Message from');
                my $EndMessage  = $LayoutObject->{LanguageObject}->Translate('End message');

                $Param{Body} = "<br/>---- $MessageFrom $From ---<br/><br/>" . $Param{Body};
                $Param{Body} .= "<br/>---- $EndMessage ---<br/>";
            }
        }
    }
    else {

        # prepare body, subject, ReplyTo ...
        # rewrap body if exists
        if ( $Param{Body} ) {
            $Param{Body} =~ s/\t/ /g;
            my $Quote = $ConfigObject->Get('Ticket::Frontend::Quote');
            if ($Quote) {
                $Param{Body} =~ s/\n/\n$Quote /g;
                $Param{Body} = "\n$Quote " . $Param{Body};

                my $ResponseFormat
                    = $LayoutObject->{LanguageObject}->FormatTimeString( $Param{Created}, 'DateFormat', 'NoSeconds' );
                $ResponseFormat .= ' - ' . $Param{From} . ' ';
                $ResponseFormat
                    .= $LayoutObject->{LanguageObject}->Translate('wrote') . ":\n";

                $Param{Body} = $ResponseFormat . $Param{Body};
            }
            else {
                $Param{Body} = "\n" . $Param{Body};
                if ( $Param{Created} ) {
                    $Param{Body} = $LayoutObject->{LanguageObject}->Translate('Date') .
                        ": $Param{Created}\n" . $Param{Body};
                }

                for (qw(Subject ReplyTo Reply-To Cc To From)) {
                    if ( $Param{$_} ) {
                        $Param{Body} = $LayoutObject->{LanguageObject}->Translate($_) .
                            ": $Param{$_}\n" . $Param{Body};
                    }
                }

                my $MessageFrom = $LayoutObject->{LanguageObject}->Translate('Message from');
                my $EndMessage  = $LayoutObject->{LanguageObject}->Translate('End message');

                $Param{Body} = "\n---- $MessageFrom $Param{From} ---\n\n" . $Param{Body};
                $Param{Body} .= "\n---- $EndMessage ---\n";
            }
        }
    }

    return $Param{Body};
}

sub _GetStandardTemplates {
    my ( $Self, %Param ) = @_;

    # get create templates
    my %Templates;

    # check needed
    return \%Templates if !$Param{QueueID} && !$Param{TicketID};

    my $QueueID = $Param{QueueID} || '';
    if ( !$Param{QueueID} && $Param{TicketID} ) {

        # get QueueID from the ticket
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
            UserID        => $Self->{UserID},
        );
        $QueueID = $Ticket{QueueID} || '';
    }

    # fetch all std. templates
    my %StandardTemplates = $Kernel::OM->Get('Kernel::System::Queue')->QueueStandardTemplateMemberList(
        QueueID       => $QueueID,
        TemplateTypes => 1,
    );

    # return empty hash if there are no templates for this screen
    return \%Templates if !IsHashRefWithData( $StandardTemplates{Note} );

    # return just the templates for this screen
    return $StandardTemplates{Note};
}

sub _GetTypes {
    my ( $Self, %Param ) = @_;

    # get type
    my %Type;
    if ( $Param{QueueID} || $Param{TicketID} ) {
        %Type = $Kernel::OM->Get('Kernel::System::Ticket')->TicketTypeList(
            %Param,
            TicketID => $Self->{TicketID},
            Action   => $Self->{Action},
            UserID   => $Self->{UserID},
        );
    }
    return \%Type;
}

sub _GetShownDynamicFields {
    my ( $Self, %Param ) = @_;

    # use only dynamic fields which passed the acl
    my %TicketAclFormData = $Kernel::OM->Get('Kernel::System::Ticket')->TicketAclFormData();

    # cycle through dynamic fields to get shown or hidden fields
    for my $DynamicField ( @{ $Self->{DynamicField} } ) {

        # if field was not configured initially set it as not visible
        if ( $Self->{NotShownDynamicFields}->{ $DynamicField->{Name} } ) {
            $DynamicField->{Shown} = 0;
        }
        else {

            # hide DynamicFields only if we have ACL's
            if (
                IsHashRefWithData( \%TicketAclFormData )
                && defined $TicketAclFormData{ $DynamicField->{Name} }
            ) {
                if ( $TicketAclFormData{ $DynamicField->{Name} } >= 1 ) {
                    $DynamicField->{Shown} = 1;
                }
                else {
                    $DynamicField->{Shown} = 0;
                }
            }

            # else show them by default
            else {
                $DynamicField->{Shown} = 1;
            }
        }
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
