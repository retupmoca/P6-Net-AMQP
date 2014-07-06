class Net::AMQP;

use Net::AMQP::Frame;

method new() {
    my $s = IO::Socket::INET.new(:host('localhost'), :port(5672));
    $s.write(buf8.new(65, 77, 81, 80, 0, 0, 9, 1));
    my $frame-head = $s.read(7);
    my $payload-size = Net::AMQP::Frame.size($frame-head);
    my $frame = $frame-head ~ $s.read($payload-size + 1);
    my $payload = Net::AMQP::Frame.new($frame).payload;
    my $parsed = Net::AMQP::Payload::Method.new($payload);
    say "parsed:"~$parsed.perl;

    my $start-ok = Net::AMQP::Payload::Method.new("connection.start-ok", { platform => "Perl6" }, "PLAIN", "\0guest\0guest", "en_US");
    say "sent:"~$start-ok.perl;
    $start-ok = Net::AMQP::Frame.new(type => 1, channel => 0, payload => $start-ok.Buf);
    $s.write($start-ok.Buf);

    my $frame-head = $s.read(7);
    say $frame-head.perl;
    my $payload-size = Net::AMQP::Frame.size($frame-head);
    my $frame = $frame-head ~ $s.read($payload-size + 1);
    my $payload = Net::AMQP::Frame.new($frame).payload;
    my $parsed = Net::AMQP::Payload::Method.new($payload);
    say "parsed:"~$parsed.perl;
}

