# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2023 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketPrintForwardFax;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::GeneralCatalog',
    'Kernel::System::FwdLinkedObjectData',
    'Kernel::System::PDF',
    'Kernel::System::CustomerUser',
    'Kernel::System::User',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Web::Request',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    foreach ( keys %Param ) {
        $Self->{$_} = $Param{$_};
    }

    $Self->{GeneralCatalogObject} = $Kernel::OM->Get('Kernel::System::GeneralCatalog');
    $Self->{CustomerUserObject}   = $Kernel::OM->Get('Kernel::System::CustomerUser');
    $Self->{UserObject}           = $Kernel::OM->Get('Kernel::System::User');
    $Self->{PDFObject}            = $Kernel::OM->Get('Kernel::System::PDF');
    $Self->{LogObject}            = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{ConfigObject}         = $Kernel::OM->Get('Kernel::Config');
    $Self->{TicketObject}         = $Kernel::OM->Get('Kernel::System::Ticket');
    $Self->{TimeObject}           = $Kernel::OM->Get('Kernel::System::Time');
    $Self->{LayoutObject}         = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    $Self->{ParamObject}          = $Kernel::OM->Get('Kernel::System::Web::Request');
    $Self->{DynamicFieldObject}   = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{BackendObject}        = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    $Self->{Config} = $Self->{ConfigObject}->Get("Ticket::Frontend::$Self->{Action}");

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output;
    my $QueueID = $Self->{TicketObject}->TicketQueueID( TicketID => $Self->{TicketID} );

    # check needed stuff
    if ( !$Self->{TicketID} || !$QueueID ) {
        return $Self->{LayoutObject}->Error( Message => 'Need TicketID!' );
    }

    # check permissions
    if (
        !$Self->{TicketObject}->TicketPermission(
            Type     => 'ro',
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID}
        )
    ) {

        # error screen, don't show ticket
        return $Self->{LayoutObject}->NoPermission( WithHeader => 'yes' );
    }

    # get content
    my %Ticket = $Self->{TicketObject}->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # lookup criticality
    $Ticket{Criticality} = '-';
    if ( $Ticket{DynamicField_TicketFreeText13} ) {

        # get criticality list
        my $CriticalityList = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Criticality',
        );
        $Ticket{Criticality} = $CriticalityList->{ $Ticket{DynamicField_TicketFreeText13} };
    }

    # lookup impact
    $Ticket{Impact} = '-';
    if ( $Ticket{DynamicField_TicketFreeText14} ) {

        # get impact list
        my $ImpactList = $Self->{GeneralCatalogObject}->ItemList(
            Class => 'ITSM::Core::Impact',
        );
        $Ticket{Impact} = $ImpactList->{ $Ticket{DynamicField_TicketFreeText14} };
    }

    # for this purpose - print only this article
    my $RelevantFwdArticleTypesRef =
        $Self->{ConfigObject}->Get('ExternalSupplierForwarding::RelevantFwdArticleTypes');
    my @ArticleBoxRelevantFwdArticleTypes = $Self->{TicketObject}->ArticleContentIndex(
        TicketID    => $Self->{TicketID},
        ArticleType => $RelevantFwdArticleTypesRef,
        UserID      => $Self->{UserID} || 1,
    );

    # get article data
    my @Articles = $Self->{TicketObject}->ArticleGet(
        TicketID => $Self->{TicketID},
    );

    if ( !$Self->{Subaction} ) {

        # show form
        return $Self->_Mask(
            Articles         => \@Articles,
            SelectedArticles => \@ArticleBoxRelevantFwdArticleTypes,
            TicketTitle      => $Ticket{Title},
            TicketNumber     => $Ticket{TicketNumber},
            TicketID         => $Self->{TicketID},
        );
    }

    my @ArticleBox = ();

    for my $Article (@Articles) {
        if (
            $Self->{ParamObject}->GetParam(
                Param => 'Print_' . $Article->{ArticleID},
            )
        ) {
            push( @ArticleBox, $Article );
        }
    }

    # user info
    my %UserInfo = $Self->{UserObject}->GetUserData(
        User   => $Ticket{Owner},
        Cached => 1
    );

    # responsible info
    my %ResponsibleInfo;
    if ( $Self->{ConfigObject}->Get('Ticket::Responsible') && $Ticket{Responsible} ) {
        %ResponsibleInfo = $Self->{UserObject}->GetUserData(
            User   => $Ticket{Responsible},
            Cached => 1
        );
    }

    # customer info
    my %CustomerData = ();
    if ( $Ticket{CustomerUserID} ) {
        %CustomerData = $Self->{CustomerUserObject}->CustomerUserDataGet(
            User => $Ticket{CustomerUserID},
        );
    }
    elsif ( $Ticket{CustomerID} ) {
        %CustomerData = $Self->{CustomerUserObject}->CustomerUserDataGet(
            CustomerID => $Ticket{CustomerID},
        );
    }

    # do some html quoting
    $Ticket{Age} = $Self->{LayoutObject}->CustomerAge( Age => $Ticket{Age}, Space => ' ' );
    if ( $Ticket{UntilTime} ) {
        $Ticket{PendingUntil} = $Self->{LayoutObject}->CustomerAge(
            Age   => $Ticket{UntilTime},
            Space => ' ',
        );
    }
    else {
        $Ticket{PendingUntil} = '-';
    }

    # generate pdf output
    if ( $Self->{PDFObject} ) {
        my $PrintedBy = $Self->{LayoutObject}->{LanguageObject}->Translate('printed by');

        #my $Time = $Self->{LayoutObject}->Output( Template => '$Env{"Time"}' );
        my $Time = $Self->{LayoutObject}->{LanguageObject}->Time(
            Action => 'GET',
            Format => 'DateFormat',
        );
        my %Page;

        # get maximum number of pages
        $Page{MaxPages} = $Self->{ConfigObject}->Get('PDF::MaxPages');
        if ( !$Page{MaxPages} || $Page{MaxPages} < 1 || $Page{MaxPages} > 1000 ) {
            $Page{MaxPages} = 100;
        }

        my $HeaderRight  = $Self->{ConfigObject}->Get('Ticket::Hook') . $Ticket{TicketNumber};
        my $HeadlineLeft = $HeaderRight;
        my $Title        = $HeaderRight;
        if ( $Ticket{Title} ) {
            $HeadlineLeft = $Ticket{Title};
            $Title .= ' / ' . $Ticket{Title};
        }

        $Page{MarginTop}    = 30;
        $Page{MarginRight}  = 40;
        $Page{MarginBottom} = 40;
        $Page{MarginLeft}   = 40;
        $Page{HeaderRight}  = $HeaderRight;
        $Page{FooterLeft}   = '';
        $Page{PageText}     = $Self->{LayoutObject}->{LanguageObject}->Translate('Page');
        $Page{PageCount}    = 1;
        $Page{HeadlineLeft} = $HeadlineLeft;
        $Page{HeadlineRight}
            = $PrintedBy . ' '
            . $Self->{UserFirstname} . ' '
            . $Self->{UserLastname} . ' ('
            . $Self->{UserEmail} . ') '
            . $Time;

        # create new pdf document
        $Self->{PDFObject}->DocumentNew(
            Title  => $Self->{ConfigObject}->Get('Product') . ': ' . $Title,
            Encode => $Self->{LayoutObject}->{UserCharset},
        );

        # create first pdf page
        $Self->{PDFObject}->PageNew(
            %Page, FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
        );
        $Page{PageCount}++;

        $Self->_PDFOutputFaxHeader(
            PageData   => \%Page,
            TicketData => \%Ticket,
        );

        # output ticket infos
        $Self->_PDFOutputTicketInfos(
            PageData        => \%Page,
            TicketData      => \%Ticket,
            UserData        => \%UserInfo,
            ResponsibleData => \%ResponsibleInfo,
        );

        # output ticket dynamic fields
        $Self->_PDFOutputTicketDynamicFields(
            PageData   => \%Page,
            TicketData => \%Ticket,
        );

        # output customer data
        $Self->_PDFOutputCustomerInfos(
            PageData     => \%Page,
            CustomerData => \%CustomerData,
        );

        # output articles
        $Self->_PDFOutputArticles(
            PageData    => \%Page,
            ArticleData => \@ArticleBox,
        );

        # output linked CI-data
        $Self->_PDFOutputLinkedCIData(
            PageData => \%Page,
            TicketID => $Self->{TicketID},
        );

        # return the pdf document
        my $Filename = 'ForwardFAX_' . $Ticket{TicketNumber};
        my ( $s, $m, $h, $D, $M, $Y ) = $Self->{TimeObject}->SystemTime2Date(
            SystemTime => $Self->{TimeObject}->SystemTime(),
        );
        $M = sprintf( "%02d", $M );
        $D = sprintf( "%02d", $D );
        $h = sprintf( "%02d", $h );
        $m = sprintf( "%02d", $m );
        my $PDFString = $Self->{PDFObject}->DocumentOutput();
        return $Self->{LayoutObject}->Attachment(
            Filename    => $Filename . "_" . "$Y-$M-$D.pdf",
            ContentType => "application/pdf",
            Content     => $PDFString,
            Type        => 'attachment',
        );
    }

    # generate html output
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "AgentTicketPrintForwardFax: no PDFObject available!"
        );

        return $Self->{LayoutObject}->Error(
            Message => 'Function not available - contact your KIX-Admin '
                . 'to have PDF-print enabled.',
        );

    }

}

sub _PDFOutputFaxHeader {
    my ($Self, %Param) = @_;

    # check needed stuff
    foreach (qw(PageData TicketData)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    my %Ticket = %{ $Param{TicketData} };
    my %Page   = %{ $Param{PageData} };

    $Self->{PDFObject}->PositionSet(
        Move => 'absolut',
        Y    => 'top',
        X    => 'left',
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -10,
    );

    my %FwdFaxQueues =
        %{ $Self->{ConfigObject}->Get('ExternalSupplierForwarding::ForwardFaxQueues') };

    $Self->{PDFObject}->Text(
        Text     => $Self->{ConfigObject}->Get('OrganizationLong'),
        Width    => 250,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 6,
        Color    => '#000000',
        Align    => 'left',
        Lead     => 2,
    );
    $Self->{PDFObject}->Text(
        Text     => $Self->{LayoutObject}->{LanguageObject}->Translate('Fax to'),
        Width    => 250,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 13,
        Color    => '#000000',
        Align    => 'left',
        Lead     => 1,
    );
    if ( $FwdFaxQueues{ $Ticket{Queue} } ) {
        $Self->{PDFObject}->PositionSet(
            Move => 'relativ',
            Y    => -15,
        );
        $Self->{PDFObject}->Text(
            Text     => $FwdFaxQueues{ $Ticket{Queue} },
            Width    => 250,
            Type     => 'Cut',
            Font     => 'Proportional',
            FontSize => 15,
            Color    => '#000000',
            Align    => 'left',
            Lead     => 1,
        );
    }

    #print the senders information...
    $Self->{PDFObject}->PositionSet(
        Move => 'absolut',
        Y    => 'top',
        X    => 'center',
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -10,
        X    => 50,
    );
    $Self->{PDFObject}->Text(
        Text     => $Self->{ConfigObject}->Get('Organization') . " Service Desk",
        Width    => 250,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 10,
        Color    => '#000000',
        Align    => 'left',
        Lead     => 1,
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -15,
    );
    $Self->{PDFObject}->Text(
        Text => $Self->{UserFirstname} . ' '
            . $Self->{UserLastname} . ' ('
            . $Self->{UserEmail} . ')',
        ,
        Width    => 250,
        Type     => 'Cut',
        Font     => 'ProportionalBold',
        FontSize => 10,
        Color    => '#000000',
        Align    => 'left',
        Lead     => 1,
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -15,
    );
    $Self->{PDFObject}->Text(
        Text     => $Self->{ConfigObject}->Get('OrganizationHotline1'),
        Width    => 250,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 11,
        Color    => '#000000',
        Align    => 'left',
        Lead     => 1,
    );
    $Self->{PDFObject}->Text(
        Text     => $Self->{ConfigObject}->Get('OrganizationHotline2'),
        Width    => 250,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 11,
        Color    => '#000000',
        Align    => 'left',
        Lead     => 1,
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -15,
    );

    my $Time = $Self->{LayoutObject}->{LanguageObject}->Time(
        Action => 'GET',
        Format => 'DateFormat',
    );
    $Self->{PDFObject}->Text(
        Text     => $Time,            #$Self->{LayoutObject}->Output( Template => $Time ),
        Width    => 250,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 11,
        Color    => '#000000',
        Align    => 'left',
        Lead     => 1,
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'absolut',
        X    => 'left',
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -15,
    );
    my $Result = $Self->{PDFObject}->Text(
        Text => $Self->{LayoutObject}->{LanguageObject}->Translate('Order for Incident Processing'),
        Width    => 400,
        Type     => 'Cut',
        Font     => 'ProportionalBold',
        FontSize => 14,
        Color    => '#000000',
        Align    => 'left',
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'absolut',
        Y    => 'top',
        X    => 'left',
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -140,
    );

    return 1;
}

sub _PDFOutputTicketInfos {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(PageData TicketData UserData)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    my %Ticket   = %{ $Param{TicketData} };
    my %UserInfo = %{ $Param{UserData} };
    my %Page     = %{ $Param{PageData} };

    # create left table
    my $TableLeft = [
        {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('Ticket#') . ':',
            Value => $Ticket{TicketNumber},
        },
        {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('Priority') . ':',
            Value => $Self->{LayoutObject}->{LanguageObject}->Translate( $Ticket{Priority} ),
        },
        {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('CustomerID') . ':',
            Value => $Ticket{CustomerID},
        },
        {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('Owner') . ':',
            Value => $Ticket{Owner} . ' ('
                . $UserInfo{UserFirstname} . ' '
                . $UserInfo{UserLastname} . ')',
        },
    ];

    # add type row, if feature is enabled
    if ( $Self->{ConfigObject}->Get('Ticket::Type') ) {
        my $Row = {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('Type') . ':',
            Value => $Ticket{Type},
        };
        push( @{$TableLeft}, $Row );
    }

    # add service and sla row, if feature is enabled
    if ( $Self->{ConfigObject}->Get('Ticket::Service') ) {
        my $RowService = {
            Key => $Self->{LayoutObject}->{LanguageObject}->Translate('Service') . ':',
            Value => $Ticket{Service} || '-',
        };
        push( @{$TableLeft}, $RowService );
        my $RowSLA = {
            Key => $Self->{LayoutObject}->{LanguageObject}->Translate('SLA') . ':',
            Value => $Ticket{SLA} || '-',
        };
        push( @{$TableLeft}, $RowSLA );
    }

    # create right table
    my $TableRight = [
        {
            Key => $Self->{LayoutObject}->{LanguageObject}->Translate('Created') . ':',

            #Value => $Self->{LayoutObject}->Output(
            #Template => '$TimeLong{"$Data{"Created"}"}',
            #Data     => \%Ticket,
            #),
            Value => $Self->{LayoutObject}->{LanguageObject}
                ->FormatTimeString( $Ticket{Created}, "DateFormatLong" ),
        },
        {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('Criticality') . ':',
            Value => $Self->{LayoutObject}->{LanguageObject}->Translate( $Ticket{Criticality} ),
        },
        {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('Impact') . ':',
            Value => $Self->{LayoutObject}->{LanguageObject}->Translate( $Ticket{Impact} ),
        },
        {
            Key   => $Self->{LayoutObject}->{LanguageObject}->Translate('Priority') . ':',
            Value => $Self->{LayoutObject}->{LanguageObject}->Translate( $Ticket{Priority} ),
        },
    ];

    # add solution time row
    if ( defined( $Ticket{SolutionTime} ) ) {
        my $Row = {
            Key => $Self->{LayoutObject}->{LanguageObject}->Translate('Solution Time') . ':',

            #Value => $Self->{LayoutObject}->Output(
            #Template => '$TimeShort{"$QData{"SolutionTimeDestinationDate"}"}',
            #Data     => \%Ticket,
            #),
            Value => $Self->{LayoutObject}->{LanguageObject}
                ->FormatTimeString( $Ticket{Created}, "DateFormatShort" )
        };
        push( @{$TableRight}, $Row );
    }

    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -50,
    );

    # output headline
    $Self->{PDFObject}->Text(
        Text     => $Self->{LayoutObject}->{LanguageObject}->Translate('General Ticket Data'),
        Height   => 7,
        Type     => 'Cut',
        Font     => 'ProportionalBoldItalic',
        FontSize => 7,
        Color    => '#000000',
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -6,
    );

    my $Rows = @{$TableLeft};
    if ( @{$TableRight} > $Rows ) {
        $Rows = @{$TableRight};
    }

    my %TableParam;
    foreach my $Row ( 1 .. $Rows ) {
        $Row--;
        $TableParam{CellData}[$Row][0]{Content}         = $TableLeft->[$Row]->{Key};
        $TableParam{CellData}[$Row][0]{Font}            = 'ProportionalBold';
        $TableParam{CellData}[$Row][1]{Content}         = $TableLeft->[$Row]->{Value};
        $TableParam{CellData}[$Row][2]{Content}         = ' ';
        $TableParam{CellData}[$Row][2]{BackgroundColor} = '#FFFFFF';
        $TableParam{CellData}[$Row][3]{Content}         = $TableRight->[$Row]->{Key};
        $TableParam{CellData}[$Row][3]{Font}            = 'ProportionalBold';
        $TableParam{CellData}[$Row][4]{Content}         = $TableRight->[$Row]->{Value};
    }

    $TableParam{ColumnData}[0]{Width} = 80;
    $TableParam{ColumnData}[1]{Width} = 170.5;
    $TableParam{ColumnData}[2]{Width} = 4;
    $TableParam{ColumnData}[3]{Width} = 80;
    $TableParam{ColumnData}[4]{Width} = 170.5;

    $TableParam{Type}                = 'Cut';
    $TableParam{Border}              = 0;
    $TableParam{FontSize}            = 6;
    $TableParam{BackgroundColorEven} = '#FFFFFF';
    $TableParam{BackgroundColorOdd}  = '#FFFFFF';
    $TableParam{Padding}             = 1;
    $TableParam{PaddingTop}          = 3;
    $TableParam{PaddingBottom}       = 3;

    # output table
    for ( $Page{PageCount} .. $Page{MaxPages} ) {

        # output table (or a fragment of it)
        %TableParam = $Self->{PDFObject}->Table(
            %TableParam,
        );

        # stop output or output next page
        if ( $TableParam{State} ) {
            last;
        }
        else {
            $Self->{PDFObject}->PageNew(
                %Page,
                FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
            );
            $Page{PageCount}++;
        }
    }
    return 1;
}

sub _PDFOutputTicketDynamicFields {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(PageData TicketData)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    my $Output = 0;
    my %Ticket = %{ $Param{TicketData} };
    my %Page   = %{ $Param{PageData} };

    my %TableParam;
    my $Row = 0;

    # get configuration - dynamic fields to be shown
    my $PDFOutputTicketDynamicFields
        = $Self->{ConfigObject}->Get('ExternalSupplierForwarding::PDFOutputTicketDynamicFields');

    # get dynamic fields data
    if (
        $PDFOutputTicketDynamicFields
        && ( ref($PDFOutputTicketDynamicFields) eq 'HASH' )
        && %{$PDFOutputTicketDynamicFields}
    ) {
        foreach my $DField ( keys %{$PDFOutputTicketDynamicFields} ) {
            if (
                $PDFOutputTicketDynamicFields->{$DField}
                && $Ticket{"DynamicField_$DField"}
                && $Ticket{"DynamicField_$DField"} ne ""
            ) {
                my $DynamicField = $Self->{DynamicFieldObject}->DynamicFieldGet(
                    Name => $DField,
                );
                my $ValueStrg = $Self->{BackendObject}->DisplayValueRender(
                    DynamicFieldConfig => $DynamicField,
                    LayoutObject       => $Self->{LayoutObject},
                    HTMLOutput         => 0,
                    Value              => $Ticket{"DynamicField_$DField"},
                );

                $TableParam{CellData}[$Row][0]{Content}
                    = $Self->{LayoutObject}->{LanguageObject}->Translate( $DynamicField->{Label} )
                    . ':';
                $TableParam{CellData}[$Row][0]{Font}    = 'ProportionalBold';
                $TableParam{CellData}[$Row][1]{Content} = $ValueStrg->{Value};
                $Row++;
                $Output = 1;
            }
        }
    }

    $TableParam{ColumnData}[0]{Width} = 80;
    $TableParam{ColumnData}[1]{Width} = 431;

    # output ticket dynamic fields
    if ($Output) {

        # set new position
        $Self->{PDFObject}->PositionSet(
            Move => 'relativ',
            Y    => -15,
        );

        # output headline
        $Self->{PDFObject}->Text(
            Text => $Self->{LayoutObject}->{LanguageObject}->Translate('Dynamic fields')
                || 'Dynamic fields',
            Height   => 7,
            Type     => 'Cut',
            Font     => 'ProportionalBoldItalic',
            FontSize => 7,
            Color    => '#000000',
        );

        # set new position
        $Self->{PDFObject}->PositionSet(
            Move => 'relativ',
            Y    => -4,
        );

        # table params
        $TableParam{Type}            = 'Cut';
        $TableParam{Border}          = 0;
        $TableParam{FontSize}        = 6;
        $TableParam{BackgroundColor} = '#FFFFFF';
        $TableParam{Padding}         = 1;
        $TableParam{PaddingTop}      = 3;
        $TableParam{PaddingBottom}   = 3;

        # output table
        for ( $Page{PageCount} .. $Page{MaxPages} ) {

            # output table (or a fragment of it)
            %TableParam = $Self->{PDFObject}->Table( %TableParam, );

            # stop output or output next page
            if ( $TableParam{State} ) {
                last;
            }
            else {
                $Self->{PDFObject}->PageNew(
                    %Page, FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
                );
                $Page{PageCount}++;
            }
        }
    }
    return 1;
}

sub _PDFOutputCustomerInfos {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(PageData CustomerData)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }
    my $Output       = 0;
    my %CustomerData = %{ $Param{CustomerData} };
    my %Page         = %{ $Param{PageData} };
    my %TableParam;
    my $Row = 0;
    my $Map = $CustomerData{Config}->{Map};

    # check if customer company support is enabled
    if ( $CustomerData{Config}->{CustomerCompanySupport} ) {
        my $Map2 = $CustomerData{CompanyConfig}->{Map};
        if ($Map2) {
            push( @{$Map}, @{$Map2} );
        }
    }

    # Remove blacklisted fields
    my $CustomerUserAttrBlacklist =
        $Self->{ConfigObject}->Get('ExternalSupplierForwarding::CustomerUserAttrBlacklist') || '';

    # EO Remove blacklisted fields

    # get number of displayed rows
    foreach my $Field ( @{$Map} ) {

        # Remove blacklisted fields
        if ( $CustomerUserAttrBlacklist && ref($CustomerUserAttrBlacklist) eq 'ARRAY' ) {
            next if ( grep { $_ eq ${$Field}[0]; } @{$CustomerUserAttrBlacklist} );
        }

        # EO Remove blacklisted fields
        if ( ${$Field}[3] && $CustomerData{ ${$Field}[0] } ) {
            $Row++;
        }
    }

    my $ColumnSplit = $Row / 2;
    my $LabelColumn = 0;
    my $ValueColumn = 1;
    $Row = 0;
    foreach my $Field ( @{$Map} ) {

        # Remove blacklisted fields
        if ( $CustomerUserAttrBlacklist && ref($CustomerUserAttrBlacklist) eq 'ARRAY' ) {
            next if ( grep { $_ eq ${$Field}[0]; } @{$CustomerUserAttrBlacklist} );
        }

        # EO Remove blacklisted fields
        if ( ${$Field}[3] && $CustomerData{ ${$Field}[0] } ) {
            $TableParam{CellData}[$Row][$LabelColumn]{Content} =
                $Self->{LayoutObject}->{LanguageObject}->Translate( ${$Field}[1] ) . ':';
            $TableParam{CellData}[$Row][$LabelColumn]{Font}    = 'ProportionalBold';
            $TableParam{CellData}[$Row][$ValueColumn]{Content} = $CustomerData{ ${$Field}[0] };

            $Row++;
            if ( $Row >= $ColumnSplit ) {
                $LabelColumn = 3;
                $ValueColumn = 4;
                $Row         = 0;
            }
            $Output = 1;
        }
    }
    $TableParam{ColumnData}[0]{Width} = 80;
    $TableParam{ColumnData}[1]{Width} = 170.5;
    $TableParam{ColumnData}[2]{Width} = 4;
    $TableParam{ColumnData}[3]{Width} = 80;
    $TableParam{ColumnData}[4]{Width} = 170.5;

    if ($Output) {

        # set new position
        $Self->{PDFObject}->PositionSet(
            Move => 'relativ',
            Y    => -15,
        );

        # output headline
        $Self->{PDFObject}->Text(
            Text     => $Self->{LayoutObject}->{LanguageObject}->Translate('Contact information'),
            Height   => 7,
            Type     => 'Cut',
            Font     => 'ProportionalBoldItalic',
            FontSize => 7,
            Color    => '#000000',
        );

        # set new position
        $Self->{PDFObject}->PositionSet(
            Move => 'relativ',
            Y    => -4,
        );

        # table params
        $TableParam{Type}            = 'Cut';
        $TableParam{Border}          = 0;
        $TableParam{FontSize}        = 6;
        $TableParam{BackgroundColor} = '#FFFFFF';
        $TableParam{Padding}         = 1;
        $TableParam{PaddingTop}      = 3;
        $TableParam{PaddingBottom}   = 3;

        # output table
        for ( $Page{PageCount} .. $Page{MaxPages} ) {

            # output table (or a fragment of it)
            %TableParam = $Self->{PDFObject}->Table( %TableParam, );

            # stop output or output next page
            if ( $TableParam{State} ) {
                last;
            }
            else {
                $Self->{PDFObject}->PageNew(
                    %Page, FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
                );
                $Page{PageCount}++;
            }
        }
    }
    return 1;
}

sub _PDFOutputArticles {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(PageData ArticleData)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $Needed!" );
            return;
        }
    }
    my %Page = %{ $Param{PageData} };

    my $FirstArticle = 1;
    foreach my $ArticleTmp ( @{ $Param{ArticleData} } ) {
        if ($FirstArticle) {
            $Self->{PDFObject}->PositionSet(
                Move => 'relativ',
                Y    => -15,
            );

            # output headline
            $Self->{PDFObject}->Text(
                Text =>
                    $Self->{LayoutObject}->{LanguageObject}->Translate('First Customer Article'),
                Height   => 7,
                Type     => 'Cut',
                Font     => 'ProportionalBoldItalic',
                FontSize => 7,
                Color    => '#000000',
            );
            $Self->{PDFObject}->PositionSet(
                Move => 'relativ',
                Y    => 2,
            );
            $FirstArticle = 0;
        }

        my %Article = %{$ArticleTmp};

        # get attachment string
        my %AtmIndex = ();
        if ( $Article{Atms} ) {
            %AtmIndex = %{ $Article{Atms} };
        }
        my $Attachments;
        for my $FileID ( sort keys %AtmIndex ) {
            my %File = %{ $AtmIndex{$FileID} };
            $Attachments .= $File{Filename} . ' (' . $File{Filesize} . ")\n";
        }

        # generate article info table
        my %TableParam1;
        my $Row = 0;
        foreach (qw(From Subject)) {
            if ( $Article{$_} ) {
                $TableParam1{CellData}[$Row][0]{Content} =
                    $Self->{LayoutObject}->{LanguageObject}->Translate($_) . ':';
                $TableParam1{CellData}[$Row][0]{Font}    = 'ProportionalBold';
                $TableParam1{CellData}[$Row][1]{Content} = $Article{$_};
                $Row++;
            }
        }
        $TableParam1{CellData}[$Row][0]{Content} =
            $Self->{LayoutObject}->{LanguageObject}->Translate('Created') . ':';
        $TableParam1{CellData}[$Row][0]{Font} = 'ProportionalBold';

        $TableParam1{CellData}[$Row][1]{Content} =

            #$Self->{LayoutObject}->Output(
            #Template => '$TimeLong{"$Data{"Created"}"}',
            #Data     => \%Article,
            #);
            $Self->{LayoutObject}->{LanguageObject}
            ->FormatTimeString( $Article{Created}, "DateFormatLong" );
        $TableParam1{CellData}[$Row][1]{Content} .=
            ' ' . $Self->{LayoutObject}->{LanguageObject}->Translate('by');
        $TableParam1{CellData}[$Row][1]{Content} .= ' ' . $Article{SenderType};
        $Row++;

        foreach ( 1 .. 3 ) {
            if ( $Article{"ArticleFreeText$_"} ) {
                $TableParam1{CellData}[$Row][0]{Content} = $Article{"ArticleFreeKey$_"} . ':';
                $TableParam1{CellData}[$Row][0]{Font}    = 'ProportionalBold';
                $TableParam1{CellData}[$Row][1]{Content} = $Article{"ArticleFreeText$_"};
                $Row++;
            }
        }

        $TableParam1{CellData}[$Row][0]{Content} =
            $Self->{LayoutObject}->{LanguageObject}->Translate('Type') . ':';
        $TableParam1{CellData}[$Row][0]{Font}    = 'ProportionalBold';
        $TableParam1{CellData}[$Row][1]{Content} = $Article{ArticleType};
        $Row++;

        $TableParam1{ColumnData}[0]{Width} = 80;
        $TableParam1{ColumnData}[1]{Width} = 431;

        $Self->{PDFObject}->PositionSet(
            Move => 'relativ',
            Y    => -6,
        );

        # table params (article infos)
        $TableParam1{Type}            = 'Cut';
        $TableParam1{Border}          = 0;
        $TableParam1{FontSize}        = 6;
        $TableParam1{BackgroundColor} = '#FFFFFF';
        $TableParam1{Padding}         = 1;
        $TableParam1{PaddingTop}      = 3;
        $TableParam1{PaddingBottom}   = 3;

        # output table (article infos)
        for ( $Page{PageCount} .. $Page{MaxPages} ) {

            # output table (or a fragment of it)
            %TableParam1 = $Self->{PDFObject}->Table(
                %TableParam1,
            );

            # stop output or output next page
            if ( $TableParam1{State} ) {
                last;
            }
            else {
                $Self->{PDFObject}->PageNew(
                    %Page,
                    FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
                );
                $Page{PageCount}++;
            }
        }

        # table params (article body)
        my %TableParam2;
        $TableParam2{CellData}[0][0]{Content} = $Article{Body} || ' ';
        $TableParam2{Type}                    = 'Cut';
        $TableParam2{Border}                  = 0.5;
        $TableParam2{Font}                    = 'Monospaced';
        $TableParam2{FontSize}                = 7;
        $TableParam2{BackgroundColor}         = '#FFFFFF';
        $TableParam2{Padding}                 = 4;
        $TableParam2{PaddingTop}              = 8;
        $TableParam2{PaddingBottom}           = 8;

        # output table (article body)
        for ( $Page{PageCount} .. $Page{MaxPages} ) {

            # output table (or a fragment of it)
            %TableParam2 = $Self->{PDFObject}->Table(
                %TableParam2,
            );

            # stop output or output next page
            if ( $TableParam2{State} ) {
                last;
            }
            else {
                $Self->{PDFObject}->PageNew(
                    %Page,
                    FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
                );
                $Page{PageCount}++;
            }
        }
    }
    return 1;
}

sub _PDFOutputLinkedCIData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(PageData TicketID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
    my %Page = %{ $Param{PageData} };

    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -15,
    );

    # output headline
    $Self->{PDFObject}->Text(
        Text     => $Self->{LayoutObject}->{LanguageObject}->Translate('Related CI Data'),
        Height   => 7,
        Type     => 'Cut',
        Font     => 'ProportionalBoldItalic',
        FontSize => 7,
        Color    => '#000000',
    );
    $Self->{PDFObject}->PositionSet(
        Move => 'relativ',
        Y    => -6,
    );

    # table params...
    my %TableParam2;
    $TableParam2{CellData}[0][0]{Content} =
        $Kernel::OM->Get('Kernel::System::FwdLinkedObjectData')
        ->BuildFwdContent( TicketID => $Param{TicketID}, ) || ' ';
    $TableParam2{Type}            = 'Cut';
    $TableParam2{Border}          = 0.5;
    $TableParam2{Font}            = 'Monospaced';
    $TableParam2{FontSize}        = 7;
    $TableParam2{BackgroundColor} = '#ffffff';
    $TableParam2{Padding}         = 4;
    $TableParam2{PaddingTop}      = 8;
    $TableParam2{PaddingBottom}   = 8;

    # output table related CI data...
    for ( $Page{PageCount} .. $Page{MaxPages} ) {

        # output table (or a fragment of it)
        %TableParam2 = $Self->{PDFObject}->Table(
            %TableParam2,
        );

        # stop output or output next page
        if ( $TableParam2{State} ) {
            last;
        }
        else {
            $Self->{PDFObject}->PageNew(
                %Page,
                FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
            );
            $Page{PageCount}++;
        }
    }
    return 1;
}

sub _Mask {
    my ( $Self, %Param ) = @_;
    my $Output;

    # print header

    $Output .= $Self->{LayoutObject}->Header(
        Type => 'Small',
    );

    my @Articles         = @{ $Param{Articles} };
    my @SelectedArticles = @{ $Param{SelectedArticles} };
    my @SelectedArticlesIDs;
    my @ShownArticleAttributes = @{ $Self->{Config}->{ShownArticleAttributes} };

    for my $Article (@SelectedArticles) {
        push( @SelectedArticlesIDs, $Article->{ArticleID} );

    }

    my $Count = 1;

    for my $Attribute (@ShownArticleAttributes) {

        $Self->{LayoutObject}->Block(
            Name => 'ArticleHead',
            Data => {
                Attribute => $Attribute,
            },
        );
    }

    # show each article
    for my $Article (@Articles) {
        my $ArticleID = $Article->{ArticleID};
        my $Selected  = '';

        if ( grep { $_ eq $ArticleID } @SelectedArticlesIDs ) {
            $Selected = 'checked';
        }

        $Self->{LayoutObject}->Block(
            Name => 'ArticleRow',
            Data => {
                ArticleID      => $ArticleID,
                ArticleSubject => $Article->{Subject},
                Count          => $Count++,
                Selected       => $Selected,
            },
        );

        for my $Attribute (@ShownArticleAttributes) {

            $Self->{LayoutObject}->Block(
                Name => 'ArticleDataRow',
                Data => {
                    Attribute => $Article->{$Attribute},
                },
            );
        }
    }

    $Output .=
        $Self->{LayoutObject}
        ->Output( TemplateFile => 'AgentTicketPrintForwardFax', Data => \%Param );
    $Output .= $Self->{LayoutObject}->Footer(
        Type => 'Small',
    );

    return $Output;
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
