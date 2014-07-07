class Net::AMQP::Payload::Heartbeat;

method Buf {
    return buf8.new(8, 0, 0);
}

method new($data?) { }
