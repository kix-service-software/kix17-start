# --
# Kernel/System/ITSMConfigItem/Event/ServiceReference_RefreshLinks.pm
#
# Searches for attributes of type ServiceReference in the new CIs version data
# and refreshes all links to that class, if configured in CI-class definition.
# It deletes links to any objects of the referenced CI-class if the value does
# not exis in the CIs version data.
#
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/changed by:
# * Torsten(dot)Thau(at)cape(dash)it(dot)de
# * Stefan(dot)Mehlig(at)cape(dash)it(dot)de
# * Frank(dot)Oberender(at)cape(dash)it(dot)de
# * Anna(dot)Litvinova(at)cape-it(dot)de
# * Mario(dot)Illinger(at)cape-it(dot)de
#
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::Event::ServiceReference_RefreshLinks;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::ITSMCIAttributCollectionUtils',
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::LinkObject',
    'Kernel::System::Log'
);

sub new {
    my ( $Type, %Param ) = @_;

    #alCoCentate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CIACUtilsObject}  = $Kernel::OM->Get('Kernel::System::ITSMCIAttributCollectionUtils');
    $Self->{ConfigItemObject} = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');
    $Self->{LinkObject}       = $Kernel::OM->Get('Kernel::System::LinkObject');
    $Self->{LogObject}        = $Kernel::OM->Get('Kernel::System::Log');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    #check required stuff...
    foreach (qw(Event Data)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event::ServiceReference_RefreshLinks: Need $_!"
            );
            return;
        }
    }
    $Param{ConfigItemID}=$Param{Data}->{ConfigItemID};
    if ( !$Param{ConfigItemID} ) {
        $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Event::CIClassReference_RefreshLinks: No ConfigItemID in Data!"
        );
        return;
    }

    #get config item...
    my $ConfigItemRef = $Self->{ConfigItemObject}->ConfigItemGet(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$ConfigItemRef || ref($ConfigItemRef) ne 'HASH' );

    #check if there is a version at all...
    my $VersionListRef = $Self->{ConfigItemObject}->VersionList(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$VersionListRef->[0] );

    #get the most current version...
    my $VersionData = $Self->{ConfigItemObject}->VersionGet(
        ConfigItemID => $Param{ConfigItemID},
    );
    return if ( !$VersionData || ref($VersionData) ne 'HASH' );

    #---------------------------------------------------------------------------
    # get hash with all attribute-keys, referenced CI-classes,
    # corresponding link types and -directions from CI-class definition...

    my %RelAttr       = ();
    my $XMLDefinition = $Self->{ConfigItemObject}->DefinitionGet(
        ClassID => $VersionData->{ClassID},
    );

    # _CreateServiceReferencesHash() returns a hash ref with following structure:
    # $RelAttr{Key}->{ReferencedServiceLinkType}
    # $RelAttr{Key}->{ReferencedServiceLinkDirection}
    %RelAttr = $Self->_CreateServiceReferencesHash(
        XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
        XMLDefinition => $XMLDefinition->{DefinitionRef},
    );

    my %CIReferenceAttrData = ();

    #---------------------------------------------------------------------------
    # update ConfigItem-links...
    if ( $VersionData && $XMLDefinition && %RelAttr ) {

        for my $CurrKeyname ( keys(%RelAttr) ) {

            next if !$RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkType};

            #get current links from this CI..
            my @LinkedSrcRefereceIDs = @{
                $Self->GetLinkedObjects(
                    FromObject   => 'ITSMConfigItem',
                    FromObjectID => $Param{ConfigItemID},
                    ToObject     => 'Service',
                    ToSubObject  => '',
                    LinkType     => $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkType},
                    Direction    => 'Source',
                    )
                };

            #get current  links to this CI..
            my @LinkedTargetReferenceIDs = @{
                $Self->GetLinkedObjects(
                    FromObject   => 'Service',
                    FromObjectID => $Param{ConfigItemID},
                    ToObject     => 'ITSMConfigItem',
                    ToSubObject  => '',
                    LinkType     => $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkType},
                    Direction    => 'Target',
                    )
                };

            #-----------------------------------------------------------------------
            # delete existing links...
            #if possible, do what we're here for...
            if ( $VersionData && $XMLDefinition ) {

                %CIReferenceAttrData = %{
                    $Self->_GetAttributeDataByKey(
                        XMLData       => $VersionData->{XMLData}->[1]->{Version}->[1],
                        XMLDefinition => $XMLDefinition->{DefinitionRef},
                        KeyName       => $CurrKeyname,
                        Content => 1,    #need the CI-ID, not the shown value
                        )
                    };

                #delete all existing links...
                if ( keys(%CIReferenceAttrData) ) {
                    for my $CurrLinkPartnerID (@LinkedSrcRefereceIDs) {

                        $Self->{LinkObject}->LinkDelete(
                            Object1 => 'ITSMConfigItem',
                            Key1    => $Param{ConfigItemID},
                            Object2 => 'Service',
                            Key2    => $CurrLinkPartnerID,
                            Type    => $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkType},
                            UserID  => 1,
                        );
                    }
                }

                #delete all existing Target  links...
                for my $CurrLinkPartnerID (@LinkedTargetReferenceIDs) {

                    $Self->{LinkObject}->LinkDelete(
                        Object1 => 'ITSMConfigItem',
                        Key1    => $Param{ConfigItemID},
                        Object2 => 'Service',
                        Key2    => $CurrLinkPartnerID,
                        Type    => $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkType},
                        UserID  => 1,
                    );
                }
            }

            #-----------------------------------------------------------------------
            # create all links from available data...
            for my $SearchResult ( keys(%CIReferenceAttrData) ) {
                my @ReferenceCIIDs = @{ $CIReferenceAttrData{$SearchResult} };
                for my $CurrCIReferenceID (@ReferenceCIIDs) {

                    #create link between this CI and current CIReference-attribute...
                    if ( $CurrCIReferenceID && $Param{ConfigItemID} ) {
                        if (
                            $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkDirection}
                            &&
                            $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkDirection} eq
                            'Reverse'
                            )
                        {
                            $Self->{LinkObject}->LinkAdd(
                                SourceObject => 'Service',
                                SourceKey    => $CurrCIReferenceID,
                                TargetObject => 'ITSMConfigItem',
                                TargetKey    => $Param{ConfigItemID},
                                Type   => $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkType},
                                State  => 'Valid',
                                UserID => 1,
                            );

                        }
                        else {
                            $Self->{LinkObject}->LinkAdd(
                                TargetObject => 'Service',
                                TargetKey    => $CurrCIReferenceID,
                                SourceObject => 'ITSMConfigItem',
                                SourceKey    => $Param{ConfigItemID},
                                Type   => $RelAttr{$CurrKeyname}->[0]->{ReferencedServiceLinkType},
                                State  => 'Valid',
                                UserID => 1,
                            );
                        }

                    }    #EO if( $CurrCIReferenceID && $Param{ConfigItemID})

                }    #EO for my $CurrCIReferenceID( @ReferenceCIIDs )

            }    #EO foreach my $SearchResult ( keys( %CIReferenceAttrData))

        }    #EO for my $CurrKeyname ( keys( %RelAttr ))

    }    #EO if ( $VersionData && $XMLDefinition && %RelAttr)
    return;
}

sub _CreateServiceReferencesHash {
    my ( $Self, %Param ) = @_;

    # check required params...
    if (
        ( !$Param{XMLData} ) ||
        ( !$Param{XMLDefinition} ) ||
        ( ref $Param{XMLData} ne 'HASH' ) ||
        ( ref $Param{XMLDefinition} ne 'ARRAY' )
        )
    {
        return;
    }

    my $CIRelAttr = $Self->{CIACUtilsObject}->GetAttributeDataByType(
        XMLData       => $Param{XMLData},
        XMLDefinition => $Param{XMLDefinition},
        AttributeType => 'ServiceReference',
    );

    my %SumRelAttr = ();
    my $ParamRef;
    for my $Key ( keys %{$CIRelAttr} ) {

        my %RetHash = ();
        ITEM:
        for my $Item ( @{ $Param{XMLDefinition} } ) {

            COUNTER:
            for my $Counter ( 1 .. $Item->{CountMax} ) {

                # no content then stop loop...
                last COUNTER if !defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content};

                if ( $Item->{Key} eq $Key ) {

                    foreach my $ParamRef (
                        qw(ReferencedServiceName ReferencedServiceLinkType ReferencedServiceLinkDirection)
                        )
                    {
                        $RetHash{$ParamRef} = $Item->{Input}->{$ParamRef};

                    }
                }
                next COUNTER if !$Item->{Sub};

                # Handling of Sub-Iems in Definitions
                if ( $Item->{Sub} ) {
                    %SumRelAttr = (
                        %SumRelAttr,
                        $Self->_CreateServiceReferencesHash(
                            XMLDefinition => $Item->{Sub},
                            XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                        )
                    );
                }
            }
        }
        push @{ $SumRelAttr{$Key} }, \%RetHash;

    }
    return %SumRelAttr;
}

=item _GetAttributeDataByKey()

    Returns a hashref with names and attribute values from the
    XML-DataHash for a specified data type.

    $ConfigItemObject->GetAttributeDataByKey(
        XMLData       => $XMLData,
        XMLDefinition => $XMLDefinition,
        KeyName => $Key,
    );

=cut

sub _GetAttributeDataByKey {
    my ( $Self, %Param ) = @_;

    my %Result;

    if ( $Param{Content} ) {
        my $CurrContent = $Self->{CIACUtilsObject}->GetAttributeContentsByKey(
            KeyName       => $Param{KeyName},
            XMLData       => $Param{XMLData},
            XMLDefinition => $Param{XMLDefinition},
        );
        $Result{ $Param{KeyName} } = $CurrContent;
    }
    else {
        my $CurrVal = $Self->{CIACUtilsObject}->GetAttributeValuesByKey(
            KeyName       => $Param{KeyName},
            XMLData       => $Param{XMLData},
            XMLDefinition => $Param{XMLDefinition},
        );
        $Result{ $Param{KeyName} } = $CurrVal;
    }
    return \%Result;

}

#-------------------------------------------------------------------------------
#

=item GetLinkedObjects()

   returns an array ref with IDs of linked objects

   NOTE: remove this method as soon as (KIX)
   Kernel::System::LinkObject::GetLinkedObjects has been modified and is
   available !!!

   my @LinkedLocationIDs = @{$Self->GetLinkedObjects(
       FromObject   => 'ITSMConfigItem',
       FromObjectID => 123,
       ToObject     => 'ITSMConfigItem' | 'Ticket',
       ToSubObject  => 'Location-Some CI Class' | 'OrSomeTicketType',
       LinkType     => 'ParentChild',        #LinkType - optional
       Direction    => (Source|Target|Both), #LinkDirection - optional
   )};

=cut

sub GetLinkedObjects {
    my ( $Self, %Param ) = @_;
    my @IDArr = qw{};

    # check required params...
    if ( ( !$Param{ToObject} ) || ( !$Param{FromObject} ) || ( !$Param{FromObjectID} ) )
    {
        return \@IDArr;
    }

    #as long as it's not implemented...
    if (
        ( $Param{ToObject} ne 'ITSMConfigItem' )
        && ( $Param{ToObject} ne 'Ticket' )
        && ( $Param{ToObject} ne 'Service' )
        )
    {
        $Self->{LogObject}->Log(
            Priority => 'notice',
            Message  => "LinkObject::GetLinkedObjects: "
                . "unknown ToObject $Param{ToObject} - won't do anything.",
        );
        return \@IDArr;
    }

    if ( !$Param{ToSubObject} ) {
        $Param{ToSubObject} = "";
    }

    #get all linked ToObjects...
    my $PartnerLinkList = $Self->{LinkObject}->LinkListWithData(
        Object    => $Param{FromObject},
        Key       => $Param{FromObjectID},
        Object2   => $Param{ToObject},
        State     => 'Valid',
        Type      => $Param{LinkType} || '',
        Direction => $Param{Direction} || 'Both',
        UserID    => 1,
    );

    #---------------------------------------------------------------------------
    # ToPartner "ITSMConfigItem"
    if ( $Param{ToObject} eq 'ITSMConfigItem' ) {

        #for each existing link type
        for my $LinkType ( keys( %{ $PartnerLinkList->{'ITSMConfigItem'} } ) ) {

            #if linked object is a source
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) eq 'HASH' )
                )
            {
                for my $CurrCIID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} } )
                    )
                {
                    my $CurrCI =
                        $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source}->{$CurrCIID};

                    if ( $Param{ToSubObject} && ( $CurrCI->{Class} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $CurrCIID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $CurrCIID );
                    }
                }
            }

            #if linked object is target
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) eq 'HASH' )
                )
            {
                for my $CurrCIID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} } )
                    )
                {
                    my $CurrCI = $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target}
                        ->{$CurrCIID};

                    if ( $Param{ToSubObject} && ( $CurrCI->{Class} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $CurrCIID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $CurrCIID );
                    }
                }
            }

        }    #EO for each existing link type

    }

    # EO ToPartner "ITSMConfigItem"
    #---------------------------------------------------------------------------

    #---------------------------------------------------------------------------
    # ToPartner "Ticket"
    if ( $Param{ToObject} eq 'Ticket' ) {

        #for each existing link type
        for my $LinkType ( keys( %{ $PartnerLinkList->{'Ticket'} } ) ) {

            #if linked object is a source
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) eq 'HASH' )
                )
            {
                for my $TicketID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} } )
                    )
                {
                    my $CurrTicket = $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source}
                        ->{$TicketID};

                    if ( $Param{ToSubObject} && ( $CurrTicket->{Type} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $TicketID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $TicketID );
                    }
                }
            }

            #if linked object is target
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) eq 'HASH' )
                )
            {
                for my $TicketID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} } )
                    )
                {
                    my $CurrTicket = $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target}
                        ->{$TicketID};

                    if ( $Param{ToSubObject} && ( $CurrTicket->{Type} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $TicketID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $TicketID );
                    }
                }
            }

        }    #EO for each existing link type

    }

    # EO ToPartner "Ticket"
    #---------------------------------------------------------------------------

    #---------------------------------------------------------------------------
    # ToPartner "Service"
    if ( $Param{ToObject} eq 'Service' ) {

        #for each existing link type
        for my $LinkType ( keys( %{ $PartnerLinkList->{'Service'} } ) ) {

            #if linked object is a source
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} ) eq 'HASH' )
                )
            {
                for my $ServiceID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source} } )
                    )
                {
                    my $CurrService = $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Source}
                        ->{$ServiceID};

                    if ( $Param{ToSubObject} && ( $CurrService->{Type} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $ServiceID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $ServiceID );
                    }
                }
            }

            #if linked object is target
            if (
                ( defined( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) )
                &&
                ( ref( $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} ) eq 'HASH' )
                )
            {
                for my $ServiceID (
                    keys( %{ $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target} } )
                    )
                {
                    my $CurrService = $PartnerLinkList->{ $Param{ToObject} }->{$LinkType}->{Target}
                        ->{$ServiceID};

                    if ( $Param{ToSubObject} && ( $CurrService->{Type} eq $Param{ToSubObject} ) ) {
                        push( @IDArr, $ServiceID );
                    }
                    elsif ( !$Param{ToSubObject} ) {
                        push( @IDArr, $ServiceID );
                    }
                }
            }

        }    #EO for each existing link type

    }

    # EO ToPartner "Service"
    #---------------------------------------------------------------------------

    return \@IDArr;
}

#
#-------------------------------------------------------------------------------

1;
