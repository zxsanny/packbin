//! AZ-2757 AC-4: the module layout, the Rust component description and the README name the `nostd`
//! module, its features and the CI job that proves it on a device.

const ROOT: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/..");

fn read(path: &str) -> String {
    std::fs::read_to_string(format!("{ROOT}/{path}")).unwrap_or_else(|e| panic!("{path}: {e}"))
}

#[test]
fn ac4_each_document_names_the_module_the_features_and_the_ci_job() {
    // Arrange
    let documents = [
        (
            "README.md",
            vec![
                "packbin::nostd",
                "`session`",
                "`ecc`",
                "`text`",
                "embedded-arm",
            ],
        ),
        (
            "_docs/02_document/module-layout.md",
            vec![
                "rust/src/nostd/",
                "session_core",
                "`session`",
                "`text`",
                "`ecc`",
                "rust/embedded/",
            ],
        ),
        (
            "_docs/02_document/components/04_rust_package/description.md",
            vec![
                "nostd",
                "`session`",
                "`text`",
                "`ecc`",
                "embedded-arm",
                "nostd_hostile_tests",
            ],
        ),
    ];
    for (path, names) in documents {
        // Act
        let text = read(path);
        // Assert
        for name in names {
            assert!(text.contains(name), "{path} does not name {name}");
        }
    }
}
