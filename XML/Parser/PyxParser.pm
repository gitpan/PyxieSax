#
# Copyright (C) 2000 Oleg A. Paraschenko
# XML::Parser::PyxParser is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#


use strict;
use IO::File;
package XML::Parser::PyxParser;

use vars qw{ $VERSION };
$VERSION = "0.32";

#
# Create new instance of PYX parser.
#
sub new {
    my $class   = shift;
    my $self    =  (scalar (@_) == 1) ? shift : { };
    return  bless $self, $class;
}

#
# Parse PYX/ESIS stream.
#
sub parse {
    my $self = shift;
    #
    # Set defaults and get parameters.
    #
    my $args             =  (scalar  (@_) == 1)       ?  shift            : {};
    my $args_source      =  (exists $args->{Source})  ?  $args->{Source}  : {};
    my $self_source      =  (exists $self->{Source})  ?  $self->{Source}  : {};
    my $param_src = {
	"ByteStream"       =>  undef,
	"SystemId"         =>  "-",
	%$self_source,
	%$args_source
    };
    my $param = {
	"AttrBeforeElement"  =>  1,
	"CompactAttrString"  =>  0,
	"CheckNesting"     =>  1,
	"SkipBadTags"      =>  1,
	"Handler"          =>  undef,
	"DocumentHandler"  =>  undef,
	"ChompPI"          =>  1,
	%$self,
	%$args
    };
    #
    # Check arguments.
    #
    # If no handlers, we will not work.
    #
    $param->{DocumentHandler} = $param->{Handler} unless defined $param->{DocumentHandler};
    my $dh = $param->{DocumentHandler};
    return 1 unless defined $dh;
    #
    # Check if we have input stream.
    #
    my $close_file  =  0;
    my $fh          =  $param_src->{ByteStream};
    unless (defined $fh) {
	my $fname = $param_src->{SystemId};
	$fh           =  new IO::File "<$fname";
	die "XML::Parser::PyxParser: can't open input stream named '$fname'\n" unless defined $fh;
	$close_file   =  1;
    }
    #
    # Do faster parameter access.
    #
    my $check_nesting     =  $param->{'CheckNesting'};
    my $allow_bad         =  $param->{'SkipBadTags'};
    my $attr_before_elem  =  $param->{'AttrBeforeElement'};
    my $attr_after_elem   =  ! $attr_before_elem;
    my $compact_attr      =  $param->{'CompactAttrString'};
    my $can_start_elem    =  UNIVERSAL::can ($dh, 'start_element');
    my $can_end_elem      =  UNIVERSAL::can ($dh, 'end_element');
    my $can_pi            =  UNIVERSAL::can ($dh, 'processing_instruction');
    my $can_data          =  UNIVERSAL::can ($dh, 'characters');
    #
    # Ready to parse.
    #
    $dh->start_document if UNIVERSAL::can ($dh, "start_document");
    #
    # Parse!
    #
    my $attr             =  {};    # Attribute name => Attribute value.
    my @elemst           =  ();    # Stack of nested tags.
    my $start_postponed  =  0;     # True if we postponed start_element call due to PYXIE attributes order.
    my $postponed_name   =  undef; # Name of postponed element.
    my $line;
    my $lineno = 0;
    while (defined ($line = _get_line ($fh))) {
	$lineno++;
	#
	# Attribute.
	#
	if ($line =~ /^A/) {
	    my ($aname, $avalue);
	    if ($compact_attr) {
		($aname, $avalue)   = split / /, $line, 2;
	    } else {
		($aname, undef, $avalue) = split / /, $line, 3;
	    };
	    next unless defined $avalue;
	    $aname = substr $aname, 1;
	    $attr->{$aname} = $avalue;
	#
	# Start of element. Do not forget that in PYXIE mode we have attributes
        # after element, but in nsgmls mode we have attributes before element.
        #
	} elsif ($line =~ /^\(/) {
	    my $ename = substr $line, 1;
	    push @elemst, $ename if $check_nesting;
	    ($ename, $postponed_name) = ($postponed_name, $ename) if $attr_after_elem;
	    $dh->start_element ({
		"Name"        =>  $ename,
		"Attributes"  =>  $attr
	    }) if ($can_start_elem and ($attr_before_elem or $start_postponed));
	    $attr = {};
	    $start_postponed = $attr_after_elem;
	#
	# End of element.
        #
	} elsif ($line =~ /^\)/) {
	    if ($start_postponed) {
		$dh->start_element ({"Name" => $postponed_name, "Attributes" => $attr }) if $can_start_elem;
		$attr = {};
		$start_postponed = 0;
	    }
	    my $ename = substr $line, 1;
	    if ($check_nesting) {
		my $oldname = pop @elemst;
		die "XML::Parser::PyxParser: Bad nesting (line $lineno). Unexpected end of element '$ename'.\n" if $oldname ne $ename;
	    }
	    next unless $can_end_elem;
	    $dh->end_element ({
		"Name" => $ename
	    });
	#
        # Processing instruction.
        #
	} elsif ($line =~ /^\?/) {
	    if ($start_postponed) {
		$dh->start_element ({"Name" => $postponed_name, "Attributes" => $attr }) if $can_start_elem;
		$attr = {};
		$start_postponed = 0;
	    }
	    next unless $can_pi;
	    my ($ptarget, $pdata) = split / /, $line, 2;
	    $ptarget = substr $ptarget, 1;
	    $pdata   = "" unless defined $pdata;
	    if ($param->{"ChompPI"}) {
		local $/ = '?';
		chomp ($pdata);
	    }
	    $dh->processing_instruction ({
		"Target"  =>  $ptarget,
		"Data"    =>  $pdata
	    });
        #
	# Characters.
        #
	} elsif ($line =~ /^-/) {
	    if ($start_postponed) {
		$dh->start_element ({"Name" => $postponed_name, "Attributes" => $attr }) if $can_start_elem;
		$attr = {};
		$start_postponed = 0;
	    }
	    next unless $can_data;
	    my $data = substr $line, 1;
	    $dh->characters ({
		"Data"  =>  $data
	    });
	#
        # Unparsed ESIS event.
        #
	} else {
	    next if $allow_bad;
	    my $event = substr $line, 0, 1;
	    die "XML::Parser::PyxParser: Unparsed ESIS event '$event' (line $lineno).\n";
	}
    }
    #
    # Finish parsing.
    #
    $fh->close if $close_file;
    #
    # Check that we close all elements
    #
    if ($check_nesting) {
	if ($#elemst >= 0) {
	    die "XML::Parser::PyxParser: End of stream, but not all elements are closed.\n";
	}
    }
    $dh->end_document if UNIVERSAL::can ($dh, "end_document");
    return 1;
}

#
# Get line and decode XML.
# We implement part of nsgmls output format:
#  \\    is a \
#  \n    is a record end character
#  \nnn  is the character whose code is 'nnn' octal.
#  \#n;  character with code 'n' in internal character set.
# Not implemented:
#  \|    internal SDATA entities
#  \%n   character with code 'n' in document character set
#
sub _get_line {
    my $fh = shift;
    my $str = $fh->getline ();
    return $str unless defined $str;
    chomp $str;
    $str =~ s/\\\#(\d+)\;|\\(\\|n|\d\d\d)/{
	if     (defined $1)     { chr ($1); }
	elsif  ($2 eq 'n')      { "\015"; } # "\n" is incorrect.
	elsif  ($2 eq '\\')     { "\\";   }
	else                    { chr (oct ($2)); }
    }/mseg;
    return $str;
}

1;

=head1 NAME

XML::Parser::PyxParser -- convert ESIS of Nsgmls or Pyxie to Perl SAX
events.

=head1 SYNOPSIS

 use XML::Parser::PyxParser;
 use XML::Handler::Something;
 $writer = new XML::Handler::Something OPTIONS;
 $options = {
     OPTIONS,
     Handler  =>  $writer
 }
 $handler = new XML::Parser::PyxParser $options;
 $handler->parse;


=head1 DESCRIPTION

XML::Parser::PyxParser converts ESIS of Nsgmls or Pyxie to Perl SAX events.
 Behaviour of object is specified when the object is created  or in method
"parse".  This module as compatible as possible with XML::Parser::PerlSAX
module.

=head1 METHODS

=over

=item new

Creates a new parser object. Options are passed by hash. Passed options
overrides default options.

=item parse

Parses a document. Passed options overrides options passed to method "new".

=back

=over

=item location

Will not be implemented.

=back

=head1 OPTIONS

The following options are not supported by XML::Parser::PyxParser:

=over

=item *

DTDHandler

=item *

ErrorHandler

=item *

EntityResolver

=item *

Locale

=item *

UseAttributeOrder

=back

The following options are supported by XML::Parser::PyxParser:

=over

=item Handler

Default handler to receive events.

=item DocumentHandler

Handler to receive document events.  You can use as "DocumentHandler" as
"Handler". No difference. If no handlers are provided then object silently
will not parse.

=item Source

Hash containing the input source for parsing. See description below.

=item AttrBeforeElement

Attributes are before element (1) or after  element (0). Default is 1
(before).

=item CompactAttrString

Attribute type is absent (1) or present (0). Default is 0 (present).

=item SkipBadTags

Skip (1) or do not (0) skip ESIS strings with  unknown prefix. Default is 1
(skip).

=item CheckNesting

Check (1) or do not check (0) nesting of elements. Default is 1 (check).

=item ChompPI

Cut (1) or do not cut (0) symbol '?' from the end of  processing
instruction. Default is 1 (cut).

=back

XML::Parser::PyxParser does not support these options of hash "Source":

=over

=item *

String

=item *

PublicId

=item *

Encoding

=back

Options of hash "Source":

=over

=item ByteStream

Output stream object with method "print" (for example, IO::File).

=item SystemId

Name of file passed to method "open" of IO::File.  If "ByteStream" is
defined then "SystemId" is ignored.  Default value of "SystemId" is "-".

=back

=head1 RECOMMENDED VALUES

Probably you like to be compatible with Nsgmls or Pyxie. The main
difference is that Nsgmls has attributes before element and attribute
types. Pyxie has attributes after element and does not have attribute
types. By default XML::Parser::PyxParser uses Nsgmls mode.

Recommended values for Nsgmls mode:

=over

=item *

AttrBeforeElement = 1

=item *

CompactAttrString = 0

=item *

CheckNesting = 1

=item *

SkipBadTags = 1

=item *

ChompPI = 1

=back

Recommended values for Pyxie mode:

=over

=item *

AttrBeforeElement = 0

=item *

CompactAttrString = 1

=item *

CheckNesting = 1

=item *

SkipBadTags = 0

=item *

ChompPI = 0

=back

=head1 INPUT STREAM

XML::Parser::PyxParser understand this escape sequences:

=over

=item \\

A \.

=item \n

A record end character.

=item \nnn

The character whose code is "nnn" octal.

=item \#n;

The character whose number is "n" decimal. "n" can have any number of
digits. But are you sure that Perl character can be greater than 255?

=back

=head1 NOTATION

Notation is a series of lines. Each line consist of an initial command
characters and arguments. The possible command	characters and arguments
are as follows:

=over

=item (gi

The start of an element whose generic identifier is "gi". Attributes of
element are specified before or after element depending on value of option
"AttrBeforeElement".

=item )gi

The end of an element whose generic  identifier is "gi".

=item -data

Data.

=item ?pi

A processing instruction with data "pi". By default "pi" of ESIS of Nsgmls
on my box have symbol '?' at the end. In XML mode I do not have this
symbol. Parser does not know origin of ESIS stream. So he silently cut last
'?' symbol (if allowed).

=item Aname value

Attribute definition if "CompactAttrString" option is set.

=item Aname type value

Attribute definition if "CompactAttrString" option is not set.

Word "type" is any word without spaces. This word  is ignored.

=back

=head1 AUTHOR

Oleg A. Paraschenko, prof@beta.math.spbu.ru

=head1 SEE ALSO

XML::Handler::PyxWriter

Home Page, http://beta.math.spbu.ru/~prof/xc/

Nsgmls

Pyxie, http://www.pyxie.org/

PerlSAX

XML::PYX

XML::ESISParser

SGMLS

=cut



