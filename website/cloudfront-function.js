// CloudFront Function (viewer request) — "rewrite-index"
//
// Purpose: resolve directory-style URLs to their index.html object key.
// The nearbuyallim.com distribution uses the private S3 *REST* origin
// (s3.us-east-1.amazonaws.com) with OAC, which — unlike the S3 *website*
// endpoint — does NOT map "/verify/" to "/verify/index.html". Without this
// rewrite, folder paths return "403 AccessDenied" from S3.
//
// This maps:
//   "/"        -> "/index.html"        (homepage)
//   "/verify"  -> "/verify/index.html" (email-verification landing page)
//   "/verify/" -> "/verify/index.html"
//   any "/foo" with no file extension -> "/foo/index.html"
//
// Deploy:
//   1. CloudFront Console -> Functions -> Create function -> name it
//      "rewrite-index" -> paste this code -> Publish.
//   2. Distribution E1MCDD8F88E6T8 -> Behaviors -> default (*) -> Edit ->
//      Function associations -> Viewer request -> CloudFront Functions ->
//      select "rewrite-index" -> Save.
//   3. Invalidate the cache:
//      aws cloudfront create-invalidation \
//        --distribution-id E1MCDD8F88E6T8 --paths "/*"

function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (uri.endsWith('/')) {
    request.uri += 'index.html';
  } else if (!uri.includes('.')) {
    request.uri += '/index.html';
  }

  return request;
}
