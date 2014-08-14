package WormBase::Web::ThirdParty::Mendeley;

use Moose;
use JSON::Any;
use Net::OAuth::Simple;
use URI::Escape;
use HTTP::Request;
use HTTP::Request::Common;
use LWP::UserAgent;
use Encode;

has 'consumer_key'       => (is => 'ro', isa => 'Str',  required => 1);
has 'consumer_secret'    => (is => 'ro', isa => 'Str',  required => 1);
has 'authorization_url'  => (is => 'ro', isa => 'Str',  required => 1);
has 'access_token_url'   => (is => 'ro', isa => 'Str',  required => 1);
has 'request_token_url'  => (is => 'ro', isa => 'Str',  required => 1);

has 'json_data'  => (is => 'rw', isa => 'Str');
has 'api'        => (is => 'ro', lazy_build => 1);  # Authenticated API

has 'credentials' => (is => 'ro',
                      lazy_build => 1,
                      'builder' => '_build_credentials');
has 'token'      => (is => 'rw', 'builder' => '_build_token');

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

    my $key = $self->fetch_mendeley_id($id,$type);

    # Now get related documents.
    my $url    = 'https://api-oauth2.mendeley.com/oapi/documents/related';
    my $params = "$key";

    # Make request
    my $response = eval { $self->public_api_request($url . "$key") };

    my $json = JSON::Any->new();
    my $data = undef;
    $response && $json->jsonToObj( $response->content );
    return $data;
}


sub fetch_mendeley_id {
    my ($self,$id,$type) = @_;

    # Example:
    # http://api.mendeley.com/oapi/documents/details/doi:10.1038\/nmeth.1454?type=doi;consumer-key=XXXX
    my $url    = "https://api-oauth2.mendeley.com/oapi/documents/details/";

    # KLUDGE. Mendeley chokes on single encoded DOIs.
    if ($type eq 'doi') {
        $id = uri_escape($id);
    }
    $url = $url . $id;

    my $params = {
        'type' => $type
    };

    # Make request
    my $response = $self->public_api_request($url,$params);

    my $json = JSON::Any->new();
    my $data;
    $response && keys %{$response} && $response->content ;
 #   my $data = $self->check_response($response) && $json->jsonToObj( $response->content );
    return $data->{key} if ref($data) eq 'HASH';
}




# # Try and find a paper on Mendeley.
# # Provided with a pubmed ID, find the corresponding
# # Mendeley entry.
# # http://api.mendeley.com/oapi/documents/details/20418868?type=pmid&consumer_key=f67b2a45de14e07cc9658f779dd22a5804d32335b
# sub search_papers {
#     my ($self,$id,$type) = @_;

#     # Example:
#     # http://api.mendeley.com/oapi/documents/details/doi:10.1038\/nmeth.1454?type=doi;consumer-key=XXXX
#     my $url    = 'https://api-oauth2.mendeley.com/oapi/documents/details';
#     my $params = uri_escape($id);

#     # KLUDGE. Mendeley chokes on single encoded DOIs.
#     if ($type eq 'doi') {
# 	$params = uri_escape($params) . "?type=$type";
#     } else {
# 	$params = $params . "?type=$type";
#     }

#     # Make request
#     my $response = $self->public_api_request($url,$params,'get');

#     return $response;
# }

sub public_api_request {
    my ($self,$url,$params, $args) = @_;

    my $token = $self->token;
    return unless $token;

    my $uri     = URI->new("$url");
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


sub url_as_json {
    my ($self,$url,$format) = @_;
    $format ||= 'json';
    $self->json_data($self->request);
}

sub send_request {
    my ($self, $request) = @_;

    my $lwp       = LWP::UserAgent->new;
    my $response  = $lwp->request($request);
print Dumper $response;
    unless ($response->is_success){
        my $response_code = $response->code;
        print "Error code: $response_code " . $response->message;
        die "$response_code";
    }

    my $json = new JSON;
    return $json->allow_nonref->utf8->relaxed->decode($response->content);
}
# '_content' => '{"access_token":"MSwxNDA3NzI1ODcxMjE3LCw3MjIsLCxxaENUR3NqWFplRk1BMVp4TGZaeENHYktueU0","token_type":"bearer","expires_in":3600,"refresh_token":null}',


sub _build_token {

    my ($self, $args) = @_;
    my $grant_type = $args->{'grant_type'} || 'client_credentials';
    my $uri     = URI->new("https://api-oauth2.mendeley.com/oauth/token"); #?grant_type=client_credentials"); #&scope=all&client_id=$client_id&client_secret=$client_secret");
    my $req = POST("https://api-oauth2.mendeley.com/oauth/token",
                   [ grant_type  => $grant_type ],
                   Content_Type => 'application/x-www-form-urlencoded'
               );

    $req->authorization_basic($self->credentials->{'client_id'},
                              $self->credentials->{'client_secret'});

    my $response = eval { $self->send_request($req) };
    my $token = $response;
    print Dumper $response;
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


sub check_response {
    my ($self, $response) = @_;
    my $ok = $response->code eq '200';
    return $ok;
}


1;
