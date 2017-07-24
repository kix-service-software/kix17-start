# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::ITSMConfigItem::LayoutSLAReference;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Language',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Encode',
    'Kernel::System::Log',
    'Kernel::System::Package',
    'Kernel::System::Service',
    'Kernel::System::SLA',
    'Kernel::System::Web::Request'
);

=head1 NAME

Kernel::Output::HTML::ITSMConfigItemLayoutSLAReference - layout backend module

=head1 SYNOPSIS

All layout functions of SLAReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::Output::HTML::ITSMConfigItemLayoutSLAReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{ConfigObject}   = $Kernel::OM->Get('Kernel::Config');
    $Self->{LanguageObject} = $Kernel::OM->Get('Kernel::Language');
    $Self->{LayoutObject}   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{EncodeObject}   = $Kernel::OM->Get('Kernel::System::Encode');
    $Self->{LogObject}      = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{PackageObject}  = $Kernel::OM->Get('Kernel::System::Package');
    $Self->{ServiceObject}  = $Kernel::OM->Get('Kernel::System::Service');
    $Self->{SLAObject}      = $Kernel::OM->Get('Kernel::System::SLA');
    $Self->{ParamObject}    = $Kernel::OM->Get('Kernel::System::Web::Request');

    return $Self;
}

=item OutputStringCreate()

create output string

    my $Value = $BackendObject->OutputStringCreate(
        Value => 11,       # (optional)
    );

=cut

sub OutputStringCreate {
    my ( $Self, %Param ) = @_;

    #transform ascii to html...
    $Param{Value} = $Self->{LayoutObject}->Ascii2Html(
        Text => $Param{Value} || '',
        HTMLResultMode => 1,
    );

    return $Param{Value};
}

=item FormDataGet()

get form data as hash reference

    my $FormDataRef = $BackendObject->FormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub FormDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff...
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    my %FormData;

    # get selected CIClassReference...
    $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} );

    # check search button..
    if ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonSearch' ) ) {
        $Param{Item}->{Form}->{ $Param{Key} }->{Search}
            = $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Search' );

        # check additional data..
        for my $Attr ( qw(ServiceData CustomerLoginData CustomerCompanyData) ) {
            $Param{Item}->{Form}->{ $Param{Key} }->{$Attr}
                = $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::' . $Attr ) || '';
        }
    }

    # check select button...
    elsif ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonSelect' ) ) {
        $FormData{Value} = $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Select' );
    }

    # check clear button...
    elsif ( $Self->{ParamObject}->GetParam( Param => $Param{Key} . '::ButtonClear' ) ) {
        $FormData{Value} = '';
    }
    else {

        # reset value if search field is empty...
        if (
            !$Self->{ParamObject}->GetParam( Param => $Param{Key} . '::Search' )
            && defined $FormData{Value}
            )
        {
            $FormData{Value} = '';
        }

        # check required option...
        if ( $Param{Item}->{Input}->{Required} && !$FormData{Value} ) {
            $Param{Item}->{Form}->{ $Param{Key} }->{Invalid} = 1;
            $FormData{Invalid} = 1;
        }
    }

    return \%FormData;
}

=item InputCreate()

create a input string

    my $Value = $BackendObject->InputCreate(
        Key => 'Item::1::Node::3',
        Value => 11,       # (optional)
        Item => $ItemRef,
    );

=cut

sub InputCreate {
    my ( $Self, %Param ) = @_;

    #check needed stuff...
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    my $Value = '';
    if ( defined $Param{Value} ) {
        $Value = $Param{Value};
    }
    elsif ( $Param{Item}->{Input}->{ValueDefault} ) {
        $Value = $Param{Item}->{Input}->{ValueDefault};
    }

    my $Size         = $Param{Item}->{Input}->{Size} || 50;
    my $Search       = '';
    my $StringOption = '';
    my $StringSelect = '';
    my $Class        = 'W50pc SLASearch';
    my $Required     = $Param{Required} || '';
    my $Invalid      = $Param{Invalid} || '';
    my $ItemId       = $Param{ItemId} || '';

    if ($Required) {
        $Class .= ' Validate_Required';
    }

    if ($Invalid) {
        $Class .= ' ServerError';
    }

    # SLAReference search...
    if ( $Param{Item}->{Form}->{ $Param{Key} }->{Search} ) {

        #-----------------------------------------------------------------------
        # search for name....
        my %SLAList = $Self->_SLASearch(
            Search              => '*' . $Param{Item}->{Form}->{ $Param{Key} }->{Search} . '*',
            ServiceData         => $Param{Item}->{Form}->{ $Param{Key} }->{ServiceData},
            CustomerLoginData   => $Param{Item}->{Form}->{ $Param{Key} }->{CustomerLoginData},
            CustomerCompanyData => $Param{Item}->{Form}->{ $Param{Key} }->{CustomerCompanyData},
        );

        #-----------------------------------------------------------------------
        # build search result presentation....
        if ( %SLAList && scalar( keys %SLAList ) > 1 ) {

            #create option list...
            $StringOption = $Self->{LayoutObject}->BuildSelection(
                Name => $Param{Key} . '::Select',
                Data => \%SLAList,
            );
            $StringOption .= '<br>';

            #create select button...
            $StringSelect = '<input class="button" type="submit" name="'
                . $Param{Key}
                . '::ButtonSelect" '
                . 'value="'
                . $Self->{LanguageObject}->Translate( "Select" )
                . '">&nbsp;';

            #set search...
            $Search = $Param{Item}->{Form}->{ $Param{Key} }->{Search};
        }
        elsif (%SLAList) {
            $Value = ( keys %SLAList )[0];
            my %SLAData = $Self->{SLAObject}->SLAGet(
                SLAID  => $Value,
                UserID => 1,
            );
            my $SLAName = "";

            if ( %SLAData && $SLAData{Name} ) {
                $SLAName = $SLAData{Name};
            }

            #transform ascii to html...
            $Search = $Self->{LayoutObject}->Ascii2Html(
                Text => $SLAName || '',
                HTMLResultMode => 1,
            );
        }

    }

    #create CIClassReference string...
    elsif ($Value) {

        my %SLAData = $Self->{SLAObject}->SLAGet(
            SLAID  => $Value,
            UserID => 1,
        );
        my $SLAName = "";

        if ( %SLAData && $SLAData{Name} ) {
            $SLAName = $SLAData{Name};
        }

        #transform ascii to html...
        $Search = $Self->{LayoutObject}->Ascii2Html(
            Text => $SLAName || '',
            HTMLResultMode => 1,
        );
    }

    # AutoComplete CIClass
    my $AutoCompleteConfig
        = $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Frontend::CommonSearchAutoComplete');

    #create string...
    my $String = '';
    if (   $AutoCompleteConfig
        && ref($AutoCompleteConfig) eq 'HASH'
        && $AutoCompleteConfig->{Active} )
    {

        $Self->{LayoutObject}->Block(
            Name => 'SLASearchAutoComplete',
            Data => {
                minQueryLength      => $AutoCompleteConfig->{MinQueryLength}      || 2,
                queryDelay          => $AutoCompleteConfig->{QueryDelay}          || 0.1,
                maxResultsDisplayed => $AutoCompleteConfig->{MaxResultsDisplayed} || 20,
                dynamicWidth        => $AutoCompleteConfig->{DynamicWidth}        || 1,
            },
        );

        $Self->{LayoutObject}->Block(
            Name => 'SLASearchInitAutoComplete',
            Data => {
                Key                       => $Param{Key},
                ItemID                    => $ItemId,
                ActiveAutoComplete        => 'true',
                ReferencedServiceAttrKey  => $Param{Item}->{Input}->{ReferencedServiceAttrKey}  || '',
                ReferencedCustomerLogin   => $Param{Item}->{Input}->{ReferencedCustomerLogin}   || '',
                ReferencedCustomerCompany => $Param{Item}->{Input}->{ReferencedCustomerCompany} || '',
            }
        );

        $String = $Self->{LayoutObject}->Output(
            TemplateFile => 'AgentSLASearch',
        );
        $String
            = '<input type="hidden" name="'
            . $Param{Key}
            . '" value="'
            . $Value
            . '" id="'
            . $ItemId
            . 'Selected"/><input type="text" name="'
            . $Param{Key}
            . '::Search" class="'
            . $Class
            . '" id="'
            . $ItemId
            . '" SearchClass="SLASearch" value="'
            . $Search
            . '"/>';
    }
    else {
        $Self->{LayoutObject}->Block(
            Name => 'SLASearchInitNoAutoComplete',
            Data => {
                Key                       => $Param{Key},
                ItemID                    => $ItemId,
                ReferencedServiceAttrKey  => $Param{Item}->{Input}->{ReferencedServiceAttrKey}  || '',
                ReferencedCustomerLogin   => $Param{Item}->{Input}->{ReferencedCustomerLogin}   || '',
                ReferencedCustomerCompany => $Param{Item}->{Input}->{ReferencedCustomerCompany} || '',
            }
        );

        $String = $Self->{LayoutObject}->Output(
            TemplateFile => 'AgentSLASearch',
        );
        $String
            = '<input type="hidden" name="'
            . $Param{Key}
            . '" value="'
            . $Value
            . '" id="'
            . $ItemId
            . 'Selected"><input type="Text" name="'
            . $Param{Key}
            . '::Search" size="'
            . $Size
            . '" value="'
            . $Search
            . '" id="'
            . $ItemId
            . '"><br>'
            . $StringOption
            . $StringSelect
            . '<input class="button" type="submit" name="'
            . $Param{Key}
            . '::ButtonSearch" value="'
            . $Self->{LanguageObject}->Translate( "Search" )
            . '">&nbsp;<input class="button" type="submit" name="'
            . $Param{Key}
            . '::ButtonClear" value="'
            . $Self->{LanguageObject}->Translate( "Clear" )
            . '">';
    }

    if ($Param{Item}->{Input}->{ReferencedServiceAttrKey}){
        $String .= '<input type="hidden" name="'
            . $Param{Key}
            . '::ServiceData" value="" id="'
            . $ItemId
            . 'ServiceData"/>';
    }
    if ($Param{Item}->{Input}->{ReferencedCustomerLogin}){
        $String .= '<input type="hidden" name="'
            . $Param{Key}
            . '::CustomerLoginData" value="" id="'
            . $ItemId
            . 'CustomerLoginData"/>';
    }
    elsif ($Param{Item}->{Input}->{ReferencedCustomerCompany} ) {
        $String .= '<input type="hidden" name="'
            . $Param{Key}
            . '::CustomerCompanyData" value="" id="'
            . $ItemId
            . 'CustomerCompanyData"/>';
    }

    return $String;
}

=item SearchFormDataGet()

get search form data

    my $Value = $BackendObject->SearchFormDataGet(
        Key => 'Item::1::Node::3',
        Item => $ItemRef,
    );

=cut

sub SearchFormDataGet {
    my ( $Self, %Param ) = @_;

    #check needed stuff
    if ( !$Param{Key} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Key!'
        );
        return;
    }

    # get form data
    my $Value;
    if ( $Param{Value} ) {
        $Value = $Param{Value};
    }
    else {
        $Value = $Self->{ParamObject}->GetParam( Param => $Param{Key} );
    }

    return $Value;
}

=item SearchInputCreate()

create a search input string

    my $Value = $BackendObject->SearchInputCreate(
        Key => 'Item::1::Node::3',
    );

=cut

sub SearchInputCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # hash with values for the input field
    my %FormData;

    if ( $Param{Value} ) {
        $FormData{Value} = $Param{Value};
    }

    # create input field
    my $InputString = $Self->InputCreate(
        %FormData,
        Key    => $Param{Key},
        Item   => $Param{Item},
        ItemId => $Param{Key},
    );

    return $InputString;
}

sub _SLASearch {
    my ( $Self, %Param ) = @_;

    # check if KIXServiceCatalog is installed
    my $KIXServCatalogInstalled = 0;
    my @InstalledPackages = $Self->{PackageObject}->RepositoryList();
    for my $Package (@InstalledPackages) {
        if ( $Package->{Name}->{Content} eq 'KIXServiceCatalog' ) {
            $KIXServCatalogInstalled = 1;
        }
    }

    # get all valid SLAs
    my %AllValidSLAs = $Self->{SLAObject}->SLAList(
        Valid  => 1,
        UserID => $Self->{UserID},
    );
    my %SLAs = %AllValidSLAs;

    #-------------------------------------------------------------------------------
    # if ServiceData is given -> get SLAs that are configured for ALL given services
    if ( $Param{ServiceData} && $Param{ServiceData} ne 'NONE' ) {
        my @Services = split( ';', $Param{ServiceData} );
        if (@Services) {
            for my $ServiceID (@Services) {
                my %SLAsForService = $Self->{SLAObject}->SLAList(
                    Valid     => 1,
                    ServiceID => $ServiceID,
                    UserID    => $Self->{UserID},
                );

                # delete SLA from result if it is not configured for one of Services
                for my $SLA ( keys %SLAs ) {
                    delete $SLAs{$SLA} if !$SLAsForService{$SLA};
                }
            }
        }
        else {
            %SLAs = ();
        }
    }

    # if CustomerLoginData is given -> get SLAs that are configured for ALL CustomerUser's Services
    #----------------------------------------------------------------------------------------------
    if ( $Param{CustomerLoginData} && $Param{CustomerLoginData} ne 'NONE' ) {
        my @CustomerUsers = split( ';', $Param{CustomerLoginData} );
        if (@CustomerUsers) {
            for my $CustomerUserLogin (@CustomerUsers) {
                my %SLAsForCustomerUser = ();

                # get Services for CustomerUser
                my %Services = $Self->{ServiceObject}->CustomerUserServiceMemberList(
                    CustomerUserLogin => $CustomerUserLogin,
                    Result            => 'HASH',
                    DefaultServices   => 0,
                );

                # get SLAs for each Service (SLAs for CUstomerUser)
                for my $ServiceID ( keys %Services ) {
                    my %SLAsForService = $Self->{SLAObject}->SLAList(
                        Valid     => 1,
                        ServiceID => $ServiceID,
                        UserID    => $Self->{UserID},
                    );
                    %SLAsForCustomerUser = ( %SLAsForCustomerUser, %SLAsForService );
                }

                # delete SLA from result if it is not configured for one of CustomerUsers
                for my $SLA ( keys %SLAs ) {
                    delete $SLAs{$SLA} if !$SLAsForCustomerUser{$SLA};
                }
            }
        }
        else {
            %SLAs = ();
        }
    }

    # if CustomerCompanyData is given AND KIXServiceCatalog installiert
    # -> get SLAs that are configured for ALL given CustomerIDs
    #------------------------------------------------------------------
    elsif ( $Param{CustomerCompanyData} && $Param{CustomerCompanyData} ne 'NONE' && $KIXServCatalogInstalled ) {
        my @CustomerUsers = ();
        my @CustomerCompanyList = split( ';', $Param{CustomerCompanyData} );
        if (@CustomerCompanyList) {
            for my $CustomerCompany (@CustomerCompanyList) {

                # get CustomerServiceSLA entries that have this CustomerID
                my @CustomerServiceSLAs = $Self->{ServiceObject}->CustomerServiceMemberSearch(
                    CustomerID => $CustomerCompany,
                    Result     => 'HASH',
                );

                # get SLAs for this CustomerCompany (CustomerID)
                my %SLAsForCustomerCompany = ();
                for my $CatalogEntry (@CustomerServiceSLAs) {
                    next if ( ref($CatalogEntry) ne 'HASH' );
                    if ( $CatalogEntry->{SLAID} ) {
                        $SLAsForCustomerCompany{ $CatalogEntry->{SLAID} } = 1,
                    }
                }

                # delete SLA from result if it is not configured for one of CustomerIDs
                for my $SLA ( keys %SLAs ) {
                    delete $SLAs{$SLA} if !$SLAsForCustomerCompany{$SLA};
                }
            }
        }
        else {
            %SLAs = ();
        }
    }

    # get SLAs for DEFAULT-Services
    my %SLAsForDefaultServices = ();
    if ( !$KIXServCatalogInstalled ) {
        my %DefaultServices = $Self->{ServiceObject}->CustomerUserServiceMemberList(
            CustomerUserLogin => '<DEFAULT>',
            Result            => 'HASH',
            DefaultServices   => 0,
        );
        for my $ServiceID ( keys %DefaultServices ) {
            my %SLAsForService = $Self->{SLAObject}->SLAList(
                Valid     => 1,
                ServiceID => $ServiceID,
                UserID    => $Self->{UserID},
            );
            %SLAsForDefaultServices = ( %SLAsForDefaultServices, %SLAsForService );
        }
    }
    else {
        my @CustomerServiceSLAs = $Self->{ServiceObject}->CustomerServiceMemberSearch(
            CustomerID => 'DEFAULT',
            Result     => 'HASH',
        );
        for my $CatalogEntry (@CustomerServiceSLAs) {
            next if ( ref($CatalogEntry) ne 'HASH' );
            if ( $CatalogEntry->{SLAID} ) {
                $SLAsForDefaultServices{ $CatalogEntry->{SLAID} }
                    = $AllValidSLAs{ $CatalogEntry->{SLAID} },
            }
        }
    }
    %SLAs = ( %SLAs, %SLAsForDefaultServices );

    # workaround, all auto completion requests get posted by utf8 anyway
    # convert any to 8bit string if application is not running in utf8
#    if ( !$Self->{EncodeObject}->EncodeInternalUsed() ) {
#        $Param{Search} = $Self->{EncodeObject}->Convert(
#            Text => $Param{Search},
#            From => 'utf-8',
#            To   => $Self->{LayoutObject}->{UserCharset},
#        );
#    }

    $Param{Search} =~ s/\_/\./g;
    $Param{Search} =~ s/\%/\.\*/g;
    $Param{Search} =~ s/\*/\.\*/g;

    # build data
    my %Data;
    for my $SLAID ( keys %SLAs ) {
        if ( $SLAs{$SLAID} =~ /$Param{Search}/i ) {
            $Data{$SLAID} = $SLAs{$SLAID};
        }
    }

    return %Data;
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
