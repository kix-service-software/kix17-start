# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketPhoneCommon;

use strict;
use warnings;

use Mail::Address;
use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

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

    my $OutputNotify = '';

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Got no TicketID!'),
            Comment => Translatable('System Error!'),
        );
    }

    # get needed objects
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

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
        return $LayoutObject->NoPermission( WithHeader => 'yes' );
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

    # show lock state
    $OutputNotify .= $LayoutObject->Notify(
        Data => "$Ticket{TicketNumber}: "
            . $LayoutObject->{LanguageObject}->Translate("Ticket locked."),
    );

    # get lock state && write (lock) permissions
    if ( $Config->{RequiredLock} ) {
        if ( !$TicketObject->TicketLockGet( TicketID => $Self->{TicketID} ) ) {
            $TicketObject->TicketLockSet(
                TicketID => $Self->{TicketID},
                Lock     => 'lock',
                UserID   => $Self->{UserID},
            );
            if (
                $TicketObject->TicketOwnerSet(
                    TicketID  => $Self->{TicketID},
                    UserID    => $Self->{UserID},
                    NewUserID => $Self->{UserID},
                )
            ) {

                # show lock state
                $OutputNotify = $LayoutObject->Notify(
                    Data => "$Ticket{TicketNumber}: "
                        . $LayoutObject->{LanguageObject}->Translate("Ticket locked."),
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
                    Value     => $Ticket{Number},
                    Type      => 'Small',
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
            else {
                $LayoutObject->Block(
                    Name => 'TicketBack',
                    Data => {
                        %Param,
                        TicketID => $Self->{TicketID},
                    },
                );
            }
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'TicketBack',
            Data => { %Param, %Ticket, },
        );
    }

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my %GetParam;
    for my $Key (
        qw(Body Subject TimeUnits NextStateID Year Month Day Hour Minute StandardTemplateID )
    ) {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
    }

    # set default state, if no next state id given
    if (
        !$GetParam{NextStateID}
        && $Config->{State}
    ) {
        $GetParam{State} = $Config->{State};
    }

    # MultipleCustomer From-field
    my @MultipleCustomer;
    if ( $Config->{CallContact} ) {

        # build customer search autocomplete field
        $LayoutObject->Block(
            Name => 'CustomerSearchAutoComplete',
        );

        my $CustomersNumber = $ParamObject->GetParam( Param => 'CustomerTicketCounterFromCustomer' ) || 0;

        # hash for check duplicated entries
        my %AddressesList;

        # get check item object
        my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

        if ( $CustomersNumber) {

            # check if attachment handling
            my $IsUpload = 0;
            if ( $Self->{Subaction} eq 'Store' ) {
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
                    $IsUpload = 1;
                }
                if ( $ParamObject->GetParam( Param => 'AttachmentUpload' ) ) {
                    $IsUpload = 1;
                }
            }

            my $CustomerCounter = 1;
            my @Contacts;
            for my $Count ( 1 ... $CustomersNumber ) {
                my $CustomerElement = $ParamObject->GetParam( Param => 'CustomerTicketText_' . $Count );
                my $CustomerKey = $ParamObject->GetParam( Param => 'CustomerKey_' . $Count )
                    || '';

                if ($CustomerElement) {

                    my $CountAux         = $CustomerCounter++;
                    my $CustomerError    = '';
                    my $CustomerErrorMsg = 'CustomerGenericServerErrorMsg';
                    my $CustomerDisabled = '';

                    if ( !$IsUpload ) {
                        push( @Contacts, $CustomerElement );

                        # check email address
                        for my $Email ( Mail::Address->parse($CustomerElement) ) {
                            if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                                $CustomerErrorMsg = $CheckItemObject->CheckErrorType()
                                    . 'ServerErrorMsg';
                                $CustomerError = 'ServerError';
                            }
                        }

                        # check for duplicated entries
                        if ( defined $AddressesList{$CustomerElement} && $CustomerError eq '' ) {
                            $CustomerErrorMsg = 'IsDuplicatedServerErrorMsg';
                            $CustomerError    = 'ServerError';
                        }

                        if ( $CustomerError ne '' ) {
                            $CustomerDisabled = 'disabled="disabled"';
                            $CountAux         = $Count . 'Error';
                        }
                    }

                    push @MultipleCustomer, {
                        Count            => $CountAux,
                        CustomerElement  => $CustomerElement,
                        CustomerKey      => $CustomerKey,
                        CustomerError    => $CustomerError,
                        CustomerErrorMsg => $CustomerErrorMsg,
                        CustomerDisabled => $CustomerDisabled,
                    };
                    $AddressesList{$CustomerElement} = 1;
                }
            }

            # remember call contacts
            $GetParam{Contacts} = join(', ', sort @Contacts);
        }
    }

    # get dynamic field values form http request
    my %DynamicFieldValues;

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # get backend object
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # extract the dynamic field value form the web request
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} } = $BackendObject->EditFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ParamObject        => $ParamObject,
            LayoutObject       => $LayoutObject,
        );
    }

    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    DYNAMICFIELDNAME:
    for my $DynamicFieldName ( sort keys %DynamicFieldValues ) {
        next DYNAMICFIELDNAME if !$DynamicFieldName;
        next DYNAMICFIELDNAME if !$DynamicFieldValues{$DynamicFieldName};

        $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicFieldName } = $DynamicFieldValues{$DynamicFieldName};
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

    # get needed objects
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $UploadCacheObject  = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    # run acl to prepare TicketAclFormData
    my $ShownDFACL = $Kernel::OM->Get('Kernel::System::Ticket')->TicketAcl(
        %GetParam,
        Action        => $Self->{Action},
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Ticket',
        ReturnSubType => '-',
        Data          => {},
        UserID        => $Self->{UserID},
    );

    # update 'Shown' for $Self->{DynamicField}
    $Self->_GetShownDynamicFields();

    if ( !$Self->{Subaction} ) {

        # get ticket info
        my %CustomerData;
        if ( $ConfigObject->Get('Ticket::Frontend::CustomerInfoCompose') ) {
            if ( $Ticket{CustomerUserID} ) {
                %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                    User => $Ticket{CustomerUserID},
                );
            }
            elsif ( $Ticket{CustomerID} ) {
                %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                    CustomerID => $Ticket{CustomerID},
                );
            }
        }

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle through the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $BackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {

                # get PossibleValues
                my $PossibleValues = $BackendObject->PossibleValuesGet(
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
                        Action        => $Self->{Action},
                        TicketID      => $Self->{TicketID},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => \%AclData,
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();

                        %{$DynamicFieldConfig->{ShownPossibleValues}} = map( { $_ => $PossibleValues->{$_} } keys %Filter );
                    }
                }
            }

            # to store dynamic field value from database (or undefined)
            my $Value;

            # only get values for Ticket fields (all screens based on AgentTickeActionCommon
            # generates a new article, then article fields will be always empty at the beginign)
            if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {

                # get value stored on the database from Ticket
                $Value = $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $BackendObject->EditFieldRender(
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

        # get and format default subject and body
        my $Subject = $LayoutObject->Output(
            Template => $Config->{Subject} || '',
        );
        my $Body = $LayoutObject->Output(
            Template => $Config->{Body} || '',
        );
        if ( $LayoutObject->{BrowserRichText} ) {
            $Body = $LayoutObject->Ascii2RichText(
                String => $Body,
            );
        }

        # print form ...
        my $Output = $LayoutObject->Header(
            Type      => 'Small',
            BodyClass => 'Popup',
        );

        if ( $TicketObject->TicketLockGet( TicketID => $Self->{TicketID} ) ) {
            $Output .= $OutputNotify;
        }

        # set ticket customer as default call contact
        my %PrepopulatedCallContact;
        if ( %CustomerData && $Config->{CallContact} ) {
            %PrepopulatedCallContact = (
                Customer  => $CustomerData{UserID},
                Email     => $CustomerData{UserEmail} || '',
                Firstname => $CustomerData{UserFirstname},
                Lastname  => $CustomerData{UserLastname},
            );
        }

        $Output .= $Self->_MaskPhone(
            TicketID     => $Self->{TicketID},
            QueueID      => $Self->{QueueID} || $Ticket{QueueID},
            %Ticket,
            TicketTypeID => $Ticket{TypeID},
            NextStates   => $Self->_GetNextStates(
                %GetParam,
            ),
            StandardTemplates => $Self->_GetStandardTemplates(%Ticket),
            CustomerData      => \%CustomerData,
            Subject           => $Subject,
            Body              => $Body,
            DynamicFieldHTML  => \%DynamicFieldHTML,

            MultipleCustomer        => \@MultipleCustomer,
            PrepopulatedCallContact => \%PrepopulatedCallContact,
        );
        $Output .= $LayoutObject->Footer(
            Type => 'Small',
        );
        return $Output;
    }

    # save new phone article to existing ticket
    elsif ( $Self->{Subaction} eq 'Store' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my %Error;

        # rewrap body if no rich text is used
        if ( $GetParam{Body} && !$LayoutObject->{BrowserRichText} ) {
            $GetParam{Body} = $LayoutObject->WrapPlainText(
                MaxCharacters => $ConfigObject->Get('Ticket::Frontend::TextAreaNote'),
                PlainText     => $GetParam{Body},
            );
        }

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

        # check subject
        for my $Key (qw(Body Subject)) {
            if ( !$IsUpload && $GetParam{$Key} eq '' ) {
                $Error{ $Key . 'Invalid' } = 'ServerError';
            }
        }
        if (
            $ConfigObject->Get('Ticket::Frontend::AccountTime')
            && $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
        ) {
            if ( !$IsUpload && $GetParam{TimeUnits} eq '' ) {
                $Error{'TimeUnitsInvalid'} = 'ServerError';
            }
        }

        # get all attachments meta data
        my @Attachments = $UploadCacheObject->FormIDGetAllFilesMeta(
            FormID => $Self->{FormID},
        );

        # get needed objects
        my $StateObject = $Kernel::OM->Get('Kernel::System::State');
        my $TimeObject  = $Kernel::OM->Get('Kernel::System::Time');

        # check if date is valid
        my %StateData;
        $GetParam{NextStateID} ||= '';
        if ( $GetParam{NextStateID} ) {
            %StateData = $StateObject->StateGet( ID => $GetParam{NextStateID} );

            if ( $StateData{TypeName} =~ /^pending/i ) {
                if ( !$TimeObject->Date2SystemTime( %GetParam, Second => 0 ) ) {
                    if ( $IsUpload == 0 ) {
                        $Error{'DateInvalid'} = ' ServerError';
                    }
                }
                if (
                    $TimeObject->Date2SystemTime( %GetParam, Second => 0 )
                    < $TimeObject->SystemTime()
                ) {
                    if ( $IsUpload == 0 ) {
                        $Error{'DateInvalid'} = ' ServerError';
                    }
                }
            }
        }

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle through the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $BackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ($IsACLReducible) {

                # get PossibleValues
                my $PossibleValues = $BackendObject->PossibleValuesGet(
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
                        %{$DynamicFieldConfig->{ShownPossibleValues}} = map( { $_ => $PossibleValues->{$_} } keys %Filter );
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

                $ValidationResult = $BackendObject->EditFieldValueValidate(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
                    ParamObject          => $ParamObject,
                    Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                );

                if ( !IsHashRefWithData($ValidationResult) ) {
                    return $LayoutObject->ErrorScreen(
                        Message =>
                            $LayoutObject->{LanguageObject}
                            ->Translate( 'Could not perform validation on field %s!', $DynamicFieldConfig->{Label} ),
                        Comment => Translatable('Please contact the administrator.'),
                    );
                }

                # propagate validation error to the Error variable to be detected by the frontend
                if ( $ValidationResult->{ServerError} ) {
                    $Error{ $DynamicFieldConfig->{Name} } = ' ServerError';
                }
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $BackendObject->EditFieldRender(
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

        # show error if no call contact is given
        if ( $Config->{CallContact} && !$GetParam{Contacts} && !$IsUpload ) {
            $Error{'FromInvalid'} = ' ServerError';
        }

        if (%Error) {

            # check permissions if it's a existing ticket
            if (
                !$TicketObject->TicketPermission(
                    Type     => 'ro',
                    TicketID => $Self->{TicketID},
                    UserID   => $Self->{UserID},
                )
            ) {

                # error screen, don't show ticket
                return $LayoutObject->NoPermission( WithHeader => 'yes' );
            }

            # get ticket info
            my $Tn = $Ticket{TicketNumber};
            my %CustomerData;
            if ( $ConfigObject->Get('Ticket::Frontend::CustomerInfoCompose') ) {
                if ( $Ticket{CustomerUserID} ) {
                    %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                        User => $Ticket{CustomerUserID},
                    );
                }
                elsif ( $Ticket{CustomerID} ) {
                    %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                        CustomerID => $Ticket{CustomerID},
                    );
                }
            }

            # header
            my $Output = $LayoutObject->Header(
                Type      => 'Small',
                BodyClass => 'Popup',
            );

            if ( $TicketObject->TicketLockGet( TicketID => $Self->{TicketID} ) ) {
                $Output .= $OutputNotify;
            }

            $Output .= $Self->_MaskPhone(
                TicketID     => $Self->{TicketID},
                TicketNumber => $Tn,
                QueueID      => $Ticket{QueueID},
                SLAID        => $Ticket{SLAID},
                Title        => $Ticket{Title},
                NextStates   => $Self->_GetNextStates(
                    %GetParam,
                ),
                StandardTemplates => $Self->_GetStandardTemplates(%Ticket),
                CustomerData      => \%CustomerData,
                Attachments       => \@Attachments,
                %GetParam,
                DynamicFieldHTML => \%DynamicFieldHTML,
                Errors           => \%Error,

                MultipleCustomer => \@MultipleCustomer,

                TicketTypeID => $Ticket{TypeID},
                QueueID      => $Ticket{QueueID},
                Title        => $Ticket{Title},
            );
            $Output .= $LayoutObject->Footer(
                Type => 'Small',
            );
            return $Output;
        }
        else {

            # get pre loaded attachment
            my @AttachmentData = $UploadCacheObject->FormIDGetAllFilesData(
                FormID => $Self->{FormID},
            );

            # get submit attachment
            my %UploadStuff = $ParamObject->GetUploadAll(
                Param => 'FileUpload',
            );
            if (%UploadStuff) {
                push @AttachmentData, \%UploadStuff;
            }

            my $MimeType = 'text/plain';
            if ( $LayoutObject->{BrowserRichText} ) {
                $MimeType = 'text/html';

                # remove unused inline images
                my @NewAttachmentData;
                ATTACHMENT:
                for my $Attachment (@AttachmentData) {
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
                @AttachmentData = @NewAttachmentData;

                # verify html document
                $GetParam{Body} = $LayoutObject->RichTextDocumentComplete(
                    String => $GetParam{Body},
                );
            }

            my $From;
            my $To = '';

            if ( lc $Config->{SenderType} eq 'customer' ) {

                # get customer email address
                if ( $Config->{CallContact} && $GetParam{Contacts} ) {
                    $From = $GetParam{Contacts};
                } elsif ( $Ticket{CustomerUserID} ) {
                    my %CustomerUserData = $CustomerUserObject->CustomerUserDataGet(
                        User => $Ticket{CustomerUserID}
                    );

                    # use data from customer user (if customer user is in database)
                    if ( IsHashRefWithData( \%CustomerUserData ) ) {
                        $From = '"'
                            . $CustomerUserData{UserFirstname} . ' '
                            . $CustomerUserData{UserLastname} . '"'
                            . ' <' . $CustomerUserData{UserEmail} . '>';
                    }
                }
                else {
                    # Use customer data as From, if possible
                    my %LastCustomerArticle = $TicketObject->ArticleLastCustomerArticle(
                        TicketID      => $Self->{TicketID},
                        DynamicFields => 0,
                    );
                    $From = $LastCustomerArticle{From};
                }
            } else {
                if ( $Config->{CallContact} && $GetParam{Contacts} ) {
                    $To = $GetParam{Contacts};
                }
            }

            # If we don't have a customer article, or if SenderType is "agent", use the agent as From.
            if ( !$From ) {
                my $TemplateGenerator = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
                $From = $TemplateGenerator->Sender(
                    QueueID => $Ticket{QueueID},
                    UserID  => $Self->{UserID},
                );
            }

            my $ArticleID = $TicketObject->ArticleCreate(
                TicketID       => $Self->{TicketID},
                ArticleType    => $Config->{ArticleType},
                SenderType     => $Config->{SenderType},
                From           => $From,
                To             => $To,
                Subject        => $GetParam{Subject},
                Body           => $GetParam{Body},
                MimeType       => $MimeType,
                Charset        => $LayoutObject->{UserCharset},
                UserID         => $Self->{UserID},
                HistoryType    => $Config->{HistoryType},
                HistoryComment => $Config->{HistoryComment} || '%%',
                UnlockOnAway   => 1,
            );

            # show error of creating article
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

            # write attachments
            for my $Attachment (@AttachmentData) {
                $TicketObject->ArticleWriteAttachment(
                    %{$Attachment},
                    ArticleID => $ArticleID,
                    UserID    => $Self->{UserID},
                );
            }

            # remove pre submitted attachments
            $UploadCacheObject->FormIDRemove( FormID => $Self->{FormID} );

            # set dynamic fields
            # cycle through the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                # set the object ID (TicketID or ArticleID) depending on the field configuration
                my $ObjectID = $DynamicFieldConfig->{ObjectType} eq 'Article'
                    ? $ArticleID
                    : $Self->{TicketID};

                # set the value
                my $Success = $BackendObject->ValueSet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $ObjectID,
                    Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                    UserID             => $Self->{UserID},
                );
            }

            # set state
            if ( $StateData{ID} ) {
                $TicketObject->TicketStateSet(
                    TicketID  => $Self->{TicketID},
                    ArticleID => $ArticleID,
                    StateID   => $StateData{ID},
                    UserID    => $Self->{UserID},
                );
            }

            # should i set an unlock? yes if the ticket is closed
            if ( $StateData{TypeName} =~ /^close/i ) {

                # set lock
                $TicketObject->TicketLockSet(
                    TicketID => $Self->{TicketID},
                    Lock     => 'unlock',
                    UserID   => $Self->{UserID},
                );
            }

            # set pending time if next state is a pending state
            elsif ( $StateData{TypeName} =~ /^pending/i ) {

                # set pending time
                $TicketObject->TicketPendingTimeSet(
                    UserID   => $Self->{UserID},
                    TicketID => $Self->{TicketID},
                    %GetParam,
                );
            }

            # redirect to last screen (e. g. zoom view) and to queue view if
            # the ticket is closed (move to the next task).
            my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences( UserID => $Self->{UserID} );
            $Self->{RedirectDestination} = $Preferences{RedirectAfterTicketClose} || '0';

            if (
                !$Self->{RedirectDestination}
                && $StateData{TypeName}
                && $StateData{TypeName} =~ /^close/i
            ) {
                return $LayoutObject->PopupClose(
                    URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID};ArticleID=$ArticleID",
                );
            }

            return $LayoutObject->PopupClose(
                URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID};ArticleID=$ArticleID",
            );
        }
    }
    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {
        my $ElementChanged = $ParamObject->GetParam( Param => 'ElementChanged' ) || '';

        my $NextStates = $Self->_GetNextStates(
            %GetParam,
        );

        # update Dynamic Fields Possible Values via AJAX
        my @DynamicFieldAJAX;
        my %DynamicFieldHTML;

        # cycle through the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $BackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );

            if ( !$IsACLReducible ) {
                $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $BackendObject->EditFieldRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Mandatory          => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                    LayoutObject       => $LayoutObject,
                    ParamObject        => $ParamObject,
                    AJAXUpdate         => 0,
                    UpdatableFields    => $Self->_GetFieldsToUpdate(),
                );

                   next DYNAMICFIELD;
            }

            my $PossibleValues = $BackendObject->PossibleValuesGet(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            # convert possible values key => value to key => key for ACLs using a Hash slice
            my %AclData = %{$PossibleValues};
            @AclData{ keys %AclData } = keys %AclData;

            # set possible values filter from ACLs
            $ACL = $TicketObject->TicketAcl(
                %GetParam,
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
                %{$PossibleValues} = map { $_ => $PossibleValues->{$_} } keys %Filter;
            }

            my $DataValues = $BackendObject->BuildSelectionDataGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                PossibleValues     => $PossibleValues,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            ) || $PossibleValues;

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

            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $BackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
                Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
            );
        }

        # use only dynamic fields which passed the acl
        my %Output;
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {

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
                    TicketID   => $Self->{TicketID},
                    TemplateID => $GetParam{StandardTemplateID},
                    UserID     => $Self->{UserID},
                );

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

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'NextStateID',
                    Data         => $NextStates,
                    SelectedID   => $GetParam{NextStateID},
                    Translation  => 1,
                    PossibleNone => 1,
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
        $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
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

    return $LayoutObject->ErrorScreen(
        Message => Translatable('No Subaction!'),
        Comment => Translatable('Please contact the administrator.'),
    );
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
    return \%Templates if !IsHashRefWithData( $StandardTemplates{PhoneCall} );

    # return just the templates for this screen
    return $StandardTemplates{PhoneCall};
}

sub _MaskPhone {
    my ( $Self, %Param ) = @_;

    $Param{FormID} = $Self->{FormID};

    my $DynamicFieldNames = $Self->_GetFieldsToUpdate(
        OnlyDynamicFields => 1
    );

    # create a string with the quoted dynamic field names separated by commas
    if ( !$Param{DynamicFieldNamesStrg} ) {
        $Param{DynamicFieldNamesStrg} = '';
    }

    if ( IsArrayRefWithData($DynamicFieldNames) ) {
        for my $Field ( @{$DynamicFieldNames} ) {
            $Param{DynamicFieldNamesStrg} .= ", '" . $Field . "'";
        }
    }

    # get needed objects
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config of frontend module
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    if ( $Config->{CallContact} ) {
        $LayoutObject->Block(
            Name => 'CallContact',
            Data => \%Param,
        );

        # prepopulate call contact
        my $ShowErrors = 1;
        if ( IsHashRefWithData($Param{PrepopulatedCallContact}) ) {
            $ShowErrors = 0;
            $LayoutObject->Block(
                Name => 'PrepopulatedCallContact',
                Data => $Param{PrepopulatedCallContact},
            );
        }

        # show call contacts
        my $CustomerCounter = 0;
        if ( $Param{MultipleCustomer} ) {
            for my $Item ( @{ $Param{MultipleCustomer} } ) {
                if ( !$ShowErrors ) {

                    # set empty values for errors
                    $Item->{CustomerError}    = '';
                    $Item->{CustomerDisabled} = '';
                    $Item->{CustomerErrorMsg} = 'CustomerGenericServerErrorMsg';
                }
                $LayoutObject->Block(
                    Name => 'MultipleCustomer',
                    Data => $Item,
                );
                $LayoutObject->Block(
                    Name => $Item->{CustomerErrorMsg},
                    Data => $Item,
                );
                if ( $Item->{CustomerError} ) {
                    $LayoutObject->Block(
                        Name => 'CustomerErrorExplantion',
                    );
                }
                $CustomerCounter++;
            }
        }

        if ( !$CustomerCounter ) {
            $Param{CustomerHiddenContainer} = 'Hidden';
        }

        # set customer counter
        $LayoutObject->Block(
            Name => 'MultipleCustomerCounter',
            Data => {
                CustomerCounter => $CustomerCounter++,
            },
        );

        if ( $Param{Errors}->{FromInvalid} ) {
            $LayoutObject->Block( Name => 'FromServerErrorMsg' );
        }
        if ( !$ShowErrors ) {
            $Param{Errors}->{FromInvalid} = '';
        }
    }

    # build next states string
    my %Selected;
    if ( $Param{NextStateID} ) {
        $Selected{SelectedID} = $Param{NextStateID};
    }
    elsif ( $Config->{State} ) {
        $Selected{SelectedValue} = $Config->{State};
    }
    $Param{NextStatesStrg} = $LayoutObject->BuildSelection(
        Data         => $Param{NextStates},
        Name         => 'NextStateID',
        Class        => 'Modernize',
        Translation  => 1,
        PossibleNone => 1,
        %Selected,
    );

    # load KIXSidebar
    $Param{KIXSidebarContent} = $LayoutObject->AgentKIXSidebar(%Param);

    # check if exists create templates regardless the queue
    my %StandardTemplates = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateList(
        Valid => 1,
        Type  => 'PhoneCall',
    );

    # build text template string
    if ( IsHashRefWithData( \%StandardTemplates ) ) {
        $Param{StandardTemplateStrg} = $LayoutObject->BuildSelection(
            Data       => $Param{StandardTemplates}  || {},
            Name       => 'StandardTemplateID',
            SelectedID => $Param{StandardTemplateID} || '',
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 0,
            Max          => 200,
            Class        => 'Modernize',
        );
        $LayoutObject->Block(
            Name => 'StandardTemplate',
            Data => {%Param},
        );
    }

    # get used calendar
    my $Calendar = $Kernel::OM->Get('Kernel::System::Ticket')->TicketCalendarGet(
        QueueID => $Param{QueueID},
        SLAID   => $Param{SLAID},
    );

    # pending data string
    $Param{PendingDateString} = $LayoutObject->BuildDateSelection(
        %Param,
        Format               => 'DateInputFormatLong',
        YearPeriodPast       => 0,
        YearPeriodFuture     => 5,
        DiffTime             => $ConfigObject->Get('Ticket::Frontend::PendingDiffTime') || 0,
        Class                => $Param{Errors}->{DateInvalid},
        Validate             => 1,
        ValidateDateInFuture => 1,
        Calendar             => $Calendar,
    );

    # do html quoting
    for my $Parameter (qw(From To Cc)) {
        $Param{$Parameter} = $LayoutObject->Ascii2Html( Text => $Param{$Parameter} ) || '';
    }

    # prepare errors!
    if ( $Param{Errors} ) {
        for my $KeyError ( sort keys %{ $Param{Errors} } ) {
            $Param{$KeyError} = '* ' . $LayoutObject->Ascii2Html( Text => $Param{Errors}->{$KeyError} );
        }
    }

    # Dynamic fields
    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # skip fields that HTML could not be retrieved
        next DYNAMICFIELD if !IsHashRefWithData(
            $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} }
        );

        # get the html strings form $Param
        my $DynamicFieldHTML = $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} };

        if ( !$DynamicFieldConfig->{Shown} ) {
            my $DynamicFieldName = $DynamicFieldConfig->{Name};

            $LayoutObject->AddJSOnDocumentComplete( Code => <<"END");
Core.Form.Validate.DisableValidation(\$('.Row_DynamicField_$DynamicFieldName'));
\$('.Row_DynamicField_$DynamicFieldName').addClass('Hidden hiddenFormField').find('select').prop('disabled', true);
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

    # show time accounting box
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabelMandatory',
                Data => \%Param,
            );
            $Param{TimeUnitsRequired} = 'Validate_Required';
        }
        else {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabel',
                Data => \%Param,
            );
            $Param{TimeUnitsRequired} = '';
        }
        $LayoutObject->Block(
            Name => 'TimeUnits',
            Data => \%Param,
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

    # get output back
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketPhoneCommon',
        Data         => \%Param,
    );

}

sub _GetFieldsToUpdate {
    my ( $Self, %Param ) = @_;

    my @UpdatableFields;

    # set the fields that can be updateable via AJAXUpdate
    if ( !$Param{OnlyDynamicFields} ) {
        @UpdatableFields = qw( NextStateID StandardTemplateID );
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
