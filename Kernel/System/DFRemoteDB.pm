# --
# Kernel/System/DFRemoteDB.pm - based on Kernel/System/DB.pm without global configurations
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape(dash)it(dot)de
#
# Depends: OTRS, Kernel/System/DB.pm, 5.0.4
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DFRemoteDB;
## nofilter(TidyAll::Plugin::OTRS::Perl::PODSpelling)

use strict;
use warnings;

use DBI;
use List::Util();

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Time',
);

our $UseSlaveDB = 0;

# capeIT
use base qw(Kernel::System::DB);
# EO capeIT

=head1 NAME

Kernel::System::DB - global database interface

=head1 SYNOPSIS

All database functions to connect/insert/update/delete/... to a database.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create database object, with database connect..
Usually you do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::System::DB' => {
            # if you don't supply the following parameters, the ones found in
            # Kernel/Config.pm are used instead:
            DatabaseDSN  => 'DBI:odbc:database=123;host=localhost;',
            DatabaseUser => 'user',
            DatabasePw   => 'somepass',
            Type         => 'mysql',
            Attribute => {
                LongTruncOk => 1,
                LongReadLen => 100*1024,
            },
        },
    );
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=updates; 2=+selects; 3=+Connects;
    $Self->{Debug} = $Param{Debug} || 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config data
# capeIT
#    $Self->{DSN}  = $Param{DatabaseDSN}  || $ConfigObject->Get('DatabaseDSN');
#    $Self->{USER} = $Param{DatabaseUser} || $ConfigObject->Get('DatabaseUser');
#    $Self->{PW}   = $Param{DatabasePw}   || $ConfigObject->Get('DatabasePw');
# EO capeIT

    $Self->{IsSlaveDB} = $Param{IsSlaveDB};

# capeIT
#    $Self->{SlowLog} = $Param{'Database::SlowLog'}
#        || $ConfigObject->Get('Database::SlowLog');
    # check needed params
    for my $Needed (qw(DatabaseDSN DatabaseUser)) {
        if ( !$Param{$Needed} ) {
            die "Got no Param $Needed!";
        }
    }
    $Self->{DSN}  = $Param{DatabaseDSN};
    $Self->{USER} = $Param{DatabaseUser};
    $Self->{PW}   = $Param{DatabasePw};

    $Self->{SlowLog} = $Param{'Database::SlowLog'};
# EO capeIT

    # decrypt pw (if needed)
    if ( $Self->{PW} =~ /^\{(.*)\}$/ ) {
        $Self->{PW} = $Self->_Decrypt($1);
    }

    # get database type (auto detection)
    if ( $Self->{DSN} =~ /:mysql/i ) {
        $Self->{'DB::Type'} = 'mysql';
    }
    elsif ( $Self->{DSN} =~ /:pg/i ) {
        $Self->{'DB::Type'} = 'postgresql';
    }
    elsif ( $Self->{DSN} =~ /:oracle/i ) {
        $Self->{'DB::Type'} = 'oracle';
    }
    elsif ( $Self->{DSN} =~ /:db2/i ) {
        $Self->{'DB::Type'} = 'db2';
    }
    elsif ( $Self->{DSN} =~ /(mssql|sybase|sql server)/i ) {
        $Self->{'DB::Type'} = 'mssql';
    }

# capeIT
#    # get database type (config option)
#    if ( $ConfigObject->Get('Database::Type') ) {
#        $Self->{'DB::Type'} = $ConfigObject->Get('Database::Type');
#    }
# EO capeIT

    # get database type (overwrite with params)
    if ( $Param{Type} ) {
        $Self->{'DB::Type'} = $Param{Type};
    }

    # load backend module
    if ( $Self->{'DB::Type'} ) {
        my $GenericModule = 'Kernel::System::DB::' . $Self->{'DB::Type'};
        return if !$Kernel::OM->Get('Kernel::System::Main')->Require($GenericModule);
        $Self->{Backend} = $GenericModule->new( %{$Self} );

        # set database functions
        $Self->{Backend}->LoadPreferences();
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'Error',
            Message  => 'Unknown database type! Set option Database::Type in '
                . 'Kernel/Config.pm to (mysql|postgresql|oracle|db2|mssql).',
        );
        return;
    }

# capeIT    # check/get extra database configuration options
    # (overwrite auto-detection with config options)
    for my $Setting (
        qw(
        Type Limit DirectBlob Attribute QuoteSingle QuoteBack
        Connect Encode CaseSensitive LcaseLikeInLargeText
        )
        )
    {
# capeIT
#        if ( defined $Param{$Setting} || defined $ConfigObject->Get("Database::$Setting") )
#        {
#            $Self->{Backend}->{"DB::$Setting"} = $Param{$Setting}
#                // $ConfigObject->Get("Database::$Setting");
        if ( defined $Param{$Setting})
        {
            $Self->{Backend}->{"DB::$Setting"} = $Param{$Setting};
# EO capeIT
        }
    }

    return $Self;
}

=item Connect()

to connect to a database

    $DBObject->Connect();

=cut

sub Connect {
    my $Self = shift;

    # check database handle
    if ( $Self->{dbh} ) {

        return $Self->{dbh} if $Self->{dbh}->ping();

        delete $Self->{dbh};
    }

    # debug
    if ( $Self->{Debug} > 2 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',
            Message =>
# capeIT
#                "DB.pm->Connect: DSN: $Self->{DSN}, User: $Self->{USER}, Pw: $Self->{PW}, DB Type: $Self->{'DB::Type'};",
                "DFRemoteDB.pm->Connect: DSN: $Self->{DSN}, User: $Self->{USER}, Pw: $Self->{PW}, DB Type: $Self->{'DB::Type'};",
# EO capeIT
        );
    }

    # db connect
    $Self->{dbh} = DBI->connect(
        $Self->{DSN},
        $Self->{USER},
        $Self->{PW},
        $Self->{Backend}->{'DB::Attribute'},
    );

    if ( !$Self->{dbh} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'Error',
            Message  => $DBI::errstr,
        );
        return;
    }

    if ( $Self->{Backend}->{'DB::Connect'} ) {
        $Self->Do( SQL => $Self->{Backend}->{'DB::Connect'} );
    }

    # set utf-8 on for PostgreSQL
    if ( $Self->{Backend}->{'DB::Type'} eq 'postgresql' ) {
        $Self->{dbh}->{pg_enable_utf8} = 1;
    }

    if ( $Self->{SlaveDBObject} ) {
        $Self->{SlaveDBObject}->Connect();
    }

    return $Self->{dbh};
}

=item Disconnect()

to disconnect from a database

    $DBObject->Disconnect();

=cut

sub Disconnect {
    my $Self = shift;

    # debug
    if ( $Self->{Debug} > 2 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',
# capeIT
#            Message  => 'DB.pm->Disconnect',
            Message  => 'DFRemoteDB.pm->Disconnect',
# EO capeIT
        );
    }

    # do disconnect
    if ( $Self->{dbh} ) {
        $Self->{dbh}->disconnect();
        delete $Self->{dbh};
    }

    if ( $Self->{SlaveDBObject} ) {
        $Self->{SlaveDBObject}->Disconnect();
    }

    return 1;
}

=item Do()

to insert, update or delete values

    $DBObject->Do( SQL => "INSERT INTO table (name) VALUES ('dog')" );

    $DBObject->Do( SQL => "DELETE FROM table" );

    you also can use DBI bind values (used for large strings):

    my $Var1 = 'dog1';
    my $Var2 = 'dog2';

    $DBObject->Do(
        SQL  => "INSERT INTO table (name1, name2) VALUES (?, ?)",
        Bind => [ \$Var1, \$Var2 ],
    );

=cut

sub Do {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SQL} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need SQL!',
        );
        return;
    }

    if ( $Self->{Backend}->{'DB::PreProcessSQL'} ) {
        $Self->{Backend}->PreProcessSQL( \$Param{SQL} );
    }

    # check bind params
    my @Array;
    if ( $Param{Bind} ) {
        for my $Data ( @{ $Param{Bind} } ) {
            if ( ref $Data eq 'SCALAR' ) {
                push @Array, $$Data;
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Caller   => 1,
                    Priority => 'Error',
                    Message  => 'No SCALAR param in Bind!',
                );
                return;
            }
        }
        if ( @Array && $Self->{Backend}->{'DB::PreProcessBindData'} ) {
            $Self->{Backend}->PreProcessBindData( \@Array );
        }
    }

    # Replace current_timestamp with real time stamp.
    # - This avoids time inconsistencies of app and db server
    # - This avoids timestamp problems in Postgresql servers where
    #   the timestamp is sometimes 1 second off the perl timestamp.
    my $Timestamp = $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp();
    $Param{SQL} =~ s{
        (?<= \s | \( | , )  # lookahead
        current_timestamp   # replace current_timestamp by 'yyyy-mm-dd hh:mm:ss'
        (?=  \s | \) | , )  # lookbehind
    }
    {
        '$Timestamp'
    }xmsg;

    # debug
    if ( $Self->{Debug} > 0 ) {
        $Self->{DoCounter}++;
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',
# capeIT
#            Message  => "DB.pm->Do ($Self->{DoCounter}) SQL: '$Param{SQL}'",
            Message  => "DFRemoteDB.pm->Do ($Self->{DoCounter}) SQL: '$Param{SQL}'",
# EO capeIT
        );
    }

    return if !$Self->Connect();

    # send sql to database
    if ( !$Self->{dbh}->do( $Param{SQL}, undef, @Array ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'error',
            Message  => "$DBI::errstr, SQL: '$Param{SQL}'",
        );
        return;
    }

    return 1;
}

=item Prepare()

to prepare a SELECT statement

    $DBObject->Prepare(
        SQL   => "SELECT id, name FROM table",
        Limit => 10,
    );

or in case you want just to get row 10 until 30

    $DBObject->Prepare(
        SQL   => "SELECT id, name FROM table",
        Start => 10,
        Limit => 20,
    );

in case you don't want utf-8 encoding for some columns, use this:

    $DBObject->Prepare(
        SQL    => "SELECT id, name, content FROM table",
        Encode => [ 1, 1, 0 ],
    );

you also can use DBI bind values, required for large strings:

    my $Var1 = 'dog1';
    my $Var2 = 'dog2';

    $DBObject->Prepare(
        SQL    => "SELECT id, name, content FROM table WHERE name_a = ? AND name_b = ?",
        Encode => [ 1, 1, 0 ],
        Bind   => [ \$Var1, \$Var2 ],
    );

=cut

sub Prepare {
    my ( $Self, %Param ) = @_;

    my $SQL   = $Param{SQL};
    my $Limit = $Param{Limit} || '';
    my $Start = $Param{Start} || '';

    # check needed stuff
    if ( !$Param{SQL} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need SQL!',
        );
        return;
    }

    $Self->{_PreparedOnSlaveDB} = 0;

    # Route SELECT statements to the DB slave if requested and a slave is configured.
    if (
        $UseSlaveDB
        && !$Self->{IsSlaveDB}
        && $Self->_InitSlaveDB()    # this is very cheap after the first call (cached)
        && $SQL =~ m{\A\s*SELECT}xms
        )
    {
        $Self->{_PreparedOnSlaveDB} = 1;
        return $Self->{SlaveDBObject}->Prepare(%Param);
    }

    if ( defined $Param{Encode} ) {
        $Self->{Encode} = $Param{Encode};
    }
    else {
        $Self->{Encode} = undef;
    }
    $Self->{Limit}        = 0;
    $Self->{LimitStart}   = 0;
    $Self->{LimitCounter} = 0;

    # build final select query
    if ($Limit) {
        if ($Start) {
            $Limit = $Limit + $Start;
            $Self->{LimitStart} = $Start;
        }
        if ( $Self->{Backend}->{'DB::Limit'} eq 'limit' ) {
            $SQL .= " LIMIT $Limit";
        }
        elsif ( $Self->{Backend}->{'DB::Limit'} eq 'top' ) {
            $SQL =~ s{ \A \s* (SELECT ([ ]DISTINCT|)) }{$1 TOP $Limit}xmsi;
        }
        else {
            $Self->{Limit} = $Limit;
        }
    }

    # debug
    if ( $Self->{Debug} > 1 ) {
        $Self->{PrepareCounter}++;
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'debug',
# capeIT
#            Message  => "DB.pm->Prepare ($Self->{PrepareCounter}/" . time() . ") SQL: '$SQL'",
            Message  => "DFRemoteDB.pm->Prepare ($Self->{PrepareCounter}/" . time() . ") SQL: '$SQL'",
# EO capeIT
        );
    }

    # slow log feature
    my $LogTime;
    if ( $Self->{SlowLog} ) {
        $LogTime = time();
    }

    if ( $Self->{Backend}->{'DB::PreProcessSQL'} ) {
        $Self->{Backend}->PreProcessSQL( \$SQL );
    }

    # check bind params
    my @Array;
    if ( $Param{Bind} ) {
        for my $Data ( @{ $Param{Bind} } ) {
            if ( ref $Data eq 'SCALAR' ) {
                push @Array, $$Data;
            }
            else {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Caller   => 1,
                    Priority => 'Error',
                    Message  => 'No SCALAR param in Bind!',
                );
                return;
            }
        }
        if ( @Array && $Self->{Backend}->{'DB::PreProcessBindData'} ) {
            $Self->{Backend}->PreProcessBindData( \@Array );
        }
    }

    return if !$Self->Connect();

    # do
    if ( !( $Self->{Cursor} = $Self->{dbh}->prepare($SQL) ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'Error',
            Message  => "$DBI::errstr, SQL: '$SQL'",
        );
        return;
    }

    if ( !$Self->{Cursor}->execute(@Array) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Caller   => 1,
            Priority => 'Error',
            Message  => "$DBI::errstr, SQL: '$SQL'",
        );
        return;
    }

    # slow log feature
    if ( $Self->{SlowLog} ) {
        my $LogTimeTaken = time() - $LogTime;
        if ( $LogTimeTaken > 4 ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Caller   => 1,
                Priority => 'error',
                Message  => "Slow ($LogTimeTaken s) SQL: '$SQL'",
            );
        }
    }

    return 1;
}

1;
