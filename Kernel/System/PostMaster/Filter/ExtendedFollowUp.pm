# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::ExtendedFollowUp;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    # get needed objects
    $Self->{ConfigObject}       = $Kernel::OM->Get('Kernel::Config');
    $Self->{DynamicFieldObject} = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{TicketObject}       = $Kernel::OM->Get('Kernel::System::Ticket');

    # get our config
    $Self->{Config} = $Self->{ConfigObject}->Get('ExtendedFollowUp');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # no config --> no mapping
    return if ( !$Self->{Config}
                || ref( $Self->{Config} ) ne 'HASH'
    );
    return if ( !$Self->{Config}->{Identifier}
                || ref( $Self->{Config}->{Identifier} ) ne 'HASH'
    );
    return if ( !$Self->{Config}->{SenderEmail}
                || ref( $Self->{Config}->{SenderEmail} ) ne 'HASH'
    );
    return if ( !$Self->{Config}->{ExternalReference}
                || ref( $Self->{Config}->{ExternalReference} ) ne 'HASH'
    );
    return if ( !$Self->{Config}->{DynamicFieldMapping}
                || ref( $Self->{Config}->{DynamicFieldMapping} ) ne 'HASH'
    );

    my %ExistingTicket;
    if ( $Param{TicketID} ) {
        %ExistingTicket = $Self->{TicketObject}->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );
    }

    my %FilterKeys = %{ $Self->{Config}->{Identifier} };

    foreach my $FilterKey ( sort keys %FilterKeys ) {

        # next if not all config values for the key are set
        next if ( !$Self->{Config}->{SenderEmail}->{ $FilterKeys{$FilterKey} }
                || !$Self->{Config}->{ExternalReference}->{ $FilterKeys{$FilterKey} }
                || !$Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{$FilterKey} }
        );

        my $SenderEmail         = $Self->{Config}->{SenderEmail}->{ $FilterKeys{$FilterKey} };
        my $ExternalReference   = $Self->{Config}->{ExternalReference}->{ $FilterKeys{$FilterKey} };
        my $DynamicField        = $Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{$FilterKey} };

        # next if configured dynamic field does not exist
        my $TicketDynamicFields = $Self->{DynamicFieldObject}->DynamicFieldList(
            ObjectType => 'Ticket',
            ResultType => 'HASH',
        );
        my %DynamicFieldHash = reverse %{$TicketDynamicFields};

        next if ( !defined( $DynamicFieldHash{ $DynamicField } ) );

        # next if in the existing ticket the dynamic field is not empty
        next if ( %ExistingTicket
                && ref %ExistingTicket eq 'HASH'
                && $ExistingTicket{ 'DynamicField_' . $DynamicField }
        );

        # sender email doesnt match
        next if ( $Param{GetParam}->{From} !~ /$SenderEmail/ );

        my $ReferenceNumber = '';
        if ( $Param{GetParam}->{Subject} =~ /$ExternalReference/ ) {
            $ReferenceNumber = $1;
        }

        if ($ReferenceNumber) {

            # write DynamicField
            $Param{GetParam}->{ 'X-KIX-FollowUp-DynamicField-' . $DynamicField } = $ReferenceNumber;
            $Param{GetParam}->{ 'X-KIX-DynamicField-' . $DynamicField }          = $ReferenceNumber;

            # if no ticket was found by followup search on by external reference_number

            if ( !$Param{TicketID} ) {

                my @TicketIDs = $Self->{TicketObject}->TicketSearch(
                    Result                          => 'ARRAY',
                    UserID                          => 1,
                    OrderBy                         => [ $Self->{Config}->{SortByAgeOrder} ],
                    SortBy                          => ['Age'],
                    'DynamicField_' . $DynamicField => {
                        Equals => $ReferenceNumber,
                    },
                );

                if ( scalar(@TicketIDs) > 0 ) {
                    ## TODO
                    my $TicketNumber = '';

                    # if ticket statetype isn't relevat
                    if ( $Self->{Config}->{AllTicketStateTypesIncluded} ) {
                        $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
                            TicketID => $TicketIDs[0],
                            UserID   => 1,
                        );
                    }

                    # if ticket statetape should by pending or open
                    else {
                        for my $TicketID (@TicketIDs) {
                            my %Ticket = $Self->{TicketObject}->TicketGet(
                                TicketID => $TicketID,
                                UserID   => 1,
                            );

                            if ( $Ticket{StateType} =~ /^(pending|new|open)/ ) {
                                $TicketNumber = $Ticket{TicketNumber};
                                last;
                            }
                        }

# if open/pending tickets should be take and no one was found the first closed ticket will be choose
                        if ( !$TicketNumber ) {
                            $TicketNumber = $Self->{TicketObject}->TicketNumberLookup(
                                TicketID => $TicketIDs[0],
                                UserID   => 1,
                            );
                        }
                    }

                    if ($TicketNumber) {
                        $Param{GetParam}->{'Subject'} = $Self->{TicketObject}->TicketSubjectBuild(
                            TicketNumber => $TicketNumber,
                            Subject      => $Param{GetParam}->{'Subject'},
                            Type         => 'New',
                            NoCleanup    => 1,
                        );
                    }
                }
            }
        }
    }

    #...done...
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
