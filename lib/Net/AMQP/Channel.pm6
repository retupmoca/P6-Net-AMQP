class Net::AMQP::Channel;

use Net::AMQP::Exchange;
use Net::AMQP::Queue;

use Net::AMQP::Payload::Method;
use Net::AMQP::Frame;

has $.id;
has $.conn;

has $!close-vow;

method handle-channel-method($method) {
    given $method.method-name {
        when 'channel.close' {

        }
        when 'channel.close-ok' {
            $.conn._remove_channel($.id);
            $!close-vow.keep(1);
        }
        when 'channel.flow' {

        }
        when 'channel.flow-ok' {

        }

        when 'basic.qos-ok' {

        }
    }
}

method handle-channel-content($stuff) {

}

###

method close($reply-code, $reply-text, $class-id = 0, $method-id = 0) {
    my $p = Promise.new;
    $!close-vow = $p.vow;
    my $close = Net::AMQP::Payload::Method.new("channel.close",
                                               $reply-code,
                                               $reply-text,
                                               $class-id,
                                               $method-id);
    $.conn.conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $close.Buf).Buf);
    return $p;
}

method declare-exchange {
    #Net::AMQP::Exchange
}

method declare-queue {
    #Net::AMQP::Queue
}

method qos($prefetch-size, $prefetch-count, $global){

}
