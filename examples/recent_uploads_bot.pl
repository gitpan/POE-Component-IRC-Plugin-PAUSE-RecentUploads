#!/usr/bin/perl -w

use strict;
use warnings;
use lib '../lib';

use POE qw(Component::IRC  Component::IRC::Plugin::PAUSE::RecentUploads);


my @Channels = ( '#zofbot' );
my ( $Login, $Pass ) = @ARGV[0, 1];

my $irc = POE::Component::IRC->spawn( 
        nick    => 'PAUSEBot',
        server  => 'irc.freenode.net',
        port    => 6667,
        ircname => 'PAUSE recent upload reporter',
) or die "Oh noes :( $!";

POE::Session->create(
    package_states => [
        main => [
            qw(
                _start
                irc_001
                _default
            )
        ],
    ],
);


$poe_kernel->run();

sub _start {
    $irc->yield( register => 'all' );
    
    # register our plugin
    $irc->plugin_add(
        'PAUSE' => 
            POE::Component::IRC::Plugin::PAUSE::RecentUploads->new(
                login => $Login,
                pass  => $Pass,
                interval => 600,
                channels => \@Channels,
            )
    );
    
    $irc->yield( connect => { } );
    undef;
}

sub irc_001 {
    my ( $kernel, $sender ) = @_[ KERNEL, SENDER ];
    $kernel->post( $sender => join => $_ )
        for @Channels;

    undef;
}

sub _default {
    my ($event, $args) = @_[ARG0 .. $#_];
    my @output = ( "$event: " );

    foreach my $arg ( @$args ) {
        if ( ref($arg) eq 'ARRAY' ) {
                push( @output, "[" . join(" ,", @$arg ) . "]" );
        } else {
                push ( @output, "'$arg'" );
        }
    }
    print STDOUT join ' ', @output, "\n";
    return 0;
}