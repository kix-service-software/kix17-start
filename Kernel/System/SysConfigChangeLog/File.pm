# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfigChangeLog::File;

use strict;
use warnings;

umask "002";

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get logfile location
    # KIX4OTRS-capeIT
    # $Self->{LogFile} = $ConfigObject->Get('LogModule::LogFile')
    #     || die 'Need LogModule::LogFile param in Config.pm';
    $Self->{LogFile} = $ConfigObject->Get('SysConfigChangeLog::LogModule::LogFile')
        || die 'Need SysConfigChangeLog::LogModule::LogFile param in Config.pm';

#rbo - T2016121190001552 - added KIX placeholders
    # replace config tags
    $Self->{LogFile} =~ s{<(KIX|OTRS)_CONFIG_(.+?)>}{$Self->{ConfigObject}->Get($2)}egx;

    # EO KIX4OTRS-capeIT

    # get log file suffix
    # KIX4OTRS-capeIT
    # if ( $ConfigObject->Get('LogModule::LogFile::Date') ) {
    #     my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = localtime( time() );    ## no critic
    if ( $ConfigObject->Get('SysConfigChangeLog::LogModule::LogFile::Date') ) {
        my ( $s, $m, $h, $D, $M, $Y, $wd, $yd, $dst ) = localtime( time() );

        # EO KIX4OTRS-capeIT
        $Y = $Y + 1900;
        $M = sprintf '%02d', ++$M;
        $Self->{LogFile} .= ".$Y-$M";
    }

    # Fixed bug# 2265 - For IIS we need to create a own error log file.
    # Bind stderr to log file, because iis do print stderr to web page.
    if ( $ENV{SERVER_SOFTWARE} && $ENV{SERVER_SOFTWARE} =~ /^microsoft\-iis/i ) {
        ## no critic
        if ( !open STDERR, '>>', $Self->{LogFile} . '.error' ) {
            ## use critic
            print STDERR "ERROR: Can't write $Self->{LogFile}.error: $!";
        }
    }

    return $Self;
}

sub Log {
    my ( $Self, %Param ) = @_;

    my $FH;

    # open logfile
    ## no critic
    if ( !open $FH, '>>', $Self->{LogFile} ) {
        ## use critic

        # print error screen
        print STDERR "\n";
        print STDERR " >> Can't write $Self->{LogFile}: $! <<\n";
        print STDERR "\n";
        return;
    }

    # write log file
    $Kernel::OM->Get('Kernel::System::Encode')->SetIO($FH);

    print $FH '[' . localtime() . ']';    ## no critic

    if ( lc $Param{Priority} eq 'debug' ) {
        print $FH "[Debug][$Param{Module}][$Param{Line}] $Param{Message}\n";
    }
    elsif ( lc $Param{Priority} eq 'info' ) {

        # KIX4OTRS-capeIT
        # print $FH "[Info][$Param{Module}] $Param{Message}\n";
        print $FH "[Info] $Param{Message}\n";

        # EO KIX4OTRS-capeIT
    }
    elsif ( lc $Param{Priority} eq 'notice' ) {

        # KIX4OTRS-capeIT
        # print $FH "[Notice][$Param{Module}] $Param{Message}\n";
        print $FH "[Notice] $Param{Message}\n";

        # EO KIX4OTRS-capeIT
    }
    elsif ( lc $Param{Priority} eq 'error' ) {
        print $FH "[Error][$Param{Module}][$Param{Line}] $Param{Message}\n";
    }
    else {

        # print error messages to STDERR
        print STDERR
            "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}\n";

        # and of course to logfile
        print $FH
            "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}\n";
    }

    # close file handle
    close $FH;

    return 1;
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
