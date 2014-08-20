package WormBase::Web::ThirdParty::Mendeley;

use Moose;
use JSON::Any;
use Net::OAuth::Simple;
use URI::Escape;
use HTTP::Request;
use HTTP::Request::Common;
use LWP::UserAgent;
use Encode;



our $_base_url = 'https://api.mendeley.com';
has 'base_url' => (
    is => 'ro',
    isa => 'Str',
    default => sub { return $_base_url} );

has 'credentials' => (is => 'ro',
                      lazy_build => 1,
                      'builder' => '_build_credentials');
has 'token'      => (is => 'rw', lazy_build => 1, 'builder' => '_build_token');

use Data::Dumper;
# sub _build_api {
#     my ($self) = @_;
#     my %tokens = ( consumer_key => $self->consumer_key,
#                    consumer_secret => $self->consumer_secret );

#     my $api =  Net::OAuth::Simple->new( tokens => \%tokens,
# 					protocol_version => '1.0',
# 					urls   => {
# 					    authorization_url => $self->authorization_url,
# 					    request_token_url => $self->request_token_url,
# 					    access_token_url  => $self->access_token_url,
# 					});

#     # HARD-CODED
#     $api->callback("http://todd.wormbase.org/auth/mendeley");
# #    my ($access_token, $access_token_secret) = $api->request_access_token;

#     # in the case of a web app, you want to save the request tokens
#     # (and/or set them)
# #    my $request_token        = $api->request_token;
# #    my $request_token_secret = $api->request_token_secret;
# #    $api->request_token( $request_token );
# #    $api->request_token_secret( $request_token_secret );

#     return $api;
# }


#################################################
#
#
#   Public Methods (2Leg OAuth)
#
#
#################################################

# Provided with a pubmed or doi, find related papers on Mendeley.
# http://api.mendeley.com/oapi/documents/related/20418868?type=pmid&consumer_key=f67b2a45de14e07cc9658f779dd22a5804d32335b
sub related_papers {
    my ($self,$id,$type) = @_;
    return unless $id;

    my $mendeley_obj = $self->fetch_mendeley_object($id,$type);
    return unless $mendeley_obj;
    return;
    # Now get related documents.

}

# Example:
# $id = '10.1016/j.febslet.2005.08.001'
# https://api.mendeley.com:443/catalog?doi=10.1016%2Fj.febslet.2005.08.001
# $id = '16162338'
# https://api.mendeley.com:443/catalog?pmid=16162338
sub fetch_mendeley_object {
    my ($self,$id,$type) = @_;
    my $url    = "catalog/";

    # KLUDGE. Mendeley chokes on single encoded DOIs.
    if ($type eq 'doi') {
        $id = uri_escape($id);
    }

    my $params = {
        $type => $id,
    };

    # Make request
    my $result = $self->public_api_request($url, $params);
    return @{$result} ? pop @{$result} : undef;
}

sub public_api_request {
    my ($self,$url,$params, $args) = @_;

    my $token = $self->token;
    return unless $token;

    my $uri     = URI->new($self->base_url);
    $uri->path("$url");
    $uri->query_form($params);

    my $method = $args->{'method'} || 'GET';
    my $req = HTTP::Request->new(GET => $uri);

    $req->header(
        'Authorization' => 'Bearer ' . $token->{'access_token'},
        'Content-Type' => 'application/json'
    );

    my $response;
    eval {
        $response = $self->send_request($req);
        1;
    } || do {
        my $error_code = $@;
        if ($error_code eq '401'){
            $self->_build_token({ grant_type => 'refresh_token' });
        }
    };

    return $response;
}

sub send_request {
    my ($self, $request) = @_;

    my $lwp       = LWP::UserAgent->new;
    my $response  = $lwp->request($request);
print $request->url . "\n";
#print Dumper $response;
    unless ($response->is_success){
        my $response_code = $response->code;
#        print "Error code: $response_code " . $response->message;
        die "$response_code";
    }

    my $json = new JSON;
    return $json->allow_nonref->utf8->relaxed->decode($response->content);
}


sub _build_token {

    my ($self, $args) = @_;
    my $grant_type = $args->{'grant_type'} || 'client_credentials';
    my $uri     =  URI->new($_base_url);
    $uri->path('oauth/token');

    my $req = POST($uri,
                   [ grant_type  => $grant_type ],
                   Content_Type => 'application/x-www-form-urlencoded'
               );

    $req->authorization_basic($self->credentials->{'client_id'},
                              $self->credentials->{'client_secret'});

    my $response = eval { $self->send_request($req) };
    my $token = $response;

    return $token;
}

sub _build_token_old {

    my ($self) = @_;
    my $uri     = URI->new("https://api-oauth2.mendeley.com/oauth/token"); #?grant_type=client_credentials"); #&scope=all&client_id=$client_id&client_secret=$client_secret");
    my $req = HTTP::Request->new(POST => "https://api-oauth2.mendeley.com/oauth/token",
                                 [],  #
                                 'grant_type=client_credentials');
    $req->authorization_basic($self->credentials->{'client_id'},
                              $self->credentials->{'client_secret'});

  #  $req->content(grant_type  => 'client_credentials');
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');

    # my $content = {
    #     grant_type  => 'client_credentials',
    #     client_id => $self->credentials->{'client_id'},
    #     client_secret =>  $self->credentials->{'client_secret'},
    # }; #'client_credentials' };
#     my $json = new JSON;
#     my $request_json = $json->encode($content);
# # print $request_json;
# #    $req->content($request_json);
print $req->as_string();
    my $lwp       = LWP::UserAgent->new;
    my $response  = $lwp->request($req);
print $response->as_string; print 'QQQQ';
    my $token = $response if $response->is_success();  #CHANGE this;
    return $token;
}

sub _build_credentials {
    my ($self) = @_;
    my $path = WormBase::Web->path_to('/') . '/credentials';
    my $client_id = `cat $path/mendeley/client_id.txt`;
    chomp $client_id;
    my $client_secret = `cat $path/mendeley/client_secret.txt`;
    chomp $client_secret;

    die 'Missing credentials' unless $client_id && $client_secret;

    return {
        client_id => $client_id,
        client_secret => $client_secret
    };
}


# sub send_request {
#     my $self    = shift;
#     my $class   = shift;
#     my $url     = shift;
#     my $method  = uc(shift);
#     my @extra   = @_;

#     my $uri   = URI->new($url);
#     my %query = $uri->query_form;
#     $uri->query_form({});

#     my $request = $class->new(
#         consumer_key     => $self->consumer_key,
#         consumer_secret  => $self->consumer_secret,
#         request_url      => $uri,
#         request_method   => $method,
#         signature_method => $self->signature_method,
#         protocol_version => $self->oauth_1_0a ? Net::OAuth::PROTOCOL_VERSION_1_0A : Net::OAuth::PROTOCOL_VERSION_1_0,
#         timestamp        => time,
#         nonce            => $self->_nonce,
#         extra_params     => \%query,
#         @extra,
# 	);
#     $request->sign;
#     return $self->_error("Couldn't verify request! Check OAuth parameters.")
# 	unless $request->verify;

#     my $params  = $request->to_hash;
#     $uri->query_form(%$params);
#     my $req      = HTTP::Request->new( $method => "$uri");
#     my $response = $self->{browser}->request($req);
#     return $self->_error("$method on ".$request->normalized_request_url." failed: ".$response->status_line." - ".$response->content)
# 	unless ( $response->is_success );

#     return $response;
# }



1;
