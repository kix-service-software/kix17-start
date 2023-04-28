package Locale::Codes::LangFam;
# Copyright (C) 2001      Canon Research Centre Europe (CRE).
# Copyright (C) 2002-2023 Neil Bowers
# Copyright (c) 2010-2023 Sullivan Beck
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

# This file was automatically generated.  Any changes to this file will
# be lost the next time 'gen_mods' is run.
#    Generated on: Thu Sep  1 10:01:11 EDT 2022

use strict;
use warnings;
require 5.006;
use Exporter qw(import);

our($VERSION,@EXPORT);
$VERSION   = '3.72';

################################################################################
use if $] >= 5.027007, 'deprecate';
use Locale::Codes;
use Locale::Codes::Constants;

@EXPORT    = qw(
                code2langfam
                code2langfams
                langfam2code
                all_langfam_codes
                all_langfam_names
                langfam_code2code
               );
push(@EXPORT,@Locale::Codes::Constants::CONSTANTS_LANGFAM);

our $obj = new Locale::Codes('langfam');
$obj->show_errors(0);

sub show_errors {
   my($val) = @_;
   $obj->show_errors($val);
}

sub code2langfam {
   return $obj->code2name(@_);
}

sub code2langfams {
   return $obj->code2names(@_);
}

sub langfam2code {
   return $obj->name2code(@_);
}

sub langfam_code2code {
   return $obj->code2code(@_);
}

sub all_langfam_codes {
   return $obj->all_codes(@_);
}

sub all_langfam_names {
   return $obj->all_names(@_);
}

sub rename_langfam {
   return $obj->rename_code(@_);
}

sub add_langfam {
   return $obj->add_code(@_);
}

sub delete_langfam {
   return $obj->delete_code(@_);
}

sub add_langfam_alias {
   return $obj->add_alias(@_);
}

sub delete_langfam_alias {
   return $obj->delete_alias(@_);
}

sub rename_langfam_code {
   return $obj->replace_code(@_);
}

sub add_langfam_code_alias {
   return $obj->add_code_alias(@_);
}

sub delete_langfam_code_alias {
   return $obj->delete_code_alias(@_);
}

1;
