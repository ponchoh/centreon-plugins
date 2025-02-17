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

package cloud::azure::management::monitor::mode::discoverytenant;

use base qw(centreon::plugins::mode);

use strict;
use warnings;


sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        "prettify"        => { name => "prettify" },
        "select-type:s"   => { name => "select_type" }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

}

sub run {
    my ($self, %options) = @_;

    my @disco_data;
    my $disco_stats;

    $disco_stats->{start_time} = time();

    my $subscriptions = $options{custom}->azure_list_subscriptions(
        api_version => '2020-01-01'
    );

    foreach my $subscription (@$subscriptions) {
        my $resources = $options{custom}->azure_list_resources(
            subscription_id => $subscription->{subscriptionId},
            api_version => '2021-04-01'
        );

        foreach my $resource (@{$resources}) {
            next if (defined($self->{option_results}->{select_type}) && $self->{option_results}->{select_type} ne '' && $resource->{type} !~ /$self->{option_results}->{select_type}/i);

            my $resource_group = '';
            $resource_group = $resource->{resourceGroup} if (defined($resource->{resourceGroup}));
            $resource_group = $1 if ($resource_group eq '' && defined($resource->{id}) && $resource->{id} =~ /resourceGroups\/(.*)\/providers/);
            $resource->{resourceGroup} = $resource_group;

            foreach my $entry (keys %{$resource}) {
                next if (ref($resource->{$entry}) ne "HASH");
                my @array;

                foreach my $key (keys %{$resource->{$entry}}) {
                    push @array, { key => $key, value => $resource->{$entry}->{$key} };
                }
                $resource->{$entry} = \@array;
            }
            $resource->{tags} = [] if !defined($resource->{tags});

            $resource->{subscriptionId} = $subscription->{id};
            $resource->{subscriptionId} =~ s/\/subscriptions\///g;
            $resource->{subscriptionName} = $subscription->{displayName};

            foreach my $tag (keys %{$subscription}) {
                next if (ref($subscription->{$tag}) ne "HASH" || $tag !~ /tags/) ;
                my @array;
                
                foreach my $key (keys %{$subscription->{$tag}}) {
                    push @array, { key => $key, value => $subscription->{$tag}->{$key} };
                }
                $resource->{subscriptionTags} = \@array;
            }
            $resource->{subscriptionTags} = [] if !defined($resource->{subscriptionTags});

            push @disco_data, $resource;

        }
    }

    $disco_stats->{end_time} = time();
    $disco_stats->{duration} = $disco_stats->{end_time} - $disco_stats->{start_time};

    $disco_stats->{discovered_items} = @disco_data;
    $disco_stats->{results} = \@disco_data;

    my $encoded_data;
    eval {
        if (defined($self->{option_results}->{prettify})) {
            $encoded_data = JSON::XS->new->utf8->pretty->encode($disco_stats);
        } else {
            $encoded_data = JSON::XS->new->utf8->encode($disco_stats);
        }
    };
    if ($@) {
        $encoded_data = '{"code":"encode_error","message":"Cannot encode discovered data into JSON format"}';
    }
    
    $self->{output}->output_add(short_msg => $encoded_data);
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1);
    $self->{output}->exit();

}

1;

__END__

=head1 MODE

Discover all resources for every subscription related to a particular tenant. 

=over 8

=item B<--prettify>

Prettify JSON output.

=back

=cut