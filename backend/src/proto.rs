pub mod api {
    pub mod v1 {
        include!(concat!(env!("OUT_DIR"), "/api.v1.rs"));
    }
}
