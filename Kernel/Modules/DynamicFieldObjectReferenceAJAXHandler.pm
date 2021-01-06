# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::DynamicFieldObjectReferenceAJAXHandler;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    $Self->{CallingAction}    = $ParamObject->GetParam( Param => 'CallingAction' )    || '';
    $Self->{DirectLinkAnchor} = $ParamObject->GetParam( Param => 'DirectLinkAnchor' ) || '';

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject          = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject          = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject           = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $DynamicFieldObject    = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $BackendObject         = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $TicketObject          = $Kernel::OM->Get('Kernel::System::Ticket');
    my $EncodeObject          = $Kernel::OM->Get('Kernel::System::Encode');
    my $UserObject            = $Kernel::OM->Get('Kernel::System::User');
    my $CustomerUserObject    = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    my $JSON = '0';

    # get search string
    my $Search = $ParamObject->GetParam( Param => 'Term' ) || '';
    $Search = '*' . $Search . '*';

    # get count of shown results
    my $MaxResults = int( $ParamObject->GetParam( Param => 'MaxResults' ) || 20 );

    # get kind of object reference (User, CustomerUser, CustomerCompany)
    my $ObjectReference = $ParamObject->GetParam( Param => 'ObjectReference' );

    # get calling action - necessary for acls
    my $CallingAction = $ParamObject->GetParam( Param => 'CallingAction' );
    if ( $CallingAction eq 'KIXSidebarDynamicFieldAJAXHandler' ) {
        $CallingAction = 'KIXSidebarDynamicField';
    }

    # get dynamic field name
    my $DynamicField = $ParamObject->GetParam( Param => 'DynamicField' );
    if ( $DynamicField =~ m/^(?:Search_)?DynamicField_(.*)/ ) {
        $DynamicField = $1;
    }

    # extract keys and values from form data string, template is needed for EditFieldValueGet() to use existing value and not one from ParamObject
    my $FormData
        = $ParamObject->GetParam( Param => 'FormData' );    # separated string with all form data
    my %GetParam;
    my %Template;
    my @FormDataArray = split( /;/, $FormData );
    for my $Key (@FormDataArray) {
        if ( $Key =~ m/(.*?)=(.*)/ ) {
            $GetParam{$1} = $2;
            $Template{$1} = $2;
        }
    }

    # get dynamic field config
    my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
        Name => $DynamicField
    );

    # extract the dynamic field value form the web request
    my $DynamicFieldValue = $BackendObject->EditFieldValueGet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ParamObject        => $ParamObject,
        LayoutObject       => $LayoutObject,
        Template           => \%Template
    );

    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicFieldConfig->{Name} }
        = $DynamicFieldValue;
    $GetParam{DynamicField} = \%DynamicFieldACLParameters;

    my %PossibleValuesHash;
    my %DynamicFieldHash;
    my $PossibleValuesFilter;

    # get PossibleValues
    my $PossibleValues = $BackendObject->PossibleValuesGet(
        DynamicFieldConfig    => $DynamicFieldConfig,
        Search                => $Search,
        GetAutocompleteValues => 1
    );

    $DynamicFieldHash{ $DynamicFieldConfig->{ID} } = $DynamicFieldConfig->{Name};

    # check if field has PossibleValues property in its configuration
    if ( IsHashRefWithData($PossibleValues) ) {

        # convert possible values key => value to key => key for ACLs using a Hash slice
        my %AclData = %{$PossibleValues};
        @AclData{ keys %AclData } = keys %AclData;

        # set possible values filter from ACLs
        my $ACL;

        # for customer frontend
        if ( $CallingAction =~ /^CustomerTicket/ ) {
            $ACL = $TicketObject->TicketAcl(
                %GetParam,
                Action         => $CallingAction,
                ReturnType     => 'Ticket',
                ReturnSubType  => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data           => \%AclData,
                CustomerUserID => $Self->{UserID},
            );
        }

        # for agent frontend
        else {
            $ACL = $TicketObject->TicketAcl(
                %GetParam,
                Action        => $CallingAction,
                ReturnType    => 'Ticket',
                ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data          => \%AclData,
                UserID        => $Self->{UserID},
            );
        }

        if ($ACL) {
            my %Filter = $TicketObject->TicketAclData();

            # convert Filer key => key back to key => value using map
            %{$PossibleValuesFilter}
                = map { $_ => $PossibleValues->{$_} }
                keys %Filter;

            $PossibleValuesHash{ $DynamicFieldConfig->{Name} } = $PossibleValuesFilter;
        }
        else {
            $PossibleValuesHash{ $DynamicFieldConfig->{Name} } = $PossibleValues;
        }
    }

    # workaround, all auto completion requests get posted by utf8 anyway
    # convert any to 8bit string if application is not running in utf8
    $Search = $EncodeObject->Convert(
        Text => $Search,
        From => 'utf-8',
        To   => $LayoutObject->{UserCharset},
    );

    # get result list
    my %ObjectList;

    # search customer users
    if ( $ObjectReference eq 'CustomerUser' ) {
        %ObjectList = $CustomerUserObject->CustomerSearch(
            Search => $Search,
        );
    }

    # search users
    elsif ( $ObjectReference eq 'User' ) {
        my %UserList = $UserObject->UserSearch(
            Search => $Search,
        );

        for my $User ( keys %UserList ) {
            my %UserData = $UserObject->GetUserData(
                UserID => $User,
            );

            $ObjectList{ $UserData{UserLogin} }
                = $UserData{UserFirstname} . " "
                . $UserData{UserLastname} . " <"
                . $UserData{UserEmail} . ">";
        }
    }

    # search customer companies
    elsif ( $ObjectReference eq 'CustomerCompany' ) {
        my %CompanyList = $CustomerCompanyObject->CustomerCompanyList(
            Search => $Search,
        );

        for my $Company ( keys %CompanyList ) {
            $ObjectList{$Company} = $CompanyList{$Company};
        }

    }

    # eliminate values if they are not in possible list
    %ObjectList
        = map { $_ => $ObjectList{$_} } grep { defined $PossibleValuesHash{$DynamicField}->{$_} }
        keys %ObjectList;

    # create data hash for return
    my %DataHash = ();
    if ( scalar keys %ObjectList ) {

        # build data
        for my $DynamicFieldName ( keys %PossibleValuesHash ) {

            my $MaxResultCount = $MaxResults;
            my @Data;

            # create data for autocomplete field
            if ( $DynamicField eq $DynamicFieldName ) {
                for my $ObjectID (
                    sort { $ObjectList{$a} cmp $ObjectList{$b} }
                    keys %ObjectList
                ) {
                    push @Data, {
                        Key   => $ObjectID,
                        Value => $ObjectList{$ObjectID},
                    };

                    $MaxResultCount--;
                    last if $MaxResultCount <= 0;
                }
            }

            # create data for other fields affected by depending field acl
            else {
                for my $PossibleValue (
                    sort {
                        $PossibleValuesHash{$DynamicFieldName}->{$a}
                            cmp $PossibleValuesHash{$DynamicFieldName}->{$b}
                    }
                    keys %{ $PossibleValuesHash{$DynamicFieldName} }
                ) {
                    push @Data, {
                        Key   => $PossibleValue,
                        Value => $PossibleValuesHash{$DynamicFieldName}->{$PossibleValue},
                    };

                    $MaxResultCount--;
                    last if $MaxResultCount <= 0;
                }
            }

            # add data array to data hash
            $DataHash{$DynamicFieldName} = \@Data;
        }
    }

    # build JSON output
    $JSON = $LayoutObject->JSONEncode(
        Data => \%DataHash,
    );

    # send JSON response
    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON || '',
        Type        => 'inline',
        NoCache     => 1,
    );

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
