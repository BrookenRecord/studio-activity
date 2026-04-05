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

    // Rerun if protos change
    println!("cargo:rerun-if-changed={}", proto_root.display());
    for proto in &protos {
        println!("cargo:rerun-if-changed={}", proto.display());
    }

    let mut config = prost_build::Config::new();
    config.type_attribute(".", "#[derive(serde::Serialize, serde::Deserialize)]");
    config.type_attribute(".", "#[serde(rename_all = \"camelCase\")]");

    config.compile_protos(&protos, &[proto_root])?;

    Ok(())
}
