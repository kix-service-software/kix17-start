# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfigChangeLog::SysLog;

use strict;
use warnings;

use Sys::Syslog qw();

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set syslog facility
    # KIX4OTRS-capeIT
    # $Self->{SysLogFacility} = $Kernel::OM->Get('Kernel::Config')->Get('LogModule::SysLog::Facility') || 'user';
    $Self->{SysLogFacility}
        = $Kernel::OM->Get('Kernel::Config')->Get('SysConfigChangeLog::LogModule::SysLog::Facility')
        || 'user';

    # EO KIX4OTRS-capeIT

    return $Self;
}

sub Log {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

    # prepare data for byte output
    if ( $ConfigObject->Get('LogModule::SysLog::Charset') =~ m/^utf-?8$/ ) {
        $EncodeObject->EncodeOutput( \$Param{Message} );
    }
    else {
        $Param{Message} = $EncodeObject->Convert(
            Text => $Param{Message},
            From => 'utf8',

            # KIX4OTRS-capeIT
            # To    => $ConfigObject->Get('LogModule::SysLog::Charset') || 'iso-8859-15',
            To => $ConfigObject->Get('SysConfigChangeLog::LogModule::SysLog::Charset')
                || 'iso-8859-15',

            # EO KIX4OTRS-capeIT
            Force => 1,
        );
    }

    # According to the docs, this is not needed any longer and should not be used any more.
    # Please see the Sys::Syslog documentation for details.
    # # TODO: remove this code sometime, and the config setting.
    # my $LogSock = $Self->{ConfigObject}->Get('LogModule::SysLog::LogSock') || 'unix';
    # Sys::Syslog::setlogsock($LogSock);
    Sys::Syslog::openlog( $Param{LogPrefix}, 'cons,pid', $Self->{SysLogFacility} );

    if ( lc $Param{Priority} eq 'debug' ) {

        # KIX4OTRS-capeIT
        # Sys::Syslog::syslog( 'debug', "[Debug][$Param{Module}][$Param{Line}] $Param{Message}" );
        Sys::Syslog::syslog( 'debug', "[Debug][$Param{Line}] $Param{Message}" );

        # EO KIX4OTRS-capeIT
    }
    elsif ( lc $Param{Priority} eq 'info' ) {

        # KIX4OTRS-capeIT
        # Sys::Syslog::syslog( 'info', "[Info][$Param{Module}] $Param{Message}" );
        Sys::Syslog::syslog( 'info', "[Info] $Param{Message}" );

        # EO KIX4OTRS-capeIT
    }
    elsif ( lc $Param{Priority} eq 'notice' ) {

        # KIX4OTRS-capeIT
        # Sys::Syslog::syslog( 'notice', "[Notice][$Param{Module}] $Param{Message}" );
        Sys::Syslog::syslog( 'notice', "[Notice] $Param{Message}" );

        # EO KIX4OTRS-capeIT
    }
    elsif ( lc $Param{Priority} eq 'error' ) {

      # KIX4OTRS-capeIT
      # Sys::Syslog::syslog( 'err', "[Error][$Param{Module}][Line:$Param{Line}]: $Param{Message}" );
        Sys::Syslog::syslog( 'err', "[Error][Line:$Param{Line}]: $Param{Message}" );

        # EO KIX4OTRS-capeIT
    }
    else {

        # print error messages to STDERR
        print STDERR
            "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}\n";

        # and of course to syslog
        Sys::Syslog::syslog(
            'err',
            "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}"
        );
    }

    Sys::Syslog::closelog();

    return;
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
