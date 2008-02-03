use Test::More;
eval "use Test::Pod::Coverage 1.00";

plan skip_all => "Test::Pod::Coverage 1.00 required for testing POD coverage"   if $@;
    
all_pod_coverage_ok( { trustme => [ qr/new/, qr/PCI_register/, 
                    qr/PCI_unregister/, qr/S_public/, 
] } );