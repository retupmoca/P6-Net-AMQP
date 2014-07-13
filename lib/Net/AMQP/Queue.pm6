class Net::AMQP::Queue;

use Net::AMQP::Payload::Method;
use Net::AMQP::Frame;

has $.name;
has $.passive;
has $.durable;
has $.exclusive;
has $.auto-delete;
has $.arguments;

has $!conn;
has $!login;
has $!methods;
has $!headers;
has $!bodies;
has $!channel;
has $!channel-lock;

submethod BUILD(:$!name, :$!passive, :$!durable, :$!exclusive, :$!auto-delete, :$!conn, :$!methods,
                :$!headers, :$!bodies, :$!channel, :$!channel-lock, :$!arguments) { }
                
method declare {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'queue.declare-ok').tap({
        $tap.close;

        $v.keep(self);
    });

    my $declare = Net::AMQP::Payload::Method.new('queue.declare',
                                                 0,
                                                 $.name,
                                                 $.passive,
                                                 $.durable,
                                                 $.exclusive,
                                                 $.auto-delete,
                                                 0,
                                                 $.arguments);
    $!channel-lock.protect: {
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $!channel, payload => $declare.Buf).Buf);
    };

    return $p;
}

method bind($exchange, $routing-key) {

}

method unbind($exchange, $routing-key) {

}

method purge {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'queue.purge-ok').tap({
        $tap.close;

        $v.keep($_.arguments[0]);
    });

    my $purge = Net::AMQP::Payload::Method.new('queue.purge',
                                               0,
                                               $.name,
                                               0);
    $!channel-lock.protect: {
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $!channel, payload => $purge.Buf).Buf);
    };

    return $p;
}

method delete(:$if-unused, :$if-empty) {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'queue.delete-ok').tap({
        $tap.close;

        $v.keep(1);
    });

    my $delete = Net::AMQP::Payload::Method.new('queue.delete',
                                                0,
                                                $.name,
                                                $if-unused,
                                                $if-empty,
                                                0);
    $!channel-lock.protect: {
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $!channel, payload => $delete.Buf).Buf);
    };

    return $p;
}

method get {

}

method consume {

}

method cancel {

}

method message-supply {

}

method recover {

}
