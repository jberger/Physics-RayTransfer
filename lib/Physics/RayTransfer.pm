use MooseX::Declare;
use Method::Signatures::Modifiers;

class Physics::RayTransfer {

  use Carp;
  use List::Util qw/reduce/;

  has 'elements' => (
    isa => 'ArrayRef[Physics::RayTransfer::Element]',
    is => 'rw', 
    default => sub{ [] },
    traits => ['Array'],
    handles => {
      add_element => 'push',
    },
  );

  method add_observer () {
    my $obs = Physics::RayTransfer::Observer->new();
    $self->add_element( $obs );
    return $obs;
  }

  method add_space (Num $length?) {
    my $space = Physics::RayTransfer::Space->new( 
      (defined $length) ? ( length => $length ) : ()
    );
    $self->add_element($space);
    return $space;
  }

  method add_mirror (Num $radius?) {
    my $mirror = Physics::RayTransfer::Mirror->new(
      (defined $radius) ? ( radius => $radius ) : ()
    );
    $self->add_element($mirror);
    return $mirror;
  }

  method add_lens (Num $f?) {
    my $lens = Physics::RayTransfer::Lens->new(
      (defined $f) ? ( radius => $f ) : ()
    );
    $self->add_element($lens);
    return $lens;
  }

  method evaluate () {
    my $elements = $self->_construct;
    my $matrix = reduce { $a * $b } map { $_->get } @$elements;
    return Physics::RayTransfer::Element->new( matrix => $matrix );
  }

  method evaluate_parameterized (ArrayRef $vals) {
    my $elements = $self->_construct;
     map { 
      my $val = $_;
      my $matrix = 
        reduce { $a * $b } 
        map { $_->get($val) }
        @$elements;
      [ $val, Physics::RayTransfer::Element->new( matrix => $matrix ) ];
    } @$vals;
  }

  method _construct () {
    my @orig = @{ $self->elements };

    # see if system begins(left) and/or ends(right) with mirror
    my $left_mirror = shift @orig if $orig[0]->isa('Physics::RayTransfer::Mirror');
    my $right_mirror = pop @orig if $orig[-1]->isa('Physics::RayTransfer::Mirror');

    # see if an observer object exists
    my $has_observer = grep { $_->isa('Physics::RayTransfer::Observer') } @orig;

    croak "Cannot have more than one observer" if $has_observer > 1;

    # create an observer "at the end" for several cases
    unless ($has_observer) {
      my $obs = Physics::RayTransfer::Observer->new();
      if ( $right_mirror and not $left_mirror) {
        unshift @orig, $obs;
      } else {
        push @orig, $obs;
      }
    }


    # determine which elements are left or right of observer
    my (@left, @right);
    my $obs_seen = 0;

    foreach my $elem (@orig) {
      if ($elem->isa('Physics::RayTransfer::Observer')) {
        $obs_seen = 1;
        next;
      }
      
      if (! $obs_seen) {
        push @left, $elem;
      } else {
        push @right, $elem;
      }
    }

    # build elements array for evaluation
    my @elements;
    if ($left_mirror and $right_mirror) {
      #cavity begins and ends at observer
      push @elements, @right, $right_mirror, reverse(@right), reverse(@left), $left_mirror, @left;
    } else {
      push @elements, @left;
      if ($right_mirror) {
        push @elements, @right, $right_mirror, reverse(@right);
      }
    }

    return \@elements;
  }

}

class Physics::RayTransfer::Element {
  use Math::MatrixReal;

  has 'matrix' => ( 
    isa => 'Math::MatrixReal',
    is => 'rw', 
    builder => '_build_matrix',
    lazy => 1,
  );

  has 'parameter' => (
    isa => 'CodeRef',
    is => 'rw',
    predicate => 'has_parameter',
  );

  method _build_matrix () {
    return Math::MatrixReal->new_diag([1,1]);
  }

  method get_parameterized (Num $val?) {
    return $self->matrix;
  }

  method get (Num $val?) {
    if (defined $val and $self->has_parameter) {
      my $param_val = $self->parameter->($val);
      return $self->get_parameterized($param_val);
    } else {
      return $self->matrix;
    }
  }

  method a () { $self->matrix->element(1,1) }
  method b () { $self->matrix->element(1,2) }
  method c () { $self->matrix->element(2,1) }
  method d () { $self->matrix->element(2,2) }

  method w (Num $lambda) {
    my $stability = $self->stability($lambda);
    return undef if abs($stability) >= 1;

    return sqrt( 
      abs($self->b) * $lambda / (4*atan2(1,1))
      * sqrt(
        1 / ( 1 - $stability ** 2 )
      )
    );
  }

  method stability (Num $lambda) {
    my $stability = ($self->a + $self->d) / 2;
    return $stability;
  }
}

class Physics::RayTransfer::Observer
  extends Physics::RayTransfer::Element {

}

class Physics::RayTransfer::Space
  extends Physics::RayTransfer::Element {

  use Math::MatrixReal;

  has 'length' => (isa => 'Num', is => 'rw', default => 0);

  override _build_matrix () {
    return $self->_build_space($self->length);
  }

  method _build_space (Num $length) {
    return Math::MatrixReal->new_from_rows( [[ 1, $length], [0, 1]] );
  }

  override get_parameterized (Num $length) {
    return $self->_build_space($length);
  }
}

class Physics::RayTransfer::Mirror
  extends Physics::RayTransfer::Element {

  use Math::MatrixReal;

  has 'radius' => (isa => 'Num', is => 'rw', predicate => 'has_radius');

  override _build_matrix () {
    my $c_term;

    if ($self->has_radius) {
      $c_term = - 2 / $self->radius;
    } else {
      $c_term = 0;
    }

    return $self->_build_from_c( $c_term );

  }

  method _build_from_c (Num $c) {
    return Math::MatrixReal->new_from_rows( [[ 1, 0], [$c, 1]] );
  }

  override get_parameterized (Num $c) {
    return $self->_build_from_c($c);
  }
}

class Physics::RayTransfer::Lens
  extends Physics::RayTransfer::Element {

  use Math::MatrixReal;

  has 'f' => (isa => 'Num', is => 'rw', predicate => 'has_f');

  override _build_matrix (Num $f?) {
    my $c_term;

    if ($self->has_f) {
      $c_term = - 1 / $self->f;
    } else {
      $c_term = 0;
    }

    return $self->_build_from_c($c_term);
  }

  method _build_from_c (Num $c) {
    return Math::MatrixReal->new_from_rows( [[ 1, 0], [$c, 1]] );
  }

  override get_parameterized (Num $c) {
    return $self->_build_from_c($c);
  }
}

