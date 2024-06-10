#!raku

use v6;

use Test;
use Net::AMQP;

use lib $*PROGRAM.parent.add('lib').Str;

use RabbitHelper;

plan 1;

if check-rabbit() {
    my $queue-name = "hello" ~ ((2**32 .. 2**64).pick + ($*PID +< 32) + time).base(16);

    {
        my $n = get-amqp();
        my $con =  await $n.connect;
        my $channel = $n.open-channel(1).result;
        my $queue = $channel.declare-queue($queue-name, :durable).result;

        my $exchange = $channel.exchange.result;
        $exchange.publish(routing-key => $queue-name, body => "Hello, World".encode, :persistent);
        await $n.close("", "");
        await $con;
    }
    {
        my $n = get-amqp();
        my $con =  await $n.connect;
        my $channel = $n.open-channel(1).result;
        my $queue = $channel.declare-queue($queue-name, :durable).result;
        $queue.consume;

        my $p = Promise.new;
        $queue.message-supply.tap( -> $v {
            my $ret = $v.body.decode;
            is $ret, "Hello, World", "got the message";
            $p.keep: True;
        });

        await Promise.anyof($p, Promise.in(5));
        await $n.close("", "");
        await $con;
    }

    {
        my $n = get-amqp();
        my $con =  await $n.connect;
        my $channel = $n.open-channel(1).result;
        my $queue = $channel.declare-queue($queue-name, :durable).result;

        await $queue.delete;

        await $n.close("", "");
        await $con;
    }

}
else {
   skip-rest "Unable to connect. Please run RabbitMQ on localhost with default credentials.";
}


