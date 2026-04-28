//! Async file system helpers for use in async contexts.
//!
//! These wrap tokio::fs operations with consistent error handling patterns.
//! Use these instead of std::fs when inside tokio::spawn blocks or async functions.

use std::path::Path;

/// Read file contents asynchronously
pub async fn read_file<P: AsRef<Path>>(path: P) -> Result<Vec<u8>, String> {
    tokio::fs::read(path.as_ref())
        .await
        .map_err(|e| format!("Failed to read file {:?}: {}", path.as_ref(), e))
}

/// Remove directory and all contents asynchronously
pub async fn remove_dir_all<P: AsRef<Path>>(path: P) -> Result<(), String> {
    tokio::fs::remove_dir_all(path.as_ref())
        .await
        .map_err(|e| format!("Failed to remove directory {:?}: {}", path.as_ref(), e))
}

/// Remove a single file asynchronously
pub async fn remove_file<P: AsRef<Path>>(path: P) -> Result<(), String> {
    tokio::fs::remove_file(path.as_ref())
        .await
        .map_err(|e| format!("Failed to remove file {:?}: {}", path.as_ref(), e))
}

/// Check if path exists asynchronously
pub async fn exists<P: AsRef<Path>>(path: P) -> bool {
    tokio::fs::try_exists(path.as_ref()).await.unwrap_or(false)
}

/// Create directory and parents asynchronously
pub async fn create_dir_all<P: AsRef<Path>>(path: P) -> Result<(), String> {
    tokio::fs::create_dir_all(path.as_ref())
        .await
        .map_err(|e| format!("Failed to create directory {:?}: {}", path.as_ref(), e))
}

/// Write data to file asynchronously
pub async fn write<P: AsRef<Path>, C: AsRef<[u8]>>(path: P, contents: C) -> Result<(), String> {
    tokio::fs::write(path.as_ref(), contents)
        .await
        .map_err(|e| format!("Failed to write file {:?}: {}", path.as_ref(), e))
}

/// Read file contents as string asynchronously
pub async fn read_to_string<P: AsRef<Path>>(path: P) -> Result<String, String> {
    tokio::fs::read_to_string(path.as_ref())
        .await
        .map_err(|e| format!("Failed to read file {:?}: {}", path.as_ref(), e))
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_read_write_file() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");

        write(&file_path, b"test content").await.unwrap();
        let content = read_file(&file_path).await.unwrap();

        assert_eq!(content, b"test content");
    }

    #[tokio::test]
    async fn test_read_to_string() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");

        write(&file_path, "hello world").await.unwrap();
        let content = read_to_string(&file_path).await.unwrap();

        assert_eq!(content, "hello world");
    }

    #[tokio::test]
    async fn test_exists() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");

        assert!(!exists(&file_path).await);

        write(&file_path, b"content").await.unwrap();

        assert!(exists(&file_path).await);
    }

    #[tokio::test]
    async fn test_remove_file() {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.txt");

        write(&file_path, b"content").await.unwrap();
        assert!(exists(&file_path).await);

        remove_file(&file_path).await.unwrap();
        assert!(!exists(&file_path).await);
    }

    #[tokio::test]
    async fn test_create_and_remove_dir_all() {
        let dir = tempdir().unwrap();
        let nested = dir.path().join("nested").join("path");

        create_dir_all(&nested).await.unwrap();
        assert!(exists(&nested).await);

        // Create a file in the nested directory
        let file_path = nested.join("file.txt");
        write(&file_path, b"content").await.unwrap();

        // Remove the entire nested structure
        remove_dir_all(dir.path().join("nested")).await.unwrap();
        assert!(!exists(&nested).await);
    }

    #[tokio::test]
    async fn test_read_nonexistent_file_returns_error() {
        let result = read_file("/nonexistent/path/file.txt").await;
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Failed to read file"));
    }

    #[tokio::test]
    async fn test_remove_nonexistent_dir_returns_error() {
        let result = remove_dir_all("/nonexistent/path").await;
        assert!(result.is_err());
    }
}
