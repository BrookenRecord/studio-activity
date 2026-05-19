use std::{io::Result, path::Path};
use walkdir::WalkDir;

fn main() -> Result<()> {
    let proto_root = Path::new("../protos");

    let protos: Vec<_> = WalkDir::new(proto_root)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().is_some_and(|ext| ext == "proto"))
        .map(|e| e.into_path())
        .collect();

    if protos.is_empty() {
        println!("cargo:warning=No .proto files found");
        return Ok(());
    }

    println!("cargo:rerun-if-changed={}", proto_root.display());
    for proto in &protos {
        println!("cargo:rerun-if-changed={}", proto.display());
    }

    // Step 1: Generate prost types into a known directory
    let descriptor_path =
        std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap()).join("proto_descriptor.bin");

    let mut config = prost_build::Config::new();
    config.file_descriptor_set_path(&descriptor_path);
    config.compile_well_known_types();

    // Give the oneof enum a snake_case serde Serialize so decompose_event()
    // can split it into (event_name, properties) via the externally-tagged
    // representation. pbjson handles everything else.
    config.type_attribute(
        ".api.v1.TelemetryRequest.event",
        "#[derive(serde::Serialize)]\n#[serde(rename_all = \"snake_case\")]",
    );

    config.compile_protos(&protos, &[proto_root])?;

    // Step 2: Generate pbjson serde impls from the descriptor
    let descriptor_set = std::fs::read(&descriptor_path)?;
    pbjson_build::Builder::new()
        .register_descriptors(&descriptor_set)?
        .build(&[".api"])?;

    Ok(())
}
