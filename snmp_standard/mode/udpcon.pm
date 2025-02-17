#
# Copyright 2022 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package snmp_standard::mode::udpcon;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my %map_addr_type = (
    0 => 'unknown',
    1 => 'ipv4',
    2 => 'ipv6',
    3 => 'ipv4z',
    4 => 'ipv6z',
    16 => 'dns',
);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'warning:s'       => { name => 'warning', },
        'critical:s'      => { name => 'critical', },
        'service:s@'      => { name => 'service', },
        'application:s@'  => { name => 'application', },
    });

    @{$self->{connections}} = ();
    $self->{services} = { total => { filter => '.*?#.*?#.*?', builtin => 1, number => 0, msg => 'Total connections: %d' } };
    $self->{applications} = {};
    $self->{states} = { listen => 0 };
    return $self;
}

sub get_ipv6 {
    my ($self, %options) = @_;

    my $ipv6 = '';
    my $num = 1;
    foreach my $val (split /\./, $options{value}) {
        if ($num % 3 == 0) {
            $ipv6 .= ':';
            $num++;
        }
        $ipv6 .= sprintf("%02x", $val);
        $num++;
    }

    return $ipv6;
}

sub get_from_rfc4022 {
    my ($self, %options) = @_;

    my $oid_udpListenerProcess = '.1.3.6.1.2.1.7.7.1.8';
    my $results = $self->{snmp}->get_multiple_table(
        oids => [
            { oid => $oid_udpListenerProcess },
        ]
    );
    return 0 if (scalar(keys %{$results->{$oid_udpListenerProcess}}) == 0);

    # Listener
    foreach (keys %{$results->{$oid_udpListenerProcess}}) {
        /^$oid_udpListenerProcess\.(\d+)/;
        my $ipv = $map_addr_type{$1};
        next if ($ipv !~ /^ipv4|ipv6$/); # manage only 'ipv4' (1) and 'ipv6' (2) for now

        my ($src_addr, $src_port);
        if ($ipv eq 'ipv6') {
            /^$oid_udpListenerProcess\.\d+\.\d+\.((?:\d+\.){16})(\d+)/;
            ($src_addr, $src_port) = ($self->get_ipv6(value => $1), $2);
        } else {
            /^$oid_udpListenerProcess\.\d+\.\d+\.(\d+\.\d+\.\d+\.\d+)\.(\d+)/;
            ($src_addr, $src_port) = ($1, $2);
        }
        push @{$self->{connections}}, $ipv . "#$src_addr#$src_port";
        $self->{states}->{listen}++;
    }

    return 1;
}

sub get_from_rfc1213 {
    my ($self, %options) = @_;

    my $oid_udpLocalAddress = '.1.3.6.1.2.1.7.5.1.1';
    my $result = $self->{snmp}->get_table(oid => $oid_udpLocalAddress, nothing_quit => 1);

    # Construct
    foreach (keys %$result) {
        /(\d+\.\d+\.\d+\.\d+).(\d+)$/;
        $self->{states}->{listen}++;
        push @{$self->{connections}}, "ipv4#$1#$2";
    }
}

sub build_connections {
    my ($self, %options) = @_;

    if ($self->get_from_rfc4022() == 0) {
        $self->get_from_rfc1213();
    }
}

sub check_services {
    my ($self, %options) = @_;

    foreach my $service (@{$self->{option_results}->{service}}) {
        my ($tag, $ipv, $port, $filter_ip, $warn, $crit) = split /,/, $service;

        if (!defined($tag) || $tag eq '') {
            $self->{output}->add_option_msg(short_msg => "Tag for service '" . $service . "' must be defined.");
            $self->{output}->option_exit();
        }
        if (defined($self->{services}->{$tag})) {
            $self->{output}->add_option_msg(short_msg => "Tag '" . $tag . "' (service) already exists.");
            $self->{output}->option_exit();
        }

        $self->{services}->{$tag} = {
            filter =>
                ((defined($ipv) && $ipv ne '') ? $ipv : '.*?') . '#' .
                ((defined($filter_ip) && $filter_ip ne '') ? $filter_ip : '.*?') . '#' .
                ((defined($port) && $port ne '') ? $port : '.*?'),
            builtin => 0, 
            number => 0
        };
        if (($self->{perfdata}->threshold_validate(label => 'warning-service-' . $tag, value => $warn)) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $warn . "' for service '$tag'.");
            $self->{output}->option_exit();
        }
        if (($self->{perfdata}->threshold_validate(label => 'critical-service-' . $tag, value => $crit)) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $crit . "' for service '$tag'.");
            $self->{output}->option_exit();
        }
    }
}

sub check_applications {
    my ($self, %options) = @_;

    foreach my $app (@{$self->{option_results}->{application}}) {
        my ($tag, $services, $warn, $crit) = split /,/, $app;

        if (!defined($tag) || $tag eq '') {
            $self->{output}->add_option_msg(short_msg => "Tag for application '" . $app . "' must be defined.");
            $self->{output}->option_exit();
        }
        if (defined($self->{applications}->{$tag})) {
            $self->{output}->add_option_msg(short_msg => "Tag '" . $tag . "' (application) already exists.");
            $self->{output}->option_exit();
        }

        $self->{applications}->{$tag} = { services => {} };
        foreach my $service (split /\|/, $services) {
            if (!defined($self->{services}->{$service})) {
                $self->{output}->add_option_msg(short_msg => "Service '" . $service . "' is not defined.");
                $self->{output}->option_exit();
            }
            $self->{applications}->{$tag}->{services}->{$service} = 1;
        }

        if (($self->{perfdata}->threshold_validate(label => 'warning-app-' . $tag, value => $warn)) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $warn . "' for application '$tag'.");
            $self->{output}->option_exit();
        }
        if (($self->{perfdata}->threshold_validate(label => 'critical-app-' . $tag, value => $crit)) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $crit . "' for application '$tag'.");
            $self->{output}->option_exit();
        }
    }
}

sub test_services {
    my ($self, %options) = @_;

    foreach my $tag (keys %{$self->{services}}) {
        foreach (@{$self->{connections}}) {
            if (/$self->{services}->{$tag}->{filter}/) {
                $self->{services}->{$tag}->{number}++;
            }
        }

        my $exit_code = $self->{perfdata}->threshold_check(
            value => $self->{services}->{$tag}->{number},
            threshold => [ { label => 'critical-service-' . $tag, 'exit_litteral' => 'critical' }, { label => 'warning-service-' . $tag, exit_litteral => 'warning' } ]
        );
        my $msg = "Service '$tag' connections: %d";
        if ($self->{services}->{$tag}->{builtin} == 1) {
            $msg = $self->{services}->{$tag}->{msg};
        }

        $self->{output}->output_add(
            severity => $exit_code,
            short_msg => sprintf($msg, $self->{services}->{$tag}->{number})
        );
        $self->{output}->perfdata_add(
            label => 'service',
            nlabel => 'service.connections.udp.count',
            instances => $tag,
            value => $self->{services}->{$tag}->{number},
            warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-service-' . $tag),
            critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-service-' . $tag),
            min => 0
        );
    }
}

sub test_applications {
    my ($self, %options) = @_;

    foreach my $tag (keys %{$self->{applications}}) {
        my $number = 0;

        foreach (keys %{$self->{applications}->{$tag}->{services}}) {
            $number += $self->{services}->{$_}->{number};
        }

        my $exit_code = $self->{perfdata}->threshold_check(
            value => $number,
            threshold => [ { label => 'critical-app-' . $tag, 'exit_litteral' => 'critical' }, { label => 'warning-app-' . $tag, exit_litteral => 'warning' } ]
        );
        $self->{output}->output_add(
            severity => $exit_code,
            short_msg => sprintf("Applicatin '%s' connections: %d", $tag, $number)
        );
        $self->{output}->perfdata_add(
            label => 'app',
            nlabel => 'application.connections.udp.count',
            instances => $tag,
            value => $number,
            warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-app-' . $tag),
            critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-app-' . $tag),
            min => 0
        );
    }
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (($self->{perfdata}->threshold_validate(label => 'warning-service-total', value => $self->{option_results}->{warning})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning threshold '" . $self->{option_results}->{warning} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical-service-total', value => $self->{option_results}->{critical})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical threshold '" . $self->{option_results}->{critical} . "'.");
        $self->{output}->option_exit();
    }
    $self->check_services();
    $self->check_applications();
}

sub run {
    my ($self, %options) = @_;
    $self->{snmp} = $options{snmp};

    $self->build_connections();
    $self->test_services();
    $self->test_applications();

    foreach (keys %{$self->{states}}) {
        $self->{output}->perfdata_add(
            label => 'con_' . $_,
            nlabel => 'connections.udp.' . lc($_) . '.count',
            value => $self->{states}->{$_},
            min => 0
        );
    }

    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check udp connections.

=over 8

=item B<--warning>

Threshold warning for total connections.

=item B<--critical>

Threshold critical for total connections.

=item B<--service>

Check udp connections following rules:
tag,[type],[port],[filter-ip],[threshold-warning],[threshold-critical]

Example to test NTP connections on the server: --service="ntp,,123,1,2"

=over 16

=item <tag>

Name to identify service (must be unique and couldn't be 'total').

=item <type>

regexp - can use 'ipv4', 'ipv6'. Empty means all.

=item <filter-ip>

regexp - can use to exclude or include some IPs.

=item <threshold-*>

nagios-perfdata - number of connections.

=back

=item B<--application>

Check udp connections of mutiple services:
tag,[services],[threshold-warning],[threshold-critical]

Example:
--application="web,http|https,1,2"

=over 16

=item <tag>

Name to identify application (must be unique).

=item <services>

List of services (used the tag name. Separated by '|').

=item <threshold-*>

nagios-perfdata - number of connections.

=back

=back

=cut
