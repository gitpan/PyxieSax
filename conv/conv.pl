#!/usr/bin/perl
#
# Convert: ESIS stream -> SAX events -> ESIS stream.
# Oleg A. Paraschenko, prof@beta.math.spbu.ru
#
# Usage:
#   conv.pl in:param1=value1 ... out:param2=value2 ... 
# All parameters with 'in' prefix are passed to input filter
# (XML::Parser::PyxParser). All parameters with 'out' prefix
# are passed to output filter (XML::Handler::PyxWriter).
#
# Examples:
# 1) Convert Esis of Nsgmls to Esis of Pyxie
#    conv.pl in:SystemId=<in_file> out:SystemId=<out_file> \
#    out:AttrBeforeElement=0 out:CompactAttrString=1
# 2) Convert Esis of Pyxie to Esis of Nsgmls
#    conv.pl in:SystemId=<in_file> out:SystemId=<out_file> \
#            in:SkipBadTags=0 in:AttrBeforeElement=0 in:CompactAttrString=1
#
use XML::Parser::PyxParser;
use XML::Handler::PyxWriter;

#
# Usage.
#
unless (@ARGV) {
    print "Conv: convert Esis of Pyxie to Esis of Nsgmls and back.\nUsage:\nconv.pl in:SystemId=<input file name> out:SystemId=<output file name> [in:AttrBeforeElement=<bool>] [in:CompactAttrString=<bool>] [in:CheckNesting=<bool>] [in:ChompPI=<bool>] [in:SkipBadTags=<bool>] [out:AttrBeforeElement=<bool>] [out:CompactAttrString]\nOleg A. Paraschenko <prof\@beta.math.spbu.ru>\n";
    exit 0;
}

#
# Parse arguments.
#
my $in_para   =  {Source => {}};
my $out_para  =  {};
for my $arg (@ARGV) {
    my $cur_para;
    my ($what, $pv) = split /:/, $arg, 2;
    if      ($what eq "in") {
	$cur_para = $in_para;
    } elsif ($what eq "out") {
	$cur_para = $out_para;
    } else {
	die "Bad argument: $arg\n";
    }
    my ($param, $value) = split /=/, $pv, 2;
    unless ((defined $param) && (defined $value)) {
	die "Bad param=value string: $pv\n";
    }
    if (($param eq "SystemId") and ($what eq "in")) {
	$cur_para = $in_para->{"Source"};
    }
    $cur_para->{$param} = $value;
}

#
# Create parser, handler and run parser.
#
my $handler            =  new XML::Handler::PyxWriter $out_para;
$in_para->{"Handler"}  =  $handler;
my $parser             =  new XML::Parser::PyxParser $in_para;

exit  ! $parser->parse;


