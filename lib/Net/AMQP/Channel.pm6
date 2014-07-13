class Net::AMQP::Channel;

use Net::AMQP::Exchange;
use Net::AMQP::Queue;

use Net::AMQP::Payload::Method;
use Net::AMQP::Frame;

has $.id;
has $!conn;
has $!login;

# supplies
has $!methods;
has $!headers;
has $!bodies;
#

has $!flow-stopped;
has $!write-lock;
has $!channel-lock;

submethod BUILD(:$!id, :$!conn, :$!methods, :$!headers, :$!bodies, :$!login) {
    $!write-lock = Lock.new;
    $!channel-lock = Lock.new;
    my $wl = $!write-lock;
    my $c = $!conn;
    $!conn = class { method write($stuff) { $wl.protect: { $c.write($stuff); }; }; method real { $c }; };
}

method open {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'channel.open-ok').tap({
        $tap.close;

        $v.keep(self);
    });

    $!methods.grep(*.method-name eq 'channel.flow').tap({
        my $flow-ok = Net::AMQP::Payload::Method.new("channel.flow-ok",
                                                     $_.arguments[0]);
        if $_.arguments[0] {
            if $!flow-stopped {
                $!conn.real.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $flow-ok.Buf).Buf);
                $!write-lock.unlock();
                $!flow-stopped = 0;
            }
        } else {
            unless $!flow-stopped {
                $!flow-stopped = 1;
                $!write-lock.lock();
                $!conn.real.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $flow-ok.Buf).Buf);
            }
        }

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
    $!channel-lock.protect: {
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $close.Buf).Buf);
    };
    return $p;
}

method declare-exchange($name, $type, :$durable = 0, :$passive = 0) {
    return Net::AMQP::Exchange.new(:$name,
                                   :$type,
                                   :$durable,
                                   :$passive,
                                   conn => $!conn,
                                   channel-lock => $!channel-lock,
                                   login => $!login,
                                   methods => $!methods,
                                   channel => $.id).declare;
}

method exchange($name = "") {
    return Net::AMQP::Exchange.new(:$name,
                                   conn => $!conn,
                                   channel-lock => $!channel-lock,
                                   login => $!login,
                                   methods => $!methods,
                                   channel => $.id);
}

method declare-queue($name, :$passive, :$durable, :$exclusive, :$auto-delete, *%arguments) {
    return Net::AMQP::Queue.new(:$name,
                                :$passive,
                                :$durable,
                                :$exclusive,
                                :$auto-delete,
                                arguments => $%arguments,
                                conn => $!conn,
                                channel-lock => $!channel-lock,
                                methods => $!methods,
                                headers => $!headers,
                                bodies => $!bodies,
                                channel => $.id).declare;
}

method queue($name) {
    return Net::AMQP::Queue.new(:$name,
                                conn => $!conn,
                                channel-lock => $!channel-lock,
                                methods => $!methods,
                                headers => $!headers,
                                bodies => $!bodies,
                                channel => $.id);
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
    $!channel-lock.protect: {
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $qos.Buf).Buf);
    };
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
    $!channel-lock.protect: {
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $flow.Buf).Buf);
    }
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
    $!channel-lock.protect: {
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $.id, payload => $recover.Buf).Buf);
    }
    return $p;
}
