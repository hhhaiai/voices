//! Vocabulary and Snippets helper for transcription context
//!
//! Reads vocabulary words and snippets from stores and builds
//! a context string to pass to transcription providers for better accuracy.

use serde::{Deserialize, Serialize};
use tauri::AppHandle;
use tauri_plugin_store::StoreExt;

/// A vocabulary word entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VocabularyWord {
    pub id: String,
    pub word: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
}

/// A snippet entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snippet {
    pub id: String,
    pub snippet: String,
    pub expansion: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
}

/// Context data for transcription providers
#[derive(Debug, Clone, Default)]
pub struct TranscriptionContext {
    /// All vocabulary words
    pub vocabulary_words: Vec<String>,
    /// All snippet triggers (short forms)
    pub snippet_triggers: Vec<String>,
    /// All snippet expansions (what they expand to)
    pub snippet_expansions: Vec<String>,
}

impl TranscriptionContext {
    /// Build a prompt string for Whisper-style providers
    /// Format: comma-separated list of all vocabulary and snippet terms
    pub fn to_prompt(&self) -> Option<String> {
        let mut terms: Vec<&str> = Vec::new();

        // Add vocabulary words
        for word in &self.vocabulary_words {
            terms.push(word.as_str());
        }

        // Add snippet triggers
        for trigger in &self.snippet_triggers {
            terms.push(trigger.as_str());
        }

        // Add snippet expansions (the expanded form might also be spoken)
        for expansion in &self.snippet_expansions {
            terms.push(expansion.as_str());
        }

        if terms.is_empty() {
            None
        } else {
            Some(terms.join(", "))
        }
    }

    /// Get all unique words/phrases for providers that take an array
    pub fn to_word_list(&self) -> Vec<String> {
        let mut words: Vec<String> = Vec::new();

        words.extend(self.vocabulary_words.clone());
        words.extend(self.snippet_triggers.clone());
        words.extend(self.snippet_expansions.clone());

        // Remove duplicates while preserving order
        let mut seen = std::collections::HashSet::new();
        words.retain(|w| seen.insert(w.clone()));

        words
    }

    /// Check if context is empty
    pub fn is_empty(&self) -> bool {
        self.vocabulary_words.is_empty()
            && self.snippet_triggers.is_empty()
            && self.snippet_expansions.is_empty()
    }
}

/// Read vocabulary and snippets from stores and build transcription context
pub fn get_transcription_context(app: &AppHandle) -> TranscriptionContext {
    let mut context = TranscriptionContext::default();

    // Read vocabulary words
    if let Ok(vocab_store) = app.store("vocabulary.json") {
        if let Some(words_value) = vocab_store.get("words") {
            if let Ok(words) = serde_json::from_value::<Vec<VocabularyWord>>(words_value.clone()) {
                context.vocabulary_words = words.into_iter().map(|w| w.word).collect();
                log::debug!(
                    "Loaded {} vocabulary words for transcription context",
                    context.vocabulary_words.len()
                );
            }
        }
    }

    // Read snippets
    if let Ok(snippets_store) = app.store("snippets.json") {
        if let Some(snippets_value) = snippets_store.get("snippets") {
            if let Ok(snippets) = serde_json::from_value::<Vec<Snippet>>(snippets_value.clone()) {
                context.snippet_triggers = snippets.iter().map(|s| s.snippet.clone()).collect();
                context.snippet_expansions = snippets.iter().map(|s| s.expansion.clone()).collect();
                log::debug!(
                    "Loaded {} snippets for transcription context",
                    context.snippet_triggers.len()
                );
            }
        }
    }

    context
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_context_to_prompt() {
        let context = TranscriptionContext {
            vocabulary_words: vec!["Dicta".to_string(), "Tauri".to_string()],
            snippet_triggers: vec!["btw".to_string()],
            snippet_expansions: vec!["by the way".to_string()],
        };

        let prompt = context.to_prompt().unwrap();
        assert!(prompt.contains("Dicta"));
        assert!(prompt.contains("Tauri"));
        assert!(prompt.contains("btw"));
        assert!(prompt.contains("by the way"));
    }

    #[test]
    fn test_empty_context() {
        let context = TranscriptionContext::default();
        assert!(context.is_empty());
        assert!(context.to_prompt().is_none());
    }

    #[test]
    fn test_to_word_list_deduplication() {
        let context = TranscriptionContext {
            vocabulary_words: vec!["Dicta".to_string(), "Tauri".to_string()],
            snippet_triggers: vec!["Dicta".to_string()], // Duplicate
            snippet_expansions: vec![],
        };

        let words = context.to_word_list();
        assert_eq!(words.len(), 2); // Should be deduplicated
    }
}
