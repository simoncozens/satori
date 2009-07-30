use Sys::Virt;
  my $vmm = Sys::Virt->new(address => "xen+tls://".shift);

  use Data::Dumper;
  print "List domains:\n";
  my @domains = $vmm->list_domains();

  foreach my $dom (@domains) { print "Domain ", $dom->get_id, " ",
      $dom->get_name, " ",$dom->get_uuid_string,"\n"; 
      print "\t", $dom->get_info()->{state},"\n";
  }
  
  print "Known domains:\n";
  my @domains = $vmm->list_defined_domains();

  foreach my $dom (@domains) { print "Domain ", $dom->get_id, " ",
      $dom->get_name, " ",$dom->get_uuid_string,"\n"; }
