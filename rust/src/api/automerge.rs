use anyhow::bail;
use automerge::{transaction::Transactable, AutoCommit, ObjType, ReadDoc};

pub struct BAutoCommit {
    autocommit: AutoCommit,
}

const BLOCKS_LABEL: &str = "blocks";

impl BAutoCommit {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> BAutoCommit {
        let mut autocommit = BAutoCommit {
            autocommit: AutoCommit::new(),
        };

        autocommit
            .setup_block_label()
            .expect("should put block object");

        autocommit
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

    fn setup_block_label(&mut self) -> anyhow::Result<()> {
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
}
