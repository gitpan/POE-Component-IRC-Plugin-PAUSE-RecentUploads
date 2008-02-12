#!/usr/bin/env perl

use Test::More tests => 6;
BEGIN {
    use_ok('POE');
    use_ok('POE::Component::IRC::Plugin');
    use_ok('WWW::PAUSE::RecentUploads');
    use_ok('POE::Component::WWW::PAUSE::RecentUploads');
    use_ok('POE::Component::WWW::PAUSE::RecentUploads::Tail');
    use_ok('POE::Component::IRC::Plugin::PAUSE::RecentUploads');
};

diag( "Testing POE::Component::IRC::Plugin::PAUSE::RecentUploads $POE::Component::IRC::Plugin::PAUSE::RecentUploads::VERSION, Perl $], $^X" );
