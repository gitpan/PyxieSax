use ExtUtils::MakeMaker;
$VERSION = "0.32";

WriteMakefile(
    'NAME'          =>  'PyxieSax',
    'ABSTRACT'      =>  'Convert ESIS stream of Nsgmls or Pyxie to Perl SAX events and back',
    'AUTHOR'        =>  'Oleg A. Paraschenko (prof@beta.math.spbu.ru)',
    'VERSION_FROM'  =>  'Makefile.PL',
    'PM'            =>  {
        'XML/Parser/PyxParser.pm'    =>  '$(INST_LIBDIR)/XML/Parser/PyxParser.pm',
        'XML/Handler/PyxWriter.pm'   =>  '$(INST_LIBDIR)/XML/Handler/PyxWriter.pm'
    }
);

