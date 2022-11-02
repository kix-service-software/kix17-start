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

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use Kernel::System::Environment;
use Kernel::System::VariableCheck qw( :all );
use Kernel::System::ObjectManager;

use Linux::Distribution;
use ExtUtils::MakeMaker;
use File::Path;
use Getopt::Long;
use Term::ANSIColor;

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix.CheckModules.pl',
    },
);

## no critic qw(BuiltinFunctions::ProhibitStringyEval)

our %InstTypeToCMD = (

    # [InstType] => {
    #    CMD       => '[cmd to install module]',
    #    UseModule => 1/0,
    # }
    # Set UseModule to 1 if you want to use the
    # cpan module name of the package as replace string.
    # e.g. yum install "perl(Date::Format)"
    # If you set it 0 it will use the name
    # for the InstType of the module
    # e.g. apt-get install -y libtimedate-perl
    # and as fallback the default cpan install command
    # e.g. cpan DBD::Oracle
    aptget => {
        CMD       => 'apt-get install -y %s',
        UseModule => 0,
    },
    emerge => {
        CMD       => 'emerge %s',
        UseModule => 0,
    },
    ppm => {
        CMD       => 'ppm install %s',
        UseModule => 0,
    },
    yum => {
        CMD       => 'yum install "%s"',
        SubCMD    => 'perl(%s)',
        UseModule => 1,
    },
    zypper => {
        CMD       => 'zypper install %s',
        UseModule => 0,
    },
    default => {
        CMD => 'cpan %s',
    },
);

our %DistToInstType = (

    # apt-get
    debian => 'aptget',
    ubuntu => 'aptget',

    # emerge
    # for reasons unknown, some environments return "gentoo" (incl. the quotes)
    '"gentoo"' => 'emerge',
    gentoo     => 'emerge',

    # yum
    centos => 'yum',
    fedora => 'yum',
    rhel   => 'yum',
    redhat => 'yum',

    # zypper
    suse => 'zypper',
);

our $OSDist = Linux::Distribution::distribution_name() || '';

my $AllModules;
my $NeedPackageList;
my $Help;
GetOptions(
    all  => \$AllModules,
    list => \$NeedPackageList,
    h    => \$Help
);

# check needed params
if ($Help) {
    print "kix.CheckModules.pl - KIX CheckModules\n";
    print "usage: kix.CheckModules.pl [-list|all] \n";
    print "\n\tkix.CheckModules.pl";
    print "\n\t\ŧReturns all required and optional packages of KIX.\n";
    print "\n\tkix.CheckModules.pl -list";
    print "\n\t\ŧReturns a install command with all required packages.\n";
    print "\n\tkix.CheckModules.pl -all";
    print "\n\t\ŧReturns all required, optional and bundled packages of KIX.\n\n";
    exit 1;
}

my $Options = shift || '';
my $NeedNoColors;

if ( $ENV{nocolors} || $Options =~ m{\A nocolors}msxi ) {
    $NeedNoColors = 1;
}

# config
my @NeededModules = (
    {
        Module    => 'Algorithm::Diff',
        Required  => 1,
        Comment   => 'Compute \'intelligent\' differences between two files / lists.',
        InstTypes => {
            aptget => 'libalgorithm-diff-perl',
            emerge => undef,
            zypper => 'perl-Algorithm-Diff',
        },
    },
    {
        Module    => 'Apache::DBI',
        Required  => 0,
        Comment   => 'Improves Performance on Apache webservers with mod_perl enabled.',
        InstTypes => {
            aptget => 'libapache-dbi-perl',
            emerge => 'dev-perl/Apache-DBI',
            zypper => 'perl-Apache-DBI',
        },
    },
    {
        Module    => 'Apache2::Reload',
        Required  => 0,
        Comment   => 'Avoids web server restarts on mod_perl.',
        InstTypes => {
            aptget => 'libapache2-mod-perl2',
            emerge => 'dev-perl/Apache-Reload',
            zypper => 'apache2-mod_perl',
        },
    },
    {
        Module    => 'Archive::Tar',
        Required  => 1,
        Comment   => 'Required for compressed file generation (in perlcore).',
        InstTypes => {
            emerge => 'perl-core/Archive-Tar',
            zypper => 'perl-Archive-Tar',
        },
    },
    {
        Module    => 'Archive::Zip',
        Required  => 1,
        Comment   => 'Required for compressed file generation.',
        InstTypes => {
            aptget => 'libarchive-zip-perl',
            emerge => 'dev-perl/Archive-Zip',
            zypper => 'Archive-Zip',
            zypper => 'perl-Archive-Zip',
        },
    },
    {
        Module    => 'Bytes::Random::Secure::Tiny',
        Required  => 1,
        Comment   => 'A tiny Perl extension to generate cryptographically-secure random bytes.',
        InstTypes => {
            aptget => undef,
            emerge => undef,
            zypper => undef,
        },
    },
    {
        Module    => 'CGI',
        Required  => 1,
        Comment   => 'Handle Common Gateway Interface requests and responses.',
        InstTypes => {
            aptget => 'libcgi-pm-perl',
            emerge => undef,
            zypper => 'perl-CGI',
        },
    },
    {
        Module    => 'CGI::Fast',
        Required  => 0,
        Comment   => 'CGI Interface for Fast CGI.',
        InstTypes => {
            aptget => 'libcgi-fast-perl',
            emerge => undef,
            zypper => 'perl-cgi-fast',
        },
    },
    {
        Module    => 'Class::Inspector',
        Required  => 0,
        Comment   => 'Get information about a class and its structure.',
        InstTypes => {
            aptget => 'libclass-inspector-perl',
            emerge => undef,
            zypper => 'perl-class-inspector',
        },
    },
    {
        Module    => 'Crypt::Eksblowfish::Bcrypt',
        Required  => 0,
        Comment   => 'For strong password hashing.',
        InstTypes => {
            aptget => 'libcrypt-eksblowfish-perl',
            emerge => 'dev-perl/Crypt-Eksblowfish',
            zypper => 'perl-Crypt-Eksblowfish',
        },
    },
    {
        Module    => 'Crypt::PasswdMD5',
        Required  => 1,
        Comment   => 'Provide interoperable MD5-based crypt() functions.',
        InstTypes => {
            aptget => 'libcrypt-passwdmd5-perl',
            emerge => undef,
            zypper => 'perl-crypt-passwdMD5',
        },
    },
    {
        Module    => 'Crypt::SSLeay',
        Required  => 0,
        Comment   => 'OpenSSL support for LWP.',
        InstTypes => {
            aptget => 'libcrypt-ssleay-perl',
            emerge => undef,
            zypper => 'perl-crypt-ssleay',
        },
    },
    {
        Module    => 'CSS::Minifier',
        Required  => 0,
        Comment   => 'Perl extension for minifying CSS.',
        InstTypes => {
            aptget => 'libcss-minifier-perl',
            emerge => undef,
            zypper => 'perl-css-minifier-xs',
        },
    },
    {
        Module   => 'Data::Compare',
        Required => 0,
        Comment  => 'Required to track SysConfig changes.',
    },
    {
        Module    => 'Date::Format',
        Required  => 1,
        InstTypes => {
            aptget => 'libtimedate-perl',
            emerge => 'dev-perl/TimeDate',
            zypper => 'perl-TimeDate',
        },
    },
    {
        Module    => 'Date::Pcalc',
        Required  => 1,
        Comment   => 'Gregorian calendar date calculations.',
        InstTypes => {
            aptget => 'libdate-pcalc-perl',
            emerge => undef,
            zypper => undef,
        },
    },
    {
        Module    => 'DBI',
        Required  => 1,
        InstTypes => {
            aptget => 'libdbi-perl',
            emerge => 'dev-perl/DBI',
            zypper => 'perl-DBI'
        },
    },
    {
        Module    => 'DBD::mysql',
        Required  => 0,
        Comment   => 'Required to connect to a MySQL database.',
        InstTypes => {
            aptget => 'libdbd-mysql-perl',
            emerge => 'dev-perl/DBD-mysql',
            zypper => 'perl-DBD-mysql'
        },
    },
    {
        Module       => 'DBD::ODBC',
        Required     => 0,
        NotSupported => [
            {
                Version => '1.23',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
        ],
        Comment   => 'Required to connect to a MS-SQL database.',
        InstTypes => {
            aptget => 'libdbd-odbc-perl',
            emerge => undef,
            yum    => undef,
            zypper => undef,
        },
    },
    {
        Module    => 'DBD::Oracle',
        Required  => 0,
        Comment   => 'Required to connect to a Oracle database.',
        InstTypes => {
            aptget => undef,
            emerge => undef,
            yum    => undef,
            zypper => undef,
        },
    },
    {
        Module    => 'DBD::Pg',
        Required  => 0,
        Comment   => 'Required to connect to a PostgreSQL database.',
        InstTypes => {
            aptget => 'libdbd-pg-perl',
            emerge => 'dev-perl/DBD-Pg',
            zypper => 'perl-DBD-Pg',
        },
    },
    {
        Module    => 'Email::Valid',
        Required  => 1,
        Comment   => 'Check validity of Internet email addresses.',
        InstTypes => {
            aptget => 'libemail-valid-perl',
            emerge => undef,
            zypper => 'perl-Email-Valid',
        },
    },
    {
        Module    => 'Encode::HanExtra',
        Version   => '0.23',
        Required  => 0,
        Comment   => 'Required to handle mails with several Chinese character sets.',
        InstTypes => {
            aptget => 'libencode-hanextra-perl',
            emerge => 'dev-perl/Encode-HanExtra',
            zypper => 'perl-Encode-HanExtra',
        },
    },
    {
        Module    => 'Encode::Locale',
        Version   => '1.05',
        Required  => 1,
        Comment   => 'Determine the locale encoding.',
        InstTypes => {
            aptget => 'libencode-locale-perl',
            emerge => undef,
            zypper => 'perl-Encode-Locale',
        },
    },
    {
        Module    => 'Excel::Writer::XLSX',
        Required  => 1,
        Comment   => 'Create a new file in the Excel 2007+ XLSX format.',
        InstTypes => {
            aptget => 'libexcel-writer-xlsx-perl',
            emerge => undef,
            zypper => undef,
        },
    },
    {
        Module    => 'Font::TTF',
        Required  => 1,
        Comment   => 'Perl module for TrueType Font hacking.',
        InstTypes => {
            aptget => 'libfont-ttf-perl',
            emerge => undef,
            zypper => 'perl-Font-TTF',
        },
    },
    {
        Module    => 'GD',
        Required  => 1,
        Comment   => 'Interface to Gd Graphics Library.',
        InstTypes => {
            aptget => 'libgd-perl',
            emerge => undef,
            zypper => 'perl-gd',
        },
    },
    {
        Module    => 'GD::SecurityImage',
        Required  => 1,
        InstTypes => {
            aptget => 'libgd-securityimage-perl',
            emerge => undef,
            zypper => 'perl-gd-securityimage',
        },
    },
    {
        Module    => 'HTML::Tagset',
        Required  => 1,
        Comment   => 'data tables useful in parsing HTML.',
        InstTypes => {
            aptget => 'libhtml-tagset-perl',
            emerge => undef,
            zypper => 'perl-HTML-Tagset',
        },
    },
    {
        Module    => 'HTML::Truncate',
        Required  => 1,
        Comment   => 'truncate HTML by percentage or character count while preserving well-formedness.',
        InstTypes => {
            aptget => undef,
            emerge => undef,
            zypper => undef,
        },
    },
    {
        Module    => 'HTTP::Date',
        Required  => 1,
        Comment   => 'date conversion routines.',
        InstTypes => {
            aptget => 'libhttp-date-perl',
            emerge => undef,
            zypper => 'perl-http-date',
        },
    },
    {
        Module    => 'HTTP::Message',
        Required  => 1,
        Comment   => 'HTTP style message (base class).',
        InstTypes => {
            aptget => 'libhttp-message-perl',
            emerge => undef,
            zypper => 'perl-http-message',
        },
    },
    {
        Module    => 'IO::Interactive',
        Required  => 1,
        Comment   => 'Utilities for interactive I/O.',
        InstTypes => {
            aptget => undef,
            emerge => undef,
            zypper => undef,
        },
    },
    {
        Module    => 'IO::Socket::SSL',
        Required  => 0,
        Comment   => 'Required for SSL connections to web and mail servers.',
        InstTypes => {
            aptget => 'libio-socket-ssl-perl',
            emerge => 'dev-perl/IO-Socket-SSL',
            zypper => 'perl-IO-Socket-SSL',
        },
    },
    {
        Module    => 'JavaScript::Minifier',
        Required  => 1,
        Comment   => 'Perl extension for minifying JavaScript code.',
        InstTypes => {
            aptget => 'libjavascript-minifier-perl',
            emerge => undef,
            zypper => 'perl-javascript-minifier',
        },
    },
    {
        Module    => 'JSON',
        Required  => 1,
        Comment   => 'JSON (JavaScript Object Notation) encoder/decoder.',
        InstTypes => {
            aptget => 'libjson-perl',
            emerge => undef,
            zypper => 'perl-JSON',
        },
    },
    {
        Module    => 'JSON::PP',
        Required  => 1,
        Comment   => 'JSON::XS compatible pure-Perl module.',
        InstTypes => {
            aptget => 'libjson-pp-perl',
            emerge => undef,
            zypper => 'perl-JSON-PP',
        },
    },
    {
        Module    => 'JSON::XS',
        Required  => 0,
        Comment   => 'Recommended for faster AJAX/JavaScript handling.',
        InstTypes => {
            aptget => 'libjson-xs-perl',
            emerge => 'dev-perl/JSON-XS',
            zypper => 'perl-JSON-XS',
        },
    },
    {
        Module    => 'Linux::Distribution',
        Required  => 1,
        Comment   => 'Perl extension to detect on which Linux distribution we are running.',
        InstTypes => {
            aptget => 'liblinux-distribution-perl',
            emerge => undef,
            zypper => undef,
        },
    },
    {
        Module   => 'List::Util::XS',
        Required => 1,
        Comment =>
            "Do a 'force install Scalar::Util' via cpan shell to fix this problem. Please make sure to have an c compiler and make installed before.",
        InstTypes => {
            aptget => 'libscalar-list-utils-perl',
            emerge => 'perl-core/Scalar-List-Utils',
            zypper => 'perl-Scalar-List-Utils',
        },
    },
    {
        Module    => 'Locale::Codes',
        Required  => 1,
        Comment   => 'a distribution of modules to handle locale codes.',
        InstTypes => {
            aptget => 'liblocale-codes-perl',
            emerge => undef,
            zypper => 'perl-locale-codes',
        },
    },
    {
        Module    => 'LWP',
        Required  => 1,
        Comment   => 'The World-Wide Web library for Perl.',
        InstTypes => {
            aptget => 'libwww-perl',
            emerge => 'dev-perl/libwww-perl',
            zypper => 'perl-libwww-perl',
        },
    },
    {
        Module    => 'LWP::Protocol::https',
        Required  => 1,
        Comment   => 'Provide https support for LWP::UserAgent.',
        InstTypes => {
            aptget => 'liblwp-protocol-https-perl',
            emerge => undef,
            zypper => 'perl-lwp-protocol-https',
        },
    },
    {
        Module    => 'LWP::UserAgent',
        Required  => 1,
        InstTypes => {
            aptget => 'libwww-perl',
            emerge => 'dev-perl/libwww-perl',
            zypper => 'perl-libwww-perl',
        },
    },
    {
        Module    => 'MailTools',
        Required  => 1,
        Comment   => 'bundle of ancient email modules.',
        InstTypes => {
            aptget => 'libmailtools-perl',
            emerge => undef,
            zypper => 'perl-mailtools',
        },
    },
    {
        Module    => 'Mail::IMAPClient',
        Version   => '3.22',
        Comment   => 'Required for IMAP TLS connections.',
        Required  => 0,
        InstTypes => {
            aptget => 'libmail-imapclient-perl',
            emerge => 'dev-perl/Mail-IMAPClient',
            zypper => 'perl-Mail-IMAPClient',
        },
        Depends => [
            {
                Module    => 'IO::Socket::SSL',
                Required  => 0,
                Comment   => 'Required for IMAP TLS connections.',
                InstTypes => {
                    aptget => 'libio-socket-ssl-perl',
                    emerge => 'dev-perl/IO-Socket-SSL',
                    zypper => 'perl-IO-Socket-SSL',
                },
            },
        ],
    },
    {
        Module    => 'MIME::Tools',
        Required  => 1,
        Comment   => 'modules for parsing (and creating!) MIME entities.',
        InstTypes => {
            aptget => 'libmime-tools-perl',
            emerge => undef,
            zypper => 'perl-mime-tools',
        },
    },
    {
        Module    => 'ModPerl::Util',
        Required  => 0,
        Comment   => 'Improves Performance on Apache webservers dramatically.',
        InstTypes => {
            aptget => 'libapache2-mod-perl2',
            emerge => 'www-apache/mod_perl',
            zypper => 'apache2-mod_perl',
        },
    },
    {
        Module    => 'Mozilla::CA',
        Required  => 1,
        Comment   => 'Mozilla\'s CA cert bundle in PEM format.',
        InstTypes => {
            aptget => undef,
            emerge => undef,
            zypper => 'perl-mozilla-ca',
        },
    },
    {
        Module       => 'Net::DNS',
        Required     => 1,
        NotSupported => [
            {
                Version => '0.60',
                Comment =>
                    'This version is broken and not useable! Please upgrade to a higher version.',
            },
        ],
        InstTypes => {
            aptget => 'libnet-dns-perl',
            emerge => 'dev-perl/Net-DNS',
            zypper => 'perl-Net-DNS',
        },
    },
    {
        Module    => 'Net::HTTP',
        Required  => 1,
        Comment   => 'Low-level HTTP connection (client).',
        InstTypes => {
            aptget => 'libnet-http-perl',
            emerge => undef,
            zypper => 'perl-net-http',
        },
    },
    {
        Module    => 'Net::HTTPS',
        Required  => 1,
        Comment   => 'Low-level HTTP connection (client).',
        InstTypes => {
            aptget => 'libnet-http-perl',
            emerge => undef,
            zypper => 'perl-net-http',
        },
    },
    {
        Module    => 'Net::IMAP::Simple',
        Required  => 0,
        Comment   => 'Perl extension for simple IMAP account handling.',
        InstTypes => {
            aptget => 'libnet-imap-simple-perl',
            emerge => undef,
            zypper => 'perl-net-imap-simple',
        },
    },
    {
        Module    => 'Net::LDAP',
        Required  => 0,
        Comment   => 'Required for directory authentication.',
        InstTypes => {
            aptget => 'libnet-ldap-perl',
            emerge => 'dev-perl/perl-ldap',
            zypper => 'perl-ldap',
        },
    },
    {
        Module    => 'Net::SSLGlue',
        Required  => 1,
        Comment   => 'add/extend SSL support for common perl modules.',
        InstTypes => {
            aptget => 'libnet-sslglue-perl',
            emerge => undef,
            zypper => 'perl-net-sslglue',
        },
    },
    {
        Module    => 'PDF::API2',
        Required  => 1,
        Comment   => 'Create, modify, and examine PDF files.',
        InstTypes => {
            aptget => 'libpdf-api2-perl',
            emerge => undef,
            zypper => 'perl-pdf-api2',
        },
    },
    {
        Module    => 'REST::Client',
        Required  => 1,
        Comment   => 'A simple client for interacting with RESTful http/https resources.',
        InstTypes => {
            aptget => 'librest-client-perl',
            emerge => undef,
            zypper => 'perl-rest-client',
        },
    },
    {
        Module    => 'Schedule::Cron::Events',
        Required  => 1,
        Comment   => 'take a line from a crontab and find out when events will occur.',
        InstTypes => {
            aptget => 'libschedule-cron-events-perl',
            emerge => undef,
            zypper => 'perl-schedule-cron-events',
        },
    },
    {
        Module    => 'Set::Crontab',
        Required  => 1,
        Comment   => 'Expand crontab(5)-style integer lists.',
        InstTypes => {
            aptget => 'libset-crontab-perl',
            emerge => undef,
            zypper => 'perl-set-crontab',
        },
    },
    {
        Module    => 'SOAP::Lite',
        Required  => 1,
        Comment   => 'Perl\'s Web Services Toolkit.',
        InstTypes => {
            aptget => 'libsoap-lite-perl',
            emerge => undef,
            zypper => 'perl-soap-lite',
        },
    },
    {
        Module    => 'Sys::Hostname::Long',
        Required  => 1,
        Comment   => 'Try every conceivable way to get full hostname.',
        InstTypes => {
            aptget => 'libsys-hostname-long-perl',
            emerge => undef,
            zypper => 'perl-sys-hostname-long',
        },
    },
    {
        Module    => 'Template',
        Required  => 1,
        Comment   => 'Template::Toolkit, the rendering engine of KIX.',
        InstTypes => {
            aptget => 'libtemplate-perl',
            emerge => 'dev-perl/Template-Toolkit',
            zypper => 'perl-Template-Toolkit',
        },
    },
    {
        Module    => 'Template::Stash::XS',
        Required  => 1,
        Comment   => 'The fast data stash for Template::Toolkit.',
        InstTypes => {
            aptget => 'libtemplate-perl',
            emerge => 'dev-perl/Template-Toolkit',
            zypper => 'perl-Template-Toolkit',
        },
    },
    {
        Module    => 'Text::CSV',
        Required  => 1,
        Comment   => 'comma-separated values manipulator (using XS or PurePerl).',
        InstTypes => {
            aptget => 'libtext-csv-perl',
            emerge => undef,
            zypper => 'perl-Text-CSV',
        },
    },

    {
        Module    => 'Text::CSV_XS',
        Required  => 0,
        Comment   => 'Recommended for faster CSV handling.',
        InstTypes => {
            aptget => 'libtext-csv-xs-perl',
            emerge => 'dev-perl/Text-CSV_XS',
            zypper => 'perl-Text-CSV_XS',
        },
    },
    {
        Module    => 'Time::HiRes',
        Required  => 1,
        Comment   => 'Required for high resolution timestamps.',
        InstTypes => {
            aptget => 'perl',
            emerge => 'perl-core/Time-HiRes',
            zypper => 'perl-Time-HiRes',
        },
    },
    {
        Module    => 'Try::Tiny',
        Required  => 1,
        Comment   => 'Required for db connection check.',
        InstTypes => {
            aptget => 'libtry-tiny-perl',
            yum    => 'perl(Try::Tiny)',
            zypper => 'perl(Try::Tiny)',
        },
    },
    {
        # perlcore
        Module   => 'Time::Piece',
        Required => 1,
        Comment  => 'Required for statistics.',
    },
    {
        Module    => 'URI',
        Required  => 1,
        Comment   => 'Uniform Resource Identifiers (absolute and relative).',
        InstTypes => {
            aptget => 'liburi-perl',
            emerge => undef,
            zypper => 'perl-uri',
        },
    },
    {
        Module    => 'XML::FeedPP',
        Required  => 1,
        Comment   => 'Parse/write/merge/edit RSS/RDF/Atom syndication feeds.',
        InstTypes => {
            aptget => 'libxml-feedpp-perl',
            emerge => undef,
            zypper => 'perl-xml-feedpp',
        },
    },
    {
        Module    => 'XML::LibXML',
        Required  => 0,
        Comment   => 'Required for Generic Interface XSLT mapping module.',
        InstTypes => {
            aptget => 'libxml-libxml-perl',
            zypper => 'perl-XML-LibXML',
        },
    },
    {
        Module    => 'XML::LibXSLT',
        Required  => 0,
        Comment   => 'Required for Generic Interface XSLT mapping module.',
        InstTypes => {
            aptget => 'libxml-libxslt-perl',
            zypper => 'perl-XML-LibXSLT',
        },
    },
    {
        Module    => 'XML::Parser',
        Required  => 0,
        Comment   => 'Recommended for faster xml handling.',
        InstTypes => {
            aptget => 'libxml-parser-perl',
            emerge => 'dev-perl/XML-Parser',
            zypper => 'perl-XML-Parser',
        },
    },
    {
        Module    => 'XML::Parser::Lite',
        Required  => 1,
        Comment   => 'Lightweight pure-perl XML Parser (based on regexps).',
        InstTypes => {
            aptget => 'libxml-parser-lite-perl',
            emerge => undef,
            zypper => 'perl-XML-Parser-Lite',
        },
    },
    {
        Module    => 'XML::RSS::SimpleGen',
        Required  => 1,
        Comment   => 'for writing RSS files.',
        InstTypes => {
            aptget => 'libxml-rss-simplegen-perl',
            emerge => undef,
            zypper => 'perl-XML-RSS-SimpleGen',
        },
    },
    {
        Module    => 'XML::Simple',
        Required  => 1,
        Comment   => 'An API for simple XML files.',
        InstTypes => {
            aptget => 'libxml-simple-perl',
            emerge => undef,
            zypper => 'perl-XML-Simple',
        },
    },
    {
        Module    => 'YAML',
        Required  => 1,
        Comment   => 'YAML Ain\'t Markup Language.',
        InstTypes => {
            aptget => 'libyaml-perl',
            emerge => undef,
            zypper => 'perl-YAML',
        },
    },
    {
        Module    => 'YAML::XS',
        Required  => 1,
        Comment   => 'Very important',
        InstTypes => {
            aptget => 'libyaml-libyaml-perl',
            emerge => 'dev-perl/YAML-LibYAML',
            zypper => 'perl-YAML-LibYAML',
        },
    },
    {
        Module    => 'parent',
        Required  => 1,
        Comment   => 'Establish an ISA relationship with base classes at compile time.',
        InstTypes => {
            aptget => undef,
            emerge => undef,
            zypper => 'perl-parent',
        },
    },
);

if ($NeedPackageList) {
    my %PackageList = _PackageList( \@NeededModules );

    if ( IsArrayRefWithData( $PackageList{Packages} ) ) {

        my $CMD = $PackageList{CMD};

        for my $Package ( @{ $PackageList{Packages} } ) {
            if ( $PackageList{SubCMD} ) {
                $Package = sprintf $PackageList{SubCMD}, $Package;
            }
        }
        printf $CMD, join( ' ', @{ $PackageList{Packages} } );
        print "\n";
    }
}
else {

    # try to determine module version number
    my $Depends = 0;

    for my $Module (@NeededModules) {
        _Check( $Module, $Depends, $NeedNoColors );
    }

    if ($AllModules) {
        print "\nBundled modules:\n\n";

        my %PerlInfo = Kernel::System::Environment->PerlInfoGet(
            BundledModules => 1,
        );

        for my $Module ( sort keys %{ $PerlInfo{Modules} } ) {
            _Check(
                {
                    Module   => $Module,
                    Required => 1,
                },
                $Depends,
                $NeedNoColors
            );
        }
    }
}

sub _Check {
    my ( $Module, $Depends, $NoColors ) = @_;

    print "  " x ( $Depends + 1 );
    print "o $Module->{Module}";
    my $Length = 33 - ( length( $Module->{Module} ) + ( $Depends * 2 ) );
    print '.' x $Length;

    my $Version = Kernel::System::Environment->ModuleVersionGet( Module => $Module->{Module} );
    if ($Version) {

        # cleanup version number
        my $CleanedVersion = _VersionClean(
            Version => $Version,
        );

        my $ErrorMessage;

        # Test if all module dependencies are installed by requiring the module.
        #   Don't do this for Net::DNS as it seems to take very long (>20s) in a
        #   mod_perl environment sometimes.
        my %DontRequire = (
            'Net::DNS'        => 1,
            'Email::Valid'    => 1,    # uses Net::DNS internally
            'Apache2::Reload' => 1,    # is not needed / working on systems without mod_perl (like Plack etc.)
        );

        if (
            !$DontRequire{ $Module->{Module} }
            && !eval( "require $Module->{Module}" )
        ) {
            $ErrorMessage .= 'Not all prerequisites for this module correctly installed. ';
        }

        if ( $Module->{NotSupported} ) {

            my $NotSupported = 0;
            ITEM:
            for my $Item ( @{ $Module->{NotSupported} } ) {

                # cleanup item version number
                my $ItemVersion = _VersionClean(
                    Version => $Item->{Version},
                );

                if ( $CleanedVersion == $ItemVersion ) {
                    $NotSupported = $Item->{Comment};
                    last ITEM;
                }
            }

            if ($NotSupported) {
                $ErrorMessage .= "Version $Version not supported! $NotSupported ";
            }
        }

        if ( $Module->{Version} ) {

            # cleanup item version number
            my $RequiredModuleVersion = _VersionClean(
                Version => $Module->{Version},
            );

            if ( $CleanedVersion < $RequiredModuleVersion ) {
                $ErrorMessage
                    .= "Version $Version installed but $Module->{Version} or higher is required! ";
            }
        }

        if ($ErrorMessage) {
            if ($NoColors) {
                print "FAILED! $ErrorMessage\n";
            }
            else {
                print color('red') . 'FAILED!' . color('reset') . " $ErrorMessage\n";
            }
        }
        else {
            my $OutputVersion = $Version;

            if ( $OutputVersion =~ m{ [0-9.] }xms ) {
                $OutputVersion = 'v' . $OutputVersion;
            }

            if ($NoColors) {
                print "ok ($OutputVersion)\n";
            }
            else {
                print color('green') . 'ok' . color('reset') . " ($OutputVersion)\n";
            }
        }
    }
    else {
        my $Comment  = $Module->{Comment} ? ' - ' . $Module->{Comment} : '';
        my $Required = $Module->{Required};
        my $Color    = 'yellow';

        # OS Install Command
        my %InstallCommand = _GetInstallCommand($Module);

        # create example installation string for module
        my $InstallText = '';
        if ( IsHashRefWithData( \%InstallCommand ) ) {
            my $CMD = $InstallCommand{CMD};
            if ( $InstallCommand{SubCMD} ) {
                $CMD = sprintf $InstallCommand{CMD}, $InstallCommand{SubCMD};
            }

            $InstallText = " Use: '" . sprintf( $CMD, $InstallCommand{Package} ) . "'";
        }

        if ($Required) {
            $Required = 'required';
            $Color    = 'red';
        }
        else {
            $Required = 'optional';
        }
        if ($NoColors) {
            print "Not installed! ($Required $Comment)\n";
        }
        else {
            print color($Color)
                . 'Not installed!'
                . color('reset')
                . "$InstallText ($Required$Comment)\n";
        }
    }

    if ( $Module->{Depends} ) {
        for my $ModuleSub ( @{ $Module->{Depends} } ) {
            _Check( $ModuleSub, $Depends + 1, $NoColors );
        }
    }

    return 1;
}

sub _PackageList {
    my ($PackageList) = @_;

    my $CMD;
    my $SubCMD;
    my @Packages;

    # if we're on Windows we don't need to see Apache + mod_perl modules
    MODULE:
    for my $Module ( @{$PackageList} ) {

        my $Required = $Module->{Required};
        my $Version = Kernel::System::Environment->ModuleVersionGet( Module => $Module->{Module} );
        if ( !$Version ) {
            my %InstallCommand = _GetInstallCommand($Module);

            next MODULE if !$Required;

            if ( $Module->{Depends} ) {

                MODULESUB:
                for my $ModuleSub ( @{ $Module->{Depends} } ) {
                    my %InstallCommandSub = _GetInstallCommand($ModuleSub);

                    next MODULESUB if !IsHashRefWithData( \%InstallCommandSub );
                    next MODULESUB if !$Required;

                    push @Packages, $InstallCommandSub{Package};
                }
            }

            next MODULE if !IsHashRefWithData( \%InstallCommand );

            $CMD    = $InstallCommand{CMD};
            $SubCMD = $InstallCommand{SubCMD};
            push @Packages, $InstallCommand{Package};
        }
    }

    return (
        CMD      => $CMD,
        SubCMD   => $SubCMD,
        Packages => \@Packages,
    );
}

sub _VersionClean {
    my (%Param) = @_;

    return 0 if !$Param{Version};
    return 0 if $Param{Version} eq 'undef';

    # replace all special characters with an dot
    $Param{Version} =~ s{ [_-] }{.}xmsg;

    my @VersionParts = split q{\.}, $Param{Version};

    my $CleanedVersion = '';
    for my $Count ( 0 .. 4 ) {
        $VersionParts[$Count] ||= 0;
        $CleanedVersion .= sprintf "%04d", $VersionParts[$Count];
    }

    return int $CleanedVersion;
}

sub _GetInstallCommand {
    my ($Module) = @_;
    my $CMD;
    my $SubCMD;
    my $Package;

    # returns the installation type e.g. ppm
    my $InstType     = $DistToInstType{$OSDist};
    my $OuputInstall = 1;

    if ($InstType) {

        # gets the install command for installation type
        # e.g. ppm install %s
        # default is the cpan install command
        # e.g. cpan %s
        $CMD    = $InstTypeToCMD{$InstType}->{CMD};
        $SubCMD = $InstTypeToCMD{$InstType}->{SubCMD};

        # gets the target package
        if (
            exists $Module->{InstTypes}->{$InstType}
            && !defined $Module->{InstTypes}->{$InstType}
        ) {
            # if we a hash key for the installation type but a undefined value
            # then we prevent the output for the installation command
            $OuputInstall = 0;
        }
        elsif ( $InstTypeToCMD{$InstType}->{UseModule} ) {

            # default is the cpan module name
            $Package = $Module->{Module};
        }
        else {
            # if the package name is defined for the installation type
            # e.g. ppm then we use this as package name
            $Package = $Module->{InstTypes}->{$InstType};
        }
    }

    return if !$OuputInstall;

    if ( !$CMD || !$Package ) {
        $CMD     = $InstTypeToCMD{default}->{CMD};
        $SubCMD  = $InstTypeToCMD{default}->{SubCMD};
        $Package = $Module->{Module};
    }

    return (
        CMD     => $CMD,
        SubCMD  => $SubCMD,
        Package => $Package,
    );
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut