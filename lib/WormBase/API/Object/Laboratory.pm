package WormBase::API::Object::Laboratory	;
use Moose;

with 'WormBase::API::Role::Object';
extends 'WormBase::API::Object';



########

sub name {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my $data_pack;

	#### data pull and packaging

	$data_pack = {
	
		'id' => "$object",
		'label' => "$object",
		'class' => 'Laboratory'
	
	};

	####
	
	$data{'data'} = $data_pack;
	$data{'description'} = $desc;
	return \%data;
}

sub phone {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my $data_pack;

	#### data pull and packaging

	$data_pack = $object->Phone;

	####
	
	$data{'data'} = $data_pack;
	$data{'description'} = $desc;
	return \%data;
}



sub fax {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my $data_pack;

	#### data pull and packaging

	$data_pack = $object->Fax;

	####
	
	$data{'data'} = $data_pack;
	$data{'description'} = $desc;
	return \%data;
}



sub email {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my $data_pack;

	#### data pull and packaging

	$data_pack = $object->Email;
	####
	
	$data{'data'} = $data_pack;
	$data{'description'} = $desc;
	return \%data;
}



sub web_site {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my $data_pack;

	#### data pull and packaging

	$data_pack = $object->URL;

	####
	
	$data{'data'} = $data_pack;
	$data{'description'} = $desc;
	return \%data;
}


##########
## details
##########

sub details {

	my $self = shift;
	my $lab = $self->object;
	my %data;
	my $desc = 'notes';
	my %data_pack;

	#### data pull and packaging

	my ($institution,@address)    = $lab->Address(2);
	my $fax =  $lab->Fax;  
	my $phone =  $lab->Phone;
	my $email =  $lab->Email;

	%data_pack = (

	  'name' => "$lab",
	  'instituion' => $institution,
	  'fax' => $fax,
	  'phone' => $phone,
	  'email' => $email
	  );

	####

	$data{'data'} = \%data_pack;
	$data{'description'} = $desc;
	return \%data;
}

sub representatives {

      my $self = shift;
      my $lab = $self->object;
      my %data;
      my $desc = 'notes';
      my %data_pack;

      #### data pull and packaging
    
      my @representatives = $lab->Representative;

   	foreach my $rep (@representatives) {
		my $name = $rep->Standard_name;
		my $laboratory = $rep->Laboratory;
		my @a   = $rep->Address(2);
		foreach (@a) {
	  		$_ = $_->right if $_->right;  # AtDB damnation
		}

		my $email = $rep->get('Email' => 1);
		$email = eval{$email->right if $email->right;};

		$data_pack{$rep} = {
	      'ace_id' => $rep,
	      'name' => $name,
	      'laboratory' => $laboratory,
	      'class' => 'Person',
	      'address' => \@a,
	      'email' => $email
	  	};

	}

	####

	$data{'data'} = \%data_pack;
	$data{'description'} = $desc;
	return \%data;
}


####################
# genes and alleles
####################

sub gene_class {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my @data_pack = [];

	#### data pull and packaging

	my @gene_classes;
	@gene_classes = $object->get('Gene_classes');	

	foreach my $gene_class (@gene_classes) {
	
	push @data_pack, {
	
						'id' => "$gene_class",
						'label' => "$gene_class",
						'class' => 'Gene_class'
						};
	}

	####
	
	$data{'data'} = \@data_pack;
	$data{'description'} = $desc;
	return \%data;
}

sub allele_designation {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my $data_pack;

	#### data pull and packaging

	$data_pack = $object->Allele_designation;

	####
	
	$data{'data'} = $data_pack;
	$data{'description'} = $desc;
	return \%data;
}


sub strain_designation {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my $data_pack;

	#### data pull and packaging

	$data_pack = $object->Strain_designation;

	####
	
	$data{'data'} = $data_pack;
	$data{'description'} = $desc;
	return \%data;
}


sub alleles {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my @data_pack;

	#### data pull and packaging

	my @alleles = $object->Alleles;

	foreach my $allele (@alleles) {
	
		my $allele_name = $allele->Public_name;
	
		push @data_pack, {
		
			'id' => "$allele",
			'lable' => "$allele_name",
			'class' => 'Variation'
		
		};
	}

	####
	
	$data{'data'} = \@data_pack;
	$data{'description'} = $desc;
	return \%data;
}


sub allele_prefixes {

	my $self = shift;
    my $lab = $self->object;
	my %data;
	my $desc = 'notes';
	my %data_pack;

	#### data pull and packaging

	my @alleles = $lab->get('Allele_designation');
	
	foreach my $allele (@alleles) {

	  my $allele_name; # = $allele->Public_name;
  
	 $data_pack{$allele} = {
	  'ace_id' => $allele,
	  'class' => 'Variation'
	  }

	 }
	####

	$data{'data'} = \%data_pack;
	$data{'description'} = $desc;
	return \%data;
}

#####################
# lab personnel
#####################

sub current_member {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my @data_pack;

	#### data pull and packaging
	
	my @current_members = $object->Registered_lab_members;
	
	foreach my $current_member (@current_members) {
	
		my $cm_name = $current_member->Full_name;
		
		push @data_pack, {
		
			'id' => "$current_member",
			'label' => "$cm_name",
			'class' => 'Person'
		};
	}
	
	####
	
	$data{'data'} = \@data_pack;
	$data{'description'} = $desc;
	return \%data;
}


sub former_member {

	my $self = shift;
    my $object = $self->object;
	my %data;
	my $desc = 'notes';
	my @data_pack;

	#### data pull and packaging
	
	my @former_members = $object->Past_lab_members;
	
	foreach my $former_member (@former_members) {
	
		my $fm_name = $former_member->Full_name;
		
		push @data_pack, {
		
			'id' => "$former_member",
			'label' => "$fm_name",
			'class' => 'Person'
		};
	}
	

	####
	
	$data{'data'} = \@data_pack;
	$data{'description'} = $desc;
	return \%data;
}


1; 