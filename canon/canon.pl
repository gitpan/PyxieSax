#!/usr/bin/perl
#
# Convert ESIS stream of Nsgmls or Pyxie to canonical XML.
# Oleg A. Paraschenko, prof@beta.math.spbu.ru
#
# Usage:
#   canon.pl param1=value1 param2=value2 ... 
# Parameters are passed to XML::Parser::PyxParser.
#
# Examples:
# 1) Convert ESIS of Nsgmls to canonical XML.
#    canon.pl SystemId={in_file} OutFile={out_file}
# 2) Convert ESIS of Pyxie to canonical XML.
#    canon.pl SystemId={in_file} SkipBadTags=0  \
#    AttrBeforeElement=0 CompactAttrString=1 \
#    OutFile={out_file}
#
use XML::Parser::PyxParser;
use XML::Handler::CanonXMLWriter;
use IO::File;

#
# Print usage.
#
unless (@ARGV) {
    print "Canon.pl: convert Esis stream of Pyxie or Nsgmls to canonical XML.\nUsage:\ncanon.pl SystemId=<input file> OutFile=<output file> AttrBeforeElement=<bool> CompactAttrString=<bool> CheckNesting=<bool> ChompPI=<bool> SkipBadTags=<bool>\nOleg A. Paraschenko <prof\@beta.math.spbu.ru>\n";
    exit 0;
}

#
# Parse arguments.
#
my $para = {"Source" => {}};
my $outf = "-";
for my $arg (@ARGV) {
    my ($p, $v) = split /=/, $arg, 2;
    die "Bad argument (no '=' sign): $arg\n" unless defined $v;
    if ($p eq 'SystemId') {
	$para->{'Source'}->{$p} = $v;
    } elsif ($p eq 'OutFile') {
	$outf = $v;
    } else {
	$para->{$p} = $v;
    }
}


#
# Create handler and run parser.
#
my $fh = new IO::File ">$outf";
die "Can't create '$outf'.\n" unless $fh;
my $handler = new XML::Handler::CanonXMLWriter IOHandle => $fh;
$para->{"Handler"} = $handler;
my $parser  = new XML::Parser::PyxParser $para;

exit ! $parser->parse;


