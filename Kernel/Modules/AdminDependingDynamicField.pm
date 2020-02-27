# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminDependingDynamicField;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');

    my $DependingDynamicFieldObject
        = $Kernel::OM->Get('Kernel::System::DependingDynamicField');
    my $DynamicFieldBackendObject
        = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # get configured object types
    $Self->{ObjectTypeConfig} = $ConfigObject->Get('DynamicFields::ObjectType');

    # get configured field types
    $Self->{FieldTypeConfig} = $ConfigObject->Get('DynamicFields::Driver');

    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();

    # get DynamicFieldList
    my $DynamicFieldsListGet = $DynamicFieldObject->DynamicFieldListGet( Valid => 0 );
    my @DynamicFieldsList;
    my @DynamicFieldsDataList;
    for my $DynamicFieldHash ( @{$DynamicFieldsListGet} ) {
        next
            if (
            defined $DynamicFieldHash->{Config}->{DisplayFieldType}
            && $DynamicFieldHash->{Config}->{DisplayFieldType} eq 'Multiselect'
            );
        next
            if (
            !defined $DynamicFieldHash->{Config}->{DisplayFieldType}
            && $DynamicFieldHash->{FieldType} !~ /^Dropdown/
            );
        push @DynamicFieldsList,     $DynamicFieldHash->{ID};
        push @DynamicFieldsDataList, $DynamicFieldHash;
    }
    $LayoutObject->Block(
        Name => 'Main',
        Data => {
            %Param,
            Action => $Self->{Subaction} || 'Overview',
            }
    );
    my $InsertedDependingFieldID;

    ##################################################################################
    # Add
    ##################################################################################
    if ( $Self->{Subaction} eq 'Add' ) {

        # get already used dynamic fields
        my $UsedFields = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameList();

        # Build Dynamic Field String
        my %DynamicFieldHash;
        for my $DynamicField (@DynamicFieldsDataList) {
            next if grep {/$DynamicField->{ID}/} @{$UsedFields};
            $DynamicFieldHash{ $DynamicField->{ID} } = $DynamicField->{Name};
        }
        my $DynamicFieldString = $LayoutObject->BuildSelection(
            Data         => \%DynamicFieldHash,
            Name         => 'DynamicField',
            Class        => 'Modernize',
            Translation  => 0,
            PossibleNone => 1,
        );

        # build target value string
        my $DynamicFieldValueString
            = '<select id="DynamicFieldValue" name="DynamicFieldValue" class="Modernize TargetValueSelect" size="5" multiple></select>';

        # build valid string
        my %ValidList = $ValidObject->ValidList();

        # create the Validity select
        my $ValidityStrg = $LayoutObject->BuildSelection(
            Data         => \%ValidList,
            Name         => 'ValidID',
            SelectedID   => $Param{ValidID} || 1,
            Class        => 'Modernize',
            PossibleNone => 0,
            Translation  => 1,
        );

        # output backlink
        $LayoutObject->Block(
            Name => 'ActionOverview',
            Data => \%Param,
        );

        # call all needed dtl blocks
        $LayoutObject->Block(
            Name => 'DependingFieldAdd',
            Data => {
                %Param,
                TreeNameString =>
                    '<input type="text" id="TreeName" name="TreeName" size="35" class="Validate_Required Validate_MaxLength Validate_Length_80" maxlength="80"/>',
                ValidityStrg            => $ValidityStrg,
                DynamicFieldString      => $DynamicFieldString,
                DynamicFieldValueString => $DynamicFieldValueString,
            },
        );
    }
    ##################################################################################
    # Edit
    ##################################################################################
    elsif ( $Self->{Subaction} eq 'Edit' ) {

        # get parameters
        my $DependingDynamicFieldID
            = $ParamObject->GetParam( Param => 'DependingFieldID' );
        my $AddField
            = $ParamObject->GetParam( Param => 'AddField' ) || 0;

        # edit
        if ( $DependingDynamicFieldID =~ m/^DynamicField_(.*)$/ ) {
            my $DynamicFieldData = $DynamicFieldObject->DynamicFieldGet(
                Name => $1
            );

            my $TreeData;
            my $DynamicFieldValueString;
            if ( ref $DynamicFieldData eq 'HASH' ) {
                $TreeData = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameGet(
                    ID => $DynamicFieldData->{ID}
                );
                my $DependingFields =
                    $DependingDynamicFieldObject->DependingDynamicFieldListGet(
                    ParentID       => 0,
                    DynamicFieldID => $DynamicFieldData->{ID}
                    );
                my @SelectedValues;
                for my $Field ( @{$DependingFields} ) {
                    push @SelectedValues, $Field->{Value};
                }

                # get all values
                my $Values = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $DynamicFieldData,
                );

                # build dynamic field value string
                $DynamicFieldValueString = $LayoutObject->BuildSelection(
                    Data       => $Values,
                    Name       => 'DynamicFieldValue',
                    Multiple   => 1,
                    Size       => 5,
                    SelectedID => \@SelectedValues,
                    Class      => 'Modernize DynamicFieldValue'
                );
            }

            # build valid string
            my %ValidList = $ValidObject->ValidList();

            # create the Validity select
            my $ValidityStrg = $LayoutObject->BuildSelection(
                Data         => \%ValidList,
                Name         => 'ValidID',
                Class        => 'Modernize',
                SelectedID   => $TreeData->{ValidID} || 1,
                PossibleNone => 0,
                Translation  => 1,
            );

            # output backlink
            $LayoutObject->Block(
                Name => 'ActionOverview',
                Data => \%Param,
            );

            # call all needed dtl blocks
            $LayoutObject->Block(
                Name => 'DependingFieldAdd',
                Data => {
                    %Param,
                    DynamicFieldID          => $DynamicFieldData->{ID},
                    TreeNameString          => '<span>' . $TreeData->{Name} . '</span>' || '',
                    ValidityStrg            => $ValidityStrg,
                    DynamicFieldString      => '<span>' . $DynamicFieldData->{Label} . '</span>'  || '',
                    DynamicFieldValueString => $DynamicFieldValueString,
                },
            );
        }

        # edit the child nodes
        else {

            # get depending field values
            my $DependingField = $DependingDynamicFieldObject
                ->DependingDynamicFieldGet( ID => $DependingDynamicFieldID );

            # get child node list
            my $DependingFieldChildNodes = $DependingDynamicFieldObject
                ->DependingDynamicFieldList(
                ParentID => $DependingDynamicFieldID
                );

            # output backlink
            $LayoutObject->Block(
                Name => 'ActionOverview',
                Data => \%Param,
            );

            # Build Source String
            my $SourceDataHash;
            for my $Hash (@DynamicFieldsDataList) {
                next if $Hash->{ID} ne $DependingField->{DynamicFieldID};
                $SourceDataHash = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig => $Hash,
                );
            }
            my $DynamicFieldSourceString = $SourceDataHash->{ $DependingField->{Value} };

            # call all needed dtl blocks
            $LayoutObject->Block(
                Name => 'DependingFieldEdit',
                Data => {
                    %Param,
                    DynamicFieldSourceString => $DynamicFieldSourceString,
                    DependingFieldID         => $DependingDynamicFieldID,
                    DynamicFieldID           => $DependingField->{DynamicFieldID},
                },
            );

            # get all parent nodes
            my @UsedDynamicFields = ();
            push @UsedDynamicFields, $DependingField->{DynamicFieldID};
            my $ParentNode = $DependingField->{ParentID};
            while ( $ParentNode != 0 ) {
                my $ParentDependingField = $DependingDynamicFieldObject
                    ->DependingDynamicFieldGet( ID => $ParentNode );
                push @UsedDynamicFields, $ParentDependingField->{DynamicFieldID};
                $ParentNode = $ParentDependingField->{ParentID};
            }
            my $Counter              = 0;
            my @UsedDynamicFieldList = ();
            for my $ChildItem ( @{$DependingFieldChildNodes} ) {

                # get child dynamic field data
                my $ChildNodeValues = $DependingDynamicFieldObject
                    ->DependingDynamicFieldGet( ID => $ChildItem );
                my $ChildNodeDynamicFieldID = $ChildNodeValues->{DynamicFieldID};

                # next if dynamic field already used
                next if grep( {/$ChildNodeDynamicFieldID/} @UsedDynamicFieldList );

                # add dynamic field id to used dynamic field list
                push @UsedDynamicFieldList, $ChildNodeDynamicFieldID;

                # build dynamic field target selection (dropdown)
                my $ParentID = $DependingField->{ParentID};
                if (
                    !( grep( {/$DependingField->{DynamicFieldID}/} @UsedDynamicFields ) )
                    && $DependingField->{DynamicFieldID}
                ) {
                    push @UsedDynamicFields, $DependingField->{DynamicFieldID};
                }
                while ($ParentID) {
                    my $Data =
                        $DependingDynamicFieldObject
                        ->DependingDynamicFieldGet( ID => $ParentID );
                    push @UsedDynamicFields, $Data->{DynamicFieldID};
                    $ParentID = $Data->{ParentID};
                }

                # remove already used dynamic fields
                my %TargetDataHash;
                for my $Hash (@DynamicFieldsDataList) {
                    next if grep( {/$Hash->{ID}/} @UsedDynamicFields );
                    $TargetDataHash{ $Hash->{ID} } = $Hash->{Name};
                }
                my $DynamicFieldTargetString = $LayoutObject->BuildSelection(
                    Data         => \%TargetDataHash,
                    Name         => 'DynamicFieldTarget_' . $Counter,
                    SelectedID   => $ChildNodeDynamicFieldID,
                    Class        => 'Modernize',
                    Translation  => 0,
                    PossibleNone => 1
                );

                # build target value selection (multiselect)
                # create empty selection
                my $DynamicFieldTargetValueString
                    = '<select id="DynamicFieldTargetValue_'
                    . $Counter
                    . '" name="DynamicFieldTargetValue_'
                    . $Counter
                    . '" class="Modernize TargetValueSelect" size="5" multiple></select>';

                # if target dynamic field selected
                if ($ChildNodeDynamicFieldID) {

                    # get all possible values
                    my $TargetValueHash;
                    for my $Hash (@DynamicFieldsDataList) {
                        next if $Hash->{ID} ne $ChildNodeDynamicFieldID;
                        $TargetValueHash = $DynamicFieldBackendObject->PossibleValuesGet(
                            DynamicFieldConfig => $Hash,
                        );

                    }

                    # get selected values
                    my $ChildNodes = $DependingDynamicFieldObject
                        ->DependingDynamicFieldListGet(
                        ParentID       => $DependingDynamicFieldID,
                        DynamicFieldID => $ChildNodeDynamicFieldID
                        );
                    my @SelectedTargetValues = ();
                    for my $Child ( @{$ChildNodes} ) {
                        push @SelectedTargetValues, $Child->{Value};
                    }
                    $DynamicFieldTargetValueString = $LayoutObject->BuildSelection(
                        Data       => $TargetValueHash,
                        Name       => 'DynamicFieldTargetValue_' . $Counter,
                        Multiple   => 1,
                        Size       => 5,
                        SelectedID => \@SelectedTargetValues,
                        Class      => 'Modernize TargetValueSelect'
                    );
                }
                $LayoutObject->Block(
                    Name => 'DependingFieldEditItem',
                    Data => {
                        Counter => $Counter,
                        %Param,
                        OldTargetKey                  => $ChildNodeDynamicFieldID,
                        DynamicFieldTargetString      => $DynamicFieldTargetString,
                        DynamicFieldTargetValueString => $DynamicFieldTargetValueString || ''
                    },
                );
                if ( !( grep( {/$ChildNodeDynamicFieldID/} @UsedDynamicFields ) ) ) {
                    push @UsedDynamicFields, $ChildNodeDynamicFieldID;
                }
                $Counter++;
            }

            # add one empty field
            if ($AddField) {
                my %TargetDataHash;
                for my $Hash (@DynamicFieldsDataList) {
                    next if grep {/$Hash->{ID}/} @UsedDynamicFields;
                    $TargetDataHash{ $Hash->{ID} } = $Hash->{Name};
                }
                my $DynamicFieldTargetString = $LayoutObject->BuildSelection(
                    Data         => \%TargetDataHash,
                    Name         => 'DynamicFieldTarget_' . $Counter,
                    Class        => 'Modernize',
                    Translation  => 0,
                    PossibleNone => 1
                );

                # build target value selection (multiselect)
                # create empty selection
                my $DynamicFieldTargetValueString
                    = '<select id="DynamicFieldTargetValue_'
                    . $Counter
                    . '" name="DynamicFieldTargetValue_'
                    . $Counter
                    . '" class="Modernize TargetValueSelect" size="5" multiple></select>';
                $LayoutObject->Block(
                    Name => 'DependingFieldEditItem',
                    Data => {
                        Counter => $Counter,
                        %Param,
                        OldTargetKey                  => 0,
                        DynamicFieldTargetString      => $DynamicFieldTargetString,
                        DynamicFieldTargetValueString => $DynamicFieldTargetValueString || ''
                    },
                );
                $Counter++;
            }
            $LayoutObject->Block(
                Name => 'DependingFieldEditAdd',
                Data => {
                    CountMax => $Counter - 1,
                },
            );
        }
    }
    ##################################################################################
    # AJAXUpdate
    ##################################################################################
    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {
        my $Counter
            = $ParamObject->GetParam( Param => 'CurrentCounter' );
        my $DependingFieldTargetID
            = $ParamObject->GetParam( Param => 'DynamicFieldTarget_' . $Counter );
        my $JSON;
        my $TargetValueHash;
        if ($DependingFieldTargetID) {

            # Build Target Selection
            for my $Hash (@DynamicFieldsDataList) {
                next if $Hash->{ID} != $DependingFieldTargetID;
                $TargetValueHash = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig    => $Hash,
                    GetAutocompleteValues => 1
                );
            }
        }
        if ( ref $TargetValueHash ne 'HASH' ) {
            $TargetValueHash->{Key1} = '';
        }
        $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'DynamicFieldTargetValue_' . $Counter,
                    Data         => $TargetValueHash,
                    Translation  => 0,
                    PossibleNone => 0,
                    Class        => 'Modernize'
                },
            ],
        );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    ##################################################################################
    # AJAXUpdateNew
    ##################################################################################
    elsif ( $Self->{Subaction} eq 'AJAXUpdateNew' ) {
        my $DynamicFieldID
            = $ParamObject->GetParam( Param => 'DynamicField' );
        my $JSON;
        my $DynamicFieldValueHash;
        if ($DynamicFieldID) {

            # Build Target Selection
            my $DynamicFieldData
                = $DynamicFieldObject->DynamicFieldGet( ID => $DynamicFieldID );

            if (
                ref $DynamicFieldData eq 'HASH'
            ) {
                $DynamicFieldValueHash = $DynamicFieldBackendObject->PossibleValuesGet(
                    DynamicFieldConfig    => $DynamicFieldData,
                    GetAutocompleteValues => 1
                );
            }
        }
        if ( ref $DynamicFieldValueHash ne 'HASH' ) {
            $DynamicFieldValueHash->{Key1} = '';
        }
        $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'DynamicFieldValue',
                    Data         => $DynamicFieldValueHash,
                    Translation  => 0,
                    PossibleNone => 0,
                    Class        => 'Modernize'
                },
            ],
        );
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    ##################################################################################
    # Delete
    ##################################################################################
    elsif ( $Self->{Subaction} eq 'Delete' ) {
        my $DependingFieldID
            = $ParamObject->GetParam( Param => 'DependingFieldID' );
        my $DeleteResult;
        if ( $DependingFieldID =~ m/^DynamicField_(.*)$/ ) {
            my $DynamicFieldData = $DynamicFieldObject->DynamicFieldGet( Name => $1 );
            $DeleteResult =
                $DependingDynamicFieldObject->DependingDynamicFieldTreeNameDelete(
                ID => $DynamicFieldData->{ID}
                );
        }
        else {
            $DeleteResult = $DependingDynamicFieldObject->DependingDynamicFieldDelete(
                ID => $DependingFieldID
            );
        }
        if ($DeleteResult) {
            return $LayoutObject->Redirect(
                OP => "Action=$Self->{Action}"
            );
        }
        else {
            return $LayoutObject->ErrorScreen();
        }
    }
    ##################################################################################
    # Store
    ##################################################################################
    elsif (
        $Self->{Subaction}    eq 'Store'
        || $Self->{Subaction} eq 'StoreDelete'
        || $Self->{Subaction} eq 'StoreAdd'
    ) {
        my %GetParam;
        for my $Key (
            qw(DependingFieldID DynamicFieldID DynamicFieldSource CountMax ValidID)
        ) {
            $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
        }

        # get targets
        my %TargetHash;
        my $DeleteResult = 0;
        for ( my $Count = 0; $Count <= $GetParam{CountMax}; $Count++ ) {
            my $TargetID
                = $ParamObject->GetParam( Param => 'DynamicFieldTarget_' . $Count ) || 0;
            my $OldTargetKey
                = $ParamObject->GetParam( Param => 'OldTargetKey_' . $Count ) || 0;
            if ($TargetID) {

                # get target dynamic field ID
                $TargetHash{$Count}->{DynamicFieldTargetID} = $TargetID;

                # get target values
                my @TargetValues
                    = $ParamObject
                    ->GetArray( Param => 'DynamicFieldTargetValue_' . $Count );
                $TargetHash{$Count}->{TargetValues} = \@TargetValues;

                # get old target dynamic field ID
                $TargetHash{$Count}->{OldDynamicFieldTargetID}
                    = $ParamObject->GetParam( Param => 'OldTargetKey_' . $Count );
            }
            elsif ( !$TargetID && $OldTargetKey ) {

                # get depending fields using dynamic fields id and parent id
                my $DeleteChildNodes = $DependingDynamicFieldObject
                    ->DependingDynamicFieldListGet(
                    ParentID       => $GetParam{DependingFieldID},
                    DynamicFieldID => $OldTargetKey
                    );

                # delete
                for my $DeleteItem ( @{$DeleteChildNodes} ) {
                    $DeleteResult =
                        $DependingDynamicFieldObject
                        ->DependingDynamicFieldDelete( ID => $DeleteItem->{ID} );
                }
            }
        }

        # empty field added?
        my $AddDynamicField = 0;
        my $TargetHashSize  = scalar( keys %TargetHash );
        if ( ( $GetParam{CountMax} + 1 ) != $TargetHashSize && !$DeleteResult ) {
            $AddDynamicField = 1;
        }
        my $ParentID;
        my $TreeID;
        my $ChildNodes;

        # depending dynamic field exists - update
        if ( $GetParam{DependingFieldID} ) {
            $DeleteResult = 1;

            # get existing child nodes
            $ChildNodes = $DependingDynamicFieldObject
                ->DependingDynamicFieldListGet( ParentID => $GetParam{DependingFieldID} );

            # delete unused child nodes or all child nodes if target changed
            for my $Child ( @{$ChildNodes} ) {
                my $ChildExists = 0;

                # check if existing child also exists in new data hash
                for my $Node ( keys %TargetHash ) {
                    if (
                        $Child->{DynamicFieldID} eq $TargetHash{$Node}->{DynamicFieldTargetID}
                        && ( grep {/$Child->{Value}/} @{ $TargetHash{$Node}->{TargetValues} } )
                    ) {
                        if (
                            $TargetHash{$Node}->{OldDynamicFieldTargetID} eq
                            $TargetHash{$Node}->{DynamicFieldTargetID}
                        ) {
                            $ChildExists = 1;

                            # get Index
                            my $ArrayIndex = 0;
                            my $ArrayCount = 0;
                            for my $ArrayItem ( @{ $TargetHash{$Node}->{TargetValues} } ) {
                                $ArrayIndex = $ArrayCount;
                                last
                                    if $TargetHash{$Node}->{TargetValues}->[$ArrayCount] eq
                                        $Child->{Value};
                                $ArrayCount++;
                            }

                            # remove this node from new hash (no changes for this one)
                            splice( @{ $TargetHash{$Node}->{TargetValues} }, $ArrayIndex, 1 );

                            # remove hash if values hash is empty
                            if ( !( scalar @{ $TargetHash{$Node}->{TargetValues} } ) ) {
                                delete $TargetHash{$Node};
                            }
                        }
                    }
                }
                next if $ChildExists;

                # delete unused children
                $DeleteResult
                    = $DeleteResult
                    && $DependingDynamicFieldObject
                    ->DependingDynamicFieldDelete( ID => $Child->{ID} );
            }

            # get parent id
            $ParentID = $GetParam{DependingFieldID};
            my $ParentData =
                $DependingDynamicFieldObject->DependingDynamicFieldGet( ID => $ParentID );
            $TreeID = $ParentData->{TreeID};
        }

        # create new depending dynamic field
        else {

            # get parent id
            $ParentID = $DependingDynamicFieldObject
                ->DependingDynamicFieldAdd(
                DynamicFieldID => $GetParam{DynamicFieldID},
                Value          => $GetParam{DynamicFieldSource},
                ParentID       => 0,
                TreeID         => $GetParam{DynamicFieldID}
                );
            $TreeID = $GetParam{DynamicFieldID};
        }

        # add child nodes (if not exist)
        for my $Node ( keys %TargetHash ) {
            if (
                scalar @{ $TargetHash{$Node}->{TargetValues} }
                && ref $TargetHash{$Node}->{TargetValues} eq 'ARRAY'
            ) {
                for my $NewChild ( @{ $TargetHash{$Node}->{TargetValues} } ) {
                    my $DependingFieldID = $DependingDynamicFieldObject
                        ->DependingDynamicFieldAdd(
                        DynamicFieldID => $TargetHash{$Node}->{DynamicFieldTargetID},
                        Value          => $NewChild,
                        ParentID       => $ParentID,
                        TreeID         => $TreeID
                        );
                }
            }
            $InsertedDependingFieldID = $ParentID;
        }
        if ($AddDynamicField) {
            return $LayoutObject->Redirect(
                OP => "Action=$Self->{Action};Subaction=Edit;AddField=1;DependingFieldID="
                    . $GetParam{DependingFieldID}
            );
        }
        if ( $Self->{Subaction} eq 'StoreDelete' ) {
            return $LayoutObject->Redirect(
                OP => "Action=$Self->{Action};Subaction=Edit;DependingFieldID="
                    . $GetParam{DependingFieldID}
            );
        }
    }
    ##################################################################################
    # StoreNew
    ##################################################################################
    elsif ( $Self->{Subaction} eq 'StoreNew' ) {

        my $TreeName = $ParamObject->GetParam( Param => 'TreeName' );
        my $ValidID  = $ParamObject->GetParam( Param => 'ValidID' );
        my @DynamicFieldValues = $ParamObject->GetArray( Param => 'DynamicFieldValue' );
        my $DynamicField   = $ParamObject->GetParam( Param => 'DynamicField' );
        my $DynamicFieldID = $ParamObject->GetParam( Param => 'DynamicFieldID' );

        if ( !$DynamicFieldID ) {
            $DynamicFieldID = $DynamicField;
        }

        my $ParentID;
        my $ChildNodes;
        if ($DynamicFieldID) {
            my $DeleteResult = 1;

            # get existing child nodes
            $ChildNodes = $DependingDynamicFieldObject
                ->DependingDynamicFieldListGet(
                ParentID       => 0,
                DynamicFieldID => $DynamicFieldID
                );

            # delete unused child nodes or all child nodes if target changed
            for my $Child ( @{$ChildNodes} ) {
                next if ( grep {/$Child->{Value}/} @DynamicFieldValues );
                $DeleteResult
                    = $DeleteResult
                    && $DependingDynamicFieldObject
                    ->DependingDynamicFieldDelete( ID => $Child->{ID} );
            }
        }

        # add parent
        if ($TreeName) {
            my $TreeID = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameAdd(
                ID      => $DynamicFieldID,
                UserID  => $Self->{UserID},
                Name    => $TreeName,
                ValidID => $ValidID
            );
        }

        # store changed valid id
        my $Success = $DependingDynamicFieldObject->DependingDynamicFieldTreeNameUpdate(
            ID      => $DynamicFieldID,
            ValidID => $ValidID,
            UserID  => $Self->{UserID},
        );

        # add child nodes (if not exist)
        for my $ArrayValue (@DynamicFieldValues) {
            my $ChildExist = 0;
            if ( $ChildNodes && ref $ChildNodes eq 'ARRAY' ) {
                for my $Child ( @{$ChildNodes} ) {
                    next if $Child->{Value} ne $ArrayValue;
                    $ChildExist = 1;
                }
            }
            if ( !$ChildExist ) {
                my $DependingFieldID = $DependingDynamicFieldObject
                    ->DependingDynamicFieldAdd(
                    DynamicFieldID => $DynamicFieldID,
                    Value          => $ArrayValue,
                    ParentID       => 0,
                    TreeID         => $DynamicFieldID
                    );
            }
        }
        if ($TreeName) {
            $InsertedDependingFieldID = 'DynamicField_' . $TreeName;
        }
    }
    ##################################################################################
    # Overview
    ##################################################################################
    if ( $Self->{Subaction} =~ m/^Store/ || !$Self->{Subaction} ) {

        # get possible values of all available dynamic fields
        my %PossibleValues;
        for my $Hash (@DynamicFieldsDataList) {
            $PossibleValues{ $Hash->{ID} } = $DynamicFieldBackendObject->PossibleValuesGet(
                DynamicFieldConfig    => $Hash,
                GetAutocompleteValues => 1
            );
        }

        # get data for tree view
        my $DependingDynamicFieldTreeList
            = $DependingDynamicFieldObject->DependingDynamicFieldTreeList(
            PossibleValues => \%PossibleValues,
            );

        $Param{DependingFieldTree} = $LayoutObject->DependingDynamicFieldTree(
            SelectedID => $InsertedDependingFieldID || '',
            Nodes => $DependingDynamicFieldTreeList,
        );

        my %FieldTypes;
        my %FieldDialogs;
        if ( !IsHashRefWithData( $Self->{FieldTypeConfig} ) ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Fields configuration is not valid'),
            );
        }

        # get the field types (backends) and its config dialogs
        FIELDTYPE:
        for my $FieldType ( keys %{ $Self->{FieldTypeConfig} } ) {
            next FIELDTYPE if !$Self->{FieldTypeConfig}->{$FieldType};

            # add the field type to the list
            $FieldTypes{$FieldType} = $Self->{FieldTypeConfig}->{$FieldType}->{DisplayName};

            # get the config dialog
            $FieldDialogs{$FieldType} =
                $Self->{FieldTypeConfig}->{$FieldType}->{ConfigDialog};
        }
        if ( !IsHashRefWithData( $Self->{ObjectTypeConfig} ) ) {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Objects configuration is not valid'),
            );
        }
        $LayoutObject->Block(
            Name => 'OverviewList',
            Data => \%Param,
        );
        $LayoutObject->Block(
            Name => 'DependingFieldList',
            Data => \%Param,
        );

        # print the list of dynamic fields
        $Self->_DynamicFieldsListShow(
            DynamicFields => \@DynamicFieldsList,
            Total         => scalar @DynamicFieldsList
        );
    }
    ##################################################################################
    # Output
    ##################################################################################
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AdminDependingDynamicField',
        Data         => {
            %Param,
        },
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _DynamicFieldsListShow {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $ValidObject        = $Kernel::OM->Get('Kernel::System::Valid');

    # check start option, if higher than fields available, set
    # it to the last field page
    my $StartHit = $ParamObject->GetParam( Param => 'StartHit' ) || 1;

    # get personal page shown count
    my $PageShownPreferencesKey = 'AdminDynamicFieldsOverviewPageShown';
    my $PageShown               = $Self->{$PageShownPreferencesKey} || 35;
    my $Group                   = 'DynamicFieldsOverviewPageShown';

    # get data selection
    my %Data;
    my $Config = $ConfigObject->Get('PreferencesGroups');
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
    }
    my $MaxFieldOrder = 0;

    # check if at least 1 dynamic field is registered in the system
    if ( $Param{Total} ) {

        # get dynamic fields details
        my $Counter = 0;
        DYNAMICFIELDID:
        for my $DynamicFieldID ( @{ $Param{DynamicFields} } ) {
            $Counter++;
            if ( $Counter >= $StartHit && $Counter < ( $PageShown + $StartHit ) ) {
                my $DynamicFieldData = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldID,
                );
                next DYNAMICFIELDID if !IsHashRefWithData($DynamicFieldData);

                # convert ValidID to Validity string
                my $Valid = $ValidObject->ValidLookup(
                    ValidID => $DynamicFieldData->{ValidID},
                );

                # get the object type display name
                my $ObjectTypeName
                    = $Self->{ObjectTypeConfig}->{ $DynamicFieldData->{ObjectType} }->{DisplayName}
                    || $DynamicFieldData->{ObjectType};

                # get the field type display name
                my $FieldTypeName
                    = $Self->{FieldTypeConfig}->{ $DynamicFieldData->{FieldType} }->{DisplayName}
                    || $DynamicFieldData->{FieldType};

                # get the field backend dialog
                my $ConfigDialog
                    = $Self->{FieldTypeConfig}->{ $DynamicFieldData->{FieldType} }->{ConfigDialog}
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

                # set MaxFieldOrder
                if ( int $DynamicFieldData->{FieldOrder} > int $MaxFieldOrder ) {
                    $MaxFieldOrder = $DynamicFieldData->{FieldOrder}
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
            MaxFieldOrder => $MaxFieldOrder,
        },
    );
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
