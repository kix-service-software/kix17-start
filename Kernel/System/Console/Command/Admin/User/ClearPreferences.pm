# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::User::ClearPreferences;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Clear user preferences.');
    $Self->AddOption(
        Name        => 'key',
        Description => 'Define the key to look at.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'value',
        Description => 'Define the value to restrict to (only look at these values).',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'user-id',
        Description => 'Restrict to this UserID.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'all',
        Description => 'Clear everything.',
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my @BindObj;

    my %Options;
    $Options{Key}    = $Self->GetOption('key');
    $Options{Value}  = $Self->GetOption('value');
    $Options{UserID} = $Self->GetOption('user-id');
    $Options{All}    = $Self->GetOption('all');

    if (   !defined( $Options{Key} )
        && !defined( $Options{Value} )
        && !defined( $Options{UserID} )
        && !$Options{All} )
    {
        $Self->Print("<red>At least one option must be given.</red>\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<yellow>Clearing user preferences.</yellow>\n");

    my $SQL = 'DELETE FROM user_preferences WHERE 1=1';

    if ( defined( $Options{Key} ) ) {
        $SQL .= ' AND preferences_key = ?';
        push( @BindObj, \$Options{Key} );
    }
    if ( defined( $Options{Value} ) ) {
        $SQL .= ' AND preferences_value = ?';
        push( @BindObj, \$Options{Value} );
    }
    if ( defined( $Options{UserID} ) ) {
        $SQL .= ' AND user_id = ?';
        push( @BindObj, \$Options{UserID} );
    }

    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => $SQL,
        Bind => \@BindObj,
    );

    if ( !$Result ) {
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
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
