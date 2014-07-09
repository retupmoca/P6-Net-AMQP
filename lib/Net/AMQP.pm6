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

has %!channels;

has $.conn;

has $!frame-supply;

method connect(){
    my $p = Promise.new;
    $!vow = $p.vow;
    $!promise = $p;

    $!frame-supply = Supply.new;

    $!frame-supply.tap(-> $frame {
        if $frame.type == 1 { # method
            my $method = Net::AMQP::Payload::Method.new($frame.payload);
            #say $method.perl;
            if $method.class-id == 10 { # connection
                self!handle-connection-method($method);
            } elsif $method.method-name eq 'channel.open-ok' {
                my $v = %!channels{$frame.channel};
                %!channels{$frame.channel} = Net::AMQP::Channel.new(id => $frame.channel,
                                                                    conn => self);
                $v.keep(%!channels{$frame.channel});
            } else {
                %!channels{$frame.channel}.handle-channel-method($method);
            }
        } elsif $frame.type == 2 { # content header
            my $header = Net::AMQP::Payload::Header.new($frame.payload);
            %!channels{$frame.channel}.handle-channel-content($header);
        } elsif $frame.type == 3 { # content body
            my $body = Net::AMQP::Payload::Body.new($frame.payload);
            %!channels{$frame.channel}.handle-channel-content($body);
        } elsif $frame.type == 4 { # heartbeat
            # TODO
        }
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

method !handle-connection-method($method) {
    if $method.method-name eq 'connection.start' {
        my $start-ok = Net::AMQP::Payload::Method.new("connection.start-ok",
                                                      { platform => "Perl6" },
                                                      "PLAIN",
                                                      "\0"~$.login~"\0"~$.password,
                                                      "en_US");
                                                      #say $start-ok.perl;
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $start-ok.Buf).Buf);
    } elsif $method.method-name eq 'connection.tune' {
        $!channel-max = $method.arguments[0];
        $!frame-max = $method.arguments[1];
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
        #say 'here';
    } elsif $method.method-name eq 'connection.open-ok' {
        # we are ready to rumble
        #say "Connection setup complete.";
        my $p = Promise.new;
        $!promise = $p;
        my $v = $!vow;
        $!vow = $p.vow;

        $v.keep($p);
    } elsif $method.method-name eq 'connection.close' {
        my $close-ok = Net::AMQP::Payload::Method.new("connection.close-ok");
        $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $close-ok.Buf).Buf);
        $!conn.close();
        $!vow.keep(1);
    } elsif $method.method-name eq 'connection.close-ok' {
        $!conn.close();
        $!vow.keep(1);
    }
}

method close($reply-code, $reply-text, $class-id = 0, $method-id = 0) {
    my $close = Net::AMQP::Payload::Method.new("connection.close",
                                               $reply-code,
                                               $reply-text,
                                               $class-id,
                                               $method-id);
    $!conn.write(Net::AMQP::Frame.new(type => 1, channel => 0, payload => $close.Buf).Buf);
    $!promise;
}

method open-channel(Int $id?) {
    if $id {
        if %!channels{$id} {
            die;
        } else {
            my $p = Promise.new;
            %!channels{$id} = $p.vow;
            my $open = Net::AMQP::Payload::Method.new("channel.open", "");
            $!conn.write(Net::AMQP::Frame.new(type => 1, channel => $id, payload => $open.Buf).Buf);
            return $p;
        }
    } else {
        die "NYI";
    }
}

method _remove_channel($id) {
    %!channels{$id} = Nil;
}
