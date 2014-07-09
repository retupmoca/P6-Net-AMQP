use v6;

use Test;

plan 6;

use Net::AMQP;

my $n = Net::AMQP.new;

ok 1, 'can create Net::AMQP object';

my $initial-promise = $n.connect;
my $timeout = Promise.in(5);
await Promise.anyof($initial-promise, $timeout);
unless $initial-promise.status == Kept {
    skip "Unable to connect. Please run RabbitMQ on localhost with default credentials.", 5;
    exit;
}
is $initial-promise.status, Kept, 'Initial connection successful';

my $close-promise = $initial-promise.result;

my $channel-promise = $n.open-channel(1);
await $channel-promise;
is $channel-promise.status, Kept, 'channel.open success';
ok $channel-promise.result ~~ Net::AMQP::Channel, 'value has right class';

my $close-promise-new = $n.close("", "");
await $close-promise-new;
is $close-promise-new.status, Kept, 'connection.close success';
is $close-promise.status, Kept, 'Also affects initial connection promise';
