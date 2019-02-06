# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Event::DFValueTTLDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log'
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
    if ( $Param{Event} ne 'DynamicFieldValueDelete' ) {
        return 1;
    }

    for (qw(FieldID ObjectID)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # create needed objects
    my $DBObject           = $Kernel::OM->Get('Kernel::System::DB');
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my $DFConfig = $DynamicFieldObject->DynamicFieldGet(
        ID => $Param{Data}->{FieldID},
    );
    return 1 if (!$DFConfig);

    my $ObjectIDAttr = IsHashRefWithData($DFConfig) && $DFConfig->{IdentifierDBAttribute} || 'object_id';
    return if !$DBObject->Do(
        SQL => 'DELETE FROM dynamic_field_value_ttl'
             . ' WHERE field_id=? AND '.$ObjectIDAttr.'=?',
        Bind => [ \$Param{Data}->{FieldID}, \$Param{Data}->{ObjectID} ],
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
