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
    return reduce { $a->times($b) } map { $_->get } @$elements;
  }

  method evaluate_parameterized (ArrayRef $vals) {
    my $elements = $self->_construct;
     map { 
      my $val = $_;
      my $new = 
        reduce { $a->times($b) } 
        map { $_->get($val) }
        @$elements;
      [ $val, $new ];
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

  has 'a' => ( isa => 'Num', is => 'rw', default => 1 );
  has 'b' => ( isa => 'Num', is => 'rw', builder => '_build_b', lazy => 1 );
  has 'c' => ( isa => 'Num', is => 'rw', builder => '_build_c', lazy => 1 );
  has 'd' => ( isa => 'Num', is => 'rw', default => 1 );

  method _build_b () { 0 };
  method _build_c () { 0 };

  has 'parameter' => (
    isa => 'CodeRef',
    is => 'rw',
    predicate => 'has_parameter',
  );

  method get_parameterized (Num $val?) {
    return $self;
  }

  method get (Num $val?) {
    if (defined $val and $self->has_parameter) {
      my $param_val = $self->parameter->($val);
      return $self->get_parameterized($param_val);
    } else {
      return $self;
    }
  }

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

  method times (Physics::RayTransfer::Element $right) {
    my $a = $self->a * $right->a + $self->b * $right->c;
    my $b = $self->a * $right->b + $self->b * $right->d;
    my $c = $self->c * $right->a + $self->d * $right->c;
    my $d = $self->c * $right->b + $self->d * $right->d;

    return Physics::RayTransfer::Element->new(
      a => $a, b => $b, c => $c, d => $d,
    );
  }
}

class Physics::RayTransfer::Observer
  extends Physics::RayTransfer::Element {

}

class Physics::RayTransfer::Space
  extends Physics::RayTransfer::Element {

  has 'length' => (isa => 'Num', is => 'rw', default => 0);

  override _build_b () {
    return $self->length;
  }

  override get_parameterized (Num $length) {
    return __PACKAGE__->new( b => $length );
  }
}

class Physics::RayTransfer::Mirror
  extends Physics::RayTransfer::Element {

  has 'radius' => (isa => 'Num', is => 'rw', predicate => 'has_radius');

  method _radius_to_c () {
    my $c_term;

    if ($self->has_radius) {
      $c_term = - 2 / $self->radius;
    } else {
      $c_term = 0;
    }

    return $c_term;
  }

  override _build_c () {
    my $c = $self->_radius_to_c;
    return $c;
  }

  override get_parameterized (Num $c) {
    return __PACKAGE__->new( c => $c );
  }
}

class Physics::RayTransfer::Lens
  extends Physics::RayTransfer::Element {

  has 'f' => (isa => 'Num', is => 'rw', predicate => 'has_f');

  method _f_to_c () {
    my $c_term;

    if ($self->has_f) {
      $c_term = - 1 / $self->f;
    } else {
      $c_term = 0;
    }

    return $c_term;
  }

  override _build_c () {
    my $c = $self->_f_to_c;
    return Math::MatrixReal->new_from_rows( $c );
  }

  override get_parameterized (Num $c) {
    return __PACKAGE__->new( c => $c );
  }
}

