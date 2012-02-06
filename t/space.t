use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

my $shift = sub { shift };

{
  my $space = Physics::RayTransfer::Space->new( length => 2, parameter => $shift );

  isa_ok( $space, 'Physics::RayTransfer::Element' );
  isa_ok( $space, 'Physics::RayTransfer::Space' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,2], [0,1]] );
    ok( $space->get - $expected <= 1e-12, "with init without param" );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,3], [0,1]] );
    ok( $space->get(3) - $expected <= 1e-12, "with init with param" );
  }
}

{
  my $space = Physics::RayTransfer::Space->new( parameter => $shift );

  isa_ok( $space, 'Physics::RayTransfer::Element' );
  isa_ok( $space, 'Physics::RayTransfer::Space' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [0,1]] );
    ok( $space->get - $expected <= 1e-12, "without init without param"  );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,3], [0,1]] );
    ok( $space->get(3) - $expected <= 1e-12, "without init with param" );
  }
}

done_testing;

