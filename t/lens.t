use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

{
  my $lens = Physics::RayTransfer::Lens->new( f => 2 );

  isa_ok( $lens, 'Physics::RayTransfer::Element' );
  isa_ok( $lens, 'Physics::RayTransfer::Lens' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.5,1]] );
    ok( $lens->matrix - $expected <= 1e-12, "with init without arg" );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.25,1]] );
    ok( $lens->get_matrix(-0.25) - $expected <= 1e-12, "with init with arg" );
  }
}

{
  my $lens = Physics::RayTransfer::Lens->new();

  isa_ok( $lens, 'Physics::RayTransfer::Element' );
  isa_ok( $lens, 'Physics::RayTransfer::Lens' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [0,1]] );
    ok( $lens->matrix - $expected <= 1e-12, "without init without arg"  );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.125,1]] );
    ok( $lens->get_matrix(-0.125) - $expected <= 1e-12, "without init with arg" );
  }
}

done_testing;

