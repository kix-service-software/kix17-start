
###############################################################################
##                                                                           ##
##    Copyright (c) 2000 - 2009 by Steffen Beyer.                            ##
##    All rights reserved.                                                   ##
##                                                                           ##
##    This package is free software; you can redistribute it                 ##
##    and/or modify it under the same terms as Perl itself.                  ##
##                                                                           ##
###############################################################################

package Date::Pcalendar::Profiles;

BEGIN { eval { require bytes; }; }
use strict;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION $Profiles );

require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw();

@EXPORT_OK = qw(
    $Profiles
    &Previous_Friday
    &Next_Monday
    &Next_Monday_or_Tuesday
    &Nearest_Workday
    &Sunday_to_Monday
    &Advent1
    &Advent2
    &Advent3
    &Advent4
    &Advent
);

$VERSION = '6.1';

use Date::Pcalc qw(:all);
use Carp::Clan qw(^Date::);

##########################################################################
#                                                                        #
#  Moving ("variable") holidays depending on the date of Easter Sunday:  #
#                                                                        #
#  Weiberfastnacht, Fettdonnerstag                         =  -52 days   #
#  Carnival Monday / Rosenmontag / Veille du Mardi Gras    =  -48 days   #
#  Mardi Gras / Karnevalsdienstag / Mardi Gras             =  -47 days   #
#  Ash Wednesday / Aschermittwoch / Mercredi des Cendres   =  -46 days   #
#  Palm Sunday / Palmsonntag / Dimanche des Rameaux        =   -7 days   #
#  Maundy Thursday / Gruendonnerstag / Jeudi avant Paques  =   -3 days   #
#  Good Friday / Karfreitag / Vendredi Saint               =   -2 days   #
#  Easter Saturday / Ostersamstag / Samedi de Paques       =   -1 day    #
#  Easter Sunday / Ostersonntag / Dimanche de Paques       =   +0 days   #
#  Easter Monday / Ostermontag / Lundi de Paques           =   +1 day    #
#  Prayer Day / Bettag / Jour de la Priere (Denmark)       =  +26 days   #
#  Ascension of Christ / Christi Himmelfahrt / Ascension   =  +39 days   #
#  Whitsunday / Pfingstsonntag / Dimanche de Pentecote     =  +49 days   #
#  Whitmonday / Pfingstmontag / Lundi de Pentecote         =  +50 days   #
#  Feast of Corpus Christi / Fronleichnam / Fete-Dieu      =  +60 days   #
#                                                                        #
##########################################################################

###############################################
#                                             #
# Rules to enhance readability:               #
#                                             #
# 1) First level constants in single quotes,  #
#    second level constants in double quotes. #
# 2) Use leading zeros for fixed length.      #
#                                             #
###############################################

#####################
# Global variables: #
#####################

$Profiles = { };

###############################
# Global utility subroutines: #
###############################

sub Previous_Friday
{
    my($yy) = shift;
    my($mm) = shift;
    my($dd) = shift;
    my($dow);

# If holiday falls on Saturday or Sunday, use previous Friday instead:

    $dow = Day_of_Week($yy,$mm,$dd);
    if    ($dow == 6) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,-1); }
    elsif ($dow == 7) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,-2); }
    return($yy,$mm,$dd,@_);
}

sub Next_Monday
{
    my($yy) = shift;
    my($mm) = shift;
    my($dd) = shift;
    my($dow);

# If holiday falls on Saturday, use following Monday instead;
# if holiday falls on Sunday, use day thereafter (Monday) instead:

    $dow = Day_of_Week($yy,$mm,$dd);
    if    ($dow == 6) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,+2); }
    elsif ($dow == 7) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,+1); }
    return($yy,$mm,$dd,@_);
}

sub Next_Monday_or_Tuesday # For second holiday of two adjacent ones!
{
    my($yy) = shift;
    my($mm) = shift;
    my($dd) = shift;
    my($dow);

# If holiday falls on Saturday, use following Monday instead;
# if holiday falls on Sunday or Monday, use next Tuesday instead
# (because Monday is already taken by adjacent holiday on the day before):

    $dow = Day_of_Week($yy,$mm,$dd);
    if    ($dow == 6 or $dow == 7) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,+2); }
    elsif ($dow == 1)              { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,+1); }
    return($yy,$mm,$dd,@_);
}

sub Nearest_Workday
{
    my($yy) = shift;
    my($mm) = shift;
    my($dd) = shift;
    my($dow);

# If holiday falls on Saturday, use day before (Friday) instead;
# if holiday falls on Sunday, use day thereafter (Monday) instead:

    $dow = Day_of_Week($yy,$mm,$dd);
    if    ($dow == 6) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,-1); }
    elsif ($dow == 7) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,+1); }
    return($yy,$mm,$dd,@_);
}

sub Sunday_to_Monday
{
    my($yy) = shift;
    my($mm) = shift;
    my($dd) = shift;
    my($dow);

# If holiday falls on Sunday, use day thereafter (Monday) instead:

    $dow = Day_of_Week($yy,$mm,$dd);
    if ($dow == 7) { ($yy,$mm,$dd) = Add_Delta_Days($yy,$mm,$dd,+1); }
    return($yy,$mm,$dd,@_);
}

######################################
# Global utility callback functions: #
######################################

sub Advent1
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,12,25,
        -(Day_of_Week($year,12,25)+21)), '#' );
}
sub Advent2
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,12,25,
        -(Day_of_Week($year,12,25)+14)), '#' );
}
sub Advent3
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,12,25,
        -(Day_of_Week($year,12,25)+7)), '#' );
}
sub Advent4
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,12,25,
        -Day_of_Week($year,12,25)), '#' );
}

sub Advent
{
    my($year,$label) = @_;
    my($offset);

    $offset = (4 - substr($label,0,1)) * 7;
    return( Add_Delta_Days($year,12,25,
        -(Day_of_Week($year,12,25)+$offset)), '#' );
}

###################
# Local profiles: #
###################

$Profiles->{'DE'} = # Deutschland
{
    # For labeling only (defaults, may be overridden):
    "Dreik�nigstag"             => "#06.01.",
    "Valentinstag"              => "#14.02.",
    "Weltfrauentag"             => "#08.03.",
    "Josephstag"                => "#19.03.",
    "Fr�hlingsanfang"           => "#20.03.",
    "Sommeranfang"              => "#21.06.",
    "Herbstanfang"              => "#23.09.",
    "Winteranfang"              => "#21.12.",
    "Beginn d. Sommerzeit"      => "#5/Sun/Mar",
    "Fettdonnerstag"            => "#-52",
    "Weiberfastnacht"           => "#-52",
    "Rosenmontag"               => "#-48",
    "Karnevalsdienstag"         => "#-47",
    "Aschermittwoch"            => "#-46",
    "Palmsonntag"               => "#-7",
    "Gr�ndonnerstag"            => "#-3",
    "Karfreitag"                => "#-2",
    "Karsamstag"                => "#-1",
    "Muttertag"                 => "#2/Sun/May",
    "Vatertag"                  => "#2/Sun/Aug",
    "Peter und Paul"            => "#29.06.",
    "Fronleichnam"              => "#+60",
    "Mari� Himmelfahrt"         => "#15.08.",
    "Erntedankfest"             => "#1/Sun/Oct",
    "Ende d. Sommerzeit"        => "#5/Sun/Oct",
    "Reformationstag"           => "#31.10.",
    "Allerheiligen"             => "#01.11.",
    "Allerseelen"               => "#02.11.",
    "Martinstag"                => "#11.11.",
    "Mari� Empf�ngnis"          => "#08.12.",
    "Bu�- und Bettag"           => \&DE_Buss_und_Bettag2,
    "Volkstrauertag"            => \&DE_Volkstrauertag,
    "Totensonntag"              => \&DE_Totensonntag,
    "1. Advent"                 => \&Advent,
    "2. Advent"                 => \&Advent,
    "3. Advent"                 => \&Advent,
    "4. Advent"                 => \&Advent,
    "Nikolaus"                  => "#06.12.",
    "Heiligabend"               => "#24.12.",
    "Sylvester"                 => "#31.12.",
    # Common legal holidays (in all federal states):
    "Neujahr"                   => "01.01.",
    "Karfreitag"                => "-2",
    "Ostersonntag"              => "+0",
    "Ostermontag"               => "+1",
    "Tag der Arbeit"            => "01.05.",
    "Christi Himmelfahrt"       => "+39",
    "Pfingstsonntag"            => "+49",
    "Pfingstmontag"             => "+50",
    "Tag der deutschen Einheit" => "03.10.",
    "1. Weihnachtsfeiertag"     => "25.12.",
    "2. Weihnachtsfeiertag"     => "26.12."
};

$Profiles->{'DE-BW'} = # Baden-W�rttemberg
{
    %{$Profiles->{'DE'}},
    "Dreik�nigstag"             => "06.01.",
    "Fronleichnam"              => "+60",
    "Allerheiligen"             => "01.11."
};
$Profiles->{'DE-BY'} = # Bayern
{
    %{$Profiles->{'DE'}},
    "Dreik�nigstag"             => "06.01.",
    "Fronleichnam"              => "+60",
    "Mari� Himmelfahrt"         => "15.08.",
    "Allerheiligen"             => "01.11."
};
$Profiles->{'DE-BE'} = # Berlin
{
    %{$Profiles->{'DE'}}
};
$Profiles->{'DE-BB'} = # Brandenburg
{
    %{$Profiles->{'DE'}},
    "Reformationstag"           => "31.10."
};
$Profiles->{'DE-HB'} = # Bremen
{
    %{$Profiles->{'DE'}}
};
$Profiles->{'DE-HH'} = # Hamburg
{
    %{$Profiles->{'DE'}}
};
$Profiles->{'DE-HE'} = # Hessen
{
    %{$Profiles->{'DE'}},
    "Fronleichnam"              => "+60"
};
$Profiles->{'DE-MV'} = # Mecklenburg-Vorpommern
{
    %{$Profiles->{'DE'}},
    "Reformationstag"           => "31.10."
};
$Profiles->{'DE-NI'} = # Niedersachsen
{
    %{$Profiles->{'DE'}}
};
$Profiles->{'DE-NW'} = # Nordrhein-Westfalen
{
    %{$Profiles->{'DE'}},
    "Fronleichnam"              => "+60",
    "Allerheiligen"             => "01.11."
};
$Profiles->{'DE-RP'} = # Rheinland-Pfalz
{
    %{$Profiles->{'DE'}},
    "Fronleichnam"              => "+60",
    "Allerheiligen"             => "01.11."
};
$Profiles->{'DE-SL'} = # Saarland
{
    %{$Profiles->{'DE'}},
    "Fronleichnam"              => "+60",
    "Mari� Himmelfahrt"         => "15.08.",
    "Allerheiligen"             => "01.11."
};
$Profiles->{'DE-SN'} = # Sachsen
{
    %{$Profiles->{'DE'}},
    "Reformationstag"           => "31.10.",
    "Bu�- und Bettag"           => \&DE_Buss_und_Bettag
};
$Profiles->{'DE-ST'} = # Sachsen-Anhalt
{
    %{$Profiles->{'DE'}},
    "Dreik�nigstag"             => "06.01.",
    "Reformationstag"           => "31.10."
};
$Profiles->{'DE-SH'} = # Schleswig-Holstein
{
    %{$Profiles->{'DE'}}
};
$Profiles->{'DE-TH'} = # Th�ringen
{
    %{$Profiles->{'DE'}},
    "Reformationstag"           => "31.10."
};

# Alternative:
# Buss- und Bettag = 1. Advent - 11 Tage
#        1. Advent = 4. Advent - 21 Tage (3 Wochen)
#        4. Advent = letzter Sonntag vor dem 25.12.
# (Beide Alternativen sind auf dem Definitionsbereich
# [1583..2299] aequivalent!)
#sub DE_Buss_und_Bettag
#{
#    my($year,$label) = @_;
#    return( Add_Delta_Days($year,12,25,
#        -(Day_of_Week($year,12,25)+32)) );
#}

sub DE_Buss_und_Bettag # Dritter Werktags-Mittwoch im November
{
    my($year,$label) = @_;
    if (Day_of_Week($year,11,1) == 3)
        { return( Nth_Weekday_of_Month_Year($year,11,3,4) ); }
    else
        { return( Nth_Weekday_of_Month_Year($year,11,3,3) ); }
}
sub DE_Buss_und_Bettag2
{
    return( &DE_Buss_und_Bettag(@_), '#' );
}
sub DE_Volkstrauertag
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,12,25,
        -(Day_of_Week($year,12,25)+35)), '#' );
}
sub DE_Totensonntag
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,12,25,
        -(Day_of_Week($year,12,25)+28)), '#' );
}

# Thanks to:
# David Cassell <cassell@mercury.cor.epa.gov>
# Larry Rosler <lr@hpl.hp.com>
# Anthony Argyriou <anthony@alphageo.com>
# Philip Newton <pne@writeme.com>
# Joe Rice <riceja@water-melon.net>
# Sridhar Gopal <sridhar.gopal@bankofamerica.com>

$Profiles->{'US'} = # United States of America
{
    # For labeling only (defaults, may be overridden):
    "Valentine's Day"               => "#Feb/14",
    "Maundy Thursday"               => "#-3",
    "Good Friday"                   => "#-2",
    "Election Day"                  => \&US_Election,
    # Common legal holidays (in all federal states):
    "New Year's Day"                => \&US_New_Year,
    "Martin Luther King's Birthday" => "3/Mon/Jan",
    "Civil Rights Day"              => "#3/Mon/Jan", # Thanks to Michael G. Schwern <mschwern@cpan.org>
    "Human Rights Day"              => "#3/Mon/Jan", # and http://en.wikipedia.org/wiki/Martin_Luther_King_Day
    "President's Day"               => "3/Mon/Feb",
    "Washington's Birthday"         => "#3/Mon/Feb", # Thanks to Michael G. Schwern <mschwern@cpan.org>
    "Memorial Day"                  => "5/Mon/May",
    "Independence Day"              => \&US_Independence,
    "Labor Day"                     => "1/Mon/Sep",
    "Columbus Day"                  => "2/Mon/Oct",
    "Halloween"                     => "#Oct/31",
    "All Saints Day"                => "#Nov/1",
    "All Souls Day"                 => "#Nov/2",
    "Veterans' Day"                 => \&US_Veteran,
    "Thanksgiving Day"              => "4/Thu/Nov",
    "Christmas Day"                 => \&US_Christmas,
    # Federal observances (thanks to http://en.wikipedia.org/wiki/US_holidays):
    "Inauguration Day"              => "#Jan/20",
    "Super Bowl Sunday"             => "#1/Sun/Feb",
    "Groundhog Day"                 => "#Feb/2",
    "St. Patrick's Day"             => "#Mar/17",
    "Earth Day"                     => "#Apr/22",
    "Cinco de Mayo"                 => "#May/5",
    "Mother's Day"                  => "#2/Sun/May",
    "Father's Day"                  => "#3/Sun/Jun",
    "Pearl Harbor Remembrance Day"  => "#Dec/7",
    "Winter Solstice"               => "#Dec/21",
    "Christmas Eve"                 => "#Dec/24",
    "New Year's Eve"                => "#Dec/31"
};

sub US_New_Year # First of January
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,1) );
}
sub US_Independence # Fourth of July
{
    my($year,$label) = @_;
    return( &Nearest_Workday($year,7,4) );
}
sub US_Labor # First Monday after the first Sunday in September
{
    my($year,$label) = @_;
    return( Add_Delta_Days(
        Nth_Weekday_of_Month_Year($year,9,7,1), +1) );
}
sub US_Election # First Tuesday after the first Monday in November
{
    my($year,$label) = @_;
    return( Add_Delta_Days(
        Nth_Weekday_of_Month_Year($year,11,1,1), +1), '#' );
}
sub US_Veteran # 11th of November
{
    my($year,$label) = @_;
    return( &Nearest_Workday($year,11,11) );
}
sub US_Christmas # 25th of December
{
    my($year,$label) = @_;
    return( &Next_Monday($year,12,25) );
}

$Profiles->{'US-AK'} = # Alaska
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-AL'} = # Alabama
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-AR'} = # Arkansas
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-AS'} = # American Samoa
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-AZ'} = # Arizona
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-CA'} = # California
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-CO'} = # Colorado
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-CT'} = # Connecticut
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-DC'} = # District of Columbia
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-DE'} = # Delaware
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-FL'} = # Florida
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-FM'} = # Federated States of Micronesia
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-GA'} = # Georgia
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-GU'} = # Guam
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-HI'} = # Hawaii
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-IA'} = # Iowa
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-ID'} = # Idaho
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-IL'} = # Illinois
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-IN'} = # Indiana
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-KS'} = # Kansas
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-KY'} = # Kentucky
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-LA'} = # Louisiana
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MA'} = # Massachusetts
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MD'} = # Maryland
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-ME'} = # Maine
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MH'} = # Marshall Islands
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MI'} = # Michigan
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MN'} = # Minnesota
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MO'} = # Missouri
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MP'} = # Northern Mariana Islands
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MS'} = # Mississippi
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-MT'} = # Montana
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-NC'} = # North Carolina
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-ND'} = # North Dakota
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-NE'} = # Nebraska
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-NH'} = # New Hampshire
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-NJ'} = # New Jersey
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-NM'} = # New Mexico
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-NV'} = # Nevada
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-NY'} = # New York
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-OH'} = # Ohio
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-OK'} = # Oklahoma
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-OR'} = # Oregon
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-PA'} = # Pennsylvania
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-PR'} = # Puerto Rico
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-PW'} = # Palau
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-RI'} = # Rhode Island
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-SC'} = # South Carolina
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-SD'} = # South Dakota
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-TN'} = # Tennessee
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-TX'} = # Texas
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-UT'} = # Utah
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-VA'} = # Virginia
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-VI'} = # Virgin Islands
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-VT'} = # Vermont
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-WA'} = # Washington
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-WI'} = # Wisconsin
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-WV'} = # West Virginia
{
    %{$Profiles->{'US'}}
};
$Profiles->{'US-WY'} = # Wyoming
{
    %{$Profiles->{'US'}}
};

# Thanks to:
# M Lyons <lyonsm@bob.globalmediacorp.com>
# Larry Rosler <lr@hpl.hp.com>
# Geoff Baskwill <glb@nortel.ca>
# Simon Perreault <nomis80@linuxquebec.com>

$Profiles->{'CA'} = # Canada
{
    "New Year's Day"       => "Jan/01",
    "Good Friday"          => "-2",
    "Labour Day"           => "1/Mon/Sep",
    "Christmas Day"        => "Dec/25"
};

sub CA_QC_Dollard # First Monday before May 25
{
    my($year,$label) = @_;
    my($dow) = Day_of_Week($year, 5, 25);
    return( Add_Delta_Days($year, 5, 25, 1-$dow) );
}

$Profiles->{'CA-AB'} = # Alberta
{
    %{$Profiles->{'CA'}},
    "Family Day"           => "3/Mon/Feb",
    "Victoria Day"         => "May/22",
    "Canada Day"           => "Jul/01",
    "Thanksgiving Day"     => "2/Mon/Oct",
    "Remembrance Day"      => "Nov/11"
};
$Profiles->{'CA-BC'} = # British Columbia
{
    %{$Profiles->{'CA'}},
    "Victoria Day"         => "May/22",
    "Canada Day"           => "Jul/01",
    "British Columbia Day" => "1/Mon/Aug",
    "Thanksgiving Day"     => "2/Mon/Oct",
    "Remembrance Day"      => "Nov/11"
};
$Profiles->{'CA-MB'} = # Manitoba
{
    %{$Profiles->{'CA'}},
    "Victoria Day"         => "May/22",
    "Canada Day"           => "Jul/01",
    "Thanksgiving Day"     => "2/Mon/Oct"
};
$Profiles->{'CA-NB'} = # New Brunswick
{
    %{$Profiles->{'CA'}},
    "Canada Day"           => "Jul/01",
    "New Brunswick Day"    => "1/Mon/Aug"
};
$Profiles->{'CA-NF'} = # Newfoundland
{
    %{$Profiles->{'CA'}},
    "Memorial Day"         => "Jul/01"
};
$Profiles->{'CA-NS'} = # Nova Scotia
{
    %{$Profiles->{'CA'}},
    "Canada Day"           => "Jul/01"
};
$Profiles->{'CA-NT'} = # Northwest Territories and Nunavut
{
    %{$Profiles->{'CA'}},
    "Victoria Day"         => "May/22",
    "Canada Day"           => "Jul/01",
    "Thanksgiving Day"     => "2/Mon/Oct",
    "Remembrance Day"      => "Nov/11"
};
$Profiles->{'CA-ON'} = # Ontario
{
    %{$Profiles->{'CA'}},
    "Victoria Day"         => "May/22",
    "Canada Day"           => "Jul/01",
    "Family Day"           => "3/Mon/Feb", # Thanks to
    "Civic Holiday"        => "1/Mon/Aug", # Iain Dwyer <dermanus@gmail.com>
    "Thanksgiving Day"     => "2/Mon/Oct",
    "Boxing Day"           => "Dec/26"
};
$Profiles->{'CA-PE'} = # Prince Edward Island
{
    %{$Profiles->{'CA'}},
    "Canada Day"           => "Jul/01"
};
$Profiles->{'CA-QC'} = # Qu�bec
{
    "Jour de l'an"         => "Jan/01",
    "Vendredi Saint"       => "-2",
    "P�ques"               => "+0",
    "Lundi de P�ques"      => "+1",
    "F�te de Dollard"      => \&CA_QC_Dollard,
    "F�te du Qu�bec"       => "Jun/24",
    "F�te du Canada"       => "Jul/01",
    "F�te du Travail"      => "1/Mon/Sep",
    "Action de Gr�ce"      => "2/Mon/Oct",
    "No�l"                 => "Dec/25"
};
$Profiles->{'CA-SK'} = # Saskatchewan
{
    %{$Profiles->{'CA'}},
    "Victoria Day"         => "May/22",
    "Canada Day"           => "Jul/01",
    "Saskatchewan Day"     => "1/Mon/Aug",
    "Thanksgiving Day"     => "2/Mon/Oct",
    "Remembrance Day"      => "Nov/11"
};
$Profiles->{'CA-YK'} = # Yukon Territory
{
    %{$Profiles->{'CA'}},
    "Victoria Day"         => "May/22",
    "Canada Day"           => "Jul/01",
    "Discovery Day"        => "3/Mon/Aug",
    "Thanksgiving Day"     => "2/Mon/Oct",
    "Remembrance Day"      => "Nov/11"
};

# Thanks to:
# Nora Elia Castillo <nec@leia.sunmexico.Sun.COM>

$Profiles->{'MX'} = # Mexico
{
    "A�o Nuevo"                    => "01-01",
    "D�a de la Constituci�n"       => "05-02",
    "Natalicio de Benito Juarez"   => "21-03",
    "D�a del Trabajo"              => "01-05",
    "D�a de la Independencia"      => "16-09",
    "Revoluci�n Mexicana"          => "20-11",
    "Navidad"                      => "25-12"
};

# Thanks to:
# Slawek Szmyd <slawek@msstudio.com.pl>
# Marcin Wlazlowski <marcin@msstudio.com.pl>

$Profiles->{'PL'} = # Polska
{
    "Nowy Rok"                             => "01.01.",
    "Trzech Kroli"                         => "#06.01.",
    "Dzien Babci"                          => "#21.01.",
    "Dzien Dziadka"                        => "#22.01.",
    "Walentynki"                           => "#14.02.",
    "Dzien Kobiet"                         => "#08.03.",

    "Tlusty Czwartek"                      => "#-52",
    "Ostatki"                              => "#-47",
    "Sroda Popielcowa"                     => "#-46",
    "Niedziela Palmowa"                    => "#-7",
    "Wielkanoc"                            => "+0",
    "Poniedzialek Wielkanocny"             => "+1",
    "Zielone Swiatki"                      => "#+49",
    "Boze Cialo"                           => "+60",

    "Prima Aprilis"                        => "#01.04.",
    "Swieto Pracy"                         => "01.05.",
    "Swieto Narodowe 3 Maja"               => "03.05.",
    "Dzien Matki"                          => "#26.05.",
    "Dzien Dziecka"                        => "#01.06.",
    "Dzien Ojca"                           => "#23.06.",
    "Wniebowziecie NMP"                    => "15.08.",
    "Dzien Nauczyciela"                    => "#14.10.",
    "Halloween"                            => "#Oct/31",
    "Wszystkich Swietych"                  => "01.11.",
    "Dzien Zaduszny"                       => "#02.11",
    "Narodowe Swieto Niepodleglosci"       => "11.11.",
    "Andrzejki"                            => "#30.11.",
    "Mikolajki"                            => "#06.12.",
    "Wigilia"                              => "#24.12.",
    "Boze Narodzenie pierwszy dzien Swiat" => "25.12.",
    "Boze Narodzenie drugi dzien Swiat"    => "26.12.",
    "Sylwester"                            => "#31.12."
};

$Profiles->{'PL-SW'} = # kalendarz z wieksza iloscia Swiat
{
    %{$Profiles->{'PL'}},
    "Wielki Czwartek"                      => "#-3",
    "Wielki Piatek"                        => "#-2",
    "Poczatek Adwentu"                     => \&Advent1,
    "Swieto Dziekczynienia"                => "#4/Thu/Nov"
};

## ISO-Latin-2:
#
## Thanks to:
## S�awek Szmyd <slawek@msstudio.com.pl>
## Marcin Wlaz�owski <marcin@msstudio.com.pl>
#
#$Profiles->{'PL'} = # Polska
#{
#    "Nowy Rok"                             => "01.01.",
#    "Trzech Kr�li"                         => "#06.01.",
#    "Dzie� Babci"                          => "#21.01.",
#    "Dzie� Dziadka"                        => "#22.01.",
#    "Walentynki"                           => "#14.02.",
#    "Dzie� Kobiet"                         => "#08.03.",
#
#    "T�usty Czwartek"                      => "#-52",
#    "Ostatki"                              => "#-47",
#    "�roda Polpielcowa"                    => "#-46",
#    "Niedziela Palmowa"                    => "#-7",
#    "Wielkanoc"                            => "+0",
#    "Poniedzia�ek Wielkanocny"             => "+1",
#    "Zielone �wi�tki"                      => "#+49",
#    "Bo�e Cia�o"                           => "+60",
#
#    "Prima Aprilis"                        => "#01.04.",
#    "�wi�to Pracy"                         => "01.05.",
#    "�wi�to Narodowe 3 Maja"               => "03.05.",
#    "Dzie� Matki"                          => "#26.05.",
#    "Dzie� Dziecka"                        => "#01.06.",
#    "Dzie� Ojca"                           => "#23.06.",
#    "Wniebowzi�cie NMP"                    => "15.08.",
#    "Dzie� Nauczyciela"                    => "#14.10.",
#    "Halloween"                            => "#Oct/31",
#    "Wszystkich �wi�tych"                  => "01.11.",
#    "Dzie� Zaduszny"                       => "#02.11",
#    "Narodowe �wi�to Niepodleg�o�ci"       => "11.11.",
#    "Andrzejki"                            => "#30.11.",
#    "Miko�ajki"                            => "#06.12.",
#    "Wigilia"                              => "#24.12.",
#    "Bo�e Narodzenie pierwszy dzie� �wi�t" => "25.12.",
#    "Bo�e Narodzenie drugi dzie� �wi�t"    => "26.12.",
#    "Sylwester"                            => "#31.12."
#};
#
#$Profiles->{'PL-SW'} = # kalendarz z wieksza iloscia Swiat
#{
#    %{$Profiles->{'PL'}},
#    "Wielki Czwartek"                      => "#-3",
#    "Wielki Pi�tek"                        => "#-2",
#    "Pocz�tek Adwentu"                     => \&Advent1,
#    "�wi�to Dzi�kczynienia"                => "#4/Thu/Nov"
#};

$Profiles->{'AT'} = # �sterreich
{
    "Neujahr"                   => "01.01.",
    "Dreik�nigstag"             => "06.01.",
    "Karfreitag"                => "#-2", # regional unterschiedlich
    "Ostersonntag"              => "+0",
    "Ostermontag"               => "+1",
    "Staatsfeiertag"            => "01.05.",
    "Christi Himmelfahrt"       => "+39",
    "Pfingstsonntag"            => "+49",
    "Pfingstmontag"             => "+50",
    "Fronleichnam"              => "+60",
    "Mari� Himmelfahrt"         => "15.08.",
    "Nationalfeiertag"          => "26.10.",
    "Allerheiligen"             => "01.11.",
    "Mari� Empf�ngnis"          => "08.12.",
    "Christtag"                 => "25.12.",
    "Stephanitag"               => "26.12."
};

# Thanks to:
# Herbert Liechti <herbert.liechti@thinx.ch>
# Marco Hunn <m_hunn@blue-design.ch>
# Aldo Calpini <dada@perl.it>

$Profiles->{'CH-DE'} = # Schweiz - Deutsch
{
    "Neujahr"                   => "01.01.",
    "Dreik�nigstag"             => "06.01.",
    "Karfreitag"                => "#-2",
    "Ostersonntag"              => "+0",
    "Ostermontag"               => "+1",
    "Auffahrt"                  => "+39",
    "Pfingstsonntag"            => "+49",
    "Pfingstmontag"             => "+50",
    "Fronleichnam"              => "#+60",
    "Bundesfeiertag"            => "01.08.",
    "Mari� Himmelfahrt"         => "#15.08.",
    "Allerheiligen"             => "#01.11.",
    "Weihnachten"               => "25.12.",
    "Stefanstag"                => "26.12."
};
$Profiles->{'CH-FR'} = # Suisse - Fran�ais
{
    "Nouvel An"                 => "01.01.",
    "�piphanie"                 => "06.01.",
    "Vendredi Saint"            => "#-2",
    "P�ques"                    => "+0",
    "Lundi de P�ques"           => "+1",
    "L'Ascension"               => "+39",
    "La Pentec�te"              => "+49",
    "Lundi de Pentec�te"        => "+50",
    "F�te Dieu"                 => "#+60",
    "F�te f�d�rale"             => "01.08.",
    "Assomption"                => "#15.08.",
    "Toussaint"                 => "#01.11.",
    "N�el"                      => "25.12.",
    "St. Etienne"               => "26.12."
};
$Profiles->{'CH-IT'} = # Switzerland - Italian
{
    "Capo d'Anno"               => "01.01.",
    "Epifania"                  => "06.01.",
    "Venerd� Santo"             => "#-2",
    "Pasqua"                    => "+0",
    "Luned� di Pasqua"          => "+1",
    "Ascensione"                => "+39",
    "Pentecoste"                => "+49",
    "Luned� di Pentecoste"      => "+50",
    "Corpus Domini"             => "#+60",
    "Festa federale"            => "01.08.",
    "Assunzione di M.V."        => "#15.08.",
    "Ognissanti"                => "#01.11.",
    "S. Natale"                 => "25.12.",
    "S. Stefano"                => "26.12."
};
$Profiles->{'CH-RM'} = # Swizra rumantscha (Switzerland - Rhaeto-Romance)
{
    "B�man"                     => "01.01.",
    "Di da la Babania"          => "#06.01.",
    "Venderdi sonch"            => "-2",
    "Dumengia da Pasqua"        => "+0",
    "Fir� da Pasqua"            => "+1",
    "Ascensiun"                 => "+39",
    "Dumengia da Tschinquaisma" => "+49",
    "Fir� da Tschinquaisma"     => "+50",
    "Sonch sang"                => "#+60",
    "Festa federala"            => "01.08.",
    "Assunziun da Maria"        => "#15.08.",
    "Festa da tuot ils sonchs"  => "#01.11.",
    "Festa da Nadal"            => "25.12.",
    "Stefan sonch"              => "26.12."
};

# Thanks to:
# Fran�ois Desarmenien <francois@fdesar.net>
# Arnaud Calvo <arnaud@calvo-france.com>
# Jean Forget <ponder.stibbons@wanadoo.fr>
# Cedric Bouvier <Cedric.Bouvier@ctp.com>
# Julien Quint <julien.quint@imag.fr>

$Profiles->{'FR'} = # France
{
    "Jour de l'An"              => "01.01.",
    "�piphanie"                   => "#06.01.",
    "Chandeleur"                => "#02.02.",
    "Mardi-Gras"                => "#-47",
    "Mercredi des Cendres"      => "#-46",
    "Dimanche des Rameaux"      => "-7",
    "P�ques"                    => "+0",
    "Lundi de P�ques"           => "+1",
    "Fin de Guerre d'Alg�rie"   => "#19.03.", # Contrat d'Evian 19.03.1962
    "F�te du Travail"           => "01.05.",
    "Victoire 1945"             => "08.05.",
    "Saint Jean"                => "#24.06.",
    "Ascension"                 => "+39",
    "Pentec�te"                 => "+49",
    "Lundi de Pentec�te"        => "+50",
    "F�te Nationale"            => "14.07.",
    "Assomption"                => "15.08.",
    "Toussaint"                 => "01.11.",
    "Jour des D�funts"          => "#02.11.",
    "Saint Martin"              => "#11.11",
    "Armistice 1918"            => "11.11.",
    "Avent"                     => \&Advent1,
    "No�l"                      => "25.12.",
    "Saint Sylvestre"           => "#31.12."
};

$Profiles->{'BE-DE'} = # Belgien
{
    "Neujahr"                   => "01.01.",
    "Dreik�nigstag"             => "#06.01.",
    "Lichtmesse"                => "#02.02.",
    "Karnevalsdienstag"         => "#-47",
    "Aschermittwoch"            => "#-46",
    "Palmsonntag"               => "-7",
    "Ostersonntag"              => "+0",
    "Ostermontag"               => "+1",
    "Tag der Arbeit"            => "01.05.",
    "Christi Himmelfahrt"       => "+39",
    "Pfingstsonntag"            => "+49",
    "Pfingstmontag"             => "+50",
    "Nationalfeiertag"          => "21.07.",
    "Mari� Himmelfahrt"         => "15.08.",
    "Allerheiligen"             => "01.11.",
    "Allerseelen"               => "#02.11.",
    "Waffenstillstand 1918"     => "11.11.",
    "Weihnachten"               => "25.12.",
    "2. Weihnachtsfeiertag"     => "#26.12.",
    "Sylvester"                 => "#31.12."
};

# Thanks to:
# Hendrik Van Belleghem <beatnik@quickndirty.org>
# Stefaan Colson <stefaan.colson@sitel.com>

$Profiles->{'BE-NL'} = # Belgi�
{
    "Nieuwjaar"                 => "01.01.",
    "Driekoningen"              => "#06.01.",
    "Lichtmis"                  => "#02.02.",
    "Vastenavond"               => "#-47",
    "Aswoensdag"                => "#-46",
    "Palmzondag"                => "-7",
    "Pasen"                     => "+0",
    "Paasmaandag"               => "+1",
    "Dag van de arbeid"         => "01.05.",
    "Hemelvaartsdag"            => "+39", # Onze Lieve Heer Hemelvaart
    "Pinksteren"                => "+49",
    "Pinkstermaandag"           => "+50",
    "Feest van de Vlaamse Gemeenschap" => "#11.07",
    "Nationale feestdag"        => "21.07.",
    "OLV Hemelvaart"            => "15.08.", # Onze Lieve Vrouw Hemelvaart
    "Allerheiligen"             => "01.11.",
    "Allerzielen"               => "#02.11.",
    "Wapenstilstand 1918"       => "11.11.",
    "Kerstmis"                  => "25.12.",
    "Tweede kerstdag"           => "#26.12."
};

# Thanks to:
# Stefaan Colson <stefaan.colson@sitel.com>
# Stephane Rondal <rondal@usa.net>

$Profiles->{'BE-FR'} = # Belgique
{
    "Nouvel An"                 => "01.01.",
    "�piphanie"                   => "#06.01.",
    "Chandeleur"                => "#02.02.",
    "Mardi-Gras"                => "#-47",
    "Mercredi des Cendres"      => "#-46",
    "Dimanche des Rameaux"      => "-7",
    "P�ques"                    => "+0",
    "Lundi de P�ques"           => "+1",
    "F�te du Travail"           => "01.05.",
    "Ascension"                 => "+39",
    "Pentec�te"              => "+49",
    "Lundi de Pentec�te"        => "+50",
    "F�te Nationale"            => "21.07.",
    "Assomption"                => "15.08.",
    "F�te de la Communaut� Fran�aise" => "#27.09.",
    "Toussaint"                 => "01.11.",
    "Jour des D�funts"          => "#02.11.",
    "Armistice 1918"            => "11.11.",
    "No�l"                      => "25.12.",
    "2i�me Jour de No�l"        => "#26.12.",
    "Saint Sylvestre"           => "#31.12."
};

$Profiles->{'LU-DE'} = # Gro�herzogtum Luxemburg
{
    "Neujahr"                   => "01.01.",
    "Fastnachtsmontag"          => "#-48", # regional unterschiedlich
    "Ostersonntag"              => "+0",
    "Ostermontag"               => "+1",
    "Tag der Arbeit"            => "01.05.",
    "Christi Himmelfahrt"       => "+39",
    "Pfingstsonntag"            => "+49",
    "Pfingstmontag"             => "+50",
    "Nationalfeiertag"          => "23.06.",
    "Mari� Himmelfahrt"         => "15.08.",
    "Allerheiligen"             => "01.11.",
    "Allerseelen"               => "#02.11.", # regional unterschiedlich
    "Weihnachten"               => "25.12.",
    "2. Weihnachtsfeiertag"     => "26.12."
};
$Profiles->{'LU-FR'} = # Grand Duch� du Luxembourg
{
    "Nouvel An"                 => "01.01.",
    "Veille du Mardi Gras"      => "#-48", # varie selon la r�gion
    "P�ques"                    => "+0",
    "Lundi de P�ques"           => "+1",
    "F�te du Travail"           => "01.05.",
    "Ascension"                 => "+39",
    "Pentec�te"                 => "+49",
    "Lundi de Pentec�te"        => "+50",
    "Jour National"             => "23.06.",
    "Assomption"                => "15.08.",
    "Toussaint"                 => "01.11.",
    "Jour des D�funts"          => "#02.11.", # varie selon la r�gion
    "No�l"                      => "25.12.",
    "2i�me Jour de No�l"        => "#26.12.",
    "Saint Sylvestre"           => "#31.12."
};

$Profiles->{'PT'} = # Portugal
{
    "Ano Novo"                  => "01.01.",
    "Ter�a-Feira de Carnaval"   => "-47",
    "Paix�o de Cristo"          => "-2",
    "Domingo de P�scoa"         => "+0",
    "Dia da Liberdade"          => "25.04.",
    "Dia do Trabalho"           => "01.05.",
    "Ascens�o de Cristo"        => "+39",
    "Domingo de Pentecostes"    => "+49",
    "Dia Nacional"              => "10.06.",
    "Corpus Christi"            => "#+60", # varia segundo a regi�o
    "Assun��o de Maria"         => "15.08.",
    "Dia da Rep�blica"          => "05.10.",
    "Todos os Santos"           => "01.11.",
    "Dia da Independ�ncia"      => "01.12.",
    "Concei��o de Maria"        => "08.12.",
    "Natal"                     => "25.12."
};

# Thanks to:
# Arturo Valdes <arturovaldes@usa.net>

$Profiles->{'ES'} = # Espa�a
{
    "A�o Nuevo"                 => "01.01.",
    "Epifan�a del Se�or"        => "06.01.",
    "D�a de Santo Jos�"         => "#19.03.",
    "Jueves Santo"              => "#-3",
    "Viernes Santo"             => "-2",
    "Domingo de P�scuas"        => "+0",
    "Lunes de P�scuas"          => "#+1", # var�a segundo la region
    "D�a del Trabajo"           => "01.05.",
    "Domingo de Pentecostes"    => "+49",
    "Santiago Ap�stol"          => "#25.07.",
    "Ascensi�n de la Virgen"    => "15.08.", # Ascensi�n de Mar�a
    "Fiesta Nacional de Espa�a" => "12.10.",
    "Todos los Santos"          => "01.11.",
    "D�a de la Constituci�n"    => "06.12.",
    "Inmaculada Concepci�n"     => "08.12.", # D�a de la Concepci�n
    "Natividad del Se�or"       => "25.12."
};

# Thanks to:
# Michele Beltrame <mb@io.com>
# Aldo Calpini <dada@perl.it>
# Alessio Bragadini <alessio@sevenseas.org>

$Profiles->{'IT'} = # Italia
{
    "Capodanno"                 => "01.01.",
    "Epifania"                  => "06.01.",
    "San Valentino"             => "#14.02.",
    "Festa della Donna"         => "#08.03.",
    "Festa della Mamma"         => "1/Sun/May",
    "Marted� Grasso"            => "#-47",
    "Pasqua"                    => "+0",
    "Luned� dell'Angelo"        => "+1",
    "Liberazione d'Italia 1945" => "25.04.",
    "Festa del Lavoro"          => "01.05.",
    "Fondazione della Repubblica 1946" => \&IT_Fondazione,
    "Pentecoste"                => "+49",
    "Ferragosto"                => "15.08.",
    "Tutti i Santi"             => "01.11.",
    "Celebrazione dei Defunti"  => "#02.11.",
    "Giorno dell'Unit� Nazionale" => "#04.11.",
    "Fine della 1a Guerra Mondiale" => "#04.11.",
    "Giorno delle Forze Armate" => "#04.11.",
    "Immacolata Concezione"     => "08.12.",
    "Natale"                    => "25.12.",
    "S. Stefano"                => "26.12."
};

# Fixed thanks to:
# Michele Valzelli <spleen.leveller@gmail.com>

sub IT_Fondazione
{
    my($year,$label) = @_;

    if ($year >= 1947)
    {
        if (($year <= 1977) or ($year >= 2000)) { return($year,6,2);     }
        else                                    { return($year,6,2,'#'); } # only commemorative
    }
    return(); # didn't exist before 1947
}

# Thanks to:
# Georg Mavridis <GM@mavridis.net>

$Profiles->{'GR'} = # Greece
{
    "Prwtohronia"                 => "01.01.",  # New Year
    "Theofaneia"                  => "06.01.",  # Epifania
    "Katharh devtera"             => "-48",     # Carnival Monday
#   "???"                         => "???",     # Annunciation of Maria
    "Ethniki giorth 1"            => "25.03.",  # National Day #1
    "Megalh paraskevh"            => "-2",      # Good Friday
    "Kyriakh toy pasha"           => "+0",      # Easter Sunday
    "Devtera toy pasha"           => "+1",      # Easter Monday
    "Analypsews"                  => "#+39",    # Ascension of Christ
    "Kyriakh toy agiou pnevmatos" => "+49",     # Whitsunday
    "Agiou pnevmatos"             => "+50",     # Whitmonday
    "Hmera ths ergasias"          => "01.05.",  # Labour Day (also commonly called "Prwtomagia")
    "Koimhsews theotokoy"         => "15.08.",  # Ascension of Maria
    "Timioy stavrou"              => "#14.09.", # Feast of the Elevation of the Cross
    "Ethniki giorth 2"            => "28.10.",  # National Day #2
    "Hristougenna"                => "25.12.",  # Christmas (1st Day)
    "Devterh mera hristougennwn"  => "26.12.",  # Christmas (2nd Day)
};

# Thanks to:
# Flemming Mahler Larsen <mahler@dk.net>

$Profiles->{'DK'} = # Denmark
{
    "Nyt�rsdag"              => "01.01.",
    "Hellig tre Konger"         => "1/Sun/Jan", # (H3K) - First Sunday of the year
    "Fastelavn"                 => "-49", # 7th Sunday before Easter
    "Palme s�ndag"           => "-7", # Sunday before Easter
    "Sk�rtorsdag"            => "-3",
    "Langfredag"                => "-2",
    "P�skedag"               => "+0",
    "2. P�skedag"            => "+1",
    "Store bededag"             => "+26", # 4th Friday after Easter
    "Grundlovsdag"              => "05.06.",
    "Skt. Hans aften"           => "23.06.",
    "Kristi himmelfart"         => "+39",
    "Pinsedag"                  => "+49",
    "2. Pinsedag"               => "+50",
    "Mortensdag"                => "11.10.",
    "Allehelgen"                => "1/Sun/Nov", # Halloween
    "1. Advent"                 => \&Advent,
    "2. Advent"                 => \&Advent,
    "3. Advent"                 => \&Advent,
    "4. Advent"                 => \&Advent,
    "Juleaftensdag"             => "24.12.",
    "1. Juledag"                => "25.12.",
    "2. Juledag"                => "26.12."
};

# Thanks to:
# H. Merijn Brand <h.m.brand@xs4all.nl>
# Johan Vromans <JVromans@squirrel.nl>
# Abigail <abigail@foad.org>
# Elizabeth Mattijsen <liz@dijkmat.nl>
# Abe Timmerman <abe@ztreet.demon.nl>
# Jigal van Hemert <jigal.van.hemert@iquip.nl>
# Wim Verhaegen <wim.verhaegen@esat.kuleuven.ac.be>
# Cas Tuyn <cas.tuyn@asml.nl>
# Remco B. Brink <remco@solbors.no>
# Can Bican <can@ripe.net>
# Ziya Suzen <ziya@ripe.net>
# Henk Uijterwaal <henk@ripe.net>
# Eric Veldhuyzen <ericv@xs4all.net>

$Profiles->{'NL'} = # Nederland
{
    "Nieuwjaar"                 => "01-01",
    "Driekoningen"              => "#06-01",
    "Valentijnsdag"             => "#14-02",
    "Biddag voor het gewas"     => "#2/Wed/Mar",
    "Carnaval"                  => "#-48",
    "Vastenavond"               => "#-47",
    "Aswoensdag"                => "#-46",
    "Een April"                 => "#01-04",
    "Palmpasen"                 => "-7",
    "Witte Donderdag"           => "#-3",
    "Goede Vrijdag"             => "#-2",
    "Stille Zaterdag"           => "#-1",
    "Pasen"                     => "+0",
    "Paasmaandag"               => "+1",
    "Moederdag"                 => "2/Sun/May",
    "Vaderdag"                  => "3/Sun/Jun",
    "Koninginnedag"             => \&NL_Koninginnedag,
    "Dodenherdenking"           => "#04-05",
    "Bevrijdingsdag"            => \&NL_Bevrijdingsdag,
    "Hemelvaart"                => "+39",
    "Pinksteren"                => "+49",
    "Pinkstermaandag"           => "+50",
    "Trinitatis"                => "+56",
    "Prinsjesdag"               => "#3/Tue/Sep",
    "Dierendag"                 => "#04-10",
    "Dankdag voor het gewas"    => "#1/Wed/Nov",
    "Sint Maarten"              => "#11-11",
    "Sinterklaasavond"          => "#05-12",
    "Sinterklaas"               => "#06-12",
    "Koninkrijksdag"            => "#15-12",
    "Kerstmis"                  => "25-12",
    "2e Kerstdag"               => "26-12"
};

sub NL_Koninginnedag
{
    my($year,$label) = @_;
    my(@date);

    @date = ($year,4,30);
    if (Day_of_Week(@date) == 7) { @date = Add_Delta_Days(@date,-1); }
    return(@date);
}

# Bevrijdingsdag:
#
# 1945     : Liberation from German occupation in World War II
# 1946,1947: Official holiday
# 1948,1949: Afternoon off for government personnel, some local celebrations
# 1950-1957: No official celebrations
# 1958-1981: Commemorative, holiday for government personnel, schools etc.
# 1982-1990: Official holiday for everybody
# 1990-... : Official holiday every 5th year for everybody
#
# See also
# http://www.herdenkenenvieren.nl/utility/print.jsp?detail=2197&contentid=2197&siteid=hev&nofooter=true

# As far as I know, 'bevrijdingsdag' is an official national celebration
# day for everybody, but this does NOT mean that you do not have to go to
# work. This depends on your employer. In general, for everybody it is
# just a normal work day, except for people working for the government.
#
# See also
# http://home.szw.nl/faq/dsp_faq.cfm?view=3Ddetail&link_id=3D41264
# http://www.abvakabo.net/faq/index.php?page=3Dindex_v2&id=3D333&c=3D91

sub NL_Bevrijdingsdag
{
    my($year,$label) = @_;

    if ($year >= 1945)
    {
        if (                     ($year <= 1947)  or
            (($year >= 1982) and ($year <= 1990)) or
            (($year >  1990) and (($year % 5) == 0)))
        {
            return($year,5,5);     # true holiday
        }
        elsif (($year == 1948) or ($year == 1949))
        {
            return($year,5,5,':'); # half day off
        }
        else
        {
            return($year,5,5,'#'); # only commemorative
        }
    }
    return(); # didn't exist before 1945
}

# Thanks to:
# Erland Sommarskog <sommar@algonet.se>
# Magnus Bodin <magnus@bodin.org>
# Olle E. Johansson <oej@edvina.net>

$Profiles->{'SV'} = # Sverige
{
    "Ny�rsdagen"                => "01.01.",
    "Trettondedagsafton"        => "#05.01.", # 12 days after Dec 24th
    "Trettondedag jul"          => "06.01.",  # 13 days after Dec 24th
    "Tjugondedag Knut"          => "#13.01.", # 20 days after Dec 24th according to Olle E. Johansson
    "Kyndelsm�ssodagen"         => "#02.02",
    "Marie beb�delsedag"        => "#25.03",
    "Sk�rtorsdag"               => "#-3",
    "L�ngfredagen"              => "-2",
    "P�skafton"                 => "#-1", # like a Saturday
    "P�skdagen"                 => "+0",
    "Annandag p�sk"             => "+1",
    "Valborgsm�ssoafton"        => "#30.04.",
    "F�rsta maj"                => "01.05.",
    "Syttende maj"              => "#17.05.", # not a swedish but a norwegian holiday according to Olle E. Johansson
    "Mors dag"                  => "5/Sun/May", # Last Sun in May
    "Fars dag"                  => "2/Sun/Nov", # 2nd  Sun in Nov
    "Sveriges nationaldag"      => "#06.06.",
    "Johannes D�parens dag"     => "#24.06.",
    "Kristi himmelsf�rds dag"   => "+39",
    "Pingstafton"               => "#+48", # like a Saturday
    "Pingstdagen"               => "+49",
    "Annandag pingst"           => "+50",
    "Midsommarafton"            => \&SV_Midsommarafton, # like a Saturday
    "Midsommardagen"            => \&SV_Midsommardagen,
    "Alla helgons dag"          => \&SV_Alla_Helgons_Dag,
    "Allhelgonadagen"           => "#01.11.",
    "FN-dagen"                  => "#24.10.",
    "Gustav Adolfs-dagen"       => "#06.11.",
    "Nobeldagen"                => "#10.12.",
    "Julafton"                  => "#24.12.", # like a Saturday
    "Juldagen"                  => "25.12.",
    "Annandag jul"              => "26.12.",
    "Ny�rsafton"                => "#31.12." # like a Saturday
};

sub SV_Midsommarafton # Friday that falls on June 19th to 25th
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,6,28,
        -(Day_of_Week($year,6,28)+2)), '#' );
}
sub SV_Midsommardagen # Saturday that falls on June 20th to 26th
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,6,28,
        -(Day_of_Week($year,6,28)+1)) );
}
sub SV_Alla_Helgons_Dag # Saturday that falls on Oct 31st to Nov 6th
{
    my($year,$label) = @_;
    return( Add_Delta_Days($year,11,8,
        -(Day_of_Week($year,11,8)+1)) );
}

# Thanks to:
# Gisle Aas <gisle@aas.no>
# Remco B. Brink <remco@solbors.no>
# Lars Ole <ma-karl2@online.no>
# Vetle Roeim <vetler@opera.com>

$Profiles->{'NO'} = # Norway
{
    "Nytt�rsdag"              => "01/01",
    "Onsdag f�r Skj�rtorsdag" => "#-4", # sometimes half a day off
    "Skj�rtorsdag"            => "-3",
    "Langfredag"              => "-2",
    "P�skedag"                => "+0",
    "2. P�skedag"             => "+1",
    "1. mai"                  => "05/01",
    "Grunnlovsdag"            => "05/17",
    "Kristi himmelfartsdag"   => "+39",
    "Pinsedag"                => "+49",
    "2. Pinsedag"             => "+50",
    "Julaften"                => "#12/24", # sometimes half a day off
    "Juledag"                 => "12/25",
    "2. Juledag"              => "12/26",
    "Nytt�rsaften"            => "#31.12" # sometimes half a day off
};

## Thanks to:
## Sercan Uslu <sercanuslu@su.sabanciuniv.edu>
#
#$Profiles->{'TR'} = # T�rkiye
#{
## National Public Holidays (fixed):
#
#    "New Year's Day"                         => "01-01",
#    "National Sovereignty Day"               => "23-04",
#    "Children's Day"                         => "23-04",
#    "Atat�rk Commemoration"                  => "19-05",
#    "Youth and Sports Day"                   => "19-05",
#    "Victory Day"                            => "30-08",
#    "Republic Day"                           => "29-10",
#
## Religious Public Holidays (moving):
#
#    "Kurban Bayram (Eid al Adha) 1"          => "22-02", # only valid in 2002
#    "Kurban Bayram (Eid al Adha) 2"          => "23-02", # only valid in 2002
#    "Kurban Bayram (Eid al Adha) 3"          => "24-02", # only valid in 2002
#    "Kurban Bayram (Eid al Adha) 4"          => "25-02", # only valid in 2002
#
#    "Ramazan / Seker Bayram (Eid al Fitr) 1" => "05-12", # only valid in 2002
#    "Ramazan / Seker Bayram (Eid al Fitr) 2" => "06-12", # only valid in 2002
#    "Ramazan / Seker Bayram (Eid al Fitr) 3" => "07-12"  # only valid in 2002
#};

# Thanks to:
# Jonathan Stowe <gellyfish@gellyfish.com>

$Profiles->{'GB'} = # Great Britain
{
    "New Year's Day"            => \&GB_New_Year,
    "Good Friday"               => "-2",
    "Easter Sunday"             => "+0",
    "Easter Monday"             => "+1",
    "Early May Bank Holiday"    => \&GB_Early_May,
    "Late May Bank Holiday"     => "5/Mon/May", # Last Monday
#
# Jonathan Stowe <gellyfish@gellyfish.com> told me that spring
# bank holiday is the first Monday after Whitsun, but my pocket
# calendar suggests otherwise. I decided to follow my pocket
# guide and an educated guess ;-), but please correct me if
# I'm wrong!
#
    "Summer Bank Holiday"       => "5/Mon/Aug", # Last Monday
    "Christmas Day"             => \&GB_Christmas,
    "Boxing Day"                => \&GB_Boxing
};

sub GB_New_Year
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,1) );
}
#
# The following formula (also from Jonathan Stowe <gellyfish@gellyfish.com>)
# also contradicts my pocket calendar, but for lack of a better guess I
# left it as it is. Please tell me the correct formula in case this one
# is wrong! Thank you!
#
sub GB_Early_May # May bank holiday is the first Monday after May 1st
{
    my($year,$label) = @_;
    if (Day_of_Week($year,5,1) == 1)
        { return( Nth_Weekday_of_Month_Year($year,5,1,2) ); }
    else
        { return( Nth_Weekday_of_Month_Year($year,5,1,1) ); }
}
sub GB_Christmas
{
    my($year,$label) = @_;
    return( &Next_Monday($year,12,25) );
}
sub GB_Boxing
{
    my($year,$label) = @_;
    return( &Next_Monday_or_Tuesday($year,12,26) );
}

# Thanks to:
# Bianca Taylor <bianca@unisolve.com.au>
# Andie Posey <andie@posey.org>
# Don Simonetta <don.simonetta@tequinox.com>
# Paul Fenwick <pjf@cpan.org>
# Brian Graham <brian.graham@nec.com.au>
# Pat Waters <pat.waters@dir.qld.gov.au>
# Stephen Riehm <Stephen.Riehm@gmx.net>
#     http://www.holidayfestival.com/Australia.html
#     http://www.earthcalendar.net/countries/2001/australia.html
# Sven Geisler <sgeisler@aeccom.com>
# Canberra (ACT):
#     http://www.workcover.act.gov.au/labourreg/publicholidays.html
# New South Wales (NSW):
#     http://www.dir.nsw.gov.au/holidays/index.html
# Northern Territory (NT):
#     http://www.nt.gov.au/ocpe/documents/public-holidays/
# Queensland (QLD):
#     http://www.wageline.qld.gov.au/publicholidays/list_pubhols.html
# South Australia (SA):
#     http://www.sacentral.sa.gov.au/information/pubhols.htm
# Tasmania (TAS):
#     http://www.workcover.tas.gov.au/WSTPublish/node/wststatutory.htm
# Victoria (VIC):
#     http://www.info.vic.gov.au/resources/publichols.htm
# Western Australia (WA):
#     http://www.doplar.wa.gov.au/wages/pub_hol1.htm

$Profiles->{'AU'} = # Australia
{
    "Australia Day"             => \&AU_Australia,
    "St. Valentine's Day"       => "#14.02.",
    "Good Friday"               => "-2",
    "Easter Sunday"             => "+0",
    "Easter Monday"             => "+1",
    "Anzac Day"                 => "25.04.",
    "Christmas Day"             => \&AU_Christmas,
    "Boxing Day"                => \&AU_Boxing
};

sub AU_Australia
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,26) );
}
sub AU_Christmas
{
    my($year,$label) = @_;
    return( &Next_Monday($year,12,25) );
}
sub AU_Boxing
{
    my($year,$label) = @_;
    return( &Next_Monday_or_Tuesday($year,12,26) );
}
sub AU_New_Year
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,1) );
}
sub AU_Lauceston
{
    my($year,$label) = @_;
    if (Nth_Weekday_of_Month_Year($year,2,3,5))
        { return( Nth_Weekday_of_Month_Year($year,2,3,4) ); }
    else
        { return( Nth_Weekday_of_Month_Year($year,2,3,3) ); }
}
sub AU_May
{
    my($year,$label) = @_;
    return( &Next_Monday($year,5,1) );
}
sub AU_QLD_Anzac
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,4,25) );
}
sub AU_QLD_Brisbane
{
    my($year,$label) = @_;
    if (Nth_Weekday_of_Month_Year($year,8,3,5))
        { return( Nth_Weekday_of_Month_Year($year,8,3,3), '#' ); }
    else
        { return( Nth_Weekday_of_Month_Year($year,8,3,2), '#' ); }
}
sub AU_VIC_New_Year
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,1,1) );
}
sub AU_VIC_Boxing
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,12,26) );
}

$Profiles->{'AU-QLD'} = # Queensland
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => "01.01.",
    "Anzac Day"                 => \&AU_QLD_Anzac,
    "Easter Saturday"           => "-1",
    "Labour Day"                => "1/Mon/May",
    "Queen's Birthday"          => "2/Mon/Jun",
    "Royal Show (Brisbane)"     => \&AU_QLD_Brisbane
};
$Profiles->{'AU-TAS'} = # Tasmania
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => "01.01.",
    "Regatta Day"               => "2/Tue/Feb",
    "Lauceston Cup Day"         => \&AU_Lauceston,
    "King Island Show Day"      => "1/Tue/Mar", # uncertain! (maybe Tuesday after 1/Sun/Mar?)
    "Eight Hour Day"            => "2/Mon/Mar", # dubious, formula probably wrong!
    "Easter Saturday"           => "-1",
    "Queen's Birthday"          => "2/Mon/Jun",
    "Recreation Day"            => "1/Mon/Nov"  # only North Tasmania - date not confirmed!
};
$Profiles->{'AU-SA'} =  # South Australia
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => "01.01.",
    "Easter Saturday"           => "-1",
    "Adelaide Cup Day"          => "3/Mon/May", # uncertain! (maybe Monday after 3/Sun/May?)
    "Queen's Birthday"          => "2/Mon/Jun",
    "Labour Day"                => "1/Mon/Oct",
    "Proclamation Day"          => "#26.12."
};
$Profiles->{'AU-WA'} =  # Western Australia
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => "01.01.",
    "Labour Day"                => "1/Mon/Mar",
    "Foundation Day"            => "1/Mon/Jun",
    "Queen's Birthday"          => "1/Mon/Oct"
};
$Profiles->{'AU-ACT'} = # Australian Capital Territory
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => "01.01.",
    "Canberra Day"              => "2/Mon/Mar", # dubious, formula probably wrong!
    "Easter Saturday"           => "-1",
    "Queen's Birthday"          => "2/Mon/Jun",
    "Labour Day"                => "1/Mon/Oct"
};
$Profiles->{'AU-NSW'} = # New South Wales
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => \&AU_New_Year,
    "Easter Saturday"           => "-1",
    "Queen's Birthday"          => "2/Mon/Jun",
    "Labour Day"                => "1/Mon/Oct"
};
$Profiles->{'AU-NT'} =  # Northern Territory
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => "01.01.",
    "Easter Saturday"           => "-1",
    "May Day"                   => \&AU_May,
    "Queen's Birthday"          => "2/Mon/Jun",
    "Picnic Day"                => "1/Mon/Aug"
};
$Profiles->{'AU-VIC'} = # Victoria
{
    %{$Profiles->{'AU'}},
    "New Year's Day"            => \&AU_VIC_New_Year,
    "Australia Day"             => "26.01.",
    "Labour Day"                => "2/Mon/Mar",
    "Queen's Birthday"          => "2/Mon/Jun",
    "Melbourne Cup Day"         => "#1/Tue/Nov", # only in metropolitian municipal districts
    "Christmas Day"             => "25.12.",
    "Boxing Day"                => \&AU_VIC_Boxing
};

# Thanks to:
# John Bolland <jbolland@mainzeal.co.nz>
# Andie Posey <andie@posey.org>

$Profiles->{'NZ'} = # New Zealand
{
    "New Year's Day"            => \&NZ_New_Year,
    "Day after New Year's Day"  => \&NZ_After_New_Year,
    "Waitangi Day"              => "06.02.",
    "St. Valentine's Day"       => "#14.02.",
    "St. David's Day"           => "#01.03.",
    "St. Patrick's Day"         => "#17.03.",
    "St. George's Day"          => "#23.04.",
    "St. Andrew's Day"          => "#30.11.",
    "Good Friday"               => "-2",
    "Easter Sunday"             => "+0",
    "Easter Monday"             => "+1",
    "Anzac Day"                 => "25.04.",
    "Queen's Birthday"          => "1/Mon/Jun",
    "Labour Day"                => \&NZ_Labour,
    "Christmas Day"             => \&NZ_Christmas,
    "Boxing Day"                => \&NZ_Boxing,
    "Southland"                 => \&NZ_Southland,
    "Wellington"                => \&NZ_Wellington,
    "Auckland"                  => \&NZ_Auckland,
    "Taranaki"                  => \&NZ_Taranaki,
    "Otago"                     => \&NZ_Otago,
    "South Canterbury"          => \&NZ_South_Canterbury,
    "Hawkes Bay"                => \&NZ_Hawkes_Bay,
    "Marlborough"               => \&NZ_Marlborough,
    "North Canterbury"          => \&NZ_North_Central_Canterbury,
    "Central Canterbury"        => \&NZ_North_Central_Canterbury,
    "Chatham Islands"           => \&NZ_Chatham_Islands,
    "Westland"                  => \&NZ_Westland,
    "Christchurch Show Day"     => \&NZ_Christchurch
};

sub NZ_New_Year
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,1) );
}
sub NZ_After_New_Year
{
    my($year,$label) = @_;
    return( &Next_Monday_or_Tuesday($year,1,2) );
}
sub NZ_Labour
{
    my($year,$label) = @_;
    return( &Next_Monday($year,10,22) );
}
sub NZ_Christmas
{
    my($year,$label) = @_;
    return( &Next_Monday($year,12,25) );
}
sub NZ_Boxing
{
    my($year,$label) = @_;
    return( &Next_Monday_or_Tuesday($year,12,26) );
}

sub NZ_Southland
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,15), '#' );
}
sub NZ_Wellington
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,22), '#' );
}
sub NZ_Auckland
{
    my($year,$label) = @_;
    return( &Next_Monday($year,1,29), '#' );
}
sub NZ_Taranaki
{
    my($year,$label) = @_;
    return( &Next_Monday($year,3,12), '#' );
}
sub NZ_Otago
{
    my($year,$label) = @_;
    return( &Next_Monday($year,3,26), '#' );
}
sub NZ_South_Canterbury
{
    my($year,$label) = @_;
    return( &Next_Monday($year,9,24), '#' );
}
sub NZ_Hawkes_Bay
{
    my($year,$label) = @_;
    return( &Previous_Friday($year,10,19), '#' );
}
sub NZ_Marlborough
{
    my($year,$label) = @_;
    return( &Next_Monday($year,10,29), '#' );
}
sub NZ_North_Central_Canterbury
{
    my($year,$label) = @_;
    return( &Previous_Friday($year,11,16), '#' );
}
sub NZ_Chatham_Islands
{
    my($year,$label) = @_;
    return( &Next_Monday($year,12,3), '#' );
}
sub NZ_Westland
{
    my($year,$label) = @_;
    return( &Next_Monday($year,12,3), '#' );
}
sub NZ_Christchurch
{
    my($year,$label) = @_;
    return( &Previous_Friday($year,11,9), '#' );
}

# Thanks to:
# Ana Maria Lopes Monteiro <anamaria_l@hotmail.com>
# Pe. Am�ncio <catedral@lkn.com.br>
# In�z Hiltrop <inez@hiltrop.de>
# http://www.imagensbahia.com.br/calend.htm
# http://www.hotelonline.com.br/menu/datas.htm
# http://www.mec.gov.br/acs/relpublc/datas.shtm

$Profiles->{'BR'} = # Brasil
{
# Feriados oficiais variaveis:

    "Carnaval"                                                                       => "-47",
    "Paix�o de Cristo"                                                               => "-2",
    "Corpus Christi"                                                                 => "+60",

# Feriados oficiais fixos:

    "Ano Novo"                                                                       => "01-01",
    "Tiradentes (Patrono C�vico da Na��o Brasileira)"                                => "21-04",
    "Dia (Mundial) do Trabalho"                                                      => "01-05",
    "Dia da Independ�ncia do Brasil (1822)"                                          => "07-09",
    "N. Sra. Aparecida (Padroeira do Brasil)"                                        => "12-10",
    "Finados"                                                                        => "02-11",
    "Proclama��o da Rep�blica dos Estados Unidos do Brasil (1889)"                   => "15-11",
    "Natal"                                                                          => "25-12",

# Dias comemorativos variaveis:

    "Segunda-Feira de Carnaval"                                                      => "#-48",
    "Cinzas"                                                                         => "#-46",
    "Aleluia"                                                                        => "#-1",
    "P�scoa"                                                                         => "#+0",
    "Ascens�o do Senhor"                                                             => "#+39",
    "Pentecostes"                                                                    => "#+49",
    "Dia Mundial da Ora��o"                                                          => "#1/Fri/Mar",
    "Dia das M�es"                                                                   => "#2/Sun/May",
    "Dia dos Pais"                                                                   => "#2/Sun/Aug",
    "Dia da B�blia"                                                                  => "#5/Sun/Sep",
    "Dia Universal da Crian�a"                                                       => "#1/Mon/Oct",
    "Dia do Securit�rio"                                                             => "#3/Mon/Oct",

# Sinonimos:

#   "Dia da Ressaca"                                                                 => "#-46", # >;-)
    "Sexta-Feira Santa"                                                              => "#-2",
    "Dia Mundial da Paz"                                                             => "#01-01",
    "Confraterniza��o Universal"                                                     => "#01-01",
#   "Fraternidade Universal"                                                         => "#01-01",
    "Santos Reis"                                                                    => "#06-01",
    "Inconfid�ncia Mineira"                                                          => "#21-04",
    "Todas as Almas"                                                                 => "#02-11",
    "Natividade de Jesus"                                                            => "#25-12",
#   "Natividade do Senhor"                                                           => "#25-12",

# Datas especiais:

    "Elei��es"                                                                       => "#03-10",
    "In�cio do Outono"                                                               => "#21-03",
    "In�cio do Inverno"                                                              => "#21-06",
    "In�cio da Primavera"                                                            => "#23-09",
    "In�cio do Ver�o"                                                                => "#22-12",
#   "Come�o do Hor�rio de Ver�o"                                                     => "#??-??",
#   "Fim do Hor�rio de Ver�o"                                                        => "#??-??",

# Dias comemorativos (datas contraditorias ou duvidosas):

    "In�cio da Semana Nacional contra o Alcoolismo"                                  => "#18-02", # (1) = 3/Sun/Feb ?
    "In�cio da Semana da Educa��o (1� Semana)"                                       => "#02-07", # (1) = 1/Sun/Jul ?
    "In�cio da Semana do Ex�rcito"                                                   => "#18-08", # (1) = 3/Sun/Aug ?
    "In�cio da Semana do Livro Escolar"                                              => "#19-08", # (1) = 3/Sun/Aug ?
    "In�cio da Semana do Portador de S�ndrome de Down"                               => "#21-08", # (1) = 4/Sun/Aug ?
    "In�cio da Semana da P�tria"                                                     => "#01-09", # (2) = 1/Sun/Sep ?
    "In�cio da Semana do Tr�nsito"                                                   => "#19-09", # (1) = 3/Sun/Sep ?
    "Dia do Tr�nsito"                                                                => "#25-09", # (2)
    "In�cio da Semana da Asa"                                                        => "#17-10", # (1) = 3/Sun/Oct ?

    "Dia do Agricultor"                                                              => "#28-07", # (2)
    "Dia do Engenheiro Agr�nomo"                                                     => "#12-10", # (1)
    "Dia do Agr�nomo"                                                                => "#11-12", # (1)

    "Dia Nacional da Alfabetiza��o"                                                  => "#08-09", # (2)
#   "Dia da Alfabetiza��o"                                                           => "#08-09", # (2)
#   "Dia Nacional da Alfabetiza��o"                                                  => "#14-11", # (1)
#   "Dia Nacional da Alfabetiza��o"                                                  => "#15-11", # (1)

#   "Dia da Amizade"                                                                 => "#23-06", # (1)
    "Dia Internacional da Amizade"                                                   => "#20-07", # (1)
    "Dia Mundial da Amizade"                                                         => "#20-07", # (2)
    "Dia da Amizade"                                                                 => "#20-07", # (1)
    "Dia do Amigo"                                                                   => "#20-07", # (1)

    "Dia dos Aposentados"                                                            => "#24-01", # (1)
    "Dia do Professor Aposentado"                                                    => "#15-05", # (1)
    "Dia do Funcion�rio P�blico Aposentado"                                          => "#17-06", # (2)
    "Dia do Aposentado"                                                              => "#08-11", # (1)

    "Dia do Idoso"                                                                   => "#27-02", # (1)
    "Dia dos Idosos"                                                                 => "#07-10", # (1)

    "Dia do Artista"                                                                 => "#23-08", # (1)
    "Dia dos Artistas"                                                               => "#24-08", # (1)

#   "Dia do Atleta"                                                                  => "#10-02", # (1)
    "Dia do Atletismo"                                                               => "#12-10", # (1)
    "Dia do Atleta Profissional"                                                     => "#19-12", # (1)
    "Dia do Atleta"                                                                  => "#21-12", # (2)

    "Dia das Bandeiras"                                                              => "#30-05", # (1)
    "Dia dos S�mbolos Nacionais"                                                     => "#18-09", # (1)
    "Dia da Bandeira"                                                                => "#19-11", # (4)

    "Dia dos Bandeirantes"                                                           => "#08-08", # (1)
    "Dia do Bandeirante"                                                             => "#14-11", # (1)

    "Dia do Barbeiro"                                                                => "#06-09", # (1)
    "Dia do Barbeiro"                                                                => "#03-11", # (1)

    "Dia do Bombeiro"                                                                => "#01-07", # (1)
    "Dia dos Bombeiros Brasileiros"                                                  => "#02-07", # (1)

    "Dia do Industrial do Caf�"                                                      => "#12-03", # (1)
    "Dia Pan-Americano do Caf�"                                                      => "#14-04", # (1)
    "Dia do Caf�"                                                                    => "#14-04", # (1)
#   "Dia do Caf�"                                                                    => "#24-05", # (1)

    "Dia do Carteiro"                                                                => "#25-01", # (2)
#   "Dia do Carteiro"                                                                => "#05-08", # (1)

    "Cria��o dos Correios no Brasil"                                                 => "#25-01", # (1)
    "Dia do Correio"                                                                 => "#08-04", # (1)
    "Dia do Correio A�reo Nacional"                                                  => "#12-06", # (1)
    "Dia Postal Mundial"                                                             => "#09-10", # (1)

#   "Dia Universal da Crian�a"                                                       => "#1/Mon/Oct",
    "Dia da Crian�a"                                                                 => "#12-10",

    "Dia do Enfermo"                                                                 => "#14-01", # (1)
    "Dia Mundial do Enfermo"                                                         => "#11-02", # (1)

#   "Dia da Escola"                                                                  => "#15-03", # (1)
    "Dia da Escola"                                                                  => "#19-03", # (3)

    "Dia do Escritor Paulista"                                                       => "#29-06", # (1)
#   "Dia do Escritor"                                                                => "#25-07", # (2)
    "Dia do Escritor"                                                                => "#13-10", # (3)

    "Dia do Estudante (Feriado Escolar)"                                             => "#11-08", # (4)
    "Dia Internacional do Estudante"                                                 => "#17-11", # (1)

#   "Dia do Folclore"                                                                => "#19-08", # (1)
    "Dia do Folclore"                                                                => "#22-08", # (4)

    "Dia Mundial Sem Fumar"                                                          => "#07-04", # (1)
    "Dia Mundial do Combate ao Fumo"                                                 => "#31-05", # (1)
    "Dia Mundial Sem Tabaco"                                                         => "#31-05", # (1)
    "Dia Nacional de Combate ao Fumo"                                                => "#29-08", # (1)
    "Dia do Fumar"                                                                   => "#16-11", # (1)

    "Dia da Sa�de e Nutri��o"                                                        => "#31-03", # (1)
    "Dia Mundial da Sa�de"                                                           => "#07-04", # (4)
    "Dia Nacional da Sa�de"                                                          => "#05-08", # (4)
    "Dia da Sa�de Dent�ria"                                                          => "#25-10", # (1)
    "Dia Pan-Americano da Sa�de"                                                     => "#02-12", # (1)

    "Dia do Hino Nacional"                                                           => "#13-04", # (1)
    "Dia do Hino Nacional"                                                           => "#06-09", # (1)

    "Dia do Hoteleiro"                                                               => "#11-08", # (1)
    "Dia do Hoteleiro"                                                               => "#09-11", # (1)

    "Festa de Iemanj�"                                                               => "#02-02", # (2)
#   "Festa de Iemanj�"                                                               => "#08-12", # (1)
    "Festa de Iemanj� em S�o Paulo e Para�ba"                                        => "#08-12", # (1)

    "Funda��o da Associa��o Brasileira de Imprensa (ABI)"                            => "#07-04", # (1)
    "Dia Nacional da Imprensa"                                                       => "#01-06", # (1)
    "Dia da Liberdade de Imprensa"                                                   => "#07-06", # (2)
    "Dia Internacional da Liberdade de Imprensa"                                     => "#10-06", # (1)
    "Dia da Imprensa"                                                                => "#10-09", # (4)

    "Dia da Inf�ncia"                                                                => "#20-08", # (3)
    "Dia da Inf�ncia"                                                                => "#24-08", # (1)

    "Dia do Jornalista"                                                              => "#29-01", # (1)
    "Dia do Jornalismo"                                                              => "#07-04", # (2)
    "Dia Nacional do Jornaleiro"                                                     => "#30-09", # (1)

    "Dia dos Jovens"                                                                 => "#13-04", # (2)
    "Dia Internacional do Jovem Trabalhador"                                         => "#24-04", # (4)
    "Dia da Juventude Oper�ria Cat�lica"                                             => "#29-04", # (1)
    "Dia da Juventude Constitucionalista"                                            => "#23-05", # (1)
    "Dia Nacional da Juventude"                                                      => "#22-09", # (2)
    "Dia Mundial da Juventude"                                                       => "#04-10", # (1)

    "Dia Mundial do Leonino"                                                         => "#08-10", # (1)
    "Dia Mundial do Lions Clube"                                                     => "#10-10", # (1)

    "Dia do Livro"                                                                   => "#19-03", # (2)
#   "Dia do Livro"                                                                   => "#18-04", # (1)
    "Dia Nacional do Livro"                                                          => "#29-10", # (2)
#   "Dia do Livro"                                                                   => "#23-11", # (1)
    "Dia Internacional do Livro"                                                     => "#23-11", # (1)

    "Dia Internacional do Livro Infantil"                                            => "#02-04", # (3)
#   "Dia Internacional do Livro Infantil"                                            => "#02-09", # (2)
    "Dia Nacional do Livro Infantil"                                                 => "#18-04", # (3)

    "Dia Oficial da M�sica"                                                          => "#21-11", # (1)
    "Dia do M�sico"                                                                  => "#22-11", # (1)

    "Dia Mundial da �gua (ONU)"                                                      => "#22-03", # (2)
    "Dia da Organiza��o das Na��es Unidas (ONU)"                                     => "#25-04", # (1)
    "Dia das Na��es Unidas (ONU) (1945)"                                               => "#24-10", # (4)

    "N. Sra. Rainha da Paz"                                                          => "#09-07", # (1)
    "N. Sra. Rainha da Paz"                                                          => "#22-08", # (1)

    "N. Sra. da Penha (Feriado Escolar)"                                             => "#24-04", # (1)
#   "N. Sra. da Penha"                                                               => "#24-04", # (2)
#   "N. Sra. da Penha"                                                               => "#08-09", # (1)

    "Dia da Liberdade de Pensamento"                                                 => "#14-07", # (2)
    "Dia do Pensamento"                                                              => "#13-08", # (1)

    "Dia do Petr�leo"                                                                => "#29-09", # (1)
    "Dia do Petr�leo Brasileiro"                                                     => "#03-10", # (2)

    "Dia do Profissional de Marketing"                                               => "#08-04", # (1)
    "Dia do Profissional de Marketing"                                               => "#08-05", # (1)

    "Dia do Publicit�rio"                                                            => "#01-02", # (1)
    "Dia do Publicit�rio"                                                            => "#04-12", # (1)

    "Dia do Rep�rter"                                                                => "#16-02", # (2)
#   "Dia do Rep�rter"                                                                => "#17-02", # (1)
    "Dia do Rep�rter Fotogr�fico"                                                    => "#02-09", # (1)

#   "Dia da Televis�o"                                                               => "#11-08", # (2)
    "Santa Clara de Assis (Padroeira da Televis�o)"                                  => "#11-08", # (1)
#   "Dia da Padroeira da Televis�o (Santa Clara de Assis)"                           => "#12-08", # (1)

    "Santa Isabel"                                                                   => "#04-07", # (1)
    "Santa Isabel"                                                                   => "#05-11", # (1)

    "Santa Terezinha (Tereza do Menino Jesus)"                                       => "#01-10", # (2)
#   "Santa Tereza"                                                                   => "#15-10", # (1)

    "Dia Mundial das Voca��es Sacerdotais"                                           => "#25-04", # (1)
    "Dia Mundial das Voca��es"                                                       => "#26-04", # (1)
    "Dia Mundial das Voca��es"                                                       => "#02-05", # (1)

    "Dia do Comiss�rio de Bordo"                                                     => "#31-05", # (1)
    "Dia Internacional do Controlador de V�o"                                        => "#18-10", # (1)
    "Dia Mundial do Comiss�rio de V�o"                                               => "#31-10", # (1)

# Dias comemorativos fixos (sem garantias!):

    "Dia dos Munic�pios"                                                             => "#01-01",
    "Maria Sant�ssima M�e de Deus"                                                   => "#01-01",
    "Dia Nacional da Abreugrafia"                                                    => "#03-01",
    "Dia da Cria��o do Estado de Rond�nia-RO"                                        => "#04-01",
    "Cria��o da Primeira Tipografia no Brasil"                                       => "#05-01",
    "Reis Magos"                                                                     => "#06-01",
    "Dia da Gratid�o"                                                                => "#06-01",
    "Dia da Liberdade de Cultos"                                                     => "#07-01",
    "Dia do Leitor"                                                                  => "#07-01",
    "Batismo do Senhor"                                                              => "#08-01",
    "Dia do Fot�grafo"                                                               => "#08-01",
    "Dia do Fico"                                                                    => "#09-01",
    "Dia do Empres�rio de Contabilidade"                                             => "#12-01",
    "Cria��o do Museu Nacional de Belas Artes (1937)"                                => "#13-01",
    "Dia Mundial do Compositor"                                                      => "#15-01",
    "Dia do Museu de Arte Moderna do Rio de Janeiro"                                 => "#15-01",
    "Dia dos Tribunais de Contas"                                                    => "#17-01",
    "Dia Nacional do Fusca"                                                          => "#20-01",
    "Dia de Oxal�"                                                                   => "#20-01",
    "Dia do Farmac�utico"                                                            => "#20-01",
    "S�o Sebasti�o (Padroeiro da Cidade do Rio de Janeiro)"                          => "#20-01",
    "Dia Mundial da Religi�o"                                                        => "#21-01",
    "Santa In�s"                                                                     => "#21-01",
    "S�o Vicente"                                                                    => "#22-01",
    "Dia da Previd�ncia Social"                                                      => "#24-01",
    "Institui��o do Casamento C�vil no Brasil"                                       => "#24-01",
    "Promulga��o da Constitui��o (1967)"                                             => "#24-01",
    "Funda��o da Cidade de S�o Paulo (1554)"                                         => "#25-01",
    "Eleva��o do Brasil a Vice-Reinado (1763)"                                       => "#27-01",
    "Santa �ngela de M�dici"                                                         => "#27-01",
    "Abertura dos Pontos no Brasil (1808)"                                           => "#28-01",
    "Dia Nacional das Hist�rias em Quadrinhos"                                       => "#30-01",
    "Dia da Saudade"                                                                 => "#30-01",
    "Dia do Portu�rio (Portu�ria)"                                                   => "#30-01",
    "Dia Mundial do M�gico"                                                          => "#31-01",
    "S�o Jo�o Bosco"                                                                 => "#31-01",
    "Dia da Solidariedade"                                                           => "#31-01",
    "Dia do Agente Fiscal"                                                           => "#02-02",
    "N. Sra. dos Navegantes"                                                         => "#02-02",
    "S�o Br�s"                                                                       => "#03-02",
    "Dia da Papiloscopia"                                                            => "#05-02",
    "Dia do Datiloscopista (Datiloscopia)"                                           => "#05-02",
    "Dia do Gr�fico"                                                                 => "#07-02",
    "Santa Apol�nia (Dentistas)"                                                     => "#09-02",
    "Cria��o da Casa da Moeda"                                                       => "#10-02",
    "Santa Escol�stica"                                                              => "#10-02",
    "Dia do Zelador"                                                                 => "#11-02",
    "N. Sra. de Lourdes"                                                             => "#11-02",
    "Dia Estadual do Minist�rio P�blico (SP)"                                        => "#12-02",
    "1� Transmiss�o da TV em Cores (1972)"                                           => "#16-02",
    "Dia do Esportista"                                                              => "#19-02",
    "Data Festiva do Ex�rcito"                                                       => "#21-02",
    "Dia Nacional do Rotary (Dia do Rotariano)"                                      => "#23-02",
    "Promulga��o da Primeira Constitui��o Republicana (1891)"                        => "#24-02",
    "Cria��o do Minist�rio das Comunica��es"                                         => "#25-02",
    "Dia Nacional do Livro Did�tico"                                                 => "#27-02",
    "Dia do Agente Fiscal da Receita Federal"                                        => "#27-02",
    "Dia da Vindima"                                                                 => "#01-03",
    "Funda��o da Cidade do Rio de Janeiro (1565)"                                    => "#01-03",
    "Dia Nacional do Turismo"                                                        => "#02-03",
    "Dia do Meteorologista"                                                          => "#03-03",
    "Dia do Filatelista Brasileiro"                                                  => "#05-03",
    "Dia dos Fuzileiros Navais"                                                      => "#07-03",
    "Dia Internacional da Mulher"                                                    => "#08-03",
    "Dia do Telefone"                                                                => "#10-03",
    "S�o Domingos S�vio"                                                             => "#10-03",
    "Dia do Bibliotec�rio"                                                           => "#12-03",
    "Funda��o da Cidade de Recife (1537)"                                            => "#12-03",
    "Semana Nacional da Biblioteca"                                                  => "#12-03",
    "Dia Nacional da Poesia"                                                         => "#14-03",
    "Dia do Agente Aut�nomo de Investimentos"                                        => "#14-03",
    "Dia do Conservador"                                                             => "#14-03",
    "Dia do Vendedor de Livros"                                                      => "#14-03",
    "Dia Mundial do Consumidor"                                                      => "#15-03",
    "Dia da Constitui��o"                                                            => "#15-03",
    "Dia do Carpinteiro"                                                             => "#19-03",
    "Dia do Consertador"                                                             => "#19-03",
    "Dia do Marceneiro"                                                              => "#19-03",
    "S�o Jos� (Padroeiro da Igreja Universal)"                                       => "#19-03",
    "Dia Internacional para a Elimina��o da Discrimina��o Racial"                    => "#21-03",
    "Dia Universal do Teatro"                                                        => "#21-03",
    "Dia Internacional da Floresta"                                                  => "#21-03",
    "Dia Mundial do Meteorol�gico"                                                   => "#23-03",
    "Dia do Cacau"                                                                   => "#26-03",
    "Dia do Circo"                                                                   => "#27-03",
    "Dia do Diagramador"                                                             => "#28-03",
    "Dia do Revisor"                                                                 => "#28-03",
    "Anivers�rio do Golpe Militar (1964)"                                            => "#31-03",
    "Dia da Integra��o Nacional"                                                     => "#31-03",
    "Dia da Mentira"                                                                 => "#01-04",
    "Dia do Humanismo"                                                               => "#01-04",
    "Dia do Propagandista"                                                           => "#02-04",
    "S�o Francisco de Paula"                                                         => "#02-04",
    "Dia Nacional do Parkinsoniano"                                                  => "#04-04",
    "Dia do Corretor"                                                                => "#07-04",
    "Dia do M�dico Legista"                                                          => "#07-04",
    "Dia Mundial do Combate ao C�ncer"                                               => "#08-04",
    "Dia da Nata��o"                                                                 => "#08-04",
    "Dia Nacional do A�o"                                                            => "#09-04",
    "Endoen�as"                                                                      => "#09-04",
    "Dia da Engenharia do Ex�rcito Brasileiro"                                       => "#10-04",
    "Funda��o do Ex�rcito da Salva��o"                                               => "#10-04",
    "Anivers�rio da Organiza��o Internacional do Trabalho"                           => "#11-04",
    "Dia da Intend�ncia do Ex�rcito Brasileiro"                                      => "#12-04",
    "Dia do Obstetra / da Obstetriz"                                                 => "#12-04",
    "Aniversario da Loteria Esportiva (1970)"                                        => "#13-04",
    "Dia do Office-Boy"                                                              => "#13-04",
    "Dia Pan-Americano"                                                              => "#14-04",
    "Dia da Am�rica"                                                                 => "#14-04",
    "Dia Mundial do Desenhista"                                                      => "#15-04",
    "Dia da Conserva��o do Solo"                                                     => "#15-04",
    "Dia da Conven��o do Solo"                                                       => "#15-04",
    "Dia do Desarmamento Infantil"                                                   => "#15-04",
    "Nascimento de Monteiro Lobato (Taubat�-SP)"                                     => "#18-04",
    "Dia do �ndio"                                                                   => "#19-04",
    "Santo Expedito"                                                                 => "#19-04",
    "Dia do Diplomata"                                                               => "#20-04",
    "Dia da Latinidade"                                                              => "#21-04",
    "Dia da Pol�cia Civil"                                                           => "#21-04",
    "Dia Internacional da Terra"                                                     => "#21-04",
    "Dia do Metal�rgico"                                                             => "#21-04",
    "Funda��o da Cidade de Bras�lia-DF (1960)"                                       => "#21-04",
    "Morre Tancredo de Almeida Neves (1985)"                                         => "#21-04",
    "Descobrimento do Brasil (1500)"                                                 => "#22-04",
    "Dia Mundial da Terra"                                                           => "#22-04",
    "Dia da Avia��o de Ca�a"                                                         => "#22-04",
    "Dia da Comunidade Luso-Brasileira"                                              => "#22-04",
    "Dia da For�a A�rea Brasileira"                                                  => "#22-04",
    "Dia do Planeta Terra"                                                           => "#22-04",
    "Dia Mundial do Escoteiro (Baden Powell Day)"                                    => "#23-04",
    "Dia Mundial do Livro e do Direito Autoral"                                      => "#23-04",
    "S�o Jorge"                                                                      => "#23-04",
    "Dia do Agente de Viagem"                                                        => "#24-04",
    "Dia do Contabilista"                                                            => "#25-04",
    "S�o Marcos"                                                                     => "#25-04",
    "Celebra��o da Primeira Missa no Brasil"                                         => "#26-04",
    "Dia do Goleiro"                                                                 => "#26-04",
    "Dia Nacional da Empregada Dom�stica"                                            => "#27-04",
    "Dia do Sacerdote"                                                               => "#27-04",
    "Santa Zita"                                                                     => "#27-04",
    "Dia da Educa��o"                                                                => "#28-04",
    "Dia da Sogra"                                                                   => "#28-04",
    "Dia Nacional da Mulher"                                                         => "#30-04",
    "Dia da OEA (Organiza��o dos Estados Americanos)"                                => "#30-04",
    "Dia do Ferrovi�rio"                                                             => "#30-04",
    "Inaugura��o da Primeira Estrada de Ferro no Brasil"                             => "#30-04",
    "Dia da Literatura Brasileira"                                                   => "#01-05",
    "S�o Jos� Oper�rio"                                                              => "#01-05",
    "Dia Nacional do Ex-Combatente"                                                  => "#02-05",
    "Dia do Sertanejo"                                                               => "#03-05",
    "Dia do Taquigrafo"                                                              => "#03-05",
    "S�o Tiago"                                                                      => "#03-05",
    "Dia Nacional das Comunica��es"                                                  => "#05-05",
    "Dia Nacional do Expedicion�rio"                                                 => "#05-05",
    "Dia da Comunidade"                                                              => "#05-05",
    "Dia das Comunica��es"                                                           => "#05-05",
    "Dia de Rondon"                                                                  => "#05-05",
    "Dia do Pintor"                                                                  => "#05-05",
    "Dia do Trabalhador Preso"                                                       => "#05-05",
    "Dia do Cart�grafo"                                                              => "#06-05",
    "Dia do Oftalmologista"                                                          => "#07-05",
    "Dia do Sil�ncio"                                                                => "#07-05",
    "Dia Internacional da Cruz Vermelha"                                             => "#08-05",
    "Dia da Vit�ria (1945)"                                                          => "#08-05",
    "Dia do Artista Pl�stico"                                                        => "#08-05",
    "S�o Vitor"                                                                      => "#08-05",
    "T�rmino da II Guerra Mundial (1945)"                                            => "#08-05",
    "Dia da Cavalaria"                                                               => "#10-05",
    "Dia do Campo"                                                                   => "#10-05",
    "Dia do Guia de Turismo"                                                         => "#10-05",
    "Dia da Integra��o do Tel�grafo no Brasil"                                       => "#11-05",
    "Dia Mundial da Enfermeira"                                                      => "#12-05",
    "S�o Pancr�cio"                                                                  => "#12-05",
    "Aboli��o da Escravatura, Lei �urea (1888)"                                      => "#13-05",
    "Cria��o da Biblioteca Nacional, Rio de Janeiro-RJ (1811)"                       => "#13-05",
    "Dia da Estrada de Rodagem"                                                      => "#13-05",
    "Dia da Fraternidade Brasileira"                                                 => "#13-05",
    "Dia do Autom�vel"                                                               => "#13-05",
    "N. Sra. de F�tima"                                                              => "#13-05",
    "Dia Continental do Seguro"                                                      => "#14-05",
    "S�o Matias"                                                                     => "#14-05",
    "Dia do Assistente Social"                                                       => "#15-05",
    "Dia do Gerente Banc�rio"                                                        => "#15-05",
    "Dia do Gari"                                                                    => "#16-05",
    "Dia Internacional da Comunica��o e Telecomunica��o"                             => "#17-05",
    "Dia Internacional da Comunica��o Social"                                        => "#18-05",
    "Dia Internacional dos Museus"                                                   => "#18-05",
    "Dia dos Vidreiros"                                                              => "#18-05",
    "Dia do Comiss�rio de Menores"                                                   => "#20-05",
    "Dia da L�ngua Nacional"                                                         => "#21-05",
    "Dia do Apicultor"                                                               => "#22-05",
    "Santa Rita"                                                                     => "#22-05",
    "Dia da Infantaria"                                                              => "#24-05",
    "Dia do Datil�grafo"                                                             => "#24-05",
    "Dia do Detento"                                                                 => "#24-05",
    "Dia do Telegrafista"                                                            => "#24-05",
    "Dia do Vestibulando"                                                            => "#24-05",
    "N. Sra. Auxiliadora"                                                            => "#24-05",
    "Dia da Ind�stria"                                                               => "#25-05",
    "Dia do Industrial"                                                              => "#25-05",
    "Dia do Massagista"                                                              => "#25-05",
    "Dia do Trabalhador Rural"                                                       => "#25-05",
    "Dia Nacional da Mata Atl�ntica"                                                 => "#27-05",
    "Dia do Profissional Liberal"                                                    => "#27-05",
    "Dia do Estat�stico"                                                             => "#29-05",
    "Dia do Ge�grafo"                                                                => "#29-05",
    "Dia do Ge�logo"                                                                 => "#30-05",
    "Santa Joana d'Arc"                                                              => "#30-05",
    "Dia Mundial das Comunica��es Sociais"                                           => "#31-05",
    "Dia do Esp�rito Santo"                                                          => "#31-05",
    "Primeira Transmiss�o de TV no Brasil (1950)"                                    => "#01-06",
    "Dia do Duque de Caxias"                                                         => "#01-06",
    "Dia Mundial do Administrador de Pessoal"                                        => "#03-06",
    "Dia Mundial do Meio Ambiente"                                                   => "#05-06",
    "Dia da Ecologia"                                                                => "#05-06",
    "Dia do Citricultor"                                                             => "#08-06",
    "Dia Nacional da Imuniza��o"                                                     => "#09-06",
    "Dia Nacional do Pe. Anchieta"                                                   => "#09-06",
    "Dia do Porteiro"                                                                => "#09-06",
    "Dia do T�nis e do Tenista"                                                      => "#09-06",
    "Dia da Artilharia"                                                              => "#10-06",
    "Dia da L�ngua Portuguesa"                                                       => "#10-06",
    "Dia da Ra�a"                                                                    => "#10-06",
    "Batalha Naval do Riachuelo"                                                     => "#11-06",
    "Dia da Marinha Brasileira"                                                      => "#11-06",
    "Dia do Educador Sanit�rio"                                                      => "#11-06",
    "Dia dos Namorados"                                                              => "#12-06",
    "Criado o Jardim Bot�nico do Rio de Janeiro por D. Jo�o VI"                      => "#13-06",
    "Dia do Turista"                                                                 => "#13-06",
    "Santo Ant�nio"                                                                  => "#13-06",
    "Dia Universal de Deus"                                                          => "#14-06",
    "Dia do Solista"                                                                 => "#14-06",
    "S�o Vito"                                                                       => "#15-06",
    "Dia da Unidade Nacional"                                                        => "#16-06",
    "Dia da Imigra��o Japonesa"                                                      => "#18-06",
    "Dia do Qu�mico"                                                                 => "#18-06",
    "Dia do Revendedor"                                                              => "#20-06",
    "Dia Nacional do Luto"                                                           => "#21-06",
    "Dia Universal Ol�mpico"                                                         => "#21-06",
    "Dia da M�dia"                                                                   => "#21-06",
    "Dia do Mel"                                                                     => "#21-06",
    "Dia do Migrante"                                                                => "#21-06",
    "Nascimento de Machado de Assis, Rio de Janeiro-RJ (1839)"                       => "#21-06",
    "Sagrado Cora��o de Jesus"                                                       => "#22-06",
    "Imaculado Cora��o de Maria"                                                     => "#23-06",
    "Dia Internacional do Leite"                                                     => "#24-06",
    "Dia da Comunidade Brit�nica"                                                    => "#24-06",
    "Dia das Empresas Gr�ficas"                                                      => "#24-06",
    "Dia do Caboclo"                                                                 => "#24-06",
    "Festa Junina (Feriado Escolar)"                                                 => "#24-06",
    "S�o Jo�o Batista"                                                               => "#24-06",
    "Dia do Quilo"                                                                   => "#25-06",
    "Dia Nacional de Combate �s Drogas"                                              => "#26-06",
    "Dia Nacional do Progresso"                                                      => "#27-06",
    "Dia da Revolu��o Espiritual"                                                    => "#27-06",
    "Dia dos Artistas L�ricos"                                                       => "#27-06",
    "Dia da Renova��o Espiritual"                                                    => "#28-06",
    "Dia Internacional do Orgulho Gay"                                               => "#29-06",
    "Dia da Telefonista"                                                             => "#29-06",
    "Dia do Papa"                                                                    => "#29-06",
    "Dia do Pescador"                                                                => "#29-06",
    "S�o Pedro e S�o Paulo"                                                          => "#29-06",
    "Dia do Economi�rio"                                                             => "#30-06",
    "Dia da Vacina BCG"                                                              => "#01-07",
    "Institui��o do Real como Unidade Monet�ria (1994)"                              => "#01-07",
    "Dia do Hospital"                                                                => "#02-07",
    "S�o Tom�"                                                                       => "#03-07",
    "Dia Internacional do Cooperativismo"                                            => "#04-07",
    "Cria��o do IBGE (Instituto Brasileiro de Geografia e Estat�stica)"              => "#06-07",
    "Santa Maria Goretti"                                                            => "#06-07",
    "Dia do Panificador"                                                             => "#08-07",
    "Dia do Soldado Constitucionalista"                                              => "#09-07",
    "N. Sra. Mediug�rie"                                                             => "#09-07",
    "Promulga��o da Constitui��o Republicana (1932)"                                 => "#09-07",
    "Dia da Pizza em S�o Paulo"                                                      => "#10-07",
    "Dia do Rondonista"                                                              => "#11-07",
    "S�o Bento"                                                                      => "#11-07",
    "Dia do Engenheiro Florestal"                                                    => "#12-07",
    "Dia Mundial do Rock"                                                            => "#13-07",
    "Dia do Engenheiro de Saneamento"                                                => "#13-07",
    "Dia dos Cantores e Compositores Sertanejos"                                     => "#13-07",
    "Dia do Propagandista de Laborat�rio"                                            => "#14-07",
    "S�o Camilo de L�lis"                                                            => "#14-07",
    "Dia Nacional dos Clubes"                                                        => "#15-07",
    "Dia do Comerciante"                                                             => "#16-07",
    "N. Sra. do Carmo"                                                               => "#16-07",
    "Dia do Protetor de Florestas"                                                   => "#17-07",
    "Dia da Coroa��o de D. Pedro"                                                    => "#18-07",
    "Dia Nacional do Futebol"                                                        => "#19-07",
    "Dia da Caridade"                                                                => "#19-07",
    "Dia da Junta Comercial"                                                         => "#19-07",
    "Dia Pan-Americano do Engenheiro"                                                => "#20-07",
    "Dia do Revendedor (de Gasolina)"                                                => "#20-07",
    "1� Vez Que o Homem Pisou na Lua (1969)"                                         => "#21-07",
    "Santa Madalena"                                                                 => "#22-07",
    "Dia da Declara��o da Maioridade de D. Pedro II (1840)"                          => "#23-07",
    "Dia do Guarda Rodovi�rio"                                                       => "#23-07",
    "Dia do Colono"                                                                  => "#25-07",
    "Dia do Motorista"                                                               => "#25-07",
    "S�o Crist�v�o"                                                                  => "#25-07",
    "Dia da Vov�"                                                                    => "#26-07",
    "Santa Ana"                                                                      => "#26-07",
    "S�o Joaquim"                                                                    => "#26-07",
    "Dia Nacional de Preven��o de Acidentes de Trabalho"                             => "#27-07",
    "Dia do Motociclista"                                                            => "#27-07",
    "Santa Marta"                                                                    => "#29-07",
    "S�o In�cio de Loyola"                                                           => "#31-07",
    "Dia Nacional do S�lo"                                                           => "#01-08",
    "Dia do Tintureiro"                                                              => "#03-08",
    "S�o Jo�o Maria Vianei"                                                          => "#04-08",
    "N. Sra. das Neves"                                                              => "#05-08",
    "Bom Jesus"                                                                      => "#06-08",
    "S�o Caetano"                                                                    => "#07-08",
    "Dia do Padre"                                                                   => "#08-08",
    "S�o Louren�o"                                                                   => "#10-08",
    "Dia Internacional da Logosofia"                                                 => "#11-08",
    "Dia da Consci�ncia Nacional"                                                    => "#11-08",
    "Dia da Pintura"                                                                 => "#11-08",
    "Dia do Advogado"                                                                => "#11-08",
    "Dia do Direito"                                                                 => "#11-08",
    "Dia do Gar�om"                                                                  => "#11-08",
    "Dia do Magistrado"                                                              => "#11-08",
    "Dia Nacional das Artes"                                                         => "#12-08",
    "N. Sra. das Cabe�as"                                                            => "#12-08",
    "Dia do Economista"                                                              => "#13-08",
    "Dia do Encarcerado"                                                             => "#13-08",
    "Dia da Unidade Humana"                                                          => "#14-08",
    "Assun��o de Nossa Senhora"                                                      => "#15-08",
    "Dia da Inform�tica"                                                             => "#15-08",
    "Dia dos Solteiros"                                                              => "#15-08",
    "N. Sra. da Gl�ria"                                                              => "#15-08",
    "S�o Roque"                                                                      => "#16-08",
    "Cria��o do Instituto Hist�rico e Geogr�fico, Rio de Janeiro-RJ (1838)"          => "#18-08",
    "Santa Helena"                                                                   => "#18-08",
    "Dia Mundial da Fotografia"                                                      => "#19-08",
    "Dia do Artista de Teatro"                                                       => "#19-08",
    "Dia do Ma�om"                                                                   => "#20-08",
    "Dia do Excepcional"                                                             => "#22-08",
    "Dia Internacional em Mem�ria da Escravid�o e da Aboli��o"                       => "#23-08",
    "Dia da Injusti�a"                                                               => "#23-08",
    "Santa Rosa de Lima"                                                             => "#23-08",
    "S�o Bartolomeu"                                                                 => "#24-08",
    "Dia do Ex�rcito Brasileiro"                                                     => "#25-08",
    "Dia do Feirante"                                                                => "#25-08",
    "Dia do Soldado"                                                                 => "#25-08",
    "Dia Nacional do Psic�logo"                                                      => "#27-08",
    "Dia do Corretor de Im�veis"                                                     => "#27-08",
    "Santa M�nica"                                                                   => "#27-08",
    "Dia Nacional dos Banc�rios"                                                     => "#28-08",
    "Dia da Avicultura"                                                              => "#28-08",
    "Santo Agostinho"                                                                => "#28-08",
    "Dia do Nutricionista"                                                           => "#31-08",
    "S�o Raimundo Nonato"                                                            => "#31-08",
    "Dia do Bi�logo"                                                                 => "#03-09",
    "Dia da Amaz�nia"                                                                => "#05-09",
    "Dia do Oficial de Farm�cia"                                                     => "#05-09",
    "Dia do Alfaiate"                                                                => "#06-09",
    "Natividade de Nossa Senhora"                                                    => "#08-09",
    "Dia do Administrador"                                                           => "#09-09",
    "Dia do Veterin�rio"                                                             => "#09-09",
    "Dia da Cruz"                                                                    => "#14-09",
    "Dia do Frevo"                                                                   => "#14-09",
    "N. Sra. das Dores"                                                              => "#15-09",
    "S�o Cipriano"                                                                   => "#16-09",
    "Dia da Compreens�o Mundial"                                                     => "#17-09",
    "Promulga��o da Constitui��o do Brasil (1946)"                                   => "#18-09",
    "Dia do Teatro"                                                                  => "#19-09",
    "S�o Genaro"                                                                     => "#19-09",
    "Dia do Funcion�rio Municipal"                                                   => "#20-09",
    "Dia do Ga�cho"                                                                  => "#20-09",
    "Dia do Policial Civil"                                                          => "#20-09",
    "Dia Nacional da Radiodifus�o"                                                   => "#21-09",
    "Dia da �rvore"                                                                  => "#21-09",
    "Dia do Fazendeiro"                                                              => "#21-09",
    "Dia do Radialista"                                                              => "#21-09",
    "Dia do Radio"                                                                   => "#21-09",
    "Santa Efig�nia"                                                                 => "#21-09",
    "S�o Mateus"                                                                     => "#21-09",
    "Dia do Soldador"                                                                => "#23-09",
    "Dia Interamericano/Internacional de Rela��es P�blicas"                          => "#26-09",
    "Dia Mundial do Turismo"                                                         => "#27-09",
    "Dia do Anci�o"                                                                  => "#27-09",
    "Dia do Encanador"                                                               => "#27-09",
    "S�o Cosme e Dami�o"                                                             => "#27-09",
    "S�o Vicente de Paulo"                                                           => "#27-09",
    "Dia da Lei do Sexagen�rio"                                                      => "#28-09",
    "Dia da M�e Preta"                                                               => "#28-09",
    "Lei do Ventre Livre Sancionada pela Princesa Isabel (1871)"                     => "#28-09",
    "Dia do Anunciante"                                                              => "#29-09",
    "Dia do Professor de Educa��o F�sica"                                            => "#29-09",
    "Santos Arcanjos"                                                                => "#29-09",
    "S�o Gabriel"                                                                    => "#29-09",
    "S�o Miguel"                                                                     => "#29-09",
    "Dia Internacional da Navega��o"                                                 => "#30-09",
    "Dia Mundial do Tradutor"                                                        => "#30-09",
    "Dia da Secret�ria"                                                              => "#30-09",
    "S�o Jer�nimo"                                                                   => "#30-09",
    "Dia Nacional do Vereador"                                                       => "#01-10",
    "Dia Pan-Americano do Vendedor"                                                  => "#01-10",
    "Dia do Representante Comercial"                                                 => "#01-10",
    "Dia da Esquadra"                                                                => "#01-10",
    "Dia do Anjo da Guarda"                                                          => "#02-10",
    "Dia das Abelhas"                                                                => "#03-10",
    "Dia Mundial do Dentista"                                                        => "#03-10",
    "Dia do Latino-Americano"                                                        => "#03-10",
    "Dia Internacioanl dos Animais"                                                  => "#03-10",
    "Dia da Ave"                                                                     => "#04-10",
    "Dia da Natureza"                                                                => "#04-10",
    "Dia do Barman"                                                                  => "#04-10",
    "Dia do C�o"                                                                     => "#04-10",
    "Dia do Poeta"                                                                   => "#04-10",
    "Dia do Radio Interamericano"                                                    => "#04-10",
    "S�o Francisco de Assis"                                                         => "#04-10",
    "Dia Internacional da Ecologia"                                                  => "#04-10",
    "Dia Mundial dos Animais"                                                        => "#05-10",
    "Dia das Aves"                                                                   => "#05-10",
    "Promulga��o da Nova Constitui��o do Brasil (1988)"                              => "#05-10",
    "S�o Benedito"                                                                   => "#05-10",
    "Dia do Compositor"                                                              => "#07-10",
    "N. Sra. do Ros�rio"                                                             => "#07-10",
    "Dia do Nordestino"                                                              => "#08-10",
    "N. Sra. de Nazar�"                                                              => "#10-10",
    "Dia do Deficiente F�sico"                                                       => "#11-10",
    "Dia do Teatro Municipal"                                                        => "#11-10",
    "Descobrimento da Am�rica (1492)"                                                => "#12-10",
    "Dia da Aclama��o de D. Pedro I"                                                 => "#12-10",
    "Dia da Cirurgia Infantil"                                                       => "#12-10",
    "Dia do Mar"                                                                     => "#12-10",
    "Inaugura��o do Cristo Redentor Rio de Janeiro-RJ"                               => "#12-10",
    "Dia da Terapia Ocupacional"                                                     => "#13-10",
    "Dia do Fisioterapeuta"                                                          => "#13-10",
    "Dia Nacional da Pecu�ria"                                                       => "#14-10",
    "Dia da Normalista"                                                              => "#15-10",
    "Dia do Professor"                                                               => "#15-10",
    "Dia Mundial da Alimenta��o"                                                     => "#16-10",
    "Santa Edwirges (Endividados)"                                                   => "#16-10",
    "Dia da Industria Aeron�utica Brasileira"                                        => "#17-10",
    "Dia do Eletricista"                                                             => "#17-10",
    "Dia do Estivador"                                                               => "#18-10",
    "Dia do M�dico"                                                                  => "#18-10",
    "Dia do Pintor (de Parede, de Carro)"                                            => "#18-10",
    "S�o Lucas (M�dicos)"                                                            => "#18-10",
    "Dia do Contato"                                                                 => "#21-10",
    "Dia do MacKenzie"                                                               => "#21-10",
    "Comemora��o do 1� V�o de Santos Dumont pilotando o 14 Bis (1906)"               => "#23-10",
    "Dia da Avia��o e do Aviador"                                                    => "#23-10",
    "Dia Mundial do Desenvolvimento"                                                 => "#24-10",
    "Dia da Democracia"                                                              => "#25-10",
    "Dia das Miss�es"                                                                => "#25-10",
    "Dia do Dentista Brasileiro"                                                     => "#25-10",
    "Dia do Sapateiro"                                                               => "#25-10",
    "Dia da Universidade Cat�lica"                                                   => "#28-10",
    "Dia do Funcion�rio P�blico"                                                     => "#28-10",
    "S�o Judas Tadeu (Causas Imposs�veis)"                                           => "#28-10",
    "Dia da Decora��o"                                                               => "#30-10",
    "Dia do Balconista"                                                              => "#30-10",
    "Dia do Comerci�rio"                                                             => "#30-10",
    "S�o Geraldo"                                                                    => "#30-10",
    "Dia Mundial da Poupan�a"                                                        => "#31-10",
    "Todos os Santos"                                                                => "#01-11",
    "S�o L�zaro"                                                                     => "#02-11",
    "Dia do Cabeleireiro"                                                            => "#03-11",
    "Dia do Inventor"                                                                => "#04-11",
    "Dia Nacional da Cultura"                                                        => "#05-11",
    "Dia da Ci�ncia"                                                                 => "#05-11",
    "Dia do Cinema Brasileiro"                                                       => "#05-11",
    "Dia do Radio-Amador"                                                            => "#05-11",
    "Dia do T�cnico em Eletr�nica"                                                   => "#05-11",
    "A��o Cat�lica"                                                                  => "#07-11",
    "Dia Nacional dos Tribunais de Conta"                                            => "#07-11",
    "Dia Mundial do Urbanismo"                                                       => "#08-11",
    "Dia do Munic�pio"                                                               => "#09-11",
    "Dia do Trigo"                                                                   => "#10-11",
    "Dia do Soldado Desconhecido"                                                    => "#11-11",
    "Dia do Supermercado"                                                            => "#12-11",
    "Anivers�rio do Minist�rio da Educa��o"                                          => "#14-11",
    "Dia Nacional da Alfabetiza��o"                                                  => "#14-11",
    "Dia do Esporte Amador"                                                          => "#15-11",
    "Santos Roque Gonzalez e Companheiros"                                           => "#19-11",
    "Dia Nacional da Consci�ncia Negra"                                              => "#20-11",
    "Dia do Datiloscopista Brasileiro"                                               => "#20-11",
    "Dia da Homeopatia"                                                              => "#21-11",
    "Dia das Sauda��es"                                                              => "#21-11",
    "Dia da Solidariedade com o Povo Liban�s"                                        => "#22-11",
    "Santa Cec�lia"                                                                  => "#22-11",
    "Dia Nacional do Doador de Sangue"                                               => "#25-11",
    "Dia da Baiana do Acaraj�"                                                       => "#25-11",
    "Santa Catarina"                                                                 => "#26-11",
    "N. Sra. das Gra�as"                                                             => "#27-11",
    "Dia Mundial de A��o de Gra�as"                                                  => "#28-11",
    "Santo Andr� (Ap�stolo)"                                                         => "#30-11",
    "Dia Mundial de Preven��o contra AIDS"                                           => "#01-12",
    "Dia do Imigrante"                                                               => "#01-12",
    "Dia do Numismata"                                                               => "#01-12",
    "Dia Nacional da Astronomia"                                                     => "#02-12",
    "Dia Nacional das Rela��es P�blicas"                                             => "#02-12",
    "Dia Nacional do Samba"                                                          => "#02-12",
    "S�o Francisco Xavier"                                                           => "#03-12",
    "Dia Mundial da Propaganda"                                                      => "#04-12",
    "Dia Nacional do Minist�rio P�blico"                                             => "#04-12",
    "Dia do Orientador Educacional"                                                  => "#04-12",
    "Dia do Pod�logo"                                                                => "#04-12",
    "Dia do Trabalhador em Minas de Carv�o"                                          => "#04-12",
    "Santa B�rbara"                                                                  => "#04-12",
    "Dia da Funda��o da Associa��o Comercial de S�o Paulo (1894)"                    => "#07-12",
    "UNESCO Declara Bras�lia Patrim�nio Cultural da Humanidade (1987)"               => "#07-12",
    "Anivers�rio da Avenida Paulista S�o Paulo-SP (1891)"                            => "#08-12",
    "Dia Nacional da Fam�lia"                                                        => "#08-12",
    "Imaculada Concei��o"                                                            => "#08-12",
    "Dia da Justi�a"                                                                 => "#08-12",
    "Dia do Cronista Esportivo"                                                      => "#08-12",
    "Dia da Crian�a Defeituosa"                                                      => "#09-12",
    "Dia do Alco�latra Recuperado"                                                   => "#09-12",
    "Dia do Fono�udiologo"                                                           => "#09-12",
    "Declara��o Universal dos Direitos Humanos"                                      => "#10-12",
    "Dia do Palha�o"                                                                 => "#10-12",
    "Dia do Arquiteto"                                                               => "#11-12",
    "Dia do Engenheiro"                                                              => "#11-12",
    "Dia do Tango"                                                                   => "#11-12",
    "N. Sra. de Guadalupe"                                                           => "#12-12",
    "Dia do Avaliador"                                                               => "#13-12",
    "Dia do Cego"                                                                    => "#13-12",
    "Dia do Marinheiro"                                                              => "#13-12",
    "Dia do �tico"                                                                   => "#13-12",
    "Santa Luzia"                                                                    => "#13-12",
    "Dia do Reservista"                                                              => "#16-12",
    "Dia do Mec�nico"                                                                => "#20-12",
    "Dia do Vizinho"                                                                 => "#23-12",
    "Dia do �rf�o"                                                                   => "#24-12",
    "Dia da Lembran�a"                                                               => "#26-12",
    "Santo Estev�o"                                                                  => "#26-12",
    "Festa da Sagrada Fam�lia"                                                       => "#27-12",
    "Dia do Salva-Vidas"                                                             => "#28-12",
    "S�o Silvestre (Reveillon)"                                                      => "#31-12"
};

$Profiles->{'BR-AC'} = # Acre
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-AL'} = # Alagoas
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-AP'} = # Amap�
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-AM'} = # Amazonas
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-BA'} = # Bahia
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-CE'} = # Cear�
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-DF'} = # Distrito Federal
{
    %{$Profiles->{'BR'}},
    "Funda��o da Cidade de Bras�lia-DF (1960)"                                       => "#21-04"  # feriado em Bras�lia ?
};
$Profiles->{'BR-ES'} = # Esp�rito Santo
{
    %{$Profiles->{'BR'}},
    "N. Sra. da Penha"                                                               => "#24-04", # feriado em Vit�ria e Vila Velha
    "Dia da Cidade de Vit�ria"                                                       => "#08-09", # feriado s� em Vit�ria
    "Dia da Coloniza��o do Solo Esp�ritosantense"                                    => "#23-05"  # feriado s� em Vila Velha
};
$Profiles->{'BR-GO'} = # Goi�s
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-MA'} = # Maranh�o
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-MT'} = # Mato Grosso
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-MS'} = # Mato Grosso do Sul
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-MG'} = # Minas Gerais
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-PR'} = # Paran�
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-PB'} = # Para�ba
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-PA'} = # Par�
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-PE'} = # Pernambuco
{
    %{$Profiles->{'BR'}},
    "Funda��o da Cidade de Recife (1537)"                                            => "#12-03"  # feriado em Recife ?
};
$Profiles->{'BR-PI'} = # Piau�
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-RN'} = # Rio Grande do Norte
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-RS'} = # Rio Grande do Sul
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-RJ'} = # Rio de Janeiro
{
    %{$Profiles->{'BR'}},
    "S�o Sebasti�o (Padroeiro da Cidade do Rio de Janeiro)"                          => "#20-01", # feriado no Rio de Janeiro
    "Funda��o da Cidade do Rio de Janeiro (1565)"                                    => "#01-03"  # feriado no Rio de Janeiro
};
$Profiles->{'BR-RO'} = # Rond�nia
{
    %{$Profiles->{'BR'}},
    "Dia da Cria��o do Estado de Rond�nia-RO"                                        => "#04-01", # feriado ?
    "Dia de Rondon"                                                                  => "#05-05", # feriado ?
    "Dia do Rondonista"                                                              => "#11-07"  # feriado ?
};
$Profiles->{'BR-RR'} = # Roraima
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-SC'} = # Santa Catarina
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-SE'} = # Sergipe
{
    %{$Profiles->{'BR'}}
};
$Profiles->{'BR-SP'} = # S�o Paulo
{
    %{$Profiles->{'BR'}},
    "Funda��o da Cidade de S�o Paulo (1554)"                                         => "#25-01", # feriado em S�o Paulo
};
$Profiles->{'BR-TO'} = # Tocantins
{
    %{$Profiles->{'BR'}}
};

# Thanks to:
# Daniel Crown <daniel@mailgratis.com.ar>

$Profiles->{'AR'} = # Argentina
{
    "A�o Nuevo"                       => "01-01",
    "D�a de los Reyes (Epifan�a)"     => "06-01",
    "D�a de Malvinas"                 => "02-04",
    "Jueves Santo"                    => "-3",
    "Viernes Santo"                   => "-2",
    "Domingo de P�scuas"              => "+0",
    "Lunes de P�scuas"                => "+1",
    "D�a del Trabajo"                 => "01-05",
    "Revoluci�n de Mayo"              => "25-05",
    "Soberan�a de las Islas Malvinas" => "10-06",
    "D�a del Padre"                   => "3/Sun/Jun",
    "D�a de la Bandera"               => "20-06",
    "D�a del Ni�o"                    => "03-07",
    "D�a de la Independencia"         => "09-07",
    "D�a de Eva Peron"                => "26-07",
    "La Asunci�n"                     => "15-08",
    "D�a de San Martin"               => "17-08",
    "Muerte de San Martin"            => "18-08",
    "D�a de la Raza"                  => "12-10",
    "D�a de la Madre"                 => "3/Sun/Oct",
    "D�a de Todos los Santos"         => "01-11",
    "Inmaculada Concepci�n"           => "08-12",
    "Navidad"                         => "25-12"
};

# Thanks to:
# Jabu Virginia Duma, Giant's Castle Lodge,
# Drakensberg, 3310 Estcourt, KwaZulu-Natal
# Dirk Swart <dirk@clickshare.com> <dirk@tristar.co.za>
# http://www.gov.za/sa_overview/holidays.htm
# http://www.gov.za/events/previous/y2kholidays.htm
# Hilda de Jager <Hildadj@gcis.pwv.gov.za>
# Hennie Meyer <Henniem@dbs1.pwv.gov.za>

$Profiles->{'ZA'} = # South Africa
{
    "Special Y2K Holiday #1"    => \&ZA_Y2K_1,
    "Special Y2K Holiday #2"    => \&ZA_Y2K_2,
    "Special Y2K Holiday #3"    => \&ZA_Y2K_3,
    "New Year's Day"            => \&ZA_New_Year,
    "Human Rights Day"          => \&ZA_Human_Rights,
    "Good Friday"               => "-2",
    "Easter Sunday"             => "+0",
    "Family Day"                => "+1",
    "Freedom Day"               => \&ZA_Freedom,
    "Workers Day"               => \&ZA_Workers,
    "Youth Day (Soweto Day)"    => \&ZA_Youth,
    "National Women's Day"      => \&ZA_Women,
    "Heritage Day"              => \&ZA_Heritage,
    "Day of Reconciliation"     => \&ZA_Reconciliation,
    "Christmas"                 => \&ZA_Christmas,
    "Day of Goodwill"           => \&ZA_Goodwill
};

sub ZA_Y2K_1
{
    my($year,$label) = @_;
    if ($year == 1999) { return(1999,12,31); }
    else               { return(); }
}
sub ZA_Y2K_2
{
    my($year,$label) = @_;
    if ($year == 2000) { return(2000,1,2); }
    else               { return(); }
}
sub ZA_Y2K_3
{
    my($year,$label) = @_;
    if ($year == 2000) { return(2000,1,3); }
    else               { return(); }
}
sub ZA_New_Year
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,1,1) );
}
sub ZA_Human_Rights
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,3,21) );
}
sub ZA_Freedom
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,4,27) );
}
sub ZA_Workers
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,5,1) );
}
sub ZA_Youth
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,6,16) );
}
sub ZA_Women
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,8,9) );
}
sub ZA_Heritage
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,9,24) );
}
sub ZA_Reconciliation
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,12,16) );
}
sub ZA_Christmas
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,12,25) );
}
sub ZA_Goodwill
{
    my($year,$label) = @_;
    return( &Sunday_to_Monday($year,12,26) );
}

$Profiles->{'ZA-WC'} =  # Western Cape
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-EC'} =  # Eastern Cape
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-NC'} =  # Northern Cape
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-FS'} =  # Free State
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-NW'} =  # North West
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-GA'} =  # Gauteng
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-NP'} =  # Northern Province
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-MP'} =  # Mpumalanga
{
    %{$Profiles->{'ZA'}}
};
$Profiles->{'ZA-KZN'} = # KwaZulu-Natal
{
    %{$Profiles->{'ZA'}}
};

$Profiles->{'sdm'} = # software design & management AG
{
    "Heiligabend"               => ":24.12.",
    "Sylvester"                 => ":31.12."
};

$Profiles->{'sdm-MUC'} = { %{$Profiles->{'DE-BY'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-STG'} = { %{$Profiles->{'DE-BW'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-FFM'} = { %{$Profiles->{'DE-HE'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-BON'} = { %{$Profiles->{'DE-NW'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-CGN'} = { %{$Profiles->{'DE-NW'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-RAT'} = { %{$Profiles->{'DE-NW'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-HAN'} = { %{$Profiles->{'DE-NI'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-HH'}  = { %{$Profiles->{'DE-HH'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-BLN'} = { %{$Profiles->{'DE-BE'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-DET'} = { %{$Profiles->{'US-MI'}}, %{$Profiles->{'sdm'}} };
$Profiles->{'sdm-ZRH'} = { %{$Profiles->{'CH-DE'}}, %{$Profiles->{'sdm'}} };

1;

__END__

