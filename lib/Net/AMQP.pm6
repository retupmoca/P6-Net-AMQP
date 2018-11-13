unit class Net::AMQP;

use Net::AMQP::Frame;
use Net::AMQP::Channel;

use Net::AMQP::Payload::Heartbeat;

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

has Bool $.debug = False;

has Supplier $!frame-supplier;
has Supply   $!frame-supply;

has Supply $!method-supply;
has Supply $!header-supply;
has Supply $!body-supply;

method connect(){
    my $p = Promise.new;
    $!vow = $p.vow;
    $!promise = $p;

    $!frame-supplier    = Supplier.new;
    $!frame-supply      = $!frame-supplier.Supply;



    $!method-supply = $!frame-supply.grep({ $_.type == 1 }).map({ (channel => $_.channel, method  => Net::AMQP::Payload::Method.new($_.payload)).hash });
    $!method-supply.tap({ say "got method ",$_<method>.method-name }) if $!debug;

    $!header-supply = $!frame-supply.grep({ $_.type == 2 }).map({ (channel => $_.channel, header  => Net::AMQP::Payload::Header.new($_.payload)).hash });
    $!body-supply = $!frame-supply.grep({ $_.type == 3 }).map({ (channel => $_.channel, payload  => $_.payload).hash });

    ###
    # initial connection setup
    #
    # once these are hit, we will never need them again
    ###

    my $connstart = $!method-supply.grep({ $_<method>.method-name eq 'connection.start'}).tap({
        $connstart.close;

        my $start-ok = Net::AMQP::Payload::Method.new("connection.start-ok",
                                                      { platform => "Perl6" },
                                                      "PLAIN",
                                                      "\0"~$.login~"\0"~$.password,
                                                      "en_US");
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $start-ok).Buf);
    });
    my $conntune = $!method-supply.grep( { $_<method>.method-name eq 'connection.tune' }).tap({
        $conntune.close;

        $!channel-max = $_<method>.arguments[0];
        $!frame-max = $_<method>.arguments[1];
        my $to = $_<method>.arguments[2];

        if $to {
            my $ih = Promise.new;
            $!frame-supply.tap({
                $ih.keep(1);
                $ih = Promise.new;
                my $tmp = $ih;
                Promise.anyof(Promise.in($to * 2),
                              $tmp).then({
                    unless $tmp.status == Kept {
                        # Timeout!
                        # TODO shut things down
                    }
                });
            });

            my $c = $!conn;
            $!conn = (class {
                has $!ob = Promise.new;
                method write($stuff) {
                    $c.write($stuff);
                    $!ob.keep(1);
                    $!ob = Promise.new;
                    my $tmp = $!ob;
                    Promise.anyof(Promise.in($to),
                                  $tmp).then({
                        unless $tmp.status == Kept {
                            self.write(Net::AMQP::Frame.new(type => 8, channel => 0,
                                                            payload => Net::AMQP::Payload::Heartbeat.new).Buf);
                        }
                    });
                }
                method real { $c }
                method close { $c.close }
            }).new;
        }

        my $tune-ok = Net::AMQP::Payload::Method.new("connection.tune-ok",
                                                     $!channel-max,
                                                     $!frame-max,
                                                     $to);
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $tune-ok).Buf);

        my $open = Net::AMQP::Payload::Method.new("connection.open",
                                                  $.vhost, "", 0);
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $open).Buf);
    });

    my $connopen = $!method-supply.grep({ $_<method>.method-name eq 'connection.open-ok' }).tap({
        $connopen.close;

        my $p = Promise.new;
        $!promise = $p;
        my $v = $!vow;
        $!vow = $p.vow;

        $v.keep($p);
    });
    ###
    ###

    $!method-supply.grep({ $_<method>.method-name eq 'connection.close' }).tap({
        my $close-ok = Net::AMQP::Payload::Method.new("connection.close-ok");
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $close-ok).Buf);
        $!conn.close();
        $!vow.keep(1);
    });

    IO::Socket::Async.connect($.host, $.port).then( -> $conn {
        $!conn = $conn.result;

        my $buf = buf8.new();

        $!conn.Supply(:bin).act(-> $bytes {
            $buf ~= $bytes;
            my $continue = True;
            while $continue && $buf.bytes >= 7 {
                my $payload-size = Net::AMQP::Frame.size($buf);
                if $buf.bytes >= $payload-size + 7 + 1 { # payload + header + trailer (do we have a full frame?)
                    my $framebuf = $buf.subbuf(0, $payload-size + 7 + 1);
                    $buf .= subbuf($payload-size + 7 + 1);

                    my $frame = Net::AMQP::Frame.new($framebuf);

                    $!frame-supplier.emit($frame);
                } else {
                    $continue = False;
                }
            }
        },
        quit => {
            $!vow.break("quit");
        },
        done => {
            $!vow.keep("done");
        });
        $!conn.write(buf8.new(65, 77, 81, 80, 0, 0, 9, 1));
    });
    $p;
}

method close($reply-code = '', $reply-text = '', $class-id = 0, $method-id = 0) {

    my $tap = $!method-supply.grep({ $_<method>.method-name eq 'connection.close-ok' }).tap({
        $tap.close;

        $!conn.close;
        $!vow.keep(1);
    });

    my $close = Net::AMQP::Payload::Method.new("connection.close",
                                               $reply-code,
                                               $reply-text,
                                               $class-id,
                                               $method-id);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $close).Buf);
    $!promise;
}

method open-channel(Int $id?) {
    if !$id {
        die "NYI - please pass an id for now";
    }
    return Net::AMQP::Channel.new(id => $id,
                                  conn => $!conn,
                                  login => $!login,
                                  frame-max => $!frame-max,
                                  headers => $!header-supply.grep( { $_<channel> == $id }).map( {$_<header> }),
                                  bodies => $!body-supply.grep({$_<channel> == $id }).map({$_<payload> }),
                                  methods => $!method-supply.grep({ $_<channel> == $id }).map({ $_<method> })).open;
}
