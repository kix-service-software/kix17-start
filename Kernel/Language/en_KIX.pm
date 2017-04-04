# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::en_KIX;

use strict;
use warnings;
use utf8;

use vars qw($VERSION);
$VERSION = qw($Revision$) [1];

# --
sub Data {
    my $Self = shift;

    my $Lang = $Self->{Translation};

    return if ref $Lang ne 'HASH';

    # $$START$$

    $Lang->{'Print Richtext'} = 'HTML Print';
    $Lang->{'Print Standard'} = 'PDF Print';

    $Lang->{'CIHistory::ConfigItemCreate'}            = 'New ConfigItem (ID=%s)';
    $Lang->{'CIHistory::VersionCreate'}               = 'New version (ID=%s)';
    $Lang->{'CIHistory::DeploymentStateUpdate'}       = 'Deployment state updated (new=%s; old=%s)';
    $Lang->{'CIHistory::IncidentStateUpdate'}         = 'Incident state updated (new=%s; old=%s)';
    $Lang->{'CIHistory::ConfigItemDelete'}            = 'ConfigItem (ID=%s) deleted';
    $Lang->{'CIHistory::LinkAdd'}                     = 'Link to %s (type=%s) added';
    $Lang->{'CIHistory::LinkDelete'}                  = 'Link to %s (type=%s) deleted';
    $Lang->{'CIHistory::DefinitionUpdate'}            = 'ConfigItems\' definition updated (ID=%s)';
    $Lang->{'CIHistory::NameUpdate'}                  = 'Name updated (new=%s; old=%s)';
    $Lang->{'CIHistory::ValueUpdate'}                 = 'Attribute %s updated from "%s" to "%s"';
    $Lang->{'CIHistory::VersionDelete'}               = 'Version %s deleted';

    $Lang->{'Developer Licence'}                      = 'Developer License';
    $Lang->{'Enterprise Licence'}                     = 'Enterprise License';
    $Lang->{'Single Licence'}                         = 'Single License';
    $Lang->{'Volume Licence'}                         = 'Volume License';
    $Lang->{'Licence Type'}                           = 'License Type';
    $Lang->{'Licence Key'}                            = 'License Key';
    $Lang->{'Licence Key::Quantity'}                  = 'License Key::Quantity';
    $Lang->{'Licence Key::Expiration Date'}           = 'License Key::Expiration Date';

    # $$STOP$$

    return 0;
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
