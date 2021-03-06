package WormBase::API::Object::Phenotype;

use Moose;
use JSON;

with 'WormBase::API::Role::Object';
extends 'WormBase::API::Object';

=pod

=head1 NAME

WormBase::API::Object::Phenotype

=head1 SYNPOSIS

Model for the Ace ?Phenotype class.

=head1 URL

http://wormbase.org/species/phenotype

=cut

#######################################
#
# CLASS METHODS
#
#######################################

#######################################
#
# INSTANCE METHODS
#
#######################################

#######################################
#
# The Overview Widget
#
#######################################

#  name { }
# Supplied by Role

# description { }
# Supplied by Role

# remarks {}
# Supplied by Role

# synonyms { }
# This method will return a data structure containing synonyms for the phenotype.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/synonym

sub synonyms {
    my $self     = shift;
    my $object   = $self->object;
    my @synonyms = map { "$_" } $object->Synonym;
    return {
        description => 'Synonymous name of the phenotype ',
        data        => @synonyms ? \@synonyms : undef };
}

# is_dead { }
# This method will return a data structure noting that the phenotype is retired and replaced by another.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/is_dead

sub is_dead {
    my $self = shift;
    my $object = $self->object;
    my $alternate = $object->Dead->right if $object->Dead(0);

    return {
        description => "The Note of the phenotype when it's retired and replaced by another.",
        data        => $alternate ? $self->_pack_obj($alternate,$self->best_phenotype_name($alternate)) : undef,
    };
}


# related_phenotypes { }
# This method will return a data structure providing the generalize and specialized terms for the phenotype in the ontology.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/related_phenotypes

sub related_phenotypes {
    my $self      = shift;
    my $phenotype = $self->object;
    my $result;
    if ( $phenotype->Related_phenotypes(0) ) {
        foreach my $tag (qw/Specialisation_of Generalisation_of/) {
          ( my $type = $tag ) =~ s/_/ /g;
          my @entries;
          foreach my $ph ( $phenotype->$tag ) {
            push @entries,$self->_pack_obj($ph);
          }
          $result->{$type} = \@entries if (scalar @entries > 0);
        }
    }
    return { description => 'The generalized and specialized terms in the ontology for this phenotype.',
	     data        => (scalar keys %{$result} > 0) ? $result : undef,
    };
}


############################################################
#
# The Ontology Browser widget
#
############################################################

############################################################
#
# The Gene Ontology Widget
#
############################################################

# go_term { }
# This method will return a data structure go terms annotating the phenotype.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/go_term

sub go_term {
    my $self        = shift;
    my $object      = $self->object;
    my @tag_objects = $object->GO_term;
    my @data_pack;

    foreach my $tag_object (@tag_objects) {
    	my $term_pack = $self->_pack_obj($tag_object,$tag_object->Term); ## , $tag_object->Term
    	push @data_pack, $term_pack; ## {go_term => $term_pack}
    }

    return {
        data        => @data_pack ? \@data_pack : undef,
        description => 'go terms associated with phenotype'
    };
}


############################################################
#
# The RNAi widget
#
############################################################

# rnai { }
# This method will return a data structure rnai experiments in which the phenotype was observed.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/rnai

sub rnai {
    my $self      = shift;
    my $object    = $self->object;
    my $data_pack = $self->_rnai('RNAi');
    return {
        'data'        => $data_pack,
        'description' => 'RNAi experiments associated with this phenotype'
    };
}

#rnai_not { }
# This method will return a data structure with RNAi experiments in which the phenotype was not observed.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/rnai_not

sub rnai_not {
    my $self      = shift;
    my $object    = $self->object;
    my $data_pack = $self->_rnai('Not_in_RNAi');
    return {
        data        => $data_pack,
        description => 'rnais not associated with this phenotype'
    };
}

############################################################
#
# The Variation widget
#
############################################################

# variation { }
# This method will return a data structure with variations in which the phenotype was observed.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/variation

sub variation {
    my $self      = shift;
    my $object    = $self->object;
    my $data_pack = $self->_variation('Variation');
    return {
        data        => @$data_pack ? $data_pack : undef,
        description => 'variations associated with this phenotype'
    };
}

# variation_not { }
# This method will return a data structure with variations in which the phenotype was not observed.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/variation_not

sub variation_not {
    my $self      = shift;
    my $object    = $self->object;
    my $data_pack = $self->_variation('Not_in_Variation');
    return {
        'data'        => @$data_pack ? $data_pack : undef,
        'description' => 'variations not associated with this phenotype'
    };
}



############################################################
#
# The Transgene widget
#
############################################################

# transgene { }
# This method will return a data structure with transgene experiments in which the phenotype was observed.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/transgene

sub transgene {
    my $self      = shift;
    my $object    = $self->object;
    my $data_pack = $self->_transgene('Transgene');
    return {
        'data'        => @$data_pack ? $data_pack : undef,
        'description' => 'transgenes associated with this phenotype'
    };
}

# transgene_not { }
# This method will return a data structure transgene experiments in which the phenotype was not observed.
# curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/transgene_not

sub transgene_not {
    my $self      = shift;
    my $object    = $self->object;
    my $data_pack = $self->_transgene('Not_in_Transgene');
    return {
        'data'        => @$data_pack ? $data_pack : undef,
        'description' => 'transgenes not associated with this phenotype'
    };
}


############################################################
#
# The Anatomy Ontology widget
#
############################################################

# anatomy_ontology
# This method will return a data structure anatomy_ontology terms associated with the phenotype via anatomy_function.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/phenotype/WBPhenotype:0000643/anatomy_ontology

sub anatomy_ontology {
    my $self = shift;
    my $object = $self->object;
    my @anatomy_fns = $object->Anatomy_function;
    my @data_pack;
    my %anatomy_term_check;
    foreach my $anatomy_fn (@anatomy_fns) {
        my $anatomy_fn_name = $anatomy_fn->Involved  if $anatomy_fn;
        my $anatomy_term    = $anatomy_fn_name->Term if $anatomy_fn_name;
        my $anatomy_term_id = $anatomy_term->Name_for_anatomy_term
          if $anatomy_term;
        my $anatomy_term_name = $anatomy_term_id->Term if $anatomy_term_id;
        next unless ($anatomy_term_id);
        if ($anatomy_term_check{$anatomy_term_id}) {
        	next;
        }
        else {
        	$anatomy_term_check{$anatomy_term_id} = 1;
        	push @data_pack, $self->_pack_obj($anatomy_term_id,$anatomy_term_name);
        }
    }
    return {
        description => "The Anatomy Ontology of the phenotype ",
        data        => @data_pack ? \@data_pack : undef,
    };
}


# anatomy_functions { }
# This method will return a data structure anatomy_functions associated with this anatomy_term.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/anatomy_term/eg WBbt:0005175/anatomy_functions

sub associated_anatomy {
    my ($self) = @_;

    my $data = $self->_anatomy_function('Anatomy_function');
    return {
        data        => @$data ? $data : undef,
        description => 'anatomy_functions associatated with this anatomy_term',
    };
}




############################################################
#
# Private methods
#
############################################################

sub _anatomy_function {
    my ($self, $tag) = @_;
    my $object = $self->object;
    my @data_pack;
    foreach ($object->$tag){
	my @bp_inv = map { if ("$_" eq "$object") {my $term = $_->Term; { text => $term && "$term", evidence => $self->_get_evidence($_)}}
			   else { { text => $self->_pack_obj($_), evidence => $self->_get_evidence($_)}}
			  } $_->Involved;
	my @bp_not_inv = map { if ("$_" eq "$object") {my $term = $_->Term; { text => $term && "$term", evidence => $self->_get_evidence($_)}}
               else { { text => $self->_pack_obj($_), evidence => $self->_get_evidence($_)}}
			  } $_->Not_involved;

	# Genotype removed from the evidence hash in WS234?
	my @assay = map { my $as = $_->right;
			  if ($as) {
			      my @geno = $as->Genotype;
			      {evidence => { genotype => join('<br /> ', @geno) },
			       text => "$_",}
			  }
	} $_->Assay;
	my $pev;
	push @data_pack, {
            af_data   => $_ && "$_",
            phenotype => ($pev = $self->_get_evidence($_->Phenotype)) ?
                          { evidence => $pev,
                           text => $self->_pack_obj(scalar $_->Phenotype)} : $self->_pack_obj(scalar $_->Phenotype),
            gene      => $self->_pack_obj(scalar $_->Gene),
        assay    => @assay ? \@assay : undef,
	    bp_inv    => @bp_inv ? \@bp_inv : undef,
	    bp_not_inv=> @bp_not_inv ? \@bp_not_inv : undef,
	    reference => $self->_pack_obj(scalar $_->Reference),
	    };
    } # array of hashes -- note the comma

    return \@data_pack;
}

sub rnai_json {
    return {
        description => 'RNAi experiments in which Phenotype is observed',
        data        => shift->_get_json_data('RNAi'),
    };
}

sub rnai_not_json {
    return {
        description => 'RNAi experiments in which Phenotype is not observed',
        data        => shift->_get_json_data('Not_in_RNAi'),
    };
}

sub variation_json {
    my $self = shift;
    return {
        description => "The related variation of the phenotype",
        data        => shift->_get_json_data('Variation'),
    };
}

sub variation_not_json {
    my $self = shift;
    return {
        description => "Variations in which the phenotype is not observed",
        data        => shift->_get_json_data('Not_in_Variation'),
    };
}

sub go_term_json {
    return {
        description => "The related Go term of the phenotype",
        data        => shift->_format_objects('GO_term'),
    };
}

sub transgene_json {
    return {
        description => "The related transgene of the phenotype ",
        data        => shift->_get_json_data('Transgene'),
    };
}

sub transgene_not_json {
    return {
        description =>
          "Transgene experiments in which phenotype is not observed ",
        data => shift->_get_json_data('Not_in_Transgene'),
    };
}

############################################################
#
# The Private Methods
#
############################################################

sub _transgene {
    my $self   = shift;
    my $tag    = shift;
    my $object = $self->object;
    my @data_pack;
    my @tag_objects = $object->$tag;

    foreach my $tag_object (@tag_objects) {
        my $tag_info = $self->_pack_obj($tag_object);
	my $oe_gene          = $tag_object->Gene ? $self->_pack_obj($tag_object->Gene) : '';
	my $reporter_product = $tag_object->Reporter_product ? $self->_pack_obj($tag_object->Reporter_product) : '';

	my @oe_genes;
	push @oe_genes,$oe_gene          if $oe_gene;
	push @oe_genes,$reporter_product if $reporter_product;

	# Deal with the Phenotype_info hash for the CURRENT phenotype only.
	# Wow, this is really circular.
	my @phenotypes = $tag_object->Phenotype;
	my %tags_with_evidence;
	my @caused_by;
	foreach my $phenotype (@phenotypes) {
	    next unless $phenotype eq $object;
	    my %hash = map { $_ => $_->right } eval { $phenotype->col };

	    # Keys with evidence
	    foreach my $tag (qw/Caused_by Caused_by_other Remark/) {
		if (defined $hash{$tag}) {
		    my $text     = $self->_pack_obj($hash{$tag});
		    my $evidence = $self->_get_evidence($hash{$tag});
		    # This is a string.
		    if ($tag eq 'Caused_by_other') {
			$text = "$hash{$tag}";
		    }

		    $tags_with_evidence{$tag} = { text     => $text,
						  evidence => $evidence };
		}
	    }
	}

	push @caused_by,$tags_with_evidence{Caused_by};
	push @caused_by,$tags_with_evidence{Caused_by_other};
        push @data_pack, {
	    transgene => $tag_info,
		overexpressed_genes => \@oe_genes,
		remark             => $tags_with_evidence{Remark},
#		caused_by          => $tags_with_evidence{Caused_by},
		caused_by          => \@caused_by,
        };
    }
    return \@data_pack;
}

sub _variation {
    my $self   = shift;
    my $tag    = shift;
    my $object = $self->object;
    my @data_pack;
    my @tag_objects = $object->$tag;

    foreach my $tag_object (@tag_objects) {
        my $tag_info       = $self->_pack_obj($tag_object);
        my $variation_type = $tag_object->Variation_type;
        my @gene_info      = map { $self->_pack_obj($_) } $tag_object->Gene
	    if $tag_object->Gene;
        my $species_info = $self->_pack_obj( $tag_object->Species )
	    if $tag_object->Species;
        push @data_pack,
	{
            variation => $tag_info,
            gene      => \@gene_info,
            type      => $variation_type && "$variation_type",
            species   => $species_info
	};
    }
    return \@data_pack;
}

sub _rnai {
    my $self   = shift;
    my $tag    = shift;
    my $object = $self->object;
    my @data_pack;
    my $count = $self->_get_count($object, $tag);

    my @tag_objects = $object->$tag if $count < 650;

    foreach my $tag_object (@tag_objects) {
        my $tag_info      = $self->_pack_obj($tag_object);
        my @genes = $tag_object->Gene;
        my $strain   = $tag_object->Strain;
        $strain = $strain ? $self->_pack_obj($strain) : undef;
        my $sequence      = $tag_object->Sequence;
        my $sequence_info = $self->_pack_obj( $tag_object->Sequence )
          if $tag_object->Sequence;
        my $species_info = $self->_pack_obj( $tag_object->Species )
          if $tag_object->Species;
        my $genotype =   $tag_object->Genotype;
        my $treatment = $tag_object->Treatment;
        push @data_pack,

        {
            rnai     => $tag_info,
            sequence => $sequence_info,
            species  => $species_info,
            genotype => $genotype && "$genotype",
            treatment => $treatment && "$treatment",
            strain    => $strain,
        };
    }

    return @data_pack ? \@data_pack : $count ? "$count found" : undef;
}

sub _get_json_data {
    my ( $self, $tag ) = @_;
    my $result;
    my $file = $self->tmp_acedata_dir() . "/" . $self->object . ".$tag.txt";
    if ( -s $file ) {
        open( F, "<$file" );
        $result = from_json(<F>);
        close F;
    }
    else {
        $result = $self->_format_objects($tag);
        open( F, ">$file" );
        print F to_json($result);
        close F;
    }
    return $result;
}

sub _format_objects {
    my ( $self, $tag ) = @_;
    my $phenotype = $self->object;
    my %result;
    my $is_not;
    my @items = $phenotype->$tag;
    my @content_array;
    my @content_array_not;
    foreach (@items) {
        my @array;
        my $str = $_;
        if ( $tag =~ m/rnai/i ) {
            my $cds  = $_->Predicted_gene || "";
            my $gene = $_->Gene;
            my $cgc  = eval { $gene->CGC_name } || "";
            if ($gene) {
                push @array,
                  {
                    id    => "$gene",
                    label => "$cgc",
                    class => $gene->class,
                  };
            }
            else { push @array, ""; }
            if ($cds) {
                push @array,
                  {
                    id    => "$cds",
                    label => "$cds",
                    class => $cds->class,
                  };
            }
            else {
                push @array, "";
            }
            if ( my $sp = $_->Species ) {
                $sp =~ /(.*) (.*)/;
                push @array,
		{
                    genus   => $1,
                    species => $2,
		};
            }
            else { push @array, ""; }

            #$is_not = _is_not($_,$phenotype);
            if ( $tag =~ m/not/i ) {
                $is_not = 0;
            }
            else {
                $is_not = 1;
            }
        }
        elsif ( $tag eq 'GO_term' ) {
            my $joined_evidence;
            my $desc = $_->Term || $_->Definition;
            $str =
                ( ($desc) ? "$desc" : "$str" )
		. ( ($joined_evidence) ? "; $joined_evidence" : '' );
        }
        elsif ( $tag =~ m/variation/i ) {    ##eq 'Variation'
	    # $is_not = _is_not($_,$phenotype);
	    my $is_not = ( $tag =~ m/not/i ) ? 0 : 1;

            my $gene = $_->Gene;
            if ($gene) {
                push @array,$self->_pack_obj($gene,$gene->Public_name);
            } else { push @array, ""; }
            $str = $_->Public_name;
            if ( my $sp = $_->Species ) {
                $sp =~ /(.*) (.*)/;
                push @array,
		{
                    genus   => $1,
                    species => $2,
		};
            }
            else { push @array, ""; }
        }
        elsif ( $tag =~ m/transgene/i ) {    ## eq 'Transgene'
            my $genotype = $_->Summary || "";
            push @array, "$genotype";
            if ( $tag =~ m/not/i ) {
                $is_not = 0;
            }
            else {
                $is_not = 1;
            }
        }
        my %real_tags = (
            'Not_in_Variation' => 'Variation',
            'Not_in_Transgene' => 'Transgene'
        );
        my $real_tag;
        if ( $real_tags{$tag} ) {
            $real_tag = $real_tags{$tag};
        }
        else {
            $real_tag = $tag;
        }
        my $hash = {
            label => "$str",
            class => $real_tag,
            id    => "$_",
        };

        unshift @array, $hash;

        if ($is_not) {
            push @content_array_not, \@array;
        }
        else {
            push @content_array, \@array;
        }
    }
    if ( defined $is_not ) {
        $result{0}{"aaData"} = \@content_array;
        $result{1}{"aaData"} = \@content_array_not;
    }
    else {
        $result{"aaData"} = \@content_array;
    }
    return \%result;
}

sub _is_not {
    my ( $obj, $phene ) = @_;
    my @phenes = $obj->Phenotype;
    foreach (@phenes) {
        next unless $_ eq $phene;
        my %keys = map { $_ => 1 } $_->col;
        return 1 if $keys{Not};
        return 0;
    }
}

__PACKAGE__->meta->make_immutable;

1;

