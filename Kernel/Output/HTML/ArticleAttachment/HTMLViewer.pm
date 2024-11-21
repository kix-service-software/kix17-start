# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ArticleAttachment::HTMLViewer;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
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
    for my $Needed (qw(File Article)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check if config exists
    if ( $ConfigObject->Get('MIME-Viewer') ) {
        for ( sort keys %{ $ConfigObject->Get('MIME-Viewer') } ) {
            if ( $Param{File}->{ContentType} =~ /^$_/i ) {
                return (
                    %{ $Param{File} },
                    Action => 'Viewer',
                    Link   => $Kernel::OM->Get('Kernel::Output::HTML::Layout')->{Baselink} .
                        "Action=AgentTicketAttachment;ArticleID=$Param{Article}->{ArticleID};FileID=$Param{File}->{FileID};Viewer=1",
                    Target => 'target="attachment"',
                    Class  => 'ViewAttachment',
                );
            }
        }
    }
    return ();
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
