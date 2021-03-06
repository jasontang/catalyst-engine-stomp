use strict;
use warnings;
use Test::More;

# Tests which expect a STOMP server like ActiveMQ to exist on
# localhost:61613, which is what you get if you just get the ActiveMQ
# distro and run its out-of-the-box config.

use YAML::XS qw/ Dump Load /;
use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/lib";
use TestServer;

my $stomp = start_server();

plan tests => 12;

my $frame = $stomp->connect();
ok($frame, 'connect to MQ server ok');

my $reply_to = sprintf '%s:1', $frame->headers->{session};
ok($frame->headers->{session}, 'got a session');
ok(length $reply_to > 2, 'valid-looking reply_to queue');

ok($stomp->subscribe( { destination => '/temp-queue/reply' } ), 'subscribe to temp queue');

# Test what happens when the action crashes
my $message = {
	       payload => { foo => 1, bar => 2 },
	       reply_to => $reply_to,
	       type => 'badaction',
	      };
my $text = Dump($message);
ok($text, 'compose message for badaction');

$stomp->send( { destination => '/queue/testcontroller', body => $text } );

my $reply_frame = $stomp->receive_frame();
ok($reply_frame, 'got a reply');
ok($reply_frame->headers->{destination} eq "/remote-temp-queue/$reply_to", 'came to correct temp queue');
ok($reply_frame->body, 'has a body');

my $response = Load($reply_frame->body);
ok($response, 'YAML response ok');
ok($response->{status} eq 'ERROR', 'is an error');
ok($response->{error} =~ /oh noes/);

ok($stomp->disconnect, 'disconnected');

