# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Stats::Dynamic::ITSMTicketFirstLevelSolutionRate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
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

    return 'ITSMTicketFirstLevelSolutionRate';
}

sub GetObjectAttributes {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject   = $Kernel::OM->Get('Kernel::Config');
    my $DBObject       = $Kernel::OM->Get('Kernel::System::DB');
    my $BackendObject  = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
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
        %StateList = $StateObject->StateGetStatesByType(
            StateType => ['closed'],
            Result    => 'HASH',
            UserID    => 1,
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

    # get current time to fix bug#3830
    my $Today;
    if (
        ref( $Param{SelectedObjectAttributes} ) ne 'HASH'
        || $Param{SelectedObjectAttributes}->{'CreateTime'}
    ) {
        my $TimeStamp = $TimeObject->CurrentTimestamp();
        my ($Date) = split /\s+/, $TimeStamp;
        $Today = sprintf "%s 23:59:59", $Date;
    }

    my @ObjectAttributes = ();

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
            Name             => Translatable('Contact login (complex search)'),
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => 'CustomerUserLogin',
            Block            => 'InputField',
        },
        {
            Name             => Translatable('Contact login (exact match)'),
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
            Name             => Translatable('Create Time'),
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
        }
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

sub GetStatElementPreview {
    my ( $Self, %Param ) = @_;

    return int rand 50;
}

sub GetStatElement {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # use all closed stats if no states are given
    if ( !$Param{StateIDs} ) {
        $Param{StateType} = ['closed'];
    }

    # start ticket search
    my @TicketSearchIDs = $TicketObject->TicketSearch(
        %Param,
        Result     => 'ARRAY',
        Limit      => 100_000_000,
        UserID     => 1,
        Permission => 'ro',
    );

    return 0 if !@TicketSearchIDs;

    my $FirstLevelSolutionTickets = 0;
    TICKETID:
    for my $TicketID ( @TicketSearchIDs ) {

        # get article data list
        my $ArticleDataList = $Self->_ArticleDataGet(
            TicketID => $TicketID,
        );

        return 'ERROR' if ( !$ArticleDataList );

        next TICKETID if ( !@{ $ArticleDataList } );
        next TICKETID if ( @{ $ArticleDataList } > 2 );

        # first article is a phone article
        if ( $ArticleDataList->[0]->{ArticleTypeID} eq $Self->{PhoneTypeID} ) {
            if ( !$ArticleDataList->[1] ) {
                $FirstLevelSolutionTickets++;
            }

            next TICKETID;
        }

        # first article is an external email article
        if ( $ArticleDataList->[0]->{ArticleTypeID} eq $Self->{EmailExternalTypeID} ) {
            # first article comes from an agent (Email-Ticket)
            if (
                $ArticleDataList->[0]->{ArticleSenderTypeID}
                && $ArticleDataList->[0]->{ArticleSenderTypeID} eq $Self->{AgentSenderTypeID}
                && !$ArticleDataList->[1]
            ) {
                $FirstLevelSolutionTickets += 1;

                next TICKETID;
            }

            # first article comes from customer and the second one from an agent
            if (
                $ArticleDataList->[0]->{ArticleSenderTypeID}
                && $ArticleDataList->[0]->{ArticleSenderTypeID} eq $Self->{CustomerSenderTypeID}
                && $ArticleDataList->[1]
                && $ArticleDataList->[1]->{ArticleSenderTypeID} eq $Self->{AgentSenderTypeID}
            ) {
                $FirstLevelSolutionTickets += 1;

                next TICKETID;
            }
        }
    }

    return $FirstLevelSolutionTickets;
}

sub _ArticleDataGet {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $DBObject     = $Kernel::OM->Get('Kernel::System::DB');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    return if !$Param{TicketID};

    # get id of article type 'phone'
    if ( !$Self->{PhoneTypeID} ) {
        $Self->{PhoneTypeID} = $TicketObject->ArticleTypeLookup(
            ArticleType => 'phone',
        );
    }

    # get id of article type 'email-external'
    if ( !$Self->{EmailExternalTypeID} ) {
        $Self->{EmailExternalTypeID} = $TicketObject->ArticleTypeLookup(
            ArticleType => 'email-external',
        );
    }

    # get id of article sender type 'agent'
    if ( !$Self->{AgentSenderTypeID} ) {
        $Self->{AgentSenderTypeID} = $TicketObject->ArticleSenderTypeLookup(
            SenderType => 'agent',
        );
    }

    # get id of article sender type 'customer'
    if ( !$Self->{CustomerSenderTypeID} ) {
        $Self->{CustomerSenderTypeID} = $TicketObject->ArticleSenderTypeLookup(
            SenderType => 'customer',
        );
    }

    # ask database
    $DBObject->Prepare(
        SQL => <<'END',
SELECT article_type_id, article_sender_type_id
FROM article
WHERE ticket_id = ?
  AND article_type_id IN ( ?, ? )
  AND article_sender_type_id IN ( ?, ? )
ORDER BY create_time
END
        Bind => [
            \$Param{TicketID},
            \$Self->{PhoneTypeID},
            \$Self->{EmailExternalTypeID},
            \$Self->{AgentSenderTypeID},
            \$Self->{CustomerSenderTypeID},
        ],
        Limit => 3,
    );

    # fetch the result
    my @ArticleDataList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        my %ArticleData;
        $ArticleData{ArticleTypeID}       = $Row[0];
        $ArticleData{ArticleSenderTypeID} = $Row[1];

        push( @ArticleDataList, \%ArticleData );
    }

    return \@ArticleDataList;
}

sub ExportWrapper {
    my ( $Self, %Param ) = @_;

    return \%Param;
}

sub ImportWrapper {
    my ( $Self, %Param ) = @_;

    return \%Param;
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
