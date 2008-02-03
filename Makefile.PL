use 5.008008;
use ExtUtils::MakeMaker;


WriteMakefile(
    NAME              => 'POE::Component::IRC::Plugin::PAUSE::RecentUploads',
    VERSION_FROM      => 'lib/POE/Component/IRC/Plugin/PAUSE/RecentUploads.pm', # finds $VERSION
    PREREQ_PM         => {
    	Carp                       => 1.04,
		POE                        => 0.9999,
		'POE::Component::IRC::Plugin' => 0.09,
		'POE::Component::WWW::PAUSE::RecentUploads::Tail' => 0.01,
    }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/POE/Component/IRC/Plugin/PAUSE/RecentUploads.pm', # retrieve abstract from module
       AUTHOR         => 'zoffix <zoffix@>') : ()),
);
