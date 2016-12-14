#!/usr/bin/perl -w
# --
# Download.pm - script to download queues, groups and roles (rights to groups) from an OTRS-instance
# this file is part of the package QueuesGroupsRoles
# Copyright (C) 2006-2015, c.a.p.e. IT GmbH, http://www.cape-it.de/
#
# written/edited by
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Thomas(dot)Lange(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# --

package Kernel::System::Console::Command::QueuesGroupsRoles::Download;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::QueuesGroupsRoles',

);
use utf8;

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description(
        'Download of OTRS queues-groups-roles schema into CSV-file, Copyright (c) 2006-2015 c.a.p.e. IT GmbH, http//www.cape-it.de/'
    );
    my @HeadlineKeys = qw{
        SalutationID SignatureID FollowUpID FollowUpLock UnlockTimeout
        FirstResponseTime FirstResponseNotify UpdateTime UpdateNotify
        SolutionTime SolutionNotify Calendar Validity SystemAddress
    };
    $Self->AddArgument(
        Name => 'filename',
        Description =>
            "/path/to/QGRdescription.csv\n"
            . " CSV-file must be semicolon separated, needs UTF8 encoding and has to be in a format like:\n"
            . "   QCRCSV-FILE     ::= <HEADLINE> <DESC_LINE>\n"
            . "   <HEADLINE>      ::= <QUEUE> <QUEUE_PARAMS> <GROUP> n*{<ROLEn_NAME>}\n"
            . "   <DESC_LINE>     ::= {<QUEUE_NAME>; <GROUP_NAME>; n*{<ROLEn_RIGHTS>} }\n"
            . "   <ROLE_RIGHTS>   ::= RO,MO,CR,OW,PR,NO,RW,\n"
            . "   <GROUP_NAME>    ::= {(<Alphanum>)}\n"
            . "   <QUEUE_NAME>    ::= {<Alphanum>}\n"
            . "   <QUEUE_PARAMS>  ::= {" . join( ";", @HeadlineKeys ) . "}\n"
            . "   <SystemAddress> ::= {<SystemAddressID>||<Emailstring>}\n"
            . "   <Validity>      ::= {<ValidID>||<valid>||<invalid>||<invalid-temporarily>}\n"
            . "   <ROLEn_NAME>    ::= {<Alphanum>}\n\n"
            . " NOTE: Headlines which do not denote a role name are not used."
            . " The order of the columns is important!\n\n",
        Required   => 1,
        ValueRegex => qr/.*/smx,
    );
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;
    $Self->Print("<yellow>Downloading queues-groups-roles schema into CSV-file...</yellow>\n");
    my $QGRObject = $Kernel::OM->Get('Kernel::System::QueuesGroupsRoles');

    my $currLine = undef;
    my $CSV;
    my $FileName = $Self->GetArgument('filename');

    #-------------------------------------------------------------------------------
    # check CSV...
    if ( !open( $CSV, "<", $FileName ) ) {
        die "\nCould not open file: <$FileName> ($!).\n";
    }

    #-------------------------------------------------------------------------------
    # process CSV...
    my @Result = $QGRObject->QGRShow();
    my @Head   = @{ $Result[0] };
    my @Data   = @{ $Result[1] };

    my $Result = $QGRObject->Download(
        Head => \@Head,
        Data => \@Data,
    );

    my $OutputFile = $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
        Location   => $FileName,
        Content    => \$Result,
        Mode       => 'utf8',
        Type       => 'Local',
        Permission => '644',
    );
    if ($OutputFile) {
        $Self->Print("<green>Export written to <$OutputFile>.</green>\n");
    }
    else {
        $Self->Print("<red>Could not write export to <$FileName>.</red>\n");
    }
    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
