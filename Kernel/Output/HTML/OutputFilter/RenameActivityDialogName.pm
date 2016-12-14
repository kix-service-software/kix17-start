# --
# Kernel/Output/HTML/OutputFilter/RenameActivityDialogName.pm
# Output filter to rename "ActivityDialogbutton"
# BPMX Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Sebastian(dot)Reiss(at)cape(dash)it(dot)de
# * Frank(dot)Jacquemin(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
package Kernel::Output::HTML::OutputFilter::RenameActivityDialogName;

use strict;
use warnings;
use utf8;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::ProcessManagement::DB::ActivityDialog',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBActivityDialogObject}
        = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::ActivityDialog');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    return if !$Param{Data};
    return if ref $Param{Data} ne 'SCALAR';
    return if !${ $Param{Data} };

    # get configuration
    $Self->{Config} = $Self->{ConfigObject}->Get('Frontend::Output::FilterElementPost');
    my $SubtitutionName = $Self->{Config}->{RenameActivityDialogName}->{DialogLabelAttribute}
        || 'DescriptionShort';

    # get list ActivityDialogs
    my $ListActivityDialogs = $Self->{DBActivityDialogObject}->ActivityDialogList(
        UseEntities => 1,
        UserID      => 1,
    );

    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # replace all available AD dialog names by SubstitutionAttribute...
    for my $CurrADKey ( sort keys %{$ListActivityDialogs} ) {
        my $SearchPattern = '(<a[^>]+ActivityDialogEntityID=' . $CurrADKey . '[^>]+>)[^<]+';
        if ( ${ $Param{Data} } =~ m{ $SearchPattern }ixms ) {
            my $ActivityDialogData = $Self->{DBActivityDialogObject}->ActivityDialogGet(
                EntityID => $CurrADKey,
                UserID   => 1,
            );
            my $ReplaceData = $LayoutObject->{LanguageObject}
                ->Translate( $ActivityDialogData->{Config}->{$SubtitutionName} );
            ${ $Param{Data} } =~ s{ $SearchPattern }{ $1$ReplaceData }ixms;
        }
    }

    return 1;
}
1;