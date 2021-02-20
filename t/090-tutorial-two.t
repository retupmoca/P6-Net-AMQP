#!raku

use v6;

use Test;
use Net::AMQP;


use lib $*PROGRAM.parent.add('lib').Str;

use RabbitHelper;

if check-rabbit() {

    my $queue-name = "hello" ~ ((2**32 .. 2**64).pick + ($*PID +< 32) + time).base(16);

    my Promise $start-promise = Promise.new;
    my Promise $done-promise  = Promise.new;

# This tests for the behaviour in the RabbitMQ tutorial two
# By way of a full up integrated test.
# This differs in that we don't close the connection
    my $p = start {
        my $n = Net::AMQP.new;
        my $connection = $n.connect.result;
        my Str $ret = "FAIL";
        react {
            whenever $n.open-channel(1) -> $channel {
                $channel.qos(1);
                whenever $channel.declare-queue($queue-name, :durable) -> $q {
                    $q.consume(:ack);
                    $start-promise.keep([$n, $connection]);
                    whenever $q.message-supply -> $message {
                        $ret = $message.body.decode;
                        $q.delete;
                        # This may make an error message in the broker log
                        # as for some reason ack does not work in process like this.
                        $channel.ack($message.delivery-tag);
                        $done-promise.keep(True);
                        done();
                    }
                }
            }
        }
        $ret;
    }

# wait for the receiver to start u
    my ( $receiver, $receiver-promise) =  await $start-promise;
    my $n = Net::AMQP.new;
    my $con =  await $n.connect;
    my $channel = $n.open-channel(1).result;
    $channel.exchange.result.publish(routing-key => $queue-name, body => "Hello, World".encode, :persistent);
    await $done-promise;

    await $p;
    is $p.status, Kept, "receiver status Kept";
    is $p.result, "Hello, World", "and it got our message";

    await $n.close("", "");
    await $con;
}
else {
    skip "Unable to connect. Please run RabbitMQ on localhost with default credentials.", 2;
}

done-testing;
# vim: expandtab shiftwidth=4 ft=raku
