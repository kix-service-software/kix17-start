# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::DefaultUser;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Kernel::System::Auth',
    'Kernel::System::Group',
    'Kernel::System::User',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # get needed objects
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    my %UserList = $UserObject->UserList(
        Type  => 'Short',
        Valid => '1',
    );

    my $DefaultPassword;

    my $SuperUserID;
    USER:
    for my $UserID ( sort keys %UserList ) {
        if ( $UserList{$UserID} eq 'root@localhost' ) {
            $SuperUserID = 1;
            last USER;
        }
    }

    if ($SuperUserID) {

        $DefaultPassword = $Kernel::OM->Get('Kernel::System::Auth')->Auth(
            User => 'root@localhost',
            Pw   => 'root',
        );
    }

    if ($DefaultPassword) {
        $Self->AddResultProblem(
            Label => Translatable('Default Admin Password'),
            Value => '',
            Message =>
                Translatable(
                'Security risk: the agent account root@localhost still has the default password. Please change it or invalidate the account.'
                ),
        );
    }
    else {
        $Self->AddResultOk(
            Label => Translatable('Default Admin Password'),
            Value => '',
        );
    }

    return $Self->GetResults();
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
