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
        $tap.close;

        $v.keep(self);
    });

    $!methods.grep(*.method-name eq 'channel.flow').tap({
        1; # TODO
    });

    $!methods.grep(*.method-name eq 'channel.close').tap({
        1; # TODO
    });

    my $open = Net::AMQP::Payload::Method.new("channel.open", "");
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $open.Buf).Buf);

    return $p;
}

method close($reply-code, $reply-text, $class-id = 0, $method-id = 0) {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'channel.close-ok').tap({
        $tap.close;

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
    # TODO
}

method declare-queue {
    # TODO
}

method qos($prefetch-size, $prefetch-count, $global = 0){
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'basic.qos-ok').tap({
        $tap.close;

        $v.keep(1);
    });

    my $qos = Net::AMQP::Payload::Method.new("basic.qos",
                                             $prefetch-size,
                                             $prefetch-count,
                                             $global);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $qos.Buf).Buf);
    return $p;
}

method flow($status) {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'channel.flow-ok').tap({
        $tap.close;

        $v.keep(1);
    });

    my $flow = Net::AMQP::Payload::Method.new("channel.flow",
                                             $status);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $flow.Buf).Buf);
    return $p;
}

method recover($requeue) {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'basic.recover-ok').tap({
        $tap.close;

        $v.keep(1);
    });

    my $recover = Net::AMQP::Payload::Method.new("basic.recover",
                                              $requeue);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $recover.Buf).Buf);
    return $p;
}
