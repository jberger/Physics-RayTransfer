use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

my $shift = sub { shift };

{
  my $mirror = Physics::RayTransfer::Mirror->new( radius => 2, parameter => $shift );

  isa_ok( $mirror, 'Physics::RayTransfer::Element' );
  isa_ok( $mirror, 'Physics::RayTransfer::Mirror' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-1,1]] );
    ok( $mirror->get - $expected <= 1e-12, "with init without param" );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.5,1]] );
    ok( $mirror->get(-0.5) - $expected <= 1e-12, "with init with param" );
  }
}

{
  my $mirror = Physics::RayTransfer::Mirror->new( parameter => $shift );

  isa_ok( $mirror, 'Physics::RayTransfer::Element' );
  isa_ok( $mirror, 'Physics::RayTransfer::Mirror' );

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [0,1]] );
    ok( $mirror->get - $expected <= 1e-12, "without init without param"  );
  }

  {
    my $expected = Math::MatrixReal->new_from_rows( [[1,0], [-0.25,1]] );
    ok( $mirror->get(-0.25) - $expected <= 1e-12, "without init with param" );
  }
}

done_testing;

