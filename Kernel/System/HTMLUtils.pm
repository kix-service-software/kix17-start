# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLUtils;

use strict;
use warnings;

use utf8;

use MIME::Base64;
use HTML::Entities qw(decode_entities encode_entities);
use HTML::Parser;
use HTML::Truncate;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Encode',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::HTMLUtils - creating and modifying html strings

=head1 SYNOPSIS

A module for creating and modifying html strings.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get debug level from parent
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

=item ToAscii()

convert a html string to an ascii string

    my $Ascii = $HTMLUtilsObject->ToAscii( String => $String );

=cut

sub ToAscii {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # turn on utf8 flag (bug#10970, bug#11596 and bug#12097)
    $Kernel::OM->Get('Kernel::System::Encode')->EncodeInput( \$Param{String} );

    # get length of line for forcing line breakes
    my $LineLength = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::TextAreaNote') || 78;

    # get parser object
    my $Parser = HTML::Parser->new(
        api_version        => 3,
        declaration_h      => [ \&_AsciiDeclarationHandler, 'self, text' ],
        start_h            => [ \&_AsciiTagStartHandler, 'self, tagname, attr, attrseq' ],
        end_h              => [ \&_AsciiTagEndHandler, 'self, tagname' ],
        text_h             => [ \&_AsciiTextHandler, 'self, text, is_cdata' ],
        empty_element_tags => 1,
        unbroken_text      => 1
    );

    # init variables for parser
    $Parser->{Ascii}         = '';
    $Parser->{Flag}          = {};
    $Parser->{Link}          = {
        Counter => 0,
        List    => [],
    };
    $Parser->{PreformatTags} = {
        'pre'  => 1,
        'code' => 1,
        'samp' => 1,
        'kbd'  => 1,
        'var'  => 1
    };
    $Parser->{SingleBreakStartTags} = {
        'br' => 1
    };
    $Parser->{DoubleBreakTags} = {
        'div'   => 1,
        'hr'    => 1,
        'p'     => 1,
        'table' => 1,
        'th'    => 1,
        'tr'    => 1
    };
    $Parser->{WhitespaceStartTags}  = {};
    $Parser->{SingleBreakEndTags}   = {};
    $Parser->{WhitespaceEndTags}    = {
        'td' => 1
    };

    # handle UTF7
    $Param{String} =~ s/[+]ADw-/</igsm;
    $Param{String} =~ s/[+]AD4-/>/igsm;

    # replace slash after tag with whitespace
    $Param{String} =~ s/(<[a-z]+)\/([a-z]+)/$1 $2/igsm;

    # parse string
    $Parser->parse( $Param{String} );
    $Parser->eof();

    # get new string from parser
    $Param{String} = $Parser->{Ascii};

    # append link list
    if ( @{ $Parser->{Link}->{List} } ) {
        $Param{String} .= "\n\n" . join( "\n", @{ $Parser->{Link}->{List} } );
    }

    # force line breaking
    if ( length $Param{String} > $LineLength ) {
        $Param{String} =~ s/(.{4,$LineLength})(?:\s|\z)/$1\n/gm;
    }

    return $Param{String};
}

sub _AsciiDeclarationHandler {
    my ( $Self, $Text ) = @_;

    # ignore declarations
    return;
}

sub _AsciiTagStartHandler {
    my ( $Self, $TagName, $Attributes, $AttributeSequence ) = @_;

    # check style element
    if ( lc($TagName) eq 'style' ) {
        if ( $Self->{Flag}->{Style} ) {
            # increment flag count
            $Self->{Flag}->{Style} += 1;
        }
        else {
            # init flag count
            $Self->{Flag}->{Style} = 1;
        }

        return;
    }

    # check preformat element
    if ( $Self->{PreformatTags}->{ lc($TagName) } ) {
        if ( $Self->{Flag}->{Preformat} ) {
            # increment flag count
            $Self->{Flag}->{Preformat} += 1;
        }
        else {
            # init flag count
            $Self->{Flag}->{Preformat} = 1;
        }

        return;
    }

    # check for lists
    if (
        lc($TagName) eq 'ol'
        || lc($TagName) eq 'ul'
    ) {
        if ( $Self->{Flag}->{List} ) {
            # increment flag level
            $Self->{Flag}->{List}->{Level} += 1;

            # push tagname to stack
            push( @{ $Self->{Flag}->{List}->{Stack} }, {
                Tag     => lc($TagName),
                Counter => 0,
            } );
        }
        else {
            # init flag level
            $Self->{Flag}->{List}->{Level} = 1;

            # init stack
            $Self->{Flag}->{List}->{Stack} = [ {
                Tag     => lc($TagName),
                Counter => 0,
            } ];

            if (
                $Self->{Flag}->{Preformat}
                || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
            ) {
                # append single line break
                $Self->{Ascii} .= "\n";
            }
        }

        return;
    }

    # check for blockquote
    if ( lc($TagName) eq 'blockquote' ) {
        if ( $Self->{Flag}->{Quote} ) {
            # increment flag level
            $Self->{Flag}->{Quote}->{QuoteLevel} += 1;
        }
        else {
            # init flag level of div element
            $Self->{Flag}->{Quote}->{DivLevel} = 0;

            # init flag level of quotation
            $Self->{Flag}->{Quote}->{QuoteLevel} = 1;

            # init stack
            $Self->{Flag}->{Quote}->{Stack} = [ ];
        }

        if (
            $Self->{Flag}->{Preformat}
            || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
        ) {
            # append single line break
            $Self->{Ascii} .= "\n";
        }

        return;
    }

    # replace li tags
    if ( lc($TagName) eq 'li' ) {
        # check for current list tag
        if ( $Self->{Flag}->{List} ) {
            # get current list element
            my $CurrentList = $Self->{Flag}->{List}->{Stack}->[-1];

            # increment list counter
            $CurrentList->{Counter} += 1;

            if (
                $Self->{Flag}->{Preformat}
                || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
            ) {
                # append single line break
                $Self->{Ascii} .= "\n";
            }

            # append indentation
            my $Indentation = 1;
            while ( $Indentation < $Self->{Flag}->{List}->{Level} ) {
                # append two white spaces
                $Self->{Ascii} .= '  ';

                # increment indenation index
                $Indentation += 1;
            }

            # check for ordered list
            if ( $CurrentList->{Tag} eq 'ol' ) {
                # append count
                $Self->{Ascii} .= $CurrentList->{Counter} . '. ';
            }
            # use unordered list
            else {
                # append dash
                $Self->{Ascii} .= ' - ';
            }
        }
        # use unordered list as fallback
        else {
            # append dash
            $Self->{Ascii} .= "\n" . ' - ';
        }

        return;
    }

    # process attributes
    ATTRIBUTE:
    for my $Attribute ( @{ $AttributeSequence } ) {
        # check for links
        if (
            lc($TagName) eq 'a'
            && lc( $Attribute ) eq 'href'
        ) {
            # increment counter
            $Self->{Link}->{Counter} += 1;

            # add href to link list with tag
            push( @{ $Self->{Link}->{List} }, '[' . $Self->{Link}->{Counter} . '] ' . $Attributes->{ $Attribute } );

            # append tag to text
            $Self->{Ascii} .= '[' . $Self->{Link}->{Counter} . ']';

            return;
        }
        # check for quotation
        if (
            lc($TagName) eq 'div'
            && lc( $Attribute ) eq 'type'
            && lc( $Attributes->{ $Attribute } ) eq 'cite'
        ) {
            if ( $Self->{Flag}->{Quote} ) {
                # increment flag level of div element
                $Self->{Flag}->{Quote}->{DivLevel} += 1;

                # increment flag level of quotation
                $Self->{Flag}->{Quote}->{QuoteLevel} += 1;

                # push level of div to stack
                push( @{ $Self->{Flag}->{Quote}->{Stack} }, $Self->{Flag}->{Quote}->{DivLevel} );
            }
            else {
                # init flag level of div element
                $Self->{Flag}->{Quote}->{DivLevel} = 1;

                # init flag level of quotation
                $Self->{Flag}->{Quote}->{QuoteLevel} = 1;

                # init stack
                $Self->{Flag}->{Quote}->{Stack} = [ 1 ];
            }

            if (
                $Self->{Flag}->{Preformat}
                || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
            ) {
                # append single line break
                $Self->{Ascii} .= "\n";
            }

            return;
        }
    }

    # check for div while quotation is active
    if (
        lc($TagName) eq 'div'
        && $Self->{Flag}->{Quote}
    ) {
        # increment flag level of div element
        $Self->{Flag}->{Quote}->{DivLevel} += 1;
    }

    # check for replacement with single line break
    if (
        $Self->{SingleBreakStartTags}->{ lc($TagName) }
        && (
            $Self->{Flag}->{Preformat}
            || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
        )
    ) {
        # append quotation at begin of line
        if (
            $Self->{Ascii} =~ m/(?:^$|\n\z)/
            && $Self->{Flag}->{Quote}
        ) {
            my $Quotation = 0;

            while ( $Quotation < $Self->{Flag}->{Quote}->{QuoteLevel} ) {
                # append quotation mark
                $Self->{Ascii} .= '> ';

                # increment quote index
                $Quotation += 1;
            }
        }

        # append single line break
        $Self->{Ascii} .= "\n";

        return;
    }

    # check for replacement with double line break
    if (
        $Self->{DoubleBreakTags}->{ lc($TagName) }
        && (
            $Self->{Flag}->{Preformat}
            || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
        )
    ) {
        # append quotation at begin of line
        if (
            $Self->{Ascii} =~ m/(?:^$|\n\z)/
            && $Self->{Flag}->{Quote}
        ) {
            my $Quotation = 0;

            while ( $Quotation < $Self->{Flag}->{Quote}->{QuoteLevel} ) {
                # append quotation mark
                $Self->{Ascii} .= '> ';

                # increment quote index
                $Quotation += 1;
            }
        }

        # append first line break
        $Self->{Ascii} .= "\n";

        return;
    }

    # check for replacement with white space
    if ( $Self->{WhitespaceStartTags}->{ lc($TagName) } ) {
        # append quotation at begin of line
        if (
            $Self->{Ascii} =~ m/(?:^$|\n\z)/
            && $Self->{Flag}->{Quote}
        ) {
            my $Quotation = 0;

            while ( $Quotation < $Self->{Flag}->{Quote}->{QuoteLevel} ) {
                # append quotation mark
                $Self->{Ascii} .= '> ';

                # increment quote index
                $Quotation += 1;
            }
        }

        # append white space
        $Self->{Ascii} .= ' ';

        return;
    }

    return;
}

sub _AsciiTagEndHandler {
    my ( $Self, $TagName ) = @_;

    # check style element
    if ( $Self->{Flag}->{Style} ) {
        if ( lc($TagName) eq 'style' ) {
            # reduce flag count
            $Self->{Flag}->{Style} -= 1;

            # delete flag if last tag was closed
            if ( $Self->{Flag}->{Style} == 0 ) {
                delete( $Self->{Flag}->{Style} );
            }

            return;
        }
    }

    # check preformat element
    if ( $Self->{Flag}->{Preformat} ) {
        # check for closing of preformat tag
        if ( $Self->{PreformatTags}->{ lc($TagName) } ) {
            # reduce flag count
            $Self->{Flag}->{Preformat} -= 1;

            # delete flag if last tag was closed
            if ( $Self->{Flag}->{Preformat} == 0 ) {
                delete( $Self->{Flag}->{Preformat} );
            }

            return;
        }
    }

    # check for lists
    if ( $Self->{Flag}->{List} ) {
        if (
            lc($TagName) eq 'ol'
            || lc($TagName) eq 'ul'
        ) {
            # reduce flag level
            $Self->{Flag}->{List}->{Level} -= 1;

            # pop tagname to stack
            pop( @{ $Self->{Flag}->{List}->{Stack} } );

            # delete flag if last tag was closed
            if ( $Self->{Flag}->{List}->{Level} == 0 ) {
                delete( $Self->{Flag}->{List} );

                if (
                    $Self->{Flag}->{Preformat}
                    || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
                ) {
                    # append single line break
                    $Self->{Ascii} .= "\n";
                }
            }

            return;
        }
    }

    # check for quotation
    if ( $Self->{Flag}->{Quote} ) {
        # check for ending blockquote
        if ( lc($TagName) eq 'blockquote' ) {
            # reduce flag level of quotation
            $Self->{Flag}->{Quote}->{QuoteLevel} -= 1;
        }
        # check for ending div
        elsif ( lc($TagName) eq 'div' ) {
            # check if current div is part of the stack
            if (
                $Self->{Flag}->{Quote}->{Stack}->[-1]
                && $Self->{Flag}->{Quote}->{DivLevel} eq $Self->{Flag}->{Quote}->{Stack}->[-1]
            ) {
                # reduce level of quotation
                $Self->{Flag}->{Quote}->{QuoteLevel} -= 1;

                # pop element from stack
                pop( @{ $Self->{Flag}->{Quote}->{Stack} } );
            }

            # reduce flag level of div elements
            $Self->{Flag}->{Quote}->{DivLevel} -= 1;
        }

        # delete flag if last tag was closed
        if ( $Self->{Flag}->{Quote}->{QuoteLevel} == 0 ) {
            delete( $Self->{Flag}->{Quote} );

            if (
                $Self->{Flag}->{Preformat}
                || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
            ) {
                # append single line break
                $Self->{Ascii} .= "\n";
            }
        }

        return;
    }

    # check for replacement with single line break
    if (
        $Self->{SingleBreakEndTags}->{ lc($TagName) }
        && (
            $Self->{Flag}->{Preformat}
            || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
        )
    ) {
        # append quotation at begin of line
        if (
            $Self->{Ascii} =~ m/(?:^$|\n\z)/
            && $Self->{Flag}->{Quote}
        ) {
            my $Quotation = 0;

            while ( $Quotation < $Self->{Flag}->{Quote}->{QuoteLevel} ) {
                # append quotation mark
                $Self->{Ascii} .= '> ';

                # increment quote index
                $Quotation += 1;
            }
        }

        # append single line break
        $Self->{Ascii} .= "\n";

        return;
    }

    # check for replacement with double line break
    if (
        $Self->{DoubleBreakTags}->{ lc($TagName) }
        && (
            $Self->{Flag}->{Preformat}
            || $Self->{Ascii} !~ m/(?:^$|\n\n\z)/
        )
    ) {
        # append quotation at begin of line
        if (
            $Self->{Ascii} =~ m/(?:^$|\n\z)/
            && $Self->{Flag}->{Quote}
        ) {
            my $Quotation = 0;

            while ( $Quotation < $Self->{Flag}->{Quote}->{QuoteLevel} ) {
                # append quotation mark
                $Self->{Ascii} .= '> ';

                # increment quote index
                $Quotation += 1;
            }
        }

        # append first line break
        $Self->{Ascii} .= "\n";

        return;
    }

    # check for replacement with white space
    if ( $Self->{WhitespaceEndTags}->{ lc($TagName) } ) {
        # append quotation at begin of line
        if (
            $Self->{Ascii} =~ m/(?:^$|\n\z)/
            && $Self->{Flag}->{Quote}
        ) {
            my $Quotation = 0;

            while ( $Quotation < $Self->{Flag}->{Quote}->{QuoteLevel} ) {
                # append quotation mark
                $Self->{Ascii} .= '> ';

                # increment quote index
                $Quotation += 1;
            }
        }

        # append white space
        $Self->{Ascii} .= ' ';

        return;
    }

    return;
}

sub _AsciiTextHandler {
    my ( $Self, $Text, $IsCDATA ) = @_;

    # ignore text while style flag is set
    if ( $Self->{Flag}->{Style} ) {
        return;
    }

    # cleanup text, if Preformat is not active
    if ( !$Self->{Flag}->{Preformat} ) {
        # remove leading whitespace
        $Text =~ s/^\s*//mg;

        # replace new lines with one space
        $Text =~ s/\n/ /gs;
        $Text =~ s/\r/ /gs;

        # replace multiple spaces with just one space
        $Text =~ s/[ ]{2,}/ /mg;
    }

    # append quotation at begin of line
    if (
        $Self->{Ascii} =~ m/(?:^$|\n\z)/
        && $Self->{Flag}->{Quote}
    ) {
        my $Quotation = 0;

        while ( $Quotation < $Self->{Flag}->{Quote}->{QuoteLevel} ) {
            # append quotation mark
            $Self->{Ascii} .= '> ';

            # increment quote index
            $Quotation += 1;
        }
    }

    # append decoded text
    $Self->{Ascii} .= decode_entities( $Text );

    return;
}

=item ToHTML()

convert an ascii string to a html string

    my $HTMLString = $HTMLUtilsObject->ToHTML( String => $String );

=cut

sub ToHTML {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # fix some bad stuff from opera and others
    $Param{String} =~ s/(\n\r|\r\r\n|\r\n)/\n/gs;

    $Param{String} =~ s/&/&amp;/g;
    $Param{String} =~ s/</&lt;/g;
    $Param{String} =~ s/>/&gt;/g;
    $Param{String} =~ s/"/&quot;/g;
    $Param{String} =~ s/(\n|\r)/<br\/>\n/g;
    $Param{String} =~ s/  /&nbsp;&nbsp;/g;

    return $Param{String};
}

=item DocumentComplete()

check and e. g. add <html> and <body> tags to given html string

    my $HTMLDocument = $HTMLUtilsObject->DocumentComplete(
        String  => $String,
        Charset => $Charset,
    );

=cut

sub DocumentComplete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String Charset)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    return $Param{String} if $Param{String} =~ /<html>/i;

    my $Css = $Kernel::OM->Get('Kernel::Config')->Get('Frontend::RichText::DefaultCSS')
        || 'font-size: 12px; font-family:Courier,monospace,fixed;';

    # Use the HTML5 doctype because it is compatible with HTML4 and causes the browsers
    #   to render the content in standards mode, which is more safe than quirks mode.
    my $Body = '<!DOCTYPE html><html><head>';
    $Body
        .= '<meta http-equiv="Content-Type" content="text/html; charset=' . $Param{Charset} . '"/>';
    $Body .= '</head><body style="' . $Css . '">' . $Param{String} . '</body></html>';
    return $Body;
}

=item DocumentStrip()

remove html document tags from string

    my $HTMLString = $HTMLUtilsObject->DocumentStrip(
        String  => $String,
    );

=cut

sub DocumentStrip {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Param{String} =~ s/^<\!DOCTYPE\s+HTML.+?>//gsi;
    $Param{String} =~ s/<head>.+?<\/head>//gsi;
    $Param{String} =~ s/<(html|body)(.*?)>//gsi;
    $Param{String} =~ s/<\/(html|body)>//gsi;

    return $Param{String};
}

=item DocumentCleanup()

perform some sanity checks on HTML content.

 -  Replace MS Word 12 <p|div> with class "MsoNormal" by using <br/> because
    it's not used as <p><div> (margin:0cm; margin-bottom:.0001pt;).

 -  Replace <blockquote> by using
    "<div style="border-style:solid;border-color:blue;border-width:0 0 0 1.5pt;padding:0cm 0cm 0cm 4.0pt" type="cite">"
    because of cross mail client and browser compatibility.

 -  If there is no HTML doctype present, inject the HTML5 doctype, because it is compatible with HTML4
    and causes the browsers to render the content in standards mode, which is safer.

    $HTMLBody = $HTMLUtilsObject->DocumentCleanup(
        String => $HTMLBody,
    );

=cut

sub DocumentCleanup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # If the string starts with <html> directly, inject the doctype
    $Param{String} =~ s{ \A \s* <html }{<!DOCTYPE html><html}gsmix;

    # remove <base> tags - see bug#8880
    $Param{String} =~ s{<base .*?>}{}xmsi;

    # replace MS Word 12 <p|div> with class "MsoNormal" by using <br/> because
    # it's not used as <p><div> (margin:0cm; margin-bottom:.0001pt;)
    $Param{String} =~ s{
        <p\s{1,3}class=(|"|')MsoNormal(|"|')(.*?)>(.+?)</p>
    }
    {
        $4 . '<br/>';
    }segxmi;

    $Param{String} =~ s{
        <div\s{1,3}class=(|"|')MsoNormal(|"|')(.*?)>(.+?)</div>
    }
    {
        $4 . '<br/>';
    }segxmi;

    # replace <blockquote> by using
    # "<div style="border-style:solid;border-color:blue;border-width:0 0 0 1.5pt;padding:0cm 0cm 0cm 4.0pt" type="cite">"
    # because of cross mail client and browser compatability
    my $Style = "border-style:solid;border-color:blue;border-width:0 0 0 1.5pt;padding:0cm 0cm 0cm 4.0pt";
    for ( 1 .. 10 ) {
        $Param{String} =~ s{
            <blockquote(.*?)>(.+?)</blockquote>
        }
        {
            "<div $1 style=\"$Style\">$2</div>";
        }segxmi;
    }

    return $Param{String};
}

=item LinkQuote()

URL link detections in HTML code, add "<a href" if missing

    my $HTMLWithLinks = $HTMLUtilsObject->LinkQuote(
        String    => $HTMLString,
        Target    => 'TargetName', # content of target="?", e. g. _blank
        TargetAdd => 1,            # add target="_blank" to all existing "<a href"
    );

also string ref is possible

    my $HTMLWithLinksRef = $HTMLUtilsObject->LinkQuote(
        String => \$HTMLStringRef,
    );

=cut

sub LinkQuote {
    my ( $Self, %Param ) = @_;

    my $String = $Param{String} || '';

    # check ref
    my $StringScalar;
    if ( !ref $String ) {
        $StringScalar = $String;
        $String       = \$StringScalar;

        # return if string is not a ref and it is empty
        return $StringScalar if !$StringScalar;
    }

    # add target to already existing url of html string
    if ( $Param{TargetAdd} ) {

        # find target
        my $Target = $Param{Target};
        if ( !$Target ) {
            $Target = '_blank';
        }

        # add target to existing "<a href"
        ${$String} =~ s{
            (<a\s{1,10})([^>]+)>
        }
        {
            my $Start = $1;
            my $Value = $2;
            if ( $Value !~ /href=/i || $Value =~ /target=/i ) {
                "$Start$Value>";
            }
            else {
                "$Start$Value target=\"$Target\">";
            }
        }egxsi;
    }

    my $Marker = "§" x 10;

    # Remove existing <a>...</a> tags and their content to be re-inserted later, this must not be quoted.
    # Also remove other tags to avoid quoting in tag parameters.
    my $Counter = 0;
    my %TagHash;
    ${$String} =~ s{
        (<a\s[^>]*?>[^>]*</a>|<[^>]+?>)
    }
    {
        my $Content = $1;
        my $Key     = "${Marker}TagHash-$Counter${Marker}";
        $TagHash{$Counter++} = $Content;
        $Key;
    }egxism;

    # Add <a> tags for URLs in the content.
    my $Target = '';
    if ( $Param{Target} ) {
        $Target = " target=\"$Param{Target}\"";
    }
    ${$String} =~ s{
        (                                          # $1 greater-than and less-than sign
            > | < | \s+ | §{10} |
            (?: &[a-zA-Z0-9]+; )                   # get html entities
        )
        (                                          # $2
            (?:                                    # http or only www
                (?: (?: http s? | ftp ) :\/\/) |   # http://,https:// and ftp://
                (?: (?: www | ftp ) \.)            # www. and ftp.
            )
        )
        (                                          # $3
            (?: [a-z0-9\-]+ \. )*                  # get subdomains, optional
            [a-z0-9\-]+                            # get top level domain
            (?:                                    # optional port number
                [:]
                [0-9]+
            )?
            (?:                                    # file path element
                [\/\.]
                | [a-zA-Z0-9\-_=%]
            )*
            (?:                                    # param string
                [\?]                               # if param string is there, "?" must be present
                [a-zA-Z0-9&;=%\-_:\.\/]*           # param string content, this will also catch entities like &amp;
            )?
            (?:                                    # link hash string
                [\#]                               #
                [a-zA-Z0-9&;=%\-_:\.\/]*           # hash string content, this will also catch entities like &amp;
            )?
        )
        (?=                                        # $4
            (?:
                [\?,;!\.\)] (?: \s | $ )           # \)\s this construct is because of bug# 2450
                | \"
                | \]
                | \s+
                | '
                | >                               # greater-than and less-than sign
                | <                               # "
                | (?: &[a-zA-Z0-9]+; )+            # html entities
                | $                                # bug# 2715
            )
            | §{10}                                # ending TagHash
        )
    }
    {
        my $Start    = $1;
        my $Protocol = $2;
        my $Link     = $3;
        my $End      = $4 || '';

        # there may different links for href and link body
        my $HrefLink;
        my $DisplayLink;

        if ( $Protocol =~ m{\A ( http | https | ftp ) : \/ \/ }xi ) {
            $DisplayLink = $Protocol . $Link;
            $HrefLink    = $DisplayLink;
        }
        else {
            if ($Protocol =~ m{\A ftp }smx ) {
                $HrefLink = 'ftp://';
            }
            else {
                $HrefLink = 'http://';
            }

            if ( $Protocol ) {
                $HrefLink   .= $Protocol;
                $DisplayLink = $Protocol;
            }

            $DisplayLink .= $Link;
            $HrefLink    .= $Link;
        }
        $Start . "<a href=\"$HrefLink\"$Target title=\"$HrefLink\">$DisplayLink<\/a>" . $End;
    }egxism;

    # Re-add previously removed tags.
    ${$String} =~ s{${Marker}TagHash-(\d+)${Marker}}{$TagHash{$1}}egsxim;

    # check ref && return result like called
    if ($StringScalar) {
        return ${$String};
    }
    return $String;
}

=item Safety()

To remove/strip active html tags/addons (javascript, applets, embeds and objects)
from html strings.

    my %Safe = $HTMLUtilsObject->Safety(
        String         => $HTMLString,
        NoApplet       => 1,
        NoObject       => 1,
        NoEmbed        => 1,
        NoSVG          => 1,
        NoImg          => 1,
        NoIntSrcLoad   => 0,
        NoExtSrcLoad   => 1,
        NoJavaScript   => 1,
        ReplacementStr => 'string',          # optional, string to show instead of applet, object, embed, svg and img tags
    );

also string ref is possible

    my %Safe = $HTMLUtilsObject->Safety(
        String       => \$HTMLStringRef,
        NoApplet     => 1,
        NoObject     => 1,
        NoEmbed      => 1,
        NoSVG        => 1,
        NoImg        => 1,
        NoIntSrcLoad => 0,
        NoExtSrcLoad => 1,
        NoJavaScript => 1,
    );

returns

    my %Safe = (
        String  => $HTMLString, # modified html string (scalar or ref)
        Replace => 1,           # info if something got replaced
    );

=cut

sub Safety {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $String = $Param{String} || '';

    # check ref
    my $StringScalar;
    my $StringIsRef = 0;
    if ( ref $String ) {
        $String = $$String;
        $StringIsRef  = 1;
    }

    # get parser object
    my $Parser = HTML::Parser->new(
        api_version        => 3,
        declaration_h      => [ \&_SafetyDeclarationHandler, 'self, text' ],
        comment_h          => [ \&_SafetyCommentHandler, 'self, text' ],
        start_h            => [ \&_SafetyTagStartHandler, 'self, tagname, attr, attrseq' ],
        end_h              => [ \&_SafetyTagEndHandler, 'self, tagname' ],
        text_h             => [ \&_SafetyTextHandler, 'self, text, is_cdata' ],
        empty_element_tags => 1,
        unbroken_text      => 1
    );

    # init variables for parser
    $Parser->{Safety} = {
        'String'  => '',
        'Replace' => 0,
    };
    $Parser->{Config} = {
        NoApplet       => $Param{NoApplet},
        NoObject       => $Param{NoObject},
        NoEmbed        => $Param{NoEmbed},
        NoSVG          => $Param{NoSVG},
        NoImg          => $Param{NoImg},
        NoIntSrcLoad   => $Param{NoIntSrcLoad},
        NoExtSrcLoad   => $Param{NoExtSrcLoad},
        NoJavaScript   => $Param{NoJavaScript},
        ReplacementStr => $Param{ReplacementStr} // '',
    };
    $Parser->{Flag}         = {};
    $Parser->{TagMap}       = {
        'JavaScript' => 'script',
        'Applet'     => 'applet',
        'Object'     => 'object',
        'SVG'        => 'svg',
        'Img'        => 'img',
        'Embed'      => 'embed'
    };
    $Parser->{VoidElements} = {
        'area'    => 1,
        'base'    => 1,
        'br'      => 1,
        'col'     => 1,
        'command' => 1,
        'embed'   => 1,
        'hr'      => 1,
        'img'     => 1,
        'input'   => 1,
        'keygen'  => 1,
        'link'    => 1,
        'meta'    => 1,
        'param'   => 1,
        'source'  => 1,
        'track'   => 1,
        'wbr'     => 1
    };

    # handle UTF7
    $String =~ s/[+]ADw-/</igsm;
    $String =~ s/[+]AD4-/>/igsm;

    # replace slash after tag with whitespace
    $String =~ s/(<[a-z]+)\/([a-z]+)/$1 $2/igsm;

    # parse string
    $Parser->parse( $String );
    $Parser->eof();

    # check ref && return result like called
    if ( $StringIsRef ) {
        $Parser->{Safety}->{String} = \$Parser->{Safety}->{String};
    }
    return %{$Parser->{Safety}};
}

sub _SafetyDeclarationHandler {
    my ( $Self, $Text ) = @_;

    # append to safety string
    $Self->{Safety}->{String} .= $Text;

    return;
}

sub _SafetyCommentHandler {
    my ( $Self, $Text ) = @_;

    # remember replacement, conditional comments can contain unsecure code
    $Self->{Safety}->{Replace} = 1;

    return;
}

sub _SafetyTagStartHandler {
    my ( $Self, $TagName, $Attributes, $AttributeSequence ) = @_;

    # cleanup tag name
    $TagName = lc($TagName);
    $TagName =~ s/[^a-z0-9]+//g;

    # check for further opening of style tag for expression check
    if (
        $Self->{Flag}->{StyleExpression}
        && $TagName eq 'style'
    ) {
        $Self->{Flag}->{StyleExpression} += 1;
        return;
    }

    # check for open flagged tag
    if ( $Self->{Flag}->{TagName} ) {
        # check for further opening of flagged tag
        if ( $TagName eq $Self->{Flag}->{TagName} ) {
            $Self->{Flag}->{TagCount} += 1;
        }

        return;
    }

    # check for mapped tags
    for my $Config ( keys( %{ $Self->{TagMap} } ) ) {
        if (
            $Self->{Config}->{ 'No' . $Config }
            && $TagName eq $Self->{TagMap}->{ $Config }
        ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;

            # check for non-void elements
            if ( !$Self->{VoidElements}->{ $TagName } ) {
                # flag tag
                $Self->{Flag}->{TagName}  = $TagName;
                $Self->{Flag}->{TagCount} = 1;
            }

            # add replacement string
            $Self->{Safety}->{String} .= $Self->{Config}->{ReplacementStr};

            return;
        }
    }

    # open tag
    my $String = '<' . $TagName;

    # process attributes
    ATTRIBUTE:
    for my $Attribute ( @{ $AttributeSequence } ) {
        # check for HTTP redirects
        if (
            $TagName eq 'meta'
            && lc( $Attribute ) eq 'http-equiv'
            && lc( $Attributes->{ $Attribute } )  eq 'refresh'
        ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;
            return;
        }

        # cleanup javascript code
        if ( $Self->{Config}->{NoJavaScript} ) {
            # check for link and style tag
            if (
                $TagName eq 'link'
                || $TagName eq 'style'
            ) {
                # check for type 'text/javascript'
                if (
                    lc( $Attribute ) eq 'type'
                    && lc( $Attributes->{ $Attribute } ) eq 'text/javascript'
                ) {
                    # remember replacement
                    $Self->{Safety}->{Replace} = 1;

                    # flag tag
                    $Self->{Flag}->{TagName}  = $TagName;
                    $Self->{Flag}->{TagCount} = 1;

                    return;
                }
            }

            # check for animate and set tag
            if (
                $TagName eq 'animate'
                || $TagName eq 'set'
            ) {
                my $CheckValue = lc( $Attributes->{ $Attribute } );
                $CheckValue =~ s/[^a-z1-9:;=()]+//g;
                if ( $CheckValue =~ m/^javascript.+/ ) {
                    # remember replacement
                    $Self->{Safety}->{Replace} = 1;

                    # flag tag
                    $Self->{Flag}->{TagName}  = $TagName;
                    $Self->{Flag}->{TagCount} = 1;

                    return;
                }
            }

            # check for 'on'-attributes
            if ( $Attribute =~ m/^on.+$/i ) {
                # remember replacement
                $Self->{Safety}->{Replace} = 1;

                next ATTRIBUTE;
            }

            # check several attributes for javascript code
            if (
                lc( $Attribute ) eq 'background'
                || lc( $Attribute ) eq 'url'
                || lc( $Attribute ) eq 'src'
                || lc( $Attribute ) eq 'dynsrc'
                || lc( $Attribute ) eq 'lowsrc'
                || lc( $Attribute ) eq 'href'
                || lc( $Attribute ) eq 'xlink:href'
                || lc( $Attribute ) eq 'action'
                || lc( $Attribute ) eq 'formaction'
            ) {

                # prepare checkvalue
                my $CheckValue = lc( $Attributes->{ $Attribute } );
                $CheckValue =~ s/[^a-z1-9:;=()]+//g;
                if (
                    $CheckValue =~ m/^javascript.+/
                    || $CheckValue =~ m/^livescript.+/
                    || $CheckValue =~ m/^vbscript.+/
                ) {
                    # remember replacement
                    $Self->{Safety}->{Replace} = 1;

                    next ATTRIBUTE;
                }
            }

            # check for expression function in style attribute
            if ( lc( $Attribute ) eq 'style' ) {
                # prepare attribute value
                my $AttributeValue = $Attributes->{ $Attribute };
                $AttributeValue =~ s/\/\*.*?\*\///g;

                if (
                    $AttributeValue =~ m/expression\(/i
                    || $AttributeValue =~ m/javascript/i
                ) {
                    # remember replacement
                    $Self->{Safety}->{Replace} = 1;

                    next ATTRIBUTE;
                }
            }
        }

        # cleanup internal load statements
        if ( $Self->{Config}->{NoIntSrcLoad} ) {
            # check for url function in style attribute
            if (
                lc( $Attribute ) eq 'style'
                && $Attributes->{ $Attribute } =~ m/url\(/i
            ) {
                # remember replacement
                $Self->{Safety}->{Replace} = 1;

                next ATTRIBUTE;
            }

            # check for src and poster attribute
            if (
                lc( $Attribute ) eq 'poster'
                || lc( $Attribute ) eq 'src'
            ) {
                # remember replacement
                $Self->{Safety}->{Replace} = 1;

                next ATTRIBUTE;
            }
        }

        # cleanup external load statements
        if ( $Self->{Config}->{NoExtSrcLoad} ) {
            # check for url in style attribute
            if (
                lc( $Attribute ) eq 'style'
                && $Attributes->{ $Attribute } =~ m/(?:http|ftp|https):\/\//i
            ) {
                # remember replacement
                $Self->{Safety}->{Replace} = 1;

                next ATTRIBUTE;
            }

            # check for url in src and poster attribute
            if (
                (
                    lc( $Attribute ) eq 'poster'
                    || lc( $Attribute ) eq 'src'
                )
                && $Attributes->{ $Attribute } =~ m/(?:http|ftp|https):\/\//i
            ) {
                # remember replacement
                $Self->{Safety}->{Replace} = 1;

                next ATTRIBUTE;
            }
        }

        # check for iframe with srcdoc attribute
        if (
            $TagName eq 'iframe'
            && lc( $Attribute ) eq 'srcdoc'
        ) {
            # call safety function for srcdoc
            my %Safety = $Kernel::OM->Get('Kernel::System::HTMLUtils')->Safety(
                %{ $Self->{Config} },
                String => $Attributes->{ $Attribute },
            );
            if ( $Safety{Replace} ) {
                # remember replacement
                $Self->{Safety}->{Replace} = 1;

                # replace attribute value
                $Attributes->{ $Attribute } = $Safety{String};
            }
        }

        # prepare attribute value
        my $AttributeValue = encode_entities( $Attributes->{ $Attribute } );

        # check for changes
        if ( $AttributeValue ne $Attributes->{ $Attribute } ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;
        }

        # add attribute with value
        $String .= ' ' . $Attribute . '="' . $AttributeValue . '"';
    }

    # flag check for style expression
    if ( $TagName eq 'style' ) {
        $Self->{Flag}->{StyleExpression} = 1;
    }

    # special handling for void elements
    if ( $Self->{VoidElements}->{ $TagName } ) {
        $String .= ' /';
    }

    # close tag
    $String .= '>';

    # append to safety string
    $Self->{Safety}->{String} .= $String;

    return;
}

sub _SafetyTagEndHandler {
    my ( $Self, $TagName ) = @_;

    # cleanup tag name
    $TagName = lc($TagName);
    $TagName =~ s/[^a-z0-9]+//g;

    # ignore void elements
    if ( $Self->{VoidElements}->{ $TagName } ) {
        return;
    }

    # check style tag for expression function
    if ( $Self->{Flag}->{StyleExpression} ) {
        # check for closing of style tag for expression check
        if ( $TagName eq 'style' ) {
            $Self->{Flag}->{StyleExpression} -= 1;
            if ( $Self->{Flag}->{StyleExpression} == 0 ) {
                delete( $Self->{Flag}->{StyleExpression} );
            }
        }
    }

    # check for open flagged tag
    if ( $Self->{Flag}->{TagName} ) {
        # check for closing of flagged tag
        if ( $TagName eq $Self->{Flag}->{TagName} ) {
            $Self->{Flag}->{TagCount} -= 1;
            if ( $Self->{Flag}->{TagCount} == 0 ) {
                delete( $Self->{Flag}->{TagName} );
                delete( $Self->{Flag}->{TagCount} );
            }
        }
        return;
    }

    # check for mapped tags
    for my $Config ( keys( %{ $Self->{TagMap} } ) ) {
        if (
            $Self->{Config}->{ 'No' . $Config }
            && $TagName eq $Self->{TagMap}->{ $Config }
        ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;

            return;
        }
    }

    # append to safety string
    $Self->{Safety}->{String} .= '</' . $TagName . '>';

    return;
}

sub _SafetyTextHandler {
    my ( $Self, $Text, $IsCDATA ) = @_;

    # check style tag
    if ( $Self->{Flag}->{StyleExpression} ) {
        # for expression function
        if ( $Text =~ m/expression\(/i ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;

            return;
        }

        # for javascript
        my $CheckValue = lc( $Text );
        $CheckValue =~ s/[^a-z1-9:;=()@]+//g;
        if ( $CheckValue =~ m/javascript/ ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;

            return;
        }

        # for @import
        if ( $CheckValue =~ m/^\@import/i ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;

            return;
        }
    }

    # check style tag for expression function
    if ( $Self->{Flag}->{StyleExpression} ) {
        if ( $Text =~ m/expression\(/i ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;

            return;
        }
    }

    # check for open flagged tag
    if ( $Self->{Flag}->{TagName} ) {
        return;
    }

    # append to safety string
    if ( $IsCDATA ) {
        $Self->{Safety}->{String} .= $Text;
    }
    # encode text before appending
    else {
        # encode text
        my $EncodedText = encode_entities( decode_entities( $Text ) );

        # check for changes
        if ( $EncodedText ne $Text ) {
            # remember replacement
            $Self->{Safety}->{Replace} = 1;
        }
        $Self->{Safety}->{String} .= $EncodedText;
    }

    return;
}

=item EmbeddedImagesExtract()

extracts embedded images with data-URLs from an HTML document.

    $HTMLUtilsObject->EmbeddedImagesExtract(
        DocumentRef    => \$Body,
        AttachmentsRef => \@Attachments,
    );

Returns nothing. If embedded images were found, these will be appended
to the attachments list, and the image data URL will be replaced with a
cid: URL in the document.

=cut

sub EmbeddedImagesExtract {
    my ( $Self, %Param ) = @_;

    if ( ref $Param{DocumentRef} ne 'SCALAR' || !defined ${ $Param{DocumentRef} } ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need DocumentRef!"
        );
        return;
    }
    if ( ref $Param{AttachmentsRef} ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need AttachmentsRef!"
        );
        return;
    }

    my $FQDN = $Kernel::OM->Get('Kernel::Config')->Get('FQDN');
    ${ $Param{DocumentRef} } =~ s{(src=")(data:image/)(png|gif|jpg|jpeg|bmp)(;base64,)(.+?)(")}{

        my $Base64String = $5;

        my $FileName     = 'pasted-' . time() . '-' . int(rand(1000000)) . '.' . $3;
        my $ContentType  = "image/$3; name=\"$FileName\"";
        my $ContentID    = 'pasted.' . time() . '.' . int(rand(1000000)) . '@' . $FQDN;

        my $AttachmentData = {
            Content     => decode_base64($Base64String),
            ContentType => $ContentType,
            ContentID   => $ContentID,
            Filename    => $FileName,
            Disposition => 'inline',
        };
        push @{$Param{AttachmentsRef}}, $AttachmentData;

        # compose new image tag
        $1 . "cid:$ContentID" . $6

    }egxi;

    return 1;
}

=item HTMLTruncate()

DEPRECATED: This function will be removed in further versions of KIX

truncate an HTML string to certain amount of characters without loosing the HTML tags, the resulting
string will contain the specified amount of text characters plus the HTML tags, and ellipsis string.

special characters like &aacute; in HTML code are considered as just one character.

    my $HTML = $HTMLUtilsObject->HTMLTruncate(
        String   => $String,
        Chars    => 123,
        Ellipsis => '...',              # optional (defaults to HTML &#8230;) string to indicate
                                        #    that the HTML was truncated until that point
        UTF8Mode => 0,                  # optional 1 or 0 (defaults to 0)
        OnSpace  => 0,                  # optional 1 or 0 (defaults to 0) if enabled, prevents to
                                        #    truncate in a middle of a word, but in the space before
    );

returns

    $HTML => 'some HTML code'           # or false in case of a failure

=cut

sub HTMLTruncate {
    my ( $Self, %Param ) = @_;

    # check needed
    for my $Needed (qw(String Chars)) {

        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # translate params for compatibility reasons with HTML::Truncate
    my %CompatibilityParams = (
        'utf8_mode' => $Param{UTF8Mode} ? 1 : 0,
        'on_space'  => $Param{OnSpace}  ? 1 : 0,
        'chars'     => $Param{Chars},
        'repair'    => 1,
    );

    if ( defined $Param{Ellipsis} ) {
        $CompatibilityParams{ellipsis} = $Param{Ellipsis};
    }

    # create new HTML truncate object (with the specified options)
    my $HTMLTruncateObject;
    eval {
        $HTMLTruncateObject = HTML::Truncate->new(%CompatibilityParams);
    };

    if ( !$HTMLTruncateObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not create HTMLTruncateObject: $@",
        );
        return;
    }

    # sanitize the string
    my %Safe = $Self->Safety(
        String         => $Param{String},
        NoApplet       => 1,
        NoObject       => 1,
        NoEmbed        => 1,
        NoSVG          => 1,
        NoImg          => 1,
        NoIntSrcLoad   => 1,
        NoExtSrcLoad   => 1,
        NoJavaScript   => 1,
        ReplacementStr => '✂︎',
    );

    # truncate the HTML input string
    my $Result;
    if ( !eval { $Result = $HTMLTruncateObject->truncate( $Safe{String} ) } ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Truncating string failed: ' . $@,
        );

        return;
    }

    return $Result;
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
