# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::QuickLinkAJAXHandler;

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

    # create needed objects
    my $LinkObject  = $Kernel::OM->Get('Kernel::System::LinkObject');
    my $QuickLinkObject = $Kernel::OM->Get('Kernel::System::QuickLink');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');

    my $Result;

    # add link type for quick link
    if ( $Self->{Subaction} eq 'CreateLinkTypeList' ) {

        # get params
        for (qw(SourceObject TargetObject)) {
            if ( $ParamObject->GetParam( Param => $_ ) ne 'undefined' ) {
                $Param{$_} = $ParamObject->GetParam( Param => $_ ) || '';
            }
            else {
                $Param{$_} = '';
            }
        }

        my @Type = split( '::', $Param{TargetObject} );
        $Param{TargetObject} = $Type[0];

        # get possible types list
        my %PossibleTypesList = $LinkObject->PossibleTypesList(
            Object1 => $Param{SourceObject},
            Object2 => $Param{TargetObject},
            UserID  => $Self->{UserID},
        );

        # define blank line entry
        my %BlankLine = (
            Key      => '-',
            Value    => '-------------------------',
            Disabled => 1,
        );

        # create the selectable type list
        my $Counter = 0;
        my @SelectableTypesList;
        POSSIBLETYPE:
        for my $PossibleType ( sort { lc $a cmp lc $b } keys %PossibleTypesList ) {

            # lookup type id
            my $TypeID = $LinkObject->TypeLookup(
                Name   => $PossibleType,
                UserID => $Self->{UserID},
            );

            # get type
            my %Type = $LinkObject->TypeGet(
                TypeID => $TypeID,
                UserID => $Self->{UserID},
            );

            # create the source name
            my %SourceName;
            $SourceName{Key}   = $PossibleType . '::Source';
            $SourceName{Value} = $Type{SourceName};

            push @SelectableTypesList, \%SourceName;

            next POSSIBLETYPE if !$Type{Pointed};

            # create the source name
            my %TargetName;
            $TargetName{Key}   = $PossibleType . '::Target';
            $TargetName{Value} = $Type{TargetName};

            push @SelectableTypesList, \%TargetName;
        }
        continue {

            # add blank line
            push @SelectableTypesList, \%BlankLine;

            $Counter++;
        }

        # removed last (empty) entry
        pop @SelectableTypesList;

        # add blank lines on top and bottom of the list if more then two linktypes
        if ( $Counter > 2 ) {
            unshift @SelectableTypesList, \%BlankLine;
            push @SelectableTypesList, \%BlankLine;
        }

        # set selected value if link type person
        my $SelectedID = '';
        if ( $Param{TargetObject} eq 'Person' ) {
            $SelectedID = 'Customer::Source';
        }

        # create link type string
        my $LinkTypeStrg = $LayoutObject->BuildSelection(
            Data       => \@SelectableTypesList,
            Name       => 'TypeIdentifier',
            SelectedID => $SelectedID,
            Class => 'Modernize'
        );

        # update flag icon content
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $LinkTypeStrg,
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # add new quick link
    elsif ( $Self->{Subaction} eq 'AddLink' ) {

        # get params
        for (qw(SourceObject SourceKey TargetObject QuickLinkAttribute TypeIdentifier)) {
            if ( $ParamObject->GetParam( Param => $_ ) ne 'undefined' ) {
                $Param{$_} = $ParamObject->GetParam( Param => $_ ) || '';
            }
            else {
                $Param{$_} = '';
            }
        }

        my ( $LinkType, $LinkDirection ) = split( '::', $Param{TypeIdentifier} );

        my $Result = $QuickLinkObject->AddLink(
            %Param,
            TargetKey     => $Param{QuickLinkAttribute},
            UserID        => $Self->{UserID},
            LinkType      => $LinkType,
            LinkDirection => $LinkDirection,
        );

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }

    # load autocomplete content
    if ( $Self->{Subaction} eq 'Search' ) {

        # get params
        for (qw(Term MaxResults SourceObject SourceKey TargetObject TypeIdentifier)) {
            if ( $ParamObject->GetParam( Param => $_ ) ne 'undefined' ) {
                $Param{$_} = $ParamObject->GetParam( Param => $_ ) || '';
            }
            else {
                $Param{$_} = '';
            }
        }

        my ( $LinkType, $LinkDirection ) = split( '::', $Param{TypeIdentifier} );

        my @Result = $QuickLinkObject->Search(
            %Param,
            UserID        => $Self->{UserID},
            LinkType      => $LinkType,
            LinkDirection => $LinkDirection,
        );

        # build JSON output
        my $JSON = $LayoutObject->JSONEncode(
            Data => \@Result,
        );

        # send JSON response
        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON || '',
            Type        => 'inline',
            NoCache     => 1,
        );
    }
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
