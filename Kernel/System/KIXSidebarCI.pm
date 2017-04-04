# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::KIXSidebarCI;

use strict;
use warnings;

use utf8;

our @ObjectDependencies = (
    'Kernel::System::GeneralCatalog',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{ConfigItemObject}     = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LinkObject}           = $Kernel::OM->Get('Kernel::System::LinkObject');

    return $Self;
}

sub KIXSidebarCISearch {
    my ( $Self, %Param ) = @_;

    my %Result;

    # get linked objects
    if ( $Param{TicketID} && $Param{LinkMode} ) {
        my %LinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => 'ITSMConfigItem',
            State   => $Param{LinkMode},
            UserID  => 1,
        );

        for my $ID ( keys %LinkKeyList ) {
            my $VersionRef = $Self->{ConfigItemObject}->VersionGet(
                ConfigItemID => $ID,
                XMLDataGet   => 0,
            );

            if (
                $VersionRef
                && ( ref($VersionRef) eq 'HASH' )
                && $VersionRef->{Name}
                && $VersionRef->{Number}
                )
            {

                if (
                    $Param{CIClasses}
                    && ref( $Param{CIClasses} ) eq 'HASH'
                    )
                {
                    CLASS:
                    for my $Class ( keys %{ $Param{CIClasses} } ) {
                        if ( $Class eq $VersionRef->{Class} ) {
                            $Result{$ID} = $VersionRef;
                            $Result{$ID}->{'Link'} = 1;
                            last CLASS;
                        }
                    }
                }
                else {
                    $Result{$ID} = $VersionRef;
                    $Result{$ID}->{'Link'} = 1;
                }

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );

            }
        }
    }

    # Search only if Search-String was given
    if ( $Param{SearchString} ) {

        # Get Classes from Config
        my %SearchInClasses = ();
        if (
            $Param{CIClasses}
            && ref( $Param{CIClasses} ) eq 'HASH'
            )
        {
            %SearchInClasses = %{ $Param{CIClasses} };
        }
        else {
            my $ClassList = $Self->{GeneralCatalogObject}->ItemList(
                Class => 'ITSM::ConfigItem::Class',
            );
            if (
                $ClassList
                && ref($ClassList) eq 'HASH'
                )
            {
                for my $ClassID ( keys %{$ClassList} ) {
                    $SearchInClasses{ $ClassList->{$ClassID} } = '';
                }
            }
        }

        my $SearchListRef = ();

        # perform CMDB search and link results...
        CLASS:
        for my $Class ( keys %SearchInClasses ) {
            my $ClassItemRef = $Self->{GeneralCatalogObject}->ItemGet(
                Class => 'ITSM::ConfigItem::Class',
                Name  => $Class,
            ) || 0;
            next CLASS if ( ref($ClassItemRef) ne 'HASH' || !$ClassItemRef->{ItemID} );

            # get CI-class definition...
            my $XMLDefinition = $Self->{ConfigItemObject}->DefinitionGet(
                ClassID => $ClassItemRef->{ItemID},
            );
            if ( !$XMLDefinition->{DefinitionID} ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "No Definition definied for class $Class!",
                );
                next CLASS;
            }

            my $SearchAttributeKey = $SearchInClasses{$Class} || '';
            $SearchAttributeKey =~ s/^\s+//g;
            $SearchAttributeKey =~ s/\s+$//g;

            my %SearchParams = ();
            my %SearchData   = ();

           # build search params...
           # perform multiple seaparat searches if search pattern contains comma-separated values...
            my @SearchValues = ();
            my $SplitSeparator = $Param{CustomerDataSplitSeparator} || '';
            if ($SplitSeparator) {
                @SearchValues = split( $SplitSeparator, $Param{CustomerSearchPattern} );
            }
            else {
                push( @SearchValues, $Param{CustomerSearchPattern} );
            }

            for my $SearchValue (@SearchValues) {

                $SearchData{$SearchAttributeKey} = $SearchValue;
                my @SearchParamsWhat;
                $Self->_ExportXMLSearchDataPrepare(
                    XMLDefinition => $XMLDefinition->{DefinitionRef},
                    What          => \@SearchParamsWhat,
                    SearchData    => \%SearchData,
                );

                # build search hash...
                if (@SearchParamsWhat) {
                    $SearchParams{What} = \@SearchParamsWhat;
                }

                # search for name....
                $SearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                    %SearchParams,
                    ClassIDs => [ $ClassItemRef->{ItemID} ],
                    Name     => $Param{SearchString},
                    Limit    => $Param{Limit},
                );

                ID:
                for my $ID ( @{$SearchListRef} ) {

                    next ID if ( $Result{$ID} );

                    my $VersionRef = $Self->{ConfigItemObject}->VersionGet(
                        ConfigItemID => $ID,
                        XMLDataGet   => 0,
                    );
                    if (
                        $VersionRef
                        && ( ref($VersionRef) eq 'HASH' )
                        && $VersionRef->{Name}
                        && $VersionRef->{Number}
                        )
                    {
                        $Result{$ID} = $VersionRef;
                        $Result{$ID}->{'Link'} = 0;

                        # Check if limit is reached
                        return \%Result
                            if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
                    }
                }

                # search for number....
                $SearchListRef = $Self->{ConfigItemObject}->ConfigItemSearchExtended(
                    %SearchParams,
                    ClassIDs => [ $ClassItemRef->{ItemID} ],
                    Number   => $Param{SearchString},
                    Limit    => $Param{Limit},
                );

                ID:
                for my $ID ( @{$SearchListRef} ) {

                    next ID if ( $Result{$ID} );

                    my $VersionRef = $Self->{ConfigItemObject}->VersionGet(
                        ConfigItemID => $ID,
                        XMLDataGet   => 0,
                    );
                    if (
                        $VersionRef
                        && ( ref($VersionRef) eq 'HASH' )
                        && $VersionRef->{Name}
                        && $VersionRef->{Number}
                        )
                    {
                        $Result{$ID} = $VersionRef;
                        $Result{$ID}->{'Link'} = 0;

                        # Check if limit is reached
                        return \%Result
                            if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
                    }
                }
            }
        }
    }

    return \%Result;
}

sub _ExportXMLSearchDataPrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLDefinition} || ref $Param{XMLDefinition} ne 'ARRAY';
    return if !$Param{What}          || ref $Param{What}          ne 'ARRAY';
    return if !$Param{SearchData}    || ref $Param{SearchData}    ne 'HASH';

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {

        # create key
        my $Key = $Param{Prefix} ? $Param{Prefix} . '::' . $Item->{Key} : $Item->{Key};

        # prepare value
        my $Values = $Self->{ConfigItemObject}->XMLExportSearchValuePrepare(
            Item  => $Item,
            Value => $Param{SearchData}->{$Key},
        );
        if ($Values) {

            # create search key
            my $SearchKey = $Key;
            $SearchKey =~ s{ :: }{\'\}[%]\{\'}xmsg;

            # create search hash
            my $SearchHash = {
                '[1]{\'Version\'}[1]{\''
                    . $SearchKey
                    . '\'}[%]{\'Content\'}' => $Values,
            };
            push @{ $Param{What} }, $SearchHash;
        }
        next ITEM if !$Item->{Sub};

        # start recursion, if "Sub" was found
        $Self->_ExportXMLSearchDataPrepare(
            XMLDefinition => $Item->{Sub},
            What          => $Param{What},
            SearchData    => $Param{SearchData},
            Prefix        => $Key,
        );
    }
    return 1;
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
