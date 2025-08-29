use std::{
    str::FromStr,
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::bail;
use automerge::{
    transaction::{CommitOptions, Transactable},
    ActorId, AutoCommit, Change, ObjType, ReadDoc,
};

const BLOCKS_LABEL: &str = "blocks";

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

pub struct BAutoCommit {
    autocommit: AutoCommit,
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
        let obj_id = match self.autocommit.insert_object(
            self.blocks_list_id(),
            index,
            automerge::ObjType::Text,
        ) {
            Ok(id) => id,
            Err(err) => bail!("Failed to insert block object: {}", err),
        };

        let Err(err) = self.autocommit.splice_text(obj_id, 0, 0, &text) else {
            return Ok(());
        };

        bail!("Failed to put root object: {}", err);
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_block(&self, index: usize) -> anyhow::Result<String> {
        let Some(obj) = self
            .autocommit
            .get(self.blocks_list_id(), index)
            .map_err(|err| {
                anyhow::anyhow!("Failed to get block with index {}, error: {}", index, err)
            })?
        else {
            bail!("No such block with index {}", index);
        };

        match self.autocommit.object_type(&obj.1) {
            Ok(ObjType::Text) => (),
            Err(err) => bail!("Failed to get block object type: {}", err),
            _ => bail!("Invalid block object type"),
        };

        let text = self
            .autocommit
            .text(obj.1)
            .map_err(|err| anyhow::anyhow!("Failed to get text block: {}", err))?;

        Ok(text)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn update_block(&mut self, index: usize, text: String) -> anyhow::Result<()> {
        let obj_id = match self.autocommit.get(self.blocks_list_id(), index) {
            Ok(Some(id)) => id.1,
            Err(err) => bail!("Failed to get block with index {}, error: {}", index, err),
            _ => bail!("No such block with index {}", index),
        };

        let block = self.get_block(index)?;
        let Err(err) = self
            .autocommit
            .splice_text(obj_id, 0, block.len() as isize, &text)
        else {
            return Ok(());
        };

        bail!("Failed to update block: {}", err);
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
    pub fn info(&self) -> String {
        format!("{:?}", self.autocommit)
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn get_blocks(&self) -> anyhow::Result<Vec<String>> {
        let mut block_array = vec![];

        for index in 0..self.blocks_length() {
            block_array.push(self.get_block(index)?);
        }

        Ok(block_array)
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
    #[flutter_rust_bridge::frb(sync)]
    pub fn setup_block_label(&mut self) -> anyhow::Result<()> {
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

    pub fn block_list_exist(&self) -> anyhow::Result<bool> {
        let label = self
            .autocommit
            .get(automerge::ROOT, BLOCKS_LABEL)
            .map_err(|e| anyhow::anyhow!("Failed to get block list: {}", e))?;

        Ok(label.is_some())
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn generate_actor_id() -> String {
    ActorId::random().to_hex_string()
}
