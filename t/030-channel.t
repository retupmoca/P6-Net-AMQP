use v6;

use Test;

plan 10;

use Net::AMQP;


use lib $*PROGRAM.parent.add('lib').Str;

use RabbitHelper;

if check-rabbit() {
    my $n = Net::AMQP.new;
    await $n.connect;
    my $channel-promise = $n.open-channel(1);
    await $channel-promise;
    is $channel-promise.status, Kept, 'channel.open success';
    ok $channel-promise.result ~~ Net::AMQP::Channel, 'value has right class';
    my $channel = $channel-promise.result;

    is $channel.closed.status , Planned, "the closed Promise remains planned";

    my $p;

    await $p = $channel.qos(10);
    is $p.status, Kept, 'basic.qos success (prefetch limit: 10)';

    await $p = $channel.recover(1);
    is $p.status, Kept, 'basic.recover success';

    my $chan-close-promise = $channel-promise.result.close("", "");
    await $chan-close-promise;
    is $chan-close-promise.status, Kept, 'channel.close success';
    is $channel.closed.status, Kept, "and closed is not Kept";

    lives-ok { $chan-close-promise = $channel-promise.result.close("", "") }, "try and close it again";
    await $chan-close-promise;
    is $chan-close-promise.status, Kept, 'channel.close success (already closed)';

    lives-ok { $channel-promise = $n.open-channel(2, prefetch => 5) }, "open-channel with prefetch";

    await $channel-promise.result.close("", "");

    await $n.close("", "");
}
else {
    skip "Unable to connect. Please run RabbitMQ on localhost with default credentials.", 10;
}
