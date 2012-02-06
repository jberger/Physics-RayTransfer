use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

{
  my $mirror = Physics::RayTransfer::Mirror->new( radius => 2 );

  isa_ok( $mirror, 'Physics::RayTransfer::Element' );
  isa_ok( $mirror, 'Physics::RayTransfer::Mirror' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-1,1]] );
    ok( $mirror->matrix - $expected <= 1e-12, "with init without arg" );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.5,1]] );
    ok( $mirror->get_matrix(-0.5) - $expected <= 1e-12, "with init with arg" );
  }
}

{
  my $mirror = Physics::RayTransfer::Mirror->new();

  isa_ok( $mirror, 'Physics::RayTransfer::Element' );
  isa_ok( $mirror, 'Physics::RayTransfer::Mirror' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [0,1]] );
    ok( $mirror->matrix - $expected <= 1e-12, "without init without arg"  );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.25,1]] );
    ok( $mirror->get_matrix(-0.25) - $expected <= 1e-12, "without init with arg" );
  }
}

done_testing;

