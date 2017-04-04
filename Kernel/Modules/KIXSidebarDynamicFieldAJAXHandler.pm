# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::KIXSidebarDynamicFieldAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    $Self->{DynamicFieldFilter}
        = $ConfigObject->Get("Ticket::Frontend::KIXSidebarDynamicField")->{DynamicField};

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Self->{DynamicFieldFilter} || {},
    );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $SessionObject      = $Kernel::OM->Get('Kernel::System::AuthSession');
    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $JSON = '';
    my %GetParam;

    for my $Key (qw(TicketID))
    {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key );
    }

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $GetParam{TicketID},
        DynamicFields => 1
    );

    if ( $Self->{Subaction} eq 'SelectDynamicFields' ) {

        # get shown dynamic fields
        my @DisplayedDynamicFields
            = $ParamObject->GetArray( Param => 'DisplayedDynamicFields' );
        my $DisplayedDynamicFieldsStrg = join( ",", @DisplayedDynamicFields );

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # update preferences
        my $Success = $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => 'UserKIXSidebarDynamicFieldSelection',
            Value  => $DisplayedDynamicFieldsStrg,
        );

        # update session
        if ($Success) {
            $SessionObject->UpdateSessionID(
                SessionID => $Self->{SessionID},
                Key       => 'UserKIXSidebarDynamicFieldSelection',
                Value     => $DisplayedDynamicFieldsStrg,
            );
        }

        # get dynamic field sidebar content
        # get user preferences
        my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );
        my $View                  = $UserPreferences{UserKIXSidebarDynamicFieldView} || 'Collapsed';
        my $DynamicFieldSelected  = $UserPreferences{UserKIXSidebarDynamicFieldSelection};
        my @DynamicFieldSelection = split( /,/, $DynamicFieldSelected );

        # check permissions
        my $AccessRW = $TicketObject->TicketPermission(
            Type     => 'rw',
            TicketID => $GetParam{TicketID},
            UserID   => $Self->{UserID}
        );

        my $AccessRO = 0;
        if ( !$AccessRW ) {
            $AccessRO = $TicketObject->TicketPermission(
                Type     => 'ro',
                TicketID => $GetParam{TicketID},
                UserID   => $Self->{UserID}
            );
        }

        ###############################################################################################
        # display editable dynamic fields
        ###############################################################################################

        if ($AccessRW) {

            # get dynamic field values form http request
            my %DynamicFieldValues;

            # cycle trough the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next if !grep { $_ eq $DynamicFieldConfig->{Name} } @DynamicFieldSelection;

                # extract the dynamic field value from the web request
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
                next DYNAMICFIELD if !$DynamicField;
                next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

                $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField }
                    = $DynamicFieldValues{$DynamicField};
            }
            $GetParam{DynamicField} = \%DynamicFieldACLParameters;

            # create html strings for all dynamic fields
            my %DynamicFieldHTML;

            # cycle trough the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next if !grep { $_ eq $DynamicFieldConfig->{Name} } @DynamicFieldSelection;

                my $PossibleValuesFilter;

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
                            Action        => 'KIXSidebarDynamicField',
                            TicketID      => $GetParam{TicketID},
                            ReturnType    => 'Ticket',
                            ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                            Data          => \%AclData,
                            UserID        => $Self->{UserID},
                        );
                        if ($ACL) {
                            my %Filter = $TicketObject->TicketAclData();

                            # convert Filer key => key back to key => value using map
                            %{$PossibleValuesFilter}
                                = map { $_ => $PossibleValues->{$_} }
                                keys %Filter;
                        }
                    }
                }

                # get field html
                $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                    $BackendObject->EditFieldRender(
                    DynamicFieldConfig   => $DynamicFieldConfig,
                    PossibleValuesFilter => $PossibleValuesFilter,
                    Value           => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                    LayoutObject    => $LayoutObject,
                    ParamObject     => $ParamObject,
                    AJAXUpdate      => 1,
                    UpdatableFields => $Self->_GetFieldsToUpdate(),
                    );
            }

            # Dynamic fields
            # cycle trough the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next if !grep { $_ eq $DynamicFieldConfig->{Name} } @DynamicFieldSelection;

                # skip fields that HTML could not be retrieved
                next DYNAMICFIELD if !IsHashRefWithData(
                    $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }
                );

                # get the html strings form $Param
                my $DynamicFieldHTML = $DynamicFieldHTML{ $DynamicFieldConfig->{Name} };

                $JSON .= '<div class="Row Row_DynamicField_' . $DynamicFieldConfig->{Name} . '">'
                    . '<label id="LabelDynamicField_'
                    . $DynamicFieldConfig->{Name}
                    . '" for="DynamicField_'
                    . $DynamicFieldConfig->{Name} . '">'
                    . $LayoutObject->{LanguageObject}->Translate( $DynamicFieldConfig->{Label} )
                    . ': </label>'
                    . '<div class="Field">' . $DynamicFieldHTML->{Field} . '</div>'
                    . '<div class="Clear"></div>'
                    . '</div>';
            }
        }

        ###############################################################################################
        # display dynamic field values
        ###############################################################################################

        elsif ($AccessRO) {

            # cycle trough the activated Dynamic Fields for ticket object
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next if !grep { $_ eq $DynamicFieldConfig->{Name} } @DynamicFieldSelection;
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next DYNAMICFIELD if $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} } eq '';

                # get print string for this dynamic field
                my $ValueStrg = $BackendObject->DisplayValueRender(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                    ValueMaxChars => $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")
                        ->{TicketDataLength} || '',
                    LayoutObject => $LayoutObject,
                );

                $JSON
                    .= '<label id="LabelDynamicField_'
                    . $DynamicFieldConfig->{Name}
                    . '" for="DynamicField_'
                    . $DynamicFieldConfig->{Name} . '">'
                    . $LayoutObject->{LanguageObject}->Translate( $DynamicFieldConfig->{Label} )
                    . ': </label>';

                if (
                    !defined $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
                    || !$Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
                    )
                {
                    $LayoutObject->Block(
                        Name => 'DynamicFieldContentNotSet',
                        Data => {
                        },
                    );
                }
                elsif ( $DynamicFieldConfig->{FieldType} eq 'DateTime' ) {
                    $JSON
                        .= '<p class="Value" title="'
                        . $ValueStrg->{Title}
                        . '">$TimeLong{"$Data{"Value"}"}</p>';
                }
                elsif (
                    $DynamicFieldConfig->{FieldType}    eq 'Dropdown'
                    || $DynamicFieldConfig->{FieldType} eq 'Multiselect'
                    || $DynamicFieldConfig->{FieldType} eq 'MultiselectGeneralCatalog'
                    || $DynamicFieldConfig->{FieldType} eq 'DropdownGeneralCatalog'
                    )
                {
                    $JSON
                        .= '<p class="Value" title="'
                        . $ValueStrg->{Title} . '">'
                        . $ValueStrg->{Value} . '</p>';
                }
                elsif ( $DynamicFieldConfig->{FieldType} eq 'Checkbox' ) {
                    my $Checked = '';
                    if ( $ValueStrg->{Value} eq 'Checked' ) {
                        $Checked = 'Checked="Checked"';
                    }
                    $JSON
                        .= '<p class="Value" title="'
                        . $ValueStrg->{Title}
                        . '"><input type="Checkbox" '
                        . $ValueStrg->{Value}
                        . ' disabled="disabled"></input>';
                    </p>
                }
                elsif ( $ValueStrg->{Link} ) {
                    $JSON
                        .= '<p class="Value" title="'
                        . $ValueStrg->{Title}
                        . '"><a href="'
                        . $ValueStrg->{Link}
                        . '" target="_blank" class="DynamicFieldLink">'
                        . $ValueStrg->{Value}
                        . '</a></p>';
                }
                else {
                    $JSON
                        .= '<p class="Value" title="'
                        . $ValueStrg->{Title} . '">'
                        . $ValueStrg->{Value} . '</p>';
                }

                $JSON .= '<div class="Clear">&nbsp;</div>';

            }
        }

    }
    else {

        # get Dynamic fields form ParamObject
        my %DynamicFieldValues;

        # cycle trough the activated Dynamic Fields for this screen
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
            next DYNAMICFIELD if !$DynamicField;
            next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

            $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField }
                = $DynamicFieldValues{$DynamicField};
        }
        $GetParam{DynamicField} = \%DynamicFieldACLParameters;

        if ( $Self->{Subaction} eq 'Store' ) {

            # set dynamic fields
            # cycle through the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

                # set the value
                my $Success = $BackendObject->ValueSet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $GetParam{TicketID},
                    Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                    UserID             => $Self->{UserID},
                );
            }
        }
        elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {

            # convert dynamic field values into a structure for ACLs
            my %DynamicFieldACLParameters;
            DYNAMICFIELD:
            for my $DynamicField ( sort @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !$DynamicField;
                next DYNAMICFIELD if !$DynamicFieldValues{$DynamicField};

                $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicField }
                    = $DynamicFieldValues{$DynamicField};
            }

            # update Dynamic Fields Possible Values via AJAX
            my @DynamicFieldAJAX;

            # cycle trough the activated Dynamic Fields for this screen
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);
                next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Ticket';

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
                    Action        => 'KIXSidebarDynamicField',
                    TicketID      => $GetParam{TicketID},
                    QueueID       => $Ticket{QueueID} || '',
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
            }
            $JSON = $LayoutObject->BuildSelectionJSON(
                [
                    @DynamicFieldAJAX,
                ],
            );
        }
    }

    if ( $JSON eq '' ) {
        $JSON = " "
    }

    # send JSON response
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );

}

sub _GetFieldsToUpdate {
    my ( $Self, %Param ) = @_;

    my @UpdatableFields;

    # set the fields that can be updatable via AJAXUpdate
    if ( !$Param{OnlyDynamicFields} ) {
        @UpdatableFields
            = qw( TypeID Dest ServiceID SLAID NewUserID NewResponsibleID NextStateID PriorityID
            StandardTemplateID
        );
    }

    # cycle trough the activated Dynamic Fields for this screen
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


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
