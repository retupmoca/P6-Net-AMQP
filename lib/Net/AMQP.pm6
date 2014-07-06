class Net::AMQP;

use Net::AMQP::Frame;

method new() {
    my $s = IO::Socket::INET.new(:host('localhost'), :port(5672));
    $s.write(buf8.new(65, 77, 81, 80, 0, 0, 9, 1));
    my $frame-head = $s.read(7);
    say "Received: "~$frame-head.perl;
    my $payload-size = Net::AMQP::Frame.size($frame-head);
    say "payload-size: "~$payload-size;
    my $frame = $frame-head ~ $s.read($payload-size + 1);
    say "full frame:"~$frame.perl;
    my $payload = Net::AMQP::Frame.new($frame).payload;
    say "payload:"~$payload.perl;
    my $parsed = Net::AMQP::Payload::Method.new($payload);
    say "parsed:"~$parsed.perl;
}

