use anyhow::bail;
use automerge::{transaction::Transactable, AutoCommit};

pub struct BAutoCommit {
    autocommit: AutoCommit,
}

pub enum BObjType {
    /// A map
    Map,
    /// Retained for backwards compatibility, tables are identical to maps
    Table,
    /// A sequence of arbitrary values
    List,
    /// A sequence of characters
    Text,
}

impl BAutoCommit {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> BAutoCommit {
        BAutoCommit {
            autocommit: AutoCommit::new(),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn from_bytes(bytes: Vec<u8>) -> anyhow::Result<BAutoCommit> {
        let autocommit = match AutoCommit::load(&bytes) {
            Ok(autocommit) => autocommit,
            Err(err) => bail!("Failed to load AutoCommit: {}", err),
        };

        Ok(BAutoCommit { autocommit })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn put_root_object(&mut self, label: &str, value: BObjType) -> anyhow::Result<()> {
        let object = match value {
            BObjType::Map => automerge::ObjType::Map,
            BObjType::Table => automerge::ObjType::Map,
            BObjType::List => automerge::ObjType::List,
            BObjType::Text => automerge::ObjType::Text,
        };

        match self.autocommit.put_object(automerge::ROOT, label, object) {
            Ok(exid) => exid,
            Err(err) => bail!("Failed to put root object: {}", err),
        };

        Ok(())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn save(&mut self) -> Vec<u8> {
        self.autocommit.save()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn info(&self) -> String {
        format!("{:?}", self.autocommit)
    }
}
