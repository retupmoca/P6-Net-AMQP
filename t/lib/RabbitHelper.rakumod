use v6;

use Net::AMQP;

module RabbitHelper {

    sub get-amqp(--> Net::AMQP) is export {
        my $host = %*ENV<AMQP_HOST> // 'localhost';
        my $port = %*ENV<AMQP_PORT> // 5672;

        my $login = %*ENV<AMQP_LOGIN> // 'guest';
        my $password = %*ENV<AMQP_PASSWORD> // 'guest';

        my $vhost = %*ENV<AMQP_VHOST> // '/';
        Net::AMQP.new(:$host, :$port, :$login, :$password, :$vhost);
    }

    sub check-rabbit(--> Bool) is export {
        my Bool $rc = False;
        my $n = get-amqp();
        my $initial-promise = $n.connect;
        my $timeout = Promise.in(5);
        try await Promise.anyof($initial-promise, $timeout);
        if $initial-promise.status == Kept {
            await $n.close("","");
            $rc = True;
        }
        $rc;
    }
}

# vim: expandtab shiftwidth=4 ft=raku
