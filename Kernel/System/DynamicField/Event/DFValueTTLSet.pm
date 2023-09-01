# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Event::DFValueTTLSet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
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
    if ( $Param{Event} ne 'DynamicFieldValueSet' ) {
        return 1;
    }

    for (qw(FieldID ObjectID Values)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }
    return 1 if !IsArrayRefWithData($Param{Data}->{Values});

    # create needed objects
    my $DBObject           = $Kernel::OM->Get('Kernel::System::DB');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');

    my $DFConfig = $DynamicFieldObject->DynamicFieldGet(
        ID => $Param{Data}->{FieldID},
    );
    return 1 if (!$DFConfig || !$DFConfig->{Config} || !$DFConfig->{Config}->{ValueTTL});

    my $ValueTTL = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $TimeObject->SystemTime() + $DFConfig->{Config}->{ValueTTL},
    );
    my $ObjectIDAttr = IsHashRefWithData($DFConfig) && $DFConfig->{IdentifierDBAttribute} || 'object_id';
    return if !$DBObject->Do(
        SQL => 'INSERT INTO dynamic_field_value_ttl'
             . ' (field_id, '.$ObjectIDAttr.', value_ttl, create_time)'
             . ' VALUES (?, ?, ?, current_timestamp)',
        Bind => [ \$Param{Data}->{FieldID}, \$Param{Data}->{ObjectID}, \$ValueTTL ],
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
