use worker::Cf;

/// Snapshot of Cloudflare edge metadata for a single request.
#[derive(Clone, Debug)]
#[allow(unused)]
pub struct EdgeContext {
    pub cf: Option<Cf>,

    pub asn: Option<u32>,
    pub as_organization: Option<String>,
    pub country: Option<String>,
    pub colo: Option<String>,

    /// Useful correlation id (from header) if present.
    pub cf_ray: Option<String>,

    /// Best-effort client ip (from header).
    pub client_ip: Option<String>,
}

impl EdgeContext {
    pub fn from_worker_request(req: &worker::Request) -> Self {
        let cf = req.cf().cloned();

        let (asn, as_organization, country, colo) = match &cf {
            Some(cf) => (
                cf.asn(),
                cf.as_organization(),
                cf.country(),
                Some(cf.colo()),
            ),
            None => (None, None, None, None),
        };

        let cf_ray = req.headers().get("cf-ray").ok().flatten();
        let client_ip = req.headers().get("cf-connecting-ip").ok().flatten();

        Self {
            cf,
            asn,
            as_organization,
            country,
            colo,
            cf_ray,
            client_ip,
        }
    }
}
