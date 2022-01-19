# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::KIXSidebar::DynamicField;

use Kernel::System::VariableCheck qw(:all);

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    $Self->{DynamicFieldFilter} = {};
    my $Config = $ConfigObject->Get("Ticket::Frontend::KIXSidebarDynamicField");
    if (
        ref( $Config ) eq 'HASH'
        && defined( $Config->{DynamicField} )
        && ref( $Config->{DynamicField} ) eq 'HASH'
    ) {
        $Self->{DynamicFieldFilter} = $Config->{DynamicField};
    }

    # get the dynamic fields for this screen
    $Self->{DynamicField} = $DynamicFieldObject->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => ['Ticket'],
        FieldFilter => $Self->{DynamicFieldFilter},
    );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create needed objects
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get values
    my %GetParam = %Param;
    for my $Key (qw(TicketID)) {
        $GetParam{$Key} = $GetParam{$Key} || $Self->{ParamObject}->GetParam( Param => $Key ) || '';
    }

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $GetParam{TicketID},
        DynamicFields => 1
    );

    # get user preferences
    my %UserPreferences = $UserObject->GetPreferences( UserID => $Self->{UserID} );
    my $View                 = $UserPreferences{UserKIXSidebarDynamicFieldView}      || 'Collapsed';
    my $DynamicFieldSelected = $UserPreferences{UserKIXSidebarDynamicFieldSelection} || '';
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

    # create dynamic field selection string
    my %DynamicFieldsHash;
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        $DynamicFieldsHash{ $DynamicFieldConfig->{Name} } = $DynamicFieldConfig->{Name};
    }

    my $DynamicFieldSelectionStrg = $LayoutObject->BuildSelection(
        Data       => \%DynamicFieldsHash,
        Name       => 'DisplayedDynamicFields',
        SelectedID => \@DynamicFieldSelection,
        Multiple   => 1,
    );

    $LayoutObject->Block(
        Name => 'DynamicFieldSelect',
        Data => {
            DynamicFieldSelectionStrg => $DynamicFieldSelectionStrg,
            %GetParam
        },
    );

    ###############################################################################################
    # display editable dynamic fields
    ###############################################################################################

    if ($AccessRW) {

        $LayoutObject->Block(
            Name => 'DynamicFieldEdit',
            Data => {
                %GetParam
            },
        );

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
                Value                => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                LayoutObject         => $LayoutObject,
                ParamObject          => $ParamObject,
                AJAXUpdate           => 1,
                UpdatableFields      => $Self->_GetFieldsToUpdate(),
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

            $LayoutObject->Block(
                Name => 'DynamicFieldEditRow',
                Data => {
                    Name  => $DynamicFieldConfig->{Name},
                    Label => $DynamicFieldHTML->{Label},
                    Field => $DynamicFieldHTML->{Field},
                },
            );
        }
    }

    ###############################################################################################
    # display dynamic field values
    ###############################################################################################

    elsif ($AccessRO) {

        $LayoutObject->Block(
            Name => 'DynamicFieldDisplay',
            Data => {
            },
        );

        # cycle trough the activated Dynamic Fields for ticket object
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {

            next if !grep { $_ eq $DynamicFieldConfig->{Name} } @DynamicFieldSelection;
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            # get print string for this dynamic field
            my $ValueStrg = $BackendObject->DisplayValueRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Value              => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
                ValueMaxChars      => $ConfigObject->Get("Ticket::Frontend::AgentTicketZoom")
                    ->{TicketDataLength} || '',
                LayoutObject => $LayoutObject,
            );

            $LayoutObject->Block(
                Name => 'DynamicFieldContent',
                Data => {
                    Label => $DynamicFieldConfig->{Label},
                },
            );

            if (
                !defined $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
                || !$Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
            ) {
                $LayoutObject->Block(
                    Name => 'DynamicFieldContentNotSet',
                    Data => {
                    },
                );
            }
            elsif ( $DynamicFieldConfig->{FieldType} eq 'DateTime' ) {
                $LayoutObject->Block(
                    Name => 'DynamicFieldContentTime',
                    Data => {
                        Value => $ValueStrg->{Value},
                        Title => $ValueStrg->{Title},
                    },
                );
            }
            elsif (
                $DynamicFieldConfig->{FieldType}    eq 'Dropdown'
                || $DynamicFieldConfig->{FieldType} eq 'Multiselect'
                || $DynamicFieldConfig->{FieldType} eq 'MultiselectGeneralCatalog'
                || $DynamicFieldConfig->{FieldType} eq 'DropdownGeneralCatalog'
            ) {
                $LayoutObject->Block(
                    Name => 'DynamicFieldContentQuoted',
                    Data => {
                        Value => $ValueStrg->{Value},
                        Title => $ValueStrg->{Title},
                    },
                );
            }
            elsif ( $DynamicFieldConfig->{FieldType} eq 'Checkbox' ) {
                my $Checked = '';
                if ( $ValueStrg->{Value} eq 'Checked' ) {
                    $Checked = 'Checked="Checked"';
                }
                $LayoutObject->Block(
                    Name => 'DynamicFieldContentCheckbox',
                    Data => {
                        Value => $Checked,
                        Title => $ValueStrg->{Title},
                    },
                );
            }
            elsif ( $ValueStrg->{Link} ) {
                $LayoutObject->Block(
                    Name => 'DynamicFieldContentLink',
                    Data => {
                        %Ticket,
                        Value => $ValueStrg->{Value},
                        Title => $ValueStrg->{Title},
                        Link  => $ValueStrg->{Link},
                    },
                );
            }
            else {
                $LayoutObject->Block(
                    Name => 'DynamicFieldContentRaw',
                    Data => {
                        Value => $ValueStrg->{Value},
                        Title => $ValueStrg->{Title},
                    },
                );
            }
        }
    }

    $GetParam{TemplateFile} = 'AgentKIXSidebarDynamicField';

    # output result
    return $LayoutObject->Output(
        TemplateFile => 'AgentKIXSidebarDynamicField',
        Data         => {
            Title => 'DynamicFields',
            View  => $View,
            %GetParam
        },
        KeepScriptTags => $Param{AJAX},
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

        my $IsACLReducible
            = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->HasBehavior(
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
