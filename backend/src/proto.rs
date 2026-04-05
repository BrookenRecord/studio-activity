pub mod api {
    pub mod v1 {
        pub mod ping {
            include!(concat!(env!("OUT_DIR"), "/api.v1.rs"));
        }
    }
}
