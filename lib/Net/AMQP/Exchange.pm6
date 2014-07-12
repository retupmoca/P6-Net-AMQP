class Net::AMQP::Exchange;

use Net::AMQP::Frame;
use Net::AMQP::Payload::Method;

has $.name;
has $.type;
has $.durable;
has $.passive;

has $!conn;
has $!methods;
has $!channel;

submethod BUILD(:$!name, :$!type, :$!durable, :$!passive, :$!conn, :$!methods, :$!channel) { }

method declare {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'exchange.declare-ok').tap({
        $tap.close;

        $v.keep(self);
    });

    my $declare = Net::AMQP::Payload::Method.new('exchange.declare',
                                                 0,
                                                 $.name,
                                                 $.type,
                                                 $.passive,
                                                 $.durable,
                                                 0,
                                                 0,
                                                 0,
                                                 {});
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $!channel, payload => $declare.Buf).Buf);

    return $p;
}

method delete($if-unused = 0) {
    my $p = Promise.new;
    my $v = $p.vow;

    my $tap = $!methods.grep(*.method-name eq 'exchange.delete-ok').tap({
        $tap.close;

        $v.keep(1);
    });
    
    my $delete = Net::AMQP::Payload::Method.new('exchange.delete',
                                                0,
                                                $.name,
                                                $if-unused,
                                                0);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $!channel, payload => $delete.Buf).Buf);
    return $p;
}
