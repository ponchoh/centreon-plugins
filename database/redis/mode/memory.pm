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

package database::redis::mode::memory;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_usage_perfdata {
    my ($self, %options) = @_;

    $self->{output}->perfdata_add(
        nlabel => $self->{nlabel}, 
        unit => 'B',
        value => $self->{result_values}->{used},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}, total => $self->{result_values}->{total}, cast_int => 1),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}, total => $self->{result_values}->{total}, cast_int => 1),
        min => 0, max => $self->{result_values}->{total}
    );
}

sub custom_usage_threshold {
    my ($self, %options) = @_;

    my ($exit, $threshold_value);
    $threshold_value = $self->{result_values}->{used};
    $threshold_value = $self->{result_values}->{free} if (defined($self->{instance_mode}->{option_results}->{free}));
    if ($self->{instance_mode}->{option_results}->{units} eq '%') {
        $threshold_value = $self->{result_values}->{prct_used};
        $threshold_value = $self->{result_values}->{prct_free} if (defined($self->{instance_mode}->{option_results}->{free}));
    }
    $exit = $self->{perfdata}->threshold_check(
        value => $threshold_value,
        threshold => [
            { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' },
            { label => 'warning-' . $self->{thlabel}, exit_litteral => 'warning' }
        ]
    );
    return $exit;
}

sub custom_usage_output {
    my ($self, %options) = @_;

    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used});
    return sprintf(
        "%s: %s (%.2f%%)",
        $self->{result_values}->{display},
        $total_used_value . " " . $total_used_unit,
        $self->{result_values}->{prct_used}
    );
}

sub custom_usage_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{label} = $options{new_datas}->{$self->{instance} . '_label'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_used'};
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_total'};
    $self->{result_values}->{free} = $self->{result_values}->{total} - $self->{result_values}->{used};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{prct_free} = 100 - $self->{result_values}->{prct_used};

    return 0;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'used', type => 0 },
        { name => 'rss', type => 0, skipped_code => { -10 => 1 } },
        { name => 'peak', type => 0, skipped_code => { -10 => 1 } },
        { name => 'overhead', type => 0, skipped_code => { -10 => 1 } },
        { name => 'startup', type => 0, skipped_code => { -10 => 1 } },
        { name => 'dataset', type => 0, skipped_code => { -10 => 1 } },
        { name => 'lua', type => 0, skipped_code => { -10 => 1 } },
        { name => 'stats', type => 0, skipped_code => { -10 => 1 } }
    ];
    
    $self->{maps_counters}->{used} = [
        { label => 'used', nlabel => 'memory.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'label' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];

    $self->{maps_counters}->{rss} = [
        { label => 'rss', nlabel => 'memory.rss.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'label' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];

    $self->{maps_counters}->{peak} = [
        { label => 'peak', nlabel => 'memory.peak.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'label' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];

    $self->{maps_counters}->{overhead} = [
        { label => 'overhead', nlabel => 'memory.overhead.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'label' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];

    $self->{maps_counters}->{startup} = [
        { label => 'startup', nlabel => 'memory.startup.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'label' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];

    $self->{maps_counters}->{dataset} = [
        { label => 'dataset', nlabel => 'memory.dataset.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'label' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];

    $self->{maps_counters}->{lua} = [
        { label => 'lua', nlabel => 'memory.lua.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'label' }, { name => 'used' }, { name => 'total' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                closure_custom_perfdata => $self->can('custom_usage_perfdata'),
                closure_custom_threshold_check => $self->can('custom_usage_threshold')
            }
        }
    ];

    $self->{maps_counters}->{stats} = [
        { label => 'fragmentation-ratio', nlabel => 'memory.fragmentation.ratio.count', set => {
                key_values => [ { name => 'mem_fragmentation_ratio' } ],
                output_template => 'fragmentation ratio: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'defrag-running', nlabel => 'memory.defragmentation.running.count', set => {
                key_values => [ { name => 'active_defrag_running' } ],
                output_template => 'defragmentation running: %s',
                perfdatas => [
                    { label => 'defrag_running', template => '%s', min => 0 }
                ]
            }
        },
        { label => 'lazyfree-pending-objects', nlabel => 'memory.lazy_pending_objects.count', set => {
                key_values => [ { name => 'lazyfree_pending_objects' } ],
                output_template => 'lazyfree pending objects: %s',
                perfdatas => [
                    { label => 'lazyfree_pending_objects', template => '%s', min => 0 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'units:s' => { name => 'units', default => '%' },
        'free'    => { name => 'free' }
    });

    return $self;
}

my $metrics = {
    used_memory          => { label => 'used', display => 'used' },
    used_memory_rss      => { label => 'rss', display => 'rss' },
    used_memory_peak     => { label => 'peak', display => 'peak' },
    used_memory_overhead => { label => 'overhead', display => 'overhead' },
    used_memory_startup  => { label => 'startup', display => 'startup' },
    used_memory_dataset  => { label => 'dataset', display => 'dataset' },
    used_memory_lua      => { label => 'lua', display => 'lua' }
};

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->get_info(); 
    foreach my $type (keys %$metrics) {
        next if (!defined($results->{$type}));
        $self->{$metrics->{$type}->{label}} = {
            display => $metrics->{$type}->{display},
            label   => $metrics->{$type}->{label},
            used    => $results->{$type},
            total   => $results->{total_system_memory}
        };
    }

    $self->{stats} = { 
        mem_fragmentation_ratio => $results->{mem_fragmentation_ratio},
        active_defrag_running => $results->{active_defrag_running},
        lazyfree_pending_objects => $results->{lazyfree_pending_objects}
    };
}

1;

__END__

=head1 MODE

Check memory utilization

=over 8

=item B<--units>

Units of thresholds (Default: '%') ('%', 'B').

=item B<--free>

Thresholds are on free space left.

=item B<--warning-used>

Warning threshold for Used memory utilization

=item B<--critical-used>

Critical threshold for Used memory utilization

=item B<--warning-rss>

Warning threshold for Rss memory utilization

=item B<--critical-rss>

Critical threshold for Rss memory utilization

=item B<--warning-peak>

Warning threshold for Peak memory utilization

=item B<--critical-peak>

Critical threshold for Peak memory utilization

=item B<--warning-overhead>

Warning threshold for Overhead memory utilization

=item B<--critical-overhead>

Critical threshold for Overhead memory utilization

=item B<--warning-startup>

Warning threshold for Startup memory utilization

=item B<--critical-startup>

Critical threshold for Startup memory utilization

=item B<--warning-dataset>

Warning threshold for Dataset memory utilization

=item B<--critical-dataset>

Critical threshold for Dataset memory utilization

=item B<--warning-lua>

Warning threshold for Lua memory utilization

=item B<--critical-lua>

Critical threshold for Lua memory utilization

=item B<--warning-fragmentation-ratio>

Warning threshold for Fragmentation Ratio

=item B<--critical-fragmentation-ratio>

Critical threshold for Fragmentation Ratio

=item B<--warning-defrag-running>

Warning threshold for Running Defragmentation

=item B<--critical-defrag-running>

Critical threshold for Running Defragmentation

=item B<--warning-lazyfree-pending-objects>

Warning threshold for Lazyfree Pending Objects

=item B<--critical-lazyfree-pending-objects>

Critical threshold for Lazyfree Pending Objects

=back

=cut
