#
# Copyright (C) 2000 Oleg A. Paraschenko
# XML::Handler::PyxWriter is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package XML::Handler::PyxWriter;

use IO::File;
use strict;

use vars qw{ $VERSION };
$VERSION = "0.32";

#
# Create new instance of PYX writer.
#
sub new {
    my $class   =  shift;
    my $args    =  (scalar (@_) == 1) ? shift : { };
    my $self    =  {
	"AttrBeforeElement"  =>  1,
	"CompactAttrString"  =>  0,
	"ByteStream"         =>  undef,
	"SystemId"           =>  "-",
	%$args,
	_close_stream        =>  0
    };
    return  bless $self, $class;
}

#
# Start document.
#
sub start_document {
    my $self = shift;
    unless (defined $self->{"ByteStream"}) {
	my $fname  =  $self->{"SystemId"};
	my $fh     =  new IO::File ">$fname";
	die "XML::Handler::PyxWriter: can't create output stream named '$fname'\n" unless defined $fh;
	$self->{"ByteStream"}     =  $fh;
	$self->{"_close_stream"}  =  1;
    }
}

#
# End document.
#
sub _close_stream {
    my $self = shift;
    if ($self->{"_close_stream"}) {
	close $self->{"ByteStream"};
	$self->{"ByteStream"}    = undef;
	$self->{"_close_stream"} = 0;
    }
}

sub end_document {
    my $self = shift;
    $self->_close_stream ();
}

sub DESTROY {
    my $self = shift;
    $self->_close_stream ();
}

#
# Start element.
#
sub start_element {
    my ($self, $args) = @_;
    my $fh   = $self->{'ByteStream'};
    my $name = $args->{'Name'};
    my $atts = $args->{'Attributes'};
    my $foo  = $self->{'CompactAttrString'} ? ' ' : ' CDATA ';
    unless ($self->{'AttrBeforeElement'}) {
	_put_line ($fh, "($name");
    }
    while (my ($a, $v) = each %$atts) {
	next unless defined $v;
	_put_line ($fh, "A$a$foo$v");
    }
    if ($self->{'AttrBeforeElement'}) {
	_put_line ($fh, "($name");
    }
}

#
# End element.
#
sub end_element {
    my ($self, $args) = @_;
    my $fh    =  $self->{"ByteStream"};
    my $name  =  $args->{"Name"};
    _put_line ($fh, ")$name");
}

#
# Processing instruction.
#
sub processing_instruction {
    my ($self, $args) = @_;
    my $fh  =  $self->{"ByteStream"};
    my $t   =  $args->{"Target"};
    my $v   =  $args->{"Data"};
    $v = "" unless defined $v;
    _put_line ($fh, "?$t $v");
}

#
# Character data.
#
sub characters {
    my ($self, $args) = @_;
    my $fh    =  $self->{"ByteStream"};
    my $data  =  $args->{"Data"};
    _put_line ($fh, "-$data");
}

#
# Escape XML special characters and print.
#
sub _put_line {
    my ($fh, $str) = @_;
    $str =~ s/\\/\\\\/gsm;
    $str =~ s/\011/\\011/gsm;
    $str =~ s/\012/\\012/gsm;
    $str =~ s/\015/\\015/gsm;
    print $fh "$str\n";
}

1;

=head1 NAME

XML::Handler::PyxWriter -- convert Perl SAX events to ESIS of Nsgmls or
Pyxie.

=head1 SYNOPSIS

 use XML::Handler::PyxWriter;
 $writer = new XML::Handler::PyxWriter OPTIONS;
 $handler->parse(Handler => $writer);


=head1 DESCRIPTION

XML::Handler::PyxWriter is a Perl SAX module. It generates ESIS of Nsgmls
or  Pyxie. Behaviour of object is specified when the object is created. 

=head1 OPTIONS

=over

=item ByteStream

Output stream object with method "print" (for example, IO::File).

=item SystemId

Name of file passed to method "open" of IO::File.  If "ByteStream" is
defined then "SystemId" is ignored.  Default value of "SystemId" is "-".

=item AttrBeforeElement

Attributes are before element (1) or after  element (0). Default is 1
(before).

=item CompactAttrString

Attribute type is absent (1) or present (0). Default is 0 (present).

=back

=head1 RECOMMENDED VALUES

Probably you like to be compatible with Nsgmls or Pyxie. The main
difference is that Nsgmls has attributes before element and attribute
types. Pyxie has attributes after element and does not have attribute
types. By default XML::Parser::PyxWriter uses Nsgmls mode.

Recommended values for Nsgmls mode:

=over

=item *

AttrBeforeElement = 1

=item *

CompactAttrString = 0

=back

Recommended values for Pyxie mode:

=over

=item *

AttrBeforeElement = 0

=item *

CompactAttrString = 1

=back

=head1 OUTPUT STREAM

XML::Handler::PyxWriter produces these escape sequences:

=over

=item \

\\

=item [TAB]

\011

=item [LF]

\012

=item [CR]

\015

=back

=head1 AUTHOR

Oleg A. Paraschenko, prof@beta.math.spbu.ru

=head1 SEE ALSO

XML::Parser::PyxParser

Home Page, http://beta.math.spbu.ru/~prof/xc/

Nsgmls

Pyxie, http://www.pyxie.org/

PerlSAX

XML::PYX

XML::ESISParser

SGMLS

=cut
