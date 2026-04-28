fn main() {
    // Set the deployment target to match our minimum system version
    println!("cargo:rustc-env=MACOSX_DEPLOYMENT_TARGET=13.0");

    // Load .env file for build-time environment variables (e.g., VITE_POSTHOG_KEY)
    if let Ok(env_path) = std::fs::canonicalize("../.env") {
        println!("cargo:rerun-if-changed=../.env");
        if let Ok(contents) = std::fs::read_to_string(&env_path) {
            for line in contents.lines() {
                let line = line.trim();
                if line.is_empty() || line.starts_with('#') {
                    continue;
                }
                if let Some((key, value)) = line.split_once('=') {
                    let key = key.trim();
                    let value = value.trim();
                    // Only set if not already set in environment
                    if std::env::var(key).is_err() {
                        println!("cargo:rustc-env={}={}", key, value);
                    }
                }
            }
        }
    }

    // Pass WHISPER_NO_I8MM to whisper-rs-sys build
    if std::env::var("WHISPER_NO_I8MM").is_ok() {
        println!("cargo:rerun-if-env-changed=WHISPER_NO_I8MM");
    }
    tauri_build::build()
}
