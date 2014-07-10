class Net::AMQP::Channel;

use Net::AMQP::Exchange;
use Net::AMQP::Queue;

use Net::AMQP::Payload::Method;
use Net::AMQP::Frame;

has $.id;
has $!conn;

# supplies
has $!methods;
has $!headers;
has $!bodies;
#

submethod BUILD(:$!id, :$!conn, :$!methods, :$!headers, :$!bodies) { }

method open {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'channel.open-ok').tap({
        #$tap.close;

        $v.keep(self);
    });

    my $open = Net::AMQP::Payload::Method.new("channel.open", "");
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $open.Buf).Buf);

    return $p;
}

# unused
# only stays here as a reference for methods I need to implement
method handle-channel-method($method) {
    given $method.method-name {
        when 'channel.close' {

        }
        when 'channel.flow' {

        }
        when 'channel.flow-ok' {

        }

        when 'basic.qos-ok' {

        }
    }
}

###

method close($reply-code, $reply-text, $class-id = 0, $method-id = 0) {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'channel.close-ok').tap({
        #$tap.close;

        $v.keep(1);
    });

    my $close = Net::AMQP::Payload::Method.new("channel.close",
                                               $reply-code,
                                               $reply-text,
                                               $class-id,
                                               $method-id);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $close.Buf).Buf);
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
