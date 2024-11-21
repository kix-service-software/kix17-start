# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::MatchDBSource;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::PostMaster::Filter',
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

    # get postmaster filter object
    my $PostMasterFilter = $Kernel::OM->Get('Kernel::System::PostMaster::Filter');

    # get all db filters
    my %JobList = $PostMasterFilter->FilterList();

    # prepare suffix for log
    my $Suffix = "(Message-ID: $Param{GetParam}->{'Message-ID'})";

    JOB:
    for my $Job ( sort( keys( %JobList ) ) ) {

        # get config options
        my %Config = $PostMasterFilter->FilterGet(
            Name => $Job
        );

        my %Match;
        my %Set;
        my %Not;
        if ( $Config{Match} ) {
            %Match = %{ $Config{Match} };
        }
        if ( $Config{Set} ) {
            %Set = %{ $Config{Set} };
        }
        if ( $Config{Not} ) {
            %Not = %{ $Config{Not} };
        }
        my $StopAfterMatch = $Config{StopAfterMatch} || 0;
        my $Prefix         = '';
        if ( $Config{Name} ) {
            $Prefix = "Filter: '$Config{Name}'";
        }

        # match 'Match => ???' stuff
        my $MatchedResult = '';
        ATTRIBUTE:
        for my $Attribute ( sort( keys( %Match ) ) ) {

            # check Body as last attribute
            if ( $Attribute eq 'Body' ) {
                next ATTRIBUTE;
            }
            # match only email addresses
            elsif (
                defined( $Param{GetParam}->{ $Attribute } )
                && $Match{ $Attribute } =~ /^EMAILADDRESS:(.*)$/
            ) {
                my $SearchEmail    = $1;
                my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
                    Line => $Param{GetParam}->{ $Attribute },
                );
                my $LocalMatched;
                RECIPIENT:
                for my $Recipients ( @EmailAddresses ) {
                    my $Email = $Self->{ParserObject}->GetEmailAddress(
                        Email => $Recipients
                    );
                    next RECIPIENT if !$Email;

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
                        last RECIPIENT;
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
                    next JOB;
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

                next JOB;
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

                next JOB;
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

        # stop after match
        if ( $StopAfterMatch ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "$Prefix Stopped filter processing because of used 'StopAfterMatch' $Suffix",
            );
            return 1;
        }
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
