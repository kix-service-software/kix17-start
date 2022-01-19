# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::DynamicField::TTLCheck;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Process TTL of dynamic field values.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Process dynamic field TTL...</yellow>");

    # get needed objects
    my $DBObject                = $Kernel::OM->Get('Kernel::System::DB');
    my $DynamicFieldObject      = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');
    my $TicketObject            = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TimeObject              = $Kernel::OM->Get('Kernel::System::Time');

    # get complete list of DFs
    my $List = $DynamicFieldObject->DynamicFieldListGet(
        Valid => 1,
    );

    if ( ref($List) eq 'ARRAY' ) {
        my $HistoryTypeID    = $TicketObject->HistoryTypeLookup( Type => 'TicketDynamicFieldUpdate' );
        my $CurrentTimeStamp = $TimeObject->CurrentTimestamp();

        DYNAMICFIELD:
        for my $DynamicField ( @{$List} ) {
            next DYNAMICFIELD if ( !$DynamicField->{Config}->{ValueTTL} );

            my $HistoryNamePattern = '\%\%FieldName\%\%' . $DynamicField->{Name} . '\%\%Value\%\%%';

            my $ObjectIDAttr = IsHashRefWithData($DynamicField) && $DynamicField->{IdentifierDBAttribute} || 'object_id';
            next DYNAMICFIELD if !$DBObject->Prepare(
                SQL =>
                    'SELECT '.$ObjectIDAttr.'' .
                    ' FROM dynamic_field_value_ttl WHERE field_id=? AND value_ttl<=?',
                Bind => [ \$DynamicField->{ID}, \$CurrentTimeStamp ],
            );

            # fetch relevant object ids
            my @ObjectIDS;
            while ( my @Row = $DBObject->FetchrowArray() ) {
                push(@ObjectIDS, $Row[0]);
            }
            next DYNAMICFIELD if !@ObjectIDS;

            $Self->Print("\n<yellow>Process expired values of field id $DynamicField->{ID}</yellow>\n");

            OBJECTID:
            for my $ObjectID ( sort( @ObjectIDS ) ) {
                $Self->Print("<yellow>-Delete values for object id $ObjectID</yellow>\n");

                # delete values for object
                my $Success = $DynamicFieldValueObject->ValueDelete(
                    FieldID  => $DynamicField->{ID},
                    ObjectID => $ObjectID,
                    UserID   => 1,
                );
                if ( !$Success ) {
                    $Self->PrintError("Unable to delete values. FieldID: $DynamicField->{ID} / ObjectID: $ObjectID\n");
                    next OBJECTID;
                }

                # special handling for tickets
                if ( $DynamicField->{ObjectType} eq 'Ticket' ) {
                    my $HistorySuccess = $DBObject->Do(
                        SQL => 'DELETE FROM ticket_history'
                             . ' WHERE name like ? AND history_type_id=? AND ticket_id=?',
                        Bind => [ \$HistoryNamePattern, \$HistoryTypeID, \$ObjectID ],
                    );

                    if ( !$HistorySuccess ) {
                        $Self->PrintError("Unable to delete relevant ticket history. FieldID: $DynamicField->{ID} / TicketID: $ObjectID\n");
                    }
                }
            }
        }
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
