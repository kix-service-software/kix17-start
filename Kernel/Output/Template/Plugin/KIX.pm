# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::Template::Plugin::KIX;

use strict;
use warnings;

use base qw(Template::Plugin);

use Scalar::Util;

our $ObjectManagerDisabled = 1;

use Kernel::System::ObjectManager;

=head1 NAME

Kernel::Output::Template::Plugin::KIX - Template Toolkit extension plugin

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

this plugin registers a few filters and functions in Template::Toolkit.

These extensions have names starting with an uppercase letter so that
you can distinguish them from the builtins of Template::Toolkit which
are always lowercase.

Filters:

    [% Data.MyData  | Translate %]              - Translate to user language.

    [% Data.Created | Localize("TimeLong") %]   - Format DateTime string according to user's locale.
    [% Data.Created | Localize("TimeShort") %]  - Format DateTime string according to user's locale, without seconds.
    [% Data.Created | Localize("Date") %]       - Format DateTime string according to user's locale, only date.

    [% Data.Complex | Interpolate %]            - Treat Data.Complex as a TT template and parse it.

    [% Data.Complex | JSON %]                   - Convert Data.Complex into a JSON string.

Functions:

    [% Translate("Test string for %s", "Documentation") %]  - Translate text, with placeholders.

    [% Config("Home") %]    - Get SysConfig configuration value.

    [% Env("Baselink") %]   - Get environment value of LayoutObject.

=cut

sub new {
    my ( $Class, $Context, @Params ) = @_;

    # Produce a weak reference to the LayoutObject and use that in the filters.
    # We do this because there could be more than one LayoutObject in the process,
    #   so we don't fetch it from the ObjectManager.
    #
    # Don't use $Context in the filters as that creates a circular dependency.
    my $LayoutObject = $Context->{LayoutObject};
    Scalar::Util::weaken($LayoutObject);

    my $ConfigFunction = sub {
        return $Kernel::OM->Get('Kernel::Config')->Get(@_);
    };

    my $EnvFunction = sub {
        return $LayoutObject->{EnvRef}->{ $_[0] };
    };

    my $TranslateFunction = sub {
        return $LayoutObject->{LanguageObject}->Translate(@_);
    };

    my $TranslateFilterFactory = sub {
        my ( $FilterContext, @Parameters ) = @_;
        return sub {
            $LayoutObject->{LanguageObject}->Translate( $_[0], @Parameters );
        };
    };

    my $LocalizeFunction = sub {
        my $Format = $_[1];
        if ( $Format eq 'TimeLong' ) {
            return $LayoutObject->{LanguageObject}->FormatTimeString( $_[0], 'DateFormat' );
        }
        elsif ( $Format eq 'TimeShort' ) {
            return $LayoutObject->{LanguageObject}->FormatTimeString( $_[0], 'DateFormat', 'NoSeconds' );
        }
        elsif ( $Format eq 'Date' ) {
            return $LayoutObject->{LanguageObject}->FormatTimeString( $_[0], 'DateFormatShort' );
        }
        return;
    };

    my $LocalizeFilterFactory = sub {
        my ( $FilterContext, @Parameters ) = @_;
        my $Format = $Parameters[0] || 'TimeLong';

        return sub {
            if ( $Format eq 'TimeLong' ) {
                return $LayoutObject->{LanguageObject}->FormatTimeString( $_[0], 'DateFormat' );
            }
            elsif ( $Format eq 'TimeShort' ) {
                return $LayoutObject->{LanguageObject}->FormatTimeString( $_[0], 'DateFormat', 'NoSeconds' );
            }
            elsif ( $Format eq 'Date' ) {
                return $LayoutObject->{LanguageObject}->FormatTimeString( $_[0], 'DateFormatShort' );
            }
            return;
        };
    };

    # This filter processes the data as a template and replaces any contained TT tags.
    # This is expensive and potentially dangerous, use with caution!
    my $InterpolateFunction = sub {

        # Don't parse if there are no TT tags present!
        if ( index( $_[0], '[%' ) == -1 ) {
            return $_[0];
        }
        return $Context->include( \$_[0] );
    };

    my $InterpolateFilterFactory = sub {
        my ( $FilterContext, @Parameters ) = @_;
        return sub {

            # Don't parse if there are no TT tags present!
            if ( index( $_[0], '[%' ) == -1 ) {
                return $_[0];
            }
            return $FilterContext->include( \$_[0] );
        };
    };

    my $JSONFunction = sub {
        return $LayoutObject->JSONEncode( Data => $_[0] );
    };

    my $JSONFilter = sub {
        return $LayoutObject->JSONEncode( Data => $_[0] );
    };

    my $JSONHTMLFunction = sub {
        return $LayoutObject->JSONEncode(
            Data        => $_[0],
            EscapeSlash => 1
        );
    };

    my $JSONHTMLFilter = sub {
        return $LayoutObject->JSONEncode(
            Data        => $_[0],
            EscapeSlash => 1
        );
    };

    $Context->stash()->set( 'Config',      $ConfigFunction );
    $Context->stash()->set( 'Env',         $EnvFunction );
    $Context->stash()->set( 'Translate',   $TranslateFunction );
    $Context->stash()->set( 'Localize',    $LocalizeFunction );
    $Context->stash()->set( 'Interpolate', $InterpolateFunction );
    $Context->stash()->set( 'JSON',        $JSONFunction );
    $Context->stash()->set( 'JSONHTML',    $JSONHTMLFunction );

    $Context->define_filter( 'Translate',   [ $TranslateFilterFactory,   1 ] );
    $Context->define_filter( 'Localize',    [ $LocalizeFilterFactory,    1 ] );
    $Context->define_filter( 'Interpolate', [ $InterpolateFilterFactory, 1 ] );
    $Context->define_filter( 'JSON', $JSONFilter );
    $Context->define_filter( 'JSONHTML', $JSONHTMLFilter );

    return bless {
        _CONTEXT => $Context,
        _PARAMS  => \@Params,
    }, $Class;
}


1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
