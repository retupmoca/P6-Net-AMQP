use v6;

use Test;


use Net::AMQP;

my $n = Net::AMQP.new;

my $initial-promise = $n.connect;
my $timeout = Promise.in(5);
try await Promise.anyof($initial-promise, $timeout);
unless $initial-promise.status == Kept {
    skip "Unable to connect. Please run RabbitMQ on localhost with default credentials.", 1;
    exit;
}

my $channel-promise = $n.open-channel(1);
my $channel = $channel-promise.result;

my $exchange = $channel.exchange.result;

my $queue = $channel.declare-queue("netamqptest").result;

my $p = Promise.new;

my Int $first-count = 0;

$queue.message-supply.tap({
    is $_.body.decode, "test", 'got sent message';
    $first-count++;
    $p.keep(1);
});

my $ck = "nanananiwo";

is do { await $queue.consume(consumer-tag => $ck) }, $ck, "got back the consumer code we supplied" ;

$exchange.publish(routing-key => 'netamqptest', body => 'test'.encode);

await $p;

await $queue.delete;

my $bind-exchange = $channel.declare-exchange('bind_test', 'direct').result;
my $bind-queue = $channel.declare-queue('', :exclusive).result;
await $bind-queue.bind('bind_test', 'test-key-good');
$bind-queue.consume;
my $body-supply = $bind-queue.message-supply.map( -> $v { $v.body.decode }).share;

my $good-promise = Promise.new;

my Int $second-count = 0;

$body-supply.tap( -> $m {
   is $m, "good-test", "got the thing we expected";
   $second-count++;
   if $good-promise.status ~~ Kept {
      fail "saw more than one message";
   }
   else {
      $good-promise.keep($m);
   }

});

$bind-exchange.publish(routing-key => "test-key-bad", body => "bad-test".encode);
$bind-exchange.publish(routing-key => "test-key-good", body => "good-test".encode);

await $good-promise;
is $good-promise.result, "good-test", "and the promise was kept with what we expected";


my $chan-close-promise = $channel.close("", "");
await $chan-close-promise;

await $n.close("", "");

is $first-count, 1, "the first tap only saw one message";
is $second-count, 1, "the second tap only saw one message";

done-testing;
