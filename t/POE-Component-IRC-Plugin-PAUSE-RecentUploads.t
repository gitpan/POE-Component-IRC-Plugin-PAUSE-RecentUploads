# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl POE-Component-IRC-Plugin-PAUSE-RecentUploads.t'


use Test::More tests => 6;
BEGIN {
    use_ok('POE');
    use_ok('POE::Component::IRC::Plugin');
    use_ok('WWW::PAUSE::RecentUploads');
    use_ok('POE::Component::WWW::PAUSE::RecentUploads');
    use_ok('POE::Component::WWW::PAUSE::RecentUploads::Tail');
    use_ok('POE::Component::IRC::Plugin::PAUSE::RecentUploads');
};

