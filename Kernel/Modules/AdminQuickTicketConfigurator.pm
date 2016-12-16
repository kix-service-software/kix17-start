# --
# Kernel/Modules/AdminQuickTicketConfigurator.pm - to handle qucik ticket templates
# based upon AgentTicketEmail.pm
# original Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# KIX4OTRS-Extensions Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Martin(dot)Balzarek(at)cape(dash)it(dot)de
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::Modules::AdminQuickTicketConfigurator;

use strict;
use warnings;

use Mail::Address;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $UploadCacheObject  = $Kernel::OM->Get('Kernel::System::Web::UploadCache');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $ServiceObject      = $Kernel::OM->Get('Kernel::System::Service');
    my $LinkObject         = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');

    $Self->{Config} = $ConfigObject->Get("Ticket::Frontend::AdminQuickTicketConfigurator");

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Self->{Config}->{DynamicField} || {},
    );

    # create form id
    $Self->{FormID} = $UploadCacheObject->FormIDCreate();

    my $Output;
    my %GetParam;

    # get form values
    for my $Key (
        qw(ID  Name CustomerLogin CcCustomerLogin BccCustomerLogin ElementChanged
        PriorityID OwnerID QueueID From Subject Body StateID TimeUnits Cc Bcc FormID
        PendingOffset LinkType LinkDirection ArticleType ArticleSenderType
        ResponsibleID ResponsibleAll OwnerAll TypeID ServiceID SLAID KIXSidebarChecklistTextField)
        )
    {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key ) || '';
        $GetParam{ $Key . 'Empty' } = $ParamObject->GetParam( Param => $Key . 'Empty' )
            || '';
        $GetParam{ $Key . 'Fixed' } = $ParamObject->GetParam( Param => $Key . 'Fixed' )
            || '';
    }

    for my $Key (qw(Agent Customer))
    {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key ) || 0;
    }

    # get user group ids
    my @UserGroupIDs = $ParamObject->GetArray( Param => 'UserGroupID' );
    $GetParam{UserGroupIDs} = join( ",", @UserGroupIDs );

    $Param{FormID} = $Self->{FormID};

    # get CustomerUser
    $GetParam{SelectedCustomerUser}
        = $ParamObject->GetParam( Param => 'SelectedCustomerUser' ) || '';
    if ( $GetParam{SelectedCustomerUser} ) {
        $GetParam{CustomerLogin}        = $GetParam{SelectedCustomerUser};
        $GetParam{SelectedCustomerUser} = '';
    }

    # ACL compatibility translation
    my %ACLCompatGetParam;
    $ACLCompatGetParam{OwnerID} = $GetParam{OwnerID};

    # set an empty value if not defined
    $GetParam{Cc}  = '' if !defined $GetParam{Cc};
    $GetParam{Bcc} = '' if !defined $GetParam{Bcc};

    # get Dynamic fields form ParamObject
    my %DynamicFieldValues;

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # extract the dynamic field value form the web request
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} }
            = $BackendObject->EditFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ParamObject        => $ParamObject,
            LayoutObject       => $LayoutObject,
            );
    }

    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    DYNAMICFIELD:
    for my $DynamicField ( sort keys %DynamicFieldValues ) {

        $GetParam{ 'DynamicField_' . $DynamicField . 'Empty' }
            = $ParamObject->GetParam( Param => 'DynamicField_' . $DynamicField . 'Empty' )
            || '';
        $GetParam{ 'DynamicField_' . $DynamicField . 'Fixed' }
            = $ParamObject->GetParam( Param => 'DynamicField_' . $DynamicField . 'Fixed' )
            || '';

        next DYNAMICFIELD if !$DynamicField;
        next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

        $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField }
            = $DynamicFieldValues{$DynamicField};
    }
    $GetParam{DynamicField} = \%DynamicFieldACLParameters;

    # ------------------------------------------------------------------------ #
    # change or add ticket template
    # ------------------------------------------------------------------------ #

    if ( ( $Self->{Subaction} eq 'Change' && $GetParam{ID} ) || $Self->{Subaction} eq 'New' ) {

        my %TicketTemplateData = ();
        my %Error;

        # header
        $Output .= $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        if ( $Self->{Subaction} eq 'Change' ) {
            %TicketTemplateData = $TicketObject->TicketTemplateGet(
                ID => $GetParam{ID}
            );
            for my $DataKey ( keys %TicketTemplateData ) {
                $GetParam{$DataKey} = $TicketTemplateData{$DataKey};
                if ( $DataKey eq 'QueueID' && $GetParam{$DataKey} eq '-' ) {
                    $GetParam{$DataKey} = '';
                }
            }
            $TicketTemplateData{Agent}    = 'checked="checked"' if $TicketTemplateData{Agent};
            $TicketTemplateData{Customer} = 'checked="checked"' if $TicketTemplateData{Customer};
        }

        # output backlink
        $LayoutObject->Block(
            Name => 'ActionOverview',
            Data => \%Param,
        );

        # store the dynamic fields default values or used specific default values to be used as
        # ACLs info for all fields
        my %DynamicFieldHTML;

        # cycle through the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $PossibleValuesFilter;

            # check if field has PossibleValues property in its configuration
            if ( IsHashRefWithData( $DynamicFieldConfig->{Config}->{PossibleValues} ) ) {

                # set possible values filter from ACLs
                my $ACL = $TicketObject->TicketAcl(
                    %TicketTemplateData,
                    %GetParam,
                    %ACLCompatGetParam,
                    Action        => $Self->{Action},
                    ReturnType    => 'Ticket',
                    ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data          => $DynamicFieldConfig->{Config}->{PossibleValues},
                    UserID        => $Self->{UserID},
                );
                if ($ACL) {
                    my %Filter = $TicketObject->TicketAclData();
                    $PossibleValuesFilter = \%Filter;
                }
            }

            # to store dynamic field value from database (or undefined)
            my $Value = '';

            # get default value
            if ( defined $DynamicFieldConfig->{Config}->{DefaultValue} ) {
                $Value = $DynamicFieldConfig->{Config}->{DefaultValue};
            }

            # get value from ticket template
            if ( $TicketTemplateData{ 'DynamicField_' . $DynamicFieldConfig->{Name} } ) {
                $Value = $TicketTemplateData{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
            }

            # get field html
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }
                = $BackendObject->EditFieldRender(
                DynamicFieldConfig   => $DynamicFieldConfig,
                PossibleValuesFilter => $PossibleValuesFilter,
                Value                => $Value,
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
                Mandatory => $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                );
        }

        # get customer from quick ticket
        my %CustomerData = ();
        $TicketTemplateData{CustomerUserID} = '';
        if ( $TicketTemplateData{CustomerLogin} ) {
            %CustomerData = $CustomerUserObject->CustomerUserDataGet(
                User => $TicketTemplateData{CustomerLogin},
            );
            if (
                $CustomerData{UserCustomerID}
                && $CustomerData{UserID}
                && $CustomerData{UserEmail}
                )
            {
                my $CustomerName = $CustomerUserObject
                    ->CustomerName( UserLogin => $CustomerData{UserID} );
                $TicketTemplateData{From}
                    = '"' . $CustomerName . '" '
                    . '<' . $CustomerData{UserEmail} . '>';
                $TicketTemplateData{CustomerID}     = $CustomerData{UserCustomerID};
                $TicketTemplateData{CustomerUserID} = $CustomerData{UserID};
                $CustomerData{CustomerUserLogin}    = $CustomerData{UserID};
            }
            else {
                $TicketTemplateData{From} = $GetParam{DefaultCustomer};
            }
        }

        # empty customer / cc / bcc
        $TicketTemplateData{FromEmpty} = 'checked="checked"' if $TicketTemplateData{FromEmpty};
        $TicketTemplateData{CcEmpty}   = 'checked="checked"' if $TicketTemplateData{CcEmpty};
        $TicketTemplateData{BccEmpty}  = 'checked="checked"' if $TicketTemplateData{BccEmpty};

        # queue id
        if ( !defined $TicketTemplateData{QueueID} || $TicketTemplateData{QueueID} eq '-' ) {
            $TicketTemplateData{QueueID} = '';
        }

        # subject and body
        $TicketTemplateData{SubjectEmpty} = 'checked="checked"'
            if $TicketTemplateData{SubjectEmpty};
        $TicketTemplateData{BodyEmpty} = 'checked="checked"' if $TicketTemplateData{BodyEmpty};

        # get services
        my $Services = $Self->_GetServices(
            CustomerUserID => $TicketTemplateData{CustomerUserID} || '',
            QueueID        => $TicketTemplateData{QueueID}        || 1,
        );
        my $SLAs = $Self->_GetSLAs(
            %GetParam,
            QueueID => $TicketTemplateData{QueueID} || 1,
            Services => $Services,
        );

        # get user groups
        if ( defined $TicketTemplateData{UserGroupIDs} && $TicketTemplateData{UserGroupIDs} ) {
            @UserGroupIDs = split( /,/, $TicketTemplateData{UserGroupIDs} )
        }
        else {
            @UserGroupIDs = ();
        }

        # html output
        $Output .= $Self->_MaskNew(
            Users => $Self->_GetUsers(
                QueueID  => $TicketTemplateData{QueueID},
                AllUsers => $TicketTemplateData{OwnerAll},
            ),
            ResponsibleUsers => $Self->_GetUsers(
                QueueID  => $TicketTemplateData{QueueID},
                AllUsers => $TicketTemplateData{ResponsibleAll},
            ),
            NextStates => $Self->_GetNextStates(
                CustomerUserID => $TicketTemplateData{CustomerUserID} || '',
                QueueID        => $TicketTemplateData{QueueID}        || 1,
            ),
            Priorities => $Self->_GetPriorities(
                CustomerUserID => $TicketTemplateData{CustomerUserID} || '',
                QueueID        => $TicketTemplateData{QueueID}        || 1,
            ),
            Types => $Self->_GetTypes(
                CustomerUserID => $TicketTemplateData{CustomerUserID} || '',
                QueueID        => $TicketTemplateData{QueueID}        || 1,
            ),
            Services => $Services,
            SLAs     => $SLAs,
            CustomerID =>
                $LayoutObject->Ascii2Html( Text => $TicketTemplateData{CustomerID} ),
            CustomerData     => \%CustomerData,
            FromList         => $Self->_GetTos(),
            Subject          => $LayoutObject->Ascii2Html( Text => $TicketTemplateData{Subject} ),
            Body             => $LayoutObject->Ascii2Html( Text => $TicketTemplateData{Body} ),
            Errors           => \%Error,
            DynamicFieldHTML => \%DynamicFieldHTML,
            UserGroups       => \@UserGroupIDs,
            %TicketTemplateData,
            FormID => $Param{FormID},
        );
        $Output .= $LayoutObject->Footer();
        return $Output;
    }

    # ------------------------------------------------------------------------ #
    # save
    # ------------------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Save' ) {

        my %Error;
        if ( !$GetParam{QueueID} ) {
            $GetParam{OwnerAll} = 1;
        }

        # output header
        $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        # check required attributes...
        for my $Key (qw(Name)) {
            if ( !$GetParam{$Key} ) {
                $Error{ $Key . 'Invalid' } = 'ServerError';
            }
        }

        # some sort of error handling...
        if (%Error) {

            # output backlink
            $LayoutObject->Block(
                Name => 'ActionOverview',
                Data => \%Param,
            );

            # store the dynamic fields default values or used specific default values to be used as
            # ACLs info for all fields
            my %DynamicFieldHTML;

            # cycle through the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                my $PossibleValuesFilter;

                # check if field has PossibleValues property in its configuration
                if ( IsHashRefWithData( $DynamicFieldConfig->{Config}->{PossibleValues} ) ) {

                    # set possible values filter from ACLs
                    my $ACL = $TicketObject->TicketAcl(
                        %GetParam,
                        %ACLCompatGetParam,
                        Action        => $Self->{Action},
                        ReturnType    => 'Ticket',
                        ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                        Data          => $DynamicFieldConfig->{Config}->{PossibleValues},
                        UserID        => $Self->{UserID},
                    );
                    if ($ACL) {
                        my %Filter = $TicketObject->TicketAclData();
                        $PossibleValuesFilter = \%Filter;
                    }
                }

                # to store dynamic field value from database (or undefined)
                my $Value = '';

                # get default value
                if ( defined $DynamicFieldConfig->{Config}->{DefaultValue} ) {
                    $Value = $DynamicFieldConfig->{Config}->{DefaultValue};
                }

                # get value from ticket template
                if ( $GetParam{ 'DynamicField_' . $DynamicFieldConfig->{Name} } ) {
                    $Value = $GetParam{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
                }

                # get field html
                $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }
                    = $BackendObject->EditFieldRender(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $PossibleValuesFilter,
                    Value                => $Value,
                    LayoutObject         => $LayoutObject,
                    ParamObject          => $ParamObject,
                    AJAXUpdate           => 1,
                    UpdatableFields      => $Self->_GetFieldsToUpdate(),
                    Mandatory => $Self->{Config}->{DynamicField}->{ $DynamicFieldConfig->{Name} }
                        == 2,
                    );
            }

            # set QueueID if empty selection
            $GetParam{QueueID} = '' if $GetParam{QueueID} eq '-';

            # get and format default subject and body
            my $Subject = $GetParam{Subject} || '';
            my $Body    = $GetParam{Body}    || '';

            # get services
            my $Services = $Self->_GetServices(
                %GetParam,
                CustomerUserID => $GetParam{CustomerUserID} || '',
                QueueID        => $GetParam{QueueID}        || 1,
            );
            my $SLAs = $Self->_GetSLAs(
                QueueID => $GetParam{QueueID} || 1,
                Services => $Services,
                %GetParam,
            );

            # html output
            $Output .= $Self->_MaskNew(
                Users => $Self->_GetUsers(
                    QueueID  => $GetParam{QueueID},
                    AllUsers => $GetParam{OwnerAll},
                ),
                ResponsibleUsers => $Self->_GetUsers(
                    QueueID  => $GetParam{QueueID},
                    AllUsers => $GetParam{ResponsibleAll},
                ),
                States => $Self->_GetNextStates(
                    %GetParam,
                    CustomerUserID => $GetParam{CustomerUserID} || '',
                    QueueID        => $GetParam{QueueID}        || 1,
                ),
                Priorities => $Self->_GetPriorities(
                    %GetParam,
                    CustomerUserID => $GetParam{CustomerUserID} || '',
                    QueueID        => $GetParam{QueueID}        || 1,
                ),
                Types => $Self->_GetTypes(
                    %GetParam,
                    CustomerUserID => $GetParam{CustomerUserID} || '',
                    QueueID        => $GetParam{QueueID}        || 1,
                ),
                Services         => $Services,
                SLAs             => $SLAs,
                CustomerID       => $LayoutObject->Ascii2Html( Text => $GetParam{CustomerID} ),
                FromList         => $Self->_GetTos(),
                Subject          => $LayoutObject->Ascii2Html( Text => $GetParam{Subject} ),
                Body             => $LayoutObject->Ascii2Html( Text => $GetParam{Body} ),
                Errors           => \%Error,
                DynamicFieldHTML => \%DynamicFieldHTML,
                UserGroups       => \@UserGroupIDs,
                %GetParam,
                FormID => $Param{FormID},
            );
            $Output .= $LayoutObject->Footer();
            return $Output;

        }
        if ( !$GetParam{ID} ) {
            $Param{ID} = $TicketObject->TicketTemplateCreate(
                Data   => \%GetParam,
                UserID => $Self->{UserID},
                Name   => $GetParam{Name},
            );
        }
        else {
            my $UpdateResult = $TicketObject->TicketTemplateUpdate(
                Data   => \%GetParam,
                ID     => $GetParam{ID},
                UserID => $Self->{UserID},
                Name   => $GetParam{Name},
            );
        }

        return $LayoutObject->Redirect(
            OP => "Action=AdminQuickTicketConfigurator;Subaction=Overview"
        );
    }

    # ------------------------------------------------------------------------ #
    # delete
    # ------------------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Delete' && $GetParam{ID} ) {

        my $DeleteResult = $TicketObject->TicketTemplateDelete(
            ID     => $GetParam{ID},
            UserID => $Self->{UserID},
        );

        if ($DeleteResult) {
            return $LayoutObject->Redirect(
                OP => "Action=AdminQuickTicketConfigurator;Subaction=Overview"
            );
        }
        else {
            return $LayoutObject->ErrorScreen();
        }
    }

    # ------------------------------------------------------------------------ #
    # AJAXUpdate
    # ------------------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {

        if ( $GetParam{QueueID} eq '-' ) {
            $GetParam{QueueID} = '';
        }

        if ( $ConfigObject->Get('Frontend::Agent::CreateOptions::ViewAllOwner') ) {
            $GetParam{OwnerAll}       = 1;
            $GetParam{ResponsibleAll} = 1;
        }

        if ( $GetParam{ElementChanged} eq 'ServiceID' && $GetParam{ServiceID} ) {

            # retrieve service data...
            my %ServiceData = $ServiceObject->ServiceGet(
                ServiceID => $GetParam{ServiceID} || '',
                UserID => 1,
            );

            if ( %ServiceData && $ServiceData{AssignedQueueID} ) {
                $GetParam{QueueID} = $ServiceData{AssignedQueueID};
            }
        }

        # get list type
        my $TreeView = 0;
        if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
            $TreeView = 1;
        }

        my $Tos = $Self->_GetTos(
            %GetParam,
            %ACLCompatGetParam,
            CustomerUserID => $GetParam{SelectedCustomerUser} || '',
            QueueID => $GetParam{QueueID} || 1,
        );

        my $NewTos;

        if ($Tos) {
            TOs:
            for my $KeyTo ( sort keys %{$Tos} ) {
                next TOs if ( $Tos->{$KeyTo} eq '-' );
                $NewTos->{"$KeyTo||$Tos->{$KeyTo}"} = $Tos->{$KeyTo};
            }
        }

        my $Users = $Self->_GetUsers(
            %GetParam,
            %ACLCompatGetParam,
            QueueID  => $GetParam{QueueID},
            AllUsers => $GetParam{OwnerAll},
        );
        my $ResponsibleUsers = $Self->_GetUsers(
            %GetParam,
            %ACLCompatGetParam,
            QueueID  => $GetParam{QueueID},
            AllUsers => $GetParam{ResponsibleAll},
        );

        my %NewTo;
        for my $QueueKey ( keys %{$Tos} ) {
            $NewTo{ $QueueKey . '||' . $Tos->{$QueueKey} } = $Tos->{$QueueKey};
        }

        my $Services = $Self->_GetServices(
            %GetParam,
            CustomerUserID => $GetParam{SelectedCustomerUser} || $GetParam{CustomerLogin} || '',
            QueueID => $GetParam{QueueID} || 1,
        );
        my $SLAs = $Self->_GetSLAs(
            %GetParam,
            CustomerUserID => $GetParam{SelectedCustomerUser} || $GetParam{CustomerLogin} || '',
            QueueID        => $GetParam{QueueID}              || 1,
            Services       => $Services,
        );

        # get possible link type directions
        my @LinkDirections;
        if ( $GetParam{LinkType} ) {

            # lookup link type id and get possible link directions
            my $LinkTypeID = $LinkObject->TypeLookup(
                Name   => $GetParam{LinkType},
                UserID => $Self->{UserID},
            );
            my %LinkType = $LinkObject->TypeGet(
                TypeID => $LinkTypeID,
                UserID => $Self->{UserID},
            );
            push( @LinkDirections, $LinkType{SourceName} );
            if ( $LinkType{SourceName} ne $LinkType{TargetName} ) {
                push( @LinkDirections, $LinkType{TargetName} );
            }
        }

        # update Dynamic Fields Possible Values via AJAX
        my @DynamicFieldAJAX;

        # cycle through the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $BackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );
            next DYNAMICFIELD if !$IsACLReducible;

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
                CustomerUserID => $GetParam{SelectedCustomerUser} || '',
                Action         => $Self->{Action},
                QueueID        => $GetParam{QueueID}              || 0,
                ReturnType     => 'Ticket',
                ReturnSubType  => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data           => \%AclData,
                UserID         => $Self->{UserID},
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
        }

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'QueueID',
                    Data         => $Tos,
                    SelectedID   => $GetParam{QueueID},
                    Translation  => 0,
                    PossibleNone => 1,
                    TreeView     => $TreeView,
                    Max          => 100,
                },
                {
                    Name         => 'OwnerID',
                    Data         => $Users,
                    SelectedID   => $GetParam{OwnerID},
                    Translation  => 0,
                    PossibleNone => 1,
                    Max          => 100,
                },
                {
                    Name         => 'ResponsibleID',
                    Data         => $ResponsibleUsers,
                    SelectedID   => $GetParam{ResponsibleID},
                    Translation  => 0,
                    PossibleNone => 1,
                    Max          => 100,
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
                    Name         => 'LinkDirection',
                    Data         => \@LinkDirections,
                    SelectedID   => $GetParam{LinkDirection},
                    PossibleNone => 1,
                    Translation  => 1,
                    Max          => 100,
                },
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

    # ------------------------------------------------------------------------ #
    # upload
    # ------------------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Upload' && $GetParam{FormID} ) {

        # init result...
        my %UploadResult = ();
        $Param{CountUploaded}     = 0;
        $Param{CountUpdateFailed} = 0;
        $Param{CountUpdated}      = 0;
        $Param{CountInsertFailed} = 0;
        $Param{CountAdded}        = 0;

        # get uploaded data...
        my %UploadStuff = $ParamObject->GetUploadAll(
            Param  => 'file_upload',
            Source => 'string',
        );

        my @FileList = $UploadCacheObject->FormIDGetAllFilesMeta(
            FormID => $Param{FormID},
        );

        if (%UploadStuff) {
            my $UploadFileName = $UploadStuff{Filename};

            #start the update process...
            if ( !$Param{UploadMessage} && $UploadStuff{Content} ) {

                %UploadResult = %{
                    $TicketObject->TicketTemplateImport(
                        Content  => $UploadStuff{Content},
                        DoNotAdd => $GetParam{XMLUploadDoNotAdd},
                        UserID   => $Self->{UserID},
                        )
                    };

                if ( $UploadResult{XMLResultString} ) {
                    my $DownloadFileName = $UploadFileName;
                    my $TimeString       = $TimeObject->SystemTime2TimeStamp(
                        SystemTime => $TimeObject->SystemTime(),
                    );
                    $TimeString       =~ s/\s/\_/g;
                    $DownloadFileName =~ s/\.(.*)$/_ImportResult_$TimeString\.xml/g;

                    my $FileID = $UploadCacheObject->FormIDAddFile(
                        FormID      => $Param{FormID},
                        Filename    => $DownloadFileName,
                        Content     => $UploadResult{XMLResultString},
                        ContentType => 'text/xml',

                    );
                    $Param{XMLResultFileID}   = $FileID;
                    $Param{XMLResultFileName} = $DownloadFileName;
                    $Param{XMLResultFileSize} = length( $UploadStuff{Content} );
                }
                if ( !$UploadResult{UploadMessage} ) {
                    $UploadResult{UploadMessage}
                        = $UploadStuff{Filename} . ' successful loaded.<br /><br />';
                }
            }
        }
        else {
            $Param{UploadMessage} = 'Import failed - No file uploaded/received. <br /><br />';
        }

        # output upload
        $LayoutObject->Block(
            Name => 'Upload',
            Data => {
                %Param,
                }
        );

        # output overview list
        $LayoutObject->Block(
            Name => 'UploadResult',
            Data => { %GetParam, %Param, %UploadResult },
        );
    }

    # ------------------------------------------------------------ #
    # DownloadResult
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'DownloadResult' && $GetParam{XMLResultFileID} ) {
        my @Data = $UploadCacheObject->FormIDGetAllFilesData(
            FormID => $GetParam{FormID},
        );
        for my $Entry (@Data) {
            if ( $Entry->{FileID} eq $GetParam{XMLResultFileID} ) {
                return $LayoutObject->Attachment(
                    Type        => 'attachment',
                    Filename    => $Entry->{Filename},
                    ContentType => $Entry->{ContentType},
                    Content     => $Entry->{Content},
                    NoCache     => 1,
                );
            }
        }
    }

    # ------------------------------------------------------------ #
    # download
    # ------------------------------------------------------------ #

    elsif ( $Self->{Subaction} eq 'Download' ) {
        my $Content     = $TicketObject->TicketTemplateExport();
        my $ContentType = 'application/xml';
        my $FileType    = 'xml';

        my $TimeString = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $TimeObject->SystemTime(),
        );
        $TimeString =~ s/\s/\_/g;
        my $FileName = 'TicketTemplates_' . $TimeString . '.' . $FileType;

        return $LayoutObject->Attachment(
            Type        => 'attachment',
            Filename    => $FileName,
            ContentType => $ContentType,
            Content     => $Content,
            NoCache     => 1,
        );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #

    # output header
    $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    my @Templates = $TicketObject->TicketTemplateList(
        Result => 'Name',
    );
    my %TicketTemplateData;
    for my $Template (@Templates)
    {
        my %Hash = $TicketObject->TicketTemplateGet(
            Name => $Template,
        );
        $TicketTemplateData{$Template} = \%Hash;
    }

    # output add
    $LayoutObject->Block(
        Name => 'ActionAdd',
        Data => \%Param,
    );

    # output migrate
    if ( $Self->{Config}->{MigrateButton} ) {
        $LayoutObject->Block(
            Name => 'ActionMigrate',
            Data => \%Param,
        );
    }

    # output download area
    $LayoutObject->Block(
        Name => 'Download',
        Data => \%Param,
    );

    #  output upload area
    if ( $Self->{Subaction} ne 'Upload' ) {
        $LayoutObject->Block(
            Name => 'Upload',
            Data => \%Param,
        );
    }

    # output hint
    $LayoutObject->Block(
        Name => 'Hint',
        Data => \%Param,
    );

    $Param{Count} = scalar keys %TicketTemplateData;
    $Param{CountNote} =
        ( $GetParam{Limit} && $Param{Count} == $GetParam{Limit} ) ? '(limited)' : '';

    $LayoutObject->Block(
        Name => 'OverviewList',
        Data => \%Param,
    );

    if ( $Param{Count} ) {
        for my $CurrHashID (
            sort { $TicketTemplateData{$a}->{Name} cmp $TicketTemplateData{$b}->{Name} }
            keys %TicketTemplateData
            )
        {

            # create Frontend-Info-String
            my @FrontendInfoArray;
            push( @FrontendInfoArray, 'A' ) if ( $TicketTemplateData{$CurrHashID}->{Agent} );
            push( @FrontendInfoArray, 'C' ) if ( $TicketTemplateData{$CurrHashID}->{Customer} );
            $TicketTemplateData{$CurrHashID}->{FrontendInfoStrg}
                = join( '/', @FrontendInfoArray );

            $LayoutObject->Block(
                Name => 'OverviewListRow',
                Data => {
                    %{ $TicketTemplateData{$CurrHashID} },
                    }
            );
        }
    }
    else {
        $LayoutObject->Block( Name => 'OverviewListEmpty' );
    }

    if ( $Self->{Subaction} eq 'MigrationComplete' ) {

        # notify info
        $Output .= $LayoutObject->Notify(
            Info => 'Ticket template migration successful',
        );
    }

    # generate output
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminQuickTicketConfigurator',
        Data         => \%Param,
    );
    $Output .= $LayoutObject->Footer();

    return $Output;
}

sub _GetNextStates {
    my ( $Self, %Param ) = @_;

    my %NextStates;
    if ( $Param{QueueID} ) {
        %NextStates = $Kernel::OM->Get('Kernel::System::Ticket')->TicketStateList(
            %Param,
            Action => $Self->{Action},
            UserID => $Self->{UserID},
        );
    }
    return \%NextStates;
}

sub _GetUsers {
    my ( $Self, %Param ) = @_;

    # get users
    my %ShownUsers;
    my %AllGroupsMembers = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type  => 'Long',
        Valid => 1,
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # just show only users with selected custom queue
    if ( $Param{QueueID} && !$Param{AllUsers} ) {
        my @UserIDs = $TicketObject->GetSubscribedUserIDsByQueueID(%Param);
        for my $GroupMemberKey ( sort keys %AllGroupsMembers ) {
            my $Hit = 0;
            for my $UID (@UserIDs) {
                if ( $UID eq $GroupMemberKey ) {
                    $Hit = 1;
                }
            }
            if ( !$Hit ) {
                delete $AllGroupsMembers{$GroupMemberKey};
            }
        }
    }

    # check show users
    if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ChangeOwnerToEveryone') ) {
        %ShownUsers = %AllGroupsMembers;
    }

    # show all users who are owner or rw in the queue group
    elsif ( $Param{QueueID} ) {
        my $GID = $Kernel::OM->Get('Kernel::System::Queue')->GetQueueGroupID( QueueID => $Param{QueueID} );
        my %MemberList = $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupGet(
            GroupID => $GID,
            Type    => 'owner',
        );
        for my $MemberKey ( sort keys %MemberList ) {
            if ( $AllGroupsMembers{$MemberKey} ) {
                $ShownUsers{$MemberKey} = $AllGroupsMembers{$MemberKey};
            }
        }
    }

    # workflow
    my $ACL = $TicketObject->TicketAcl(
        %Param,
        ReturnType    => 'Ticket',
        ReturnSubType => 'Owner',
        Data          => \%ShownUsers,
        UserID        => $Self->{UserID},
    );

    return { $TicketObject->TicketAclData() } if $ACL;

    return \%ShownUsers;
}

sub _GetResponsibles {
    my ( $Self, %Param ) = @_;

    # get users
    my %ShownUsers;
    my %AllGroupsMembers = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type  => 'Long',
        Valid => 1,
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # just show only users with selected custom queue
    if ( $Param{QueueID} && !$Param{AllUsers} ) {
        my @UserIDs = $TicketObject->GetSubscribedUserIDsByQueueID(%Param);
        for my $GroupMemberKey ( sort keys %AllGroupsMembers ) {
            my $Hit = 0;
            for my $UID (@UserIDs) {
                if ( $UID eq $GroupMemberKey ) {
                    $Hit = 1;
                }
            }
            if ( !$Hit ) {
                delete $AllGroupsMembers{$GroupMemberKey};
            }
        }
    }

    # check show users
    if ( $Kernel::OM->Get('Kernel::Config')->Get('Ticket::ChangeOwnerToEveryone') ) {
        %ShownUsers = %AllGroupsMembers;
    }

    # show all users who are responsible or rw in the queue group
    elsif ( $Param{QueueID} ) {
        my $GID = $Kernel::OM->Get('Kernel::System::Queue')->GetQueueGroupID( QueueID => $Param{QueueID} );
        my %MemberList = $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupGet(
            GroupID => $GID,
            Type    => 'responsible',
        );
        for my $MemberKey ( sort keys %MemberList ) {
            if ( $AllGroupsMembers{$MemberKey} ) {
                $ShownUsers{$MemberKey} = $AllGroupsMembers{$MemberKey};
            }
        }
    }

    # workflow
    my $ACL = $TicketObject->TicketAcl(
        %Param,
        ReturnType    => 'Ticket',
        ReturnSubType => 'Responsible',
        Data          => \%ShownUsers,
        UserID        => $Self->{UserID},
    );

    return { $TicketObject->TicketAclData() } if $ACL;

    return \%ShownUsers;
}

sub _GetPriorities {
    my ( $Self, %Param ) = @_;

    # get priority
    my %Priorities;
    if ( $Param{QueueID} ) {
        %Priorities = $Kernel::OM->Get('Kernel::System::Ticket')->TicketPriorityList(
            %Param,
            Action => $Self->{Action},
            UserID => $Self->{UserID},
        );
    }
    return \%Priorities;
}

sub _GetTypes {
    my ( $Self, %Param ) = @_;

    # get type
    my %Type;
    if ( $Param{QueueID} ) {
        %Type = $Kernel::OM->Get('Kernel::System::Ticket')->TicketTypeList(
            %Param,
            Action => $Self->{Action},
            UserID => $Self->{UserID},
        );
    }
    return \%Type;
}

sub _GetServices {
    my ( $Self, %Param ) = @_;

    # get service
    my %Service;

    # check needed
    return \%Service if !$Param{QueueID};

    # get options for default services for unknown customers
    my $DefaultServiceUnknownCustomer
        = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Service::Default::UnknownCustomer');

    # check if no CustomerUserID is selected
    # if $DefaultServiceUnknownCustomer = 0 leave CustomerUserID empty, it will not get any services
    # if $DefaultServiceUnknownCustomer = 1 set CustomerUserID to get default services
    if ( !$Param{CustomerUserID} && $DefaultServiceUnknownCustomer ) {
        $Param{CustomerUserID} = '<DEFAULT>';
    }

    # get service list
    if ( $Param{CustomerUserID} || $DefaultServiceUnknownCustomer ) {
        %Service = $Kernel::OM->Get('Kernel::System::Ticket')->TicketServiceList(
            %Param,
            Action => $Self->{Action},
            UserID => $Self->{UserID},
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
                Action => $Self->{Action},
                UserID => $Self->{UserID},
            );
        }
    }
    return \%SLA;
}

sub _GetTos {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check own selection
    my %NewTos;
    if ( $ConfigObject->Get('Ticket::Frontend::NewQueueOwnSelection') ) {
        %NewTos = %{ $ConfigObject->Get('Ticket::Frontend::NewQueueOwnSelection') };
    }
    else {

        # SelectionType Queue or SystemAddress?
        my %Tos;
        if ( $ConfigObject->Get('Ticket::Frontend::NewQueueSelectionType') eq 'Queue' ) {
            %Tos = $Kernel::OM->Get('Kernel::System::Ticket')->MoveList(
                %Param,
                Type    => 'create',
                Action  => $Self->{Action},
                UserID  => 1,
                QueueID => $Param{QueueID},
                TypeID  => $Param{TypeID},
            );
        }
        else {
            %Tos = $Kernel::OM->Get('Kernel::System::DB')->GetTableData(
                Table => 'system_address',
                What  => 'queue_id, id',
                Valid => 1,
                Clamp => 1,
            );
        }

        # get create permission queues
        my %UserGroups = $Kernel::OM->Get('Kernel::System::Group')->PermissionUserGet(
            UserID => $Self->{UserID},
            Type   => 'create',
        );

        # build selection string
        QUEUEID:
        for my $QueueID ( sort keys %Tos ) {
            my %QueueData = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet( ID => $QueueID );

            # permission check, can we create new tickets in queue
            next QUEUEID if !$UserGroups{ $QueueData{GroupID} };

            my $String = $ConfigObject->Get('Ticket::Frontend::NewQueueSelectionString')
                || '<Realname> <<Email>> - Queue: <Queue>';
            $String =~ s/<Queue>/$QueueData{Name}/g;
            $String =~ s/<QueueComment>/$QueueData{Comment}/g;
            if ( $ConfigObject->Get('Ticket::Frontend::NewQueueSelectionType') ne 'Queue' )
            {
                my %SystemAddressData = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
                    ID => $Tos{$QueueID},
                );
                $String =~ s/<Realname>/$SystemAddressData{Realname}/g;
                $String =~ s/<Email>/$SystemAddressData{Name}/g;
            }
            $NewTos{$QueueID} = $String;
        }
    }

    # add empty selection
    $NewTos{''} = '-';
    return \%NewTos;
}

sub _MaskNew {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
    my $LinkObject   = $Kernel::OM->Get('Kernel::System::LinkObject');

    my @Templates = $TicketObject->TicketTemplateList(
        Result => 'Name',
    );

    # get fixed values
    for my $Fixed (qw(TypeID QueueID ServiceID SLAID StateID PriorityID)) {
        if ( defined $Param{ $Fixed . 'Fixed' } && $Param{ $Fixed . 'Fixed' } ) {
            $Param{ $Fixed . 'FixedClass' } = "Fixed";
        }
        else {
            $Param{ $Fixed . 'Fixed' }      = 0;
            $Param{ $Fixed . 'FixedClass' } = "NotFixed";
        }
    }

    # get list type
    my $TreeView = 0;
    if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
        $TreeView = 1;
    }

    # build customer search autocomplete field
    my $AutoCompleteConfig
        = $ConfigObject->Get('Ticket::Frontend::CustomerSearchAutoComplete');
    $LayoutObject->Block(
        Name => 'CustomerSearchAutoComplete',
        Data => {
            ActiveAutoComplete  => $AutoCompleteConfig->{Active},
            minQueryLength      => $AutoCompleteConfig->{MinQueryLength} || 2,
            queryDelay          => $AutoCompleteConfig->{QueryDelay} || 100,
            maxResultsDisplayed => $AutoCompleteConfig->{MaxResultsDisplayed} || 20,
        },
    );

    # build user group selection string
    my %UserGroups = $GroupObject->GroupList( Valid => 1 );
    $Param{UserGroupStrg} = $LayoutObject->BuildSelection(
        Data        => \%UserGroups,
        SelectedID  => $Param{UserGroups},
        Translation => 0,
        Name        => 'UserGroupID',
        Multiple    => 1,
        Class       => 'Modernize',
    );

    # build owner selection string
    $Param{OwnerStrg} = $LayoutObject->BuildSelection(
        Data         => $Param{Users},
        SelectedID   => $Param{OwnerID},
        Translation  => 0,
        Name         => 'OwnerID',
        PossibleNone => 1,
        Class        => 'Modernize',
    );
    if ( $Param{OwnerIDEmpty} ) {
        $Param{OwnerIDEmpty} = 'checked="checked"';
    }

    # build next states string
    $Param{StatesStrg} = $LayoutObject->BuildSelection(
        Data         => $Param{NextStates},
        Name         => 'StateID',
        Translation  => 1,
        SelectedID   => $Param{StateID},
        PossibleNone => 1,
        Class        => 'Modernize',
    );
    if ( $Param{StateIDEmpty} ) {
        $Param{StateIDEmpty} = 'checked="checked"';
    }

    # build to string
    $Param{FromList}->{'-'} = '-';
    $Param{QueueStrg} = $LayoutObject->AgentQueueListOption(
        Class          => 'Modernize',
        Data           => $Param{FromList},
        Multiple       => 0,
        Size           => 0,
        Name           => 'QueueID',
        SelectedID     => $Param{QueueID},
        Translation    => 0,
        OnChangeSubmit => 0,
        TreeView       => $TreeView,
    );
    if ( $Param{QueueIDEmpty} ) {
        $Param{QueueIDEmpty} = 'checked="checked"';
    }

    # build priority string
    $Param{PriorityStrg} = $LayoutObject->BuildSelection(
        Data         => $Param{Priorities},
        Name         => 'PriorityID',
        SelectedID   => $Param{PriorityID},
        Translation  => 1,
        PossibleNone => 1,
        Class        => 'Modernize',
    );
    if ( $Param{PriorityIDEmpty} ) {
        $Param{PriorityIDEmpty} = 'checked="checked"';
    }

    # prepare errors!
    if ( $Param{Errors} ) {
        for my $KeyError ( keys %{ $Param{Errors} } ) {
            $Param{$KeyError}
                = '* '
                . $LayoutObject->Ascii2Html( Text => $Param{Errors}->{$KeyError} );
        }
    }

    # display server error msg according with the occurred email (from) error type
    if ( $Param{Errors} && $Param{Errors}->{ErrorType} ) {
        $LayoutObject->Block( Name => 'Email' . $Param{Errors}->{ErrorType} );
    }
    else {
        $LayoutObject->Block( Name => 'GenericServerErrorMsg' );
    }

    $LayoutObject->Block(
        Name => 'Edit',
        Data => {
            %Param,
        },
    );

    my $DynamicFieldNames = $Self->_GetFieldsToUpdate(
        OnlyDynamicFields => 1
    );

    # create a string with the quoted dynamic field names separated by commas
    if ( IsArrayRefWithData($DynamicFieldNames) ) {
        for my $Field ( @{$DynamicFieldNames} ) {
            $Param{DynamicFieldNamesStrg} .= ", '" . $Field . "'";
        }
    }

    # build type string
    if ( $ConfigObject->Get('Ticket::Type') ) {
        $Param{TypeStrg} = $LayoutObject->BuildSelection(
            Data         => $Param{Types},
            Name         => 'TypeID',
            Class        => 'Validate_Required Modernize ' . ( $Param{Errors}->{TypeInvalid} || ' ' ),
            SelectedID   => $Param{TypeID},
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 0,
        );
        if ( $Param{TypeIDEmpty} ) {
            $Param{TypeIDEmpty} = 'checked="checked"';
        }
        $LayoutObject->Block(
            Name => 'TicketType',
            Data => {%Param},
        );
    }

    # build service string
    if ( $ConfigObject->Get('Ticket::Service') ) {
        $Param{ServiceStrg} = $LayoutObject->BuildSelection(
            Data         => $Param{Services},
            Name         => 'ServiceID',
            Class        => 'Modernize ' . ( $Param{Errors}->{ServiceInvalid} || ' ' ),
            SelectedID   => $Param{ServiceID},
            PossibleNone => 1,
            TreeView     => $TreeView,
            Sort         => 'TreeView',
            Translation  => 0,
            Max          => 200,
        );
        if ( $Param{ServiceIDEmpty} ) {
            $Param{ServiceIDEmpty} = 'checked="checked"';
        }
        $LayoutObject->Block(
            Name => 'TicketService',
            Data => {%Param},
        );
        $Param{SLAStrg} = $LayoutObject->BuildSelection(
            Data         => $Param{SLAs},
            Name         => 'SLAID',
            SelectedID   => $Param{SLAID},
            Class        => 'Modernize',
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 0,
            Max          => 200,
        );
        if ( $Param{SLAIDEmpty} ) {
            $Param{SLAIDEmpty} = 'checked="checked"';
        }
        $LayoutObject->Block(
            Name => 'TicketSLA',
            Data => {%Param},
        );
    }

    # show responsible selection
    if (
        $ConfigObject->Get('Ticket::Responsible')
        && $ConfigObject->Get('Ticket::Frontend::NewResponsibleSelection')
        )
    {
        $Param{ResponsibleUsers}->{''} = '-';
        $Param{ResponsibleStrg} = $LayoutObject->BuildSelection(
            Data       => $Param{ResponsibleUsers},
            SelectedID => $Param{ResponsibleID},
            Name       => 'ResponsibleID',
            Class      => 'Modernize',
        );
        if ( $Param{ResponsibleIDEmpty} ) {
            $Param{ResponsibleIDEmpty} = 'checked="checked"';
        }
        $LayoutObject->Block(
            Name => 'Responsible',
            Data => \%Param,
        );
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

        # get parameters for fixed values
        my $DynamicFieldFixedClass = "NotFixed";
        if ( $Param{ 'DynamicField_' . $DynamicFieldConfig->{Name} . 'Fixed' } ) {
            $DynamicFieldFixedClass = 'Fixed';
        }
        else {
            $Param{ 'DynamicField_' . $DynamicFieldConfig->{Name} . 'Fixed' } = 0;
        }
        my $Pin
            = '<i class="fa fa-thumb-tack LimitTemplateSelectionIcon_'
            . $DynamicFieldFixedClass
            . '"></i><input type="hidden" id="DynamicField_'
            . $DynamicFieldConfig->{Name}
            . 'Fixed" name="DynamicField_'
            . $DynamicFieldConfig->{Name}
            . 'Fixed" value="'
            . $Param{ 'DynamicField_' . $DynamicFieldConfig->{Name} . 'Fixed' }
            . '"/>';
        $DynamicFieldHTML->{Label} =~ s/(<label(.*?)>)/$1$Pin/gi;

        $LayoutObject->Block(
            Name => 'DynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );

        # get dynamic fields of type dropdown which could be empty
        if (
            (
                defined $DynamicFieldConfig->{Config}->{DisplayFieldType}
                && $DynamicFieldConfig->{Config}->{DisplayFieldType} !~ m/(Dropdown)/i
            )
            || $DynamicFieldConfig->{FieldType} !~ m/(Dropdown)/i
            || $DynamicFieldConfig->{Config}->{PossibleNone}
            )
        {
            my $Checked;
            if ( $Param{ 'DynamicField_' . $DynamicFieldConfig->{Name} . 'Empty' } ) {
                $Checked = 'checked="checked"';
            }
            $LayoutObject->Block(
                Name => 'DynamicFieldEmpty',
                Data => {
                    Checked => $Checked,
                    %{$DynamicFieldConfig},
                },
            );
        }

    }

    # show time accounting box
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        $LayoutObject->Block(
            Name => 'TimeUnits',
            Data => \%Param,
        );
        if ( $Param{TimeUnitsEmpty} ) {
            $Param{TimeUnitsEmpty} = 'checked="checked"';
        }
    }

    # build article type selection
    if ( defined $Self->{Config}->{ArticleType} && $Self->{Config}->{ArticleType} ) {
        my %ArticleTypes = $TicketObject->ArticleTypeList(
            Result => 'HASH',
        );
        for my $ArticleTypeID ( keys %ArticleTypes ) {
            my $ArticleType = $ArticleTypes{$ArticleTypeID};
            next if $Self->{Config}->{ArticleType}->{$ArticleType};
            delete $ArticleTypes{$ArticleTypeID};
        }
        $Param{ArticleTypeStrg} = $LayoutObject->BuildSelection(
            Data         => \%ArticleTypes,
            Name         => 'ArticleType',
            Class        => 'Modernize',
            SelectedID   => $Param{ArticleType},
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 1,
            Max          => 200,
        );
        $LayoutObject->Block(
            Name => 'ArticleType',
            Data => {%Param},
        );
    }

    # build article sender type selection
    if ( defined $Self->{Config}->{ArticleSenderType} && $Self->{Config}->{ArticleSenderType} ) {
        my %ArticleSenderTypes = $TicketObject->ArticleSenderTypeList(
            Result => 'HASH',
        );
        for my $ArticleSenderTypeID ( keys %ArticleSenderTypes ) {
            my $ArticleSenderType = $ArticleSenderTypes{$ArticleSenderTypeID};
            next if $Self->{Config}->{ArticleSenderType}->{$ArticleSenderType};
            delete $ArticleSenderTypes{$ArticleSenderTypeID};
        }
        $Param{ArticleSenderTypeStrg} = $LayoutObject->BuildSelection(
            Data         => \%ArticleSenderTypes,
            Name         => 'ArticleSenderType',
            Class        => 'Modernize',
            SelectedID   => $Param{ArticleSenderType},
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 1,
            Max          => 200,
        );
        $LayoutObject->Block(
            Name => 'ArticleSenderType',
            Data => {%Param},
        );
    }

    # build link type selection
    if ( defined $Self->{Config}->{LinkType} && $Self->{Config}->{LinkType} ) {
        my %LinkTypeHash = $LinkObject->PossibleTypesList(
            Object1 => 'Ticket',
            Object2 => 'Ticket',
            UserID  => $Self->{UserID},
        );
        for my $LinkType ( keys %LinkTypeHash ) {
            next if $Self->{Config}->{LinkType}->{$LinkType};
            delete $LinkTypeHash{$LinkType};
        }
        my @LinkTypes = keys %LinkTypeHash;

        $Param{LinkTypeStrg} = $LayoutObject->BuildSelection(
            Data         => \@LinkTypes,
            Name         => 'LinkType',
            Class        => 'Modernize',
            SelectedID   => $Param{LinkType},
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 1,
            Max          => 200,
        );

        $LayoutObject->Block(
            Name => 'LinkType',
            Data => {%Param},
        );
    }

    # build link direction selection
    if ( defined $Self->{Config}->{LinkDirection} && $Self->{Config}->{LinkDirection} ) {
        my @LinkDirections;

        # lookup link type id and get possible link directions
        if ( $Param{LinkType} ) {
            my $LinkTypeID = $LinkObject->TypeLookup(
                Name   => $Param{LinkType},
                UserID => $Self->{UserID},
            );
            my %LinkType = $LinkObject->TypeGet(
                TypeID => $LinkTypeID,
                UserID => $Self->{UserID},
            );
            push( @LinkDirections, $LinkType{SourceName} );
            if ( $LinkType{SourceName} ne $LinkType{TargetName} ) {
                push( @LinkDirections, $LinkType{TargetName} );
            }
        }

        $Param{LinkDirectionStrg} = $LayoutObject->BuildSelection(
            Data         => \@LinkDirections,
            Name         => 'LinkDirection',
            Class        => 'Modernize',
            SelectedID   => $Param{LinkDirection},
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 1,
            Max          => 200,
        );

        $LayoutObject->Block(
            Name => 'LinkDirection',
            Data => {%Param},
        );
    }

    # add rich text editor
    if ( $LayoutObject->{BrowserRichText} ) {

        # use height/width defined for this screen
        $Param{RichTextHeight} = $Self->{Config}->{RichTextHeight} || 0;
        $Param{RichTextWidth}  = $Self->{Config}->{RichTextWidth}  || 0;

        $LayoutObject->Block(
            Name => 'RichText',
            Data => \%Param,
        );
    }

    # add textarea for KIXSidebarChecklist
    $LayoutObject->Block(
        Name => 'KIXSidebarChecklist',
        Data => {%Param},
    );

    my $HeaderTitle = 'Create/Change quickticket templates';

    $LayoutObject->Block(
        Name => 'MaskHeader',
        Data => {
            Text => $HeaderTitle,
        },
    );

    # get output back
    return $LayoutObject->Output(
        TemplateFile => 'AdminQuickTicketConfigurator',
        Data         => {
            %Param,
            DefaultSet => $Self->{DefaultSet} || '',
        },
    );
}

sub _GetFieldsToUpdate {
    my ( $Self, %Param ) = @_;

    my @UpdatableFields;

    # set the fields that can be updateable via AJAXUpdate
    if ( !$Param{OnlyDynamicFields} ) {
        @UpdatableFields
            = qw( TypeID Dest ServiceID SLAID OwnerID ResponsibleID NextStateID PriorityID );
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

1;
