package Locale::Codes::Country;
# Copyright (C) 2001      Canon Research Centre Europe (CRE).
# Copyright (C) 2002-2009 Neil Bowers
# Copyright (c) 2010-2021 Sullivan Beck
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

# This file was automatically generated.  Any changes to this file will
# be lost the next time 'gen_mods' is run.
#    Generated on: Wed Dec  1 13:43:56 EST 2021

use strict;
use warnings;
require 5.006;
use Exporter qw(import);

our($VERSION,@EXPORT);
$VERSION   = '3.69';

################################################################################
use if $] >= 5.027007, 'deprecate';
use Locale::Codes;
use Locale::Codes::Constants;

@EXPORT    = qw(
                code2country
                code2countrys
                country2code
                all_country_codes
                all_country_names
                country_code2code
               );
push(@EXPORT,@Locale::Codes::Constants::CONSTANTS_COUNTRY);

our $obj = new Locale::Codes('country');
$obj->show_errors(0);

sub show_errors {
   my($val) = @_;
   $obj->show_errors($val);
}

sub code2country {
   return $obj->code2name(@_);
}

sub code2countrys {
   return $obj->code2names(@_);
}

sub country2code {
   return $obj->name2code(@_);
}

sub country_code2code {
   return $obj->code2code(@_);
}

sub all_country_codes {
   return $obj->all_codes(@_);
}

sub all_country_names {
   return $obj->all_names(@_);
}

sub rename_country {
   return $obj->rename_code(@_);
}

sub add_country {
   return $obj->add_code(@_);
}

sub delete_country {
   return $obj->delete_code(@_);
}

sub add_country_alias {
   return $obj->add_alias(@_);
}

sub delete_country_alias {
   return $obj->delete_alias(@_);
}

sub rename_country_code {
   return $obj->replace_code(@_);
}

sub add_country_code_alias {
   return $obj->add_code_alias(@_);
}

sub delete_country_code_alias {
   return $obj->delete_code_alias(@_);
}

1;
