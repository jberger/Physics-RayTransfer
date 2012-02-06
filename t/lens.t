use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

my $shift = sub { shift };

{
  my $lens = Physics::RayTransfer::Lens->new( f => 2, parameter => $shift );

  isa_ok( $lens, 'Physics::RayTransfer::Element' );
  isa_ok( $lens, 'Physics::RayTransfer::Lens' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.5,1]] );
    ok( $lens->get - $expected <= 1e-12, "with init without param" );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.25,1]] );
    ok( $lens->get(-0.25) - $expected <= 1e-12, "with init with param" );
  }
}

{
  my $lens = Physics::RayTransfer::Lens->new( parameter => $shift );

  isa_ok( $lens, 'Physics::RayTransfer::Element' );
  isa_ok( $lens, 'Physics::RayTransfer::Lens' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [0,1]] );
    ok( $lens->get - $expected <= 1e-12, "without init without param"  );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.125,1]] );
    ok( $lens->get(-0.125) - $expected <= 1e-12, "without init with param" );
  }
}

done_testing;

