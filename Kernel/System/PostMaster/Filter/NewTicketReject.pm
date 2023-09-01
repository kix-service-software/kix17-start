# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::NewTicketReject;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Email',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $EmailObject  = $Kernel::OM->Get('Kernel::System::Email');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check needed stuff
    for (qw(JobConfig GetParam)) {
        if ( !$Param{$_} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # prepare suffix for log
    my $Suffix = "(Message-ID: $Param{GetParam}->{'Message-ID'})";

    # get config options
    my %Match;
    my %Set;
    if (
        $Param{JobConfig}
        && ref( $Param{JobConfig} ) eq 'HASH'
    ) {
        if ( ref( $Param{JobConfig}->{Match} ) eq 'HASH' ) {
            %Match = %{ $Param{JobConfig}->{Match} };
        }
        if ( ref( $Param{JobConfig}->{Set} ) eq 'HASH' ) {
            %Set = %{ $Param{JobConfig}->{Set} };
        }
    }

    ATTRIBUTE:
    for my $Attribute ( sort( keys( %Match ) ) ) {

        # check Body as last attribute
        if ( $Attribute eq 'Body' ) {
            next ATTRIBUTE;
        }

        if (
            defined( $Param{GetParam}->{ $Attribute } )
            && $Param{GetParam}->{ $Attribute } =~ /$Match{ $Attribute }/i
        ) {
            if ( $Self->{Debug} > 1 ) {
                $LogObject->Log(
                    Priority => 'debug',
                    Message  => "'$Param{GetParam}->{ $Attribute }' =~ /$Match{ $Attribute }/i matched! $Suffix",
                );
            }
        }
        else {
            if ( $Self->{Debug} > 1 ) {
                $LogObject->Log(
                    Priority => 'debug',
                    Message  => "'$Param{GetParam}->{ $Attribute }' =~ /$Match{ $Attribute }/i matched NOT! $Suffix",
                );
            }

            return 1;
        }
    }

    # check body
    if ( defined( $Match{Body} ) ) {
        # optimize regex with leading wildcard
        if (
            $Match{Body} =~ m/^\.\+/
            || $Match{Body} =~ m/^\(\.\+/
            || $Match{Body} =~ m/^\(\?\:\.\+/
        ) {
            $Match{Body} = '^' . $Match{Body};
        }

        # match body
        if (
            defined( $Param{GetParam}->{Body} )
            && $Param{GetParam}->{Body} =~ m{$Match{Body}}i
        ) {
            if ( $Self->{Debug} > 1 ) {
                $LogObject->Log(
                    Priority => 'debug',
                    Message  => "'$Param{GetParam}->{Body}' =~ /$Match{Body}/i matched! $Suffix",
                );
            }
        }
        else {
            if ( $Self->{Debug} > 1 ) {
                $LogObject->Log(
                    Priority => 'debug',
                    Message  => "'$Param{GetParam}->{Body}' =~ /$Match{Body}/i matched NOT! $Suffix",
                );
            }

            return 1;
        }
    }

    # check if new ticket
    my $Tn = $TicketObject->GetTNByString( $Param{GetParam}->{Subject} );

    return 1 if (
        $Tn
        && $TicketObject->TicketCheckNumber( Tn => $Tn )
    );

    # set attributes if ticket is created
    for my $Attribute ( sort( keys( %Set ) ) ) {
        $Param{GetParam}->{ $Attribute } = $Set{ $Attribute };

        $LogObject->Log(
            Priority => 'notice',
            Message  => "Set param '$Attribute' to '$Set{ $Attribute }' $Suffix",
        );
    }

    # send bounce mail
    my $Subject = $ConfigObject->Get( 'PostMaster::PreFilterModule::NewTicketReject::Subject' );
    my $Body    = $ConfigObject->Get( 'PostMaster::PreFilterModule::NewTicketReject::Body' );
    my $Sender  = $ConfigObject->Get( 'PostMaster::PreFilterModule::NewTicketReject::Sender' ) || '';

    $EmailObject->Send(
        From       => $Sender,
        To         => $Param{GetParam}->{From},
        Subject    => $Subject,
        Body       => $Body,
        Charset    => 'utf-8',
        MimeType   => 'text/plain',
        Loop       => 1,
        Attachment => [
            {
                Filename    => 'email.txt',
                Content     => $Param{GetParam}->{Body},
                ContentType => 'application/octet-stream',
            }
        ],
    );

    $LogObject->Log(
        Priority => 'notice',
        Message  => "Send reject mail to '$Param{GetParam}->{From}'! $Suffix",
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
