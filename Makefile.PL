use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'WWW::Hotmail',
    'VERSION_FROM'	=> 'Hotmail.pm', # finds $VERSION
    'PREREQ_PM'		=> {
         WWW::Mechanize => 0,
         Mail::Audit    => 2.1,
         Crypt::SSLeay  => 0,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?  
       (AUTHOR     => 'David Davis <xantus@cpan.org>') : ()),
);
