use std::{
    str::FromStr,
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{anyhow, bail};
use automerge::{
    transaction::{CommitOptions, Transactable},
    ActorId, AutoCommit, Change, ChangeHash, ObjType, ReadDoc, Value,
};
use sha2::Digest;

const BLOCKS_LABEL: &str = "blocks";

#[derive(Debug)]
pub struct BChange {
    change: Change,
}

impl BChange {
    fn new(change: Change) -> Self {
        Self { change }
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn actor_id_hex(&self) -> String {
        self.change.actor_id().to_hex_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn change_hash(&self) -> String {
        self.change.hash().to_string()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn timestamp(&self) -> i64 {
        self.change.timestamp()
    }
}

#[derive(Clone)]
pub struct BAutoCommit {
    autocommit: AutoCommit,
}

impl BAutoCommit {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> BAutoCommit {
        let mut automerge = BAutoCommit {
            autocommit: AutoCommit::new(),
        };

        automerge
            .setup_block_label()
            .expect("Should setup block label");

        automerge
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn load(data: Vec<u8>) -> anyhow::Result<BAutoCommit> {
        let autocommit = AutoCommit::load(&data)?;

        Ok(BAutoCommit {
            autocommit: autocommit,
        })
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
    pub fn delete_block(&mut self, index: usize) -> anyhow::Result<()> {
        let Err(err) = self.autocommit.delete(self.blocks_list_id(), index) else {
            return Ok(());
        };

        bail!("Failed to delete root object: {}", err);
    }

    /// Insert block at specific index.
    /// If index is duplicate it will add new value at this index and previous value will be moved to next index
    #[flutter_rust_bridge::frb(sync)]
    pub fn insert_block(&mut self, index: usize, text: String) -> anyhow::Result<()> {
        match self
            .autocommit
            .insert(self.blocks_list_id(), index, text.as_str())
        {
            Ok(id) => id,
            Err(err) => bail!("Failed to insert block object: {}", err),
        };

        Ok(())
    }

    #[flutter_rust_bridge::frb(sync)]
    /// If content is the same nothing will be changed. Returns true if content was changed, othervise false
    pub fn update_block(&mut self, index: usize, text: String) -> anyhow::Result<()> {
        let block_list_id = self.blocks_list_id();

        // let block = self.get_block(index)?;
        // let block_hash = sha2::Sha256::digest(&block);

        // if block_hash == sha2::Sha256::digest(&text) {
        // return Ok(false);
        // }

        self.autocommit.put(block_list_id, index, text.as_str())?;

        Ok(())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn save(&mut self) -> Vec<u8> {
        self.autocommit.save()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn save_incremental(&mut self) -> Vec<u8> {
        self.autocommit.save_incremental()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn load_incremental(&mut self, bytes: Vec<u8>) -> anyhow::Result<usize> {
        self.autocommit
            .load_incremental(&bytes)
            .map_err(|e| anyhow!("Failed to load incremental: {}", e))
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn empty_change(&mut self) {
        let start = SystemTime::now();
        let since_the_epoch = start
            .duration_since(UNIX_EPOCH)
            .expect("time should go forward")
            .as_secs();

        let opts = CommitOptions::default().with_time(since_the_epoch as i64);

        self.autocommit.empty_change(opts);
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn info(&self) -> String {
        format!("{:?}", self.autocommit)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_blocks(&self) -> anyhow::Result<Vec<String>> {
        let mut blocks = vec![];
        for (value, _) in self.autocommit.values(&self.blocks_list_id()) {
            let string = value.to_string();

            let formatted_string = string
                .chars()
                .skip(1)
                .take(string.chars().count() - 2)
                .collect::<String>();

            blocks.push(formatted_string);
        }

        Ok(blocks)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn blocks_length(&self) -> usize {
        let blocks_list_id = self.blocks_list_id();

        self.autocommit.length(blocks_list_id)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn set_actor_id(&mut self, uuid: String) -> anyhow::Result<()> {
        let actor_id = ActorId::from_str(&uuid)?;
        self.autocommit = self.autocommit.clone().with_actor(actor_id);

        Ok(())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_change_list(&mut self) -> Vec<BChange> {
        self.autocommit
            .get_changes(&[])
            .iter()
            .map(|change| BChange::new((*change).clone()))
            .collect()
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn commit(&mut self) {
        let start = SystemTime::now();
        let since_the_epoch = start
            .duration_since(UNIX_EPOCH)
            .expect("time should go forward")
            .as_secs();

        self.autocommit
            .commit_with(CommitOptions::default().with_time(since_the_epoch as i64));
    }

    /// This function setups list of message blocks.
    /// If it is exist it will be skipped
    // #[flutter_rust_bridge::frb(sync)]
    fn setup_block_label(&mut self) -> anyhow::Result<()> {
        if self.block_list_exist()? {
            return Ok(());
        }

        match self
            .autocommit
            .put_object(automerge::ROOT, BLOCKS_LABEL, automerge::ObjType::List)
        {
            Ok(exid) => exid,
            Err(err) => bail!("Failed to put root object: {}", err),
        };

        Ok(())
    }

    fn blocks_list_id(&self) -> automerge::ObjId {
        self.autocommit
            .get(automerge::ROOT, BLOCKS_LABEL)
            .expect("should be in the root")
            .expect("should be inited")
            .1
    }

    fn block_list_exist(&self) -> anyhow::Result<bool> {
        let label = self
            .autocommit
            .get(automerge::ROOT, BLOCKS_LABEL)
            .map_err(|e| anyhow::anyhow!("Failed to get block list: {}", e))?;

        Ok(label.is_some())
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn doc_at_change_hash(&self, change_hash: &str) -> anyhow::Result<BAutoCommit> {
        let hash = ChangeHash::from_str(change_hash)?;
        let autocommit = self.autocommit.clone().fork_at(&[hash])?;

        Ok(BAutoCommit {
            autocommit: autocommit,
        })
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn docs_before_after(
        &mut self,
        change_hash: &str,
    ) -> anyhow::Result<(BAutoCommit, BAutoCommit)> {
        let changes = self.get_change_list();

        let index = changes
            .iter()
            .position(|c| c.change.hash().to_string() == change_hash)
            .ok_or_else(|| anyhow::anyhow!("No such change hash"))?;

        let after_doc = self.doc_at_change_hash(change_hash)?;

        let before_doc = if index == 0 {
            let mut doc = BAutoCommit::new();
            doc.setup_block_label()?;
            doc
        } else {
            let prev_hash = changes[index - 1].change.hash().to_string();
            self.doc_at_change_hash(&prev_hash)?
        };

        Ok((before_doc, after_doc))
    }

    /// For tests only
    pub fn get_automerge(&self) -> &AutoCommit {
        &self.autocommit
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_actor_id() -> String {
    ActorId::random().to_hex_string()
}
