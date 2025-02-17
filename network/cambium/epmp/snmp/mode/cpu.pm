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

package network::cambium::epmp::snmp::mode::cpu;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' }
    ];
    
    $self->{maps_counters}->{global} = [
        { label => 'cpu', nlabel => 'system.cpu.utilization.percentage', set => {
                key_values => [ { name => 'cpu' } ],
                output_template => 'CPU usage: %.2f%% ',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%' },
                ],
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_sysCPUUsage = '.1.3.6.1.4.1.17713.21.2.1.64.0';
    my $snmp_result = $options{snmp}->get_leef(
        oids => [ $oid_sysCPUUsage ] , 
        nothing_quit => 1
    );

    $self->{global} = { 'cpu' => ($snmp_result->{$oid_sysCPUUsage} / 10) };
}

1;

__END__

=head1 MODE

Check CPU usage.

=over 8

=item B<--warning-cpu>

Warning threshold for CPU.

=item B<--critical-cpu>

Warning threshold for CPU.

=back

=cut