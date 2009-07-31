package Satori;
use strict;
use CGI::Carp qw(fatalsToBrowser);
use base 'CGI::Application';
use CGI::Application::Plugin::TT;
use Sys::Virt;

my $config = do "/home/simon/satori/config.pl";

sub setup {
    my $self = shift;
    $self->start_mode('list_nodes');
    $self->mode_param('rm');
    $self->run_modes(
            list_nodes => \&Satori::list_nodes,
            action => \&Satori::node_action,
            hostinfo => \&Satori::host_info
    );
    $self->tt_include_path('/home/simon/satori/templates');
    $self->tt_params(config => $config);
    $self->tt_params(query => $self->query);
}

sub list_nodes {
    my $self = shift;
    my $details = {};
    my $messages;
    for (@{$config->{servers}}) {
        my $vmm = eval { Sys::Virt->new(address => "xen+tls://$_") };
        if ($@) { $messages .= $@."\n"; next }
        $details->{$_} = $vmm->get_node_info;
        my %all_hosts = map { $_->get_uuid_string => $_ }
        ($vmm->list_domains(), $vmm->list_defined_domains());
        $details->{$_}{running_hosts} = [ $vmm->list_domains() ] ;
        $details->{$_}{known_hosts} = [ $vmm->list_defined_domains() ] ;
        $details->{$_}{storage_pools} = {
            map {
                my $i = $_->get_info(); $i->{volumes} = { 
                    map {$_->get_name() => $_->get_info() }
                    $_->list_volumes }; 
                 $_->get_name() => $i;
            }
            $vmm->list_storage_pools() 
        };
    }
    $self->tt_params(message => $messages);
    return $self->tt_process('list-nodes.tt',{servers => $details});
}

sub host_info {
    my $self = shift;
    my $node = $self->query->param("node");
    my $vmm = eval { Sys::Virt->new(address => "xen+tls://".$self->query->param("server")) };
    if (!$vmm) { 
        $self->tt_params(message => "Couldn't get a handle on server");
        return list_nodes($self);
    }
    my $n = $vmm->get_domain_by_name($node);
    my $info = $n->get_info();
    $self->tt_params(info => $info);
    $self->tt_params(status => $n->state_as_text);
    return list_nodes($self);
}

sub node_action {
    my $self = shift;
    my $node = $self->query->param("node");
    my $action = $self->query->param("action");
    if ($action !~ /^(reboot|shutdown|create)/) {
        $self->tt_params(message => "I don't know what '$action' is");
        return list_nodes($self);
    }
    if ($node eq "Domain-0") {
        $self->tt_params(message => "Cowardly refusing to $action Domain-0");
        return list_nodes($self);
    }
    my $vmm = eval { Sys::Virt->new(address => "xen+tls://".$self->query->param("server")) };
    if (!$vmm) { 
        $self->tt_params(message => "Couldn't get a handle on server");
        return list_nodes($self);
    }
    my $n = $vmm->get_domain_by_name($node);
    if (!$n) { 
        $self->tt_params(message => "Couldn't get a handle on $node");
        return list_nodes($self);
    }
    $n->$action();
    $self->tt_params(message => "Performed a $action on node $node");
    return list_nodes($self);

}
package Sys::Virt::Domain;
sub state_as_text {
    my $self = shift;
    my $state = $self->get_info()->{state};
    if ($state == Sys::Virt::Domain::STATE_NOSTATE) {
        return "idle";
    } elsif ($state == Sys::Virt::Domain::STATE_RUNNING) {
        return "active";
    } elsif ($state == Sys::Virt::Domain::STATE_BLOCKED) {
        return "blocked";
    } elsif ($state == Sys::Virt::Domain::STATE_PAUSED) {
        return "paused";
    } elsif ($state == Sys::Virt::Domain::STATE_SHUTDOWN) {
        return "shutting down";
    } elsif ($state == Sys::Virt::Domain::STATE_SHUTOFF) {
        return "off";
    } elsif ($state == Sys::Virt::Domain::STATE_CRASHED) {
        return "crashed";
    }
    return "unknown";
}

sub disks {
    # This is a bit TM-specific, although not much.
    my $self = shift;
    my $conn = shift;
    my $config = $self->get_xml_description();
    # "Parse" XML.
    my (@devices) = $config =~ /<source dev='([^']+)'/g;
    my @pools = $conn->list_storage_pools();
    my @disks;
    for my $dev (@devices) {
        for my $pool (@pools) {
            my $node = eval { $pool->get_volume_by_name($dev) };
            if ($node) { push @disks, $node; last }
        }
    }
    return @disks;
}

package Template::Plugin::HumanBytes;
$INC{"Template/Plugin/HumanBytes.pm"}++;
use base 'Template::Plugin::Filter';
sub init {
   my $self = shift;
   my $name = $self->{ _ARGS }->[0] || 'humanbytes';
   warn "Init called";
   $self->install_filter($name);
   return $self;
}
use Number::Bytes::Human 'format_bytes';
sub filter { format_bytes($_[1]) }



1;
