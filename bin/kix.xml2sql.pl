#!/usr/bin/perl
# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

# use ../ as lib location
use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);

use Getopt::Std;

use Kernel::Config;
use Kernel::System::Encode;
use Kernel::System::Time;
use Kernel::System::DB;
use Kernel::System::Log;
use Kernel::System::Main;
use Kernel::System::XML;
use Kernel::System::ObjectManager;

use vars qw($VERSION);
$VERSION = qw($Revision$) [1];

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix.PostMaster.pl',
    },
);

my %Opts = ();
getopt( 'hton', \%Opts );
if ( $Opts{'h'} || !%Opts ) {
    print <<"EOF";
$0 <Revision $VERSION> - tool to generate database specific SQL from the XML database definition files used by KIX

Usage: $0 -t <DATABASE_TYPE> (or 'all') [-o <OUTPUTDIR> -n <NAME> -s <SPLIT_FILES>]
EOF
    exit 1;
}

# name
if ( !$Opts{n} && $Opts{o} ) {
    die 'ERROR: Need -n <NAME>';
}

# output dir
if ( $Opts{o} && !-e $Opts{o} ) {
    die "ERROR: <OUTPUTDIR> $Opts{o} doesn' exist!";
}
if ( !$Opts{o} ) {
    $Opts{o} = '';
}

# database type
if ( !$Opts{t} ) {
    die 'ERROR: Need -t <DATABASE_TYPE>';
}

my @DatabaseType;
if ( $Opts{t} eq 'all' ) {
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my @List         = glob( $ConfigObject->Get('Home') . '/Kernel/System/DB/*.pm' );
    for my $File (@List) {
        $File =~ s/^.*\/(.+?).pm$/$1/;
        push @DatabaseType, $File;
    }
}
else {
    push @DatabaseType, $Opts{t};
}

# read xml file
my @File       = "<STDIN>";
my $FileString = '';
for my $Line (@File) {
    $FileString .= $Line;
}

for my $DatabaseType (@DatabaseType) {

    # create common objects
    my %CommonObject = ();
    $CommonObject{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $CommonObject{ConfigObject}->Set(
        Key   => 'Database::Type',
        Value => $DatabaseType,
    );
    $CommonObject{ConfigObject}->Set(
        Key   => 'Database::ShellOutput',
        Value => 1,
    );
    $CommonObject{EncodeObject} = $Kernel::OM->Get('Kernel::System::Encode');
    $CommonObject{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $CommonObject{MainObject}   = $Kernel::OM->Get('Kernel::System::Main');
    $CommonObject{TimeObject}   = $Kernel::OM->Get('Kernel::System::Time');
    $CommonObject{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $CommonObject{XMLObject}    = $Kernel::OM->Get('Kernel::System::XML');

    # parse xml package
    my @XMLARRAY = $CommonObject{XMLObject}->XMLParse( String => $FileString );

    # remember header
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $CommonObject{TimeObject}->SystemTime2Date(
        SystemTime => $CommonObject{TimeObject}->SystemTime(),
    );

    my $Head = $CommonObject{DBObject}->{Backend}->{'DB::Comment'}
        . "----------------------------------------------------------\n";
    $Head .= $CommonObject{DBObject}->{Backend}->{'DB::Comment'}
        . " driver: $DatabaseType, generated: $Year-$Month-$Day $Hour:$Min:$Sec\n";
    $Head .= $CommonObject{DBObject}->{Backend}->{'DB::Comment'}
        . "----------------------------------------------------------\n";

    # get sql from parsed xml
    my @SQL;
    if ( $CommonObject{DBObject}->{Backend}->{'DB::ShellConnect'} ) {
        push @SQL, $CommonObject{DBObject}->{Backend}->{'DB::ShellConnect'};
    }
    push @SQL, $CommonObject{DBObject}->SQLProcessor( Database => \@XMLARRAY );

    # get port sql from parsed xml
    my @SQLPost;
    if ( $CommonObject{DBObject}->{Backend}->{'DB::ShellConnect'} ) {
        push @SQLPost, $CommonObject{DBObject}->{Backend}->{'DB::ShellConnect'};
    }
    push @SQLPost, $CommonObject{DBObject}->SQLProcessorPost();

    if ( $Opts{s} ) {

        # write create script
        Dump(
            $Opts{o} . '/' . $Opts{n} . '.' . $DatabaseType . '.sql',
            \@SQL,
            $Head,
            $CommonObject{DBObject}->{Backend}->{'DB::ShellCommit'},
            $Opts{o},
        );

        # write post script
        Dump(
            $Opts{o} . '/' . $Opts{n} . '-post.' . $DatabaseType . '.sql',
            \@SQLPost,
            $Head,
            $CommonObject{DBObject}->{Backend}->{'DB::ShellCommit'},
            $Opts{o},
        );
    }
    else {
        Dump(
            $Opts{o} . '/' . $Opts{n} . '.' . $DatabaseType . '.sql',
            [ @SQL, @SQLPost ],
            $Head,
            $CommonObject{DBObject}->{Backend}->{'DB::ShellCommit'},
            $Opts{o},
        );
    }
}

sub Dump {
    my ( $Filename, $SQL, $Head, $Commit, $StdOut ) = @_;

    if ($StdOut) {
        open my $OutHandle, '>', $Filename or die "Can't write: $!";
        binmode $OutHandle, ':encoding(UTF-8)';
        print "writing: $Filename\n";
        print $OutHandle $Head;
        for my $Item ( @{$SQL} ) {
            print $OutHandle $Item . $Commit . "\n";
        }
        close $OutHandle;
    }
    else {
        print $Head;
        for my $Item ( @{$SQL} ) {
            print $Item . $Commit . "\n";
        }
    }

    return 1;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
