# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Stats::Dynamic::TicketSolutionResponseTime;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Lock',
    'Kernel::System::Log',
    'Kernel::System::Priority',
    'Kernel::System::Queue',
    'Kernel::System::Service',
    'Kernel::System::SLA',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::Type',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get the dynamic fields for ticket object
    $Self->{DynamicField} = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    );

    return $Self;
}

sub GetObjectName {
    my ( $Self, %Param ) = @_;

    return 'TicketSolutionResponseTime';
}

sub GetObjectBehaviours {
    my ( $Self, %Param ) = @_;

    my %Behaviours = (
        ProvidesDashboardWidget => 0,
    );

    return %Behaviours;
}

sub GetObjectAttributes {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $DBObject       = $Kernel::OM->Get('Kernel::System::DB');
    my $BackendObject  = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $LockObject     = $Kernel::OM->Get('Kernel::System::Lock');
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    my $QueueObject    = $Kernel::OM->Get('Kernel::System::Queue');
    my $ServiceObject  = $Kernel::OM->Get('Kernel::System::Service');
    my $SLAObject      = $Kernel::OM->Get('Kernel::System::SLA');
    my $StateObject    = $Kernel::OM->Get('Kernel::System::State');
    my $TicketObject   = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject     = $Kernel::OM->Get('Kernel::System::Time');
    my $TypeObject     = $Kernel::OM->Get('Kernel::System::Type');
    my $UserObject     = $Kernel::OM->Get('Kernel::System::User');

    my $ValidAgent = 0;
    if (
        defined( $ConfigObject->Get('Stats::UseInvalidAgentInStats') )
        && $ConfigObject->Get('Stats::UseInvalidAgentInStats') == 0
    ) {
        $ValidAgent = 1;
    }

    # get queue list
    my %QueueList;
    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'QueueIDs'}
        || $Param{SelectedObjectAttributes}->{'CreatedQueueIDs'}
    ) {
        %QueueList = $QueueObject->GetAllQueues();
    }

    # get state list
    my %StateList;
    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'StateIDs'}
        || $Param{SelectedObjectAttributes}->{'CreatedStateIDs'}
    ) {
        %StateList = $StateObject->StateList(
            UserID => 1,
        );
    }

    # get state type list
    my %StateTypeList;
    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'StateTypeIDs'}
    ) {
        %StateTypeList = $StateObject->StateTypeList(
            UserID => 1,
        );
    }

    # get priority list
    my %PriorityList;
    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'PriorityIDs'}
        || $Param{SelectedObjectAttributes}->{'CreatedPriorityIDs'}
    ) {
        %PriorityList = $PriorityObject->PriorityList(
            UserID => 1,
        );
    }

    # get lock list
    my %LockList;
    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'LockIDs'}
    ) {
        %LockList = $LockObject->LockList(
            UserID => 1,
        );
    }

    # get current time to fix bug#3830
    my $Today;
    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'CreateTime'}
        || $Param{SelectedObjectAttributes}->{'LastChangeTime'}
        || $Param{SelectedObjectAttributes}->{'ChangeTime'}
        || $Param{SelectedObjectAttributes}->{'CloseTime2'}
        || $Param{SelectedObjectAttributes}->{'EscalationTime'}
        || $Param{SelectedObjectAttributes}->{'EscalationResponseTime'}
        || $Param{SelectedObjectAttributes}->{'EscalationUpdateTime'}
        || $Param{SelectedObjectAttributes}->{'EscalationSolutionTime'}
    ) {
        my $TimeStamp = $TimeObject->CurrentTimestamp();
        my ($Date) = split /\s+/, $TimeStamp;
        $Today = sprintf "%s 23:59:59", $Date;
    }

    my @ObjectAttributes = ();

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'KindsOfReporting'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('Evaluation by'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 0,
                UseAsRestriction => 1,
                Element          => 'KindsOfReporting',
                Block            => 'MultiSelectField',
                Translation      => 1,
                Sort             => 'IndividualKey',
                SortIndividual   => $Self->_SortedKindsOfReporting(),
                Values           => $Self->_KindsOfReporting(),
            }
        );
    }

    if ( $ConfigObject->Get('Ticket::Type') ) {
        # add ticket type list
        if (
            ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
            || $Param{SelectedObjectAttributes}->{'TypeIDs'}
        ) {
            my %Type = $TypeObject->TypeList(
                UserID => 1,
            );

            push(
                @ObjectAttributes,
                {
                    Name             => Translatable('Type'),
                    UseAsXvalue      => 1,
                    UseAsValueSeries => 1,
                    UseAsRestriction => 1,
                    Element          => 'TypeIDs',
                    Block            => 'MultiSelectField',
                    Translation      => $ConfigObject->Get('Ticket::TypeTranslation'),
                    Values           => \%Type,
                }
            );
        }
    }

    if ( $ConfigObject->Get('Ticket::Service') ) {
        # add service list
        if (
            ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
            || $Param{SelectedObjectAttributes}->{'ServiceIDs'}
        ) {
            my %Service = $ServiceObject->ServiceList(
                KeepChildren => $ConfigObject->Get('Ticket::Service::KeepChildren'),
                UserID       => 1,
            );

            push(
                @ObjectAttributes,
                {
                    Name             => Translatable('Service'),
                    UseAsXvalue      => 1,
                    UseAsValueSeries => 1,
                    UseAsRestriction => 1,
                    Element          => 'ServiceIDs',
                    Block            => 'MultiSelectField',
                    Translation      => $ConfigObject->Get('Ticket::ServiceTranslation'),
                    TreeView         => 1,
                    Values           => \%Service,
                }
            );
        }

        # add sla list
        if (
            ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
            || $Param{SelectedObjectAttributes}->{'SLAIDs'}
        ) {
            my %SLA = $SLAObject->SLAList(
                UserID => 1,
            );

            push(
                @ObjectAttributes,
                {
                    Name             => Translatable('SLA'),
                    UseAsXvalue      => 1,
                    UseAsValueSeries => 1,
                    UseAsRestriction => 1,
                    Element          => 'SLAIDs',
                    Block            => 'MultiSelectField',
                    Translation      => $ConfigObject->Get('Ticket::SLATranslation'),
                    Values           => \%SLA,
                }
            );
        }
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'QueueIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('Queue'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'QueueIDs',
                Block            => 'MultiSelectField',
                Translation      => 0,
                TreeView         => 1,
                Values           => \%QueueList,
            }
        );
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'StateIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('State'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'StateIDs',
                Block            => 'MultiSelectField',
                Values           => \%StateList,
            }
        );
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'StateTypeIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('State Type'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'StateTypeIDs',
                Block            => 'MultiSelectField',
                Values           => \%StateTypeList,
            }
        );
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'PriorityIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('Priority'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'PriorityIDs',
                Block            => 'MultiSelectField',
                Values           => \%PriorityList,
            }
        );
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'CreatedQueueIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('Created in Queue'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'CreatedQueueIDs',
                Block            => 'MultiSelectField',
                Translation      => 0,
                TreeView         => 1,
                Values           => \%QueueList,
            }
        );
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'CreatedStateIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('Created State'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'CreatedStateIDs',
                Block            => 'MultiSelectField',
                Values           => \%StateList,
            }
        );
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'CreatedPriorityIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('Created Priority'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'CreatedPriorityIDs',
                Block            => 'MultiSelectField',
                Values           => \%PriorityList,
            }
        );
    }

    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'LockIDs'}
    ) {
        push(
            @ObjectAttributes,
            {
                Name             => Translatable('Lock'),
                UseAsXvalue      => 1,
                UseAsValueSeries => 1,
                UseAsRestriction => 1,
                Element          => 'LockIDs',
                Block            => 'MultiSelectField',
                Values           => \%LockList,
            }
        );
    }

    my @ObjectAttributesFix = (
        {
            Name             => Translatable('Title'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'Title',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('CustomerUserLogin (complex search)'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'CustomerUserLogin',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('CustomerUserLogin (exact match)'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'CustomerUserLoginRaw',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('From'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'From',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('To'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'To',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('Cc'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'Cc',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('Subject'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'Subject',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('Text'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'Body',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('Ticket Create Time'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'CreateTime',
            TimePeriodFormat => 'DateInputFormat',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketCreateTimeNewerDate',
                TimeStop  => 'TicketCreateTimeOlderDate',
            },
        },
        {
            Name             => Translatable('Last changed times'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'LastChangeTime',
            TimePeriodFormat => 'DateInputFormat',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketLastChangeTimeNewerDate',
                TimeStop  => 'TicketLastChangeTimeOlderDate',
            },
        },
        {
            Name             => Translatable('Change times'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'ChangeTime',
            TimePeriodFormat => 'DateInputFormat',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketChangeTimeNewerDate',
                TimeStop  => 'TicketChangeTimeOlderDate',
            },
        },
        {
            Name             => Translatable('Ticket Close Time'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'CloseTime2',
            TimePeriodFormat => 'DateInputFormat',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketCloseTimeNewerDate',
                TimeStop  => 'TicketCloseTimeOlderDate',
            },
        },
        {
            Name             => Translatable('Escalation'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'EscalationTime',
            TimePeriodFormat => 'DateInputFormatLong',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketEscalationTimeNewerDate',
                TimeStop  => 'TicketEscalationTimeOlderDate',
            },
        },
        {
            Name             => Translatable('Escalation - First Response Time'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'EscalationResponseTime',
            TimePeriodFormat => 'DateInputFormatLong',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketEscalationResponseTimeNewerDate',
                TimeStop  => 'TicketEscalationResponseTimeOlderDate',
            },
        },
        {
            Name             => Translatable('Escalation - Update Time'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'EscalationUpdateTime',
            TimePeriodFormat => 'DateInputFormatLong',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketEscalationUpdateTimeNewerDate',
                TimeStop  => 'TicketEscalationUpdateTimeOlderDate',
            },
        },
        {
            Name             => Translatable('Escalation - Solution Time'),
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => 'EscalationSolutionTime',
            TimePeriodFormat => 'DateInputFormatLong',
            Block            => 'Time',
            TimeStop         => $Today,
            Values           => {
                TimeStart => 'TicketEscalationSolutionTimeNewerDate',
                TimeStop  => 'TicketEscalationSolutionTimeOlderDate',
            },
        },
    );
    for my $Attribute ( @ObjectAttributesFix ) {
        if (
            ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
            || $Param{SelectedObjectAttributes}->{ $Attribute->{'Element'} }
        ) {
            push( @ObjectAttributes, $Attribute );
        }
    }

    if ( $ConfigObject->Get('Stats::UseAgentElementInStats') ) {
        # get user list
        if (
            ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
            || $Param{SelectedObjectAttributes}->{'OwnerIDs'}
            || $Param{SelectedObjectAttributes}->{'CreatedUserIDs'}
            || $Param{SelectedObjectAttributes}->{'ResponsibleIDs'}
        ) {
            my %UserList = $UserObject->UserList(
                Type          => 'Long',
                Valid         => $ValidAgent,
                NoOutOfOffice => 1,
            );

            my @ObjectAttributesUser = (
                    {
                        Name             => Translatable('Agent/Owner'),
                        UseAsXvalue      => 1,
                        UseAsValueSeries => 1,
                        UseAsRestriction => 1,
                        Element          => 'OwnerIDs',
                        Block            => 'MultiSelectField',
                        Translation      => 0,
                        Values           => \%UserList,
                    },
                    {
                        Name             => Translatable('Created by Agent/Owner'),
                        UseAsXvalue      => 1,
                        UseAsValueSeries => 1,
                        UseAsRestriction => 1,
                        Element          => 'CreatedUserIDs',
                        Block            => 'MultiSelectField',
                        Translation      => 0,
                        Values           => \%UserList,
                    },
                    {
                        Name             => Translatable('Responsible'),
                        UseAsXvalue      => 1,
                        UseAsValueSeries => 1,
                        UseAsRestriction => 1,
                        Element          => 'ResponsibleIDs',
                        Block            => 'MultiSelectField',
                        Translation      => 0,
                        Values           => \%UserList,
                    }
            );
            for my $Attribute ( @ObjectAttributesUser ) {
                if (
                    ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
                    || $Param{SelectedObjectAttributes}->{ $Attribute->{'Element'} }
                ) {
                    push( @ObjectAttributes, $Attribute );
                }
            }
        }
    }

    if ( $ConfigObject->Get('Stats::CustomerIDAsMultiSelect') ) {
        if (
            ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
            || $Param{SelectedObjectAttributes}->{'CustomerID'}
        ) {
            # Get CustomerID
            # (This way also can be the solution for the CustomerUserID)
            $DBObject->Prepare(
                SQL => "SELECT DISTINCT customer_id FROM ticket",
            );

            # fetch the result
            my %CustomerID;
            while ( my @Row = $DBObject->FetchrowArray() ) {
                if ( $Row[0] ) {
                    $CustomerID{ $Row[0] } = $Row[0];
                }
            }

            push(
                @ObjectAttributes,
                {
                    Name             => Translatable('CustomerID'),
                    UseAsXvalue      => 1,
                    UseAsValueSeries => 1,
                    UseAsRestriction => 1,
                    Element          => 'CustomerID',
                    Block            => 'MultiSelectField',
                    Values           => \%CustomerID,
                }
            );
        }
    }
    else {
        my @ObjectAttributesCustomerID = (
            {
                Name             => Translatable('CustomerID (complex search)'),
                UseAsXvalue      => 0,
                UseAsValueSeries => 0,
                UseAsRestriction => 1,
                Element          => 'CustomerID',
                Block            => 'InputField',
            },
            {
                Name             => Translatable('CustomerID (exact match)'),
                UseAsXvalue      => 0,
                UseAsValueSeries => 0,
                UseAsRestriction => 1,
                Element          => 'CustomerIDRaw',
                Block            => 'InputField',
            },
        );
        for my $Attribute ( @ObjectAttributesCustomerID ) {
            if (
                ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
                || $Param{SelectedObjectAttributes}->{ $Attribute->{'Element'} }
            ) {
                push( @ObjectAttributes, $Attribute );
            }
        }
    }

    if ( $ConfigObject->Get('Ticket::ArchiveSystem') ) {
        if (
            ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
            || $Param{SelectedObjectAttributes}->{'SearchInArchive'}
        ) {
            push(
                @ObjectAttributes,
                {
                    Name             => Translatable('Archive Search'),
                    UseAsXvalue      => 0,
                    UseAsValueSeries => 0,
                    UseAsRestriction => 1,
                    Element          => 'SearchInArchive',
                    Block            => 'SelectField',
                    Translation      => 1,
                    Values           => {
                        ArchivedTickets    => Translatable('Archived tickets'),
                        NotArchivedTickets => Translatable('Unarchived tickets'),
                        AllTickets         => Translatable('All tickets'),
                    }
                }
            );
        }
    }

    # cycle trough the ticket dynamic fields
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if ( !IsHashRefWithData( $DynamicFieldConfig ) );
        next DYNAMICFIELD if (
            ref( $Param{SelectedObjectAttributes} ) eq 'HASH'
            && !$Param{SelectedObjectAttributes}->{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
        );

        # skip all fields not designed to be supported by statistics
        my $IsStatsCondition = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsStatsCondition',
        );
        next DYNAMICFIELD if ( !$IsStatsCondition );

        my $PossibleValuesFilter;
        my $IsACLReducible = $BackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsACLReducible',
        );
        if ( $IsACLReducible ) {
            # get PossibleValues
            my $PossibleValues = $BackendObject->PossibleValuesGet(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            # convert possible values key => value to key => key for ACLs using a Hash slice
            my %AclData = %{ $PossibleValues || {} };
            @AclData{ keys( %AclData ) } = keys( %AclData );

            # set possible values filter from ACLs
            my $ACL = $TicketObject->TicketAcl(
                Action        => 'AgentStats',
                Type          => 'DynamicField_' . $DynamicFieldConfig->{Name},
                ReturnType    => 'Ticket',
                ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data          => \%AclData || {},
                UserID        => 1,
            );
            if ( $ACL ) {
                my %Filter = $TicketObject->TicketAclData();

                # convert Filer key => key back to key => value using map
                %{$PossibleValuesFilter} = map { $_ => $PossibleValues->{$_} } keys( %Filter );
            }
        }

        # get field parameter
        my $DynamicFieldStatsParameter = $BackendObject->StatsFieldParameterBuild(
            DynamicFieldConfig   => $DynamicFieldConfig,
            PossibleValuesFilter => $PossibleValuesFilter,
        );

        if ( IsHashRefWithData( $DynamicFieldStatsParameter ) ) {
            # backward compatibility
            if ( !$DynamicFieldStatsParameter->{Block} ) {
                $DynamicFieldStatsParameter->{Block} = 'InputField';
                if ( IsHashRefWithData( $DynamicFieldStatsParameter->{Values} ) ) {
                    $DynamicFieldStatsParameter->{Block} = 'MultiSelectField';
                }
            }

            if ( $DynamicFieldStatsParameter->{Block} eq 'Time' ) {
                # create object attributes (date/time fields)
                my $TimePeriodFormat = $DynamicFieldStatsParameter->{TimePeriodFormat} || 'DateInputFormatLong';

                push(
                    @ObjectAttributes,
                    {
                        Name             => $DynamicFieldStatsParameter->{Name},
                        UseAsXvalue      => 1,
                        UseAsValueSeries => 1,
                        UseAsRestriction => 1,
                        Element          => $DynamicFieldStatsParameter->{Element},
                        TimePeriodFormat => $TimePeriodFormat,
                        Block            => $DynamicFieldStatsParameter->{Block},
                        TimePeriodFormat => $TimePeriodFormat,
                        Values           => {
                            TimeStart => $DynamicFieldStatsParameter->{Element} . '_GreaterThanEquals',
                            TimeStop  => $DynamicFieldStatsParameter->{Element} . '_SmallerThanEquals',
                        },
                    }
                );
            }
            elsif ( $DynamicFieldStatsParameter->{Block} eq 'MultiSelectField' ) {
                push(
                    @ObjectAttributes,
                    {
                        Name             => $DynamicFieldStatsParameter->{Name},
                        UseAsXvalue      => 1,
                        UseAsValueSeries => 1,
                        UseAsRestriction => 1,
                        Element          => $DynamicFieldStatsParameter->{Element},
                        Block            => $DynamicFieldStatsParameter->{Block},
                        Values           => $DynamicFieldStatsParameter->{Values},
                        Translation      => 0,
                        IsDynamicField   => 1,
                        ShowAsTree       => $DynamicFieldConfig->{Config}->{TreeView} || 0,
                    }
                );
            }
            else {
                push(
                    @ObjectAttributes,
                    {
                        Name             => $DynamicFieldStatsParameter->{Name},
                        UseAsXvalue      => 0,
                        UseAsValueSeries => 0,
                        UseAsRestriction => 1,
                        Element          => $DynamicFieldStatsParameter->{Element},
                        Block            => $DynamicFieldStatsParameter->{Block},
                    }
                );
            }
        }
    }

    return @ObjectAttributes;
}

# REMARK: is the same code as in TicketAccountedTime.pm
sub GetStatTablePreview {
    my ( $Self, %Param ) = @_;

    my @StatArray;

    if (
        $Param{XValue}->{Element}
        && $Param{XValue}->{Element} eq 'KindsOfReporting'
    ) {
        for my $Row ( sort( keys( %{ $Param{TableStructure} } ) ) ) {
            my @ResultRow = ( $Row );
            for ( @{ $Param{XValue}->{SelectedValues} } ) {
                push( @ResultRow, int rand 50 );
            }
            push( @StatArray, \@ResultRow );
        }
    }
    else {
        for my $Row ( sort( keys( %{ $Param{TableStructure} } ) ) ) {
            my @ResultRow = ( $Row) ;
            for my $Cell ( @{ $Param{TableStructure}->{ $Row } } ) {
                push( @ResultRow, int rand 50 );
            }
            push( @StatArray, \@ResultRow );
        }
    }

    return @StatArray;
}

# REMARK: is the same code as in TicketAccountedTime.pm
sub GetStatTable {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # Map the CustomerID search parameter to CustomerIDRaw search parameter for the
    #   exact search match, if the 'Stats::CustomerIDAsMultiSelect' is active.
    if ( $ConfigObject->Get('Stats::CustomerIDAsMultiSelect') ) {

        if ( defined( $Param{Restrictions}->{CustomerID} ) ) {
            $Param{Restrictions}->{CustomerIDRaw} = $Param{Restrictions}->{CustomerID};
        }
        else {
            $Param{CustomerIDRaw} = $Param{CustomerID};
        }
    }

    my @StatArray;
    if (
        $Param{XValue}->{Element}
        && $Param{XValue}->{Element} eq 'KindsOfReporting'
    ) {
        for my $Row ( sort( keys( %{ $Param{TableStructure} } ) ) ) {
            my @ResultRow        = ( $Row );
            my %SearchAttributes = ( %{ $Param{TableStructure}->{$Row}->[0] } );

            my %Reporting = $Self->_ReportingValues(
                SearchAttributes         => \%SearchAttributes,
                SelectedKindsOfReporting => $Param{XValue}->{SelectedValues},
            );

            KIND:
            for my $Kind ( @{ $Self->_SortedKindsOfReporting() } ) {
                next KIND if ( !defined( $Reporting{ $Kind } ) );
                push( @ResultRow, $Reporting{ $Kind } );
            }
            push( @StatArray, \@ResultRow );
        }
    }
    else {
        my $KindsOfReportingRef = $Self->_KindsOfReporting();
        $Param{Restrictions}->{KindsOfReporting} ||= ['TotalTime'];
        my $NumberOfReportingKinds   = scalar( @{ $Param{Restrictions}->{KindsOfReporting} } );
        my $SelectedKindsOfReporting = $Param{Restrictions}->{KindsOfReporting};

        delete( $Param{Restrictions}->{KindsOfReporting} );
        for my $Row ( sort( keys( %{ $Param{TableStructure} } ) ) ) {
            my @ResultRow = ( $Row );

            for my $Cell ( @{ $Param{TableStructure}->{ $Row } } ) {
                my %SearchAttributes = %{ $Cell };
                my %Reporting        = $Self->_ReportingValues(
                    SearchAttributes         => \%SearchAttributes,
                    SelectedKindsOfReporting => $SelectedKindsOfReporting,
                );

                my $CellContent = '';

                if ( $NumberOfReportingKinds == 1 ) {
                    my @Values = values( %Reporting );
                    $CellContent = $Values[0];
                }
                else {
                    KIND:
                    for my $Kind ( @{ $Self->_SortedKindsOfReporting() } ) {
                        next KIND if ( !defined( $Reporting{ $Kind } ) );
                        $CellContent .= $Reporting{ $Kind } . ' (' . $KindsOfReportingRef->{ $Kind } . '), ';
                    }
                }
                push( @ResultRow, $CellContent );
            }
            push( @StatArray, \@ResultRow );
        }
    }

    return @StatArray;
}

# REMARK: is the same code as in TicketAccountedTime.pm
sub GetHeaderLine {
    my ( $Self, %Param ) = @_;

    if ( $Param{XValue}->{Element} eq 'KindsOfReporting' ) {

        my %Selected = map { $_ => 1 } @{ $Param{XValue}->{SelectedValues} };

        # get language object
        my $LanguageObject = $Kernel::OM->Get('Kernel::Language');

        my $Attributes = $Self->_KindsOfReporting();
        my @HeaderLine = ( $LanguageObject->Translate('Evaluation by') );
        my $SortedRef  = $Self->_SortedKindsOfReporting();

        ATTRIBUTE:
        for my $Attribute ( @{$SortedRef} ) {
            next ATTRIBUTE if ( !$Selected{ $Attribute } );
            push( @HeaderLine, $LanguageObject->Translate( $Attributes->{ $Attribute } ) );
        }
        return \@HeaderLine;

    }

    return;
}

sub ExportWrapper {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    my $QueueObject    = $Kernel::OM->Get('Kernel::System::Queue');
    my $StateObject    = $Kernel::OM->Get('Kernel::System::State');
    my $UserObject     = $Kernel::OM->Get('Kernel::System::User');

    # wrap ids to used spelling
    for my $Use ( qw(UseAsValueSeries UseAsRestriction UseAsXvalue) ) {
        ELEMENT:
        for my $Element ( @{ $Param{ $Use } } ) {
            next ELEMENT if (
                !$Element
                || !$Element->{SelectedValues}
            );

            my $ElementName = $Element->{Element};
            my $Values      = $Element->{SelectedValues};

            if (
                $ElementName eq 'QueueIDs'
                || $ElementName eq 'CreatedQueueIDs'
            ) {
                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );

                    $ID->{Content} = $QueueObject->QueueLookup(
                        QueueID => $ID->{Content}
                    );
                }
            }
            elsif (
                $ElementName eq 'StateIDs'
                || $ElementName eq 'CreatedStateIDs'
            ) {
                my %StateList = $StateObject->StateList(
                    UserID => 1
                );

                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );

                    $ID->{Content} = $StateList{ $ID->{Content} };
                }
            }
            elsif (
                $ElementName eq 'PriorityIDs'
                || $ElementName eq 'CreatedPriorityIDs'
            ) {
                my %PriorityList = $PriorityObject->PriorityList(
                    UserID => 1
                );

                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );
                    $ID->{Content} = $PriorityList{ $ID->{Content} };
                }
            }
            elsif (
                $ElementName eq 'OwnerIDs'
                || $ElementName eq 'CreatedUserIDs'
                || $ElementName eq 'ResponsibleIDs'
            ) {
                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );

                    $ID->{Content} = $UserObject->UserLookup(
                        UserID => $ID->{Content}
                    );
                }
            }

            # locks and statustype don't have to wrap because they are never different
        }
    }

    return \%Param;
}

sub ImportWrapper {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    my $QueueObject    = $Kernel::OM->Get('Kernel::System::Queue');
    my $StateObject    = $Kernel::OM->Get('Kernel::System::State');
    my $UserObject     = $Kernel::OM->Get('Kernel::System::User');

    # wrap used spelling to ids
    for my $Use ( qw(UseAsValueSeries UseAsRestriction UseAsXvalue) ) {
        ELEMENT:
        for my $Element ( @{ $Param{ $Use } } ) {
            next ELEMENT if (
                !$Element
                || !$Element->{SelectedValues}
            );

            my $ElementName = $Element->{Element};
            my $Values      = $Element->{SelectedValues};

            if (
                $ElementName eq 'QueueIDs'
                || $ElementName eq 'CreatedQueueIDs'
            ) {
                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );

                    if (
                        $QueueObject->QueueLookup(
                            Queue => $ID->{Content}
                        )
                    ) {
                        $ID->{Content} = $QueueObject->QueueLookup(
                            Queue => $ID->{Content}
                        );
                    }
                    else {
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message  => "Import: Can' find the queue $ID->{Content}!"
                        );
                        $ID = undef;
                    }
                }
            }
            elsif (
                $ElementName eq 'StateIDs'
                || $ElementName eq 'CreatedStateIDs'
            ) {
                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );

                    my %State = $StateObject->StateGet(
                        Name  => $ID->{Content},
                        Cache => 1,
                    );
                     if ( $State{ID} ) {
                        $ID->{Content} = $State{ID};
                    }
                    else {
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message  => "Import: Can' find state $ID->{Content}!"
                        );
                        $ID = undef;
                    }
                }
            }
            elsif (
                $ElementName eq 'PriorityIDs'
                || $ElementName eq 'CreatedPriorityIDs'
            ) {
                my %PriorityList = $PriorityObject->PriorityList(
                    UserID => 1
                );

                my %PriorityIDs;
                for my $Key ( keys( %PriorityList ) ) {
                    $PriorityIDs{ $PriorityList{ $Key } } = $Key;
                }
                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );

                    if ( $PriorityIDs{ $ID->{Content} } ) {
                        $ID->{Content} = $PriorityIDs{ $ID->{Content} };
                    }
                    else {
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message  => "Import: Can' find priority $ID->{Content}!"
                        );
                        $ID = undef;
                    }
                }
            }
            elsif (
                $ElementName eq 'OwnerIDs'
                || $ElementName eq 'CreatedUserIDs'
                || $ElementName eq 'ResponsibleIDs'
            ) {
                ID:
                for my $ID ( @{ $Values } ) {
                    next ID if ( !$ID );

                    if (
                        $UserObject->UserLookup(
                            UserLogin => $ID->{Content}
                        )
                    ) {
                        $ID->{Content} = $UserObject->UserLookup(
                            UserLogin => $ID->{Content}
                        );
                    }
                    else {
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message  => "Import: Can' find user $ID->{Content}!"
                        );
                        $ID = undef;
                    }
                }
            }

            # locks and status type don't have to wrap because they are never different
        }
    }

    return \%Param;
}

sub _ReportingValues {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $DBObject      = $Kernel::OM->Get('Kernel::System::DB');
    my $BackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject    = $Kernel::OM->Get('Kernel::System::Time');

    my $SearchAttributes = $Param{SearchAttributes};

    # escape search attributes for ticket search
    my %AttributesToEscape = (
        'CustomerID' => 1,
        'Title'      => 1,
    );

    # get ticket search relevant attributes
    my %TicketSearch;
    ATTRIBUTE:
    for my $Attribute ( @{ $Self->_AllowedTicketSearchAttributes() } ) {

        # special handling for dynamic field date/time fields
        if ( $Attribute =~ m{ \A DynamicField_ }xms ) {
            SEARCHATTRIBUTE:
            for my $SearchAttribute ( sort( keys( %{ $SearchAttributes } ) ) ) {
                next SEARCHATTRIBUTE if( $SearchAttribute !~ m{ \A \Q$Attribute\E _ }xms );

                $TicketSearch{ $SearchAttribute } = $SearchAttributes->{ $SearchAttribute };

                # don't exist loop
                # there can be more than one attribute param per allowed attribute
            }
        }
        else {
            next ATTRIBUTE if ( !$SearchAttributes->{ $Attribute } );

            $TicketSearch{ $Attribute } = $SearchAttributes->{ $Attribute };
        }

        next ATTRIBUTE if ( !$AttributesToEscape{ $Attribute } );

        # escape search parameters for ticket search
        if ( ref( $TicketSearch{ $Attribute } ) ) {
            if ( ref( $TicketSearch{ $Attribute } ) eq 'ARRAY' ) {
                $TicketSearch{ $Attribute } = [
                    map { $DBObject->QueryStringEscape( QueryString => $_ ) }
                        @{ $TicketSearch{ $Attribute } }
                ];
            }
        }
        else {
            $TicketSearch{ $Attribute } = $DBObject->QueryStringEscape(
                QueryString => $TicketSearch{ $Attribute }
            );
        }
    }

    # do nothing, if there are no search attributes
    return map { $_ => 0 } @{ $Param{SelectedKindsOfReporting} } if ( !%TicketSearch );

    for my $ParameterName ( sort( keys( %TicketSearch ) ) ) {
        if ( $ParameterName =~ m{ \A DynamicField_ ( [a-zA-Z\d]+ ) (?: _ ( [a-zA-Z\d]+ ) )? \z }xms ) {
            my $FieldName = $1;
            my $Operator  = $2;

            # loop over the dynamic fields configured
            DYNAMICFIELD:
            for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
                next DYNAMICFIELD if ( !IsHashRefWithData( $DynamicFieldConfig ) );
                next DYNAMICFIELD if ( !$DynamicFieldConfig->{Name} );

                # skip all fields that do not match with current field name
                # without the 'DynamicField_' prefix
                next DYNAMICFIELD if ( $DynamicFieldConfig->{Name} ne $FieldName );

                # skip all fields not designed to be supported by statistics
                my $IsStatsCondition = $BackendObject->HasBehavior(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Behavior           => 'IsStatsCondition',
                );
                next DYNAMICFIELD if ( !$IsStatsCondition );

                # get new search parameter
                my $DynamicFieldStatsSearchParameter = $BackendObject->StatsSearchFieldParameterBuild(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    Value              => $TicketSearch{ $ParameterName },
                    Operator           => $Operator,
                );

                # add new search parameter
                if ( !IsHashRefWithData( $TicketSearch{ 'DynamicField_' . $FieldName } ) ) {
                    $TicketSearch{ 'DynamicField_' . $FieldName } = $DynamicFieldStatsSearchParameter;
                }

                # extend search parameter
                elsif ( IsHashRefWithData( $DynamicFieldStatsSearchParameter ) ) {
                    $TicketSearch{ 'DynamicField_' . $FieldName } = {
                        %{ $TicketSearch{ 'DynamicField_' . $FieldName } },
                        %{ $DynamicFieldStatsSearchParameter },
                    };
                }
            }
        }
    }

    if ( $ConfigObject->Get('Ticket::ArchiveSystem') ) {
        $SearchAttributes->{SearchInArchive} ||= '';

        if ( $SearchAttributes->{SearchInArchive} eq 'AllTickets' ) {
            $TicketSearch{ArchiveFlags} = [ 'y', 'n' ];
        }
        elsif ( $SearchAttributes->{SearchInArchive} eq 'ArchivedTickets' ) {
            $TicketSearch{ArchiveFlags} = ['y'];
        }
        else {
            $TicketSearch{ArchiveFlags} = ['n'];
        }
    }

    # get the involved tickets
    my @TicketIDs = $TicketObject->TicketSearch(
        %TicketSearch,
        UserID     => 1,
        Result     => 'ARRAY',
        Permission => 'ro',
        Limit      => 100_000_000,
        StateType  => 'Closed',
    );

    # do nothing, if there are no tickets
    return map { $_ => 0 } @{ $Param{SelectedKindsOfReporting} } if ( !@TicketIDs );

    my $Counter        = 0;
    my $CounterAllOver = 0;

    my %SolutionAllOver;
    my %Solution;
    my %SolutionWorkingTime;
    my %Response;
    my %ResponseWorkingTime;

    TICKET:
    for my $TicketID ( @TicketIDs ) {
        $CounterAllOver += 1;

        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $TicketID,
            UserID        => 1,
            Extended      => 1,
            DynamicFields => 0,
        );

        my $SolutionTime = $TimeObject->TimeStamp2SystemTime(
            String => $Ticket{SolutionTime},
        );

        $SolutionAllOver{ $TicketID } = $SolutionTime - $Ticket{CreateTimeUnix};

        next TICKET if ( !defined( $Ticket{SolutionInMin} ) );

        # now collect only data of tickets which are affected by a escalation config
        $Counter += 1;
        $Solution{ $TicketID }            = $SolutionAllOver{ $TicketID };
        $SolutionWorkingTime{ $TicketID } = $Ticket{SolutionInMin};

        if ( $Ticket{FirstResponse} ) {
            my $FirstResponse = $TimeObject->TimeStamp2SystemTime(
                String => $Ticket{FirstResponse},
            );

            $Response{ $TicketID }            = $FirstResponse - $Ticket{CreateTimeUnix};
            $ResponseWorkingTime{ $TicketID } = $Ticket{FirstResponseInMin};
        }
        else {
            $Response{ $TicketID }            = 0;
            $ResponseWorkingTime{ $TicketID } = 0;
        }
    }

    my %Reporting;
    my %SelectedKindsOfReporting = map { $_ => 1 } @{ $Param{SelectedKindsOfReporting} };

    # different solution averages
    if ( $SelectedKindsOfReporting{SolutionAverageAllOver} ) {
        $Reporting{SolutionAverageAllOver} = $Self->_GetAverage(
            Count   => $CounterAllOver,
            Content => \%SolutionAllOver,
        );
    }
    if ( $SelectedKindsOfReporting{SolutionAverage} ) {
        $Reporting{SolutionAverage} = $Self->_GetAverage(
            Count   => $Counter,
            Content => \%Solution,
        );
    }
    if ( $SelectedKindsOfReporting{SolutionWorkingTimeAverage} ) {
        $Reporting{SolutionWorkingTimeAverage} = $Self->_GetAverage(
            Count   => $Counter,
            Content => \%SolutionWorkingTime,
        );
    }

    # response average
    if ( $SelectedKindsOfReporting{ResponseAverage} ) {
        $Reporting{ResponseAverage} = $Self->_GetAverage(
            Count   => $Counter,
            Content => \%Response,
        );
    }
    if ( $SelectedKindsOfReporting{ResponseWorkingTimeAverage} ) {
        $Reporting{ResponseWorkingTimeAverage} = $Self->_GetAverage(
            Count   => $Counter,
            Content => \%ResponseWorkingTime,
        );
    }

    # min max for standard solution
    if ( $SelectedKindsOfReporting{SolutionMinTimeAllOver} ) {
        if ( %SolutionAllOver ) {
            $Reporting{SolutionMinTimeAllOver} = ( sort { $a <=> $b } values( %SolutionAllOver ) )[0];
        }
        else {
            $Reporting{SolutionMinTimeAllOver} = 0;
        }
    }
    if ( $SelectedKindsOfReporting{SolutionMaxTimeAllOver} ) {
        if ( %SolutionAllOver ) {
            $Reporting{SolutionMaxTimeAllOver} = ( sort { $b <=> $a } values( %SolutionAllOver ) )[0];
        }
        else {
            $Reporting{SolutionMaxTimeAllOver} = 0;
        }
    }

    # min max for solution time with configured escalation
    if ( $SelectedKindsOfReporting{SolutionMinTime} ) {
        if ( %Solution ) {
            $Reporting{SolutionMinTime} = ( sort { $a <=> $b } values( %Solution ) )[0];
        }
        else {
            $Reporting{SolutionMinTime} = 0;
        }
    }
    if ( $SelectedKindsOfReporting{SolutionMaxTime} ) {
        if ( %Solution ) {
            $Reporting{SolutionMaxTime} = ( sort { $b <=> $a } values( %Solution ) )[0];
        }
        else {
            $Reporting{SolutionMaxTime} = 0;
        }
    }

    # min max for solution working time
    if ( $SelectedKindsOfReporting{SolutionMinWorkingTime} ) {
        if ( %SolutionWorkingTime ) {
            $Reporting{SolutionMinWorkingTime} = ( sort { $a <=> $b } values( %SolutionWorkingTime ) )[0];
        }
        else {
            $Reporting{SolutionMinWorkingTime} = 0;
        }
    }
    if ( $SelectedKindsOfReporting{SolutionMaxWorkingTime} ) {
        if ( %SolutionWorkingTime ) {
            $Reporting{SolutionMaxWorkingTime} = ( sort { $b <=> $a } values( %SolutionWorkingTime ) )[0];
        }
        else {
            $Reporting{SolutionMaxWorkingTime} = 0;
        }
    }

    # min max for response time
    if ( $SelectedKindsOfReporting{ResponseMinTime} ) {
        if ( %Response ) {
            $Reporting{ResponseMinTime} = ( sort { $a <=> $b } values( %Response ) )[0];
        }
        else {
            $Reporting{ResponseMinTime} = 0;
        }
    }
    if ( $SelectedKindsOfReporting{ResponseMaxTime} ) {
        if ( %Response ) {
            $Reporting{ResponseMaxTime} = ( sort { $b <=> $a } values( %Response ) )[0];
        }
        else {
            $Reporting{ResponseMaxTime} = 0;
        }
    }

    # min max for response working time
    if ( $SelectedKindsOfReporting{ResponseMinWorkingTime} ) {
        if ( %ResponseWorkingTime ) {
            $Reporting{ResponseMinWorkingTime} = ( sort { $a <=> $b } values( %ResponseWorkingTime ) )[0];
        }
        else {
            $Reporting{ResponseMinWorkingTime} = 0;
        }
    }
    if ( $SelectedKindsOfReporting{ResponseMaxWorkingTime} ) {
        if ( %ResponseWorkingTime ) {
            $Reporting{ResponseMaxWorkingTime} = ( sort { $b <=> $a } values( %ResponseWorkingTime ) )[0];
        }
        else {
            $Reporting{ResponseMaxWorkingTime} = 0;
        }
    }

    # add the number of values
    if ( $SelectedKindsOfReporting{NumberOfTickets} ) {
        $Reporting{NumberOfTickets} = $Counter;
    }
    if ( $SelectedKindsOfReporting{NumberOfTicketsAllOver} ) {
        $Reporting{NumberOfTicketsAllOver} = $CounterAllOver;
    }

    # get the correct data format
    # convert seconds in minutes

    for my $Key (
        qw(
            ResponseMaxTime ResponseMinTime SolutionMaxTime SolutionMinTime SolutionMaxTimeAllOver
            SolutionMinTimeAllOver SolutionAverageAllOver SolutionAverage ResponseAverage
        )
    ) {
        if ( defined( $Reporting{ $Key } ) ) {
            $Reporting{ $Key } = int( $Reporting{ $Key } / 60 + 0.5 );
        }
    }

    # convert min in hh:mm
    KEY:
    for my $Key ( sort( keys( %Reporting ) ) ){
        next KEY if (
            $Key eq 'NumberOfTickets'
            || $Key eq 'NumberOfTicketsAllOver'
        );

        my $Hours   = int( $Reporting{ $Key } / 60 );
        my $Minutes = $Reporting{ $Key } % 60;

        $Reporting{ $Key } = $Hours . 'h ' . $Minutes . 'm';
    }

    return %Reporting;
}

sub _GetAverage {
    my ( $Self, %Param ) = @_;

    return 0 if ( !$Param{Count} );

    my $Sum = 0;
    for my $Value ( values( %{ $Param{Content} } ) ) {
        $Sum += $Value;
    }

    return $Sum / $Param{Count};
}

sub _KindsOfReporting {
    my $Self = shift;

    my %KindsOfReporting = (
        SolutionAverageAllOver     => Translatable('Solution Average'),
        SolutionMinTimeAllOver     => Translatable('Solution Min Time'),
        SolutionMaxTimeAllOver     => Translatable('Solution Max Time'),
        NumberOfTicketsAllOver     => Translatable('Number of Tickets'),
        SolutionAverage            => Translatable('Solution Average (affected by escalation configuration)'),
        SolutionMinTime            => Translatable('Solution Min Time (affected by escalation configuration)'),
        SolutionMaxTime            => Translatable('Solution Max Time (affected by escalation configuration)'),
        SolutionWorkingTimeAverage => Translatable('Solution Working Time Average (affected by escalation configuration)'),
        SolutionMinWorkingTime     => Translatable('Solution Min Working Time (affected by escalation configuration)'),
        SolutionMaxWorkingTime     => Translatable('Solution Max Working Time (affected by escalation configuration)'),
        ResponseAverage            => Translatable('Response Average (affected by escalation configuration)'),
        ResponseMinTime            => Translatable('Response Min Time (affected by escalation configuration)'),
        ResponseMaxTime            => Translatable('Response Max Time (affected by escalation configuration)'),
        ResponseWorkingTimeAverage => Translatable('Response Working Time Average (affected by escalation configuration)'),
        ResponseMinWorkingTime     => Translatable('Response Min Working Time (affected by escalation configuration)'),
        ResponseMaxWorkingTime     => Translatable('Response Max Working Time (affected by escalation configuration)'),
        NumberOfTickets            => Translatable('Number of Tickets (affected by escalation configuration)'),
    );

    return \%KindsOfReporting;
}

sub _SortedKindsOfReporting {
    my $Self = shift;

    my @SortedKindsOfReporting = qw(
        SolutionAverageAllOver
        SolutionMinTimeAllOver
        SolutionMaxTimeAllOver
        NumberOfTicketsAllOver
        SolutionAverage
        SolutionMinTime
        SolutionMaxTime
        SolutionWorkingTimeAverage
        SolutionMinWorkingTime
        SolutionMaxWorkingTime
        ResponseAverage
        ResponseMinTime
        ResponseMaxTime
        ResponseWorkingTimeAverage
        ResponseMinWorkingTime
        ResponseMaxWorkingTime
        NumberOfTickets
    );

    return \@SortedKindsOfReporting;
}

sub _AllowedTicketSearchAttributes {
    my $Self = shift;

    my @Attributes = qw(
        TicketNumber
        Title
        Queues
        QueueIDs
        Types
        TypeIDs
        States
        StateIDs
        StateType
        StateTypeIDs
        Priorities
        PriorityIDs
        Services
        ServiceIDs
        SLAs
        SLAIDs
        Locks
        LockIDs
        OwnerIDs
        ResponsibleIDs
        WatchUserIDs
        CustomerID
        CustomerIDRaw
        CustomerUserLogin
        CustomerUserLoginRaw
        CreatedUserIDs
        CreatedTypes
        CreatedTypeIDs
        CreatedPriorities
        CreatedPriorityIDs
        CreatedStates
        CreatedStateIDs
        CreatedQueues
        CreatedQueueIDs
        From
        To
        Subject
        Body
        TicketCreateTimeNewerDate
        TicketCreateTimeOlderDate
        TicketChangeTimeNewerDate
        TicketChangeTimeOlderDate
        TicketLastChangeTimeNewerDate
        TicketLastChangeTimeOlderDate
        TicketCloseTimeNewerDate
        TicketCloseTimeOlderDate
        TicketPendingTimeNewerDate
        TicketPendingTimeOlderDate
        TicketEscalationTimeNewerDate
        TicketEscalationTimeOlderDate
        TicketEscalationUpdateTimeNewerDate
        TicketEscalationUpdateTimeOlderDate
        TicketEscalationResponseTimeNewerDate
        TicketEscalationResponseTimeOlderDate
        TicketEscalationSolutionTimeNewerDate
        TicketEscalationSolutionTimeOlderDate
    );

    # loop over the dynamic fields configured
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if ( !IsHashRefWithData( $DynamicFieldConfig ) );
        next DYNAMICFIELD if ( !$DynamicFieldConfig->{Name} );

        # add dynamic field to Attribute list
        push( @Attributes, 'DynamicField_' . $DynamicFieldConfig->{Name} );
    }

    return \@Attributes;
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
