# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::Match;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(JobConfig GetParam)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get config options
    my %Config;
    my %Match;
    my %Set;
    my %Not;
    if (
        $Param{JobConfig}
        && ref $Param{JobConfig} eq 'HASH'
    ) {
        %Config = %{ $Param{JobConfig} };
        if ( $Config{Match} ) {
            %Match = %{ $Config{Match} };
        }
        if ( $Config{Set} ) {
            %Set = %{ $Config{Set} };
        }
        if ( $Config{Not} ) {
            %Not = %{ $Config{Not} };
        }
    }

    # prepare prefix for log
    my $Prefix = '';
    if ( $Config{Name} ) {
        $Prefix = "Filter: '$Config{Name}'";
    }

    # prepare suffix for log
    my $Suffix = "(Message-ID: $Param{GetParam}->{'Message-ID'})";

    # match 'Match => ???' stuff
    my $MatchedResult = '';
    ATTRIBUTE:
    for my $Attribute ( sort( keys( %Match ) ) ) {

        # check Body as last attribute
        if ( $Attribute eq 'Body' ) {
            next ATTRIBUTE;
        }
        # match only email addresses
        if (
            $Param{GetParam}->{ $Attribute }
            && $Match{ $Attribute } =~ /^EMAILADDRESS:(.*)$/
        ) {
            my $SearchEmail    = $1;
            my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
                Line => $Param{GetParam}->{ $Attribute },
            );
            my $LocalMatched;
            RECIPIENTS:
            for my $Recipients ( @EmailAddresses ) {
                my $Email = $Self->{ParserObject}->GetEmailAddress(
                    Email => $Recipients
                );
                if ( $Email =~ /^$SearchEmail$/i ) {
                    $LocalMatched = 1;
                    if ( $SearchEmail ) {
                        $MatchedResult = $SearchEmail;
                    }
                    if ( $Self->{Debug} > 1 ) {
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'debug',
                            Message  => "$Prefix '$Param{GetParam}->{ $Attribute }' =~ /$Match{ $Attribute }/i matched! $Suffix",
                        );
                    }
                    last RECIPIENTS;
                }
            }
            if (
                (
                    !$LocalMatched
                    && !$Not{ $Attribute }
                )
                || (
                    $LocalMatched
                    && $Not{ $Attribute }
                )
            ) {
                if ( $Self->{Debug} > 1 ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'debug',
                        Message  => "$Prefix '$Attribute' NOT fulfilled! $Suffix",
                    );
                }
                return 1;
            }
        }
        # match string
        elsif (
            defined( $Param{GetParam}->{ $Attribute } )
            && (
                (
                    !$Not{ $Attribute }
                    && $Param{GetParam}->{ $Attribute } =~ m{$Match{ $Attribute }}i
                )
                || (
                    $Not{ $Attribute }
                    && $Param{GetParam}->{ $Attribute } !~ m{$Match{ $Attribute }}i
                )
            )
        ) {
            # don't lose older match values if more than one header is
            # used for matching.
            if ( $1 ) {
                $MatchedResult = $1;
            }

            if ( $Self->{Debug} > 1 ) {
                my $Op = $Not{ $Attribute } ? '!' : "=";

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'debug',
                    Message =>
                        "$Prefix '$Param{GetParam}->{ $Attribute }' $Op~ /$Match{ $Attribute }/i matched! $Suffix",
                );
            }
        }
        else {
            if ( $Self->{Debug} > 1 ) {
                my $Op = $Not{ $Attribute } ? '!' : "=";

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'debug',
                    Message  => "$Prefix '$Param{GetParam}->{ $Attribute }' $Op~ /$Match{ $Attribute }/i matched NOT! $Suffix",
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
            defined $Param{GetParam}->{Body}
            && (
                (
                    !$Not{Body}
                    && $Param{GetParam}->{Body} =~ m{$Match{Body}}i
                )
                || (
                    $Not{Body}
                    && $Param{GetParam}->{Body} !~ m{$Match{Body}}i
                )
            )
        ) {
            # don't lose older match values if more than one header is
            # used for matching.
            if ( $1 ) {
                $MatchedResult = $1;
            }

            if ( $Self->{Debug} > 1 ) {
                my $Op = $Not{Body} ? '!' : "=";

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'debug',
                    Message =>
                        "$Prefix '$Param{GetParam}->{Body}' $Op~ /$Match{Body}/i matched! $Suffix",
                );
            }
        }
        else {
            if ( $Self->{Debug} > 1 ) {
                my $Op = $Not{Body} ? '!' : "=";

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'debug',
                    Message  => "$Prefix '$Param{GetParam}->{Body}' $Op~ /$Match{Body}/i matched NOT! $Suffix",
                );
            }

            return 1;
        }
    }

    # set parameter for matched filter
    for my $Attribute ( sort( keys( %Set ) ) ) {
        $Set{ $Attribute } =~ s/\[\*\*\*\]/$MatchedResult/;
        $Param{GetParam}->{ $Attribute } = $Set{ $Attribute };

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "$Prefix Set param '$Attribute' to '$Set{ $Attribute }' $Suffix",
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
