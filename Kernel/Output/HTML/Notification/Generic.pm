# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Notification::Generic;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Main',
    'Kernel::Output::HTML::Layout',
    'Kernel::Config',
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

    # define default value
    my %Arguments = (
        Priority => 'Warning',
    );

    # Check which class to add
    if ( $Param{Config}->{Priority} && $Param{Config}->{Priority} eq 'Error' ) {
        $Arguments{Priority} = 'Error';
    }
    elsif ( $Param{Config}->{Priority} && $Param{Config}->{Priority} eq 'Success' ) {
        $Arguments{Priority} = 'Success';
    }
    elsif ( $Param{Config}->{Priority} && $Param{Config}->{Priority} eq 'Info' ) {
        $Arguments{Priority} = 'Info';
    }

    if ( $Param{Config}->{Text} ) {
        $Arguments{Info} = $Param{Config}->{Text};
    }
    elsif ( $Param{Config}->{File} ) {

#rbo - T2016121190001552 - added KIX placeholders
        $Param{Config}->{File} =~ s{<KIX_CONFIG_(.+?)>}{$Kernel::OM->Get('Kernel::Config')->Get($1)}egx;

        return '' if !-e $Param{Config}->{File};

        # try to read the file
        my $FileContent = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location => $Param{Config}->{File},
            Mode     => 'utf8',
            Type     => 'Local',
            Result   => 'SCALAR',
        );

        return '' if !$FileContent;
        return '' if ref $FileContent ne 'SCALAR';

        $Arguments{Info} = ${$FileContent};
    }
    else {
        return '';
    }

    # add link if available
    if ( $Param{Config}->{Link} ) {
        $Arguments{Link} = $Param{Config}->{Link};
    }

    return '' if !$Arguments{Info};

    return $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Notify(%Arguments);
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
