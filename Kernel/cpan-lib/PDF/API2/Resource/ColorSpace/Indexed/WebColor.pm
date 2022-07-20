package PDF::API2::Resource::ColorSpace::Indexed::WebColor;

use base 'PDF::API2::Resource::ColorSpace::Indexed';

use strict;
use warnings;

our $VERSION = '2.043'; # VERSION

use PDF::API2::Basic::PDF::Utils;
use PDF::API2::Util;
use Scalar::Util qw(weaken);

sub new {
    my ($class, $pdf) = @_;

    $class = ref($class) if ref($class);
    my $self = $class->SUPER::new($pdf, pdfkey());
    $pdf->new_obj($self) unless $self->is_obj($pdf);
    $self->{' apipdf'} = $pdf;
    weaken $self->{' apipdf'};

    my $csd = PDFDict();
    $pdf->new_obj($csd);

    $csd->{'Filter'} = PDFArray(PDFName('ASCIIHexDecode'));
    $csd->{' stream'} = '';

    # 0-215
    foreach my $r (0, 0x33, 0x66, 0x99, 0xCC, 0xFF) {
        foreach my $g (0, 0x33, 0x66, 0x99, 0xCC, 0xFF) {
            foreach my $b (0, 0x33, 0x66, 0x99, 0xCC, 0xFF) {
                $csd->{' stream'} .= pack('CCC', $r, $g, $b);
            }
        }
    }

    # 216-231
    foreach my $r (   0, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                   0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF)
    {
        $csd->{' stream'} .= pack('CCC', $r, $r, $r);
    }

    # 232-247
    foreach my $r (   0, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                   0x88, 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF)
    {
        $csd->{' stream'} .= pack('CCC',
                                  map { $_ * 255 }
                                  namecolor('!' . sprintf('%02X', $r) . 'FFFF'));
    }

    # 248-255
    foreach my $r (0, 0x22, 0x44, 0x66, 0x88, 0xAA, 0xCC, 0xEE) {
        $csd->{' stream'} .= pack('CCC',
                                  map { $_ * 255 }
                                  namecolor('!' . sprintf('%02X', $r) . 'FF99'));
    }

    $csd->{' stream'} .= "\x00" x 768;
    $csd->{' stream'} = substr($csd->{' stream'}, 0, 768);

    $self->add_elements(PDFName('DeviceRGB'), PDFNum(255), $csd);
    $self->{' csd'} = $csd;

    return $self;
}

1;
