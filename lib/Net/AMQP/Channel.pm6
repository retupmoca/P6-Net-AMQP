class Net::AMQP::Channel;

use Net::AMQP::Exchange;
use Net::AMQP::Queue;

has $.id;
has $.conn;

method handle-channel-method($method) {
    given $method.method-name {
        when 'channel.close' {

        }
        when 'channel.close-ok' {

        }
        when 'channel.flow' {

        }
        when 'channel.flow-ok' {

        }

        when 'basic.qos-ok' {

        }
    }
}

method handle-channel-content($stuff) {

}

###

method close {

}

method declare-exchange {
    #Net::AMQP::Exchange
}

method declare-queue {
    #Net::AMQP::Queue
}

method qos($prefetch-size, $prefetch-count, $global){

}
