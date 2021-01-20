# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::Config::Files::ZZZAAuto;

# get needed objects
my $ConfigObject = $Kernel::OM->GetNew('Kernel::Config');
my $MainObject   = $Kernel::OM->GetNew('Kernel::System::Main');

# define needed variables
my $Directory   = $ConfigObject->Get('Home') . "/Kernel/Config/Files/";
my @ConfigFiles = $MainObject->DirectoryRead(
    Directory => $Directory,
    Filter    => "*.xml",
);
my %AllowedConfigFiles = (
    'FAQ.xml'            	=> 1,
    'Framework.xml'         => 1,
    'GenericInterface.xml'  => 1,
    'ITSM.xml'    			=> 1,
    'ProcessManagement.xml' => 1,
    'Ticket.xml'            => 1,
);
my %CheckSubEntries = (
    'Frontend::Module'            => 1,
    'CustomerFrontend::Module'    => 1,
    'PublicFrontend::Module'      => 1,
    'Loader::Agent::CommonJS'     => 1,
    'Loader::Agent::CommonCSS'    => 1,
    'Loader::Customer::CommonJS'  => 1,
    'Loader::Customer::CommonCSS' => 1,
    'PreferencesGroups'           => 1,
);
my %IgnoreEntries = (
    'Frontend::CommonParam'         => 1,
    'CustomerFrontend::CommonParam' => 1,
    'PublicFrontend::CommonParam'   => 1,
);
my $DefaultConfig = {};
bless $DefaultConfig, 'Kernel::Config::Defaults';
$DefaultConfig->Kernel::Config::Defaults::LoadDefaults();
my $ZZZAAutoConfig = {};
bless $ZZZAAutoConfig, 'Kernel::Config::Files::ZZZAAuto';
Kernel::Config::Files::ZZZAAuto->Load($ZZZAAutoConfig);
my $StartTime;

# init test case
$Self->TestCaseStart(
    TestCase    => 'Default configuration',
    Feature     => 'Configuration',
    Story       => 'Default',
    Description => <<'END',
Check default configuration for changes
* Configurations have to be be the same in Defaults.pm and ZZZAAuto.pm
END
);

## TEST STEP
# check that there are no additional xml config files
my $CleanConfigDirectory = 1;
$StartTime               = $Self->GetMilliTimeStamp();
CONFIGFILE:
for my $ConfigFile (@ConfigFiles) {
    # get file name from path
    $ConfigFile =~ s{^.*/([^/]+.xml)$}{$1}xmsg;

    # check for allowed file
    if ( !$AllowedConfigFiles{$ConfigFile} ) {
        # set flag
        $CleanConfigDirectory = 0;

        last CONFIGFILE;
    }
}
my $Success = $Self->True(
    TestName  => 'Clean config directory',
    TestValue => $CleanConfigDirectory,
    StartTime => $StartTime,
);
return 1 if ( !$Success );
## EO TEST STEP

# process config entries
DEFAULTCONFIGENTRY:
for my $DefaultConfigEntry ( sort( keys( %{$DefaultConfig} ) ) ) {

    # ignore entries that only exist in default config
    next DEFAULTCONFIGENTRY if( !exists( $ZZZAAutoConfig->{$DefaultConfigEntry} ) );

    # ignore entries that are set to be ignored
    next DEFAULTCONFIGENTRY if( $IgnoreEntries{$DefaultConfigEntry} );

    # check if sub entries should be checked
    if ( $CheckSubEntries{$DefaultConfigEntry} ) {

        # process sub entries
        DEFAULTCONFIGSUBENTRY:
        for my $DefaultConfigSubEntry ( sort( keys( %{ $DefaultConfig->{$DefaultConfigEntry} } ) ) ){

            # ignore entries that only exist in default config
            next DEFAULTCONFIGSUBENTRY if( !exists( $ZZZAAutoConfig->{$DefaultConfigEntry}->{$DefaultConfigSubEntry} ) );

            ## TEST STEP
            # check structure of default config against ZZZAAuto
            $StartTime = $Self->GetMilliTimeStamp();
            $Self->IsDeeply(
                TestName   => $DefaultConfigEntry . '->' . $DefaultConfigSubEntry . ' have to be be the same in Defaults.pm and ZZZAAuto.pm',
                CheckValue => \$DefaultConfig->{$DefaultConfigEntry}->{$DefaultConfigSubEntry},
                TestValue  => \$ZZZAAutoConfig->{$DefaultConfigEntry}->{$DefaultConfigSubEntry},
                StartTime  => $StartTime,
            );
            ## EO TEST STEP
        }
    }
    # check entry
    else {
        ## TEST STEP
        # check structure of default config against ZZZAAuto
        $StartTime = $Self->GetMilliTimeStamp();
        $Self->IsDeeply(
            TestName   => $DefaultConfigEntry . ' have to be be the same in Defaults.pm and ZZZAAuto.pm',
            CheckValue => \$DefaultConfig->{$DefaultConfigEntry},
            TestValue  => \$ZZZAAutoConfig->{$DefaultConfigEntry},
            StartTime  => $StartTime,
        );
        ## EO TEST STEP
    }
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
