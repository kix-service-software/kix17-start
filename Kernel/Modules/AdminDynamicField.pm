# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDynamicField;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);
use Kernel::System::CheckItem;

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    if ( $Self->{Subaction} eq 'DynamicFieldDelete' ) {

        # challenge token check for write action
        $Kernel::OM->Get('Kernel::Output::HTML::Layout')->ChallengeTokenCheck();

        return $Self->_DynamicFieldDelete(
            %Param,
        );
    }

    elsif ( $Self->{Subaction} eq 'DynamicFieldImport' ) {
        my $DynamicFieldImport = $Self->_DynamicFieldImport(
            %Param,
        );

        if ( !$DynamicFieldImport->{Success} ) {
            my $Message = $DynamicFieldImport->{Message}
                || Translatable('DynamicFields could not be imported due to a unknown error, please check KIX logs for more information.');

            return $Kernel::OM->Get('Kernel::Output::HTML::Layout')->ErrorScreen(
                Message => $Message,
            );
        }
    }

    elsif ( $Self->{Subaction} eq 'DynamicFieldExport' ) {
        return $Self->_DynamicFieldExport(
            %Param,
        );
    }

    return $Self->_ShowOverview(
        %Param,
        Action => 'Overview',
    );
}

# AJAX sub-action
sub _DynamicFieldDelete {
    my ( $Self, %Param ) = @_;

    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LogObject   = $Kernel::OM->Get('Kernel::System::Log');

    my $Confirmed = $ParamObject->GetParam( Param => 'Confirmed' );

    if ( !$Confirmed ) {
        $LogObject->Log(
            'Priority' => 'error',
            'Message'  => "Need 'Confirmed'!",
        );
        return;
    }

    my $ID = $ParamObject->GetParam( Param => 'ID' );

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
        ID => $ID,
    );

    if ( !IsHashRefWithData($DynamicFieldConfig) ) {
        $LogObject->Log(
            'Priority' => 'error',
            'Message'  => "Could not find DynamicField $ID!",
        );
        return;
    }

    if ( $DynamicFieldConfig->{InternalField} ) {
        $LogObject->Log(
            'Priority' => 'error',
            'Message'  => "Could not delete internal DynamicField $ID!",
        );
        return;
    }

    my $ValuesDeleteSuccess = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->AllValuesDelete(
        DynamicFieldConfig => $DynamicFieldConfig,
        UserID             => $Self->{UserID},
    );

    my $Success;

    if ($ValuesDeleteSuccess) {
        $Success = $DynamicFieldObject->DynamicFieldDelete(
            ID     => $ID,
            UserID => $Self->{UserID},
        );
    }

    return $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Attachment(
        ContentType => 'text/html',
        Content     => $Success,
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _ShowOverview {
    my ( $Self, %Param ) = @_;

    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $FieldTypeConfig    = $ConfigObject->Get('DynamicFields::Driver');

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    # check for possible order collisions or gaps
    my $OrderSuccess = $DynamicFieldObject->DynamicFieldOrderCheck();
    if ( !$OrderSuccess ) {
        return $Self->_DynamicFieldOrderReset(
            %Param,
        );
    }

    # call all needed template blocks
    $LayoutObject->Block(
        Name => 'Main',
        Data => \%Param,
    );

    my %FieldTypes;
    my %FieldDialogs;

    if ( !IsHashRefWithData($FieldTypeConfig) ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Fields configuration is not valid'),
        );
    }

    # get the field types (backends) and its config dialogs
    FIELDTYPE:
    for my $FieldType ( sort keys %{$FieldTypeConfig} ) {

        next FIELDTYPE if !$FieldTypeConfig->{$FieldType};
        next FIELDTYPE if $FieldTypeConfig->{$FieldType}->{DisabledAdd};

        my $Key = $FieldType;
        if ( $FieldTypeConfig->{$FieldType}->{ConfigDialog} eq 'AdminDynamicFieldObjectReference' ) {
            $Key = 'ObjectReference';
        }

        # add the field type to the list
        $FieldTypes{$Key} = $FieldTypeConfig->{$FieldType}->{DisplayName};

        # get the config dialog
        $FieldDialogs{$Key} = $FieldTypeConfig->{$FieldType}->{ConfigDialog};
    }

    my $ObjectTypeConfig = $ConfigObject->Get('DynamicFields::ObjectType');

    if ( !IsHashRefWithData($ObjectTypeConfig) ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable('Objects configuration is not valid'),
        );
    }

    # make ObjectTypeConfig local variable to proper sorting
    my %ObjectTypeConfig = %{$ObjectTypeConfig};

    # cycle thought all objects to create the select add field selects
    OBJECTTYPE:
    for my $ObjectType (
        sort {
            ( int $ObjectTypeConfig{$a}->{Prio} || 0 )
                <=> ( int $ObjectTypeConfig{$b}->{Prio} || 0 )
        } keys %ObjectTypeConfig
    ) {
        next OBJECTTYPE if !$ObjectTypeConfig->{$ObjectType};

        my $SelectName = $ObjectType . 'DynamicField';

        # create the Add Dynamic Field select
        my $AddDynamicFieldStrg = $LayoutObject->BuildSelection(
            Data          => \%FieldTypes,
            Name          => $SelectName,
            PossibleNone  => 1,
            Translation   => 1,
            Sort          => 'AlphanumericValue',
            SelectedValue => '-',
            Class         => 'Modernize W75pc',
        );

        # call ActionAddDynamicField block
        $LayoutObject->Block(
            Name => 'ActionAddDynamicField',
            Data => {
                %Param,
                AddDynamicFieldStrg => $AddDynamicFieldStrg,
                ObjectType          => $ObjectType,
                SelectName          => $SelectName,
            },
        );
    }

    # parse the fields dialogs as JSON structure
    my $FieldDialogsConfig = $LayoutObject->JSONEncode(
        Data => \%FieldDialogs,
    );

    # set JS configuration
    $LayoutObject->Block(
        Name => 'ConfigSet',
        Data => {
            FieldDialogsConfig => $FieldDialogsConfig,
        },
    );

    # call hint block
    $LayoutObject->Block(
        Name => 'Hint',
        Data => \%Param,
    );

    # get dynamic fields list
    my $DynamicFieldsList = $DynamicFieldObject->DynamicFieldList(
        Valid => 0,
    );

    # print the list of dynamic fields
    $Self->_DynamicFieldsListShow(
        DynamicFields => $DynamicFieldsList,
        Total         => scalar @{$DynamicFieldsList},
    );

    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminDynamicField',
        Data         => {
            %Param,
        },
    );

    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _DynamicFieldsListShow {
    my ( $Self, %Param ) = @_;

    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $FieldTypeConfig = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Driver');

    # check start option, if higher than fields available, set
    # it to the last field page
    my $StartHit = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'StartHit' ) || 1;

    # get personal page shown count
    my $PageShownPreferencesKey = 'AdminDynamicFieldsOverviewPageShown';
    my $PageShown               = $Self->{$PageShownPreferencesKey} || 35;
    my $Group                   = 'DynamicFieldsOverviewPageShown';

    # get data selection
    my %Data;
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get('PreferencesGroups');
    if ( $Config && $Config->{$Group} && $Config->{$Group}->{Data} ) {
        %Data = %{ $Config->{$Group}->{Data} };
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
        Link      => $Param{LinkPage},
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
        Sort        => 'NumericValue',
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

    # check if at least 1 dynamic field is registered in the system
    if ( $Param{Total} ) {

        # get dynamic fields details
        my $Counter = 0;

        DYNAMICFIELDID:
        for my $DynamicFieldID ( @{ $Param{DynamicFields} } ) {
            $Counter++;
            if ( $Counter >= $StartHit && $Counter < ( $PageShown + $StartHit ) ) {

                my $DynamicFieldData = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
                    ID => $DynamicFieldID,
                );
                next DYNAMICFIELDID if !IsHashRefWithData($DynamicFieldData);

                # convert ValidID to Validity string
                my $Valid = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
                    ValidID => $DynamicFieldData->{ValidID},
                );

                # get the object type display name
                my $ObjectTypeName = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::ObjectType')
                    ->{ $DynamicFieldData->{ObjectType} }->{DisplayName}
                    || $DynamicFieldData->{ObjectType};

                # get the field type display name
                my $FieldTypeName = $FieldTypeConfig->{ $DynamicFieldData->{FieldType} }->{DisplayName}
                    || $DynamicFieldData->{FieldType};

                # get the field backend dialog
                my $ConfigDialog = $FieldTypeConfig->{ $DynamicFieldData->{FieldType} }->{ConfigDialog}
                    || '';

                # print each dynamic field row
                $LayoutObject->Block(
                    Name => 'DynamicFieldsRow',
                    Data => {
                        %{$DynamicFieldData},
                        Valid          => $Valid,
                        ConfigDialog   => $ConfigDialog,
                        FieldTypeName  => $FieldTypeName,
                        ObjectTypeName => $ObjectTypeName,
                    },
                );

                # Internal fields can not be deleted.
                if ( !$DynamicFieldData->{InternalField} ) {
                    $LayoutObject->Block(
                        Name => 'DeleteLink',
                        Data => {
                            %{$DynamicFieldData},
                            Valid          => $Valid,
                            ConfigDialog   => $ConfigDialog,
                            FieldTypeName  => $FieldTypeName,
                            ObjectTypeName => $ObjectTypeName,
                        },
                    );
                }
            }
        }
    }

    # otherwise show a no data found message
    else {
        $LayoutObject->Block(
            Name => 'NoDataFound',
            Data => \%Param,
        );
    }

    $LayoutObject->Block(
        Name => 'MaxFieldOrder',
        Data => {
            MaxFieldOrder => scalar( @{ $Param{DynamicFields} } ),
        },
    );

    return;
}

sub _DynamicFieldOrderReset {
    my ( $Self, %Param ) = @_;

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ResetSuccess = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldOrderReset();

    # show error message if the order reset was not successful
    if ( !$ResetSuccess ) {
        return $LayoutObject->ErrorScreen(
            Message => Translatable(
                'Could not reset Dynamic Field order properly, please check the error log for more details.'
            ),
        );
    }

    # redirect to main screen
    return $LayoutObject->Redirect(
        OP => "Action=AdminDynamicField",
    );
}

sub _DynamicFieldImport {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject   = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $SysConfigObject      = $Kernel::OM->Get('Kernel::System::SysConfig');
    my $ValidObject          = $Kernel::OM->Get('Kernel::System::Valid');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $YAMLObject           = $Kernel::OM->Get('Kernel::System::YAML');

    # challenge token check for write action
    $LayoutObject->ChallengeTokenCheck();

    # get upload data
    my $FormID = $ParamObject->GetParam( Param => 'FormID' ) || '';
    my %UploadStuff = $ParamObject->GetUploadAll(
        Param  => 'FileUpload',
        Source => 'string',
    );
    return {
        Success => 0,
        Message => 'Content is missing, can not continue!',
    } if ( !$UploadStuff{Content} );

    # check if existing entries should be overwriten
    my $OverwriteExistingEntities = $ParamObject->GetParam( Param => 'OverwriteExistingEntities' ) || '';

    # load data from yaml file
    my $DynamicFieldData = $YAMLObject->Load(
        Data => $UploadStuff{Content}
    );
    return {
        Success => 0,
        Message => 'Invalid data structure!',
    } if ( ref( $DynamicFieldData ) ne 'ARRAY' );

    # get list of available object types
    my $ObjectTypeList = $ConfigObject->Get('DynamicFields::ObjectType');

    # get list of available field types
    my $FieldTypeList = $ConfigObject->Get('DynamicFields::Driver');

    # get list of valid values and reverse it
    my %ValidList    = $ValidObject->ValidList();
    my %ValidListRev = reverse( %ValidList );

    # get all current dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid => 0,
    );

    # create a dynamic fields lookup table
    my %DynamicFieldLookup;
    for my $DynamicField ( @{ $DynamicFieldList } ) {
        next if ( !IsHashRefWithData($DynamicField) );
        $DynamicFieldLookup{ $DynamicField->{Name} } = $DynamicField;
    }

    # init field order
    my $FieldOrder = keys( %DynamicFieldLookup ) + 1;

    # init postmaster headers
    my %PostMasterHeaders = map { $_ => 1 } @{ $ConfigObject->Get('PostmasterX-Header') };

    # process dynamic fields
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $DynamicFieldData } ) {
        # check if existing fields should be skipped
        next DYNAMICFIELD if (
            !$OverwriteExistingEntities
            && IsHashRefWithData( $DynamicFieldLookup{ $DynamicFieldConfig->{Name} } )
        );

        # check for available object type
        if ( ref( $ObjectTypeList->{ $DynamicFieldConfig->{ObjectType} } ) ne 'HASH' ) {
            return {
                Success => 0,
                Message => 'Object type "' . $DynamicFieldConfig->{ObjectType} . '" of dynamic field "' . $DynamicFieldConfig->{Name} . '" is not registered!',
            } 
        }

        # check for available field type
        if ( ref( $FieldTypeList->{ $DynamicFieldConfig->{FieldType} } ) ne 'HASH' ) {
            return {
                Success => 0,
                Message => 'Field type "' . $DynamicFieldConfig->{FieldType} . '" of dynamic field "' . $DynamicFieldConfig->{Name} . '" is not registered!',
            } 
        }

        # special handling for some configurations
        if ( $DynamicFieldConfig->{Config}->{DeploymentStates}
            || $DynamicFieldConfig->{Config}->{ITSMConfigItemClasses}
        ) {
            KEY:
            for my $Key ( qw(DeploymentStates ITSMConfigItemClasses) ) {
                next KEY if ( !$DynamicFieldConfig->{Config}->{ $Key } );
                my @IDs;

                ITEM:
                for my $ItemName ( @{ $DynamicFieldConfig->{Config}->{ $Key } } ) {
                    my $ItemDataRef = $GeneralCatalogObject->ItemGet(
                        Class => 'ITSM::ConfigItem::' . ( $Key eq 'DeploymentStates' ? 'DeploymentState' : 'Class' ),
                        Name  => $ItemName,
                    );

                    next ITEM if ( !$ItemDataRef );

                    push( @IDs, $ItemDataRef->{Name} );
                }

                if ( scalar(@IDs) ) {
                    $DynamicFieldConfig->{Config}->{ $Key } = \@IDs;
                } else {
                    delete( $DynamicFieldConfig->{Config}->{ $Key } );
                }
            }
        }

        # lookup valid id
        if (
            $DynamicFieldConfig->{ValidID}
            && $ValidListRev{ $DynamicFieldConfig->{ValidID} }
        ) {
            $DynamicFieldConfig->{ValidID} = $ValidListRev{ $DynamicFieldConfig->{ValidID} };
        }

        # check if the dynamic field already exists
        my $CreateDynamicField = 0;
        if ( !IsHashRefWithData( $DynamicFieldLookup{ $DynamicFieldConfig->{Name} } ) ) {
            $CreateDynamicField = 1;
        }
        # if the field exists check if the type match with the needed type
        elsif (
            $DynamicFieldLookup{ $DynamicFieldConfig->{Name} }->{FieldType} ne $DynamicFieldConfig->{FieldType}
        ) {

            # rename the field and create a new one
            my $Success = $DynamicFieldObject->DynamicFieldUpdate(
                %{ $DynamicFieldLookup{ $DynamicFieldConfig->{Name} } },
                Name   => $DynamicFieldLookup{ $DynamicFieldConfig->{Name} }->{Name} . 'Old',
                UserID => $Self->{UserID},
            );
            return {
                Success => 0,
                Message => 'Could not rename existing dynamic field "' . $DynamicFieldConfig->{Name} . '"!',
            } if ( !$Success );

            $CreateDynamicField = 1;
        }
        # otherwise if the field exists and the type match, update it to the new definition
        else {
            my $Success = $DynamicFieldObject->DynamicFieldUpdate(
                %{ $DynamicFieldConfig },
                ID         => $DynamicFieldLookup{ $DynamicFieldConfig->{Name} }->{ID},
                FieldOrder => $DynamicFieldLookup{ $DynamicFieldConfig->{Name} }->{FieldOrder},
                Reorder    => 0,
                UserID     => $Self->{UserID},
            );
            return {
                Success => 0,
                Message => 'Could not update existing dynamic field "' . $DynamicFieldConfig->{Name} . '"!',
            } if ( !$Success );
        }

        # check if new field has to be created
        if ($CreateDynamicField) {

            # create a new field
            my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
                Name       => $DynamicFieldConfig->{Name},
                Label      => $DynamicFieldConfig->{Label},
                FieldOrder => $FieldOrder,
                FieldType  => $DynamicFieldConfig->{FieldType},
                ObjectType => $DynamicFieldConfig->{ObjectType},
                Config     => $DynamicFieldConfig->{Config},
                ValidID    => $DynamicFieldConfig->{ValidID},
                UserID     => $Self->{UserID},
            );
            return {
                Success => 0,
                Message => 'Could not create dynamic field "' . $DynamicFieldConfig->{Name} . '"!',
            } if ( !$FieldID );

            # increment field order
            $FieldOrder += 1;
        }

        # set Dynamic Field in ticket actions
        if ( IsHashRefWithData( $DynamicFieldConfig->{ShowInRelevantAction} ) ) {
            for my $Action ( keys( %{ $DynamicFieldConfig->{ShowInRelevantAction} } ) ) {
                if ( $Action eq 'CustomerTicketZoomFollowUp' ) {
                    $Self->_AddSysConfigValue(
                        Name  => 'Ticket::Frontend::CustomerTicketZoom###FollowUpDynamicField',
                        Key   => $DynamicFieldConfig->{Name},
                        Value => $DynamicFieldConfig->{ShowInRelevantAction}->{ $Action } || 0,
                    );
                }
                else {
                    $Self->_AddSysConfigValue(
                        Name  => 'Ticket::Frontend::' . $Action . '###DynamicField',
                        Key   => $DynamicFieldConfig->{Name},
                        Value => $DynamicFieldConfig->{ShowInRelevantAction}->{ $Action } || 0,
                    );
                }
            }
        }

        # check if x-header for the dynamic field already exists
        if ( !$PostMasterHeaders{ 'X-KIX-DynamicField-' . $DynamicFieldConfig->{Name} } ) {
            $PostMasterHeaders{ 'X-KIX-DynamicField-' . $DynamicFieldConfig->{Name} } = 1;
        }

        if ( !$PostMasterHeaders{ 'X-KIX-FollowUp-DynamicField-' . $DynamicFieldConfig->{Name} } ) {
            $PostMasterHeaders{ 'X-KIX-FollowUp-DynamicField-' . $DynamicFieldConfig->{Name} } = 1;
        }

        # revert values from hash into an array
        my @PostMasterValuesToSet = sort( keys( %PostMasterHeaders ) );

        # execute the update action in sysconfig
        my $Success = $SysConfigObject->ConfigItemUpdate(
            Valid => 1,
            Key   => 'PostmasterX-Header',
            Value => \@PostMasterValuesToSet,
        );
    }

    return {
        Success => 1,
    }
}

sub _DynamicFieldExport {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject   = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    my $ValidObject          = $Kernel::OM->Get('Kernel::System::Valid');
    my $ParamObject          = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $YAMLObject           = $Kernel::OM->Get('Kernel::System::YAML');

    # get ID for single field to export
    my $ParamID = $ParamObject->GetParam( Param => 'ID' );

    # init dynamic field list to export
    my @DynamicFields = ();

    # check if single field id is given
    if ( $ParamID ) {
        push( @DynamicFields, $ParamID );
    }
    # get list of valid fields
    else {
        # get list of dynamic fields
        my $DynamicFieldList = $DynamicFieldObject->DynamicFieldList(
            ResultType => 'ARRAY',
            Valid      => 1,
        );

        # isolate array
        @DynamicFields = @{ $DynamicFieldList };
    }

    # get list of valid values
    my %ValidList = $ValidObject->ValidList();

    # prepare dynamic field data
    my @DynamicFieldData = ();
    for my $DynamicFieldID ( @DynamicFields ) {
        # get config of dynamic field
        my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
            ID => $DynamicFieldID,
        );

        # check for dynamic field data
        if ( ref( $DynamicFieldConfig ) eq 'HASH' ) {
            # lookup valid id
            if (
                $DynamicFieldConfig->{ValidID}
                && $ValidList{ $DynamicFieldConfig->{ValidID} }
            ) {
                $DynamicFieldConfig->{ValidID} = $ValidList{ $DynamicFieldConfig->{ValidID} };
            }

            # remove special entries
            for my $Entry ( qw(ID CreateTime ChangeTime) ) {
                delete( $DynamicFieldConfig->{ $Entry } );
            }

            # special handling for some configurations
            if ( $DynamicFieldConfig->{Config}->{DeploymentStates}
                || $DynamicFieldConfig->{Config}->{ITSMConfigItemClasses}
            ) {
                KEY:
                for my $Key ( qw(DeploymentStates ITSMConfigItemClasses) ) {
                    next KEY if ( !$DynamicFieldConfig->{Config}->{ $Key } );

                    # init name list
                    my @Names;

                    # process configured entries
                    ITEM:
                    for my $ItemID ( @{ $DynamicFieldConfig->{Config}->{ $Key } } ) {
                        # get data ref from general catalog
                        my $ItemDataRef = $GeneralCatalogObject->ItemGet(
                            ItemID => $ItemID,
                        );

                        # skip if no data ref is found
                        next ITEM if ( !$ItemDataRef );

                        # add ref name to list
                        push( @Names, $ItemDataRef->{Name} );
                    }

                    # check for lookup entries
                    if ( scalar(@Names) ) {
                        # replace entries
                        $DynamicFieldConfig->{Config}->{ $Key } = \@Names;
                    }
                    else {
                        # remove configuration key
                        delete( $DynamicFieldConfig->{Config}->{ $Key } );
                    }
                }
            }

            # get selections from sysconfig for dynamic field
            $DynamicFieldConfig->{ShowInRelevantAction} = $Self->_GetDynamicFieldFrontendModules(
                Name => $DynamicFieldConfig->{Name}
            );

            # add config to data
            push( @DynamicFieldData, $DynamicFieldConfig );
        }
    }

    # convert the DynamicField data hash to string
    my $DynamicFieldDataYAML = $YAMLObject->Dump( Data => \@DynamicFieldData );

    # send the result to the browser
    return $LayoutObject->Attachment(
        ContentType => 'text/html; charset=' . $LayoutObject->{Charset},
        Content     => $DynamicFieldDataYAML,
        Type        => 'attachment',
        Filename    => 'Export_DynamicField.yml',
        NoCache     => 1,
    );
}

sub _GetDynamicFieldFrontendModules {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my %Result;

    # get all frontend modules
    # get agent frontend modules
    my $ConfigHashAgent = $ConfigObject->Get('Frontend::Module');

    # get customer frontend modules
    my $ConfigHashCustomer = $ConfigObject->Get('CustomerFrontend::Module');

    # get admin frontend modules
    my %ConfigHash = ( %{$ConfigHashAgent}, %{$ConfigHashCustomer} );

    # get all tabs
    my $ConfigHashTabs = $ConfigObject->Get('AgentTicketZoomBackend');
    for my $Item ( keys %{$ConfigHashTabs} ) {

        # if no link is given
        next if !defined $ConfigHashTabs->{$Item}->{Link};

        # look for PretendAction
        my ($PretendAction) = $ConfigHashTabs->{$Item}->{Link} =~ /^(?:.*?)\;PretendAction=(.*?)\;(?:.*)$/;
        next if ( !$PretendAction || $ConfigHash{$PretendAction} );

     # if given and not already registered as frontend module - add width empty value to config hash
        $ConfigHash{$PretendAction} = '';
    }

    # ticket overview - add width empty value to config hash
    $ConfigHash{'OverviewCustom'}  = '';
    $ConfigHash{'OverviewSmall'}   = '';
    $ConfigHash{'OverviewMedium'}  = '';
    $ConfigHash{'OverviewPreview'} = '';

    # KIXSidebars - add width empty value to config hash
    foreach my $Frontend (qw(Frontend CustomerFrontend)) {
        my $SidebarConfig = $ConfigObject->Get( $Frontend . '::KIXSidebarBackend' );
        if (
            $SidebarConfig
            && ref($SidebarConfig) eq 'HASH'
        ) {
            for my $Key ( sort( keys( %{$SidebarConfig} ) ) ) {
                my $SidebarBackendConfig = $ConfigObject->Get( 'Ticket::Frontend::KIXSidebar' . $Key );
                if ( exists( $SidebarBackendConfig->{DynamicField} ) ) {
                    $ConfigHash{ 'KIXSidebar' . $Key } = '';
                }
            }
        }
    }

    my %DynamicFieldFrontends = ();

    # get all frontend modules with dynamic field config
    for my $Item ( keys %ConfigHash ) {
        my $ItemConfig = $ConfigObject->Get( "Ticket::Frontend::" . $Item );

        # if dynamic field config exists
        next if !( defined $ItemConfig && defined $ItemConfig->{DynamicField} );

        # if dynamic field is activated
        # for CustomerTicketZoom check also FollowUpDynamicFields
        if (
            $Item eq 'CustomerTicketZoom'
            && defined( $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } )
            && $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} } ne '0'
        ) {
            $DynamicFieldFrontends{'CustomerTicketZoomFollowUp'} = $ItemConfig->{FollowUpDynamicField}->{ $Param{Name} };
        }

        # if dynamic field is activated
        next if (
            !defined $ItemConfig->{DynamicField}->{ $Param{Name} }
            || $ItemConfig->{DynamicField}->{ $Param{Name} } eq '0'
        );

        $DynamicFieldFrontends{ $Item } = $ItemConfig->{DynamicField}->{ $Param{Name} };
    }

    return \%DynamicFieldFrontends;
}

sub _AddSysConfigValue {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');

    return if (!$Param{Name});

    my $SysConfigVal = '';
    if ($Param{Name} =~ /###/ ) {
        my @SysConfigData = split(/###/,$Param{Name});
        my $SysConfigObj  = $ConfigObject->Get($SysConfigData[0]);

        if (
            $SysConfigObj
            && ref($SysConfigObj)
            && $SysConfigObj->{$SysConfigData[1]}
        ) {
            $SysConfigVal = $SysConfigObj->{$SysConfigData[1]};
        }
    }

    else {
        $SysConfigVal = $ConfigObject->Get($Param{Name});
    }

    return if (!$SysConfigVal);

    my $ObjectType = ref($SysConfigVal) || '';

    return if (
        !$ObjectType
        && $ObjectType ne 'HASH'
        && $ObjectType ne 'ARRAY'
    );
    return if (
        $ObjectType eq 'HASH'
        && (
            !$Param{Key}
            || !defined($Param{Value})
        )
    );
    return if (
        $ObjectType eq 'ARRAY'
        && !$Param{Value}
    );

    if ($ObjectType eq 'HASH') {
        $SysConfigVal->{$Param{Key}} = $Param{Value};
    }
    elsif ($ObjectType eq 'ARRAY') {
        push(@{$SysConfigVal},$Param{Value});
    }

    my $Result = $SysConfigObject->ConfigItemUpdate(
        Valid => 1,
        Key   => $Param{Name},
        Value => $SysConfigVal,
    );

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
