# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::CIGroupAccess;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Group',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::CIGroupAccess - xml backend module

=head1 SYNOPSIS

All xml functions of CIGroupAccess objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeCustomerCompanyBackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::CustomerCompany');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{LogObject}   = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{GroupObject} = $Kernel::OM->Get('Kernel::System::Group');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Item  => $ItemRef,
        Value => 11,        # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Item} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Item!',
        );
        return;
    }

    return if !$Param{Value};

    # create array
    my @GetValueArray = split( /,/, $Param{Value} );

    # get item list
    my %Groups = $Self->{GroupObject}->GroupList( Valid => 1 );

    my @ValueArray = ();
    for my $Group ( keys %Groups ) {
        next if !grep { $_ eq $Group } @GetValueArray;
        push @ValueArray, $Groups{$Group};
    }
    my $Value = join( ", ", @ValueArray );

    return $Value;
}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key  => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get item list
    my %Groups = $Self->{GroupObject}->GroupList( Valid => 1 );

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => $Param{Key},
            Block            => 'MultiSelectField',
            Values           => \%Groups,
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my @Values = split '#####', $Param{Value};
    @Values = grep {$_} @Values;

    return \@Values;
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # get array from string
    my @Groups = split( /,/ , $Param{Value} );

    # get all possible groups
    my %AllGroups = $Self->{GroupObject}->GroupList( Valid => 1 );

    # map group names to GroupIDs
    my @GroupNames = map { $AllGroups{$_} } @Groups;

    # create string
    my $GroupString = join (",",@GroupNames);

    # return
    return $GroupString;
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my @Values = split '#####', $Param{Value};
    @Values = grep {$_} @Values;

    return \@Values;
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # get array from string
    my @Groups = split( /,/ , $Param{Value} );

    # get all possible groups
    my %AllGroups = $Self->{GroupObject}->GroupList( Valid => 1 );

    # reverse the list
    my %Name2ID = reverse %AllGroups;

    # map group names to GroupIDs
    my @GroupIDs = map { $Name2ID{$_} } @Groups;

    # create string
    my $GroupString = join (",",@GroupIDs);

    # return
    return $GroupString;
}

1;


=head1 VERSION

$Revision$ $Date$

=cut



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
