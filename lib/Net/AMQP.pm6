class Net::AMQP;

use Net::AMQP::Frame;
use Net::AMQP::Channel;

has $.host = 'localhost';
has $.port = 5672;

has $.login = 'guest';
has $.password = 'guest';

has $.vhost = '/';

has $!frame-max;
has $!channel-max;

has $!promise;
has $!vow;

has $!conn;

has $!frame-supply;

has $!method-supply;

method connect(){
    my $p = Promise.new;
    $!vow = $p.vow;
    $!promise = $p;

    $!frame-supply = Supply.new;

    $!method-supply = $!frame-supply.grep({ $_.type == 1 })\
                                    .map({ (channel => $_.channel,
                                            method  => Net::AMQP::Payload::Method.new($_.payload)).hash });

    ###
    # initial connection setup
    #
    # once these are hit, we will never need them again
    ###
    my $connstart = $!method-supply.grep(*<method>.method-name eq 'connection.start').tap({
        $connstart.close;

        my $start-ok = Net::AMQP::Payload::Method.new("connection.start-ok",
                                                      { platform => "Perl6" },
                                                      "PLAIN",
                                                      "\0"~$.login~"\0"~$.password,
                                                      "en_US");
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $start-ok.Buf).Buf);
    });

    my $conntune = $!method-supply.grep(*<method>.method-name eq 'connection.tune').tap({
        $conntune.close;

        $!channel-max = $_<method>.arguments[0];
        $!frame-max = $_<method>.arguments[1];
        my $tune-ok = Net::AMQP::Payload::Method.new("connection.tune-ok",
                                                     $!channel-max,
                                                     $!frame-max,
                                                     0); # no heartbeat yet
                                                     #say $tune-ok.perl;
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $tune-ok.Buf).Buf);

        my $open = Net::AMQP::Payload::Method.new("connection.open",
                                                  $.vhost, "", 0);
                                                  #say $open.perl;
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $open.Buf).Buf);
    });

    my $connopen = $!method-supply.grep(*<method>.method-name eq 'connection.open-ok').tap({
        $connopen.close;

        my $p = Promise.new;
        $!promise = $p;
        my $v = $!vow;
        $!vow = $p.vow;

        $v.keep($p);
    });
    ###
    ###

    $!method-supply.grep(*<method>.method-name eq 'connection.close').tap({
        my $close-ok = Net::AMQP::Payload::Method.new("connection.close-ok");
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $close-ok.Buf).Buf);
        $!conn.close();
        $!vow.keep(1);
    });

    IO::Socket::Async.connect($.host, $.port).then( -> $conn {
        $!conn = $conn.result;

        my $buf = buf8.new();

        $!conn.bytes_supply.act(-> $bytes {
            $buf ~= $bytes;
            my $continue = True;
            while $continue && $buf.bytes >= 7 {
                my $payload-size = Net::AMQP::Frame.size($buf);
                if $buf.bytes >= $payload-size + 7 + 1 { # payload + header + trailer (do we have a full frame?)
                    my $framebuf = $buf.subbuf(0, $payload-size + 7 + 1);
                    $buf .= subbuf($payload-size + 7 + 1);

                    my $frame = Net::AMQP::Frame.new($framebuf);

                    $!frame-supply.more($frame);
                } else {
                    $continue = False;
                }
            }
        },
        quit => {
            $!vow.break(1);
        },
        done => {
            $!vow.break(1);
        });
        $!conn.write(buf8.new(65, 77, 81, 80, 0, 0, 9, 1));
    });
    $p;
}

method close($reply-code, $reply-text, $class-id = 0, $method-id = 0) {

    my $tap = $!method-supply.grep(*<method>.method-name eq 'connection.close-ok').tap({
        $tap.close;

        $!conn.close;
        $!vow.keep(1);
    });

    my $close = Net::AMQP::Payload::Method.new("connection.close",
                                               $reply-code,
                                               $reply-text,
                                               $class-id,
                                               $method-id);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $close.Buf).Buf);
    $!promise;
}

method open-channel(Int $id?) {
    if !$id {
        die "NYI - please pass an id for now";
    }
    return Net::AMQP::Channel.new(id => $id,
                                  conn => $!conn,
                                  methods => $!method-supply.grep(*<channel> == $id).map(*<method>)).open;
}
