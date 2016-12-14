# --
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Dorothea(dot)Doerffel(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::OutputFilter::OverrideQDataDisplayLimits;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check data
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };

    # create needed objects
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config
    $Self->{Config} = $ConfigObject->Get('Frontend::OverrideQDataDisplayLimits');
    return if !$Self->{Config};

    # get template
    my $Templatename = $Param{TemplateFile} || '';
    return 1 if !$Templatename;

    for my $Item ( keys %{ $Self->{Config} } ) {
        my @Restrictions = split /::/, $Item;

        # check possible templates
        return if ( $Templatename !~ /$Restrictions[0]/ );

        # get field possible names
        my $FieldRegexp = $Restrictions[1] || '';
        return if !$FieldRegexp;

        # get new string length
        my $NewLength = $Self->{Config}->{$Item};
        return if !$NewLength;

        # create HMTL
        my $SearchPattern = '(\[\%\s+(Translate\()?Data\.'.$FieldRegexp.'(\))?\s+\|\s+truncate\()(\d+)(\)\s+(\|.*?)?\s+\%\])';

        # replace...
        if ( ${ $Param{Data} } =~ m{ $SearchPattern }igxms )
        {
            ${ $Param{Data} } =~ s{ $SearchPattern }{ $1$NewLength$6 }igxms;
        }

    }

    return 1;
}

1;
