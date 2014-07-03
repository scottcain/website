package WormBase::API::Role::Expression;

use Moose::Role;
use File::Spec::Functions qw(catfile catdir);

#######################################################
#
# Attributes
#
#######################################################

#######################################################
#
# Generic methods, shared across Gene and Transcript classes
#
#######################################################


############################################################
#
# Private Methods
#
############################################################

# anatomic_expression_patterns { }
# This method will return a complex data structure
# containing expression patterns described at the
# anatomic level. Includes links to images.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/gene/WBGene00006763/anatomic_expression_patterns

has '_gene' => (
    is       => 'ro',
    isa      => 'ArrayRef[Ace::Object]',
    required => 1,
    lazy     => 1,
    builder  => '_build__gene',
);

has 'exp_sequences' => (
    is  => 'ro',
    lazy => 1,
    builder => '_build_sequences',
);

requires '_build__gene'; # no fallback to build segments... yet (or ever?).

sub anatomic_expression_patterns {
    my $self   = shift;
    my @object = $self->_gene;
    my @genes;


    foreach my $obj (@object){

        my $file = catfile($self->pre_compile->{image_file_base},$self->pre_compile->{gene_expression_path}, "$obj.jpg");
        my $image = catfile($self->pre_compile->{gene_expression_path}, "$obj.jpg") if (-e $file && ! -z $file);
        push @genes , { "image" => $image };
    }

    #my %data_pack;

    #my $file = catfile($self->pre_compile->{image_file_base},$self->pre_compile->{gene_expression_path}, "$object.jpg");
    #$data_pack{"image"}=catfile($self->pre_compile->{gene_expression_path}, "$object.jpg") if (-e $file && ! -z $file);


    #return {
    #    description => 'expression patterns for the gene',
    #    data        => %data_pack ? \%data_pack : undef,
    #};

    return {
        description => 'expression patterns for the gene',
        data        => @genes ? \@genes : undef
    };
}



sub expression_patterns {
    my $self   = shift;
    my @object = @{$self->_gene};
    my @genes;
    my @data;
    $self->log->debug("Genes: " . join(', ', @object));

    foreach my $obj (@object){

        $self->log->debug("OBJECT: " . $obj);
        foreach my $expr ($obj->Expr_pattern) {
            my $type = $expr->Type;
            next if $type =~ /Microarray|Tiling_array/;
            push @data, $self->_expression_pattern_details($expr, $type);
        }
         push @genes, {
            description => "expression patterns associated with the gene:$obj",
            data        => @data ? \@data: undef
            };
    }

    return @genes ? \@genes : undef;
}


sub expression_profiling_graphs {
    my $self   = shift;
    my @object = $self->_gene;
    my @genes;
    my @data;

    foreach my $obj (@object){
        foreach my $expr ($obj->Expr_pattern) {
            my $type = $expr->Type;
            next unless $type =~ /Microarray|Tiling_array/;
            push @data, $self->_expression_pattern_details($expr, $type);
        }
        push @genes, {
        description => "expression patterns associated with the gene:$obj",
        data        => @data ? \@data: undef
        };
    }

    return @genes ? \@genes : undef;
}

sub _expression_pattern_details {
    my ($self, $expr, $type) = @_;

    my $author = $expr->Author;
    my @patterns = $expr->Pattern
        || $expr->Subcellular_localization
        || $expr->Remark;
    my $desc = join("<br />", @patterns) if @patterns;
    $type =~ s/_/ /g if $type;
    my $reference = $self->_pack_obj($expr->Reference);

    my @expressed_in = map { $self->_pack_obj($_) } $expr->Anatomy_term;
    my @life_stage = map { $self->_pack_obj($_) } $expr->Life_stage;
    my @go_term = map { $self->_pack_obj($_) } $expr->GO_term;
    my @transgene = map {
            my @cs =map { "$_" } $_->Construction_summary;
            @cs ?   {   text=>$self->_pack_obj($_),
                        evidence=>{'Construction summary'=> \@cs }
                    } : $self->_pack_obj($_)
        } $expr->Transgene;
    my $expr_packed = $self->_pack_obj($expr, "$expr");


    my $file = catfile($self->pre_compile->{image_file_base},$self->pre_compile->{expression_object_path}, "$expr.jpg");
    $expr_packed->{image}=catfile($self->pre_compile->{expression_object_path}, "$expr.jpg")  if (-e $file && ! -z $file);
    foreach($expr->Picture) {
        next unless($_->class eq 'Picture');
        my $pic = $self->_api->wrap($_);
        if( $pic->image->{data}) {
            $expr_packed->{curated_images} = 1;
            last;
        }
    }
    my $sub = $expr->Subcellular_localization;

    my @dbs;
    foreach my $db ($expr->DB_info) {
        # assuming we don't have any other fields other than id
        foreach my $id (map { $_->col } $db->col) {
            push @dbs, { class => "$db",
                         label => "$db",
                         id    => "$id" };
        }
    }

    return {
        expression_pattern =>  $expr_packed,
        description        => $reference ? { text=> $desc, evidence=> {'Reference' => $reference}} : $desc,
        type             => $type && "$type",
        database         => @dbs ? \@dbs : undef,
        expressed_in    => @expressed_in ? \@expressed_in : undef,
        life_stage    => @life_stage ? \@life_stage : undef,
        go_term => @go_term ? {text => \@go_term, evidence=>{'Subcellular localization' => "$sub"}} : undef,
        transgene => @transgene ? \@transgene : undef

    };
}

# anatomy_terms { }
# This method will return a hash
# containing unique anatomy terms described from the
# expression patterns associated with this gene
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/gene/WBGene00006763/anatomy_terms

sub anatomy_terms {
    my $self   = shift;
    my @object = $self->_gene;
    my %unique_anatomy_terms;

    foreach my $obj (@object){
        for my $ep ( $obj->Expr_pattern ) {
            for my $at ($ep->Anatomy_term) {

              $unique_anatomy_terms{"$at"} ||= $self->_pack_obj($at);
            }
        }
    }

    return {
        description => 'anatomy terms from expression patterns for the gene',
        data        => %unique_anatomy_terms ? \%unique_anatomy_terms : undef,
    };
}

# expression_cluster { }
# This method will return a data structure containing
# microarray expression clusters.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/gene/WBGene00006763/expression_cluster

sub expression_cluster {
    my $self   = shift;
    my @object = $self->_gene;
    my @data;
    my @genes;

    foreach my $obj (@object){
        foreach my $expr_cluster ($obj->Expression_cluster){
            my $description = $expr_cluster->Description;
            push @data, {
                expression_cluster => $self->_pack_obj($expr_cluster),
                description => $description && "$description"
            }
        }
        push @genes, @data;
    }
    return { data        => @genes ? \@genes : undef,
             description => 'expression cluster data' };
}

# fourd_expression_movies { }
# This method will return a data structure containing
# links to four-dimensional expression movies.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/gene/WBGene00006763/fourd_expression_movies
sub fourd_expression_movies {
    my $self   = shift;
    my @object = $self->_gene;
    my @genes;

    my $author;
    foreach my $obj (@object){
        my %data = map {
            my $details = $_->Pattern;
            my $url     = $_->MovieURL;
            $_ => {
                movie   => $url && "$url",
                details => $details && "$details",
                object  => $self->_pack_obj($_),
            };
        } grep {
            (($author = $_->Author) && $author =~ /Mohler/ && $_->MovieURL)
        } @{$obj->Expr_pattern};
        #} @{$self ~~ '@Expr_pattern'};
        push @genes, %data;
    }

    return {
        description => 'interactive 4D expression movies',
        data        => @genes ? \@genes : undef,
    };
}

# microrarray_topology_map_position { }
# This method will return a data structure containing
# the microarray "topology" map position.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/gene/WBGene00006763/microarray_topology_map_position

sub microarray_topology_map_position {
    my $self   = shift;
    my @object = $self->_gene;

    my $datapack = {
        description => 'microarray topology map',
        data        => undef,
    };

    return $datapack unless @{$self->exp_sequences};
    my @segments = $self->_segments && @{$self->_segments};
    return $datapack unless $segments[0];
    my @p = map { $_->info }
            $segments[0]->features('experimental_result_region:Expr_profile')
        or return $datapack;
    my %data = map {
        $_ => $self->_pack_obj($_, eval { 'Mountain ' . $_->Expr_map->Mountain })
    } @p;

    $datapack->{data} = \%data if %data;
    return $datapack;
}

# anatomy_function { }
# This method will return a data structure containing
# the anatomy function of the gene.
# eg: curl -H content-type:application/json http://api.wormbase.org/rest/field/gene/WBGene00006763/anatomy_function

sub anatomy_function {
    my $self   = shift;
    my @object = $self->_gene;
    my @data_pack;
    my @genes;

    foreach my $obj (@object){
        foreach ($obj->Anatomy_function){
          my @bp_inv = map { if ("$_" eq "$obj") {my $term = $_->Term; { text => $term && "$term", evidence => $self->_get_evidence($_)}}
                    else { { text => $self->_pack_obj($_), evidence => $self->_get_evidence($_)}}
                    } $_->Involved;
          next unless @bp_inv;
          my @assay = map { my $as = $_->right;
                      if ($as) {
                          my @geno = $as->Genotype;
                          {evidence => { genotype => join('<br /> ', @geno) },
                          text => "$_",}
                      }
                    } $_->Assay;
          my $pev;
          push @data_pack, {
              phenotype => ($pev = $self->_get_evidence($_->Phenotype)) ?
                                { evidence => $pev,
                                text => $self->_pack_obj(scalar $_->Phenotype)} : $self->_pack_obj(scalar $_->Phenotype),
              assay    => @assay ? \@assay : undef,
              bp_inv    => @bp_inv ? \@bp_inv : undef,
              reference => $self->_pack_obj(scalar $_->Reference),
          };
        }
        push @genes, @data_pack;
    }

    return {
        data        => @genes ? \@genes : undef,
        description => 'anatomy functions associatated with this gene',
    };
}


sub fpkm_expression_summary_ls {
    my $self = shift;
    return $self->fpkm_expression('summary_ls');
}

sub fpkm_expression {
    my $self = shift;
    my $mode = shift;
    my @object = $self->_gene;
    my @genes;

    my $rserve = $self->_api->_tools->{rserve};

    foreach my $obj (@object){
            my @fpkm_map = map {
                my $life_stage = $_->Public_name;
                my @fpkm_table = $_->col;
                map {
                    my @fpkm_entry = $_->row;
                    my $label = $fpkm_entry[2];
                    my $value = $fpkm_entry[0];
                    my ($project) = $label =~ /^([a-zA-Z0-9_-]+)\./;
                    {
                        label => "$label",
                        value => "$value",
                        project => "$project",
                        life_stage => "$life_stage"
                    }
                } @fpkm_table;
            } $obj->RNASeq_FPKM;

            # Return if no expression data is available.
            # Yes, it has to be <= 1, because there will be an undef entry when no data is present.
            if (length(keys @fpkm_map) <= 1) {
                return {
                    description => 'Fragments Per Kilobase of transcript per Million mapped reads (FPKM) expression data -- no data returned.',
                    data        => undef
                };
            }

            # Sort by project (primary order) and developmental stage (secondary order):
            @fpkm_map = sort {
                # Primary sorting order: project
                # Reverse comparison, so that projects that come first in the alphabet appear at the top of the barchart.
                return $b->{project} cmp $a->{project} if $a->{project} ne $b->{project};

                # Secondary sorting order: developmental stage
                my @sides = ($a, $b);
                my @label_value = (50, 50); # Entries that cannot be matched to the regexps will go to the bottom of the barchart.
                for my $i (0 .. 1) {
                    # UNAPPLIED
                    # Possible keywords? Not seen in data yet (browsing only).
                    #$label_value[$i] =  0 if ($sides[$i]->{label} =~ m/gastrula/i);
                    #$label_value[$i] =  1 if ($sides[$i]->{label} =~ m/comma/i);
                    #$label_value[$i] =  2 if ($sides[$i]->{label} =~ m/15_fold/i);
                    #$label_value[$i] =  3 if ($sides[$i]->{label} =~ m/2_fold/i);
                    #$label_value[$i] =  4 if ($sides[$i]->{label} =~ m/3_fold/i);

                    # EMBRYO STAGES
                    $label_value[$i] = 30 if ($sides[$i]->{label} =~ m/embryo/i); # May be overwritten by the next two rules.
                    if ($sides[$i]->{label} =~ m/\.([0-9]+)-cell_embryo/) {
                        # Assuming an upper bound of 40 cells (for ordering below).
                        $sides[$i]->{label} =~ /\.([0-9]+)-cell_embryo/;
                        $label_value[$i] = "$1";
                    }
                    $label_value[$i] =  0 if ($sides[$i]->{label} =~ m/early_embryo/i);
                    $label_value[$i] = 40 if ($sides[$i]->{label} =~ m/late_embryo/i);

                    # LARVA STAGES
                    $label_value[$i] = 41 if ($sides[$i]->{label} =~ m/L1_(l|L)arva/);
                    $label_value[$i] = 43 if ($sides[$i]->{label} =~ m/L2_(l|L)arva/);
                    $label_value[$i] = 42 if ($sides[$i]->{label} =~ m/L2d_(l|L)arva/i);
                    $label_value[$i] = 43 if ($sides[$i]->{label} =~ m/L3_(l|L)arva/);
                    $label_value[$i] = 45 if ($sides[$i]->{label} =~ m/L4_(l|L)arva/);

                    # DAUER STAGES
                    $label_value[$i] = 43 if ($sides[$i]->{label} =~ m/dauer/i); # May be overwritten by the next two rules.
                    $label_value[$i] = 42 if ($sides[$i]->{label} =~ m/dauer_entry/);
                    $label_value[$i] = 44 if ($sides[$i]->{label} =~ m/dauer_exit/);
                    $label_value[$i] = 42 if ($sides[$i]->{label} =~ m/predauer/i);

                    # ADULTHOOD
                    $label_value[$i] = 47 if ($sides[$i]->{label} =~ m/adult/); # May be overwritten by the next rule.
                    $label_value[$i] = 46 if ($sides[$i]->{label} =~ m/young_adult/);
                }

                # Reversed comparison, so that early stages appear at the top of the barchart.
                return $label_value[1] <=> $label_value[0];
            } @fpkm_map;


        my $plot;


        if ($mode eq 'summary_ls') {
        # This is NOT consistently returning an ID, resulting in fpkm_.png
        # and breaking the expression widget.
        # filename => "fpkm_" . $self->name->{data}{id} . ".png",
        #my $obj = $self->object;
            $plot = $rserve->boxplot(\@fpkm_map, {
                                        filename => "fpkm_$obj.png",
                                        xlabel   => WormBase::Web->config->{fpkm_expression_chart_xlabel},
                                        ylabel   => WormBase::Web->config->{fpkm_expression_chart_ylabel},
                                        width    => WormBase::Web->config->{fpkm_expression_chart_width},
                                        height   => WormBase::Web->config->{fpkm_expression_chart_height},
                                        rotate   => WormBase::Web->config->{fpkm_expression_chart_rotate},
                                        bw       => WormBase::Web->config->{fpkm_expression_chart_bw},
                                        facets   => WormBase::Web->config->{fpkm_expression_chart_facets},
                                        adjust_height_for_less_than_X_facets => WormBase::Web->config->{fpkm_expression_chart_height_shorter_if_less_than_X_facets}
                                     })->{uri};
        } else {
            $plot = $rserve->barchart(\@fpkm_map, {
                                        filename => "fpkm_$obj.png",
                                        xlabel   => WormBase::Web->config->{fpkm_expression_chart_xlabel},
                                        ylabel   => WormBase::Web->config->{fpkm_expression_chart_ylabel},
                                        width    => WormBase::Web->config->{fpkm_expression_chart_width},
                                        height   => WormBase::Web->config->{fpkm_expression_chart_height},
                                        rotate   => WormBase::Web->config->{fpkm_expression_chart_rotate},
                                        bw       => WormBase::Web->config->{fpkm_expression_chart_bw},
                                        facets   => WormBase::Web->config->{fpkm_expression_chart_facets},
                                        adjust_height_for_less_than_X_facets => WormBase::Web->config->{fpkm_expression_chart_height_shorter_if_less_than_X_facets}
                                     })->{uri};
        }

        push @genes, {
                plot => $plot,
                table => { fpkm => { data => \@fpkm_map } }
            };

    }

        return {
            description => 'Fragments Per Kilobase of transcript per Million mapped reads (FPKM) expression data',
            data        =>  @genes ? \@genes : undef,
        };

}


1;
