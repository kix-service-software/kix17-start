# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::TicketBulk::Base;

use strict;
use warnings;

our @ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Output::HTML::TicketBulk::Base - ticket bulk module base class

=head1 SYNOPSIS

Base class for ticket bulk modules.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Display()

Generates the required HTML to display new fields in ticket bulk screen. It requires to get the value from the web request (e.g. in case of an error to re-display the field content).

    my $ModuleContent = $ModuleObject->Display(
        Errors       => $ErrorsHashRef,             # created in ticket bulk and updated by Validate()
        UserID       => $123,
    );

Returns:

    $ModuleContent = $HMLContent;                   # HTML content of the field

Override this method in your modules.

=cut

sub Display {
    my ( $Self, %Param ) = @_;

    return;
}

=item Validate()

Validates the values of the ticket bulk module. It requires to get the value from the web request.

    my @Result = $ModuleObject->Validate(
        UserID       => $123,
    );

Returns:

    @Result = (
        {
            ErrorKey   => 'SomeFieldName',
            ErrorValue => 'SomeErrorMessage',
        }
       # ...
    );

Override this method in your modules.

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    return ();
}

=item Store()

Stores the values of the ticket bulk module. It requires to get the values from the web request.

    my @Success = $ModuleObject->Store(
        TicketID => 123,
        UserID   => 123,
    );

Returns:

    $Success = 1,       # or false in case of an error;

Override this method in your modules.

=cut

sub Store {
    my ( $Self, %Param ) = @_;

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
