use Sys::Virt;
  my $vmm = Sys::Virt->new(address => "xen+tls://".shift);
my $xml = q{
      <pool type="logical">
        <name>vg0</name>
        <source>
          <device path="/dev/sda2"/>
        </source>
        <target>
          <path>/dev/vg0</path>
        </target>
      </pool>
      };
  $vmm->create_storage_pool($xml);
