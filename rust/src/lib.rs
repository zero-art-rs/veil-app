pub mod api;
mod frb_generated;

mod test {
    use crate::api;

    #[test]
    fn bautomerge_flow() -> anyhow::Result<()> {
        let mut autocommit = api::automerge::BAutoCommit::new();

        autocommit.insert_block(0, "hello".to_string())?;
        autocommit.insert_block(1, "world".to_string())?;
        autocommit.insert_block(2, "!!!!".to_string())?;
        autocommit.save_incremental();

        println!(
            "Block with index {}: {}",
            0,
            autocommit.get_block(0).unwrap()
        );
        println!(
            "Block with index {}: {}",
            1,
            autocommit.get_block(1).unwrap()
        );
        println!(
            "Block with index {}: {}",
            2,
            autocommit.get_block(2).unwrap()
        );

        println!("Delete block at index 2");
        autocommit.delete_block(2)?;

        println!(
            "Block with index {}: {}",
            0,
            autocommit.get_block(0).unwrap()
        );

        println!("Update block at index 0");
        autocommit.update_block(0, "hlloe".to_string())?;

        println!(
            "Block with index {}: {}",
            0,
            autocommit.get_block(0).unwrap()
        );

        println!("Save changes");
        autocommit.save_incremental();

        println!("All blocks:");
        for (i, block) in autocommit.get_blocks()?.iter().enumerate() {
            println!("Block with index {}: {}", i, block);
        }

        Ok(())
    }

    #[test]
    fn insert_overrides() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();

        automerge.insert_block(0, "hello".to_string())?;

        // overrides existing block, previous value will be moved to next index
        automerge.insert_block(0, "world".to_string())?;

        println!("Blocks #1: {:?}", automerge.get_blocks());

        assert!(automerge.blocks_length() == 2);
        assert!(automerge.delete_block(1).is_ok());

        println!("Blocks #2: {:?}", automerge.get_blocks());

        Ok(())
    }

    #[test]
    fn empty_get_blocks() -> anyhow::Result<()> {
        let automerge = api::automerge::BAutoCommit::new();

        automerge.get_blocks()?;

        assert!(automerge.blocks_length() == 1);

        Ok(())
    }

    #[test]
    fn duplicate_block() -> anyhow::Result<()> {
        let mut automerge = api::automerge::BAutoCommit::new();

        automerge.insert_block(0, '1'.to_string())?;
        automerge.insert_block(0, '2'.to_string())?;

        let block = automerge.get_block(0)?;

        assert!(block == '2'.to_string());

        Ok(())
    }
}
