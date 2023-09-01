# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Event::DFTTLUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Time'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need ' . $Needed . '!',
            );
            return;
        }
    }

    # only handle ArticleCreate events
    if ( $Param{Event} ne 'DynamicFieldUpdate' ) {
        return 1;
    }

    for (qw(NewData)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # create needed objects
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    if (!$Param{Data}->{NewData}->{Config}->{ValueTTL}) {
        return if !$DBObject->Do(
            SQL => 'DELETE FROM dynamic_field_value_ttl'
                 . ' WHERE field_id=?',
            Bind => [ \$Param{Data}->{NewData}->{ID} ],
        );
        return 1;
    }

    my $ObjectIDAttr = IsHashRefWithData($Param{Data}->{NewData}) && $Param{Data}->{NewData}->{IdentifierDBAttribute} || 'object_id';
    return if !$DBObject->Prepare(
        SQL =>
            'SELECT '.$ObjectIDAttr.', create_time' .
            ' FROM dynamic_field_value_ttl WHERE field_id = ?',
        Bind => [ \$Param{Data}->{NewData}->{ID} ],
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{$Row[0]} = $Row[1];
    }

    for my $ObjectID ( keys ( %Data ) ) {
        my $CreateTime = $TimeObject->TimeStamp2SystemTime(
            String => $Data{$ObjectID},
        );
        my $ValueTTL = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $CreateTime + $Param{Data}->{NewData}->{Config}->{ValueTTL},
        );
        next if !$DBObject->Do(
            SQL => 'UPDATE dynamic_field_value_ttl'
                 . ' SET value_ttl=?'
                 . ' WHERE field_id=? AND '.$ObjectIDAttr.'=?',
            Bind => [ \$ValueTTL, \$Param{Data}->{NewData}->{ID}, \$ObjectID ],
        );
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
