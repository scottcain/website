package WormBase::Web::Controller::REST;

use strict;
use warnings;
use parent 'Catalyst::Controller::REST';
use Time::Duration;
use XML::Simple;
use Crypt::SaltedHash;

__PACKAGE__->config(
    'default' => 'text/x-yaml',
    'stash_key' => 'rest',
    'map' => {
     'text/x-yaml' => 'YAML',,
     'text/html'          => 'YAML::HTML',
     'text/xml' => 'XML::Simple',
     'application/json'   => 'JSON',
    }
);

=head1 NAME

WormBase::Web::Controller::REST - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut
 
 


sub workbench :Path('/rest/workbench') :Args(0) :ActionClass('REST') {}
sub workbench_GET {
    my ( $self, $c) = @_;
    my $session = $self->get_session($c);
    my $url = $c->req->params->{url};
	if($url){
      my $class = $c->req->params->{class};
      my $save_to = $c->req->params->{save_to};
      my $loc = "saved reports";
      $save_to = 'reports' unless $save_to;
      if ($class eq 'paper') {
        $loc = "library";
        $save_to = 'my_library';
      }
      my $name = $c->req->params->{name};

      my $page = $c->model('Schema::Page')->find_or_create({url=>$url,title=>$name});
      my $saved = $page->user_saved->find({session_id=>$session->id});
      if($saved){
            $c->stash->{notify} = "$name has been removed from your $loc";
            $saved->delete();
            $saved->update(); 
      } else{
            $c->stash->{notify} = "$name has been added to your $loc"; 
            $c->model('Schema::UserSave')->find_or_create({session_id=>$session->id,page_id=>$page->page_id, save_to=>$save_to, time_saved=>time()}) ;
      }
    }
 	$c->stash->{noboiler} = 1;
    my $count = $session->pages->count;
    $c->stash->{count} = $count || 0;
    $c->stash->{template} = "workbench/count.tt2";
    $c->forward('WormBase::Web::View::TT');
} 

sub workbench_star :Path('/rest/workbench/star') :Args(0) :ActionClass('REST') {}

sub workbench_star_GET{
    my ( $self, $c) = @_;
    my $wbid = $c->req->params->{wbid};
    my $name = $c->req->params->{name};
    my $class = $c->req->params->{class};

    my $url = $c->req->params->{url};
    my $page = $self->get_session($c)->pages->find({url=>$url});

    if($page) {
          $c->stash->{star}->{value} = 1;
    } else{
        $c->stash->{star}->{value} = 0;
    }
    $c->stash->{star}->{wbid} = $wbid;
    $c->stash->{star}->{name} = $name;
    $c->stash->{star}->{class} = $class;
    $c->stash->{star}->{url} = $url;
    $c->stash->{template} = "workbench/status.tt2";
    $c->stash->{noboiler} = 1;
    $c->forward('WormBase::Web::View::TT');
}

sub layout :Path('/rest/layout') :Args(2) :ActionClass('REST') {}

sub layout_POST {
  my ( $self, $c, $class, $layout) = @_;
  $layout = 'default' unless $layout;
#   my %layoutHash = %{$c->user_session->{'layout'}->{$class}};
  my $i = 0;
  if($layout ne 'default'){
    $c->log->debug("max: " . join(',', (sort {$b <=> $a} keys %{$c->user_session->{'layout'}->{$class}})));
    
    $i = ((sort {$b <=> $a} keys %{$c->user_session->{'layout'}->{$class}})[0]) + 1;
    $c->log->debug("not default: $i");
  }
  $c->log->debug($i);
  my $left = $c->request->body_parameters->{'left[]'};
  my $right = $c->request->body_parameters->{'right[]'};  
  my $leftWidth = $c->request->body_parameters->{'leftWidth'};
  $c->user_session->{'layout'}->{$class}->{$i}->{'name'} = $layout;
  $c->user_session->{'layout'}->{$class}->{$i}->{'left'} = $left;
  $c->user_session->{'layout'}->{$class}->{$i}->{'right'} = $right;
  $c->user_session->{'layout'}->{$class}->{$i}->{'leftWidth'} = $leftWidth;
}

sub layout_GET {
  my ( $self, $c, $class, $layout) = @_;
  $c->stash->{noboiler} = 1;
  if ($c->req->params->{delete}){
    delete $c->user_session->{'layout'}->{$class}->{$layout};
    return;
  }
  unless (defined $c->user_session->{'layout'}->{$class}->{$layout}){
    $layout = 0;
  }
  my $left = $c->user_session->{'layout'}->{$class}->{$layout}->{'left'};
  my $right = $c->user_session->{'layout'}->{$class}->{$layout}->{'right'};
  my $leftWidth = $c->user_session->{'layout'}->{$class}->{$layout}->{'leftWidth'};
  my $name = $c->user_session->{'layout'}->{$class}->{$layout}->{'name'};
  if(ref($left) eq 'ARRAY') {$left = join(',', @$left);}
  if(ref($right) eq 'ARRAY') {$right = join(',', @$right);}

  $c->log->debug("left:" . $left);
  $c->log->debug("right:" . $right);
  $c->log->debug("leftWidth:" . $leftWidth);
    $c->forward('WormBase::Web::View::TT');
  $self->status_ok(
      $c,
      entity =>  {left => $left,
          right => $right,
          leftWidth => $leftWidth,
          name => $name,
      },
  );
}

sub layout_list :Path('/rest/layout_list') :Args(1) :ActionClass('REST') {}

sub layout_list_GET {
  my ( $self, $c, $class ) = @_;
  my @layouts = keys(%{$c->user_session->{'layout'}->{$class}});
  my %l;
  map {$l{$_} = $c->user_session->{'layout'}->{$class}->{$_}->{'name'};} @layouts;
  $c->log->debug("layout list:" . join(',',@layouts));
  $c->stash->{layouts} = \%l;
  $c->stash->{template} = "boilerplate/layouts.tt2";
  $c->stash->{noboiler} = 1;
    $c->forward('WormBase::Web::View::TT');
}



sub auth :Path('/rest/auth') :Args(0) :ActionClass('REST') {}

sub auth_GET {
    my ($self,$c) = @_;   
    $c->stash->{noboiler} = 1;
    $c->stash->{template} = "nav/status.tt2"; 
    $self->status_ok($c,entity => {});
    $c->forward('WormBase::Web::View::TT');
}

sub get_session {
    my ($self,$c) = @_;
    my $sid = $c->get_session_id;
    return $c->model('Schema::Session')->find({id=>"session:$sid"});
}


sub history :Path('/rest/history') :Args(0) :ActionClass('REST') {}

sub history_GET {
    my ($self,$c) = @_;
    my $clear = $c->req->params->{clear};

    my $session = $self->get_session($c);
    my @hist = $session->user_history;

    if($clear){ 
      map { 
        $_->visits->delete(); 
        $_->update(); 
      } $session->user_history;
    }

    my $size = @hist;
    my $count = $c->req->params->{count} || $size;
    if($count > $size) { $count = $size; }

    @hist = sort { $b->visits->get_column('visit_time')->max() <=> $a->visits->get_column('visit_time')->max()} @hist;

    my @histories;
    map {
      if($_->visits->count > 0){
        my $time = $_->visits->get_column('visit_time')->max();
        push @histories, {  time_lapse => concise(ago(time()-$time, 1)),
                            visits => $_->visits->count,
                            page => $_->page,
                          };
      }
    } @hist[0..$count-1];
    $c->stash->{history} = \@histories;
    $c->stash->{noboiler} = 1;
    $c->stash->{template} = "shared/fields/user_history.tt2"; 
    $c->forward('WormBase::Web::View::TT');
    $self->status_ok($c,entity => {});
}


sub history_POST {
    my ($self,$c) = @_;
    $c->log->debug("history logging");
    my $session = $self->get_session($c);
    my $path = $c->request->body_parameters->{'ref'};
    my $name = $c->request->body_parameters->{'name'};

    my $page = $session->visited->find({url=>$path});
    $page = $c->model('Schema::Page')->find_or_create({url=>$path,title=>$name}) unless $page;
    $c->log->debug("logging:" . $page->page_id);
    my $hist = $c->model('Schema::UserHistory')->find_or_create({session_id=>$session->id,page_id=>$page->page_id});
    $c->model('Schema::HistoryVisit')->create({user_history_id=>$hist->user_history_id,visit_time=>time()});
}

 
sub update_role :Path('/rest/update/role') :Args :ActionClass('REST') {}

sub update_role_POST {
      my ($self,$c,$id,$value,$checked) = @_;
      
	my $user=$c->model('Schema::User')->find({id=>$id}) if($id);
	my $role=$c->model('Schema::Role')->find({role=>$value}) if($value);
	
	my $users_to_roles=$c->model('Schema::UserRole')->find_or_create(user_id=>$id,role_id=>$role->id);
	$users_to_roles->delete()  unless($checked eq 'true');
	$users_to_roles->update();
       
}

sub evidence :Path('/rest/evidence') :Args :ActionClass('REST') {}

sub evidence_GET {
    my ($self,$c,$class,$name,$tag,$index,$right) = @_;

    my $headers = $c->req->headers;
    $c->log->debug($headers->header('Content-Type'));
    $c->log->debug($headers);
   
    unless ($c->stash->{object}) {
	# Fetch our external model
	my $api = $c->model('WormBaseAPI');
 
	# Fetch the object from our driver	 
	$c->log->debug("WormBaseAPI model is $api " . ref($api));
	$c->log->debug("The requested class is " . ucfirst($class));
	$c->log->debug("The request is " . $name);
	
	# Fetch a WormBase::API::Object::* object
	# But wait. Some methods return lists. Others scalars...
	$c->stash->{object} =  $api->fetch({class=> ucfirst($class),
					    name => $name}) or die "$!";
    }
    
    # Did we request the widget by ajax?
    # Supress boilerplate wrapping.
    if ( $c->is_ajax() ) {
	$c->stash->{noboiler} = 1;
    }

    my $object = $c->stash->{object};
    my @node = $object->object->$tag; 
    $right ||= 0;
    $index ||= 0;
    my $data = $object-> _get_evidence($node[$index]->right($right));
    $c->stash->{evidence} = $data;
    $c->stash->{template} = "shared/generic/evidence.tt2"; 
    $c->forward('WormBase::Web::View::TT');
    my $uri = $c->uri_for("/reports",$class,$name);
    $self->status_ok($c, entity => {
	                 class  => $class,
			 name   => $name,
	                 uri    => "$uri",
			 evidence => $data
		     }
	);
}


sub download : Path('/rest/download') :Args(0) :ActionClass('REST') {}

sub download_GET {
    my ($self,$c) = @_;
     
    my $filename=$c->req->param("type");
    $filename =~ s/\s/_/g;
    $c->response->header('Content-Type' => 'text/html');
    $c->response->header('Content-Disposition' => 'attachment; filename='.$filename);
#     $c->response->header('Content-Description' => 'A test file.'); # Optional line
#         $c->serve_static_file('root/test.html');
    $c->response->body($c->req->param("sequence"));
}
 
sub rest_register :Path('/rest/register') :Args(0) :ActionClass('REST') {}

sub rest_register_POST {
    my ( $self, $c) = @_;
     
    my $email = $c->req->params->{email};
    my $username = $c->req->params->{username};
    my $password = $c->req->params->{password};
    if($email && $username && $password){
	my $csh = Crypt::SaltedHash->new();
	$csh->add($password);
	my $hash_password= $csh->generate();
	my @users = $c->model('Schema::User')->search({email_address=>$email});
  	foreach (@users){
	   if($_->password && $_->active){
	      $c->res->body(0);
	      return 0;
	    }
	}  
	my $user=$c->model('Schema::User')->find_or_create({email_address=>$email, username=>$username, password=>$hash_password,active=>0}) ;
	 
	foreach my $key (sort keys %{$c->req->params}){
	  $c->stash->{info}->{$key}=$c->req->params->{$key};
	}
	$c->stash->{noboiler}=1;
	 
	  $csh->clear();
	  $csh->add($email."_".$username);
	  my $digest = $csh->generate();
	  $digest =~ s/^{SSHA}//;
	  $digest =~ s/\+/\%2B/g;
	  $c->stash->{digest}=$c->uri_for('/confirm')."?u=".$user->id."&code=".$digest ;
	
	$c->stash->{email} = {
		  to      => $email,
		  from    => $c->config->{register_email},
		  subject => "WormBase Account Activation", 
		  template => "auth/register_email.tt2",
	      };
	 
	$c->forward( $c->view('Email::Template') );
	$c->res->body(1); 
    }
    return 1;
}

sub feed :Path('/rest/feed') :Args :ActionClass('REST') {}

sub feed_GET {
    my ($self,$c,$type,$class,$name,$widget,$label) = @_;

    $c->stash->{noboiler} = 1;
    my $page ="/rest/widget/$class/$name/$widget/$label";
    $c->stash->{page} = $page;
    $c->stash->{class}=$class;
    if($type eq "issue"){
     # unless($c->user_exists) { $c->res->body("<script>alert('you need to login to use this function');</script>") ;return ;}
      my @issues;
      if( $class) {
	  @issues= $c->model('Schema::Issue')->search({location=>$page});
      }else {
	  @issues= $c->user->issues;
      }
      $c->stash->{issues} = \@issues if(@issues);  
      $c->stash->{current_time}=time();
    }
     $c->stash->{url} = "/rest/widget/$class/$name/$widget";  
     
     $c->stash->{template} = "feed/$type.tt2"; 

     $c->forward('WormBase::Web::View::TT') ;
    
     #$self->status_ok($c,entity => {});
}

sub feed_POST {
    my ($self,$c,$type) = @_;
    if($type eq 'issue'){
	if($c->req->params->{method} eq 'delete'){
	  my $id = $c->req->params->{issues};
	  if($id){
	    foreach (split('_',$id) ) {
		my $issue = $c->model('Schema::Issue')->find($_);
		$c->log->debug("delete issue #",$issue->id);
		$issue->delete();
		$issue->update();
	    }
	  }
	}else{
	  my $content= $c->req->params->{content};
	  my $title= $c->req->params->{title};
	  my $location= $c->req->params->{location};
	  if( $title && $content && $location) { 
	      my $user = $self->check_user_info($c);
	      return unless $user;
	      $c->log->debug("create new issue $content ",$user->id);
	      my $issue = $c->model('Schema::Issue')->find_or_create({reporter=>$user->id, title=>$title,location=>$location,content=>$content,state=>"new",'submit_time'=>time()});
 	      $c->model('Schema::UserIssue')->find_or_create({user_id=>$user->id,issue_id=>$issue->id}) ;
	      $self->issue_email($c,$issue,1,$content);
	  }
	}
    }elsif($type eq 'thread'){
	my $content= $c->req->params->{content};
	my $issue_id= $c->req->params->{issue};
	my $state= $c->req->params->{state};
	my $responser= $c->req->params->{responser};
	if($issue_id) { 
	   my $hash;
	   my $issue = $c->model('Schema::Issue')->find($issue_id);
	   if($state) {
	      $hash->{status}={old=>$issue->state,new=>$state};
	      $issue->state($state) ;
	   }
	   if($responser) {
	      my $people=$c->model('Schema::User')->find($responser);
	      $hash->{responser}={old=>$issue->responser,new=>$people};
	      $issue->responser($responser)  ;
	      $c->model('Schema::UserIssue')->find_or_create({user_id=>$responser,issue_id=>$issue_id}) ;
	   }
	   $issue->update();
	    
	   my $user = $self->check_user_info($c);
	   return unless $user;
	   my $thread  = { owner=>$user,
			  submit_time=>time(),
	   };
	   if($content){
		$c->log->debug("create new thread for issue #$issue_id!");
		my @threads= $issue->issues_to_threads(undef,{order_by=>'thread_id DESC' } ); 
		my $thread_id=1;
		$thread_id = $threads[0]->thread_id +1 if(@threads);
		$thread= $c->model('Schema::IssueThread')->find_or_create({issue_id=>$issue_id,thread_id=>$thread_id,content=>$content,submit_time=>$thread->{submit_time},user_id=>$user->id});
		$c->model('Schema::UserIssue')->find_or_create({user_id=>$user->id,issue_id=>$issue_id}) ;
	  }  
	  if($state || $responser || $content){
	     
	      $self->issue_email($c,$issue,$thread,$content,$hash);
	  }
	}
    }
}

sub check_user_info {
  my ($self,$c) = @_;
  my $user;
  if($c->user_exists) {
	  $user=$c->user; 
	  $user->username($c->req->params->{username}) if($c->req->params->{username});
	  $user->email_address($c->req->params->{email}) if($c->req->params->{email});
  }else{
	  if($user = $c->model('Schema::User')->find({email_address=>$c->req->params->{email},active =>1})){
	    $c->res->body(0) ;return 0 ;
	  }
	  $user=$c->model('Schema::User')->find_or_create({email_address=>$c->req->params->{email}}) ;
	  $user->username($c->req->params->{username}),
  }
  $user->update();
  return $user;
}
=head2 pages() pages_GET()

Return a list of all available pages and their URIs

TODO: This is currently just returning a dummy object

=cut

sub issue_email{
 my ($self,$c,$issue,$new,$content,$change) = @_;
 my $subject='New Issue';
 my $bcc = $issue->owner->email_address if($issue->owner);
 unless($new == 1){
    $subject='Issue Update';
    my @threads= $issue->issues_to_threads;
    $bcc .= ",".$issue->responser->email_address if($issue->responser);
    my %seen=();  
    $bcc = join ",", grep { ! $seen{$_} ++ } map {$_->user->email_address} @threads;
 }
 $subject = '[WormBase.org] '.$subject.' '.$issue->id.': '.$issue->title;
 
 $c->stash->{issue}=$issue;
 
 $c->stash->{new}=$new;
 $c->stash->{content}=$content;
 $c->stash->{change}=$change;
 $c->stash->{noboiler} = 1;
 $c->stash->{email} = {
		  to      => $c->config->{issue_email},
		  cc => $bcc,
		  from    => $c->config->{issue_email},
		  subject => $subject, 
		  template => "feed/issue_email.tt2",
	      };
   
  $c->forward( $c->view('Email::Template') );
}

sub pages : Path('/rest/pages') :Args(0) :ActionClass('REST') {}

sub pages_GET {
    my ($self,$c) = @_;
    my @pages = keys %{ $c->config->{pages} };

    my %data;
    foreach my $page (@pages) {
	my $uri = $c->uri_for('/page',$page,'WBGene00006763');
	$data{$page} = "$uri";
    }

    $self->status_ok( $c,
		      entity => { resultset => {  data => \%data,
						  description => 'Available (dynamic) pages at WormBase',
				  }
		      }
	);
}



######################################################
#
#   WIDGETS
#
######################################################

=head2 available_widgets(), available_widgets_GET()

For a given CLASS and OBJECT, return a list of all available WIDGETS

eg http://localhost/rest/available_widgets/gene/WBGene00006763

=cut

sub available_widgets : Path('/rest/available_widgets') :Args(2) :ActionClass('REST') {}

sub available_widgets_GET {
    my ($self,$c,$class,$name) = @_;

    # Does the data for this widget already exist in the cache?
    my ($cache_id,$data) = $c->check_cache('available_widgets');

    my @widgets = @{$c->config->{pages}->{$class}->{widget_order}};
    
    foreach my $widget (@widgets) {
	my $uri = $c->uri_for('/widget',$class,$name,$widget);
	push @$data, { widgetname => $widget,
		       widgeturl  => "$uri"
	};
	$c->cache->set($cache_id,$data);
    }
    
    # Retain the widget order
    $self->status_ok( $c, entity => {
	data => $data,
	description => "All widgets available for $class:$name",
		      }
	);
}




# Request a widget by REST. Gathers all component fields
# into a single data structure, passing it to a unified
# widget template.

=head widget(), widget_GET()

Provided with a class, name, and field, return its content

eg http://localhost/rest/widget/[CLASS]/[NAME]/[FIELD]

=cut

sub widget :Path('/rest/widget') :Args(3) :ActionClass('REST') {}

sub widget_GET {
    my ($self,$c,$class,$name,$widget) = @_; 
   
    my $headers = $c->req->headers;
    $c->log->debug("widget GET header ".$headers->header('Content-Type'));
    $c->log->debug($headers);

    $c->log->debug("this is NOT a bench page widget");
    # It seems silly to fetch an object if we are going to be pulling
    # fields from the cache but I still need for various page formatting duties.
    unless ($c->stash->{object}) {
	# Fetch our external model
	my $api = $c->model('WormBaseAPI');
	
	# Fetch the object from our driver	 
	$c->log->debug("WormBaseAPI model is $api " . ref($api));
	$c->log->debug("The requested class is " . ucfirst($class));
	$c->log->debug("The request is " . $name);
	
	# Fetch a WormBase::API::Object::* object
	# But wait. Some methods return lists. Others scalars...
	$c->stash->{object} = $api->fetch({class=> ucfirst($class),
					   name => $name}) or die "$!";
    }
    my $object = $c->stash->{object};

    # Does the data for this widget already exist in the cache?
    my ($cache_id,$cached_data) = $c->check_cache($class,$widget,$name);


    my $status;

    # The cache ONLY includes the field data for the widget, nothing else.
    # This is because most backend caches cannot store globs.
    if ($cached_data) {
	$c->stash->{fields} = $cached_data;
    } else {

	# No result? Generate and cache the widget.		

	# Is this a request for the references widget?
	# Return it (of course, this will ONLY be HTML).
	if ($widget eq "references") {
	    $c->stash->{class}    = $class;
	    $c->stash->{query}    = $name;
	    $c->stash->{noboiler} = 1;
	    
	    # Looking up the template is slow; hard-coded here.
	    $c->stash->{template} = "shared/widgets/references.tt2";
	    $c->forward('WormBase::Web::View::TT');
	    return;
	}elsif($widget eq "aligner" ||$widget eq "show_mult_align" ) {
	    $c->res->redirect("/tools/".$widget."/run?inline=1&sequence=".$name) ;
	    return;
       }

#    unless ($c->stash->{object}) {
#	# Fetch our external model
#	my $api = $c->model('WormBaseAPI');
#	
#	# Fetch the object from our driver	 
#	$c->log->debug("WormBaseAPI model is $api " . ref($api));
#	$c->log->debug("The requested class is " . ucfirst($class));
#	$c->log->debug("The request is " . $name);
#	
#	# Fetch a WormBase::API::Object::* object
#	# But wait. Some methods return lists. Others scalars...
#	$c->stash->{object} = $api->fetch({class=> ucfirst($class),
#					   name => $name}) or die "$!";
#    }
#    my $object = $c->stash->{object};

	
	# Load the stash with the field contents for this widget.
	# The widget itself could make a series of REST calls for each field but that could quickly become unwieldy.
	my @fields = $c->_get_widget_fields($class,$widget);
	       		
	foreach my $field (@fields) {
        unless ($field) { next;}
	    $c->log->debug($field);
	    my $data = {};
	    $data = $object->$field if defined $object->$field;
	    
	    # Conditionally load up the stash (for now) for HTML requests.
	    # Alternatively, we could return JSON and have the client format it.
	    $c->stash->{fields}->{$field} = $data; 
	}
		
	# Cache the field data for this widget.
	$c->set_cache($cache_id,$c->stash->{fields});
    }
    
    # Save the name of the widget.
    $c->stash->{widget} = $widget;

    # No boiler since this is an XHR request.
    $c->stash->{noboiler} = 1;

    # Set the template
    $c->stash->{template}="shared/generic/rest_widget.tt2";
    $c->stash->{child_template} = $c->_select_template($widget,$class,'widget'); 	

    # Forward to the view for rendering HTML.
    my $format = $headers->header('Content-Type') || $c->req->params->{'content-type'};
    $c->detach('WormBase::Web::View::TT') unless($format) ;
    
	# TODO: AGAIN THIS IS THE REFERENCE OBJECT
    # PERHAPS I SHOULD INCLUDE FIELDS?
    # Include the full uri to the *requested* object.
    # IE the page on WormBase where this should go.
    my $uri = $c->uri_for("/page",$class,$name);
    $self->status_ok($c, entity => {
	class   => $class,
	name    => $name,
	uri     => "$uri",
	fields => $c->stash->{fields},
		     }
	);
   $format ||= 'text/html';
   my $filename = "rest_widget_".$class."_".$name."_".$widget.".".$c->config->{api}->{content_type}->{$format};
   $c->log->debug("$filename download in the format: $format");
   $c->response->header('Content-Type' => $format);
   $c->response->header('Content-Disposition' => 'attachment; filename='.$filename);
   
}


sub widget_home :Path('/rest/widget/home') :Args(1) :ActionClass('REST') {}

sub widget_home_GET {
    my ($self,$c,$widget) = @_; 
    my ($self,$c,$widget) = @_; 
    $c->log->debug("getting home page widget");
    if($widget=~m/issues/){
      $c->stash->{issues} = $self->issue_rss($c,2);
    }
    if($widget=~m/activity/){
      $c->stash->{results} = $self->recently_saved($c,3);
    }
    $c->stash->{template} = "classes/home/$widget.tt2";
    $c->stash->{noboiler} = 1;
    $c->forward('WormBase::Web::View::TT')
}

sub recently_saved {
 my ($self,$c,$count) = @_;
    my $api = $c->model('WormBaseAPI');
    my @saved = $c->model('Schema::UserSave')->search(undef,
                {   select => [ 
                      'page_id', 
                      { max => 'time_saved', -as => 'latest_save' }, 
                    ],
                    as => [ qw/
                      page_id 
                      time_saved
                    /], 
                    order_by=>'latest_save DESC', 
                    group_by=>[ qw/page_id/]
                })->slice(0, $count-1);

    my @ret;
    foreach my $report (@saved){
      my @objs;
      my($class, $id) = $self->parse_url($c, $report->page->url);
      $c->log->debug("saved $class, $id"); 
      my $time = ago((time() - $report->time_saved), 1);
      if (!$id || $class=~m/page/) {
        push(@ret, { name => {  url => $report->page->url, 
                                label => $report->page->title,
                                id => $report->page->title,
                                class => 'page' },
                     footer => $time,
                    });
      }else{
      my $obj = $api->fetch({class=> ucfirst($class),
                          name => $id}) or die "$!";
      push(@objs, $obj); 
      @objs = @{$api->search->_wrap_objs(\@objs, $class)};
      @objs = map { $_->{footer} = $time; $_;} @objs;
      push(@ret, @objs);
      }
    }
    $c->stash->{'type'} = 'all'; 

    return \@ret;
}

sub issue_rss {
 my ($self,$c,$count) = @_;
 my @issues = $c->model('Schema::Issue')->search(undef,{order_by=>'submit_time DESC'} )->slice(0, $count-1);
    my $threads= $c->model('Schema::IssueThread')->search(undef,{order_by=>'submit_time DESC'} );
     
    my %seen;
    my @rss;
    while($_ = $threads->next) {
      unless(exists $seen{$_->issue_id}) {
      $seen{$_->issue_id} =1 ;
      my $time = ago((time() - $_->submit_time), 1);
      push @rss, {  time=>$_->submit_time,
            time_lapse=>$time,
            people=>$_->user,
            title=>$_->issue->title,
            location=>$_->issue->location,
            id=>$_->issue->id,
            re=>1,
            } ;
      }
      last if(scalar(keys %seen)>=$count)  ;
    };

    map {    
      my $time = ago((time() - $_->submit_time), 1);
        push @rss, {      time=>$_->submit_time,
                          time_lapse=>$time,
                          people=>$_->owner,
                          title=>$_->title,
                          location=>$_->location,
                  id=>$_->id,
            };
    } @issues;

    my @sort = sort {$b->{time} <=> $a->{time}} @rss;
    return \@sort;
}


### NOTE: Make this more robust
sub parse_url{
    my ($self,$c, $url) = @_; 
    if($url=~m/#/){ return; }
    my @parts = split(/\//,$url); 
    my $class = $parts[-2];
    my $wb_id = $parts[-1];
    
    return ($class, $wb_id);
}

sub widget_me :Path('/rest/widget/me') :Args(1) :ActionClass('REST') {}

sub widget_me_GET {
    my ($self,$c,$widget) = @_; 
    $c->log->debug("getting me widget");
    my $api = $c->model('WormBaseAPI');
    my @ret;
    my $type;
    $c->stash->{'bench'} = 1;
    if($widget=~m/user_history/){
      $self->history_GET($c);
      return;
    } elsif($widget=~m/profile/){
      $c->stash->{noboiler} = 1;
      $c->res->redirect('/profile');
      return;
    }elsif($widget=~m/issue/){
      $self->feed_GET($c,"issue");
      return;
    }
    if($widget=~m/my_library/){ $type = 'paper';} else { $type = 'all';}

    my $session = $self->get_session($c);
    my @reports = $session->user_saved->search({save_to => $widget});
    $c->log->debug("getting saved reports @reports for user $session->id");  
    foreach my $report (@reports){
      my @objs;
      my($class, $id) = $self->parse_url($c, $report->page->url);
      $c->log->debug("saved $class, $id");
      my $time = ago((time() - $report->time_saved), 1);
     if (!$id || $class=~m/page/) {
        push(@ret, { name => {  url => $report->page->url, 
                                label => $report->page->title,
                                id => $report->page->title,
                                class => 'page' },
                     footer => "added $time",
                    });
      }else{
        my $obj = $api->fetch({class=> ucfirst($class),
                            name => $id}) or die "$!";

        push(@objs, $obj); 

        @objs = @{$api->search->_wrap_objs(\@objs, $class)};
        @objs = map { $_->{footer} = "added $time"; $_;} @objs;
        push(@ret, @objs);
      }
    }
    $c->stash->{'results'} = \@ret;
    $c->stash->{'type'} = $type; 
#     $c->stash->{template} = "search/results.tt2";
    $c->stash->{template} = "workbench/widget.tt2";
    $c->stash->{noboiler} = 1;
    $c->forward('WormBase::Web::View::TT');
    return;
}






######################################################
#
#   SPECIES WIDGETS (as opposed to /species)
#
######################################################
sub widget_species :Path('/rest/widget/species_summary') :Args(2) :ActionClass('REST') {}

sub widget_species_GET {
    my ($self,$c,$species,$widget) = @_; 
    $c->log->debug("getting species widget");

    # Check for the presence of generic templates.

    $c->stash->{template} = "species/$species/$widget.tt2";
    $c->stash->{noboiler} = 1;
}








######################################################
#
#   FIELDS
#
######################################################

=head2 available_fields(), available_fields_GET()

Fetch all available fields for a given WIDGET, PAGE, NAME

eg  GET /rest/fields/[WIDGET]/[CLASS]/[NAME]


# This makes more sense than what I have now:
/rest/class/*/available_widgets  - all available widgets
/rest/class/*/widget   - the content for a given widget

/rest/class/*/widget/available_fields - all available fields for a widget
/rest/class/*/widget/field

=cut

sub available_fields : Path('/rest/available_fields') :Args(3) :ActionClass('REST') {}

sub available_fields_GET {
    my ($self,$c,$widget,$class,$name) = @_;


    # Does the data for this widget already exist in the cache?
    my ($cache_id,$data) = $c->check_cache('available_fields');

    unless ($data) {	
	my @fields = eval { @{ $c->config->{pages}->{$class}->{widgets}->{$widget} }; };
	
	foreach my $field (@fields) {
	    my $uri = $c->uri_for('/rest/field',$class,$name,$field);
	    $data->{$field} = "$uri";
	}
	$c->set_cache($cache_id,$data);
    }
    
    $self->status_ok( $c, entity => { data => $data,
				      description => "All fields that comprise the $widget for $class:$name",
		      }
	);
}


=head field(), field_GET()

Provided with a class, name, and field, return its content

eg http://localhost/rest/field/[CLASS]/[NAME]/[FIELD]

=cut

sub field :Path('/rest/field') :Args(3) :ActionClass('REST') {}

sub field_GET {
    my ($self,$c,$class,$name,$field) = @_;

    my $headers = $c->req->headers;
    $c->log->debug($headers->header('Content-Type'));
    $c->log->debug($headers);

    unless ($c->stash->{object}) {
	# Fetch our external model
	my $api = $c->model('WormBaseAPI');
 
	# Fetch the object from our driver	 
	$c->log->debug("WormBaseAPI model is $api " . ref($api));
	$c->log->debug("The requested class is " . ucfirst($class));
	$c->log->debug("The request is " . $name);
	
	# Fetch a WormBase::API::Object::* object
	# But wait. Some methods return lists. Others scalars...
	$c->stash->{object} =  $api->fetch({class=> ucfirst($class),
					    name => $name}) or die "$!";
    }
    
    # Did we request the widget by ajax?
    # Supress boilerplate wrapping.
    if ( $c->is_ajax() ) {
	$c->stash->{noboiler} = 1;
    }


    my $object = $c->stash->{object};
    my $data = $object->$field();

    # Should be conditional based on content type (only need to populate the stash for HTML)
     $c->stash->{$field} = $data;
#      $c->stash->{data} = $data->{data};
#     $c->stash->{field} = $field;
    # Anything in $c->stash->{rest} will automatically be serialized
#    $c->stash->{rest} = $data;

    
    # Include the full uri to the *requested* object.
    # IE the page on WormBase where this should go.
    my $uri = $c->uri_for("/page",$class,$name);

    $c->stash->{template} = $c->_select_template($field,$class,'field'); 

    $self->status_ok($c, entity => {
	class  => $class,
			 name   => $name,
	                 uri    => "$uri",
			 $field => $data
		     }
	);
}





=cut

=head1 AUTHOR

Todd Harris

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
