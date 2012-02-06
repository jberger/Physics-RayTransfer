use strict;
use warnings;

use Test::More;
use Math::MatrixReal;

use Physics::RayTransfer;

my $ones = Math::MatrixReal->new_from_rows( [[1,0], [0,1]] );
my $element = Physics::RayTransfer::Element->new();
my $obs = Physics::RayTransfer::Observer->new();

isa_ok( $element, 'Physics::RayTransfer::Element' );
ok( $element->matrix - $ones <= 1e-12, "Element matrix method returns 'one' matrix" );

isa_ok( $obs, 'Physics::RayTransfer::Element' );
isa_ok( $obs, 'Physics::RayTransfer::Observer' );
ok( $obs->matrix - $ones <= 1e-12, "Observer matrix method returns 'one' matrix" );

done_testing;

