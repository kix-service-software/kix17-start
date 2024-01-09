# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# Copyright (C) 2021 Znuny GmbH, https://znuny.org/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with patches licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::Output::HTML::FilterText::URL;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

## no critic qw(RegularExpressions::ProhibitComplexRegexes)

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Pre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{Data} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Data!'
        );
        $Kernel::OM->Get('Kernel::Output::HTML::Layout')->FatalDie();
    }

    $Self->{LinkHash} = undef;
    my $Counter = 0;
    my %Seen;
    ${ $Param{Data} } =~ s{
        ( > | < | &gt; | &lt; | )  # $1 greater-than and less-than sign

        (                                            #2
            (?:                                      # http or only www
                (?: (?: http s? | ftp ) :\/\/) |     # http://,https:// and ftp://
### Patch licensed under the GPL-3.0, Copyright (C) 2021 Znuny GmbH, https://znuny.org/ ###
#                (?: [a-z0-9\-]* \.?                  # allow for sub-domain or prefixes bug#12472
                (?: [a-z0-9\-]{0,255} \.?                  # allow for sub-domain or prefixes bug#12472
### Patch licensed under the GPL-3.0, Copyright (C) 2021 Znuny GmbH, https://znuny.org/ ###
                    (?: www | ftp ) \. \w+           # www.something and ftp.something
                )
            )
            .*?                           # this part should be better defined!
        )
        (                                 # $3
            [\?,;!\.] (?: \s | $ )        # this construct was root cause of bug#2450 and bug#7288
            | \s
            | \"
            | &quot;
            | &nbsp;
            | '
            | >                           # greater-than and less-than sign
            | <                           # "
            | &gt;                        # "
            | &lt;                        # "
            | $                           # bug# 2715
        )        }
    {
        my $Start = $1;
        my $Link  = $2;
        my $End   = $3;
        if ($Seen{$Link}) {
            $Start . $Seen{$Link} . $End;
        }
        else {
            $Counter++;
            if ( $Link !~ m{^ ( http | https | ftp ) : \/ \/ }xi ) {
                if ($Link =~ m{^ ftp }smx ) {
                    $Link = 'ftp://' . $Link;
                }
                else {
                    $Link = 'http://' . $Link;
                }
            }
            my $Length = length $Link ;
            $Length = $Length < 75 ? $Length : 75;
            my $String = '#' x $Length;
            $Self->{LinkHash}->{"[$String$Counter]"} = $Link;
            $Seen{$Link} = "[$String$Counter]";
            $Start . "[$String$Counter]" . $End;
        }
    }egxism;

    return $Param{Data};
}

sub Post {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{Data} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Data!'
        );
        $Kernel::OM->Get('Kernel::Output::HTML::Layout')->FatalDie();
    }

    if ( $Self->{LinkHash} ) {
        for my $Key ( sort keys %{ $Self->{LinkHash} } ) {
            my $LinkSmall = $Self->{LinkHash}->{$Key};
            $LinkSmall =~ s/^(.{75}).*$/$1\[\.\.\]/gs;
            $Self->{LinkHash}->{$Key} =~ s/ //g;
            ${ $Param{Data} }
                =~ s/\Q$Key\E/<a href=\"$Self->{LinkHash}->{$Key}\" target=\"_blank\" title=\"$Self->{LinkHash}->{$Key}\">$LinkSmall<\/a>/g;
        }
    }

    return $Param{Data};
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. This program is
licensed under the AGPL-3.0 with patches licensed under the GPL-3.0.
For details, see the enclosed files LICENSE (AGPL) and
LICENSE-GPL3 (GPL3) for license information. If you did not receive
this files, see <https://www.gnu.org/licenses/agpl.txt> (APGL) and
<https://www.gnu.org/licenses/gpl-3.0.txt> (GPL3).

=cut
