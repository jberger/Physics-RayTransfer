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
    my $lens = Physics::RayTransfer::Space->new( 
      (defined $length) ? ( length => $length ) : ()
    );
    $self->add_element($lens);
    return $lens;
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
    return reduce { $a * $b } map { $_->matrix } @$elements;
  }

  method evaluate_varying (Physics::RayTransfer::Element $elem, ArrayRef $vals) {
    my $elements = $self->_construct;
    return [ map { 
      my $val = $_;
      reduce { $a * $b } 
        map { $_ == $elem ? $_->get_matrix($val) : $_->matrix } 
        @$elements;
    } @$vals ];
  }

  method _construct () {
    my @orig = @{ $self->elements };

    # see if system begins(left) and/or ends(right) with mirror
    my $left_mirror = $orig[0]->isa('Physics::RayTransfer::Mirror');
    my $right_mirror = $orig[-1]->isa('Physics::RayTransfer::Mirror');

    # see if an observer object exists
    my $has_observer = grep { $_->isa('Physics::RayTransfer::Observer') } @orig;

    croak "Cannot have more than one observer" if $has_observer > 1;

    # create an observer "at the end" for several cases
    unless ($has_observer) {
      my $obs = Physics::RayTransfer::Observer->new();
      if (! $right_mirror) {
        push @orig, $obs;
      } elsif ( ! $left_mirror ) {
        unshift @orig, $obs;
      } else {
        splice @orig, -1, 0, $obs;
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
      push @elements, @right, reverse(@right), reverse(@left), @left;
    } else {
      push @elements, @left;
      if ($right_mirror) {
        push @elements, @right, reverse(@right);
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

  method _build_matrix () {
    return Math::MatrixReal->new_diag([1,1]);
  }

  method get_matrix () {
    return $self->matrix;
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

  override get_matrix (Num $length) {
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

  override get_matrix (Num $c) {
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

  override get_matrix (Num $c) {
    return $self->_build_from_c($c);
  }
}

