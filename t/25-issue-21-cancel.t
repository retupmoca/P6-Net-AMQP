use v6;

use Test;


use Net::AMQP;

my $n = Net::AMQP.new;

my $initial-promise = $n.connect;
my $timeout = Promise.in(5);
try await Promise.anyof($initial-promise, $timeout);
unless $initial-promise.status == Kept {
    plan 1;
    skip "Unable to connect. Please run RabbitMQ on localhost with default credentials.", 1;
    exit;
}

my $channel-promise = $n.open-channel(1);
my $channel = $channel-promise.result;

my $exchange = $channel.exchange.result;

my $queue = $channel.declare-queue().result;

my $p = Promise.new;

my Int $first-count = 0;

my $message = (^2048).map({('a' .. 'z', 'A' .. 'Z').flat.pick(1)}).join('');

my $tap = $queue.message-supply.tap({
    is $_.body.decode, $message, 'got sent message';
    $first-count++;
    $p.keep(1);
    $tap.close;
});


await $queue.consume;

$exchange.publish(routing-key => $queue.name, body => $message.encode);

await $p;

await $queue.cancel;

await $queue.delete;

my $chan-close-promise = $channel.close();
await $chan-close-promise;

await $n.close();

done-testing;
# vim: ft=perl6
