use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

{
  my $space = Physics::RayTransfer::Space->new( length => 2 );

  isa_ok( $space, 'Physics::RayTransfer::Element' );
  isa_ok( $space, 'Physics::RayTransfer::Space' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,2], [0,1]] );
    ok( $space->matrix - $expected <= 1e-12, "with init without arg" );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,3], [0,1]] );
    ok( $space->get_matrix(3) - $expected <= 1e-12, "with init with arg" );
  }
}

{
  my $space = Physics::RayTransfer::Space->new();

  isa_ok( $space, 'Physics::RayTransfer::Element' );
  isa_ok( $space, 'Physics::RayTransfer::Space' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [0,1]] );
    ok( $space->matrix - $expected <= 1e-12, "without init without arg"  );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,3], [0,1]] );
    ok( $space->get_matrix(3) - $expected <= 1e-12, "without init with arg" );
  }
}

done_testing;

