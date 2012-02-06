use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

{
  # space-space system

  my $sys = Physics::RayTransfer->new();
  isa_ok( $sys, 'Physics::RayTransfer' );

  $sys->add_space(2);
  $sys->add_space(3);

  is( scalar @{ $sys->elements }, 2, "Correct number of elements" );

  my $expected = Math::MatrixReal->new_from_rows( [[1,5], [0,1]] );
  my $eval = $sys->evaluate->matrix;

  ok( $eval - $expected <= 1e-12, "space-space" );
}

{
  # space-obs-space system

  my $sys = Physics::RayTransfer->new();
  isa_ok( $sys, 'Physics::RayTransfer' );

  $sys->add_space(2);
  $sys->add_observer;
  $sys->add_space(3);

  is( scalar @{ $sys->elements }, 3, "Correct number of elements" );

  my $expected = Math::MatrixReal->new_from_rows( [[1,2], [0,1]] );
  my $eval = $sys->evaluate->matrix;

  ok( $eval - $expected <= 1e-12, "space-obs-space" );
}

{
  # two space and right mirror system 

  my $sys = Physics::RayTransfer->new();
  isa_ok( $sys, 'Physics::RayTransfer' );

  $sys->add_space(2);
  $sys->add_space(3);
  $sys->add_mirror;

  is( scalar @{ $sys->elements }, 3, "Correct number of elements" );

  my $expected = Math::MatrixReal->new_from_rows( [[1,10], [0,1]] );
  my $eval = $sys->evaluate->matrix;

  ok( $eval - $expected <= 1e-12, "space-space-mirror" );
}

{
  # space-obs-space-mirror

  my $sys = Physics::RayTransfer->new();
  isa_ok( $sys, 'Physics::RayTransfer' );

  $sys->add_space(2);
  $sys->add_observer;
  $sys->add_space(3);
  $sys->add_mirror;

  is( scalar @{ $sys->elements }, 4, "Correct number of elements" );

  my $expected = Math::MatrixReal->new_from_rows( [[1,8], [0,1]] );
  my $eval = $sys->evaluate->matrix;

  ok( $eval - $expected <= 1e-12, "space-obs-space-mirror" );
}

{
  # mirror-space-space (left mirror is useless)

  my $sys = Physics::RayTransfer->new();
  isa_ok( $sys, 'Physics::RayTransfer' );

  $sys->add_mirror;
  $sys->add_space(2);
  $sys->add_space(3);

  is( scalar @{ $sys->elements }, 3, "Correct number of elements" );

  my $expected = Math::MatrixReal->new_from_rows( [[1,5], [0,1]] );
  my $eval = $sys->evaluate->matrix;

  ok( $eval - $expected <= 1e-12, "mirror-space-space" );
}

{
  # mirror-space-space-mirror (cavity) 

  my $sys = Physics::RayTransfer->new();
  isa_ok( $sys, 'Physics::RayTransfer' );

  $sys->add_mirror;
  $sys->add_space(2);
  $sys->add_space(3);
  $sys->add_mirror;

  is( scalar @{ $sys->elements }, 4, "Correct number of elements" );

  my $expected = Math::MatrixReal->new_from_rows( [[1,10], [0,1]] );
  my $eval = $sys->evaluate->matrix;

  ok( $eval - $expected <= 1e-12, "mirror-space-space-mirror (cavity)" );
}

done_testing;


