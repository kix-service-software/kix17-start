# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::CustomerTicketMessage;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

use base qw(Kernel::Modules::BaseTicketTemplateHandler);

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

    # get params
    my %GetParam;
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    for my $Key (qw( Subject Body PriorityID TypeID ServiceID SLAID Expand Dest QueueID )) {

        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
    }

    # ACL compatibility translation
    my %ACLCompatGetParam;
    $ACLCompatGetParam{OwnerID} = $GetParam{NewUserID};

    $GetParam{SelectedCustomerID} = $ParamObject->GetParam( Param => 'SelectedCustomerID' )
        || '';
    my $ConfigItemIDStrg = $ParamObject->GetParam( Param => 'SelectedConfigItemIDs' ) || '';
    $ConfigItemIDStrg =~ s/^,//g;
    my @SelectedCIIDs = split( ',', $ConfigItemIDStrg );
    $GetParam{DefaultSet} = $ParamObject->GetParam( Param => 'DefaultSet' ) || 0;

    # get Dynamic fields from ParamObject
    my %DynamicFieldValues;

    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Self->{Action}");

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # reduce the dynamic fields to only the ones that are designed for customer interface
    my @CustomerDynamicFields;
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsCustomerInterfaceCapable = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsCustomerInterfaceCapable',
        );
        next DYNAMICFIELD if !$IsCustomerInterfaceCapable;

        push @CustomerDynamicFields, $DynamicFieldConfig;
    }
    $DynamicField = \@CustomerDynamicFields;

    # save dynamic field config to $Self for use with show and hide acl
    $Self->{DynamicField} = $DynamicField;

    # handle for ticket templates
    $Self->{DefaultSet} = $ParamObject->GetParam( Param => 'DefaultSet' ) || 0;

    # get all dynamic fields
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{NotShownDynamicFields} = $DynamicFieldObject->DynamicFieldList(
        Valid      => 1,
        ObjectType => [ 'Ticket', 'Article' ],
        ResultType => 'HASH',
    );

    # create a lookup list
    %{ $Self->{NotShownDynamicFields} } = reverse %{ $Self->{NotShownDynamicFields} };
    for my $DynamicField ( sort keys %{ $Config->{DynamicField} } ) {

        # check if each field is active
        if ( $Config->{DynamicField}->{$DynamicField} ) {

            # remove all the fields that are actived for this screen
            delete $Self->{NotShownDynamicFields}->{$DynamicField};
        }
    }

    # prevent comparison errors by filling the non existent dynamic fields in the screen
    # configuration
    for my $DynamicField ( sort keys %{ $Self->{NotShownDynamicFields} } ) {
        if ( !defined $Config->{DynamicField}->{$DynamicField} ) {
            $Config->{DynamicField}->{$DynamicField} = 0;
        }
    }

    # Core.AJAX.js does not admit an empty string, then is necessary to define a string that
    # will set to empty right before is assigned to the HTML element (non select).
    $Self->{EmptyString} = '_DynamicTicketTemplate_EmptyString_Dont_Use_It_Please';

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # extract the dynamic field value form the web request
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} } =
            $BackendObject->EditFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ParamObject        => $ParamObject,
            LayoutObject       => $LayoutObject,
            );
    }

    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    DYNAMICFIELD:
    for my $DynamicField ( sort keys %DynamicFieldValues ) {
        next DYNAMICFIELD if !$DynamicField;
        next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

        $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField } = $DynamicFieldValues{$DynamicField};
    }
    $GetParam{DynamicField} = \%DynamicFieldACLParameters;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # handle for quick ticket templates
    if (
        $Self->{DefaultSet}
        && $Self->{Subaction} ne 'StoreNew'
        && ( !$Self->{Subaction} || $Self->{Subaction} ne 'AJAXUpdate' )
    ) {

        my %TemplateData = $Self->TicketTemplateReplace(
            IsUpload   => 0,
            Data       => \%GetParam,
            DefaultSet => $Self->{DefaultSet},
        );
        for my $Key ( keys %TemplateData ) {
            $GetParam{$Key} = $TemplateData{$Key};
            if ( $Key =~ /^QuickTicket(.*)/ ) {
                $GetParam{$1}     = $TemplateData{$Key};
                $TemplateData{$1} = $TemplateData{$Key};
                delete $GetParam{$Key};
            }
        }

        my %Ticket;
        if ( $Self->{TicketID} ) {
            %Ticket = $TicketObject->TicketGet( TicketID => $Self->{TicketID} );
        }
    }

    if ( !$Self->{Subaction} ) {

        #Get default Queue ID if none is set
        my $QueueDefaultID;
        if ( !$GetParam{Dest} && !$Param{ToSelected} && !$GetParam{DefaultQueueSelected} ) {
            my $QueueDefault = $Config->{'QueueDefault'} || '';
            if ($QueueDefault) {
                $QueueDefaultID = $QueueObject->QueueLookup( Queue => $QueueDefault );
                if ($QueueDefaultID) {
                    $Param{ToSelected} = $QueueDefaultID . '||' . $QueueDefault;
                }
                $ACLCompatGetParam{QueueID} = $QueueDefaultID;
            }

            # warn if there is no (valid) default queue and the customer can't select one
            elsif ( !$Config->{'Queue'} ) {
                $LayoutObject->CustomerFatalError(
                    Message => $LayoutObject->{LanguageObject}
                        ->Translate( 'Check SysConfig setting for %s::QueueDefault.', $Self->{Action} ),
                    Comment => Translatable('Please contact your administrator'),
                );
                return;
            }
        }

        elsif ( $GetParam{Dest} || $GetParam{DefaultQueueSelected} ) {
            if ( !$GetParam{Dest} ) {
                $GetParam{Dest} = $GetParam{DefaultQueueSelected};
            }
            my ( $QueueIDParam, $QueueParam ) = split( /\|\|/, $GetParam{Dest} );
            my $QueueIDLookup = $QueueObject->QueueLookup( Queue => $QueueParam );
            if ( $QueueIDLookup && $QueueIDLookup eq $QueueIDParam ) {
                my $CustomerPanelOwnSelection = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelOwnSelection');
                if ( %{ $CustomerPanelOwnSelection // {} } ) {
                    $Param{ToSelected} = $QueueIDParam . '||' . $CustomerPanelOwnSelection->{$QueueParam};
                }
                else {
                    $Param{ToSelected} = $GetParam{Dest};
                }
                $ACLCompatGetParam{QueueID} = $QueueIDLookup;
            }
        }

        # for ACL compatibility
        if ( !$GetParam{QueueID} ) {
            $GetParam{QueueID} = $QueueDefaultID;
        }

        # store the dynamic fields default values or used specific default values to be used as
        # ACLs info for all fields
        my %DynamicFieldDefaults;

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if !IsHashRefWithData( $DynamicFieldConfig->{Config} );
            next DYNAMICFIELD if !$DynamicFieldConfig->{Name};

            # get default value from dynamic field config (if any)
            my $DefaultValue = $DynamicFieldConfig->{Config}->{DefaultValue} || '';

            next DYNAMICFIELD if $DefaultValue eq '';
            next DYNAMICFIELD if ref $DefaultValue eq 'ARRAY' && !IsArrayRefWithData($DefaultValue);

            $DynamicFieldDefaults{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $DefaultValue;
        }
        $GetParam{DynamicField} = \%DynamicFieldDefaults;

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
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
                    my $ACL = $TicketObject->TicketAcl(
                        %GetParam,
                        %ACLCompatGetParam,
                        Action         => $Self->{Action},
                        TicketID       => $Self->{TicketID},
                        ReturnType     => 'Ticket',
                        ReturnSubType  => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data           => \%AclData,
                        CustomerUserID => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();

                        # convert Filer key => key back to key => value using map
                        %{ $DynamicFieldConfig->{ShownPossibleValues} }
                            = map( { $_ => $PossibleValues->{$_} } keys %Filter );
                    }
                }
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $BackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
                Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
                Value                => $GetParam{DynamicFieldHash}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                Template             => $GetParam{QuickTicketDynamicFieldHash},
            );
        }

        # get shown or hidden fields
        $Self->_GetShownDynamicFields();

        # print form ...
        my $Output .= $LayoutObject->CustomerHeader();
        $Output    .= $LayoutObject->CustomerNavigationBar();
        $Output    .= $Self->_MaskNew(
            %GetParam,
            %ACLCompatGetParam,
            ToSelected       => $Param{ToSelected},
            DynamicFieldHTML => \%DynamicFieldHTML,
            DefaultQueueID   => $QueueDefaultID || $GetParam{QueueID},
        );
        $Output .= $LayoutObject->CustomerFooter();
        return $Output;
    }
    elsif ( $Self->{Subaction} eq 'StoreNew' ) {

        my $NextScreen = $Config->{NextScreenAfterNewTicket};
        my %Error;

        # get destination queue
        my $Dest = $ParamObject->GetParam( Param => 'Dest' ) || '';
        my ( $NewQueueID, $To ) = split( /\|\|/, $Dest );
        if ( !$To ) {
            $NewQueueID = $ParamObject->GetParam( Param => 'NewQueueID' ) || '';
            $To = 'System';
        }

        # fallback, if no destination is given
        if ( !$NewQueueID ) {
            my $Queue = $ParamObject->GetParam( Param => 'Queue' )
                || $Config->{'QueueDefault'}
                || '';
            if ($Queue) {
                my $QueueID = $QueueObject->QueueLookup( Queue => $Queue );
                $NewQueueID = $QueueID;
                $To         = $Queue;
            }
        }

        # use default if ticket type is not available in screen but activated on system
        if ( $ConfigObject->Get('Ticket::Type') && !$Config->{'TicketType'} ) {
            my %TypeList = reverse $TicketObject->TicketTypeList(
                %Param,
                Action         => $Self->{Action},
                CustomerUserID => $Self->{UserID},
            );
            $GetParam{TypeID} = $TypeList{ $Config->{'TicketTypeDefault'} };
            if ( !$GetParam{TypeID} ) {
                $LayoutObject->CustomerFatalError(
                    Message =>
                        $LayoutObject->{LanguageObject}
                        ->Translate( 'Check SysConfig setting for %s::TicketTypeDefault.', $Self->{Action} ),
                    Comment => Translatable('Please contact your administrator'),
                );
                return;
            }
        }

        # If is an action about attachments
        my $IsUpload = 0;

        # attachment delete
        my @AttachmentIDs = map {
            my ($ID) = $_ =~ m{ \A AttachmentDelete (\d+) \z }xms;
            $ID ? $ID : ();
        } $ParamObject->GetParamNames();

        my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

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
            $IsUpload = 1;
            $Error{AttachmentUpload} = 1;
            my %UploadStuff = $ParamObject->GetUploadAll(
                Param => 'file_upload',
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

        if ( !$GetParam{QueueID} ) {
            $GetParam{QueueID} = $NewQueueID;
        }

        # create html strings for all dynamic fields
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
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
                    my $ACL = $TicketObject->TicketAcl(
                        %GetParam,
                        Action         => $Self->{Action},
                        TicketID       => $Self->{TicketID},
                        ReturnType     => 'Ticket',
                        ReturnSubType  => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data           => \%AclData,
                        CustomerUserID => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();

                        # convert Filer key => key back to key => value using map
                        %{ $DynamicFieldConfig->{ShownPossibleValues} }
                            = map( { $_ => $PossibleValues->{$_} } keys %Filter );
                    }
                }
            }
        }

        # get shown or hidden fields
        $Self->_GetShownDynamicFields();

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $ValidationResult;

            # do not validate on attachment upload or GetParam Expand
            if ( !$IsUpload && !$GetParam{Expand} && $DynamicFieldConfig->{Shown} ) {

                $ValidationResult = $BackendObject->EditFieldValueValidate(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
                    ParamObject          => $ParamObject,
                    Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                );

                if ( !IsHashRefWithData($ValidationResult) ) {
                    my $Output = $LayoutObject->CustomerHeader( Title => 'Error' );
                    $Output .= $LayoutObject->CustomerError(
                        Message =>
                            $LayoutObject->{LanguageObject}
                            ->Translate( 'Could not perform validation on field %s!', $DynamicFieldConfig->{Label} ),
                        Comment => Translatable('Please contact your administrator'),
                    );
                    $Output .= $LayoutObject->CustomerFooter();
                    return $Output;
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

        # rewrap body if no rich text is used
        if ( $GetParam{Body} && !$LayoutObject->{BrowserRichText} ) {
            $GetParam{Body} = $LayoutObject->WrapPlainText(
                MaxCharacters => $ConfigObject->Get('Ticket::Frontend::TextAreaNote'),
                PlainText     => $GetParam{Body},
            );
        }

        # check queue
        if ( !$NewQueueID && !$IsUpload && !$GetParam{Expand} ) {
            $Error{QueueInvalid} = 'ServerError';
        }

        # prevent tamper with (Queue/Dest), see bug#9408
        if ( $NewQueueID && !$IsUpload ) {

            # get the original list of queues to display
            my $Tos = $Self->_GetTos(
                %GetParam,
                %ACLCompatGetParam,
                QueueID => $NewQueueID,
            );

            # check if current selected QueueID exists in the list of queues,\
            # otherwise rise an error
            if ( !$Tos->{$NewQueueID} ) {
                $Error{QueueInvalid} = 'ServerError';
            }

            # set the correct queue name in $To if it was altered
            if ( $To ne $Tos->{$NewQueueID} ) {
                $To = $Tos->{$NewQueueID}
            }
        }

        # check subject
        if ( !$GetParam{Subject} && !$IsUpload ) {
            $Error{SubjectInvalid} = 'ServerError';
        }

        # check body
        if ( !$GetParam{Body} && !$IsUpload ) {
            $Error{BodyInvalid} = 'ServerError';
        }
        if ( $GetParam{Expand} ) {
            %Error = ();
            $Error{Expand} = 1;
        }

        # check mandatory service
        if (
            $ConfigObject->Get('Ticket::Service')
            && $Config->{Service}
            && $Config->{ServiceMandatory}
            && !$GetParam{ServiceID}
            && !$IsUpload
        ) {
            $Error{'ServiceIDInvalid'} = 'ServerError';
        }

        # check mandatory sla
        if (
            $ConfigObject->Get('Ticket::Service')
            && $Config->{SLA}
            && $Config->{SLAMandatory}
            && !$GetParam{SLAID}
            && !$IsUpload
        ) {
            $Error{'SLAIDInvalid'} = 'ServerError';
        }

        # check type
        if (
            $ConfigObject->Get('Ticket::Type')
            && !$GetParam{TypeID}
            && !$IsUpload
            && !$GetParam{Expand}
            && $Config->{TicketType}
        ) {
            $Error{TypeIDInvalid} = 'ServerError';
        }

        if (%Error) {

            # html output
            my $Output .= $LayoutObject->CustomerHeader();
            $Output    .= $LayoutObject->CustomerNavigationBar();
            $Output    .= $Self->_MaskNew(
                Attachments      => \@Attachments,
                %GetParam,
                ToSelected       => $Dest,
                QueueID          => $NewQueueID,
                DynamicFieldHTML => \%DynamicFieldHTML,
                Errors           => \%Error,
            );
            $Output .= $LayoutObject->CustomerFooter();
            return $Output;
        }

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck( Type => 'Customer' );

        # if customer is not allowed to set priority, set it to default
        if ( !$Config->{Priority} ) {
            $GetParam{PriorityID} = '';
            $GetParam{Priority}   = $Config->{PriorityDefault};
        }

        # if customer is not alowed to set ticket type, set it to default
        if ( $ConfigObject->Get('Ticket::Type') && !$Config->{TicketType} ) {
            my %Type = $TicketObject->TicketTypeList(
                %GetParam,
                Action         => $Self->{Action},
                CustomerUserID => $Self->{UserID},
            );

            my $TicketTypeDefault = $Config->{TicketTypeFix} || '';
            if ($TicketTypeDefault) {

                # Blanks remove
                $TicketTypeDefault =~ s/^\s+|\s+$//g;

                # select TypeID from Name
                my $DefaultTypeID = '';
                for my $ID ( keys %Type ) {
                    my $Name = $Type{$ID};
                    if ( $Name eq $TicketTypeDefault ) {
                        $DefaultTypeID = $ID;
                        last;
                    }
                }
                $GetParam{TypeID} = $DefaultTypeID;
            }
        }

        # create new ticket, do db insert
        my $TicketID = $TicketObject->TicketCreate(
            QueueID      => $NewQueueID,
            TypeID       => $GetParam{TypeID},
            ServiceID    => $GetParam{ServiceID},
            SLAID        => $GetParam{SLAID},
            Title        => $GetParam{Subject},
            PriorityID   => $GetParam{PriorityID},
            Priority     => $GetParam{Priority},
            Lock         => 'unlock',
            State        => $Config->{StateDefault},
            CustomerID   => $GetParam{SelectedCustomerID} || $Self->{UserCustomerID},
            CustomerUser => $Self->{UserLogin},
            OwnerID      => $ConfigObject->Get('CustomerPanelUserID'),
            UserID       => $ConfigObject->Get('CustomerPanelUserID'),
        );

        # set ticket dynamic fields
        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Ticket';
            next DYNAMICFIELD if !$DynamicFieldConfig->{Shown};

            # set the value
            my $Success = $BackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $TicketID,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $ConfigObject->Get('CustomerPanelUserID'),
            );
        }

        my $MimeType = 'text/plain';
        if ( $LayoutObject->{BrowserRichText} ) {
            $MimeType = 'text/html';

            # verify html document
            $GetParam{Body} = $LayoutObject->RichTextDocumentComplete(
                String => $GetParam{Body},
            );
        }

        my $PlainBody = $GetParam{Body};

        if ( $LayoutObject->{BrowserRichText} ) {
            $PlainBody = $LayoutObject->RichText2Ascii( String => $GetParam{Body} );
        }

        # create article
        my $FullName = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerName(
            UserLogin => $Self->{UserLogin},
        );
        my $From      = "\"$FullName\" <$Self->{UserEmail}>";
        my $ArticleID = $TicketObject->ArticleCreate(
            TicketID         => $TicketID,
            ArticleType      => $Config->{ArticleType},
            SenderType       => $Config->{SenderType},
            From             => $From,
            To               => $To,
            Subject          => $GetParam{Subject},
            Body             => $GetParam{Body},
            MimeType         => $MimeType,
            Charset          => $LayoutObject->{UserCharset},
            UserID           => $ConfigObject->Get('CustomerPanelUserID'),
            HistoryType      => $Config->{HistoryType},
            HistoryComment   => $Config->{HistoryComment} || '%%',
            AutoResponseType => ( $ConfigObject->Get('AutoResponseForWebTickets') )
            ? 'auto reply'
            : '',
            OrigHeader => {
                From    => $From,
                To      => $Self->{UserLogin},
                Subject => $GetParam{Subject},
                Body    => $PlainBody,
            },
            Queue => $QueueObject->QueueLookup( QueueID => $NewQueueID ),
        );

        if ( !$ArticleID ) {
            my $Output = $LayoutObject->CustomerHeader( Title => 'Error' );
            $Output .= $LayoutObject->CustomerError();
            $Output .= $LayoutObject->CustomerFooter();
            return $Output;
        }

        # set article dynamic fields
        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
            next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Article';
            next DYNAMICFIELD if !$DynamicFieldConfig->{Shown};

            # set the value
            my $Success = $BackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $ArticleID,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                UserID             => $ConfigObject->Get('CustomerPanelUserID'),
            );
        }

        # get pre loaded attachment
        my @AttachmentData = $UploadCacheObject->FormIDGetAllFilesData(
            FormID => $Self->{FormID},
        );

        # get submitted attachment
        my %UploadStuff = $ParamObject->GetUploadAll(
            Param => 'file_upload',
        );
        if (%UploadStuff) {
            push @AttachmentData, \%UploadStuff;
        }

        # write attachments
        ATTACHMENT:
        for my $Attachment (@AttachmentData) {

            # skip, deleted not used inline images
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
                next ATTACHMENT if $GetParam{Body} !~ /(\Q$ContentIDHTMLQuote\E|\Q$ContentID\E)/i;
            }

            # write existing file to backend
            $TicketObject->ArticleWriteAttachment(
                %{$Attachment},
                ArticleID => $ArticleID,
                UserID    => $ConfigObject->Get('CustomerPanelUserID'),
            );
        }

        my $LinkType = $ConfigObject->Get('KIXSidebarConfigItemLink::LinkType')
            || 'Normal';
        for my $CurrKey (@SelectedCIIDs) {
            $Self->{LinkObject}->LinkAdd(
                SourceObject => 'ITSMConfigItem',
                SourceKey    => $CurrKey,
                TargetObject => 'Ticket',
                TargetKey    => $TicketID,
                Type         => $LinkType,
                State        => 'Valid',
                UserID       => $ConfigObject->Get('CustomerPanelUserID'),
            );
        }

        # get the temporarily links
        my $LinkObject = $Kernel::OM->Get('Kernel::System::LinkObject');
        my $TempLinkList = $LinkObject->LinkList(
            Object => 'Ticket',
            Key    => $Self->{FormID},
            State  => 'Temporary',
            UserID => $Self->{UserID},
        );

        if ( $TempLinkList && ref $TempLinkList eq 'HASH' && %{$TempLinkList} ) {

            for my $TargetObjectOrg ( keys %{$TempLinkList} ) {

                # extract typelist
                my $TypeList = $TempLinkList->{$TargetObjectOrg};

                for my $Type ( keys %{$TypeList} ) {

                    # extract direction list
                    my $DirectionList = $TypeList->{$Type};

                    for my $Direction ( keys %{$DirectionList} ) {

                        for my $TargetKeyOrg ( keys %{ $DirectionList->{$Direction} } ) {

                            # delete the temp link
                            $LinkObject->LinkDelete(
                                Object1 => 'Ticket',
                                Key1    => $Self->{FormID},
                                Object2 => $TargetObjectOrg,
                                Key2    => $TargetKeyOrg,
                                Type    => $Type,
                                UserID  => $Self->{UserID},
                            );

                            my $SourceObject = $TargetObjectOrg;
                            my $SourceKey    = $TargetKeyOrg;
                            my $TargetObject = 'Ticket';
                            my $TargetKey    = $TicketID;

                            if ( $Direction eq 'Target' ) {
                                $SourceObject = 'Ticket';
                                $SourceKey    = $TicketID;
                                $TargetObject = $TargetObjectOrg;
                                $TargetKey    = $TargetKeyOrg;
                            }

                            # add the permanently link
                            my $Success = $LinkObject->LinkAdd(
                                SourceObject => $SourceObject,
                                SourceKey    => $SourceKey,
                                TargetObject => $TargetObject,
                                TargetKey    => $TargetKey,
                                Type         => $Type,
                                State        => 'Valid',
                                UserID       => $ConfigObject->Get('CustomerPanelUserID'),
                            );
                        }
                    }
                }
            }
        }

        # remove pre submitted attachments
        $UploadCacheObject->FormIDRemove( FormID => $Self->{FormID} );

        # redirect
        return $LayoutObject->Redirect(
            OP => "Action=$NextScreen;TicketID=$TicketID",
        );
    }

    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {

        my $Dest         = $ParamObject->GetParam( Param => 'Dest' ) || '';
        my $CustomerUser = $Self->{UserID};
        my $QueueID      = '';
        if ( $Dest =~ /^(\d{1,100})\|\|.+?$/ ) {
            $QueueID = $1;
        }

        # get list type
        my $TreeView = 0;
        if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
            $TreeView = 1;
        }

        my $Tos = $Self->_GetTos(
            %GetParam,
            %ACLCompatGetParam,
            QueueID => $QueueID,
        );

        my $NewTos;

        if ($Tos) {
            TOs:
            for my $KeyTo ( sort keys %{$Tos} ) {
                next TOs if ( $Tos->{$KeyTo} eq '-' );
                $NewTos->{"$KeyTo||$Tos->{$KeyTo}"} = $Tos->{$KeyTo};
            }
        }
        my $Priorities = $Self->_GetPriorities(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser || '',
            QueueID        => $QueueID      || 1,
        );
        my $Services = $Self->_GetServices(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser || '',
            QueueID        => $QueueID      || 1,
        );
        my $SLAs = $Self->_GetSLAs(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser || '',
            QueueID        => $QueueID      || 1,
            Services       => $Services,
            CustomerID     => $GetParam{SelectedCustomerID},
        );
        my $Types = $Self->_GetTypes(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $CustomerUser || '',
            QueueID        => $QueueID      || 1,
        );

        # update Dynamic Fields Possible Values via AJAX
        my @DynamicFieldAJAX;
        my %DynamicFieldHTML;

        # cycle trough the activated Dynamic Fields for this screen
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
                    UseDefaultValue    => 1,
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
            my $ACL = $TicketObject->TicketAcl(
                %GetParam,
                %ACLCompatGetParam,
                Action         => $Self->{Action},
                QueueID        => $QueueID || 0,
                ReturnType     => 'Ticket',
                ReturnSubType  => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data           => \%AclData,
                CustomerUserID => $Self->{UserID},
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
                    SelectedID  => $DynamicFieldValues{ $DynamicFieldConfig->{Name} } // $DynamicFieldConfig->{Config}->{DefaultValue},
                    Translation => $DynamicFieldConfig->{Config}->{TranslatableValues} || 0,
                    Max         => 100,
                }
            );

            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } = $BackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValues,
                Mandatory            => $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
            );
        }

        # get shown or hidden fields
        $Self->_GetShownDynamicFields();

        # use only dynamic fields which passed the acl
        my %Output;
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Ticket';

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

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'Dest',
                    Data         => $NewTos,
                    SelectedID   => $Dest,
                    Translation  => 0,
                    PossibleNone => 1,
                    TreeView     => $TreeView,
                    Max          => 100,
                },
                {
                    Name        => 'PriorityID',
                    Data        => $Priorities,
                    SelectedID  => $GetParam{PriorityID},
                    Translation => 1,
                    Max         => 100,
                },
                {
                    Name         => 'ServiceID',
                    Data         => $Services,
                    SelectedID   => $GetParam{ServiceID},
                    PossibleNone => 1,
                    Translation  => 0,
                    TreeView     => $TreeView,
                    Max          => 100,
                },
                {
                    Name         => 'SLAID',
                    Data         => $SLAs,
                    SelectedID   => $GetParam{SLAID},
                    PossibleNone => 1,
                    Translation  => 0,
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
                @FormDisplayOutput,
                @DynamicFieldAJAX,
            ],
        );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    else {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('No Subaction!'),
            Comment => Translatable('Please contact your administrator'),
        );
    }

}

sub _GetPriorities {
    my ( $Self, %Param ) = @_;

    # get priority
    my %Priorities;
    if ( $Param{QueueID} || $Param{TicketID} ) {
        %Priorities = $Kernel::OM->Get('Kernel::System::Ticket')->TicketPriorityList(
            %Param,
            Action         => $Self->{Action},
            CustomerUserID => $Self->{UserID},
        );
    }
    return \%Priorities;
}

sub _GetTypes {
    my ( $Self, %Param ) = @_;

    # get type
    my %Type;
    if ( $Param{QueueID} || $Param{TicketID} ) {
        %Type = $Kernel::OM->Get('Kernel::System::Ticket')->TicketTypeList(
            %Param,
            Action         => $Self->{Action},
            CustomerUserID => $Self->{UserID},
        );
    }
    return \%Type;
}

sub _GetServices {
    my ( $Self, %Param ) = @_;

    # get service
    my %Service;

    # check needed
    return \%Service if !$Param{QueueID} && !$Param{TicketID};

    # get options for default services for unknown customers
    my $DefaultServiceUnknownCustomer
        = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Service::Default::UnknownCustomer');

    # get service list
    if ( $Param{CustomerUserID} || $DefaultServiceUnknownCustomer ) {
        %Service = $Kernel::OM->Get('Kernel::System::Ticket')->TicketServiceList(
            %Param,
            Action         => $Self->{Action},
            CustomerUserID => $Self->{UserID},
            DefaultSet     => $Self->{DefaultSet}        || '',
            CustomerID     => $Param{SelectedCustomerID} || $Self->{UserCustomerID} || '',
        );
    }
    return \%Service;
}

sub _GetSLAs {
    my ( $Self, %Param ) = @_;

    # get sla
    my %SLA;
    if ( $Param{ServiceID} && $Param{Services} && %{ $Param{Services} } ) {
        if ( $Param{Services}->{ $Param{ServiceID} } ) {
            %SLA = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSLAList(
                %Param,
                Action         => $Self->{Action},
                CustomerUserID => $Self->{UserID},
            );
        }
    }
    return \%SLA;
}

sub _GetTos {
    my ( $Self, %Param ) = @_;

    # check own selection
    my %NewTos = ( '', '-' );
    my $Module = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanel::NewTicketQueueSelectionModule')
        || 'Kernel::Output::HTML::CustomerNewTicket::QueueSelectionGeneric';
    if ( $Kernel::OM->Get('Kernel::System::Main')->Require($Module) ) {
        my $Object = $Module->new(
            %{$Self},
            SystemAddress => $Kernel::OM->Get('Kernel::System::SystemAddress'),
            Debug         => $Self->{Debug},
        );

        # log loaded module
        if ( $Self->{Debug} && $Self->{Debug} > 1 ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'debug',
                Message  => "Module: $Module loaded!",
            );
        }
        %NewTos = (
            $Object->Run(
                Env       => $Self,
                ACLParams => \%Param
            ),
            ( '', => '-' )
        );
    }
    else {
        return $Kernel::OM->Get('Kernel::Output::HTML::Layout')->FatalDie(
            Message => "Could not load $Module!",
        );
    }

    return \%NewTos;
}

sub _MaskNew {
    my ( $Self, %Param ) = @_;

    $Param{FormID}                 = $Self->{FormID};
    $Param{QueueID}                = ( $Param{DefaultQueueID}       || $Self->{QueueID} ) if !defined $Param{QueueID};
    $Param{Errors}->{QueueInvalid} = $Param{Errors}->{QueueInvalid} || '';

    my $DynamicFieldNames = $Self->_GetFieldsToUpdate(
        OnlyDynamicFields => 1,
    );

    # create a string with the quoted dynamic field names separated by commas
    if ( IsArrayRefWithData($DynamicFieldNames) ) {
        for my $Field ( @{$DynamicFieldNames} ) {
            $Param{DynamicFieldNamesStrg} .= ", '" . $Field . "'";
        }
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get list type
    my $TreeView = 0;
    if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
        $TreeView = 1;
    }

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $Config       = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Self->{Action}");

    if ( $Param{SelectedCustomerID} ) {
        $LayoutObject->Block(
            Name => 'SelectedCustomer',
            Data => \%Param,
        );
    }

    if ( $Config->{Queue} ) {

        # check own selection
        my %NewTos = ( '', '-' );
        my $Module = $ConfigObject->Get('CustomerPanel::NewTicketQueueSelectionModule')
            || 'Kernel::Output::HTML::CustomerNewTicket::QueueSelectionGeneric';
        if ( $Kernel::OM->Get('Kernel::System::Main')->Require($Module) ) {
            my $Object = $Module->new(
                %{$Self},
                SystemAddress => $Kernel::OM->Get('Kernel::System::SystemAddress'),
                Debug         => $Self->{Debug},
            );

            # log loaded module
            if ( $Self->{Debug} && $Self->{Debug} > 1 ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'debug',
                    Message  => "Module: $Module loaded!",
                );
            }
            %NewTos = (
                $Object->Run(
                    Env       => $Self,
                    ACLParams => \%Param
                ),
                ( '', => '-' )
            );
        }
        else {
            return $LayoutObject->FatalError();
        }

        # get queue and build selected string
        if ( !$Param{QueueID} ) {
            if ( $Self->{'UserDefaultTicketQueue'} && $Self->{'UserDefaultTicketQueue'} ne '-' ) {
                my $UserDefQueueID = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                    Queue => $Self->{'UserDefaultTicketQueue'}
                );
                $Param{QueueID} = $UserDefQueueID if ($UserDefQueueID);
            }
        }
        my $SelectedQueueID = "";

        # build to string
        if (%NewTos) {
            for ( sort keys %NewTos ) {
                $NewTos{"$_||$NewTos{$_}"} = $NewTos{$_};

                if ( $Param{QueueID} && $_ && $_ == $Param{QueueID} ) {
                    $SelectedQueueID = "$_||$NewTos{$_}";
                }

                delete $NewTos{$_};
            }
        }

        # fallback in case of CustomerPanelOwnSelection
        if (
            $ConfigObject->Get('CustomerPanelOwnSelection')
            && !$SelectedQueueID
            && $Param{DefaultQueueSelected}
        ) {
            my ( $SelectedQueueID, $Tmp ) = split( /||/, $Param{DefaultQueueSelected} );
            foreach my $NewTo ( sort keys %NewTos ) {
                my ( $QueueID, $Tmp ) = split( /||/, $NewTo );
                if ( $QueueID == $SelectedQueueID ) {
                    $Param{DefaultQueueSelected} = $NewTo,
                        last;
                }
            }
        }

        $Param{ToStrg} = $LayoutObject->AgentQueueListOption(
            Data        => \%NewTos,
            Multiple    => 0,
            Size        => 0,
            Name        => 'Dest',
            Class       => "Validate_Required Modernize " . $Param{Errors}->{QueueInvalid},
            SelectedID  => $SelectedQueueID || $Param{DefaultQueueSelected} || '',
            TreeView    => $TreeView,
        );
        $LayoutObject->Block(
            Name => 'Queue',
            Data => {
                %Param,
                QueueInvalid => $Param{Errors}->{QueueInvalid},
            },
        );

    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get priority
    if ( $Config->{Priority} ) {
        my %Priorities = $TicketObject->TicketPriorityList(
            %Param,
            DefaultSet     => $Self->{DefaultSet} || '',
            CustomerUserID => $Self->{UserID},
            Action         => $Self->{Action},
        );

        # build priority string
        my %PrioritySelected;
        if ( $Param{PriorityID} ) {
            $PrioritySelected{SelectedID} = $Param{PriorityID};
        }
        else {
            $PrioritySelected{SelectedValue} = $Config->{PriorityDefault} || '3 normal';
        }

        $Param{PriorityStrg} = $LayoutObject->BuildSelection(
            Data  => \%Priorities,
            Name  => 'PriorityID',
            Class => 'Modernize',
            %PrioritySelected,
            Translation => 1,
        );

        $LayoutObject->Block(
            Name => 'Priority',
            Data => \%Param,
        );
    }

    # types
    if ( $ConfigObject->Get('Ticket::Type') && $Config->{'TicketType'} ) {
        my %Type = $TicketObject->TicketTypeList(
            %Param,
            Action         => $Self->{Action},
            CustomerUserID => $Self->{UserID},
            DefaultSet     => $Self->{DefaultSet} || '',
        );

        if ( $Config->{'TicketTypeDefault'} && !$Param{TypeID} ) {
            my %ReverseType = reverse %Type;
            $Param{TypeID} = $ReverseType{ $Config->{'TicketTypeDefault'} };
        }

        # get default ticket type and lookup type ID
        if ( $Self->{'UserDefaultTicketType'} && $Self->{'UserDefaultTicketType'} ne '-' ) {
            $Param{TicketTypeDefault} = $Self->{'UserDefaultTicketType'};

            # Blanks remove
            $Param{TicketTypeDefault} =~ s/^\s+|\s+$//g;

            # select TypeID from Name
            my $DefaultTypeID = '';
            for my $ID ( keys %Type ) {
                my $Name = $Type{$ID};
                if ( $Name eq $Param{TicketTypeDefault} ) {
                    $DefaultTypeID = $ID;
                    last;
                }
            }
            $Param{DefaultTypeID} = $DefaultTypeID;
        }
        if ( !$Param{DefaultTypeID} && $Config->{TicketTypeDefault} ) {
            $Param{TicketTypeDefault} = $Config->{TicketTypeDefault};

            # Blanks remove
            $Param{TicketTypeDefault} =~ s/^\s+|\s+$//g;

            # select TypeID from Name
            my $DefaultTypeID = '';
            for my $ID ( keys %Type ) {
                my $Name = $Type{$ID};
                if ( $Name eq $Param{TicketTypeDefault} ) {
                    $DefaultTypeID = $ID;
                    last;
                }
            }
            $Param{DefaultTypeID} = $DefaultTypeID;
        }

        $Param{TypeStrg} = $LayoutObject->BuildSelection(
            Data         => \%Type,
            Name         => 'TypeID',
            SelectedID   => $Param{TypeID} || $Param{DefaultTypeID} || '',
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 0,
            Class        => "Validate_Required Modernize " . ( $Param{Errors}->{TypeIDInvalid} || '' ),
        );
        $LayoutObject->Block(
            Name => 'TicketType',
            Data => {
                %Param,
                TypeIDInvalid => $Param{Errors}->{TypeIDInvalid},
            }
        );
    }

    # services
    if ( $ConfigObject->Get('Ticket::Service') && $Config->{Service} ) {
        my %Services;
        if ( $Param{QueueID} || $Param{TicketID} ) {
            %Services = $TicketObject->TicketServiceList(
                %Param,
                Action         => $Self->{Action},
                CustomerUserID => $Self->{UserID},
                DefaultSet     => $Self->{DefaultSet}        || '',
                CustomerID     => $Param{SelectedCustomerID} || $Self->{UserCustomerID} || '',
            );
        }

        my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');
        if ( !$Self->{DefaultSet} && !$Param{ServiceID} && $Self->{'UserDefaultService'} ) {
            $Param{ServiceID} = $ServiceObject->ServiceLookup(
                Name => $Self->{'UserDefaultService'},
            );
        }

        if ( $Config->{ServiceMandatory} ) {
            $Param{ServiceStrg} = $LayoutObject->BuildSelection(
                Data         => \%Services,
                Name         => 'ServiceID',
                SelectedID   => $Param{ServiceID},
                Class        => "Validate_Required Modernize " . ( $Param{Errors}->{ServiceIDInvalid} || '' ),
                PossibleNone => 1,
                TreeView     => $TreeView,
                Sort         => 'TreeView',
                Translation  => 0,
                Max          => 200,
            );

            $LayoutObject->Block(
                Name => 'TicketServiceMandatory',
                Data => \%Param,
            );
        }
        else {
            $Param{ServiceStrg} = $LayoutObject->BuildSelection(
                Data         => \%Services,
                Name         => 'ServiceID',
                SelectedID   => $Param{ServiceID},
                Class        => 'Modernize',
                PossibleNone => 1,
                TreeView     => $TreeView,
                Sort         => 'TreeView',
                Translation  => 0,
                Max          => 200,
            );
            $LayoutObject->Block(
                Name => 'TicketService',
                Data => \%Param,
            );
        }

        # reset previous ServiceID to reset SLA-List if no service is selected
        if ( !$Services{ $Param{ServiceID} || '' } ) {
            $Param{ServiceID} = '';
        }
        my %SLA;
        if ( $Config->{SLA} ) {
            if ( $Param{ServiceID} ) {
                %SLA = $TicketObject->TicketSLAList(
                    %Param,
                    Action         => $Self->{Action},
                    CustomerUserID => $Self->{UserID},
                    DefaultSet     => $Self->{DefaultSet} || '',
                );
            }

            if ( $Config->{SLAMandatory} ) {
                $Param{SLAStrg} = $LayoutObject->BuildSelection(
                    Data         => \%SLA,
                    Name         => 'SLAID',
                    SelectedID   => $Param{SLAID},
                    Class        => "Validate_Required Modernize " . ( $Param{Errors}->{SLAIDInvalid} || '' ),
                    PossibleNone => 1,
                    Sort         => 'AlphanumericValue',
                    Translation  => 0,
                    Max          => 200,
                );

                $LayoutObject->Block(
                    Name => 'TicketSLAMandatory',
                    Data => \%Param,
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
                    Translation  => 0,
                    Max          => 200,
                );

                $LayoutObject->Block(
                    Name => 'TicketSLA',
                    Data => \%Param,
                );
            }
        }
    }

    # prepare errors
    if ( $Param{Errors} ) {
        for ( sort keys %{ $Param{Errors} } ) {
            $Param{$_} = $Param{Errors}->{$_};
        }
    }

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # reduce the dynamic fields to only the ones that are designed for customer interface
    my @CustomerDynamicFields;
    DYNAMICFIELD:
    # for my $DynamicFieldConfig ( @{$DynamicField} ) {
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsCustomerInterfaceCapable = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsCustomerInterfaceCapable',
        );
        next DYNAMICFIELD if !$IsCustomerInterfaceCapable;

        push @CustomerDynamicFields, $DynamicFieldConfig;
    }
    $Self->{DynamicField} = \@CustomerDynamicFields;

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

        my $Class = "";
        if ( !$DynamicFieldConfig->{Shown} ) {
            $Class = " Hidden";
            $DynamicFieldHTML->{Field} =~ s/Validate_Required//ig;
            $DynamicFieldHTML->{Field} =~ s/<(input|select|textarea)(.*?)(!?|\/)>/<$1$2 disabled="disabled"$3>/g;
        }

        $LayoutObject->Block(
            Name => 'DynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
                Class => $Class,
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

    if ( !$Param{Subject} && $Config->{Subject} ) {
        $Param{Subject} = $LayoutObject->Output(
            Template => $Config->{Subject} || '',
        );
    }
    if ( !$Param{Body} && $Config->{Body} ) {
        $Param{Body} = $LayoutObject->Output(
            Template => $Config->{Body} || '',
        );
        if ( $LayoutObject->{BrowserRichText} ) {
            $Param{Body} = $LayoutObject->Ascii2RichText( String => $Param{Body} );
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

    # load KIXSidebar
    $Param{KIXSidebarContent} = $LayoutObject->CustomerKIXSidebar(%Param);

    # get output back
    return $LayoutObject->Output(
        TemplateFile => 'CustomerTicketMessage',
        Data         => \%Param,
    );
}

sub _GetFieldsToUpdate {
    my ( $Self, %Param ) = @_;

    my @UpdatableFields;

    # set the fields that can be updatable via AJAXUpdate
    if ( !$Param{OnlyDynamicFields} ) {
        @UpdatableFields = qw( Dest ServiceID SLAID PriorityID );
    }

    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Self->{Action}");

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    # for my $DynamicFieldConfig ( @{$DynamicField} ) {
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

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # use only dynamic fields which passed the acl
    my %TicketAclFormData = $TicketObject->TicketAclFormData();

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
