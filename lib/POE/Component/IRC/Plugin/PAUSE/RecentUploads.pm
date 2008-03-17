package POE::Component::IRC::Plugin::PAUSE::RecentUploads;

use strict;
use warnings;

our $VERSION = '0.04';

use Carp;
use POE;
use POE::Component::IRC::Plugin qw( :ALL );
use POE::Component::WWW::PAUSE::RecentUploads::Tail;

sub new {
    my $package = shift;
    my %args = @_;
    $args{ lc $_ } = delete $args{ $_ } for keys %args;
    
    for ( qw(login pass channels) ) {
        croak "Missing `$_` argument"
            unless exists $args{$_};
    }

    # load defaults and override with user args if any
    %args = (
        fetched_event => 'pause_uploads_list',
        report_event  => 'pause_new_uploads',
        message_type  => 'ctcp',
        loud_format   => 'ACTION upload: [[:dist:]] by [[:name:]]',
        flood_format  => 'ACTION Total of [[:total:]] uploads were uploaded',

        %args,
    );
    
    unless ( ref $args{channels} eq 'ARRAY' ) {
        carp "Argument `channels` must contain an arrayref..";
        return;
    }

    return bless \%args, $package;
}

sub PCI_register {
    my ( $self, $irc ) = splice @_, 0, 2;
    
    $self->{irc} = $irc;
    
#     $irc->plugin_register( $self, 'SERVER', qw(join par) );
    
    $self->{_session_id} = POE::Session->create(
        object_states => [
            $self => [
                qw(
                    _start
                    _shutdown
                    _fetched
                )
            ]
        ],
    )->ID;
    
    return 1;
}

sub _start {
    my ( $kernel, $self ) = @_[ KERNEL, OBJECT ];
    $self->{_session_id} = $_[SESSION]->ID();
    $kernel->refcount_increment( $self->{_session_id}, __PACKAGE__ );
    
    $self->{poco}
        = POE::Component::WWW::PAUSE::RecentUploads::Tail->spawn(
            login => $self->{login},
            pass  => $self->{pass},
            store => exists $self->{store}
                        ? $self->{store}
                        : 'pause_recent.data',
                        
            ua_args => exists $self->{ua_args}
                        ? $self->{ua_args}
                        : { timeout => 30 },
                        
            debug => exists $self->{debug}
                        ? $self->{debug}
                        : 0,
    );
    $self->{poco}->fetch( {
            event => '_fetched',
            interval => exists $self->{interval}
                        ? $self->{interval}
                        : 600
        }
    );
    undef;
}

sub _shutdown {
    my ($kernel, $self) = @_[ KERNEL, OBJECT ];
    $self->{poco}->shutdown;
    $kernel->alarm_remove_all();
    $kernel->refcount_decrement( $self->{_session_id}, __PACKAGE__ );
    undef;
}

sub PCI_unregister {
    my $self = shift;
    
    # Plugin is dying make sure our POE session does as well.
    $poe_kernel->call( $self->{_session_id} => '_shutdown' );
    
    delete $self->{irc};
    
    return 1;
}


sub _fetched {
    my ( $kernel, $self, $input ) = @_[ KERNEL, OBJECT, ARG0 ];
    $self->{irc}->_send_event( $self->{fetched_event} => $input );

    if ( @{ $input->{data} || [] } ) {
        $self->{irc}->_send_event( $self->{report_event} => $input );
    }

    unless ( $self->{quiet} ) {
        if ( defined $self->{flood_limit}
            and
            ( my $total = @{ $input->{data} || [] } ) > $self->{flood_limit}
        ) {
            foreach my $channel ( @{ $self->{channels} || [] } ) {
                my $format = $self->{flood_format};
                $format =~ s/\Q[[:total:]]/$total/gi;

                $kernel->post(
                    $self->{irc} =>
                    $self->{message_type} =>
                    $channel =>
                    $format
                );
            }
        }
        else {
            foreach my $dist ( @{ $input->{data} || [] } ) {
                my $format = $self->{loud_format};
                $format =~ s/\Q[[:dist:]]/$dist->{dist}/gi;
                $format =~ s/\Q[[:name:]]/$dist->{name}/gi;
                $format =~ s/\Q[[:size:]]/$dist->{size}/gi;

                foreach my $channel ( @{ $self->{channels} || [] } ) {
                    $kernel->post(
                        $self->{irc} =>
                        $self->{message_type} =>
                        $channel =>
                        $format
                    );
                }
            }
        }
    }
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

POE::Component::IRC::Plugin::PAUSE::RecentUploads - PoCo::IRC plugin
for reporting recent uploads to L<http:://pause.perl.org>

=head1 SYNOPSIS

    use strict;
    use warnings;
    
    use POE::Component::IRC;
    use POE::Component::IRC::Plugin::PAUSE::RecentUploads;
    
    my @Channels = ( '#zofbot', '#other_channel' );
    
    my $irc = POE::Component::IRC->spawn( 
            nick    => 'PAUSEBot',
            server  => 'irc.freenode.net',
            port    => 6667,
            ircname => 'PAUSE recent upload reporter',
    ) or die "Oh noes :( $!";
    
    POE::Session->create(
        package_states => [
            main => [ qw( _start irc_001 ) ],
        ],
    );
    
    
    $poe_kernel->run();
    
    sub _start {
        $irc->yield( register => 'all' );
        
        # register our plugin
        $irc->plugin_add(
            'PAUSE' => 
                POE::Component::IRC::Plugin::PAUSE::RecentUploads->new(
                    login => 'PAUSE_LOGIN',
                    pass  => 'PAUSE_PASS',
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

=head1 DESCRIPTION

The module provides a L<POE::Component::IRC> plugin using
L<POE::Component::IRC::Plugin> which reports recent uploads to 
PAUSE (L<http://pause.perl.org>)

=head1 CONTRUCTOR

    $irc->plugin_add(
        'PAUSE' => 
            POE::Component::IRC::Plugin::PAUSE::RecentUploads->new(
                login => 'PAUSE_LOGIN',
                pass  => 'PAUSE_PASS',
                interval => 600,
                channels => \@Channels,
                flood_limit => 5,
            )
    );

The contructor takes a few arguments which specify the behaviour of the
plugin. Three arguments, C<login>, C<pass> and C<channels> are B<mandatory>
the rest are optional. The contructor returns a
L<POE::Component::IRC::Plugin> object suitable for consumtion with 
L<POE::Component::IRC> C<plugin_add()> method. The accepted arguments
are as follows:

=head2 login

    ->new( login => 'PAUSE_LOGIN' )

B<Mandatory>. Must contain your L<http://pause.perl.org> login.

=head2 pass

    ->new( pass => 'PAUSE_PASS' )

B<Mandatory>. Must contain your L<http://pause.perl.org> password.

=head2 channels

    ->new( channels => \@Channels )
    
    ->new( channels => [ '#just_pause', '#reports' ] )

B<Mandatory>. Takes an arrayref as a value which should contain
the channels in which the plugin should report new uploads (see also
C<quiet> option)

=head2 interval

    { interval  => 600 }

B<Optional>. Specifies the interval in I<seconds> between requests to
PAUSE for fresh list. If specified to C<0> will make the component only
fire a single shot request without setting any interval. B<Defaults to:>
C<600> (10 minutes)

=head2 loud_format

 ->new( loud_format => 'ACTION upload: [[:dist:]] by [[:name:]]' )

 ->new( loud_format => '[[:name:]] uploaded [[:dist:]] (size: [[:size:]])' )

B<Optional>. If automatic reporting is turned on (see C<quiet> option)
The C<loud_format> takes a scalar that specifies the format of the
report message. There are three special sequences in the format which
will be replaced with data before being sent out, those are as follows:

=head2 flood_format

    ->new( flood_format  => 'ACTION Total of [[:total:]] uploads were uploaded' );

B<Optional>. When when C<flood_limit> is in effect (see below)
and the total number of the uploads is exceeded, the C<flood_format>
message will sent. The special string C<[[:total:]]> will be replaced by
the total number of uploads found. B<Defaults to:> C<ACTION Total of [[:total:]] uploads were uploaded>.

=over 10

=item [[:dist:]]

Will be replaced with the uploaded distribution name

=item [[:name:]]

Will be replaced with the PAUSE ID of the author of the upload

=item [[:size:]]

Will be replaced with the size of the upload

=back

The replacement will replace any number of each of the formats so feel
free to be redundant at will. B<Default format is:>
C<'ACTION upload: [[:dist:]] by [[:name:]]'>

=head2 message_type

    ->new( message_type  => 'ctcp' )
    
    ->new( message_type  => 'privmsg' )

B<Optional>. In addition to C<loud_format> you may specify the type of messages
the reports will be sent in. For example, setting C<message_type>
to C<ctcp> and adding C<ACTION > into C<loud_format> would
make the plugin reports via as a C</me> command, and setting
C<message_type> to C<privmsg> would make the plugin "speak" the format
normally into the channels. B<Defaults to:> C<ctcp>

Even though it's untested you could possibly set user nicks as
C<channels> (see above) and send C<notice>'s. However, in that case you'd
probably would want to set C<quiet> option (see below) and listen to
the events the plugin emits.

=head2 quiet

    ->new( quiet => 1 )

B<Optional>. When C<quiet> option is set to a true value the plugin
will not do the "reports" (see C<message_type> and C<loud_format> options
above). It will only emit the two type of events (see below).
B<Defaults to:> C<0>

=head2 flood_limit

    ->new( flood_limit => 5 );

B<Optional>. The C<flood_limit> prevents channel floods when C<quiet>
option is set to a false value (its the default). If after fetching a
new list of uploads, the number of uploads exceeds the number
specified in C<flood_limit>, the plugin will respond only with the
total number of uploads. You can still get the details via the sent out
event (see EMITED EVENTS section). If C<flood_limit> is set to C<undef>
no flood protection will be in effect. B<Defaults to:> C<undef> (no
flood protection).

=head2 fetched_event

    ->new( fetched_event => 'pause_uploads_list_event' )

B<Optional>. Specifies the name of the event to emit after
fetching the list of uploads (see EMITED EVENTS section for details).
B<Defaults to:> C<pause_uploads_list>

=head2 report_event

    ->new( report_event  => 'pause_new_uploads_event' )

B<Optional>. Specifies the name of the event to emit when a fetched
list contains uploads which haven't been reported before.
B<Defaults to:> C<pause_new_uploads>

=head2 store

    { store => 'storage_file.data' }
    
    { store => '/tmp/storage_file.data' }

B<Optional>. Specifies the filename of the file where we are going to
store the already reported modules. B<Defaults to:> C<pause_recent.data> in
the current directory.

=head2 ua_args

    ->new(
        ua_args => {
            timeout => 10, # defaults to 30
            agent   => 'SomeUA',
            # the rest of LWP::UserAgent contructor arguments
        },
    )

B<Optional>. The C<ua_args> key takes a hashref as a value which should
contain the arguments which will
be passed to
L<LWP::UserAgent> contructor. I<Note:> all arguments will default to
whatever L<LWP::UserAgent> default contructor arguments are except for
the C<timeout>, which will default to 30 seconds.

=head2 debug

    ->new( debug => 1 )

B<Optional>. When set to a true value will make the plugin print out some
debug messages. B<Defaults to:> C<0>

=head1 EMITED EVENTS

Even though in most cases setting up the plugin with C<format> and C<ctcp>
will suffice for the operation of the plugin you also have an option
of listening to the two events it emits. The event names are specified
by C<fetched_event> and C<report_event> options to the constructor
(see above).

=head2 fetched_event

The C<fetched_event> will be emitted every time the plugin
accesses L<http://pause.perl.org> for a fresh list of uploads. This will
be emited every C<interval> seconds (see contructor's C<interval> option
above). The input will be in C<ARG0> and will be exactly the same as in
L<POE::Component::WWW::PAUSE::RecentUploads::Tail> output. See
EMITED EVENTS section in L<POE::Component::WWW::PAUSE::RecentUploads::Tail>
documentation for the format of C<ARG0>

=head2 report_event

The C<report_event> will be emitted every time the plugin discovers
a new upload to L<http://pause.perl.org>. This will be emited
every time a "loud" version of the plugin would send out reports (
see C<quiet>, C<loud_format> and C<message_type> options to the contructor).
If the "loud" version doesn't satisfy your needs you can easily turn the
C<quiet> option to the constructor on and use a handler for this event
to handle the reports.

The input will be in C<ARG0> and will be exactly the same as in
L<POE::Component::WWW::PAUSE::RecentUploads::Tail> output. See
EMITED EVENTS section in L<POE::Component::WWW::PAUSE::RecentUploads::Tail>
documentation for the format of C<ARG0>

=head1 SEE ALSO

L<POE>, L<POE::Component::IRC>, L<POE::Component::IRC::Plugin>,
L<POE::Component::WWW::PAUSE::RecentUploads::Tail>

=head1 PREREQUISITES

For healthy operation this module requires you to have the following
modules/versions:

        Carp                                             => 1.04,
        POE                                              => 0.9999,
        POE::Component::IRC::Plugin                      => 0.09,
        POE::Component::WWW::PAUSE::RecentUploads::Tail  => 0.01,

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-component-irc-plugin-pause-recentuploads at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-IRC-Plugin-PAUSE-RecentUploads>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::IRC::Plugin::PAUSE::RecentUploads


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-IRC-Plugin-PAUSE-RecentUploads>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-IRC-Plugin-PAUSE-RecentUploads>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-IRC-Plugin-PAUSE-RecentUploads>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-IRC-Plugin-PAUSE-RecentUploads>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of POE::Component::IRC::Plugin::PAUSE::RecentUploads
