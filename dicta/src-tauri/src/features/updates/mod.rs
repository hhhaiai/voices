use serde::{Deserialize, Serialize};
use tauri::{command, AppHandle, Emitter};
use tauri_plugin_updater::UpdaterExt;
use ts_rs::TS;

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/lib/generated/")]
#[serde(rename_all = "camelCase")]
pub struct UpdateInfo {
    pub version: String,
    pub current_version: String,
    pub body: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/lib/generated/")]
#[serde(rename_all = "camelCase")]
pub struct UpdateProgress {
    pub downloaded: u64,
    pub total: Option<u64>,
    pub percent: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, TS)]
#[ts(export, export_to = "../../src/lib/generated/")]
#[serde(rename_all = "camelCase")]
#[serde(tag = "status")]
pub enum UpdateStatus {
    #[serde(rename = "checking")]
    Checking,
    #[serde(rename = "available")]
    Available { update: UpdateInfo },
    #[serde(rename = "notAvailable")]
    NotAvailable,
    #[serde(rename = "downloading")]
    Downloading { progress: UpdateProgress },
    #[serde(rename = "downloaded")]
    Downloaded,
    #[serde(rename = "installing")]
    Installing,
    #[serde(rename = "error")]
    Error { message: String },
}

/// Check for available updates
/// silent: if true, only emit events when update is available (for background checks)
#[command]
pub async fn check_for_updates(app: AppHandle, silent: bool) -> Result<Option<UpdateInfo>, String> {
    log::info!("Checking for updates (silent: {})...", silent);

    if !silent {
        let _ = app.emit("update-status", UpdateStatus::Checking);
    }

    let updater = app
        .updater_builder()
        .build()
        .map_err(|e| format!("Failed to build updater: {}", e))?;

    match updater.check().await {
        Ok(Some(update)) => {
            log::info!(
                "Update available: {} -> {}",
                update.current_version,
                update.version
            );
            let update_info = UpdateInfo {
                version: update.version.clone(),
                current_version: update.current_version.clone(),
                body: update.body.clone(),
            };

            let _ = app.emit(
                "update-status",
                UpdateStatus::Available {
                    update: update_info.clone(),
                },
            );

            Ok(Some(update_info))
        }
        Ok(None) => {
            log::info!("No updates available");
            if !silent {
                let _ = app.emit("update-status", UpdateStatus::NotAvailable);
            }
            Ok(None)
        }
        Err(e) => {
            let error_msg = e.to_string();
            log::warn!("Update check failed: {}", error_msg);

            if error_msg.contains("decoding")
                || error_msg.contains("404")
                || error_msg.contains("Not Found")
            {
                if !silent {
                    let _ = app.emit("update-status", UpdateStatus::NotAvailable);
                }
                Ok(None)
            } else {
                if !silent {
                    let _ = app.emit(
                        "update-status",
                        UpdateStatus::Error {
                            message: error_msg.clone(),
                        },
                    );
                }
                Err(format!("Failed to check for updates: {}", error_msg))
            }
        }
    }
}

/// Download and install an available update with progress events
#[command]
pub async fn download_and_install_update(app: AppHandle) -> Result<(), String> {
    log::info!("Starting update download and install...");

    let updater = app
        .updater_builder()
        .build()
        .map_err(|e| format!("Failed to build updater: {}", e))?;

    if let Some(update) = updater.check().await.map_err(|e| e.to_string())? {
        log::info!("Downloading update version {}...", update.version);

        let app_clone = app.clone();
        let app_clone2 = app.clone();

        update
            .download_and_install(
                move |downloaded, total| {
                    let percent = total.map(|t| (downloaded as f64 / t as f64) * 100.0);
                    let progress = UpdateProgress {
                        downloaded: downloaded as u64,
                        total: total.map(|t| t as u64),
                        percent,
                    };

                    log::debug!("Download progress: {:.1}%", percent.unwrap_or(0.0));

                    let _ = app_clone.emit("update-status", UpdateStatus::Downloading { progress });
                },
                move || {
                    log::info!("Download complete, preparing to install...");
                    let _ = app_clone2.emit("update-status", UpdateStatus::Downloaded);
                },
            )
            .await
            .map_err(|e| {
                let _ = app.emit(
                    "update-status",
                    UpdateStatus::Error {
                        message: e.to_string(),
                    },
                );
                format!("Failed to install update: {}", e)
            })?;

        // Emit installing status
        let _ = app.emit("update-status", UpdateStatus::Installing);
        log::info!("Update installed successfully, restart required");
    } else {
        log::info!("No update available to install");
    }

    Ok(())
}
